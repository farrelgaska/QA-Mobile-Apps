const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('=== Starting Full Check Suite ===');

// 1. JavaScript syntax & contract modules validation
console.log('\n1. Checking JS syntax & contract modules compilation...');
try {
  // Load core app and contracts to check syntax
  require('./config/env');
  require('./contracts/common.contract');
  require('./contracts/template.contract');
  require('./contracts/report.contract');
  require('./repositories/json-report.repository');
  require('./repositories/json-template.repository');
  require('./controllers/report.controller');
  require('./controllers/template.controller');
  require('./app');
  console.log('[PASS] All JavaScript modules and contract files compiled successfully without syntax errors.');
} catch (err) {
  console.error('[FAIL] JS syntax / contract check failed:', err.message);
  process.exit(1);
}

// 2. Validate current JSON storage validity
console.log('\n2. Validating active JSON storage files...');
try {
  const reportsPath = path.join(__dirname, '../data/reports.json');
  const templatesPath = path.join(__dirname, '../data/templates.json');

  console.log(' - Checking reports.json...');
  const reportsRaw = fs.readFileSync(reportsPath, 'utf8');
  const reports = JSON.parse(reportsRaw);
  if (!Array.isArray(reports)) {
    throw new Error('reports.json must be a JSON array');
  }
  console.log(`   [OK] reports.json is valid (${reports.length} records)`);

  console.log(' - Checking templates.json...');
  const templatesRaw = fs.readFileSync(templatesPath, 'utf8');
  const templates = JSON.parse(templatesRaw);
  if (!Array.isArray(templates)) {
    throw new Error('templates.json must be a JSON array');
  }
  console.log(`   [OK] templates.json is valid (${templates.length} records)`);
} catch (err) {
  console.error('[FAIL] JSON storage check failed:', err.message);
  process.exit(1);
}

// 3. Run check-contracts script
console.log('\n3. Running contract validator script...');
try {
  const checkContractsPath = path.join(__dirname, '../scripts/check-contracts.js');
  execSync(`node "${checkContractsPath}"`, { stdio: 'inherit' });
  console.log('[PASS] Contract validator script passed.');
} catch (err) {
  console.error('[FAIL] Contract validator script failed.');
  process.exit(1);
}

// 4. Run normalizers against test fixtures
console.log('\n4. Validating normalizers against test fixtures...');
const fixturesDir = path.join(__dirname, '../test/fixtures');
const legacyTemplates = path.join(fixturesDir, 'templates.legacy.json');
const canonicalTemplates = path.join(fixturesDir, 'templates.canonical.json');
const legacyReports = path.join(fixturesDir, 'reports.legacy.json');
const canonicalReports = path.join(fixturesDir, 'reports.canonical.json');

try {
  console.log(' - Running template normalizer...');
  const normTemplatesScript = path.join(__dirname, '../scripts/normalize-templates.js');
  execSync(`node "${normTemplatesScript}" --input "${legacyTemplates}" --output "${canonicalTemplates}"`, { stdio: 'inherit' });
  console.log('   [OK] Template normalizer completed successfully.');

  console.log(' - Running report normalizer...');
  const normReportsScript = path.join(__dirname, '../scripts/normalize-reports.js');
  execSync(`node "${normReportsScript}" --input "${legacyReports}" --output "${canonicalReports}"`, { stdio: 'inherit' });
  console.log('   [OK] Report normalizer completed successfully.');
} catch (err) {
  console.error('[FAIL] Normalizer validation against test fixtures failed.');
  process.exit(1);
}

console.log('\n=== All Checks Passed Successfully! ===');
process.exit(0);
