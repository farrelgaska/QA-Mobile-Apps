const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { JsonReportRepository } = require('../../src/repositories/json-report.repository');
const { PostgresReportRepository } = require('../../src/repositories/postgres-report.repository');
const {
  normalizeReportSampleFields,
  reportSchema
} = require('../../src/contracts/report.contract');

const REPORT_ID = 'QC-MULTI-1';
const ITEM_PHOTO =
  `reports/${REPORT_ID}/checklist/dimension/123e4567-e89b-42d3-a456-426614174000.jpg`;
const SAMPLE_PHOTO =
  `reports/${REPORT_ID}/general/123e4567-e89b-42d3-a456-426614174001.png`;
const CREATED_AT = '2026-07-23T01:00:00.000Z';

const answer = (checklistItemId, inputType, actualValue, overrides = {}) => ({
  checklist_item_id: checklistItemId,
  input_type: inputType,
  actual_value: actualValue,
  note: '',
  photo_paths: [],
  standard_text: '',
  standard_value: null,
  unit: '',
  upper_tolerance: null,
  lower_tolerance: null,
  minimum_value: null,
  maximum_value: null,
  evaluation_status: 'NOT_EVALUATED',
  ...overrides
});

const sample = (id, sampleNumber, overrides = {}) => ({
  id,
  sample_number: sampleNumber,
  inspection_status: 'IN_PROGRESS',
  checklist_answers: [],
  notes: '',
  photo_paths: [],
  created_at: CREATED_AT,
  updated_at: CREATED_AT,
  ...overrides
});

const multiSampleReport = () => ({
  id: REPORT_ID,
  type: 'MATERIAL',
  title: 'Multi-sample material report',
  status: 'DRAFT',
  checklist_items: [],
  sample_count: 2,
  samples: [
    sample('sample-a', 2, {
      inspection_status: 'COMPLETED',
      notes: 'First recorded sample',
      photo_paths: [SAMPLE_PHOTO],
      checklist_answers: [
        answer('dimension', 'number', 3.1, {
          note: 'Measured at midpoint',
          photo_paths: [ITEM_PHOTO],
          standard_text: '2,9 mm +15% / -12,5%',
          standard_value: 2.9,
          unit: 'mm',
          upper_tolerance: 15,
          lower_tolerance: -12.5,
          minimum_value: 2.5375,
          maximum_value: 3.335,
          evaluation_status: 'WITHIN_STANDARD'
        }),
        answer('accepted', 'boolean', true)
      ]
    }),
    sample('sample-b', 1, {
      checklist_answers: [
        answer('surface', 'choice', 'smooth'),
        answer('remarks', 'text', 'No visible cracks')
      ]
    })
  ]
});

const repositoryFixture = t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mock-api-multi-sample-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const filePath = path.join(directory, 'reports.json');
  fs.writeFileSync(filePath, '[]');
  return { filePath, repository: new JsonReportRepository(filePath) };
};

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

test('creates and reads multiple samples in recorded order', t => {
  const { repository } = repositoryFixture(t);
  repository.create(multiSampleReport());

  const restored = repository.findById(REPORT_ID);
  assert.equal(restored.sample_count, 2);
  assert.deepEqual(restored.samples.map(entry => entry.id), ['sample-a', 'sample-b']);
  assert.deepEqual(restored.samples.map(entry => entry.sample_number), [2, 1]);
  assert.doesNotThrow(() => reportSchema.parse({
    ...restored,
    template_id: '',
    form_code: '',
    staff: {},
    location: {},
    general_info: {},
    staff_note: '',
    submitted_at: null,
    admin_review: null,
    general_photos: [],
    revision_number: 1
  }));
});

