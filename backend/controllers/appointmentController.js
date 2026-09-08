const Appointment = require('../models/Appointment');
const Dependent = require('../models/Dependent');

async function create(req, res, next) {
	try {
		const { doctor, dependent, scheduledAt, reason } = req.body;
		if (!doctor || !scheduledAt) return res.status(400).json({ message: 'Doctor and appointment time are required' });
		if (dependent) {
			const owned = await Dependent.exists({ _id: dependent, patient: req.user.id });
			if (!owned) return res.status(403).json({ message: 'You can only book for your own dependent' });
		}
		const appointment = await Appointment.create({ patient: req.user.id, doctor, dependent: dependent || null, scheduledAt, reason });
		res.status(201).json({ appointment });
	} catch (error) { next(error); }
}

async function listMine(req, res, next) {
	try {
		const appointments = await Appointment.find({ patient: req.user.id }).populate('dependent', 'name relationship').sort({ scheduledAt: 1 });
		res.json({ appointments });
	} catch (error) { next(error); }
}

module.exports = { create, listMine };
