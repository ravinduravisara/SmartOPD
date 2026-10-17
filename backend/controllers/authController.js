const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const User = require('../models/User');
const { sendOtpEmail, isConfigured: emailConfigured } = require('../services/emailService');

const jwtSecret = () => process.env.JWT_SECRET;
const googleClient = new OAuth2Client();
const normalizeEmail = (email) => String(email || '').trim().toLowerCase();
const validEmail = (email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
const validPassword = (password) => typeof password === 'string' && password.length >= 8 && password.length <= 128 && /[A-Z]/.test(password) && /[a-z]/.test(password) && /\d/.test(password) && /[^A-Za-z0-9]/.test(password);
const validPhone = (phone) => /^\d{10}$/.test(String(phone || '').trim());
const validNic = (nic) => {
	const cleaned = String(nic || '').replace(/[\s\-]/g, '').trim();
	return /^([0-9]{9}[vVxX]|[0-9]{12})$/.test(cleaned);
};
const validName = (name) => {
	const n = String(name || '').trim();
	return n.length >= 2 && n.length <= 100 && /^[a-zA-Z\s\-'.]+$/.test(n);
};
const validProfilePicture = (value) => (String(value).startsWith('data:image/') && String(value).length <= 4500000) || (/^https:\/\/[^\s]+$/.test(value) && String(value).length <= 2048);
const makeCode = () => String(crypto.randomInt(100000, 1000000));
const hashCode = (code) => crypto.createHash('sha256').update(code).digest('hex');
const codeFields = (code) => ({ hash: hashCode(code), expires: new Date(Date.now() + 10 * 60 * 1000) });

function publicUser(user) {
	return { id: user._id, name: user.name, email: user.email, phone: user.phone || null, nic: user.nic || null, role: user.role, isEmailVerified: Boolean(user.isEmailVerified), dateOfBirth: user.dateOfBirth || null, gender: user.gender || null, profilePicture: user.profilePicture || null };
}

function issueToken(user) {
	return jwt.sign({ id: user._id.toString(), role: user.role, tokenVersion: user.tokenVersion }, jwtSecret(), { expiresIn: '1h', issuer: 'smartopd' });
}

async function register(req, res, next) {
	try {
		const { name, password, phone, nic, dateOfBirth, gender } = req.body;
		const email = normalizeEmail(req.body.email);
		if (!name || !email || !password) return res.status(400).json({ message: 'Name, email and password are required' });
		if (!validEmail(email)) return res.status(400).json({ message: 'Enter a valid email address' });
		if (!validPassword(password)) return res.status(400).json({ message: 'Password must be 8-128 characters and include uppercase, lowercase, number and symbol' });
		if (!emailConfigured()) return res.status(503).json({ message: 'Email service is not configured. Set SMTP_USER and SMTP_PASS.' });
		const cleanNic = nic ? String(nic).replace(/[\s\-]/g, '').trim().toUpperCase() : undefined;
		if (cleanNic && !validNic(cleanNic)) {
			return res.status(400).json({ message: 'NIC must be 9 digits followed by V/X or 12 digits (e.g. 991234567V or 200012345678)' });
		}
		const existing = await User.findOne({ email });
		if (existing?.isEmailVerified) return res.status(409).json({ message: 'An account with this email already exists' });
		const code = makeCode();
		const fields = codeFields(code);
		const user = existing || new User({ email });
		Object.assign(user, { name, email, phone, nic: cleanNic, dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : undefined, gender, password: await bcrypt.hash(password, 12), isEmailVerified: false, verificationCodeHash: fields.hash, verificationCodeExpires: fields.expires, verificationAttempts: 0 });
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

async function googleLogin(req, res, next) {
	try {
		const clientId = process.env.GOOGLE_SERVER_CLIENT_ID;
		if (!clientId) return res.status(503).json({ message: 'Google sign-in is not configured on the server' });
		if (typeof req.body.idToken !== 'string' || !req.body.idToken) return res.status(400).json({ message: 'Google ID token is required' });
		let ticket;
		try {
			ticket = await googleClient.verifyIdToken({ idToken: req.body.idToken, audience: clientId });
		} catch (_) {
			return res.status(401).json({ message: 'Google ID token is invalid or does not match the configured client ID' });
		}
		const payload = ticket.getPayload();
		if (!payload?.email || payload.email_verified !== true) return res.status(401).json({ message: 'Google account email is not verified' });
		const email = normalizeEmail(payload.email);
		let user = await User.findOne({ email }).select('+password +tokenVersion');
		if (!user) {
			user = new User({
				name: payload.name || email.split('@')[0],
				email,
				password: await bcrypt.hash(crypto.randomBytes(32).toString('hex'), 12),
				profilePicture: validProfilePicture(payload.picture) ? payload.picture : undefined,
				isEmailVerified: true
			});
		} else if (!user.isEmailVerified) {
			user.isEmailVerified = true;
		}
		await user.save();
		return res.json({ user: publicUser(user), token: issueToken(user) });
	} catch (error) { next(error); }
}

async function getProfile(req, res, next) {
	try { const user = await User.findById(req.user.id); if (!user) return res.status(404).json({ message: 'User not found' }); return res.json({ user: publicUser(user) }); } catch (error) { next(error); }
}

async function updateProfile(req, res, next) {
	try {
		const allowed = ['name', 'phone', 'nic', 'dateOfBirth', 'gender', 'profilePicture'];
		const updates = Object.fromEntries(Object.entries(req.body).filter(([key]) => allowed.includes(key)));

		if (updates.name !== undefined) {
			if (!validName(updates.name)) {
				return res.status(400).json({ message: 'Name must be 2-100 characters and contain letters only' });
			}
			updates.name = String(updates.name).trim();
		}

		if (updates.phone !== undefined && updates.phone !== null && updates.phone !== '') {
			const cleanedPhone = String(updates.phone).trim();
			if (!validPhone(cleanedPhone)) {
				return res.status(400).json({ message: 'Phone number must be exactly 10 digits' });
			}
			updates.phone = cleanedPhone;
		}

		if (updates.nic !== undefined && updates.nic !== null && updates.nic !== '') {
			const cleanedNic = String(updates.nic).replace(/[\s\-]/g, '').trim().toUpperCase();
			if (!validNic(cleanedNic)) {
				return res.status(400).json({ message: 'NIC must be 9 digits followed by V/X or 12 digits (e.g. 991234567V or 200012345678)' });
			}
			updates.nic = cleanedNic;
		}

		if (updates.dateOfBirth !== undefined && updates.dateOfBirth !== null && updates.dateOfBirth !== '') {
			const dob = new Date(updates.dateOfBirth);
			if (isNaN(dob.getTime()) || dob >= new Date() || dob < new Date('1900-01-01')) {
				return res.status(400).json({ message: 'Date of birth must be a valid date in the past' });
			}
			updates.dateOfBirth = dob;
		}

		if (updates.gender !== undefined && updates.gender !== null && updates.gender !== '') {
			const allowedGenders = ['male', 'female', 'other', 'prefer_not_to_say'];
			if (!allowedGenders.includes(updates.gender)) {
				return res.status(400).json({ message: 'Please select a valid gender option' });
			}
		}

		if (updates.profilePicture !== undefined && updates.profilePicture !== null && !validProfilePicture(updates.profilePicture)) {
			return res.status(400).json({ message: 'Profile picture must be an https URL or an image smaller than 3 MB' });
		}

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

module.exports = { register, verifyEmail, resendVerification, login, googleLogin, getProfile, updateProfile, forgotPassword, resetPassword, logout };
