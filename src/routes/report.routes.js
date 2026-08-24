const express = require('express');
const router = express.Router();
const reportController = require('../controllers/report.controller');
const idempotencyMiddleware = require('../middleware/idempotency');

router.get('/', reportController.getReports);
router.get('/:id', reportController.getReportById);
router.post('/', idempotencyMiddleware, reportController.validateObjectBody, reportController.createReport);
router.patch('/:id', reportController.validateObjectBody, reportController.patchReport);
router.delete('/:id', reportController.deleteReport);

module.exports = router;