test('updating one sample preserves every field in the other sample', t => {
  const { repository } = repositoryFixture(t);
  const created = repository.create(multiSampleReport());
  const untouched = structuredClone(created.samples[1]);
  const updatedSample = structuredClone(created.samples[0]);
  updatedSample.notes = 'Updated first sample only';
  updatedSample.updated_at = '2026-07-23T02:00:00.000Z';

  const updated = repository.update(REPORT_ID, { samples: [updatedSample] });

  assert.equal(updated.samples[0].notes, 'Updated first sample only');
  assert.deepEqual(updated.samples[1], untouched);
  assert.deepEqual(updated.samples.map(entry => entry.id), ['sample-a', 'sample-b']);
});

test('submitting a draft preserves its complete sample collection', t => {
  const { repository } = repositoryFixture(t);
  const created = repository.create(multiSampleReport());

  const submitted = repository.update(REPORT_ID, {
    status: 'SUBMITTED',
    submitted_at: '2026-07-23T03:00:00.000Z'
  });

  assert.equal(submitted.status, 'SUBMITTED');
  assert.equal(submitted.submitted_at, '2026-07-23T03:00:00.000Z');
  assert.deepEqual(submitted.samples, created.samples);
});

test('draft save and restore preserves answers, standards, evaluations, notes, and photos', t => {
  const { filePath, repository } = repositoryFixture(t);
  repository.create(multiSampleReport());
  const restored = new JsonReportRepository(filePath).findById(REPORT_ID);
  const first = restored.samples[0];
  const dimension = first.checklist_answers[0];

  assert.equal(first.notes, 'First recorded sample');
  assert.deepEqual(first.photo_paths, [SAMPLE_PHOTO]);
  assert.equal(dimension.standard_text, '2,9 mm +15% / -12,5%');
  assert.equal(dimension.minimum_value, 2.5375);
  assert.equal(dimension.maximum_value, 3.335);
  assert.equal(dimension.evaluation_status, 'WITHIN_STANDARD');
  assert.deepEqual(dimension.photo_paths, [ITEM_PHOTO]);
  assert.deepEqual(
    restored.samples.flatMap(entry => entry.checklist_answers)
      .map(entry => entry.actual_value),
    [3.1, true, 'smooth', 'No visible cracks']
  );
});

test('PostgreSQL aggregate writes ordered sample and answer records', async () => {
  const pool = new RecordingPool();
  await new PostgresReportRepository(pool).create(multiSampleReport());

  const sampleWrites = pool.queries.filter(query =>
    query.text.includes('insert into public.qc_report_samples'));
  const answerWrites = pool.queries.filter(query =>
    query.text.includes('insert into public.qc_report_sample_answers'));

  assert.equal(sampleWrites.length, 2);
  assert.deepEqual(sampleWrites.map(query => query.parameters[1]), ['sample-a', 'sample-b']);
  assert.deepEqual(sampleWrites.map(query => query.parameters[6]), [0, 1]);
  assert.equal(answerWrites.length, 4);
  assert.equal(answerWrites[0].parameters[4], '3.1');
  assert.equal(answerWrites[1].parameters[4], 'true');
  assert.equal(answerWrites[0].parameters[7], '2,9 mm +15% / -12,5%');
  assert.deepEqual(answerWrites[0].parameters[6], [ITEM_PHOTO]);
});

test('canonical object paths are unchanged and URL photo references are rejected', t => {
  const { repository } = repositoryFixture(t);
  const created = repository.create(multiSampleReport());
  assert.equal(created.samples[0].photo_paths[0], SAMPLE_PHOTO);
  assert.equal(created.samples[0].checklist_answers[0].photo_paths[0], ITEM_PHOTO);

  const malformed = multiSampleReport();
  malformed.id = 'QC-MULTI-BAD-PHOTO';
  malformed.samples[0].photo_paths = ['https://example.test/signed-image.jpg'];
  assert.throws(
    () => repository.create(malformed),
    error => error.statusCode === 400 && /canonical QC evidence object_path/.test(error.message)
  );
});

