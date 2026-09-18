const bcrypt = require('bcryptjs');
const User = require('../models/User');

function validateAdmin({ name, email, password } = {}) {
  if (typeof name !== 'string' || !name.trim() || name.trim().length > 100) return 'Name is required and must be 100 characters or fewer';
  if (typeof email !== 'string' || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return 'Enter a valid email address';
  if (typeof password !== 'string' || password.length < 8 || password.length > 128 || !/[A-Z]/.test(password) || !/[a-z]/.test(password) || !/\d/.test(password) || !/[^A-Za-z0-9]/.test(password)) return 'Password must be 8-128 characters and include uppercase, lowercase, number and symbol';
  return null;
}

async function createAdmin({ name, email, password }) {
  // Always insert a new account. Never promote or overwrite an existing patient.
  return User.create({ name: name.trim(), email: email.trim().toLowerCase(), password: await bcrypt.hash(password, 12), role: 'admin', isEmailVerified: true });
}

function adminSummary(user) {
  return { id: user._id, name: user.name, email: user.email, role: user.role, createdAt: user.createdAt };
}

module.exports = { validateAdmin, createAdmin, adminSummary };
