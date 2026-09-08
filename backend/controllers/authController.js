const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const jwtSecret = () => process.env.JWT_SECRET || 'development-secret-change-me';

function publicUser(user) {
	return {
		id: user._id,
		name: user.name,
		email: user.email,
		phone: user.phone,
		role: user.role,
		dateOfBirth: user.dateOfBirth,
		gender: user.gender
	};
}

function issueToken(user) {
	return jwt.sign({ id: user._id.toString(), role: user.role }, jwtSecret(), { expiresIn: '7d' });
}

async function register(req, res, next) {
	try {
		const { name, email, password, phone, dateOfBirth, gender } = req.body;
		if (!name || !email || !password) return res.status(400).json({ message: 'Name, email and password are required' });
		if (password.length < 8) return res.status(400).json({ message: 'Password must be at least 8 characters' });

		const exists = await User.findOne({ email: email.toLowerCase().trim() });
		if (exists) return res.status(409).json({ message: 'An account with this email already exists' });

		const user = await User.create({
			name, email, phone, dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : undefined,
			gender, password: await bcrypt.hash(password, 12)
		});
		return res.status(201).json({ user: publicUser(user), token: issueToken(user) });
	} catch (error) { next(error); }
}

async function login(req, res, next) {
	try {
		const { email, password } = req.body;
		const user = await User.findOne({ email: (email || '').toLowerCase().trim() }).select('+password');
		if (!user || !(await bcrypt.compare(password || '', user.password))) {
			return res.status(401).json({ message: 'Invalid email or password' });
		}
		return res.json({ user: publicUser(user), token: issueToken(user) });
	} catch (error) { next(error); }
}

async function getProfile(req, res, next) {
	try { return res.json({ user: publicUser(await User.findById(req.user.id)) }); } catch (error) { next(error); }
}

async function updateProfile(req, res, next) {
	try {
		const allowed = ['name', 'phone', 'dateOfBirth', 'gender'];
		const updates = Object.fromEntries(Object.entries(req.body).filter(([key]) => allowed.includes(key)));
		const user = await User.findByIdAndUpdate(req.user.id, updates, { new: true, runValidators: true });
		return res.json({ user: publicUser(user) });
	} catch (error) { next(error); }
}

async function forgotPassword(req, res, next) {
	try {
		const user = await User.findOne({ email: (req.body.email || '').toLowerCase().trim() }).select('+resetPasswordToken +resetPasswordExpires');
		if (user) {
			const rawToken = crypto.randomBytes(32).toString('hex');
			user.resetPasswordToken = crypto.createHash('sha256').update(rawToken).digest('hex');
			user.resetPasswordExpires = new Date(Date.now() + 15 * 60 * 1000);
			await user.save();
			console.log(`Password reset token for ${user.email}: ${rawToken}`);
		}
		return res.json({ message: 'If an account exists, password reset instructions have been sent' });
	} catch (error) { next(error); }
}

async function resetPassword(req, res, next) {
	try {
		const tokenHash = crypto.createHash('sha256').update(req.params.token).digest('hex');
		const user = await User.findOne({ resetPasswordToken: tokenHash, resetPasswordExpires: { $gt: new Date() } }).select('+resetPasswordToken +resetPasswordExpires');
		if (!user) return res.status(400).json({ message: 'Reset token is invalid or expired' });
		if (!req.body.password || req.body.password.length < 8) return res.status(400).json({ message: 'Password must be at least 8 characters' });
		user.password = await bcrypt.hash(req.body.password, 12);
		user.resetPasswordToken = undefined;
		user.resetPasswordExpires = undefined;
		await user.save();
		return res.json({ message: 'Password reset successfully' });
	} catch (error) { next(error); }
}

module.exports = { register, login, getProfile, updateProfile, forgotPassword, resetPassword };
