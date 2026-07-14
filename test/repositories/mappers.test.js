const test = require('node:test');
const assert = require('node:assert/strict');
const { templateSchema } = require('../../src/contracts/template.contract');
const { reportSchema } = require('../../src/contracts/report.contract');
const { mapTemplateAggregate, mapReportAggregate } = require('../../src/repositories/postgres/mappers');

test('template rows map to the canonical nested contract', () => {
  const template = mapTemplateAggregate({
    id: 'MAT-1', type: 'MATERIAL', name: 'Material', description: '', form_code: 'F-1',
    category: 'Pole', segment: 'construction', standard_code: 'STD-1', is_active: true,
    workflow_status: 'IN_PROGRESS', version: 1, migration_metadata: null,
    created_at: new Date('2026-01-01T00:00:00.000Z'),
    updated_at: new Date('2026-01-02T00:00:00.000Z')
  }, [{
    template_id: 'MAT-1', id: 'I-1', parameter_name: 'Length', input_type: 'number',
    standard_text: '10', unit: 'm', is_required: true, required_photo: true,
    is_active: true, is_critical: true, position: 0, choices: [], category: 'Dimension',
    validation_type: 'range', validation_min_value: '9.5', validation_max_value: '10.5',
    validation_exact_value: null, migration_metadata: null
  }]);

  assert.equal(template.checklist_items[0].validation_rule.min_value, 9.5);
  assert.equal(template.created_at, '2026-01-01T00:00:00.000Z');
  assert.doesNotThrow(() => templateSchema.parse(template));
});

test('report rows and attachment rows map to the canonical nested contract', () => {
  const report = mapReportAggregate({
    id: 'QC-1', type: 'MATERIAL', template_id: 'MAT-1', form_code: 'F-1', title: 'QC',
    status: 'SUBMITTED', staff_name: 'Ayu', staff_nik: 'N-1', site_id: 'S-1',
    site_name: 'Site', area: 'A', detail_location: 'Bay', general_info: { batch: 'B' },
    staff_note: '', submitted_at: new Date('2026-01-03T00:00:00.000Z'),
    revision_number: 1, migration_metadata: null
  }, [{
    report_id: 'QC-1', id: 'I-1', parameter_name: 'Length', input_type: 'number',
    standard_text: '10', unit: 'm', actual_value: '9.8', staff_note: '',
    admin_evaluation: 'PENDING', admin_note: ''
  }], null, [
    { id: 1, attachment_scope: 'GENERAL', report_item_id: null, uri: 'general.jpg' },
    { id: 2, attachment_scope: 'ITEM', report_item_id: 'I-1', uri: 'item.jpg' }
  ]);

  assert.deepEqual(report.general_photos, ['general.jpg']);
  assert.deepEqual(report.checklist_items[0].item_photos, ['item.jpg']);
  assert.equal(report.admin_review, null);
  assert.doesNotThrow(() => reportSchema.parse(report));
});
