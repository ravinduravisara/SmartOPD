const mongoose = require('mongoose');

const hospitalSchema = new mongoose.Schema({
	name: { type: String, required: true, trim: true, maxlength: 120 },
	city: { type: String, required: true, trim: true, maxlength: 80, index: true },
	address: { type: String, trim: true, maxlength: 240 },
	phone: { type: String, trim: true, maxlength: 20 },
	about: { type: String, trim: true, maxlength: 600 },
	lat: { type: Number },
	lng: { type: Number },
	active: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.model('Hospital', hospitalSchema);
