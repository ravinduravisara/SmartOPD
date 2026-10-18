const bcrypt = require('bcryptjs');
const User = require('../models/User');

const roles = ['patient', 'doctor', 'admin'];

function validateAdmin({ name, email, password } = {}) {
  if (typeof name !== 'string' || !name.trim() || name.trim().length > 100) return 'Name is required and must be 100 characters or fewer';
  if (typeof email !== 'string' || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return 'Enter a valid email address';
  if (typeof password !== 'string' || password.length < 8 || password.length > 128 || !/[A-Z]/.test(password) || !/[a-z]/.test(password) || !/\d/.test(password) || !/[^A-Za-z0-9]/.test(password)) return 'Password must be 8-128 characters and include uppercase, lowercase, number and symbol';
  return null;
}

function validateUser({ name, email, password, role } = {}, { passwordRequired = true } = {}) {
  if (typeof name !== 'string' || !name.trim() || name.trim().length > 100) return 'Name is required and must be 100 characters or fewer';
  if (typeof email !== 'string' || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return 'Enter a valid email address';
  if (role !== undefined && !roles.includes(role)) return 'Role must be patient, doctor or admin';
  if (passwordRequired && (typeof password !== 'string' || password.length < 8 || password.length > 128 || !/[A-Z]/.test(password) || !/[a-z]/.test(password) || !/\d/.test(password) || !/[^A-Za-z0-9]/.test(password))) return 'Password must be 8-128 characters and include uppercase, lowercase, number and symbol';
  if (!passwordRequired && password !== undefined && (typeof password !== 'string' || password.length < 8 || password.length > 128 || !/[A-Z]/.test(password) || !/[a-z]/.test(password) || !/\d/.test(password) || !/[^A-Za-z0-9]/.test(password))) return 'Password must be 8-128 characters and include uppercase, lowercase, number and symbol';
  return null;
}

async function createAdmin({ name, email, password }) {
  // Always insert a new account. Never promote or overwrite an existing patient.
  return User.create({ name: name.trim(), email: email.trim().toLowerCase(), password: await bcrypt.hash(password, 12), role: 'admin', isEmailVerified: true });
}

function adminSummary(user) {
  return userSummary(user);
}

function userSummary(user) {
  const doctor = user.doctorProfile && typeof user.doctorProfile === 'object'
    ? user.doctorProfile
    : null;
  return {
    id: user._id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    role: user.role,
    isEmailVerified: user.isEmailVerified,
    dateOfBirth: user.dateOfBirth,
    gender: user.gender,
    profilePicture: user.profilePicture || null,
    catalogOnly: user.catalogOnly === true,
    doctorProfile: doctor ? {
      id: doctor._id,
      specialization: doctor.specialization,
      hospital: doctor.hospital,
      department: doctor.department
    } : null,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt
  };
}

async function hashPassword(password) {
  return bcrypt.hash(password, 12);
}

module.exports = { roles, validateAdmin, validateUser, createAdmin, hashPassword, adminSummary, userSummary };
