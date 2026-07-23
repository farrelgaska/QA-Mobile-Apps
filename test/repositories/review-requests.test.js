const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { JsonReportRepository } = require('../../src/repositories/json-report.repository');
const { PostgresReportRepository } = require('../../src/repositories/postgres-report.repository');
const {
  EMPTY_REVIEW_REQUEST,
  normalizeReportReviewRequestFields,
  reportSchema
} = require('../../src/contracts/report.contract');
const {
  canonicalReportInput,
  mapReportAggregate
} = require('../../src/repositories/postgres/mappers');

const REQUESTED_AT = '2026-07-23T04:00:00.000Z';

const reviewRequest = (overrides = {}) => ({
  review_requested: true,
  review_requested_at: REQUESTED_AT,
  review_requested_by_role: 'STAFF_WAREHOUSE',
  review_failed_sample_count: 2,
  review_failed_sample_ids: ['sample-1', 'sample-2'],
  review_failed_sample_numbers: [1, 2],
  ...overrides
});

const report = (overrides = {}) => ({
  id: 'QC-REVIEW-1',
  type: 'MATERIAL',
  title: 'Review request persistence',
  status: 'SUBMITTED',
  staff: { name: 'Warehouse Staff', nik: 'WH-1' },
  location: {},
  general_info: {},
  checklist_items: [],
  sample_count: 2,
  samples: [],
  ...overrides
});

const repositoryFixture = t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mock-api-review-request-'));
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

test('valid review requests accept two or more failed sample snapshots', () => {
  assert.deepEqual(
    normalizeReportReviewRequestFields(report(reviewRequest())),
    reviewRequest()
  );
  const threeSamples = reviewRequest({
    review_failed_sample_count: 3,
    review_failed_sample_ids: ['sample-1', 'sample-2', 'sample-3'],
    review_failed_sample_numbers: [1, 2, 3]
  });
  assert.deepEqual(
    normalizeReportReviewRequestFields(report(threeSamples)),
    threeSamples
  );
});

test('fewer than two failed samples is rejected with HTTP-safe validation metadata', () => {
  assert.throws(
    () => normalizeReportReviewRequestFields(report(reviewRequest({
      review_failed_sample_count: 1,
      review_failed_sample_ids: ['sample-1'],
      review_failed_sample_numbers: [1]
    }))),
    error => error.statusCode === 400 && /at least 2/.test(error.message)
  );
});

test('duplicate failed sample IDs and numbers are rejected', () => {
  assert.throws(
    () => normalizeReportReviewRequestFields(report(reviewRequest({
      review_failed_sample_ids: ['sample-1', 'sample-1']
    }))),
    error => error.statusCode === 400 && /IDs must be unique/.test(error.message)
  );
  assert.throws(
    () => normalizeReportReviewRequestFields(report(reviewRequest({
      review_failed_sample_numbers: [1, 1]
    }))),
    error => error.statusCode === 400 && /numbers must be unique/.test(error.message)
  );
});

test('snapshot count must match both failed sample arrays', () => {
  assert.throws(
    () => normalizeReportReviewRequestFields(report(reviewRequest({
      review_failed_sample_count: 3
    }))),
    error => error.statusCode === 400 && /must match both failed sample arrays/.test(error.message)
  );
});

test('invalid request timestamps and unauthorized role values are rejected', () => {
  assert.throws(
    () => normalizeReportReviewRequestFields(report(reviewRequest({
      review_requested_at: 'not-a-date'
    }))),
    error => error.statusCode === 400 && /valid date/.test(error.message)
  );
  assert.throws(
    () => normalizeReportReviewRequestFields(report(reviewRequest({
      review_requested_by_role: 'ADMIN'
    }))),
    error => error.statusCode === 400 && /STAFF_WAREHOUSE/.test(error.message)
  );
});

test('non-requested and legacy reports receive empty additive defaults', () => {
  assert.deepEqual(normalizeReportReviewRequestFields(report()), EMPTY_REVIEW_REQUEST);
  assert.deepEqual(normalizeReportReviewRequestFields(report({
    review_requested: false,
    review_requested_at: null,
    review_requested_by_role: null,
    review_failed_sample_count: null,
    review_failed_sample_ids: null,
    review_failed_sample_numbers: null
  })), EMPTY_REVIEW_REQUEST);
  const parsed = reportSchema.parse({
    ...report(),
    template_id: '',
    form_code: '',
    staff_note: '',
    submitted_at: null,
    admin_review: null,
    general_photos: [],
    revision_number: 1
  });
  assert.deepEqual(
    Object.fromEntries(Object.keys(EMPTY_REVIEW_REQUEST).map(key => [key, parsed[key]])),
    EMPTY_REVIEW_REQUEST
  );
});

test('JSON repository persists and reloads the complete review request snapshot', t => {
  const { filePath, repository } = repositoryFixture(t);
  repository.create(report(reviewRequest()));

  const restored = new JsonReportRepository(filePath).findById('QC-REVIEW-1');
  assert.deepEqual(
    Object.fromEntries(Object.keys(reviewRequest()).map(key => [key, restored[key]])),
    reviewRequest()
  );
});

