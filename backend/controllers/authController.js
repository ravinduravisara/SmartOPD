const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { sendOtpEmail, isConfigured: emailConfigured } = require('../services/emailService');

const jwtSecret = () => process.env.JWT_SECRET;
const normalizeEmail = (email) => String(email || '').trim().toLowerCase();
const validEmail = (email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
const validPassword = (password) => typeof password === 'string' && password.length >= 8 && password.length <= 128 && /[A-Z]/.test(password) && /[a-z]/.test(password) && /\d/.test(password) && /[^A-Za-z0-9]/.test(password);
const makeCode = () => String(crypto.randomInt(100000, 1000000));
const hashCode = (code) => crypto.createHash('sha256').update(code).digest('hex');
const codeFields = (code) => ({ hash: hashCode(code), expires: new Date(Date.now() + 10 * 60 * 1000) });

function publicUser(user) {
	return { id: user._id, name: user.name, email: user.email, phone: user.phone, role: user.role, dateOfBirth: user.dateOfBirth, gender: user.gender };
}

function issueToken(user) {
	return jwt.sign({ id: user._id.toString(), role: user.role, tokenVersion: user.tokenVersion }, jwtSecret(), { expiresIn: '1h', issuer: 'smartopd' });
}

async function register(req, res, next) {
	try {
		const { name, password, phone, dateOfBirth, gender } = req.body;
		const email = normalizeEmail(req.body.email);
		if (!name || !email || !password) return res.status(400).json({ message: 'Name, email and password are required' });
		if (!validEmail(email)) return res.status(400).json({ message: 'Enter a valid email address' });
		if (!validPassword(password)) return res.status(400).json({ message: 'Password must be 8-128 characters and include uppercase, lowercase, number and symbol' });
		if (!emailConfigured()) return res.status(503).json({ message: 'Email service is not configured. Set SMTP_USER and SMTP_PASS.' });
		const existing = await User.findOne({ email });
		if (existing?.isEmailVerified) return res.status(409).json({ message: 'An account with this email already exists' });
		const code = makeCode();
		const fields = codeFields(code);
		const user = existing || new User({ email });
		Object.assign(user, { name, email, phone, dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : undefined, gender, password: await bcrypt.hash(password, 12), isEmailVerified: false, verificationCodeHash: fields.hash, verificationCodeExpires: fields.expires, verificationAttempts: 0 });
		await sendOtpEmail({ to: email, code, purpose: 'verification' });
		await user.save();
		return res.status(201).json({ verificationRequired: true, email, message: 'Verification code sent to your email' });
	} catch (error) { next(error); }
}

async function verifyEmail(req, res, next) {
	try {
		const email = normalizeEmail(req.body.email);
		const code = String(req.body.code || '').trim();
		const user = await User.findOne({ email }).select('+verificationCodeHash +verificationCodeExpires +verificationAttempts +tokenVersion');
		if (!user || !user.verificationCodeExpires || user.verificationCodeExpires <= new Date()) return res.status(400).json({ message: 'Verification code is invalid or expired' });
		if (user.verificationAttempts >= 5) return res.status(429).json({ message: 'Too many attempts. Request a new code.' });
		if (hashCode(code) !== user.verificationCodeHash) { user.verificationAttempts += 1; await user.save(); return res.status(400).json({ message: 'Verification code is incorrect' }); }
		user.isEmailVerified = true;
		user.verificationCodeHash = undefined;
		user.verificationCodeExpires = undefined;
		user.verificationAttempts = 0;
		await user.save();
		return res.json({ user: publicUser(user), token: issueToken(user) });
	} catch (error) { next(error); }
}

async function resendVerification(req, res, next) {
	try {
		const email = normalizeEmail(req.body.email);
		if (!emailConfigured()) return res.status(503).json({ message: 'Email service is not configured. Set SMTP_USER and SMTP_PASS.' });
		const user = await User.findOne({ email }).select('+verificationCodeHash +verificationCodeExpires');
		if (user && !user.isEmailVerified) { const code = makeCode(); const fields = codeFields(code); user.verificationCodeHash = fields.hash; user.verificationCodeExpires = fields.expires; user.verificationAttempts = 0; await user.save(); await sendOtpEmail({ to: email, code, purpose: 'verification' }); }
		return res.json({ message: 'If the account requires verification, a new code has been sent' });
	} catch (error) { next(error); }
}

async function login(req, res, next) {
	try {
		const email = normalizeEmail(req.body.email);
		const user = await User.findOne({ email }).select('+password +tokenVersion');
		if (!user || !(await bcrypt.compare(req.body.password || '', user.password))) return res.status(401).json({ message: 'Invalid email or password' });
		if (!user.isEmailVerified) return res.status(403).json({ message: 'Verify your email before logging in' });
		return res.json({ user: publicUser(user), token: issueToken(user) });
	} catch (error) { next(error); }
}

async function getProfile(req, res, next) {
	try { const user = await User.findById(req.user.id); if (!user) return res.status(404).json({ message: 'User not found' }); return res.json({ user: publicUser(user) }); } catch (error) { next(error); }
}

async function updateProfile(req, res, next) {
	try {
		const allowed = ['name', 'phone', 'dateOfBirth', 'gender'];
		const updates = Object.fromEntries(Object.entries(req.body).filter(([key]) => allowed.includes(key)));
		if (updates.name !== undefined && (!String(updates.name).trim() || String(updates.name).length > 100)) return res.status(400).json({ message: 'Name is required and must be 100 characters or fewer' });
		const user = await User.findByIdAndUpdate(req.user.id, updates, { new: true, runValidators: true });
		return res.json({ user: publicUser(user) });
	} catch (error) { next(error); }
}

async function forgotPassword(req, res, next) {
	try {
		const email = normalizeEmail(req.body.email);
		if (!emailConfigured()) return res.status(503).json({ message: 'Email service is not configured. Set SMTP_USER and SMTP_PASS.' });
		const user = await User.findOne({ email }).select('+resetCodeHash +resetCodeExpires +resetAttempts');
		if (user && user.isEmailVerified) { const code = makeCode(); const fields = codeFields(code); user.resetCodeHash = fields.hash; user.resetCodeExpires = fields.expires; user.resetAttempts = 0; await user.save(); await sendOtpEmail({ to: email, code, purpose: 'reset' }); }
		return res.json({ message: 'If an account exists, password reset instructions have been sent' });
	} catch (error) { next(error); }
}

async function resetPassword(req, res, next) {
	try {
		const email = normalizeEmail(req.body.email);
		const user = await User.findOne({ email }).select('+resetCodeHash +resetCodeExpires +resetAttempts +tokenVersion');
		if (!user || !user.resetCodeExpires || user.resetCodeExpires <= new Date()) return res.status(400).json({ message: 'Reset code is invalid or expired' });
		if (user.resetAttempts >= 5) return res.status(429).json({ message: 'Too many attempts. Request a new code.' });
		if (hashCode(String(req.body.code || '').trim()) !== user.resetCodeHash) { user.resetAttempts += 1; await user.save(); return res.status(400).json({ message: 'Reset code is incorrect' }); }
		if (!validPassword(req.body.password) || req.body.password === email) return res.status(400).json({ message: 'Password must be 8-128 characters and include uppercase, lowercase, number and symbol' });
		user.password = await bcrypt.hash(req.body.password, 12);
		user.resetCodeHash = undefined;
		user.resetCodeExpires = undefined;
		user.resetAttempts = 0;
		user.tokenVersion += 1;
		await user.save();
		return res.json({ message: 'Password reset successfully' });
	} catch (error) { next(error); }
}

async function logout(req, res, next) {
	try { await User.findByIdAndUpdate(req.user.id, { $inc: { tokenVersion: 1 } }); res.json({ message: 'Logged out successfully' }); } catch (error) { next(error); }
}

module.exports = { register, verifyEmail, resendVerification, login, getProfile, updateProfile, forgotPassword, resetPassword, logout };
