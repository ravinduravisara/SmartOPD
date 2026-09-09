const mongoose = require('mongoose');

// One recurring weekly block, e.g. Monday 09:00-12:00. Times are "HH:MM" in
// the clinic's local time; slots are generated from these on demand.
const availabilitySchema = new mongoose.Schema({
	dayOfWeek: { type: Number, required: true, min: 0, max: 6 },
	startTime: { type: String, required: true, match: /^([01]\d|2[0-3]):[0-5]\d$/ },
	endTime: { type: String, required: true, match: /^([01]\d|2[0-3]):[0-5]\d$/ }
}, { _id: false });

const doctorSchema = new mongoose.Schema({
	name: { type: String, required: true, trim: true, maxlength: 120 },
	specialization: { type: String, required: true, trim: true, maxlength: 100, index: true },
	hospital: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', required: true, index: true },
	department: { type: mongoose.Schema.Types.ObjectId, ref: 'Department', required: true, index: true },
	qualifications: { type: String, trim: true, maxlength: 200 },
	experienceYears: { type: Number, min: 0, max: 70, default: 0 },
	consultationFee: { type: Number, min: 0, default: 0 },
	about: { type: String, trim: true, maxlength: 600 },
	photo: { type: String, maxlength: 2048 },
	availability: { type: [availabilitySchema], default: [] },
	slotMinutes: { type: Number, min: 5, max: 120, default: 30 },
	active: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.model('Doctor', doctorSchema);
