const mongoose = require('mongoose');

// Limits mirror the mongoose schemas so a bad payload is rejected with a clear
// message instead of a cast/validation error from the driver.
const TIME_PATTERN = /^([01]\d|2[0-3]):[0-5]\d$/;
const LAST_DAY = 6;

const escapeRegex = (value) => String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const isObjectId = (value) => mongoose.Types.ObjectId.isValid(value);
// "Colombo" and "colombo" are the same city, so names match exactly but case-insensitively.
const exactRegex = (value) => new RegExp(`^${escapeRegex(String(value).trim())}$`, 'i');
const minutesOf = (time) => Number(time.slice(0, 2)) * 60 + Number(time.slice(3, 5));

function requiredText(value, max, label) {
	if (typeof value !== 'string' || !value.trim()) return `${label} is required`;
	if (value.trim().length > max) return `${label} must be ${max} characters or fewer`;
	return null;
}

function optionalText(value, max, label) {
	if (value === undefined || value === null || value === '') return null;
	if (typeof value !== 'string') return `${label} must be text`;
	if (value.trim().length > max) return `${label} must be ${max} characters or fewer`;
	return null;
}

function optionalNumber(value, min, max, label) {
	if (value === undefined || value === null || value === '') return null;
	const parsed = typeof value === 'number' ? value : Number(value);
	if (!Number.isFinite(parsed)) return `${label} must be a number`;
	if (parsed < min || parsed > max) return `${label} must be between ${min} and ${max}`;
	return null;
}

function optionalFlag(value, label) {
	if (value === undefined || value === null) return null;
	if (typeof value !== 'boolean') return `${label} must be true or false`;
	return null;
}

function requiredId(value, label) {
	if (value === undefined || value === null || value === '') return `${label} is required`;
	if (!isObjectId(value)) return `${label} is not a valid id`;
	return null;
}

function validateAvailability(availability) {
	if (availability === undefined || availability === null) return null;
	if (!Array.isArray(availability)) return 'Availability must be a list of time blocks';
	for (const block of availability) {
		if (!block || typeof block !== 'object' || Array.isArray(block)) return 'Each availability block needs dayOfWeek, startTime and endTime';
		const day = typeof block.dayOfWeek === 'number' ? block.dayOfWeek : Number(block.dayOfWeek);
		if (!Number.isInteger(day) || day < 0 || day > LAST_DAY) return 'Availability dayOfWeek must be a whole number from 0 (Sunday) to 6 (Saturday)';
		if (typeof block.startTime !== 'string' || !TIME_PATTERN.test(block.startTime)) return 'Availability startTime must be a 24-hour time such as 09:00';
		if (typeof block.endTime !== 'string' || !TIME_PATTERN.test(block.endTime)) return 'Availability endTime must be a 24-hour time such as 17:30';
		if (minutesOf(block.endTime) <= minutesOf(block.startTime)) return 'Availability endTime must be later than startTime';
	}
	return null;
}

// Each validator takes a complete record - PATCH handlers merge the stored row
// with the request body first - and returns an error message or null.
function validateCity({ name } = {}) {
	return requiredText(name, 80, 'City name');
}

function validateHospital({ name, city, address, phone, about, active } = {}) {
	return requiredText(name, 120, 'Hospital name')
		|| requiredText(city, 80, 'City')
		|| optionalText(address, 240, 'Address')
		|| optionalText(phone, 20, 'Phone')
		|| optionalText(about, 600, 'About')
		|| optionalFlag(active, 'Active');
}

function validateDepartment({ hospital, name, description } = {}) {
	return requiredId(hospital, 'Hospital')
		|| requiredText(name, 100, 'Department name')
		|| optionalText(description, 400, 'Description');
}

function validateDoctor(doctor = {}) {
	return requiredText(doctor.name, 120, 'Doctor name')
		|| requiredText(doctor.specialization, 100, 'Specialization')
		|| requiredId(doctor.hospital, 'Hospital')
		|| requiredId(doctor.department, 'Department')
		|| optionalText(doctor.qualifications, 200, 'Qualifications')
		|| optionalNumber(doctor.experienceYears, 0, 70, 'Years of experience')
		|| optionalNumber(doctor.consultationFee, 0, Number.MAX_SAFE_INTEGER, 'Consultation fee')
		|| optionalText(doctor.about, 600, 'About')
		|| optionalNumber(doctor.slotMinutes, 5, 120, 'Slot length in minutes')
		|| optionalFlag(doctor.active, 'Active')
		|| validateAvailability(doctor.availability);
}

// Drops anything the schema would ignore and coerces the numeric day, so a
// body sent as strings still stores cleanly.
function normalizeAvailability(availability) {
	if (!Array.isArray(availability)) return [];
	return availability.map((block) => ({
		dayOfWeek: Number(block.dayOfWeek),
		startTime: block.startTime,
		endTime: block.endTime
	}));
}

function hospitalRef(hospital) {
	if (!hospital) return null;
	if (!hospital.name) return { id: String(hospital._id || hospital), name: '', city: '' };
	return { id: String(hospital._id), name: hospital.name, city: hospital.city };
}

function citySummary(name, hospitalCount = 0) {
	return { name, hospitalCount };
}

function hospitalSummary(hospital, counts = {}) {
	return {
		id: String(hospital._id),
		name: hospital.name,
		city: hospital.city,
		address: hospital.address || '',
		phone: hospital.phone || '',
		about: hospital.about || '',
		active: hospital.active !== false,
		departmentCount: counts.departmentCount || 0,
		doctorCount: counts.doctorCount || 0
	};
}

function departmentSummary(department, doctorCount = 0) {
	return {
		id: String(department._id),
		name: department.name,
		description: department.description || '',
		hospital: hospitalRef(department.hospital),
		doctorCount
	};
}

function doctorSummary(doctor) {
	return {
		id: String(doctor._id),
		name: doctor.name,
		specialization: doctor.specialization,
		qualifications: doctor.qualifications || '',
		experienceYears: doctor.experienceYears || 0,
		consultationFee: doctor.consultationFee || 0,
		about: doctor.about || '',
		slotMinutes: doctor.slotMinutes || 30,
		active: doctor.active !== false,
		availability: (doctor.availability || []).map((block) => ({
			dayOfWeek: block.dayOfWeek,
			startTime: block.startTime,
			endTime: block.endTime
		})),
		hospital: hospitalRef(doctor.hospital),
		department: doctor.department ? { id: String(doctor.department._id || doctor.department), name: doctor.department.name || '' } : null
	};
}

module.exports = {
	escapeRegex,
	exactRegex,
	isObjectId,
	normalizeAvailability,
	validateCity,
	validateHospital,
	validateDepartment,
	validateDoctor,
	citySummary,
	hospitalSummary,
	departmentSummary,
	doctorSummary
};
