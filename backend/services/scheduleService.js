const Appointment = require('../models/Appointment');

const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function minutesOf(time) {
	const [hours, minutes] = time.split(':').map(Number);
	return hours * 60 + minutes;
}

// "2026-03-04" + 570 -> a Date at 09:30 that day in the server's timezone.
function dateAt(day, minutes) {
	const [year, month, date] = day.split('-').map(Number);
	return new Date(year, month - 1, date, Math.floor(minutes / 60), minutes % 60, 0, 0);
}

function isValidDay(day) {
	if (!DATE_PATTERN.test(String(day || ''))) return false;
	const parsed = dateAt(day, 0);
	return !Number.isNaN(parsed.getTime()) && parsed.getDate() === Number(day.slice(8, 10));
}

// Every slot the doctor's weekly availability produces for one day, before
// booked slots are removed.
function slotsForDay(doctor, day) {
	const weekday = dateAt(day, 0).getDay();
	const step = doctor.slotMinutes || 30;
	const slots = [];
	for (const block of doctor.availability || []) {
		if (block.dayOfWeek !== weekday) continue;
		const end = minutesOf(block.endTime);
		for (let start = minutesOf(block.startTime); start + step <= end; start += step) {
			slots.push(dateAt(day, start));
		}
	}
	return slots.sort((a, b) => a - b);
}

// Bookable slots: on the schedule, not already taken, and not in the past.
// `ignoreAppointmentId` lets a reschedule keep its own current slot in the list.
async function availableSlots(doctor, day, { ignoreAppointmentId = null } = {}) {
	const slots = slotsForDay(doctor, day);
	if (!slots.length) return [];
	const query = {
		doctor: doctor._id,
		status: 'booked',
		scheduledAt: { $gte: slots[0], $lte: slots[slots.length - 1] }
	};
	if (ignoreAppointmentId) query._id = { $ne: ignoreAppointmentId };
	const taken = new Set(
		(await Appointment.find(query).select('scheduledAt').lean())
			.map((row) => row.scheduledAt.getTime())
	);
	const now = Date.now();
	return slots.filter((slot) => slot.getTime() > now && !taken.has(slot.getTime()));
}

// A doctor's weekly pattern, ready to render on a profile screen.
function weeklySchedule(doctor) {
	return (doctor.availability || [])
		.slice()
		.sort((a, b) => a.dayOfWeek - b.dayOfWeek || a.startTime.localeCompare(b.startTime))
		.map((block) => ({
			dayOfWeek: block.dayOfWeek,
			day: DAY_NAMES[block.dayOfWeek],
			startTime: block.startTime,
			endTime: block.endTime
		}));
}

module.exports = { availableSlots, slotsForDay, weeklySchedule, isValidDay, DAY_NAMES };
