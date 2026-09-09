const Hospital = require('../models/Hospital');
const Department = require('../models/Department');
const Doctor = require('../models/Doctor');

const escapeRegex = (value) => String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

async function list(req, res, next) {
	try {
		const filter = { active: true };
		if (req.query.city) filter.city = new RegExp(escapeRegex(req.query.city), 'i');
		if (req.query.q) {
			const term = new RegExp(escapeRegex(req.query.q), 'i');
			filter.$or = [{ name: term }, { city: term }];
		}
		const hospitals = await Hospital.find(filter).sort({ name: 1 }).lean();
		const counts = await Doctor.aggregate([
			{ $match: { active: true } },
			{ $group: { _id: '$hospital', total: { $sum: 1 } } }
		]);
		const byHospital = new Map(counts.map((row) => [String(row._id), row.total]));
		res.json({
			hospitals: hospitals.map((hospital) => ({
				...hospital,
				doctorCount: byHospital.get(String(hospital._id)) || 0
			}))
		});
	} catch (error) { next(error); }
}

async function get(req, res, next) {
	try {
		const hospital = await Hospital.findOne({ _id: req.params.id, active: true }).lean();
		if (!hospital) return res.status(404).json({ message: 'Hospital not found' });
		const departments = await Department.find({ hospital: hospital._id }).sort({ name: 1 }).lean();
		const counts = await Doctor.aggregate([
			{ $match: { hospital: hospital._id, active: true } },
			{ $group: { _id: '$department', total: { $sum: 1 } } }
		]);
		const byDepartment = new Map(counts.map((row) => [String(row._id), row.total]));
		res.json({
			hospital: {
				...hospital,
				doctorCount: counts.reduce((total, row) => total + row.total, 0)
			},
			departments: departments.map((department) => ({
				...department,
				doctorCount: byDepartment.get(String(department._id)) || 0
			}))
		});
	} catch (error) { next(error); }
}

async function listCities(req, res, next) {
	try {
		res.json({ cities: (await Hospital.distinct('city', { active: true })).sort() });
	} catch (error) { next(error); }
}

module.exports = { list, get, listCities };
