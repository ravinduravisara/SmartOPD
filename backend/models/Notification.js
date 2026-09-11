const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
	userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
	title: { type: String, required: true },
	message: { type: String, required: true },
	type: {
		type: String,
		enum: ['QUEUE_CONFIRMATION', 'PROGRESS', 'APPROACHING_TURN', 'YOURE_NEXT', 'YOUR_TURN', 'DELAY', 'COMPLETED', 'APPOINTMENT_REMINDER', 'APPOINTMENT_CONFIRMATION', 'APPOINTMENT_CANCELLED', 'APPOINTMENT_RESCHEDULED'],
		required: true
	},
	readStatus: { type: Boolean, default: false, index: true },
	queueId: { type: mongoose.Schema.Types.ObjectId, ref: 'Queue', default: null },
	appointmentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Appointment', default: null }
}, { timestamps: true });

notificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
