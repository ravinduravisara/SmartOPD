const mongoose = require('mongoose');

const auditLogSchema = new mongoose.Schema({
	actor: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
	action: { type: String, required: true, enum: ['CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'SECURITY'], index: true },
	module: { type: String, required: true, trim: true, maxlength: 80, index: true },
	description: { type: String, required: true, trim: true, maxlength: 300 },
	method: { type: String, required: true, maxlength: 10 },
	path: { type: String, required: true, maxlength: 200 },
	statusCode: { type: Number, required: true },
	success: { type: Boolean, required: true, default: true, index: true },
	seen: { type: Boolean, default: false, index: true },
	seenAt: { type: Date, default: null },
	seenBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
	metadata: { type: mongoose.Schema.Types.Mixed, default: null },
}, { timestamps: true });

auditLogSchema.index({ createdAt: -1 });

module.exports = mongoose.model('AuditLog', auditLogSchema);
