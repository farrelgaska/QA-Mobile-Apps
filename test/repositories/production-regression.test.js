const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { test } = require('node:test');
const { reportSchema } = require('../../src/contracts/report.contract');
const { handleJsonProvider } = require('../../scripts/seed/cli');
const baselineTemplates = require('../../scripts/seed/baseline.json');
const {
  PRODUCTION_REPORTS_URL,
  applyProductionSnapshot,
  pullProductionSnapshot,
  validateProductionReports
} = require('../../scripts/production-regression');

const photoPath = reportId =>
  `reports/${reportId}/general/123e4567-e89b-42d3-a456-426614174000.jpg`;

const report = ({ id = 'REPORT-1', status = 'SUBMITTED' } = {}) => ({
  id,
  type: 'MATERIAL',
  template_id: 'template-1',
  form_code: 'FORM-1',
  title: `Report ${id}`,
  status,
  staff: { name: 'Regression Staff', nik: 'NIK-1' },
  location: { site_id: 'site-1', site_name: 'Site 1', area: 'A', detail_location: 'Rack 1' },
  general_info: {
    qcEvidenceCaptureMetadata: {
      [photoPath(id)]: { capturedAt: '2026-08-28T00:00:00.000Z' }
    }
  },
  checklist_items: [{
    id: 'item-1',
    parameter_name: 'Condition',
    input_type: 'boolean',
    actual_value: 'Ya',
    item_photos: [photoPath(id)],
    admin_evaluation: 'NEEDS_REVIEW'
  }],
  staff_note: '',
  submitted_at: id === 'REPORT-1'
    ? '2026-08-27T00:00:00.000Z'
    : '2026-08-28T00:00:00.000Z',
  admin_review: status === 'APPROVED'
    ? { admin_note: '', conclusion: 'PASSED', reviewed_at: '2026-08-28T01:00:00.000Z' }
    : null,
  general_photos: [photoPath(id)],
  sample_count: 1,
  samples: [],
  template_snapshot: {
    id: 'template-1',
    type: 'MATERIAL',
    name: 'Template 1',
    checklist_items: []
  },
  revision_number: 1
});

const snapshot = reports => ({
  schema_version: 1,
  source: PRODUCTION_REPORTS_URL,
  captured_at: '2026-08-28T02:00:00.000Z',
  reports
});

const temporaryDirectory = t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'qa-production-regression-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return directory;
};

test('production pull uses GET, validates reports, preserves IDs/statuses, and sanitizes evidence', async t => {
  const directory = temporaryDirectory(t);
  const snapshotFile = path.join(directory, 'production-reports.json');
  const calls = [];
  const payload = [report(), report({ id: 'REPORT-2', status: 'APPROVED' })];
  const result = await pullProductionSnapshot({
    snapshotFile,
    now: () => new Date('2026-08-28T02:00:00.000Z'),
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      return { ok: true, status: 200, json: async () => payload };
    }
  });

  assert.deepEqual(calls, [{
    url: PRODUCTION_REPORTS_URL,
    options: { method: 'GET', headers: { accept: 'application/json' } }
  }]);
  assert.equal(result.summary.total, 2);
  assert.deepEqual(result.reports.map(item => item.id), ['REPORT-2', 'REPORT-1']);
  assert.deepEqual(result.reports.map(item => item.status), ['APPROVED', 'SUBMITTED']);
  assert.equal(result.removedEvidenceReferences, 4);
  assert.equal(result.removedEvidenceMetadata, 2);

  const saved = JSON.parse(fs.readFileSync(snapshotFile, 'utf8'));
  assert.deepEqual(saved.reports.map(item => item.id), ['REPORT-2', 'REPORT-1']);
  assert.ok(saved.reports.every(item => reportSchema.safeParse(item).success));
  assert.ok(saved.reports.every(item => item.general_photos.length === 0));
  assert.ok(saved.reports.every(item => item.checklist_items[0].item_photos.length === 0));
  assert.ok(saved.reports.every(item => item.general_info.qcEvidenceCaptureMetadata === undefined));
  assert.equal(saved.reports[0].template_snapshot.id, 'template-1');
});

