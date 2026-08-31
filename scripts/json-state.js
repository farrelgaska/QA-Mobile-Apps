const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const STATE_FILES = ['templates.json', 'reports.json', 'idempotency.json'];
const REQUIRED_SOURCE_FILES = ['templates.json', 'reports.json'];
const PROJECT_ROOT = path.resolve(__dirname, '..');
const WORKSPACE_ROOT = path.resolve(PROJECT_ROOT, '..');
const DEFAULT_DATA_DIRECTORY = path.join(PROJECT_ROOT, 'data');

require('dotenv').config({ path: path.join(PROJECT_ROOT, '.env') });

const isPlainObject = value =>
  value !== null && typeof value === 'object' && !Array.isArray(value);

const checksum = content => crypto.createHash('sha256').update(content).digest('hex');

const isInside = (candidate, parent) => {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
};

const parseJson = (name, raw) => {
  try {
    return JSON.parse(raw);
  } catch (error) {
    throw new Error(`${name} is not valid JSON: ${error.message}`);
  }
};

const validateRecordArray = (name, records) => {
  if (!Array.isArray(records)) throw new Error(`${name} must contain a JSON array`);
  const ids = new Set();
  records.forEach((record, index) => {
    if (!isPlainObject(record) || typeof record.id !== 'string' || record.id.trim() === '') {
      throw new Error(`${name}[${index}] must be an object with a non-empty id`);
    }
    if (ids.has(record.id)) throw new Error(`${name} contains duplicate id ${record.id}`);
    ids.add(record.id);
  });
  return ids;
};

const validateState = rawFiles => {
  const templates = parseJson('templates.json', rawFiles['templates.json']);
  const reports = parseJson('reports.json', rawFiles['reports.json']);
  const idempotency = parseJson('idempotency.json', rawFiles['idempotency.json']);
  validateRecordArray('templates.json', templates);
  const reportIds = validateRecordArray('reports.json', reports);

  if (!isPlainObject(idempotency)) {
    throw new Error('idempotency.json must contain a JSON object');
  }
  Object.entries(idempotency).forEach(([key, claim]) => {
    if (key.trim() === '' || !isPlainObject(claim)) {
      throw new Error('idempotency.json contains an invalid claim');
    }
    if (!/^[a-f0-9]{64}$/i.test(claim.request_hash || '')) {
      throw new Error(`idempotency claim ${key} has an invalid request_hash`);
    }
    if (typeof claim.resource_id !== 'string' || !reportIds.has(claim.resource_id)) {
      throw new Error(`idempotency claim ${key} references a missing report`);
    }
  });

  return {
    'templates.json': templates.length,
    'reports.json': reports.length,
    'idempotency.json': Object.keys(idempotency).length
  };
};

const readState = (directory, { allowMissingIdempotency = false } = {}) => {
  for (const name of REQUIRED_SOURCE_FILES) {
    if (!fs.existsSync(path.join(directory, name))) {
      throw new Error(`Missing required JSON state file: ${name}`);
    }
  }

  return Object.fromEntries(STATE_FILES.map(name => {
    const filePath = path.join(directory, name);
    if (name === 'idempotency.json' && allowMissingIdempotency && !fs.existsSync(filePath)) {
      return [name, '{}\n'];
    }
    if (!fs.existsSync(filePath)) throw new Error(`Missing required JSON state file: ${name}`);
    return [name, fs.readFileSync(filePath, 'utf8')];
  }));
};

const buildManifest = (rawFiles, counts, kind = 'backup') => ({
  version: 1,
  kind,
  created_at: new Date().toISOString(),
  files: Object.fromEntries(STATE_FILES.map(name => [name, {
    sha256: checksum(rawFiles[name]),
    bytes: Buffer.byteLength(rawFiles[name]),
    records: counts[name]
  }]))
});

const verifyManifest = (directory, rawFiles) => {
  const manifestPath = path.join(directory, 'manifest.json');
  if (!fs.existsSync(manifestPath)) throw new Error('Backup is missing manifest.json');
  const manifest = parseJson('manifest.json', fs.readFileSync(manifestPath, 'utf8'));
  if (manifest.version !== 1 || !isPlainObject(manifest.files)) {
    throw new Error('Unsupported or invalid backup manifest');
  }
  for (const name of STATE_FILES) {
    if (manifest.files[name]?.sha256 !== checksum(rawFiles[name])) {
      throw new Error(`Checksum mismatch for ${name}`);
    }
  }
  return manifest;
};

