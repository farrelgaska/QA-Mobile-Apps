const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const templateModule = require('../../src/repositories/json-template.repository');
const reportModule = require('../../src/repositories/json-report.repository');
const { EMPTY_REVIEW_REQUEST } = require('../../src/contracts/report.contract');

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
    id: 'MAT-JSON', type: 'MATERIAL', name: 'JSON', checklistItems: [{
      id: 'I-1', parameterName: 'Note', inputType: 'text', standardText: '',
      required: true, requiredPhoto: false
    }]
  };
  const report = { id: 'QC-JSON', type: 'MATERIAL', title: 'JSON', status: 'DRAFT' };

  const createdTemplate = templates.create(template);
  assert.equal(createdTemplate.checklist_items[0].parameter_name, 'Note');
  assert.equal('checklistItems' in createdTemplate, false);
  assert.equal(templates.findById('MAT-JSON').name, 'JSON');
  assert.equal(templates.update('MAT-JSON', { name: 'Updated' }).id, 'MAT-JSON');
  assert.deepEqual(templates.deleteChecklistItem('MAT-JSON', 'I-1').checklist_items, []);
  templates.delete('MAT-JSON');
  assert.equal(templates.findById('MAT-JSON'), undefined);
  assert.throws(() => templates.delete('MAT-MISSING'), error => error.statusCode === 404);

  assert.deepEqual(reports.create(report), {
    ...report,
    sample_count: 1,
    samples: [],
    ...EMPTY_REVIEW_REQUEST
  });
  assert.equal(reports.findById('QC-JSON').status, 'DRAFT');
  assert.equal(reports.update('QC-JSON', { status: 'SUBMITTED' }).status, 'SUBMITTED');
  assert.equal(reports.findAll().length, 1);
  reports.delete('QC-JSON');
  assert.equal(reports.findById('QC-JSON'), undefined);
  assert.throws(() => reports.delete('QC-MISSING'), error => error.statusCode === 404);
});
