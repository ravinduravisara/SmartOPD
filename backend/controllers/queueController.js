const Queue = require('../models/Queue');
const Appointment = require('../models/Appointment');
const Hospital = require('../models/Hospital');
const Doctor = require('../models/Doctor');
const { sendQueueNotification } = require('../services/notificationService');
const { notifyDoctorQueueUpdate, notifyPatientQueueUpdate } = require('../services/socketService');

// Helper to calculate patients ahead and ETA
async function calculateQueueMetrics(queueEntry) {
	const activeStatuses = ['CHECKED_IN', 'WAITING'];
	
	// Count active queue entries ahead of this entry for the same doctor/date
	const startOfDay = new Date(queueEntry.createdAt);
	startOfDay.setHours(0, 0, 0, 0);

	const endOfDay = new Date(queueEntry.createdAt);
	endOfDay.setHours(23, 59, 59, 999);

	const patientsAhead = await Queue.countDocuments({
		doctorId: queueEntry.doctorId,
		status: { $in: activeStatuses },
		queuePosition: { $lt: queueEntry.queuePosition },
		createdAt: { $gte: startOfDay, $lte: endOfDay }
	});

	// Find token currently being called or in consultation
	const currentlyServing = await Queue.findOne({
		doctorId: queueEntry.doctorId,
		status: { $in: ['CALLED', 'IN_CONSULTATION'] },
		createdAt: { $gte: startOfDay, $lte: endOfDay }
	}).sort({ updatedAt: -1 });

	// Calculate average consultation duration today (default 6 mins)
	const completedToday = await Queue.find({
		doctorId: queueEntry.doctorId,
		status: 'COMPLETED',
		createdAt: { $gte: startOfDay, $lte: endOfDay },
		startedAt: { $ne: null },
		completedAt: { $ne: null }
	});

	let avgConsultationMinutes = 6;
	if (completedToday.length > 0) {
		const totalDuration = completedToday.reduce((sum, item) => {
			const mins = (item.completedAt - item.startedAt) / 60000;
			return sum + (mins > 0 ? mins : 6);
		}, 0);
		avgConsultationMinutes = Math.max(3, Math.round(totalDuration / completedToday.length));
	}

	const estimatedWaitMinutes = Math.max(0, patientsAhead * avgConsultationMinutes);

	// Congestion status
	let congestion = 'Low Queue';
	if (patientsAhead > 10) congestion = 'Busy Queue';
	else if (patientsAhead > 4) congestion = 'Moderate Queue';

	// Delay detection: check if currently serving has taken over 15 mins
	let isDelayed = false;
	let delayMessage = null;
	if (currentlyServing && currentlyServing.calledAt) {
		const minsInCall = (Date.now() - new Date(currentlyServing.calledAt).getTime()) / 60000;
		if (minsInCall > avgConsultationMinutes * 2.5) {
			isDelayed = true;
			delayMessage = 'Doctor is currently taking longer than usual.';
		}
	}

	return {
		patientsAhead,
		currentToken: currentlyServing ? currentlyServing.tokenNumber : 'None',
		estimatedWaitMinutes,
		congestion,
		isDelayed,
		delayMessage,
		avgConsultationMinutes
	};
}

