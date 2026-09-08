const express = require('express');
const controller = require('../controllers/dependentController');

const router = express.Router();
router.get('/', controller.list);
router.post('/', controller.create);
router.patch('/:id', controller.update);
router.delete('/:id', controller.remove);

module.exports = router;