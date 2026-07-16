const fs = require('fs');
const path = require('path');
const { TEMPLATES_FILE } = require('../config/env');
const {
  canonicalTemplateInput,
  canonicalTemplateItemInput,
  canonicalTemplateShape,
  mergeTemplateItemPatch
} = require('./postgres/mappers');

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

  _nextItemId(templateId, items) {
    const existing = new Set(items.map(item => item.id));
    let sequence = 1;
    while (existing.has(`${templateId}-C${String(sequence).padStart(2, '0')}`)) sequence += 1;
    return `${templateId}-C${String(sequence).padStart(2, '0')}`;
  }

  createChecklistItem(templateId, input) {
    const templates = this._read();
    const templateIndex = templates.findIndex(template => template.id === templateId);
    if (templateIndex === -1) {
      const error = new Error(`Template with ID ${templateId} not found`);
      error.statusCode = 404;
      throw error;
    }
    const template = normalizeTemplateRead(templates[templateIndex]);
    const id = input.id || this._nextItemId(templateId, template.checklist_items);
    if (template.checklist_items.some(item => item.id === id)) {
      const error = new Error(`Checklist parameter with ID ${id} already exists in template ${templateId}`);
      error.statusCode = 409;
      throw error;
    }
    const nextPosition = template.checklist_items.reduce(
      (maximum, item) => Math.max(maximum, item.position),
      -1
    ) + 1;
    const position = input.position ?? nextPosition;
    if (template.checklist_items.some(item => item.position === position)) {
      const error = new Error(`Checklist position ${position} already exists in template ${templateId}`);
      error.statusCode = 409;
      throw error;
    }
    const item = canonicalTemplateItemInput({ ...input, id, position }, nextPosition);
    template.checklist_items.push(item);
    template.checklist_items.sort((left, right) => left.position - right.position || left.id.localeCompare(right.id));
    template.updated_at = new Date().toISOString();
    templates[templateIndex] = template;
    this._write(templates);
    return item;
  }

  updateChecklistItem(templateId, itemId, patch) {
    const templates = this._read();
    const templateIndex = templates.findIndex(template => template.id === templateId);
    if (templateIndex === -1) {
      const error = new Error(`Template with ID ${templateId} not found`);
      error.statusCode = 404;
      throw error;
    }
    const template = normalizeTemplateRead(templates[templateIndex]);
    const itemIndex = template.checklist_items.findIndex(item => item.id === itemId);
    if (itemIndex === -1) {
      const error = new Error(`Checklist parameter with ID ${itemId} not found in template ${templateId}`);
      error.statusCode = 404;
      throw error;
    }
    const item = mergeTemplateItemPatch(template.checklist_items[itemIndex], patch);
    if (template.checklist_items.some((candidate, index) => index !== itemIndex && candidate.position === item.position)) {
      const error = new Error(`Checklist position ${item.position} already exists in template ${templateId}`);
      error.statusCode = 409;
      throw error;
    }
    template.checklist_items[itemIndex] = item;
    template.checklist_items.sort((left, right) => left.position - right.position || left.id.localeCompare(right.id));
    template.updated_at = new Date().toISOString();
    templates[templateIndex] = template;
    this._write(templates);
    return item;
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
