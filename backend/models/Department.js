const mongoose = require('mongoose');

const departmentSchema = new mongoose.Schema({
	hospital: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', required: true, index: true },
	name: { type: String, required: true, trim: true, maxlength: 100 },
	description: { type: String, trim: true, maxlength: 400 }
}, { timestamps: true });

departmentSchema.index({ hospital: 1, name: 1 }, { unique: true });

module.exports = mongoose.model('Department', departmentSchema);
