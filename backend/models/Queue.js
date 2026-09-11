const mongoose = require('mongoose');

const queueSchema = new mongoose.Schema({
	appointmentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Appointment', required: true, index: true },
	patientId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
	hospitalId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', required: true, index: true },
	departmentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Department', required: true, index: true },
	doctorId: { type: mongoose.Schema.Types.ObjectId, ref: 'Doctor', required: true, index: true },
	tokenNumber: { type: String, required: true },
	queuePosition: { type: Number, required: true },
	status: {
		type: String,
		enum: ['WAITING', 'CHECKED_IN', 'CALLED', 'IN_CONSULTATION', 'COMPLETED', 'SKIPPED', 'NO_SHOW', 'CANCELLED'],
		default: 'WAITING',
		index: true
	},
	checkInTime: { type: Date, default: Date.now },
	calledAt: { type: Date, default: null },
	startedAt: { type: Date, default: null },
	completedAt: { type: Date, default: null },
	estimatedWaitTime: { type: Number, default: 0 }, // in minutes
	priority: { type: Number, default: 0 },
	isWalkIn: { type: Boolean, default: false }
}, { timestamps: true });

queueSchema.index({ doctorId: 1, createdAt: 1, status: 1 });
queueSchema.index({ patientId: 1, status: 1 });

module.exports = mongoose.model('Queue', queueSchema);
