const express = require('express');
const mongoose = require('mongoose');
const User = require('../models/User');
const Doctor = require('../models/Doctor');
const Hospital = require('../models/Hospital');
const Department = require('../models/Department');
const Appointment = require('../models/Appointment');
const Queue = require('../models/Queue');
const AuditLog = require('../models/AuditLog');
const { roles, validateAdmin, validateUser, createAdmin, hashPassword, adminSummary, userSummary } = require('../services/adminService');
const catalog = require('../controllers/adminCatalogController');
const router = express.Router();

async function syncDoctorProfile(user, profile) {
  if (!profile || user.role !== 'doctor') return;
  if (!mongoose.isValidObjectId(profile.hospital) || !mongoose.isValidObjectId(profile.department)) throw Object.assign(new Error('A valid hospital and department are required for a doctor'), { status: 400 });
  const department = await Department.findById(profile.department).select('hospital');
  if (!department) throw Object.assign(new Error('Department not found'), { status: 404 });
  if (String(department.hospital) !== String(profile.hospital)) throw Object.assign(new Error('The selected department does not belong to that hospital'), { status: 400 });
  if (!await Hospital.exists({ _id: profile.hospital })) throw Object.assign(new Error('Hospital not found'), { status: 404 });
  if (typeof profile.specialization !== 'string' || !profile.specialization.trim()) throw Object.assign(new Error('Specialization is required for a doctor'), { status: 400 });
  const details = {
    user: user._id,
    name: user.name,
    specialization: profile.specialization.trim(),
    hospital: profile.hospital,
    department: profile.department,
    active: profile.active !== false
  };
  const doctor = user.doctorProfile
    ? await Doctor.findByIdAndUpdate(user.doctorProfile, details, { new: true, runValidators: true })
    : await Doctor.create(details);
  if (!doctor) throw Object.assign(new Error('Doctor profile not found'), { status: 404 });
  if (!user.doctorProfile) {
    user.doctorProfile = doctor._id;
    await user.save();
  }
}

// requireAuth in server.js loads the current role from the database.
router.use((req, res, next) => {
  if (req.user?.role !== 'admin') return res.status(403).json({ message: 'Administrator access required' });
  next();
});

router.use((req, res, next) => {
  if (['POST', 'PATCH', 'PUT', 'DELETE'].includes(req.method) && !req.path.startsWith('/audit')) {
    res.on('finish', () => {
      if (res.statusCode < 200 || res.statusCode >= 400) return;
      if (!mongoose.isValidObjectId(req.user.id)) return;
      const parts = req.path.split('/').filter(Boolean);
      const module = parts[0] || 'admin';
      const action = req.method === 'POST'
        ? 'CREATE'
        : req.method === 'DELETE' ? 'DELETE' : 'UPDATE';
      AuditLog.create({
        actor: req.user.id,
        action,
        module,
        description: `${action} ${module} record`,
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        success: true,
        metadata: { resourceId: parts[1] || null },
      }).catch((error) => console.error('Failed to write audit log:', error));
    });
  }
  next();
});

