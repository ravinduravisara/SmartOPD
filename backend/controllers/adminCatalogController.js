const City = require('../models/City');
const Hospital = require('../models/Hospital');
const Department = require('../models/Department');
const Doctor = require('../models/Doctor');
const Appointment = require('../models/Appointment');
const Queue = require('../models/Queue');
const {
	escapeRegex,
	exactRegex,
	isObjectId,
	normalizeAvailability,
	validateCity,
	validateHospital,
	validateDepartment,
	validateDoctor,
	citySummary,
	hospitalSummary,
	departmentSummary,
	doctorSummary
} = require('../services/catalogService');

const HOSPITAL_FIELDS = ['name', 'city', 'address', 'phone', 'about', 'active'];
const DEPARTMENT_FIELDS = ['hospital', 'name', 'description'];
const DOCTOR_FIELDS = ['name', 'specialization', 'hospital', 'department', 'qualifications', 'experienceYears', 'consultationFee', 'about', 'slotMinutes', 'active', 'availability'];

// PATCH bodies are partial, so fall back to what is stored and validate the
// whole record. For POST the stored record is simply empty.
function merge(current, body, keys) {
	const payload = {};
	for (const key of keys) payload[key] = body?.[key] === undefined ? current[key] : body[key];
	return payload;
}

async function countsByKey(Model, match, key) {
	const rows = await Model.aggregate([{ $match: match }, { $group: { _id: `$${key}`, total: { $sum: 1 } } }]);
	return new Map(rows.map((row) => [String(row._id), row.total]));
}

// "2 departments, 1 appointment" for the refuse-to-delete messages.
function describe(parts) {
	return parts
		.filter(([total]) => total > 0)
		.map(([total, noun, plural]) => `${total} ${total === 1 ? noun : plural || `${noun}s`}`)
		.join(', ');
}

// A city exists when it is registered, when hospitals use it, or both.
async function lookupCity(name) {
	const pattern = exactRegex(name);
	const [registered, hospitals] = await Promise.all([
		City.findOne({ name: pattern }).lean(),
		Hospital.countDocuments({ city: pattern })
	]);
	return { registered, hospitals };
}

async function listCities(req, res, next) {
	try {
		const [registered, grouped] = await Promise.all([
			City.find().lean(),
			Hospital.aggregate([{ $group: { _id: { $toLower: '$city' }, name: { $first: '$city' }, total: { $sum: 1 } } }])
		]);
		const cities = new Map();
		for (const row of grouped) cities.set(row._id, citySummary(row.name, row.total));
		// A registered name wins over the spelling a hospital happens to use.
		for (const city of registered) {
			const key = city.name.toLowerCase();
			cities.set(key, citySummary(city.name, cities.get(key)?.hospitalCount || 0));
		}
		res.json({ cities: [...cities.values()].sort((a, b) => a.name.localeCompare(b.name)) });
	} catch (error) { next(error); }
}

async function createCity(req, res, next) {
	try {
		const message = validateCity(req.body);
		if (message) return res.status(400).json({ message });
		const name = req.body.name.trim();
		const existing = await lookupCity(name);
		if (existing.registered || existing.hospitals) return res.status(409).json({ message: 'That city is already on the list' });
		const city = await City.create({ name });
		res.status(201).json({ city: citySummary(city.name, 0) });
	} catch (error) {
		if (error.code === 11000) return res.status(409).json({ message: 'That city is already on the list' });
		next(error);
	}
}

async function renameCity(req, res, next) {
	try {
		const message = validateCity(req.body);
		if (message) return res.status(400).json({ message });
		const current = await lookupCity(req.params.name);
		if (!current.registered && !current.hospitals) return res.status(404).json({ message: 'City not found' });
		const name = req.body.name.trim();
		// Changing only the casing of the same city is fine; a different name must be free.
		if (name.toLowerCase() !== String(req.params.name).trim().toLowerCase()) {
			const target = await lookupCity(name);
			if (target.registered || target.hospitals) return res.status(409).json({ message: 'Another city already uses that name' });
		}
		if (current.registered) await City.updateOne({ _id: current.registered._id }, { $set: { name } });
		await Hospital.updateMany({ city: exactRegex(req.params.name) }, { $set: { city: name } });
		res.json({ city: citySummary(name, await Hospital.countDocuments({ city: exactRegex(name) })) });
	} catch (error) {
		if (error.code === 11000) return res.status(409).json({ message: 'Another city already uses that name' });
		next(error);
	}
}

async function deleteCity(req, res, next) {
	try {
		const current = await lookupCity(req.params.name);
		if (!current.registered && !current.hospitals) return res.status(404).json({ message: 'City not found' });
		if (current.hospitals) return res.status(409).json({ message: `This city still has ${describe([[current.hospitals, 'hospital']])}. Move or delete those hospitals before removing the city.` });
		await City.deleteOne({ _id: current.registered._id });
		res.status(204).end();
	} catch (error) { next(error); }
}

