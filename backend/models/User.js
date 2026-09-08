const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
	name: { type: String, required: true, trim: true, maxlength: 100 },
	email: { type: String, required: true, unique: true, lowercase: true, trim: true },
	phone: { type: String, trim: true, maxlength: 20 },
	password: { type: String, required: true, select: false },
	role: { type: String, enum: ['patient', 'doctor', 'admin'], default: 'patient' },
	dateOfBirth: Date,
	gender: { type: String, enum: ['male', 'female', 'other', 'prefer_not_to_say'] },
	resetPasswordToken: { type: String, select: false },
	resetPasswordExpires: { type: Date, select: false }
}, { timestamps: true });

module.exports = mongoose.model('User', userSchema);
