const templateRepository = require('../repositories/json-template.repository');

const getTemplates = (req, res, next) => {
  try {
    let templates = templateRepository.findAll();
    
    // Support optional query parameters
    const { type, active } = req.query;
    
    if (type) {
      templates = templates.filter(t => t.type === type);
    }
    
    if (active !== undefined) {
      const isActiveBool = active === 'true';
      templates = templates.filter(t => t.isActive === isActiveBool);
    }

    res.json(templates);
  } catch (err) {
    next(err);
  }
};

const getTemplateById = (req, res, next) => {
  try {
    const template = templateRepository.findById(req.params.id);
    if (!template) {
      return res.status(404).json({ error: `Template with ID ${req.params.id} not found` });
    }
    res.json(template);
  } catch (err) {
    next(err);
  }
};

const createTemplate = (req, res, next) => {
  try {
    const templateData = req.body;
    
    // Auto-generate template id if missing
    if (!templateData.id) {
      const prefix = templateData.type === 'WORK' ? 'WRK' : 'MAT';
      templateData.id = `${prefix}-${Date.now()}`;
    }

    const nowIso = new Date().toISOString();
    const template = {
      id: templateData.id,
      type: templateData.type || 'MATERIAL',
      name: templateData.name || '',
      formCode: templateData.formCode || '',
      category: templateData.category || '',
      standardCode: templateData.standardCode || '',
      checklistItems: templateData.checklistItems || [],
      isActive: templateData.isActive !== undefined ? templateData.isActive : true,
      createdAt: templateData.createdAt || nowIso,
      updatedAt: nowIso
    };

    const created = templateRepository.create(template);
    res.status(201).json(created);
  } catch (err) {
    next(err);
  }
};

const patchTemplate = (req, res, next) => {
  try {
    const updated = templateRepository.update(req.params.id, req.body);
    res.json(updated);
  } catch (err) {
    next(err);
  }
};

const deleteTemplateItem = (req, res, next) => {
  try {
    const { templateId, itemId } = req.params;
    const updated = templateRepository.deleteChecklistItem(templateId, itemId);
    res.json(updated);
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getTemplates,
  getTemplateById,
  createTemplate,
  patchTemplate,
  deleteTemplateItem
};