test('duplicate sample numbers and IDs are rejected with validation errors', () => {
  const duplicateNumber = multiSampleReport();
  duplicateNumber.samples[1].sample_number = duplicateNumber.samples[0].sample_number;
  assert.throws(
    () => normalizeReportSampleFields(duplicateNumber),
    error => error.statusCode === 400 && /duplicate sample_number/.test(error.message)
  );

  const duplicateId = multiSampleReport();
  duplicateId.samples[1].id = duplicateId.samples[0].id;
  assert.throws(
    () => normalizeReportSampleFields(duplicateId),
    error => error.statusCode === 400 && /duplicate sample id/.test(error.message)
  );
});

test('invalid sample_count values are rejected', () => {
  for (const sampleCount of [0, -1, 1.5, '2']) {
    assert.throws(
      () => normalizeReportSampleFields({ sample_count: sampleCount, samples: [] }),
      error => error.statusCode === 400 && /sample_count/.test(error.message)
    );
  }
});

test('legacy reports load with additive defaults and keep the root checklist', t => {
  const { filePath, repository } = repositoryFixture(t);
  fs.writeFileSync(filePath, JSON.stringify([{
    id: 'QC-LEGACY',
    type: 'MATERIAL',
    title: 'Legacy',
    status: 'DRAFT',
    checklist_items: [{ id: 'legacy-item', actual_value: 'kept' }]
  }]));

  const restored = repository.findById('QC-LEGACY');
  assert.equal(restored.sample_count, 1);
  assert.deepEqual(restored.samples, []);
  assert.equal(restored.checklist_items[0].actual_value, 'kept');
});

test('sample-level overall result is not inferred or persisted', t => {
  const { repository } = repositoryFixture(t);
  const report = multiSampleReport();
  report.samples[0].overall_result = 'FAILED';
  report.samples[0].result = 'FAILED';

  const restored = repository.create(report);
  assert.equal('overall_result' in restored.samples[0], false);
  assert.equal('result' in restored.samples[0], false);
});

test('malformed sample payload receives a structured HTTP 400 response', async t => {
  process.env.DATA_PROVIDER = 'json';
  delete process.env.VERCEL;
  const app = require('../../src/app');
  const server = app.listen(0);
  t.after(() => server.close());
  await new Promise(resolve => server.once('listening', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const malformed = multiSampleReport();
  malformed.id = 'QC-MULTI-HTTP-INVALID';
  malformed.samples[1].sample_number = malformed.samples[0].sample_number;

  const originalConsoleError = console.error;
  console.error = () => {};
  try {
    const response = await fetch(`${baseUrl}/reports`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(malformed)
    });
    assert.equal(response.status, 400);
    const body = await response.json();
    assert.deepEqual(Object.keys(body), ['error']);
    assert.match(body.error, /duplicate sample_number/);
  } finally {
    console.error = originalConsoleError;
  }
});

test('multi-sample migration is additive and declares required integrity constraints', () => {
  const migrationPath = path.join(
    __dirname,
    '../../supabase/migrations/20260723000100_add_qc_report_samples.sql'
  );
  const migration = fs.readFileSync(migrationPath, 'utf8');

  assert.match(migration, /add column sample_count integer not null default 1/i);
  assert.match(migration, /create table public\.qc_report_samples/i);
  assert.match(migration, /create table public\.qc_report_sample_answers/i);
  assert.match(migration, /unique \(report_id, sample_number\)/i);
  assert.match(migration, /unique \(report_id, sample_id, position\)/i);
  assert.match(migration, /standard_text text not null/i);
  assert.match(
    migration,
    /evaluation_status in \('NOT_EVALUATED', 'WITHIN_STANDARD', 'OUT_OF_STANDARD'\)/i
  );
  assert.doesNotMatch(migration, /\bdrop\s+(table|column)\b/i);
  assert.match(migration, /^\s*begin;/i);
  assert.match(migration, /commit;\s*$/i);
});