test('unrelated patches preserve an existing immutable review request', t => {
  const { repository } = repositoryFixture(t);
  repository.create(report(reviewRequest()));

  const updated = repository.update('QC-REVIEW-1', {
    staff_note: 'Unrelated note update'
  });
  assert.equal(updated.staff_note, 'Unrelated note update');
  assert.deepEqual(
    Object.fromEntries(Object.keys(reviewRequest()).map(key => [key, updated[key]])),
    reviewRequest()
  );
});

test('existing review requests cannot be cleared or overwritten', t => {
  const { repository } = repositoryFixture(t);
  repository.create(report(reviewRequest()));

  assert.throws(
    () => repository.update('QC-REVIEW-1', { review_requested: false }),
    error => error.statusCode === 400 && /immutable/.test(error.message)
  );
  assert.throws(
    () => repository.update('QC-REVIEW-1', {
      review_failed_sample_ids: ['sample-1', 'sample-3']
    }),
    error => error.statusCode === 400 && /immutable/.test(error.message)
  );
});

test('valid legacy mobile metadata is promoted without removing general_info keys', t => {
  const { filePath, repository } = repositoryFixture(t);
  const generalInfo = {
    batch: 'B-17',
    qcReviewRequested: 'true',
    qcReviewRequestedAt: REQUESTED_AT,
    qcReviewFailedSampleIds: '["sample-1","sample-2"]',
    qcReviewFailedSampleNumbers: '[1,2]',
    qcFailedSampleCount: '2',
    qcReviewRequestEligible: 'true'
  };
  fs.writeFileSync(filePath, JSON.stringify([report({
    id: 'QC-LEGACY-REVIEW',
    general_info: generalInfo
  })]));

  const restored = repository.findById('QC-LEGACY-REVIEW');
  assert.deepEqual(
    Object.fromEntries(Object.keys(reviewRequest()).map(key => [key, restored[key]])),
    reviewRequest()
  );
  assert.deepEqual(restored.general_info, generalInfo);

  const updated = repository.update('QC-LEGACY-REVIEW', { staff_note: 'kept' });
  assert.deepEqual(updated.general_info, generalInfo);
  assert.equal(updated.review_requested_by_role, 'STAFF_WAREHOUSE');
});

test('JSON and PostgreSQL canonical mappings produce equivalent review fields', () => {
  const input = report(reviewRequest());
  const canonical = canonicalReportInput(input);
  const mapped = mapReportAggregate({
    id: input.id,
    type: input.type,
    title: input.title,
    status: input.status,
    staff_name: input.staff.name,
    staff_nik: input.staff.nik,
    general_info: {},
    sample_count: 2,
    revision_number: 1,
    ...reviewRequest()
  });

  for (const key of Object.keys(reviewRequest())) {
    assert.deepEqual(mapped[key], canonical[key]);
  }
});

test('PostgreSQL root writes include the complete review request snapshot', async () => {
  const pool = new RecordingPool();
  await new PostgresReportRepository(pool).create(report(reviewRequest()));
  const rootWrite = pool.queries.find(query =>
    query.text.includes('insert into public.qc_reports'));

  assert.equal(rootWrite.parameters[18], true);
  assert.equal(rootWrite.parameters[19], REQUESTED_AT);
  assert.equal(rootWrite.parameters[20], 'STAFF_WAREHOUSE');
  assert.equal(rootWrite.parameters[21], 2);
  assert.deepEqual(rootWrite.parameters[22], ['sample-1', 'sample-2']);
  assert.deepEqual(rootWrite.parameters[23], [1, 2]);
});

test('creating a review request does not infer an admin decision or report status', t => {
  const { repository } = repositoryFixture(t);
  const created = repository.create(report(reviewRequest()));
  assert.equal(created.status, 'SUBMITTED');
  assert.equal(created.admin_review, undefined);
  assert.equal('review_status' in created, false);
  assert.equal('decision' in created, false);
});

test('malformed review requests return the existing structured HTTP 400 response', async t => {
  process.env.DATA_PROVIDER = 'json';
  delete process.env.VERCEL;
  const app = require('../../src/app');
  const server = app.listen(0);
  t.after(() => server.close());
  await new Promise(resolve => server.once('listening', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const response = await fetch(`${baseUrl}/reports`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(report(reviewRequest({
      review_failed_sample_ids: ['sample-1', 'sample-1']
    })))
  });
  assert.equal(response.status, 400);
  assert.deepEqual(Object.keys(await response.json()), ['error']);
});

test('review-request migration is additive and enforces snapshot integrity', () => {
  const migration = fs.readFileSync(path.join(
    __dirname,
    '../../supabase/migrations/20260723000200_add_qc_material_review_requests.sql'
  ), 'utf8');

  for (const column of Object.keys(reviewRequest())) {
    assert.match(migration, new RegExp(`add column if not exists ${column}`, 'i'));
  }
  assert.match(migration, /review_requested_by_role = 'STAFF_WAREHOUSE'/i);
  assert.match(migration, /review_failed_sample_count >= 2/i);
  assert.match(migration, /qc_reports_review_request_snapshot_check/i);
  assert.doesNotMatch(migration, /\bdrop\s+(table|column)\b/i);
  assert.match(migration, /^\s*begin;/i);
  assert.match(migration, /commit;\s*$/i);
});
