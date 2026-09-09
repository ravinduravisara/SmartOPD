const express = require('express');
const controller = require('../controllers/doctorController');

const router = express.Router();
router.get('/', controller.list);
router.get('/:id', controller.get);
router.get('/:id/slots', controller.slots);

module.exports = router;
