const fs = require('fs');
const path = require('path');
const {
  APP_ENV,
  DATA_PROVIDER,
  REPORTS_FILE
} = require('../src/config/env');
const { reportSchema } = require('../src/contracts/report.contract');
const { assertSafeToMutate } = require('./seed/guard');
const { createSafetyCopy, writeAtomically } = require('./json-state');

const PRODUCTION_REPORTS_URL = 'https://qa-mobile-api.vercel.app/reports';
const DEFAULT_SNAPSHOT_FILE = path.join(
  __dirname,
  '../data/regression/production-reports.json'
);
const DEFAULT_IDEMPOTENCY_FILE = path.join(path.dirname(REPORTS_FILE), 'idempotency.json');

const summarizeReports = reports => ({
  total: reports.length,
  visible: reports.filter(report => report.status !== 'DRAFT').length,
  statuses: Object.fromEntries(
    Object.entries(Object.groupBy(reports, report => report.status))
      .map(([status, records]) => [status, records.length])
  )
});

const sanitizeEvidence = report => {
  let removedEvidenceReferences = 0;
  let removedEvidenceMetadata = 0;
  const sanitized = structuredClone(report);
  const clear = owner => {
    for (const field of ['general_photos', 'item_photos', 'photo_paths']) {
      if (!Array.isArray(owner?.[field])) continue;
      removedEvidenceReferences += owner[field].length;
      owner[field] = [];
    }
  };

  clear(sanitized);
  (sanitized.checklist_items ?? []).forEach(clear);
  (sanitized.samples ?? []).forEach(sample => {
    clear(sample);
    (sample.checklist_answers ?? []).forEach(clear);
  });

  const metadata = sanitized.general_info?.qcEvidenceCaptureMetadata;
  if (metadata && typeof metadata === 'object' && !Array.isArray(metadata)) {
    removedEvidenceMetadata = Object.keys(metadata).length;
    delete sanitized.general_info.qcEvidenceCaptureMetadata;
  }

  return { sanitized, removedEvidenceReferences, removedEvidenceMetadata };
};

const validateProductionReports = payload => {
  if (!Array.isArray(payload) || payload.length === 0) {
    throw new Error('Production reports response must be a non-empty JSON array');
  }

  const ids = new Set();
  let removedEvidenceReferences = 0;
  let removedEvidenceMetadata = 0;
  const reports = payload.map((rawReport, index) => {
    const sanitized = sanitizeEvidence(rawReport);
    removedEvidenceReferences += sanitized.removedEvidenceReferences;
    removedEvidenceMetadata += sanitized.removedEvidenceMetadata;
    const result = reportSchema.safeParse(sanitized.sanitized);
    if (!result.success) {
      const details = result.error.issues
        .map(issue => `${issue.path.join('.') || 'report'}: ${issue.message}`)
        .join('; ');
      throw new Error(`Invalid production report at index ${index}: ${details}`);
    }
    if (ids.has(result.data.id)) {
      throw new Error(`Production reports response contains duplicate id ${result.data.id}`);
    }
    ids.add(result.data.id);
    return result.data;
  });

  reports.sort((left, right) => {
    const timestampDifference = Date.parse(right.submitted_at || 0) -
      Date.parse(left.submitted_at || 0);
    return timestampDifference || left.id.localeCompare(right.id);
  });

  return { reports, removedEvidenceReferences, removedEvidenceMetadata };
};

const validateSnapshot = snapshot => {
  if (!snapshot || snapshot.schema_version !== 1 ||
      snapshot.source !== PRODUCTION_REPORTS_URL ||
      Number.isNaN(Date.parse(snapshot.captured_at))) {
    throw new Error('Production regression snapshot metadata is invalid');
  }
  return validateProductionReports(snapshot.reports);
};

