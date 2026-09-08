const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
	name: { type: String, required: true, trim: true, maxlength: 100 },
	email: { type: String, required: true, unique: true, lowercase: true, trim: true },
	phone: { type: String, trim: true, maxlength: 20 },
	password: { type: String, required: true, select: false },
	role: { type: String, enum: ['patient', 'doctor', 'admin'], default: 'patient' },
	isEmailVerified: { type: Boolean, default: false },
	tokenVersion: { type: Number, default: 0 },
	dateOfBirth: Date,
	gender: { type: String, enum: ['male', 'female', 'other', 'prefer_not_to_say'] },
	verificationCodeHash: { type: String, select: false },
	verificationCodeExpires: { type: Date, select: false },
	verificationAttempts: { type: Number, select: false, default: 0 },
	resetCodeHash: { type: String, select: false },
	resetCodeExpires: { type: Date, select: false },
	resetAttempts: { type: Number, select: false, default: 0 }
}, { timestamps: true });

module.exports = mongoose.model('User', userSchema);