test('invalid or duplicate production payload fails before creating a snapshot', async t => {
  const directory = temporaryDirectory(t);
  const snapshotFile = path.join(directory, 'production-reports.json');
  await assert.rejects(
    pullProductionSnapshot({
      snapshotFile,
      fetchImpl: async () => ({ ok: true, status: 200, json: async () => ({ reports: [] }) })
    }),
    /non-empty JSON array/
  );
  assert.equal(fs.existsSync(snapshotFile), false);
  assert.throws(
    () => validateProductionReports([report(), report()]),
    /duplicate id REPORT-1/
  );
  assert.throws(
    () => validateProductionReports([{ id: 'BROKEN' }]),
    /Invalid production report/
  );
});

test('apply requires confirmation, preserves report identity, clears idempotency, and keeps templates', async t => {
  const directory = temporaryDirectory(t);
  const reportsFile = path.join(directory, 'reports.json');
  const templatesFile = path.join(directory, 'templates.json');
  const idempotencyFile = path.join(directory, 'idempotency.json');
  const snapshotFile = path.join(directory, 'production-reports.json');
  const reports = [report(), report({ id: 'REPORT-2', status: 'APPROVED' })];
  fs.writeFileSync(reportsFile, JSON.stringify([{ id: 'LOCAL-REPORT' }]));
  fs.writeFileSync(templatesFile, JSON.stringify(baselineTemplates));
  fs.writeFileSync(idempotencyFile, JSON.stringify({ local: { resource_id: 'LOCAL-REPORT' } }));
  fs.writeFileSync(snapshotFile, JSON.stringify(snapshot(reports)));

  assert.throws(
    () => applyProductionSnapshot({ snapshotFile, reportsFile, idempotencyFile }),
    /--confirm-replace/
  );
  assert.deepEqual(JSON.parse(fs.readFileSync(reportsFile, 'utf8')), [{ id: 'LOCAL-REPORT' }]);

  const result = applyProductionSnapshot({
    snapshotFile,
    reportsFile,
    idempotencyFile,
    confirmReplace: true,
    environment: { APP_ENV: 'development', DATA_PROVIDER: 'json', STORAGE_PROVIDER: 'local' }
  });
  assert.deepEqual(result.reports.map(item => item.id), ['REPORT-2', 'REPORT-1']);
  assert.deepEqual(result.reports.map(item => item.status), ['APPROVED', 'SUBMITTED']);
  assert.deepEqual(JSON.parse(fs.readFileSync(idempotencyFile, 'utf8')), {});
  assert.deepEqual(JSON.parse(fs.readFileSync(templatesFile, 'utf8')), baselineTemplates);
  assert.equal(fs.existsSync(path.join(result.safetyDirectory, 'reports.json')), true);

  await handleJsonProvider('reset', reportsFile, templatesFile);
  assert.deepEqual(JSON.parse(fs.readFileSync(reportsFile, 'utf8')), []);
  assert.deepEqual(JSON.parse(fs.readFileSync(idempotencyFile, 'utf8')), {});
  assert.deepEqual(JSON.parse(fs.readFileSync(templatesFile, 'utf8')), baselineTemplates);
});

test('apply is disabled outside local JSON development', t => {
  const directory = temporaryDirectory(t);
  const snapshotFile = path.join(directory, 'production-reports.json');
  fs.writeFileSync(snapshotFile, JSON.stringify(snapshot([report()])));

  assert.throws(
    () => applyProductionSnapshot({
      snapshotFile,
      confirmReplace: true,
      environment: { APP_ENV: 'production', DATA_PROVIDER: 'json' }
    }),
    /STRICTLY PROHIBITED/
  );
  assert.throws(
    () => applyProductionSnapshot({
      snapshotFile,
      confirmReplace: true,
      environment: { APP_ENV: 'development', DATA_PROVIDER: 'postgres' }
    }),
    /supports only DATA_PROVIDER=json/
  );
});
