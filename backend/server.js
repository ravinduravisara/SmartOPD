require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const connectDatabase = require('./config/db');
const { requireAuth, requireDatabase } = require('./middleware/authMiddleware');

const app = express();
let databaseReady = false;
app.locals.databaseReady = false;
app.use(cors());
app.use(express.json());
app.get('/health', (req, res) => res.json({ status: databaseReady ? 'ok' : 'degraded', database: databaseReady ? 'connected' : 'disconnected' }));
app.use('/api/auth', requireDatabase, require('./routes/authRoutes'));
app.use('/api/dependents', requireDatabase, requireAuth, require('./routes/dependentRoutes'));
app.use('/api/appointments', requireDatabase, requireAuth, require('./routes/appointmentRoutes'));
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
			app.listen(port, () => console.log(`SmartOPD API listening on port ${port}`));
		})
		.catch((error) => {
			console.error('MongoDB connection failed; server not started', error.message);
			process.exitCode = 1;
		});
}

module.exports = app;
