const mongoose = require('mongoose');

const appointmentSchema = new mongoose.Schema({
	patient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
	dependent: { type: mongoose.Schema.Types.ObjectId, ref: 'Dependent', default: null },
	doctor: { type: mongoose.Schema.Types.ObjectId, ref: 'Doctor', required: true, index: true },
	// Kept alongside the doctor so past appointments still read correctly if a
	// doctor later moves to another hospital or department.
	hospital: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', required: true },
	department: { type: mongoose.Schema.Types.ObjectId, ref: 'Department', required: true },
	scheduledAt: { type: Date, required: true },
	durationMinutes: { type: Number, min: 5, max: 120, default: 30 },
	reason: { type: String, trim: true, maxlength: 500 },
	status: { type: String, enum: ['booked', 'cancelled', 'completed'], default: 'booked', index: true },
	cancelledAt: { type: Date, default: null },
	rescheduledFrom: { type: Date, default: null }
}, { timestamps: true });

// Blocks two live bookings landing on the same doctor and time. Cancelled rows
// are excluded so a freed slot can be booked again.
appointmentSchema.index(
	{ doctor: 1, scheduledAt: 1 },
	{ unique: true, partialFilterExpression: { status: 'booked' } }
);

module.exports = mongoose.model('Appointment', appointmentSchema);
