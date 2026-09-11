const Appointment = require('../models/Appointment');
const Notification = require('../models/Notification');
const { notifyPatientQueueUpdate } = require('./socketService');

// Interval for checking (runs every 5 minutes)
const CHECK_INTERVAL_MS = 5 * 60 * 1000;
// Send reminder this many minutes before appointment
const REMINDER_WINDOW_MINUTES = 30;

let reminderInterval = null;

/**
 * Checks for upcoming appointments and sends reminder notifications.
 * Looks for appointments scheduled within the next 30 minutes that
 * haven't already received a reminder.
 */
async function checkAndSendReminders() {
	try {
		const now = new Date();
		const windowEnd = new Date(now.getTime() + REMINDER_WINDOW_MINUTES * 60 * 1000);

		// Find booked appointments in the next 30 minutes
		const upcomingAppointments = await Appointment.find({
			status: 'booked',
			scheduledAt: { $gte: now, $lte: windowEnd }
		})
		.populate('doctor', 'name')
		.populate('hospital', 'name')
		.populate('department', 'name');

		for (const appt of upcomingAppointments) {
			const userId = appt.patient;
			const doctorName = appt.doctor?.name || 'your doctor';
			const hospitalName = appt.hospital?.name || 'the hospital';
			const deptName = appt.department?.name || 'OPD';

			// Calculate minutes until appointment
			const minsUntil = Math.round((appt.scheduledAt.getTime() - now.getTime()) / 60000);

			// Check if we already sent a reminder for this appointment
			const existingReminder = await Notification.findOne({
				userId,
				type: 'APPOINTMENT_REMINDER',
				// Use message content to match the specific appointment
				message: { $regex: appt._id.toString() },
				createdAt: { $gte: new Date(now.getTime() - 60 * 60 * 1000) } // within last hour
			});

			if (existingReminder) continue;

			// Create and send reminder notification
			const notification = await Notification.create({
				userId,
				title: 'Appointment Reminder ⏰',
				message: `Your appointment with ${doctorName} (${deptName}) at ${hospitalName} is in ~${minsUntil} minutes. Please head to the hospital and check in when you arrive! [appt:${appt._id}]`,
				type: 'APPOINTMENT_REMINDER'
			});

			// Push via socket if patient is connected
			notifyPatientQueueUpdate(userId, {
				type: 'notification',
				notification
			});

			console.log(`Sent appointment reminder to patient ${userId} for appointment in ~${minsUntil} mins`);
		}
	} catch (err) {
		console.error('Error checking appointment reminders:', err.message);
	}
}

/**
 * Start the appointment reminder scheduler.
 * Should be called once when the server starts and the database is connected.
 */
function startReminderScheduler() {
	if (reminderInterval) return;

	console.log('Appointment reminder scheduler started (checking every 5 minutes)');

	// Run immediately on start, then every 5 minutes
	checkAndSendReminders();
	reminderInterval = setInterval(checkAndSendReminders, CHECK_INTERVAL_MS);
}

/**
 * Stop the reminder scheduler (for clean shutdown).
 */
function stopReminderScheduler() {
	if (reminderInterval) {
		clearInterval(reminderInterval);
		reminderInterval = null;
	}
}

module.exports = { startReminderScheduler, stopReminderScheduler, checkAndSendReminders };
