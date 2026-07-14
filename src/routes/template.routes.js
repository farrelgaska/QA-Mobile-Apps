const express = require('express');
const router = express.Router();
const templateController = require('../controllers/template.controller');
const reportController = require('../controllers/report.controller'); // to reuse validateObjectBody

router.get('/', templateController.getTemplates);
router.get('/:id', templateController.getTemplateById);
router.post('/', reportController.validateObjectBody, templateController.createTemplate);
router.patch('/:id', reportController.validateObjectBody, templateController.patchTemplate);
router.delete('/:templateId/items/:itemId', templateController.deleteTemplateItem);

module.exports = router;