// Check-in & generate token
exports.checkIn = async (req, res) => {
	try {
		const { appointmentId } = req.body;

		const appointment = await Appointment.findById(appointmentId);
		if (!appointment) {
			return res.status(404).json({ message: 'Appointment not found' });
		}

		const patientId = (req.userRecord && req.userRecord._id) || (req.user && (req.user._id || req.user.id)) || appointment.patient || appointment.patientId;

		// Ensure patient owns appointment safely
		if (appointment.patient && patientId && appointment.patient.toString() !== patientId.toString()) {
			return res.status(403).json({ message: 'Unauthorized appointment check-in' });
		}

		// Ensure check-in is only allowed on the appointment date
		const apptDate = new Date(appointment.scheduledAt);
		const today = new Date();
		const isSameDay = apptDate.getFullYear() === today.getFullYear() &&
			apptDate.getMonth() === today.getMonth() &&
			apptDate.getDate() === today.getDate();

		if (!isSameDay) {
			const formattedApptDate = apptDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
			return res.status(400).json({
				message: `Check-in is only allowed on the day of your appointment (${formattedApptDate}).`
			});
		}

		// Check if queue entry already exists
		let queueEntry = await Queue.findOne({ appointmentId });
		if (queueEntry) {
			if (queueEntry.status === 'WAITING') {
				queueEntry.status = 'CHECKED_IN';
				queueEntry.checkInTime = new Date();
				await queueEntry.save();
			}
		} else {
			// Generate token number e.g. A-027
			const startOfDay = new Date();
			startOfDay.setHours(0, 0, 0, 0);

			const hospitalId = appointment.hospital || '6aa17de6a16ec95c9650760c';
			const doctorId = appointment.doctor || '6aa17de6a16ec95c9650760e';
			const departmentId = appointment.department || '6aa17de6a16ec95c9650760d';

			const count = await Queue.countDocuments({
				doctorId,
				createdAt: { $gte: startOfDay }
			});

			const tokenSeq = (count + 1).toString().padStart(3, '0');
			const tokenNumber = `A-${tokenSeq}`;

			const pId = (req.userRecord && req.userRecord._id) ? req.userRecord._id : (appointment.patient || (req.user && (req.user._id || req.user.id)));

			queueEntry = await Queue.create({
				appointmentId: appointment._id,
				patientId: pId,
				hospitalId,
				departmentId,
				doctorId,
				tokenNumber,
				queuePosition: count + 1,
				status: 'CHECKED_IN',
				checkInTime: new Date()
			});
		}

		const metrics = await calculateQueueMetrics(queueEntry);

		// Send notification
		await sendQueueNotification({
			userId: patientId,
			queueId: queueEntry._id,
			title: 'Check-in Confirmed',
			message: `Your queue token ${queueEntry.tokenNumber} is confirmed. ${metrics.patientsAhead} patients ahead.`,
			type: 'QUEUE_CONFIRMATION'
		});

		if (queueEntry.doctorId) {
			notifyDoctorQueueUpdate(queueEntry.doctorId.toString(), { action: 'check_in', queueId: queueEntry._id });
		}

		res.json({
			success: true,
			data: {
				queue: queueEntry,
				metrics
			}
		});
	} catch (err) {
		console.error('Check-In Error Details:', err);
		res.status(500).json({ message: 'Error checking into queue', error: err.message });
	}
};

// Get active queue for patient
exports.getActivePatientQueue = async (req, res) => {
	try {
		const patientId = (req.userRecord && req.userRecord._id) || (req.user && (req.user._id || req.user.id));

		const activeQueue = await Queue.findOne({
			patientId,
			status: { $in: ['CHECKED_IN', 'WAITING', 'CALLED', 'IN_CONSULTATION'] }
		})
		.sort({ updatedAt: -1 })
		.populate('hospitalId', 'name address')
		.populate('departmentId', 'name')
		.populate('doctorId', 'name specialization roomNumber');

		if (!activeQueue) {
			return res.json({ success: true, data: null });
		}

		const metrics = await calculateQueueMetrics(activeQueue);

		// Smart notification logic triggers
		if (metrics.patientsAhead === 1 && activeQueue.status === 'CHECKED_IN') {
			await sendQueueNotification({
				userId: patientId,
				queueId: activeQueue._id,
				title: "You're Next!",
				message: `Please stay ready near the consultation area. Only 1 patient ahead.`,
				type: 'YOURE_NEXT'
			});
		} else if (metrics.patientsAhead === 2 || metrics.patientsAhead === 3) {
			await sendQueueNotification({
				userId: patientId,
				queueId: activeQueue._id,
				title: 'Turn Approaching',
				message: `Your turn is approaching. ${metrics.patientsAhead} patients ahead.`,
				type: 'APPROACHING_TURN'
			});
		}

		if (metrics.isDelayed) {
			await sendQueueNotification({
				userId: patientId,
				queueId: activeQueue._id,
				title: 'Queue Delay Alert',
				message: metrics.delayMessage,
				type: 'DELAY'
			});
		}

		res.json({
			success: true,
			data: {
				queue: activeQueue,
				metrics
			}
		});
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error fetching active queue' });
	}
};

// Get patient queue history
exports.getPatientQueueHistory = async (req, res) => {
	try {
		const patientId = req.user._id;

		const history = await Queue.find({
			patientId,
			status: { $in: ['COMPLETED', 'CANCELLED', 'SKIPPED', 'NO_SHOW'] }
		})
		.populate('hospitalId', 'name')
		.populate('departmentId', 'name')
		.populate('doctorId', 'name')
		.sort({ updatedAt: -1 });

		res.json({ success: true, data: history });
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error fetching queue history' });
	}
};