router.get('/audit', async (req, res, next) => {
  try {
    const search = String(req.query.q || '').trim();
    const module = String(req.query.module || '').trim();
    const action = String(req.query.action || '').trim();
    const page = Math.max(1, Number.parseInt(req.query.page, 10) || 1);
    const limit = Math.min(50, Math.max(1, Number.parseInt(req.query.limit, 10) || 20));
    const query = {};
    if (module) query.module = module;
    if (action && ['CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'SECURITY'].includes(action)) query.action = action;
    if (search) {
      query.$or = [
        { description: { $regex: search, $options: 'i' } },
        { module: { $regex: search, $options: 'i' } },
      ];
    }
    const [logs, total] = await Promise.all([
      AuditLog.find(query)
        .populate('actor', 'name email role')
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),
      AuditLog.countDocuments(query),
    ]);
    res.json({
      logs,
      total,
      page,
      pages: Math.max(1, Math.ceil(total / limit)),
    });

    router.patch('/audit/:id/seen', async (req, res, next) => {
      try {
        if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid audit record id' });
        const log = await AuditLog.findByIdAndUpdate(
          req.params.id,
          { seen: true, seenAt: new Date(), seenBy: req.user.id },
          { new: true },
        );
        if (!log) return res.status(404).json({ message: 'Audit record not found' });
        res.json({ message: 'Audit record marked as seen' });
      } catch (error) { next(error); }
    });

    router.delete('/audit/:id', async (req, res, next) => {
      try {
        if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid audit record id' });
        const log = await AuditLog.findByIdAndDelete(req.params.id);
        if (!log) return res.status(404).json({ message: 'Audit record not found' });
        res.json({ message: 'Audit record deleted' });
      } catch (error) { next(error); }
    });
  } catch (error) { next(error); }
});

router.get('/dashboard', async (req, res, next) => {
  try {
    const admins = await User.find({ role: 'admin' }).select('name email role createdAt').sort({ createdAt: -1 });
    res.json({ admins: admins.map(adminSummary) });
  } catch (error) { next(error); }
});

router.get('/dashboard/metrics', async (req, res, next) => {
  try {
    const now = new Date();
    const startOfToday = new Date(now);
    startOfToday.setHours(0, 0, 0, 0);
    const startOfTomorrow = new Date(startOfToday);
    startOfTomorrow.setDate(startOfTomorrow.getDate() + 1);

    const [userCounts, catalogCounts, appointmentCounts, queueCounts, hourly] =
      await Promise.all([
        User.aggregate([
          { $group: { _id: '$role', count: { $sum: 1 } } },
        ]),
        Promise.all([
          Doctor.countDocuments({ active: true }),
          Hospital.countDocuments({ active: true }),
          Department.countDocuments(),
        ]),
        Appointment.aggregate([
          {
            $match: {
              scheduledAt: { $gte: startOfToday, $lt: startOfTomorrow },
            },
          },
          { $group: { _id: '$status', count: { $sum: 1 } } },
        ]),
        Queue.aggregate([
          {
            $match: {
              createdAt: { $gte: startOfToday, $lt: startOfTomorrow },
            },
          },
          { $group: { _id: '$status', count: { $sum: 1 } } },
        ]),
        Appointment.aggregate([
          {
            $match: {
              scheduledAt: { $gte: startOfToday, $lt: startOfTomorrow },
              status: { $ne: 'cancelled' },
            },
          },
          {
            $group: {
              _id: { $hour: '$scheduledAt' },
              count: { $sum: 1 },
            },
          },
          { $sort: { _id: 1 } },
        ]),
      ]);

    const countBy = (rows) => Object.fromEntries(
      rows.map((row) => [row._id, row.count]),
    );
    const rolesByCount = countBy(userCounts);
    const appointmentsByStatus = countBy(appointmentCounts);
    const queueByStatus = countBy(queueCounts);

    res.json({
      generatedAt: now.toISOString(),
      totals: {
        patients: rolesByCount.patient || 0,
        doctors: catalogCounts[0],
        administrators: rolesByCount.admin || 0,
        hospitals: catalogCounts[1],
        departments: catalogCounts[2],
        appointmentsToday: Object.values(appointmentsByStatus)
          .reduce((total, count) => total + count, 0),
        waiting: ['WAITING', 'CHECKED_IN', 'CALLED', 'IN_CONSULTATION']
          .reduce((total, status) => total + (queueByStatus[status] || 0), 0),
        completed: appointmentsByStatus.completed || 0,
        noShows: queueByStatus.NO_SHOW || 0,
      },
      usersByRole: {
        patient: rolesByCount.patient || 0,
        doctor: rolesByCount.doctor || 0,
        admin: rolesByCount.admin || 0,
      },
      appointmentsByStatus: {
        booked: appointmentsByStatus.booked || 0,
        completed: appointmentsByStatus.completed || 0,
        cancelled: appointmentsByStatus.cancelled || 0,
      },
      queueByStatus,
      hourlyAppointments: hourly.map((row) => ({
        hour: row._id,
        count: row.count,
      })),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/admins', async (req, res, next) => {
  try {
    const message = validateAdmin(req.body);
    if (message) return res.status(400).json({ message });
    const user = await createAdmin(req.body);
    res.status(201).json({ admin: adminSummary(user) });
  } catch (error) {
    if (error.code === 11000) return res.status(409).json({ message: 'An account with this email already exists' });
    next(error);
  }
});

router.get('/users', async (req, res, next) => {
  try {
    const search = String(req.query.q || '').trim();
    const role = String(req.query.role || '').trim();
    const verified = String(req.query.verified || '').trim();
    const page = Math.max(1, Number.parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, Number.parseInt(req.query.limit, 10) || 25));
    const userQuery = {};
    if (search) userQuery.$or = [{ name: { $regex: search, $options: 'i' } }, { email: { $regex: search, $options: 'i' } }, { phone: { $regex: search, $options: 'i' } }];
    if (role && roles.includes(role)) userQuery.role = role;
    if (verified === 'true' || verified === 'false') userQuery.isEmailVerified = verified === 'true';
    const doctorQuery = { $or: [{ user: { $exists: false } }, { user: null }] };
    if (search) doctorQuery.$and = [{ $or: [{ name: { $regex: search, $options: 'i' } }, { specialization: { $regex: search, $options: 'i' } }] }];
    if (role && role !== 'doctor') doctorQuery._id = { $in: [] };
    if (verified === 'true') doctorQuery._id = { $in: [] };
    const [users, doctors] = await Promise.all([
      User.find(userQuery).select('name email phone role doctorProfile isEmailVerified dateOfBirth gender profilePicture createdAt updatedAt').populate({ path: 'doctorProfile', select: 'specialization hospital department', populate: [{ path: 'hospital', select: 'name' }, { path: 'department', select: 'name' }] }).lean(),
      Doctor.find(doctorQuery).populate('hospital', 'name city').populate('department', 'name').lean()
    ]);
    const catalogDoctors = doctors.map((doctor) => ({
      _id: `catalog-${doctor._id}`,
      name: doctor.name,
      email: '',
      role: 'doctor',
      isEmailVerified: false,
      doctorProfile: doctor,
      catalogOnly: true,
      createdAt: doctor.createdAt,
      updatedAt: doctor.updatedAt
    }));
    const combined = [...users, ...catalogDoctors].sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
    const total = combined.length;
    const paged = combined.slice((page - 1) * limit, page * limit);
    res.json({ users: paged.map(userSummary), total, page, limit, pages: Math.max(1, Math.ceil(total / limit)) });
  } catch (error) { next(error); }
});

router.post('/doctors/:id/account', async (req, res, next) => {
  let user;
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid doctor id' });
    const doctor = await Doctor.findById(req.params.id);
    if (!doctor) return res.status(404).json({ message: 'Doctor not found' });
    if (doctor.user) return res.status(409).json({ message: 'This doctor already has a login account' });
    const message = validateUser({
      name: doctor.name,
      email: req.body.email,
      password: req.body.password,
      role: 'doctor'
    });
    if (message) return res.status(400).json({ message });
    user = await User.create({
      name: doctor.name,
      email: req.body.email.trim().toLowerCase(),
      password: await hashPassword(req.body.password),
      role: 'doctor',
      isEmailVerified: true,
      doctorProfile: doctor._id
    });
    doctor.user = user._id;
    await doctor.save();
    res.status(201).json({ user: userSummary(user) });
  } catch (error) {
    if (user?._id) await User.deleteOne({ _id: user._id }).catch(() => {});
    if (error.code === 11000) return res.status(409).json({ message: 'An account with this email already exists' });
    next(error);
  }
});

router.post('/users', async (req, res, next) => {
  let user;
  try {
    const message = validateUser(req.body);
    if (message) return res.status(400).json({ message });
    user = await User.create({
      name: req.body.name.trim(),
      email: req.body.email.trim().toLowerCase(),
      phone: req.body.phone?.trim() || undefined,
      password: await hashPassword(req.body.password),
      role: req.body.role || 'patient',
      isEmailVerified: req.body.isEmailVerified !== false
    });
    await syncDoctorProfile(user, req.body.doctorProfile);
    res.status(201).json({ user: userSummary(user) });
  } catch (error) {
    if (user?._id) await User.deleteOne({ _id: user._id }).catch(() => {});
    if (error.status) return res.status(error.status).json({ message: error.message });
    if (error.code === 11000) return res.status(409).json({ message: 'An account with this email already exists' });
    next(error);
  }
});

router.patch('/users/:id', async (req, res, next) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid user id' });
    if (req.params.id === String(req.user.id) && req.body.role && req.body.role !== 'admin') return res.status(400).json({ message: 'You cannot remove your own administrator access' });
    if (req.params.id === String(req.user.id) && req.body.isEmailVerified === false) return res.status(400).json({ message: 'You cannot disable verification for your own account' });
    const existing = await User.findById(req.params.id).select('+password +tokenVersion');
    if (!existing) return res.status(404).json({ message: 'User not found' });
    const updates = {};
    if (req.body.name !== undefined) updates.name = req.body.name;
    if (req.body.email !== undefined) updates.email = String(req.body.email).trim().toLowerCase();
    if (req.body.phone !== undefined) updates.phone = req.body.phone?.trim() || undefined;
    if (req.body.role !== undefined) updates.role = req.body.role;
    if (req.body.isEmailVerified !== undefined) updates.isEmailVerified = req.body.isEmailVerified;
    if (req.body.password !== undefined) updates.password = req.body.password;
    const message = validateUser({ name: updates.name ?? existing.name, email: updates.email ?? existing.email, password: updates.password, role: updates.role ?? existing.role }, { passwordRequired: false });
    if (message) return res.status(400).json({ message });
    if (updates.password !== undefined) updates.password = await hashPassword(updates.password);
    if (updates.role && updates.role !== existing.role || updates.password) updates.$inc = { tokenVersion: 1 };
    const user = await User.findByIdAndUpdate(req.params.id, updates, { new: true, runValidators: true });
    if (user.role === 'doctor' && req.body.doctorProfile) {
      await syncDoctorProfile(user, req.body.doctorProfile);
    } else if (user.doctorProfile && user.role !== 'doctor') {
      await Doctor.findByIdAndUpdate(user.doctorProfile, { active: false });
    }
    res.json({ user: userSummary(user) });
  } catch (error) {
    if (error.status) return res.status(error.status).json({ message: error.message });
    if (error.code === 11000) return res.status(409).json({ message: 'An account with this email already exists' });
    next(error);
  }
});

