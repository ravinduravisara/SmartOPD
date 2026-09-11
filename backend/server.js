require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const connectDatabase = require('./config/db');
const { requireAuth, requireDatabase } = require('./middleware/authMiddleware');
const { isConfigured: isEmailConfigured } = require('./services/emailService');

const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const app = express();
let databaseReady = false;
app.locals.databaseReady = false;
app.use(cors());
app.use(express.json({ limit: '5mb' }));
app.use(helmet());
app.use('/api/auth', rateLimit({
	windowMs: 15 * 60 * 1000,
	max: 100,
	standardHeaders: true,
	legacyHeaders: false,
	handler: (req, res) => res.status(429).json({ message: 'Too many authentication attempts. Please try again later.' })
}));
app.get('/health', (req, res) => res.json({
	status: databaseReady && isEmailConfigured() ? 'ok' : 'degraded',
	database: databaseReady ? 'connected' : 'disconnected',
	email: isEmailConfigured() ? 'configured' : 'not_configured'
}));
const http = require('http');
const { initSocket } = require('./services/socketService');
const { startReminderScheduler } = require('./services/reminderService');

app.use('/api/auth', requireDatabase, require('./routes/authRoutes'));
app.use('/api/hospitals', requireDatabase, requireAuth, require('./routes/hospitalRoutes'));
app.use('/api/doctors', requireDatabase, requireAuth, require('./routes/doctorRoutes'));
app.use('/api/dependents', requireDatabase, requireAuth, require('./routes/dependentRoutes'));
app.use('/api/appointments', requireDatabase, requireAuth, require('./routes/appointmentRoutes'));
app.use('/api/queues', requireDatabase, requireAuth, require('./routes/queueRoutes'));
app.use('/api/notifications', requireDatabase, requireAuth, require('./routes/notificationRoutes'));

app.use((error, req, res, next) => {
	if (error.code === 11000) return res.status(409).json({ message: 'A record with that value already exists' });
	console.error(error);
	res.status(500).json({ message: 'Internal server error' });
});

const port = process.env.PORT || 3000;
if (require.main === module) {
	connectDatabase()
		.then(() => {
			databaseReady = true;
			app.locals.databaseReady = true;
			const server = http.createServer(app);
			initSocket(server);
			startReminderScheduler();
			server.listen(port, () => console.log(`SmartOPD API listening on port ${port}`));
		})
		.catch((error) => {
			console.error('MongoDB connection failed; server not started', error.message);
			process.exitCode = 1;
		});
}

module.exports = app;

