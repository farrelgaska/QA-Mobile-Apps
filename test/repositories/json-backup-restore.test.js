const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { afterEach, test } = require('node:test');
const {
  backupJsonState,
  restoreJsonState
} = require('../../scripts/json-state');

const temporaryDirectories = [];
const temporaryDirectory = prefix => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  temporaryDirectories.push(directory);
  return directory;
};
const writeState = (directory, { idempotency = true } = {}) => {
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, 'templates.json'), JSON.stringify([
    { id: 'template-1', name: 'Recoverable template', is_active: false }
  ], null, 2));
  fs.writeFileSync(path.join(directory, 'reports.json'), JSON.stringify([
    { id: 'report-1', template_id: 'template-1', template_snapshot: { id: 'template-1' } }
  ], null, 2));
  if (idempotency) {
    fs.writeFileSync(path.join(directory, 'idempotency.json'), JSON.stringify({
      'create_report::test-key': {
        request_hash: 'a'.repeat(64),
        resource_id: 'report-1'
      }
    }, null, 2));
  }
};

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('JSON backup captures reports, templates, empty idempotency state, and checksums', () => {
  const source = temporaryDirectory('qa-json-source-');
  const backupParent = temporaryDirectory('qa-json-backups-');
  const destination = path.join(backupParent, 'backup-1');
  writeState(source, { idempotency: false });

  const { manifest } = backupJsonState({ source, destination, forbiddenRoot: __dirname });

  assert.deepStrictEqual(JSON.parse(fs.readFileSync(path.join(destination, 'idempotency.json'))), {});
  assert.strictEqual(manifest.files['templates.json'].records, 1);
  assert.strictEqual(manifest.files['reports.json'].records, 1);
  assert.strictEqual(manifest.files['idempotency.json'].records, 0);
  assert.match(manifest.files['reports.json'].sha256, /^[a-f0-9]{64}$/);
});

test('JSON backup refuses missing runtime state and existing destinations', () => {
  const source = temporaryDirectory('qa-json-source-');
  const destination = temporaryDirectory('qa-json-existing-');
  fs.writeFileSync(path.join(source, 'reports.json'), '[]');

  assert.throws(
    () => backupJsonState({ source, destination: path.join(source, 'backup'), forbiddenRoot: __dirname }),
    /Missing required JSON state file: templates.json/
  );
  writeState(source);
  assert.throws(
    () => backupJsonState({ source, destination, forbiddenRoot: __dirname }),
    /already exists/
  );
});

test('disposable JSON recovery drill restores exact state and retains a safety copy', () => {
  const target = temporaryDirectory('qa-json-target-');
  const backupParent = temporaryDirectory('qa-json-backups-');
  const backup = path.join(backupParent, 'backup-1');
  writeState(target);
  const originalReports = fs.readFileSync(path.join(target, 'reports.json'), 'utf8');
  backupJsonState({ source: target, destination: backup, forbiddenRoot: __dirname });

  fs.writeFileSync(path.join(target, 'reports.json'), '[]');
  fs.writeFileSync(path.join(target, 'templates.json'), '[]');
  fs.writeFileSync(path.join(target, 'idempotency.json'), '{}');
  const result = restoreJsonState({
    source: backup,
    target,
    confirmReplace: true,
    environment: { APP_ENV: 'development' }
  });
  temporaryDirectories.push(result.safetyDirectory);

  assert.strictEqual(fs.readFileSync(path.join(target, 'reports.json'), 'utf8'), originalReports);
  assert.deepStrictEqual(JSON.parse(fs.readFileSync(path.join(target, 'idempotency.json'))), {
    'create_report::test-key': {
      request_hash: 'a'.repeat(64),
      resource_id: 'report-1'
    }
  });
  assert.deepStrictEqual(JSON.parse(
    fs.readFileSync(path.join(result.safetyDirectory, 'reports.json'), 'utf8')
  ), []);
});

test('JSON restore requires confirmation and rejects tampered backup before replacement', () => {
  const target = temporaryDirectory('qa-json-target-');
  const backupParent = temporaryDirectory('qa-json-backups-');
  const backup = path.join(backupParent, 'backup-1');
  writeState(target);
  backupJsonState({ source: target, destination: backup, forbiddenRoot: __dirname });
  const originalReports = fs.readFileSync(path.join(target, 'reports.json'), 'utf8');

  assert.throws(
    () => restoreJsonState({ source: backup, target }),
    /--confirm-replace/
  );
  assert.throws(
    () => restoreJsonState({
      source: backup,
      target,
      confirmReplace: true,
      environment: { APP_ENV: 'production' }
    }),
    /disabled when APP_ENV=production/
  );
  fs.writeFileSync(path.join(backup, 'reports.json'), '[]');
  assert.throws(
    () => restoreJsonState({
      source: backup,
      target,
      confirmReplace: true,
      environment: { APP_ENV: 'development' }
    }),
    /Checksum mismatch/
  );
  assert.strictEqual(fs.readFileSync(path.join(target, 'reports.json'), 'utf8'), originalReports);
});
