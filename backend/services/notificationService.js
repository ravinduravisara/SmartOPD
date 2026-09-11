const Notification = require('../models/Notification');
const { notifyPatientQueueUpdate } = require('./socketService');

// Map to track sent notifications in memory to prevent rapid duplicate triggers
const recentTriggers = new Map();

function getTriggerKey(userId, queueId, type) {
	return `${userId}:${queueId}:${type}`;
}

async function sendQueueNotification({ userId, queueId, title, message, type }) {
	try {
		const key = getTriggerKey(userId, queueId, type);
		
		// If sent in the last 60 seconds, skip duplicate
		if (recentTriggers.has(key)) {
			const lastSent = recentTriggers.get(key);
			if (Date.now() - lastSent < 60000) {
				return null;
			}
		}

		// Also check DB for exact duplicate notification in last 5 minutes
		const existing = await Notification.findOne({
			userId,
			queueId,
			type,
			createdAt: { $gte: new Date(Date.now() - 5 * 60 * 1000) }
		});

		if (existing) {
			recentTriggers.set(key, Date.now());
			return existing;
		}

		const notification = await Notification.create({
			userId,
			queueId,
			title,
			message,
			type
		});

		recentTriggers.set(key, Date.now());

		// Notify via socket if connected
		notifyPatientQueueUpdate(userId, {
			type: 'notification',
			notification
		});

		return notification;
	} catch (err) {
		console.error('Error sending queue notification:', err);
		return null;
	}
}

module.exports = {
	sendQueueNotification
};
