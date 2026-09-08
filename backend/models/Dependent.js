const mongoose = require('mongoose');

const dependentSchema = new mongoose.Schema({
	patient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
	name: { type: String, required: true, trim: true, maxlength: 100 },
	relationship: { type: String, required: true, trim: true, maxlength: 40 },
	dateOfBirth: { type: Date, required: true },
	gender: { type: String, enum: ['male', 'female', 'other', 'prefer_not_to_say'] },
	phone: { type: String, trim: true, maxlength: 20 }
}, { timestamps: true });

module.exports = mongoose.model('Dependent', dependentSchema);