// Admin listings include inactive rows; only the patient-facing endpoints filter on active.
async function listHospitals(req, res, next) {
	try {
		const filter = {};
		if (req.query.city) filter.city = exactRegex(req.query.city);
		if (req.query.q) {
			const term = new RegExp(escapeRegex(req.query.q), 'i');
			filter.$or = [{ name: term }, { city: term }];
		}
		const hospitals = await Hospital.find(filter).sort({ name: 1 }).lean();
		const ids = hospitals.map((hospital) => hospital._id);
		const [departments, doctors] = await Promise.all([
			countsByKey(Department, { hospital: { $in: ids } }, 'hospital'),
			countsByKey(Doctor, { hospital: { $in: ids } }, 'hospital')
		]);
		res.json({
			hospitals: hospitals.map((hospital) => hospitalSummary(hospital, {
				departmentCount: departments.get(String(hospital._id)) || 0,
				doctorCount: doctors.get(String(hospital._id)) || 0
			}))
		});
	} catch (error) { next(error); }
}

async function createHospital(req, res, next) {
	try {
		const payload = merge({}, req.body, HOSPITAL_FIELDS);
		const message = validateHospital(payload);
		if (message) return res.status(400).json({ message });
		const hospital = await Hospital.create(payload);
		res.status(201).json({ hospital: hospitalSummary(hospital) });
	} catch (error) { next(error); }
}

async function updateHospital(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid hospital id' });
		const hospital = await Hospital.findById(req.params.id);
		if (!hospital) return res.status(404).json({ message: 'Hospital not found' });
		const payload = merge(hospital, req.body, HOSPITAL_FIELDS);
		const message = validateHospital(payload);
		if (message) return res.status(400).json({ message });
		Object.assign(hospital, payload);
		await hospital.save();
		const [departmentCount, doctorCount] = await Promise.all([
			Department.countDocuments({ hospital: hospital._id }),
			Doctor.countDocuments({ hospital: hospital._id })
		]);
		res.json({ hospital: hospitalSummary(hospital, { departmentCount, doctorCount }) });
	} catch (error) { next(error); }
}

async function deleteHospital(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid hospital id' });
		const hospital = await Hospital.findById(req.params.id).lean();
		if (!hospital) return res.status(404).json({ message: 'Hospital not found' });
		const [departments, doctors, appointments] = await Promise.all([
			Department.countDocuments({ hospital: hospital._id }),
			Doctor.countDocuments({ hospital: hospital._id }),
			Appointment.countDocuments({ hospital: hospital._id })
		]);
		const blockers = describe([[departments, 'department'], [doctors, 'doctor'], [appointments, 'appointment']]);
		if (blockers) return res.status(409).json({ message: `This hospital still has ${blockers}. Deactivate it instead of deleting it.` });
		await Hospital.deleteOne({ _id: hospital._id });
		res.status(204).end();
	} catch (error) { next(error); }
}

async function listDepartments(req, res, next) {
	try {
		const filter = {};
		if (req.query.hospital) {
			if (!isObjectId(req.query.hospital)) return res.status(400).json({ message: 'Invalid hospital id' });
			filter.hospital = req.query.hospital;
		}
		const departments = await Department.find(filter).populate('hospital', 'name city').sort({ name: 1 }).lean();
		const doctors = await countsByKey(Doctor, { department: { $in: departments.map((department) => department._id) } }, 'department');
		res.json({ departments: departments.map((department) => departmentSummary(department, doctors.get(String(department._id)) || 0)) });
	} catch (error) { next(error); }
}

// A department name is unique inside its hospital; the same name may repeat across hospitals.
async function duplicateDepartment(hospital, name, excludeId) {
	const filter = { hospital, name: exactRegex(name) };
	if (excludeId) filter._id = { $ne: excludeId };
	return Department.exists(filter);
}

async function createDepartment(req, res, next) {
	try {
		const payload = merge({}, req.body, DEPARTMENT_FIELDS);
		const message = validateDepartment(payload);
		if (message) return res.status(400).json({ message });
		if (!await Hospital.exists({ _id: payload.hospital })) return res.status(404).json({ message: 'Hospital not found' });
		if (await duplicateDepartment(payload.hospital, payload.name)) return res.status(409).json({ message: 'That hospital already has a department with this name' });
		const department = await Department.create(payload);
		await department.populate('hospital', 'name city');
		res.status(201).json({ department: departmentSummary(department, 0) });
	} catch (error) {
		if (error.code === 11000) return res.status(409).json({ message: 'That hospital already has a department with this name' });
		next(error);
	}
}