const backupJsonState = ({
  source = DEFAULT_DATA_DIRECTORY,
  destination,
  forbiddenRoot = WORKSPACE_ROOT
}) => {
  if (!destination) throw new Error('Backup destination is required');
  const sourcePath = path.resolve(source);
  const destinationPath = path.resolve(destination);
  if (isInside(destinationPath, path.resolve(forbiddenRoot))) {
    throw new Error('Backup destination must be outside the project workspace');
  }
  if (fs.existsSync(destinationPath)) {
    throw new Error(`Backup destination already exists: ${destinationPath}`);
  }

  const firstRead = readState(sourcePath, { allowMissingIdempotency: true });
  const counts = validateState(firstRead);
  const secondRead = readState(sourcePath, { allowMissingIdempotency: true });
  if (STATE_FILES.some(name => firstRead[name] !== secondRead[name])) {
    throw new Error('JSON state changed during backup; stop application writers and retry');
  }

  fs.mkdirSync(destinationPath);
  for (const name of STATE_FILES) {
    fs.writeFileSync(path.join(destinationPath, name), firstRead[name], { flag: 'wx' });
  }
  const manifest = buildManifest(firstRead, counts);
  fs.writeFileSync(
    path.join(destinationPath, 'manifest.json'),
    `${JSON.stringify(manifest, null, 2)}\n`,
    { flag: 'wx' }
  );
  return { destination: destinationPath, manifest };
};

const writeAtomically = (filePath, content) => {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const temporary = `${filePath}.${crypto.randomUUID()}.tmp`;
  try {
    fs.writeFileSync(temporary, content, { flag: 'wx' });
    fs.renameSync(temporary, filePath);
  } catch (error) {
    if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
    throw error;
  }
};

const createSafetyCopy = target => {
  const safetyDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'qa-json-pre-restore-'));
  const files = {};
  for (const name of STATE_FILES) {
    const targetFile = path.join(target, name);
    if (!fs.existsSync(targetFile)) continue;
    const content = fs.readFileSync(targetFile, 'utf8');
    files[name] = { sha256: checksum(content), bytes: Buffer.byteLength(content) };
    fs.writeFileSync(path.join(safetyDirectory, name), content, { flag: 'wx' });
  }
  fs.writeFileSync(path.join(safetyDirectory, 'manifest.json'), `${JSON.stringify({
    version: 1,
    kind: 'pre_restore_safety',
    created_at: new Date().toISOString(),
    files
  }, null, 2)}\n`, { flag: 'wx' });
  return safetyDirectory;
};

const restoreJsonState = ({
  source,
  target = DEFAULT_DATA_DIRECTORY,
  confirmReplace = false,
  environment = process.env
}) => {
  if (!source) throw new Error('Restore source is required');
  if (!confirmReplace) throw new Error('Restore requires --confirm-replace');
  if ((environment.APP_ENV || '').trim().toLowerCase() === 'production') {
    throw new Error('JSON restore is disabled when APP_ENV=production');
  }

  const sourcePath = path.resolve(source);
  const targetPath = path.resolve(target);
  const rawFiles = readState(sourcePath);
  verifyManifest(sourcePath, rawFiles);
  validateState(rawFiles);

  const safetyDirectory = createSafetyCopy(targetPath);
  for (const name of STATE_FILES) {
    writeAtomically(path.join(targetPath, name), rawFiles[name]);
  }
  const restored = readState(targetPath);
  validateState(restored);
  if (STATE_FILES.some(name => restored[name] !== rawFiles[name])) {
    throw new Error(`Restore verification failed; safety copy: ${safetyDirectory}`);
  }
  return { source: sourcePath, target: targetPath, safetyDirectory };
};

const parseArguments = argumentsList => {
  const [command, ...tokens] = argumentsList;
  const options = { command };
  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token === '--confirm-replace') {
      options.confirmReplace = true;
      continue;
    }
    if (!['--source', '--destination', '--target'].includes(token) || !tokens[index + 1]) {
      throw new Error(`Unknown or incomplete argument: ${token}`);
    }
    options[token.slice(2)] = tokens[index + 1];
    index += 1;
  }
  return options;
};

const run = argumentsList => {
  const options = parseArguments(argumentsList);
  if (options.command === 'backup') {
    const result = backupJsonState(options);
    console.log(`JSON backup created: ${result.destination}`);
    return;
  }
  if (options.command === 'restore') {
    const result = restoreJsonState(options);
    console.log(`JSON state restored to: ${result.target}`);
    console.log(`Pre-restore safety copy: ${result.safetyDirectory}`);
    return;
  }
  throw new Error('Usage: json-state.js backup --destination <path> [--source <path>] | restore --source <path> [--target <path>] --confirm-replace');
};

if (require.main === module) {
  try {
    run(process.argv.slice(2));
  } catch (error) {
    console.error(`[FAIL] ${error.message}`);
    process.exitCode = 1;
  }
}

module.exports = {
  STATE_FILES,
  backupJsonState,
  createSafetyCopy,
  restoreJsonState,
  writeAtomically,
  validateState,
  verifyManifest
};
