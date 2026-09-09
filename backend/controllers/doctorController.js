const mongoose = require('mongoose');
const Doctor = require('../models/Doctor');
const { availableSlots, weeklySchedule, isValidDay } = require('../services/scheduleService');

const escapeRegex = (value) => String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const isObjectId = (value) => mongoose.Types.ObjectId.isValid(value);

async function list(req, res, next) {
	try {
		const filter = { active: true };
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
		res.json({ doctors: doctors.map((doctor) => ({ ...doctor, schedule: weeklySchedule(doctor) })) });
	} catch (error) { next(error); }
}

async function get(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid doctor id' });
		const doctor = await Doctor.findOne({ _id: req.params.id, active: true })
			.populate('hospital', 'name city address phone')
			.populate('department', 'name description')
			.lean();
		if (!doctor) return res.status(404).json({ message: 'Doctor not found' });
		res.json({ doctor: { ...doctor, schedule: weeklySchedule(doctor) } });
	} catch (error) { next(error); }
}

// Bookable times for one day. `exclude` is an appointment id whose own slot
// should stay selectable, so the reschedule screen can show the current time.
async function slots(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid doctor id' });
		const { date, exclude } = req.query;
		if (!isValidDay(date)) return res.status(400).json({ message: 'A valid date (YYYY-MM-DD) is required' });
		const doctor = await Doctor.findOne({ _id: req.params.id, active: true });
		if (!doctor) return res.status(404).json({ message: 'Doctor not found' });
		const open = await availableSlots(doctor, date, {
			ignoreAppointmentId: exclude && isObjectId(exclude) ? exclude : null
		});
		res.json({
			date,
			slotMinutes: doctor.slotMinutes,
			slots: open.map((slot) => slot.toISOString())
		});
	} catch (error) { next(error); }
}

module.exports = { list, get, slots };
