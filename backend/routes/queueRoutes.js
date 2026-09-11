const express = require('express');
const router = express.Router();
const queueController = require('../controllers/queueController');
const { askQueueAssistant } = require('../controllers/queueAssistantController');
const { requireAuth } = require('../middleware/authMiddleware');

router.use(requireAuth);

// Patient Queue Routes
router.post('/check-in', queueController.checkIn);
router.get('/active', queueController.getActivePatientQueue);
router.get('/history', queueController.getPatientQueueHistory);
router.get('/nearby-hospitals', queueController.getNearbyHospitals);

// Smart Queue Assistant Route
router.post('/assistant', askQueueAssistant);

// Staff Queue Operations
router.post('/call-next', queueController.callNextToken);
router.post('/skip', queueController.skipToken);
router.post('/complete', queueController.completeConsultation);
router.post('/no-show', queueController.markNoShow);

module.exports = router;
