const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {
  normalizeReportSampleFields
} = require('../../src/contracts/report.contract');
const { JsonReportRepository } = require('../../src/repositories/json-report.repository');
const { PostgresReportRepository } = require('../../src/repositories/postgres-report.repository');
const {
  mapReportAggregate
} = require('../../src/repositories/postgres/mappers');

const AT = '2026-07-27T10:00:00.000Z';

const answer = (adminEvaluation, adminNote) => ({
  checklist_item_id: 'dimension',
  input_type: 'number',
  actual_value: 8.9,
  note: 'Catatan inspeksi Staff',
  photo_paths: [],
  standard_text: '10 mm',
  standard_value: 10,
  unit: 'mm',
  upper_tolerance: 5,
  lower_tolerance: -5,
  minimum_value: 9.5,
  maximum_value: 10.5,
  evaluation_status: 'OUT_OF_STANDARD',
  admin_evaluation: adminEvaluation,
  admin_note: adminNote
});

const sample = (id, number, adminEvaluation, adminNote) => ({
  id,
  sample_number: number,
  inspection_status: 'COMPLETED',
  checklist_answers: [answer(adminEvaluation, adminNote)],
  notes: `Catatan sampel ${number}`,
  photo_paths: [],
  created_at: AT,
  updated_at: AT
});

const report = () => ({
  id: 'QC-SAMPLE-ADMIN-REVIEWS',
  type: 'MATERIAL',
  title: 'Sample-scoped Admin reviews',
  status: 'SUBMITTED',
  staff: { name: 'Warehouse Staff', nik: 'WH-1' },
  location: {},
  checklist_items: [],
  sample_count: 2,
  samples: [
    sample('sample-1', 1, 'PASS', 'Sampel satu diterima'),
    sample('sample-2', 2, 'FAIL', 'Sampel dua harus diganti')
  ]
});

class RecordingPool {
  constructor() {
    this.queries = [];
    this.client = {
      query: async (text, parameters = []) => {
        this.queries.push({ text, parameters });
        return { rows: [], rowCount: 0 };
      },
      release: () => {}
    };
  }

  async connect() {
    return this.client;
  }
}

test('legacy sample answers default to an independent unevaluated Admin state', () => {
  const input = report();
  delete input.samples[0].checklist_answers[0].admin_evaluation;
  delete input.samples[0].checklist_answers[0].admin_note;

  const normalized = normalizeReportSampleFields(input);
  assert.equal(
    normalized.samples[0].checklist_answers[0].admin_evaluation,
    'NEEDS_REVIEW'
  );
  assert.equal(normalized.samples[0].checklist_answers[0].admin_note, '');
  assert.equal(
    normalized.samples[0].checklist_answers[0].evaluation_status,
    'OUT_OF_STANDARD'
  );
  assert.equal(
    normalized.samples[0].checklist_answers[0].note,
    'Catatan inspeksi Staff'
  );
});

test('same checklist item ID persists different Admin values for each sample', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'sample-admin-review-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const filePath = path.join(directory, 'reports.json');
  fs.writeFileSync(filePath, '[]');

  new JsonReportRepository(filePath).create(report());
  const restored = new JsonReportRepository(filePath).findById(
    'QC-SAMPLE-ADMIN-REVIEWS'
  );

  assert.deepEqual(
    restored.samples.map(entry => [
      entry.id,
      entry.checklist_answers[0].checklist_item_id,
      entry.checklist_answers[0].admin_evaluation,
      entry.checklist_answers[0].admin_note
    ]),
    [
      ['sample-1', 'dimension', 'PASS', 'Sampel satu diterima'],
      ['sample-2', 'dimension', 'FAIL', 'Sampel dua harus diganti']
    ]
  );
});

test('PostgreSQL writes sample Admin values beside the composite answer identity', async () => {
  const pool = new RecordingPool();
  await new PostgresReportRepository(pool).create(report());
  const writes = pool.queries.filter(query =>
    query.text.includes('insert into public.qc_report_sample_answers'));

  assert.equal(writes.length, 1);
  assert.deepEqual(
    [0, 18].map(offset => [
      writes[0].parameters[offset + 1],
      writes[0].parameters[offset + 2],
      writes[0].parameters[offset + 15],
      writes[0].parameters[offset + 16]
    ]),
    [
      ['sample-1', 'dimension', 'PASS', 'Sampel satu diterima'],
      ['sample-2', 'dimension', 'FAIL', 'Sampel dua harus diganti']
    ]
  );
});

test('PostgreSQL API mapping restores sample-scoped reviews without changing Mobile fields', () => {
  const mapped = mapReportAggregate({
    id: 'QC-SAMPLE-ADMIN-REVIEWS',
    type: 'MATERIAL',
    title: 'Sample-scoped Admin reviews',
    status: 'SUBMITTED',
    staff_name: 'Warehouse Staff',
    staff_nik: 'WH-1',
    general_info: {},
    sample_count: 2,
    revision_number: 1
  }, [], null, [], [{
    report_id: 'QC-SAMPLE-ADMIN-REVIEWS',
    id: 'sample-1',
    sample_number: 1,
    inspection_status: 'COMPLETED',
    notes: 'Catatan sampel 1',
    photo_paths: [],
    position: 0,
    created_at: AT,
    updated_at: AT
  }, {
    report_id: 'QC-SAMPLE-ADMIN-REVIEWS',
    id: 'sample-2',
    sample_number: 2,
    inspection_status: 'COMPLETED',
    notes: 'Catatan sampel 2',
    photo_paths: [],
    position: 1,
    created_at: AT,
    updated_at: AT
  }], [{
    report_id: 'QC-SAMPLE-ADMIN-REVIEWS',
    sample_id: 'sample-1',
    ...answer('PASS', 'Sampel satu diterima'),
    position: 0
  }, {
    report_id: 'QC-SAMPLE-ADMIN-REVIEWS',
    sample_id: 'sample-2',
    ...answer('FAIL', 'Sampel dua harus diganti'),
    position: 0
  }]);

  assert.deepEqual(
    mapped.samples.map(entry => [
      entry.id,
      entry.checklist_answers[0].admin_evaluation,
      entry.checklist_answers[0].admin_note,
      entry.checklist_answers[0].evaluation_status,
      entry.checklist_answers[0].note
    ]),
    [
      [
        'sample-1',
        'PASS',
        'Sampel satu diterima',
        'OUT_OF_STANDARD',
        'Catatan inspeksi Staff'
      ],
      [
        'sample-2',
        'FAIL',
        'Sampel dua harus diganti',
        'OUT_OF_STANDARD',
        'Catatan inspeksi Staff'
      ]
    ]
  );
});

test('sample Admin review migration is additive and composite-identity scoped', () => {
  const migration = fs.readFileSync(path.join(
    __dirname,
    '../../supabase/migrations/20260727000100_add_sample_admin_reviews.sql'
  ), 'utf8');

  assert.match(migration, /add column if not exists admin_evaluation/i);
  assert.match(migration, /add column if not exists admin_note/i);
  assert.match(migration, /'PASS', 'FAIL', 'NEEDS_REVIEW'/i);
  assert.match(
    migration,
    /report_id,\s*sample_id,\s*admin_evaluation/i
  );
  assert.doesNotMatch(migration, /\bdrop\s+(table|column)\b/i);
  assert.match(migration, /^\s*begin;/i);
  assert.match(migration, /commit;\s*$/i);
});
