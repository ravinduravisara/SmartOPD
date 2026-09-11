const jwt = require('jsonwebtoken');
const User = require('../models/User');

function requireDatabase(req, res, next) {

	if (req.app.locals.databaseReady === false) return res.status(503).json({ message: 'Database is unavailable. Start MongoDB and try again.' });
	next();
}

function requireAuth(req, res, next) {
	const header = req.headers.authorization || '';
	const token = header.startsWith('Bearer ') ? header.slice(7) : null;

	if (!token) return res.status(401).json({ message: 'Authentication required' });

	try {
		req.user = jwt.verify(token, process.env.JWT_SECRET, { issuer: 'smartopd' });
		User.findById(req.user.id).select('+tokenVersion')
			.then((user) => {
				if (!user || user.tokenVersion !== req.user.tokenVersion || !user.isEmailVerified) return res.status(401).json({ message: 'Session is invalid or expired' });
				req.userRecord = user;
				req.user = user;
				next();
			})
			.catch(next);
	} catch (error) {
		return res.status(401).json({ message: 'Invalid or expired token' });
	}
}

module.exports = { requireAuth, requireDatabase };
