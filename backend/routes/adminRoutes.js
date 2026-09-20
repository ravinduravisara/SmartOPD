const express = require('express');
const User = require('../models/User');
const { validateAdmin, createAdmin, adminSummary } = require('../services/adminService');
const catalog = require('../controllers/adminCatalogController');
const router = express.Router();

// requireAuth in server.js loads the current role from the database.
router.use((req, res, next) => {
  if (req.user?.role !== 'admin') return res.status(403).json({ message: 'Administrator access required' });
  next();
});

router.get('/dashboard', async (req, res, next) => {
  try {
    const admins = await User.find({ role: 'admin' }).select('name email role createdAt').sort({ createdAt: -1 });
    res.json({ admins: admins.map(adminSummary) });
  } catch (error) { next(error); }
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