router.delete('/users/:id', async (req, res, next) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid user id' });
    if (req.params.id === String(req.user.id)) return res.status(400).json({ message: 'You cannot delete your own account' });
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    if (user.role === 'admin' && await User.countDocuments({ role: 'admin' }) <= 1) return res.status(400).json({ message: 'At least one administrator must remain' });
    await User.deleteOne({ _id: req.params.id });
    res.json({ message: 'User deleted' });
  } catch (error) { next(error); }
});

// Catalog management: cities, hospitals, departments and doctors.
router.get('/cities', catalog.listCities);
router.post('/cities', catalog.createCity);
router.patch('/cities/:name', catalog.renameCity);
router.delete('/cities/:name', catalog.deleteCity);

router.get('/hospitals', catalog.listHospitals);
router.post('/hospitals', catalog.createHospital);
router.patch('/hospitals/:id', catalog.updateHospital);
router.delete('/hospitals/:id', catalog.deleteHospital);

router.get('/departments', catalog.listDepartments);
router.post('/departments', catalog.createDepartment);
router.patch('/departments/:id', catalog.updateDepartment);
router.delete('/departments/:id', catalog.deleteDepartment);

router.get('/doctors', catalog.listDoctors);
router.post('/doctors', catalog.createDoctor);
router.patch('/doctors/:id', catalog.updateDoctor);
router.delete('/doctors/:id', catalog.deleteDoctor);

module.exports = router;
