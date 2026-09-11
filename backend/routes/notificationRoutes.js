const express = require('express');
const router = express.Router();
const Notification = require('../models/Notification');
const { requireAuth } = require('../middleware/authMiddleware');

router.use(requireAuth);

// Get patient notification history
router.get('/', async (req, res) => {
	try {
		const userId = req.user?._id || req.user?.id;
		const notifications = await Notification.find({ userId })
			.sort({ createdAt: -1 })
			.limit(50);
		
		const unreadCount = await Notification.countDocuments({
			userId,
			readStatus: false
		});

		res.json({ success: true, data: { notifications, unreadCount } });
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error fetching notifications' });
	}
});

// Mark single notification as read
router.patch('/:id/read', async (req, res) => {
	try {
		const userId = req.user?._id || req.user?.id;
		const notification = await Notification.findOneAndUpdate(
			{ _id: req.params.id, userId },
			{ readStatus: true },
			{ new: true }
		);
		res.json({ success: true, data: notification });
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error marking notification read' });
	}
});

// Mark all as read
router.post('/read-all', async (req, res) => {
	try {
		const userId = req.user?._id || req.user?.id;
		await Notification.updateMany(
			{ userId, readStatus: false },
			{ readStatus: true }
		);
		res.json({ success: true, message: 'All notifications marked as read' });
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error marking all read' });
	}
});

module.exports = router;
