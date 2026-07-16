const fs = require('fs');
const path = require('path');
const { TEMPLATES_FILE } = require('../config/env');
const { canonicalTemplateInput, canonicalTemplateShape } = require('./postgres/mappers');

const normalizeTemplate = template => {
  const canonical = canonicalTemplateInput(template);
  return canonical;
};
const normalizeTemplateRead = template => canonicalTemplateShape(template);

class JsonTemplateRepository {
  constructor(filePath = TEMPLATES_FILE) {
    this.filePath = filePath;
  }

  _read() {
    try {
      if (!fs.existsSync(this.filePath)) {
        const dir = path.dirname(this.filePath);
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
        }
        this._write([]);
        return [];
      }
      const raw = fs.readFileSync(this.filePath, 'utf-8');
      return JSON.parse(raw);
    } catch (e) {
      throw new Error(`Failed to read templates database: ${e.message}`);
    }
  }

  _write(data) {
    const tempPath = `${this.filePath}.${Date.now()}.tmp`;
    try {
      const dir = path.dirname(this.filePath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.writeFileSync(tempPath, JSON.stringify(data, null, 2), 'utf-8');
      fs.renameSync(tempPath, this.filePath);
    } catch (e) {
      try {
        if (fs.existsSync(tempPath)) {
          fs.unlinkSync(tempPath);
        }
      } catch (_) {}
      throw new Error(`Failed to write templates database: ${e.message}`);
    }
  }

  findAll() {
    return this._read().map(normalizeTemplateRead);
  }

  findById(id) {
    const templates = this._read();
    const template = templates.find(t => t.id === id);
    return template ? normalizeTemplateRead(template) : undefined;
  }

  create(template) {
    const templates = this._read();
    if (templates.some(t => t.id === template.id)) {
      const err = new Error(`Template with ID ${template.id} already exists`);
      err.statusCode = 409;
      throw err;
    }
    const canonical = normalizeTemplate(template);
    templates.push(canonical);
    this._write(templates);
    return canonical;
  }

  update(id, patchData) {
    const templates = this._read();
    const index = templates.findIndex(t => t.id === id);
    if (index === -1) {
      const err = new Error(`Template with ID ${id} not found`);
      err.statusCode = 404;
      throw err;
    }
    const current = normalizeTemplateRead(templates[index]);
    const merged = { ...current, ...patchData, id };
    const aliases = [
      ['formCode', 'form_code'], ['standardCode', 'standard_code'],
      ['isActive', 'is_active'], ['workflowStatus', 'workflow_status'],
      ['checklistItems', 'checklist_items']
    ];
    for (const [legacy, canonical] of aliases) {
      if (patchData[legacy] !== undefined && patchData[canonical] === undefined) merged[canonical] = patchData[legacy];
    }
    merged.created_at = current.created_at;
    merged.updated_at = new Date().toISOString();
    const replacesItems = patchData.checklist_items !== undefined || patchData.checklistItems !== undefined;
    const updated = normalizeTemplate(replacesItems ? merged : { ...merged, checklist_items: [] });
    if (!replacesItems) updated.checklist_items = current.checklist_items;
    templates[index] = updated;
    this._write(templates);
    return updated;
  }

  delete(id) {
    const templates = this._read();
    const index = templates.findIndex(template => template.id === id);
    if (index === -1) {
      const err = new Error(`Template with ID ${id} not found`);
      err.statusCode = 404;
      throw err;
    }
    templates.splice(index, 1);
    this._write(templates);
  }

  deleteChecklistItem(templateId, itemId) {
    const templates = this._read();
    const templateIndex = templates.findIndex(t => t.id === templateId);
    if (templateIndex === -1) {
      const err = new Error(`Template with ID ${templateId} not found`);
      err.statusCode = 404;
      throw err;
    }

    const template = normalizeTemplateRead(templates[templateIndex]);
    const itemIndex = template.checklist_items.findIndex(item => item.id === itemId);
    if (itemIndex === -1) {
      const err = new Error(`Checklist parameter with ID ${itemId} not found in template ${templateId}`);
      err.statusCode = 404;
      throw err;
    }

    template.checklist_items.splice(itemIndex, 1);
    template.updated_at = new Date().toISOString();

    templates[templateIndex] = template;
    this._write(templates);
    return template;
  }
}

const repository = new JsonTemplateRepository();
repository.JsonTemplateRepository = JsonTemplateRepository;
module.exports = repository;
