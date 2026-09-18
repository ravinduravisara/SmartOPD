require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const connectDatabase = require('../config/db');
const User = require('../models/User');
const { validateAdmin, createAdmin } = require('../services/adminService');

async function main() {
  const details = { name: process.env.ADMIN_NAME, email: process.env.ADMIN_EMAIL, password: process.env.ADMIN_PASSWORD };
  const error = validateAdmin(details);
  if (error) throw new Error(`Set ADMIN_NAME, ADMIN_EMAIL and ADMIN_PASSWORD in backend/.env. ${error}`);
  await connectDatabase();
  if (await User.exists({ role: 'admin' })) throw new Error('An administrator already exists. Log in and use Create admin on the dashboard.');
  await createAdmin(details);
  console.log(`Administrator created: ${details.email.trim().toLowerCase()}. Log in using the password you configured.`);
}

main().catch((error) => {
  console.error(error.code === 11000 ? 'This email already belongs to an account. Choose a different email.' : error.message);
  process.exitCode = 1;
}).finally(() => mongoose.disconnect());
