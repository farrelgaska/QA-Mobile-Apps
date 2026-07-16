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
    const templateData = { ...req.body };
    
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
      form_code: templateData.form_code ?? templateData.formCode ?? '',
      category: templateData.category || '',
      standard_code: templateData.standard_code ?? templateData.standardCode ?? '',
      checklist_items: templateData.checklist_items ?? templateData.checklistItems ?? [],
      is_active: templateData.is_active ?? templateData.isActive ?? true,
      created_at: templateData.created_at ?? templateData.createdAt ?? nowIso,
      updated_at: nowIso
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

const deleteTemplate = async (req, res, next) => {
  try {
    await templateRepository.delete(req.params.id);
    res.status(204).end();
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
  deleteTemplate,
  deleteTemplateItem
};
