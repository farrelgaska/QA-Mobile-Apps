const express = require('express');
const router = express.Router();
const reportController = require('../controllers/report.controller');

router.get('/', reportController.getReports);
router.get('/:id', reportController.getReportById);
router.post('/', reportController.validateObjectBody, reportController.createReport);
router.patch('/:id', reportController.validateObjectBody, reportController.patchReport);

module.exports = router;
