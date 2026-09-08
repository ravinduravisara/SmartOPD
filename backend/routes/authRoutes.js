const express = require('express');
const controller = require('../controllers/authController');
const { requireAuth } = require('../middleware/authMiddleware');

const router = express.Router();
router.post('/register', controller.register);
router.post('/login', controller.login);
router.post('/forgot-password', controller.forgotPassword);
router.post('/reset-password/:token', controller.resetPassword);
router.get('/me', requireAuth, controller.getProfile);
router.patch('/me', requireAuth, controller.updateProfile);
router.post('/logout', requireAuth, (req, res) => res.json({ message: 'Logged out successfully' }));

module.exports = router;
