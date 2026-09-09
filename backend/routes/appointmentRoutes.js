const express = require('express');
const controller = require('../controllers/appointmentController');

const router = express.Router();
router.get('/', controller.listMine);
router.post('/', controller.create);
router.get('/:id', controller.get);
router.patch('/:id/cancel', controller.cancel);
router.patch('/:id/reschedule', controller.reschedule);

module.exports = router;
