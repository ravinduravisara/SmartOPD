const mongoose = require('mongoose');
const Appointment = require('../models/Appointment');
const Dependent = require('../models/Dependent');
const Doctor = require('../models/Doctor');
const Hospital = require('../models/Hospital');
const Notification = require('../models/Notification');
const { notifyPatientQueueUpdate } = require('../services/socketService');
const { availableSlots } = require('../services/scheduleService');

const isObjectId = (value) => mongoose.Types.ObjectId.isValid(value);
const DUPLICATE_KEY = 11000;

const POPULATE = [
	{ path: 'dependent', select: 'name relationship' },
	{ path: 'doctor', select: 'name specialization consultationFee photo' },
	{ path: 'hospital', select: 'name city address phone' },
	{ path: 'department', select: 'name' }
];

const dayOf = (date) => {
	const local = new Date(date);
	return `${local.getFullYear()}-${String(local.getMonth() + 1).padStart(2, '0')}-${String(local.getDate()).padStart(2, '0')}`;
};

// A slot is bookable only if the doctor's own schedule still offers it, which
// also rules out past times and days the doctor does not work.
async function assertSlotIsOpen(doctor, when, ignoreAppointmentId) {
	const open = await availableSlots(doctor, dayOf(when), { ignoreAppointmentId });
	return open.some((slot) => slot.getTime() === when.getTime());
}

async function create(req, res, next) {
	try {
		const { doctor: doctorId, dependent, scheduledAt, reason } = req.body;
		if (!doctorId || !scheduledAt) return res.status(400).json({ message: 'Doctor and appointment time are required' });
		if (!isObjectId(doctorId)) return res.status(400).json({ message: 'Invalid doctor id' });
		const when = new Date(scheduledAt);
		if (Number.isNaN(when.getTime())) return res.status(400).json({ message: 'Invalid appointment time' });

		const doctor = await Doctor.findOne({ _id: doctorId, active: true });
		if (!doctor) return res.status(404).json({ message: 'Doctor not found' });

		if (dependent) {
			if (!isObjectId(dependent)) return res.status(400).json({ message: 'Invalid dependent id' });
			const owned = await Dependent.exists({ _id: dependent, patient: req.user.id });
			if (!owned) return res.status(403).json({ message: 'You can only book for your own dependent' });
		}
		if (!(await assertSlotIsOpen(doctor, when, null))) {
			return res.status(409).json({ message: 'That time is no longer available. Pick another slot.' });
		}
		const clash = await Appointment.findOne({ patient: req.user.id, scheduledAt: when, status: 'booked' });
		if (clash) return res.status(409).json({ message: 'You already have an appointment at that time' });

		const appointment = await Appointment.create({
			patient: req.user.id,
			doctor: doctor._id,
			hospital: doctor.hospital,
			department: doctor.department,
			dependent: dependent || null,
			scheduledAt: when,
			durationMinutes: doctor.slotMinutes,
			reason
		});

		const populatedApp = await appointment.populate(POPULATE);

		// Create in-app confirmation notification
		try {
			const formattedDate = new Date(when).toLocaleDateString('en-US', {
				month: 'short',
				day: 'numeric',
				year: 'numeric'
			});
			const formattedTime = new Date(when).toLocaleTimeString('en-US', {
				hour: '2-digit',
				minute: '2-digit'
			});

			const hospitalName = populatedApp.hospital?.name || 'Hospital';
			const doctorName = doctor.name || 'Doctor';

			const notification = await Notification.create({
				userId: req.user.id,
				appointmentId: appointment._id,
				title: 'Appointment Confirmed 🎉',
				message: `Your appointment with Dr. ${doctorName} at ${hospitalName} is booked for ${formattedDate} at ${formattedTime}.`,
				type: 'APPOINTMENT_CONFIRMATION'
			});

			notifyPatientQueueUpdate(req.user.id, {
				type: 'notification',
				notification
			});
		} catch (notifErr) {
			console.error('Failed to create appointment confirmation notification:', notifErr);
		}

		res.status(201).json({ appointment: populatedApp });
	} catch (error) {
		if (error.code === DUPLICATE_KEY) {
			return res.status(409).json({ message: 'That time was just booked by someone else. Pick another slot.' });
		}
		next(error);
	}
}

