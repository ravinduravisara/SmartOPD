const express = require('express');
const controller = require('../controllers/appointmentController');

const router = express.Router();
router.get('/', controller.listMine);
router.post('/', controller.create);

module.exports = router;
