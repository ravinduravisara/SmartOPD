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

// Delete single notification
router.delete('/:id', async (req, res) => {
	try {
		const userId = req.user?._id || req.user?.id;
		const notification = await Notification.findOneAndDelete({
			_id: req.params.id,
			userId
		});

		if (!notification) {
			return res.status(404).json({ message: 'Notification not found' });
		}

		res.json({ success: true, message: 'Notification deleted successfully' });
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error deleting notification' });
	}
});

// Clear all notifications for user
router.delete('/', async (req, res) => {
	try {
		const userId = req.user?._id || req.user?.id;
		const result = await Notification.deleteMany({ userId });

		res.json({
			success: true,
			message: `${result.deletedCount} notifications cleared successfully`
		});
	} catch (err) {
		console.error(err);
		res.status(500).json({ message: 'Error clearing notifications' });
	}
});

module.exports = router;
