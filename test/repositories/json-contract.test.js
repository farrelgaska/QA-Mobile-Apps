const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const templateModule = require('../../src/repositories/json-template.repository');
const reportModule = require('../../src/repositories/json-report.repository');

test('JSON repositories satisfy the existing repository contract in OS temp', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mock-api-json-repositories-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const templatesPath = path.join(directory, 'templates.json');
  const reportsPath = path.join(directory, 'reports.json');
  fs.writeFileSync(templatesPath, '[]');
  fs.writeFileSync(reportsPath, '[]');

  const templates = new templateModule.JsonTemplateRepository(templatesPath);
  const reports = new reportModule.JsonReportRepository(reportsPath);
  const template = {
    id: 'MAT-JSON', type: 'MATERIAL', name: 'JSON', checklistItems: [{ id: 'I-1' }]
  };
  const report = { id: 'QC-JSON', type: 'MATERIAL', title: 'JSON', status: 'DRAFT' };

  assert.deepEqual(templates.create(template), template);
  assert.equal(templates.findById('MAT-JSON').name, 'JSON');
  assert.equal(templates.update('MAT-JSON', { name: 'Updated' }).id, 'MAT-JSON');
  assert.deepEqual(templates.deleteChecklistItem('MAT-JSON', 'I-1').checklistItems, []);

  assert.deepEqual(reports.create(report), report);
  assert.equal(reports.findById('QC-JSON').status, 'DRAFT');
  assert.equal(reports.update('QC-JSON', { status: 'SUBMITTED' }).status, 'SUBMITTED');
  assert.equal(reports.findAll().length, 1);
});
