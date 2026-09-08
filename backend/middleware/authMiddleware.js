const jwt = require('jsonwebtoken');

function requireDatabase(req, res, next) {

	if (req.app.locals.databaseReady === false) return res.status(503).json({ message: 'Database is unavailable. Start MongoDB and try again.' });
	next();
}

function requireAuth(req, res, next) {
	const header = req.headers.authorization || '';
	const token = header.startsWith('Bearer ') ? header.slice(7) : null;

	if (!token) return res.status(401).json({ message: 'Authentication required' });

	try {
		req.user = jwt.verify(token, process.env.JWT_SECRET || 'development-secret-change-me');
		next();
	} catch (error) {
		return res.status(401).json({ message: 'Invalid or expired token' });
	}
}

module.exports = { requireAuth, requireDatabase };
