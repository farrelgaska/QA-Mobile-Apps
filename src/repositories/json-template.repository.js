const fs = require('fs');
const path = require('path');
const { TEMPLATES_FILE } = require('../config/env');

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
    return this._read();
  }

  findById(id) {
    const templates = this._read();
    return templates.find(t => t.id === id);
  }

  create(template) {
    const templates = this._read();
    if (templates.some(t => t.id === template.id)) {
      const err = new Error(`Template with ID ${template.id} already exists`);
      err.statusCode = 409;
      throw err;
    }
    templates.push(template);
    this._write(templates);
    return template;
  }

  update(id, patchData) {
    const templates = this._read();
    const index = templates.findIndex(t => t.id === id);
    if (index === -1) {
      const err = new Error(`Template with ID ${id} not found`);
      err.statusCode = 404;
      throw err;
    }
    const updated = {
      ...templates[index],
      ...patchData,
      id // Ensure ID is never changed
    };
    templates[index] = updated;
    this._write(templates);
    return updated;
  }

  deleteChecklistItem(templateId, itemId) {
    const templates = this._read();
    const templateIndex = templates.findIndex(t => t.id === templateId);
    if (templateIndex === -1) {
      const err = new Error(`Template with ID ${templateId} not found`);
      err.statusCode = 404;
      throw err;
    }

    const template = templates[templateIndex];
    const itemIndex = template.checklistItems.findIndex(item => item.id === itemId);
    if (itemIndex === -1) {
      const err = new Error(`Checklist parameter with ID ${itemId} not found in template ${templateId}`);
      err.statusCode = 404;
      throw err;
    }

    template.checklistItems.splice(itemIndex, 1);
    template.updatedAt = new Date().toISOString();

    this._write(templates);
    return template;
  }
}

const repository = new JsonTemplateRepository();
repository.JsonTemplateRepository = JsonTemplateRepository;
module.exports = repository;
