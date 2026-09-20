const mongoose = require('mongoose');

// Registered city names. A city can exist here before its first hospital, and
// hospitals keep storing the name as a plain string, so admin lists are the
// union of this collection and the distinct Hospital.city values.
const citySchema = new mongoose.Schema({
	name: { type: String, required: true, trim: true, maxlength: 80, unique: true }
}, { timestamps: true });

module.exports = mongoose.model('City', citySchema);