const pullProductionSnapshot = async ({
  fetchImpl = fetch,
  snapshotFile = DEFAULT_SNAPSHOT_FILE,
  force = false,
  now = () => new Date()
} = {}) => {
  if (fs.existsSync(snapshotFile) && !force) {
    throw new Error(`Snapshot already exists: ${snapshotFile}. Pass --force to refresh it.`);
  }
  const response = await fetchImpl(PRODUCTION_REPORTS_URL, {
    method: 'GET',
    headers: { accept: 'application/json' }
  });
  if (!response.ok) {
    throw new Error(`Production reports GET failed with HTTP ${response.status}`);
  }

  let payload;
  try {
    payload = await response.json();
  } catch (error) {
    throw new Error(`Production reports response is not valid JSON: ${error.message}`);
  }
  const validated = validateProductionReports(payload);
  const snapshot = {
    schema_version: 1,
    source: PRODUCTION_REPORTS_URL,
    captured_at: now().toISOString(),
    reports: validated.reports
  };
  writeAtomically(snapshotFile, `${JSON.stringify(snapshot, null, 2)}\n`);
  return { snapshotFile, ...validated, summary: summarizeReports(validated.reports) };
};

const applyProductionSnapshot = ({
  snapshotFile = DEFAULT_SNAPSHOT_FILE,
  reportsFile = REPORTS_FILE,
  idempotencyFile = DEFAULT_IDEMPOTENCY_FILE,
  confirmReplace = false,
  environment = process.env
} = {}) => {
  if (!confirmReplace) {
    throw new Error('Applying a production snapshot requires --confirm-replace');
  }
  assertSafeToMutate(environment);
  const dataProvider = (environment.DATA_PROVIDER || DATA_PROVIDER).trim().toLowerCase();
  if (dataProvider !== 'json') {
    throw new Error('Production snapshot apply supports only DATA_PROVIDER=json');
  }

  let snapshot;
  try {
    snapshot = JSON.parse(fs.readFileSync(snapshotFile, 'utf8'));
  } catch (error) {
    throw new Error(`Cannot read production regression snapshot: ${error.message}`);
  }
  const validated = validateSnapshot(snapshot);
  const targetDirectory = path.dirname(reportsFile);
  const safetyDirectory = createSafetyCopy(targetDirectory);
  writeAtomically(reportsFile, `${JSON.stringify(validated.reports, null, 2)}\n`);
  writeAtomically(idempotencyFile, '{}\n');

  const applied = JSON.parse(fs.readFileSync(reportsFile, 'utf8'));
  const expectedIds = validated.reports.map(report => report.id);
  if (JSON.stringify(applied.map(report => report.id)) !== JSON.stringify(expectedIds)) {
    throw new Error(`Production snapshot apply verification failed; safety copy: ${safetyDirectory}`);
  }
  return {
    reports: applied,
    safetyDirectory,
    summary: summarizeReports(applied)
  };
};

const printSummary = (label, result) => {
  console.log(`${label}: ${result.summary.total} reports (${result.summary.visible} non-draft)`);
  console.log(`Statuses: ${JSON.stringify(result.summary.statuses)}`);
};

const run = async argumentsList => {
  const [command, ...flags] = argumentsList;
  const unknownFlags = flags.filter(flag => !['--force', '--confirm-replace'].includes(flag));
  if (unknownFlags.length > 0) throw new Error(`Unknown argument: ${unknownFlags[0]}`);

  if (command === 'pull') {
    const result = await pullProductionSnapshot({ force: flags.includes('--force') });
    printSummary('Production snapshot saved', result);
    console.log(`Evidence references removed: ${result.removedEvidenceReferences}`);
    console.log(`Evidence metadata entries removed: ${result.removedEvidenceMetadata}`);
    console.log(`Snapshot: ${result.snapshotFile}`);
    return;
  }
  if (command === 'apply') {
    const result = applyProductionSnapshot({
      confirmReplace: flags.includes('--confirm-replace'),
      environment: { ...process.env, APP_ENV, DATA_PROVIDER }
    });
    printSummary('Production snapshot applied', result);
    console.log(`Pre-apply safety copy: ${result.safetyDirectory}`);
    return;
  }
  throw new Error(
    'Usage: production-regression.js pull [--force] | apply --confirm-replace'
  );
};

if (require.main === module) {
  run(process.argv.slice(2)).catch(error => {
    console.error(`[FAIL] ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = {
  PRODUCTION_REPORTS_URL,
  DEFAULT_SNAPSHOT_FILE,
  applyProductionSnapshot,
  pullProductionSnapshot,
  sanitizeEvidence,
  summarizeReports,
  validateProductionReports,
  validateSnapshot
};
