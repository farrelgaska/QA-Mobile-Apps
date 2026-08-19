const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { JsonReportRepository } = require('../../src/repositories/json-report.repository');
const {
  canonicalReportInput,
  mapReportAggregate
} = require('../../src/repositories/postgres/mappers');

const report = {
  id: 'QC-ADMIN-PARAMETER-NOTE',
  type: 'MATERIAL',
  title: 'Admin parameter note persistence',
  status: 'SUBMITTED',
  staff: { name: 'Warehouse Staff', nik: 'WH-1' },
  location: {},
  checklist_items: [{
    id: 'dimension',
    parameter_name: 'Dimensi',
    input_type: 'number',
    standard_text: '10 mm',
    unit: 'mm',
    actual_value: '8.9',
    staff_note: 'Catatan inspeksi Staff',
    staff_evaluation: 'OUT_OF_STANDARD',
    item_photos: [],
    admin_evaluation: 'FAIL',
    admin_note: 'Ukur ulang dimensi material.'
  }],
  sample_count: 1,
  samples: []
};

test('Admin parameter notes survive repository persistence without replacing Staff notes', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'admin-parameter-note-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const filePath = path.join(directory, 'reports.json');
  fs.writeFileSync(filePath, '[]');

  new JsonReportRepository(filePath).create(report);
  const restored = new JsonReportRepository(filePath).findById(report.id);

  assert.equal(
    restored.checklist_items[0].staff_note,
    'Catatan inspeksi Staff'
  );
  assert.equal(
    restored.checklist_items[0].admin_note,
    'Ukur ulang dimensi material.'
  );
  assert.equal(restored.checklist_items[0].admin_evaluation, 'FAIL');
  assert.equal(
    restored.checklist_items[0].staff_evaluation,
    'OUT_OF_STANDARD'
  );
});

test('PostgreSQL canonical mapping keeps Staff and Admin notes in distinct fields', () => {
  const canonical = canonicalReportInput(report);
  assert.equal(canonical.checklist_items[0].staff_note, 'Catatan inspeksi Staff');
  assert.equal(
    canonical.checklist_items[0].staff_evaluation,
    'OUT_OF_STANDARD'
  );
  assert.equal(
    canonical.checklist_items[0].admin_note,
    'Ukur ulang dimensi material.'
  );

  const mapped = mapReportAggregate({
    id: report.id,
    type: 'MATERIAL',
    title: report.title,
    status: 'SUBMITTED',
    staff_name: 'Warehouse Staff',
    staff_nik: 'WH-1',
    general_info: {},
    sample_count: 1,
    revision_number: 1
  }, [{
    report_id: report.id,
    id: 'dimension',
    parameter_name: 'Dimensi',
    input_type: 'number',
    standard_text: '10 mm',
    unit: 'mm',
    actual_value: '8.9',
    staff_note: 'Catatan inspeksi Staff',
    staff_evaluation: 'OUT_OF_STANDARD',
    admin_evaluation: 'FAIL',
    admin_note: 'Ukur ulang dimensi material.'
  }]);

  assert.equal(
    mapped.checklist_items[0].staff_note,
    'Catatan inspeksi Staff'
  );
  assert.equal(
    mapped.checklist_items[0].admin_note,
    'Ukur ulang dimensi material.'
  );
  assert.equal(
    mapped.checklist_items[0].staff_evaluation,
    'OUT_OF_STANDARD'
  );
});

test('Staff evaluation migration is additive and constrained', () => {
  const migration = fs.readFileSync(
    path.join(
      __dirname,
      '../../supabase/migrations/20260818000100_add_report_item_staff_evaluation.sql'
    ),
    'utf8'
  );
  assert.match(migration, /add column if not exists staff_evaluation/i);
  assert.match(
    migration,
    /staff_evaluation in \(\s*'NOT_EVALUATED',\s*'WITHIN_STANDARD',\s*'OUT_OF_STANDARD'/i
  );
  assert.doesNotMatch(migration, /\bdrop\s+(table|column)\b/i);
});
