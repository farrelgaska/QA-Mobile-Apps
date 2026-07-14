const { templateRepository } = require('../repositories');

const getTemplates = async (req, res, next) => {
  try {
    let templates = await templateRepository.findAll();
    
    // Support optional query parameters
    const { type, active } = req.query;
    
    if (type) {
      templates = templates.filter(t => t.type === type);
    }
    
    if (active !== undefined) {
      const isActiveBool = active === 'true';
      templates = templates.filter(t => (t.is_active ?? t.isActive) === isActiveBool);
    }

    res.json(templates);
  } catch (err) {
    next(err);
  }
};

const getTemplateById = async (req, res, next) => {
  try {
    const template = await templateRepository.findById(req.params.id);
    if (!template) {
      return res.status(404).json({ error: `Template with ID ${req.params.id} not found` });
    }
    res.json(template);
  } catch (err) {
    next(err);
  }
};

const createTemplate = async (req, res, next) => {
  try {
    const templateData = req.body;
    
    // Auto-generate template id if missing
    if (!templateData.id) {
      const prefix = templateData.type === 'WORK' ? 'WRK' : 'MAT';
      templateData.id = `${prefix}-${Date.now()}`;
    }

    const nowIso = new Date().toISOString();
    const template = {
      ...templateData,
      id: templateData.id,
      type: templateData.type || 'MATERIAL',
      name: templateData.name || '',
      formCode: templateData.formCode ?? templateData.form_code ?? '',
      category: templateData.category || '',
      standardCode: templateData.standardCode ?? templateData.standard_code ?? '',
      checklistItems: templateData.checklistItems ?? templateData.checklist_items ?? [],
      isActive: templateData.isActive ?? templateData.is_active ?? true,
      createdAt: templateData.createdAt ?? templateData.created_at ?? nowIso,
      updatedAt: nowIso
    };

    const created = await templateRepository.create(template);
    res.status(201).json(created);
  } catch (err) {
    next(err);
  }
};

const patchTemplate = async (req, res, next) => {
  try {
    const updated = await templateRepository.update(req.params.id, req.body);
    res.json(updated);
  } catch (err) {
    next(err);
  }
};

const deleteTemplateItem = async (req, res, next) => {
  try {
    const { templateId, itemId } = req.params;
    const updated = await templateRepository.deleteChecklistItem(templateId, itemId);
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