async function updateDepartment(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid department id' });
		const department = await Department.findById(req.params.id);
		if (!department) return res.status(404).json({ message: 'Department not found' });
		const payload = merge(department, req.body, DEPARTMENT_FIELDS);
		const message = validateDepartment(payload);
		if (message) return res.status(400).json({ message });
		if (!await Hospital.exists({ _id: payload.hospital })) return res.status(404).json({ message: 'Hospital not found' });
		const doctorCount = await Doctor.countDocuments({ department: department._id });
		// Moving a department would strand its doctors under the old hospital.
		if (String(payload.hospital) !== String(department.hospital) && doctorCount) {
			return res.status(409).json({ message: `This department still has ${describe([[doctorCount, 'doctor']])}. Move them before moving the department to another hospital.` });
		}
		if (await duplicateDepartment(payload.hospital, payload.name, department._id)) return res.status(409).json({ message: 'That hospital already has a department with this name' });
		Object.assign(department, payload);
		await department.save();
		await department.populate('hospital', 'name city');
		res.json({ department: departmentSummary(department, doctorCount) });
	} catch (error) {
		if (error.code === 11000) return res.status(409).json({ message: 'That hospital already has a department with this name' });
		next(error);
	}
}

async function deleteDepartment(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid department id' });
		const department = await Department.findById(req.params.id).lean();
		if (!department) return res.status(404).json({ message: 'Department not found' });
		const doctors = await Doctor.countDocuments({ department: department._id });
		if (doctors) return res.status(409).json({ message: `This department still has ${describe([[doctors, 'doctor']])}. Move or deactivate them before deleting it.` });
		await Department.deleteOne({ _id: department._id });
		res.status(204).end();
	} catch (error) { next(error); }
}

async function listDoctors(req, res, next) {
	try {
		const filter = {};
		if (req.query.hospital) {
			if (!isObjectId(req.query.hospital)) return res.status(400).json({ message: 'Invalid hospital id' });
			filter.hospital = req.query.hospital;
		}
		if (req.query.department) {
			if (!isObjectId(req.query.department)) return res.status(400).json({ message: 'Invalid department id' });
			filter.department = req.query.department;
		}
		if (req.query.q) {
			const term = new RegExp(escapeRegex(req.query.q), 'i');
			filter.$or = [{ name: term }, { specialization: term }];
		}
		const doctors = await Doctor.find(filter)
			.populate('hospital', 'name city')
			.populate('department', 'name')
			.sort({ name: 1 })
			.lean();
		res.json({ doctors: doctors.map(doctorSummary) });
	} catch (error) { next(error); }
}

// Returns an error response body, or null when the pairing is valid.
async function checkPlacement(payload) {
	if (!await Hospital.exists({ _id: payload.hospital })) return { status: 404, message: 'Hospital not found' };
	const department = await Department.findById(payload.department).select('hospital').lean();
	if (!department) return { status: 404, message: 'Department not found' };
	if (String(department.hospital) !== String(payload.hospital)) return { status: 400, message: 'The selected department does not belong to that hospital' };
	return null;
}

async function createDoctor(req, res, next) {
	try {
		const payload = merge({}, req.body, DOCTOR_FIELDS);
		const message = validateDoctor(payload);
		if (message) return res.status(400).json({ message });
		const placement = await checkPlacement(payload);
		if (placement) return res.status(placement.status).json({ message: placement.message });
		if (payload.availability !== undefined) payload.availability = normalizeAvailability(payload.availability);
		const doctor = await Doctor.create(payload);
		await doctor.populate([{ path: 'hospital', select: 'name city' }, { path: 'department', select: 'name' }]);
		res.status(201).json({ doctor: doctorSummary(doctor) });
	} catch (error) { next(error); }
}

async function updateDoctor(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid doctor id' });
		const doctor = await Doctor.findById(req.params.id);
		if (!doctor) return res.status(404).json({ message: 'Doctor not found' });
		const payload = merge(doctor, req.body, DOCTOR_FIELDS);
		const message = validateDoctor(payload);
		if (message) return res.status(400).json({ message });
		const placement = await checkPlacement(payload);
		if (placement) return res.status(placement.status).json({ message: placement.message });
		payload.availability = normalizeAvailability(payload.availability);
		Object.assign(doctor, payload);
		await doctor.save();
		await doctor.populate([{ path: 'hospital', select: 'name city' }, { path: 'department', select: 'name' }]);
		res.json({ doctor: doctorSummary(doctor) });
	} catch (error) { next(error); }
}

async function deleteDoctor(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid doctor id' });
		const doctor = await Doctor.findById(req.params.id).lean();
		if (!doctor) return res.status(404).json({ message: 'Doctor not found' });
		const [appointments, queueEntries] = await Promise.all([
			Appointment.countDocuments({ doctor: doctor._id }),
			Queue.countDocuments({ doctorId: doctor._id })
		]);
		const blockers = describe([[appointments, 'appointment'], [queueEntries, 'queue entry', 'queue entries']]);
		if (blockers) return res.status(409).json({ message: `This doctor still has ${blockers}. Deactivate the doctor instead of deleting them.` });
		await Doctor.deleteOne({ _id: doctor._id });
		res.status(204).end();
	} catch (error) { next(error); }
}

module.exports = {
	listCities,
	createCity,
	renameCity,
	deleteCity,
	listHospitals,
	createHospital,
	updateHospital,
	deleteHospital,
	listDepartments,
	createDepartment,
	updateDepartment,
	deleteDepartment,
	listDoctors,
	createDoctor,
	updateDoctor,
	deleteDoctor
};
