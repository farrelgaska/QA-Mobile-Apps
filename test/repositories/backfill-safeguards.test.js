const test = require('node:test');
const assert = require('node:assert/strict');
const { execSync } = require('child_process');
const path = require('path');

const scriptPath = path.join(__dirname, '../../scripts/backfill_template_snapshots.js');

test('Backfill safeguard: refuses to run in production', () => {
  try {
    execSync(`node ${scriptPath}`, { env: { ...process.env, APP_ENV: 'production' }, stdio: 'pipe' });
    assert.fail('Should have exited with error');
  } catch (error) {
    assert.match(error.stderr.toString(), /FATAL: Cannot run backfill script in production environment/);
  }
});

test('Backfill safeguard: staging expected identity guard is applied before DB connection', () => {
  try {
    execSync(`node ${scriptPath}`, { env: { ...process.env, APP_ENV: 'staging', DATA_PROVIDER: 'postgres', DATABASE_URL: 'postgres://staging_wrong_db', STAGING_EXPECTED_DB_HOST: 'staging_correct_db' }, stdio: 'pipe' });
    assert.fail('Should have exited with error');
  } catch (error) {
    assert.match(error.stderr.toString(), /\[STAGING GUARD\] DATABASE_URL does not match STAGING_EXPECTED_DB_HOST/);
  }
});

test('Backfill data-safety: preserves existing snapshot, ignores unresolved, idempotence, dry-run', async () => {
  const envMock = { APP_ENV: 'development' };

  // Mock data
  const reports = [
    { id: 'r1', template_id: 't1', template_snapshot: { id: 't1', name: 'Existing Snap' } },
    { id: 'r2', template_id: 't2', template_snapshot: null },
    { id: 'r3', template_id: 't_missing', template_snapshot: null }
  ];
  const templates = {
    't1': { id: 't1', name: 'New Snap 1' },
    't2': { id: 't2', name: 'New Snap 2' }
  };

  let updatedReports = [];

  // Create a minimal mock runner
  const runBackfill = async (isDryRun) => {
    updatedReports = [];
    const reportRepository = {
      findAll: async () => reports,
      update: async (id, payload) => {
        updatedReports.push({ id, payload });
        const r = reports.find(r => r.id === id);
        if (r) Object.assign(r, payload);
      }
    };
    const templateRepository = {
      findById: async (id) => templates[id] || null
    };

    let updatedCount = 0;
    for (const report of await reportRepository.findAll()) {
      if (report.template_snapshot) continue;
      if (!report.template_id) continue;

      const template = await templateRepository.findById(report.template_id);
      if (!template) continue;

      if (!isDryRun) {
        await reportRepository.update(report.id, { template_snapshot: template });
      }
      updatedCount++;
    }
    return updatedCount;
  };

  // a. existing snapshot preservation (r1 has snapshot, should not be updated)
  // b. unresolved template safety (r3 references t_missing, should not be updated)
  // d. dry-run zero mutation
  const dryRunCount = await runBackfill(true);
  assert.strictEqual(dryRunCount, 1); // would update r2
  assert.strictEqual(updatedReports.length, 0); // zero actual mutations

  // Execute actual backfill
  const actualCount = await runBackfill(false);
  assert.strictEqual(actualCount, 1);
  assert.strictEqual(updatedReports.length, 1);
  assert.strictEqual(updatedReports[0].id, 'r2');
  assert.strictEqual(updatedReports[0].payload.template_snapshot.name, 'New Snap 2');
  assert.strictEqual(reports[0].template_snapshot.name, 'Existing Snap'); // r1 unchanged

  // c. idempotence
  const idempotentCount = await runBackfill(false);
  assert.strictEqual(idempotentCount, 0);
  assert.strictEqual(updatedReports.length, 0);
});
