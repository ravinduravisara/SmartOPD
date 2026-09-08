const mongoose = require('mongoose');

const appointmentSchema = new mongoose.Schema({
	patient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
	dependent: { type: mongoose.Schema.Types.ObjectId, ref: 'Dependent', default: null },
	doctor: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
	scheduledAt: { type: Date, required: true },
	reason: { type: String, trim: true, maxlength: 500 },
	status: { type: String, enum: ['booked', 'cancelled', 'completed'], default: 'booked' }
}, { timestamps: true });

module.exports = mongoose.model('Appointment', appointmentSchema);
