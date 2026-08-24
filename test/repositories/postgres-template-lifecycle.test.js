const { test } = require('node:test');
const assert = require('node:assert');
const { PostgresTemplateRepository } = require('../../src/repositories/postgres-template.repository');
const { PostgresReportRepository } = require('../../src/repositories/postgres-report.repository');

class RecordingPool {
  constructor() {
    this.queries = [];
    this.client = {
      query: async (text, parameters = []) => {
        this.queries.push({ text, parameters });
        if (text.includes('select 1 from public.qc_reports where template_id')) {
          return { rows: [{ '?column?': 1 }] };
        }
        return { rows: [], rowCount: 0 };
      },
      release: () => {}
    };
  }

  async connect() {
    return this.client;
  }
}

test('PostgreSQL Provider: immutable historical snapshot and template lifecycle rules (Mocked)', async () => {
  const pool = new RecordingPool();
  const reportRepo = new PostgresReportRepository(pool);

  // 1. Postgres report create persists template_snapshot
  const reportData = {
    id: 'r-1',
    type: 'MATERIAL',
    template_id: 't-1',
    template_snapshot: { id: 't-1', name: 'Snap A', checklist_items: [] },
    title: 'Report',
    status: 'DRAFT',
    sample_count: 1,
    samples: []
  };

  await reportRepo.create(reportData);

  const createQuery = pool.queries.find(q => q.text.includes('insert into public.qc_reports'));
  assert.ok(createQuery, 'Must insert into qc_reports');

  // Verify template_snapshot is passed to pg binding
  // In the real pg client, JSONB parameters can be passed as plain objects.
  // We check parameter index 24 (the 25th argument) matches our snapshot.
  const snapshotParam = createQuery.parameters[24];
  assert.deepEqual(snapshotParam, reportData.template_snapshot, 'template_snapshot object must be passed in query params');

  // 2. referenced template delete is blocked
  const inUse = await reportRepo.isTemplateInUse('t-1');
  assert.strictEqual(inUse, true, 'isTemplateInUse should return true based on mock count=1');

  const checkQuery = pool.queries.find(q => q.text.includes('select 1 from public.qc_reports where template_id'));
  assert.ok(checkQuery, 'Must query qc_reports to check if template is in use');
  assert.strictEqual(checkQuery.parameters[0], 't-1');
});