// Staff Call Next Patient
exports.callNextToken = async (req, res) => {
	try {
		const { doctorId } = req.body;

		const startOfDay = new Date();
		startOfDay.setHours(0, 0, 0, 0);

		// Complete any currently called/in_consultation entry if requested
		const nextInQueue = await Queue.findOne({
			doctorId,
			status: { $in: ['CHECKED_IN', 'WAITING'] },
			createdAt: { $gte: startOfDay }
		}).sort({ queuePosition: 1 });

		if (!nextInQueue) {
			return res.status(404).json({ message: 'No patients waiting in queue' });
		}

		nextInQueue.status = 'CALLED';
		nextInQueue.calledAt = new Date();
		await nextInQueue.save();

		await sendQueueNotification({
			userId: nextInQueue.patientId,
			queueId: nextInQueue._id,
			title: 'YOUR TURN!',
			message: `Token ${nextInQueue.tokenNumber} is called! Please proceed to the consultation room.`,
			type: 'YOUR_TURN'
		});

		notifyDoctorQueueUpdate(doctorId, { action: 'token_called', tokenNumber: nextInQueue.tokenNumber });
		notifyPatientQueueUpdate(nextInQueue.patientId, { action: 'your_turn', queue: nextInQueue });

		res.json({ success: true, data: nextInQueue });
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error calling next patient' });
	}
};

// Staff Skip Patient
exports.skipToken = async (req, res) => {
	try {
		const { queueId } = req.body;
		const queue = await Queue.findById(queueId);
		if (!queue) return res.status(404).json({ message: 'Queue record not found' });

		queue.status = 'SKIPPED';
		await queue.save();

		notifyDoctorQueueUpdate(queue.doctorId, { action: 'patient_skipped', queueId });
		notifyPatientQueueUpdate(queue.patientId, { action: 'skipped', queue });

		res.json({ success: true, data: queue });
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error skipping patient' });
	}
};

// Staff Complete Consultation
exports.completeConsultation = async (req, res) => {
	try {
		const { queueId } = req.body;
		const queue = await Queue.findById(queueId);
		if (!queue) return res.status(404).json({ message: 'Queue record not found' });

		queue.status = 'COMPLETED';
		queue.completedAt = new Date();
		await queue.save();

		await sendQueueNotification({
			userId: queue.patientId,
			queueId: queue._id,
			title: 'Consultation Completed',
			message: `Your consultation for token ${queue.tokenNumber} is completed. Thank you!`,
			type: 'COMPLETED'
		});

		notifyDoctorQueueUpdate(queue.doctorId, { action: 'consultation_completed', queueId });
		notifyPatientQueueUpdate(queue.patientId, { action: 'completed', queue });

		res.json({ success: true, data: queue });
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error completing consultation' });
	}
};

// Staff Mark No-Show
exports.markNoShow = async (req, res) => {
	try {
		const { queueId } = req.body;
		const queue = await Queue.findById(queueId);
		if (!queue) return res.status(404).json({ message: 'Queue record not found' });

		queue.status = 'NO_SHOW';
		await queue.save();

		notifyDoctorQueueUpdate(queue.doctorId, { action: 'no_show', queueId });
		notifyPatientQueueUpdate(queue.patientId, { action: 'no_show', queue });

		res.json({ success: true, data: queue });
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error marking no-show' });
	}
};

// Nearby Hospital Discovery & Live Queue Comparison using Real GPS Location
exports.getNearbyHospitals = async (req, res) => {
	try {
		// Default to Colombo GPS coordinates if browser location is unavailable
		const userLat = parseFloat(req.query.lat) || 6.9271;
		const userLng = parseFloat(req.query.lng) || 79.8612;

		const hospitals = await Hospital.find({ active: true }).lean();
		const startOfDay = new Date();
		startOfDay.setHours(0, 0, 0, 0);

		const results = await Promise.all(hospitals.map(async (h) => {
			const activeWaitingCount = await Queue.countDocuments({
				hospitalId: h._id,
				status: { $in: ['CHECKED_IN', 'WAITING'] },
				createdAt: { $gte: startOfDay }
			});

			const estWaitMinutes = activeWaitingCount * 5;
			
			// Haversine formula for exact distance between user GPS and Hospital GPS
			const dLat = (h.lat - userLat) * Math.PI / 180;
			const dLng = (h.lng - userLng) * Math.PI / 180;
			const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
				Math.cos(userLat * Math.PI / 180) * Math.cos(h.lat * Math.PI / 180) *
				Math.sin(dLng / 2) * Math.sin(dLng / 2);
			const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
			const distanceKm = parseFloat((6371 * c).toFixed(1));

			return {
				id: h._id,
				name: h.name,
				city: h.city,
				address: h.address || 'Government Hospital',
				lat: h.lat,
				lng: h.lng,
				distanceKm,
				activeWaitingCount,
				estimatedWaitMinutes: estWaitMinutes,
				isLiveQueueAvailable: true
			};
		}));

		// Sort strictly by nearest distance to current user location
		results.sort((a, b) => a.distanceKm - b.distanceKm);

		res.json({ success: true, data: results });
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error loading nearby hospitals' });
	}
};