// `scope` splits the history: upcoming = still booked and in the future,
// past = everything else (attended, cancelled, or simply gone by).
async function listMine(req, res, next) {
	try {
		const { scope, status } = req.query;
		const filter = { patient: req.user.id };
		if (status) {
			if (!['booked', 'cancelled', 'completed'].includes(status)) {
				return res.status(400).json({ message: 'Invalid status filter' });
			}
			filter.status = status;
		}
		if (scope === 'upcoming') {
			filter.status = 'booked';
			filter.scheduledAt = { $gte: new Date() };
		} else if (scope === 'past') {
			filter.$or = [{ status: { $ne: 'booked' } }, { scheduledAt: { $lt: new Date() } }];
		} else if (scope) {
			return res.status(400).json({ message: 'Invalid scope filter' });
		}
		const appointments = await Appointment.find(filter)
			.populate(POPULATE)
			.sort({ scheduledAt: scope === 'past' ? -1 : 1 });
		res.json({ appointments });
	} catch (error) { next(error); }
}

async function get(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid appointment id' });
		const appointment = await Appointment.findOne({ _id: req.params.id, patient: req.user.id }).populate(POPULATE);
		if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
		res.json({ appointment });
	} catch (error) { next(error); }
}

async function cancel(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid appointment id' });
		const appointment = await Appointment.findOne({ _id: req.params.id, patient: req.user.id });
		if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
		if (appointment.status === 'cancelled') return res.status(409).json({ message: 'This appointment is already cancelled' });
		if (appointment.status === 'completed') return res.status(409).json({ message: 'A completed appointment cannot be cancelled' });
		if (appointment.scheduledAt <= new Date()) return res.status(409).json({ message: 'This appointment has already passed' });
		appointment.status = 'cancelled';
		appointment.cancelledAt = new Date();
		await appointment.save();

		const populatedApp = await appointment.populate(POPULATE);

		// Create in-app cancellation notification
		try {
			const doctorName = populatedApp.doctor?.name || 'Doctor';
			const notification = await Notification.create({
				userId: req.user.id,
				appointmentId: appointment._id,
				title: 'Appointment Cancelled',
				message: `Your appointment with Dr. ${doctorName} has been cancelled.`,
				type: 'APPOINTMENT_CANCELLED'
			});

			notifyPatientQueueUpdate(req.user.id, {
				type: 'notification',
				notification
			});
		} catch (notifErr) {
			console.error('Failed to create cancellation notification:', notifErr);
		}

		res.json({ appointment: populatedApp });
	} catch (error) { next(error); }
}

async function reschedule(req, res, next) {
	try {
		if (!isObjectId(req.params.id)) return res.status(400).json({ message: 'Invalid appointment id' });
		const when = new Date(req.body.scheduledAt);
		if (!req.body.scheduledAt || Number.isNaN(when.getTime())) {
			return res.status(400).json({ message: 'A new appointment time is required' });
		}
		const appointment = await Appointment.findOne({ _id: req.params.id, patient: req.user.id });
		if (!appointment) return res.status(404).json({ message: 'Appointment not found' });
		if (appointment.status !== 'booked') return res.status(409).json({ message: 'Only a booked appointment can be rescheduled' });
		if (appointment.scheduledAt <= new Date()) return res.status(409).json({ message: 'This appointment has already passed' });
		if (appointment.scheduledAt.getTime() === when.getTime()) {
			return res.status(400).json({ message: 'Pick a different time to reschedule' });
		}
		const doctor = await Doctor.findOne({ _id: appointment.doctor, active: true });
		if (!doctor) return res.status(404).json({ message: 'Doctor is no longer available' });
		if (!(await assertSlotIsOpen(doctor, when, appointment._id))) {
			return res.status(409).json({ message: 'That time is no longer available. Pick another slot.' });
		}
		appointment.rescheduledFrom = appointment.scheduledAt;
		appointment.scheduledAt = when;
		await appointment.save();

		const populatedApp = await appointment.populate(POPULATE);

		// Create in-app reschedule notification
		try {
			const formattedDate = new Date(when).toLocaleDateString('en-US', {
				month: 'short',
				day: 'numeric',
				year: 'numeric'
			});
			const formattedTime = new Date(when).toLocaleTimeString('en-US', {
				hour: '2-digit',
				minute: '2-digit'
			});
			const doctorName = doctor.name || 'Doctor';

			const notification = await Notification.create({
				userId: req.user.id,
				appointmentId: appointment._id,
				title: 'Appointment Rescheduled 🗓️',
				message: `Your appointment with Dr. ${doctorName} has been rescheduled to ${formattedDate} at ${formattedTime}.`,
				type: 'APPOINTMENT_RESCHEDULED'
			});

			notifyPatientQueueUpdate(req.user.id, {
				type: 'notification',
				notification
			});
		} catch (notifErr) {
			console.error('Failed to create reschedule notification:', notifErr);
		}

		res.json({ appointment: populatedApp });
	} catch (error) {
		if (error.code === DUPLICATE_KEY) {
			return res.status(409).json({ message: 'That time was just booked by someone else. Pick another slot.' });
		}
		next(error);
	}
}

module.exports = { create, listMine, get, cancel, reschedule };
