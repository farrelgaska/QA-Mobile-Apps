const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');
const { execFileSync, execSync, spawnSync } = require('child_process');

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
const legacyInputTypeTemplates = path.join(fixturesDir, 'templates.input-types.legacy.json');
const unsupportedInputTypeTemplates = path.join(fixturesDir, 'templates.unsupported.legacy.json');
const legacyReports = path.join(fixturesDir, 'reports.legacy.json');
const unfinishedReports = path.join(fixturesDir, 'reports.unfinished.legacy.json');
const invalidFinalReports = path.join(fixturesDir, 'reports.invalid-final.legacy.json');
const quarantineReports = path.join(fixturesDir, 'reports.quarantine.legacy.json');
const quarantineManifest = path.join(fixturesDir, 'reports.quarantine.manifest.json');
const normalizationTempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'mock-api-normalization-'));
const canonicalTemplates = path.join(normalizationTempDir, 'templates.canonical.json');
const canonicalInputTypeTemplates = path.join(normalizationTempDir, 'templates.input-types.canonical.json');
const unsupportedOutput = path.join(normalizationTempDir, 'templates.unsupported.canonical.json');
const canonicalReports = path.join(normalizationTempDir, 'reports.canonical.json');
const canonicalUnfinishedReports = path.join(normalizationTempDir, 'reports.unfinished.canonical.json');
const invalidFinalOutput = path.join(normalizationTempDir, 'reports.invalid-final.canonical.json');
const quarantineProductionOutput = path.join(normalizationTempDir, 'reports.quarantine-production.canonical.json');
const quarantineAuditOutput = path.join(normalizationTempDir, 'reports.quarantine-audit.json');

let normalizationError = null;
try {
  console.log(' - Running template normalizer...');
  const normTemplatesScript = path.join(__dirname, '../scripts/normalize-templates.js');
  execFileSync(process.execPath, [normTemplatesScript, '--input', legacyTemplates, '--output', canonicalTemplates], { stdio: 'inherit' });
  console.log('   [OK] Template normalizer completed successfully.');

  console.log(' - Running legacy input-type and duplicate-ID regressions...');
  const inputTypeResult = spawnSync(
    process.execPath,
    [normTemplatesScript, '--input', legacyInputTypeTemplates, '--output', canonicalInputTypeTemplates],
    { encoding: 'utf8' }
  );
  process.stdout.write(inputTypeResult.stdout || '');
  process.stderr.write(inputTypeResult.stderr || '');
  assert.strictEqual(inputTypeResult.status, 0, 'Legacy input-type regression normalization failed');
  assert.match(
    inputTypeResult.stdout,
    /Migrating genuinely different duplicate checklist ID to "duplicate-source__duplicate_2"/,
    'Duplicate checklist ID migration warning was not emitted'
  );
  const unsupportedResult = spawnSync(
    process.execPath,
    [normTemplatesScript, '--input', unsupportedInputTypeTemplates, '--output', unsupportedOutput],
    { encoding: 'utf8' }
  );
  assert.notStrictEqual(unsupportedResult.status, 0, 'Unsupported input type unexpectedly normalized successfully');
  assert.match(
    `${unsupportedResult.stdout}\n${unsupportedResult.stderr}`,
    /Unsupported input type "slider"/,
    'Unsupported input type did not produce an explicit migration error'
  );
  assert.strictEqual(fs.existsSync(unsupportedOutput), false, 'Unsupported input produced a canonical output file');
  console.log('   [OK] Unsupported input types remain explicit migration errors.');

  console.log(' - Running report normalizer...');
  const normReportsScript = path.join(__dirname, '../scripts/normalize-reports.js');
  execFileSync(process.execPath, [normReportsScript, '--input', legacyReports, '--output', canonicalReports], { stdio: 'inherit' });
  console.log('   [OK] Report normalizer completed successfully.');

  console.log(' - Running report lifecycle/conclusion regressions...');
  const unfinishedResult = spawnSync(
    process.execPath,
    [normReportsScript, '--input', unfinishedReports, '--output', canonicalUnfinishedReports],
    { encoding: 'utf8' }
  );
  process.stdout.write(unfinishedResult.stdout || '');
  process.stderr.write(unfinishedResult.stderr || '');
  assert.strictEqual(unfinishedResult.status, 0, 'Unfinished report conclusion regression failed');
  const invalidFinalResult = spawnSync(
    process.execPath,
    [normReportsScript, '--input', invalidFinalReports, '--output', invalidFinalOutput],
    { encoding: 'utf8' }
  );
  const invalidFinalLogs = `${invalidFinalResult.stdout}\n${invalidFinalResult.stderr}`;
  assert.notStrictEqual(invalidFinalResult.status, 0, 'Invalid final conclusions unexpectedly normalized');
  assert.match(invalidFinalLogs, /refusing to map it to null/);
  assert.match(invalidFinalLogs, /manual resolution required/);
  assert.match(invalidFinalLogs, /\[Report: approved-missing-conclusion\]/);
  assert.match(invalidFinalLogs, /\[Report: follow-up-missing-conclusion\]/);
  assert.strictEqual(fs.existsSync(invalidFinalOutput), false, 'Invalid final reports produced canonical output');
  console.log('   [OK] SUBMITTED may await review; APPROVED and NEEDS_FOLLOW_UP require conclusions.');

  console.log(' - Running explicit report quarantine regressions...');
  const unquarantinedOutput = path.join(normalizationTempDir, 'reports.unquarantined.canonical.json');
  const unquarantinedResult = spawnSync(
    process.execPath,
    [normReportsScript, '--input', quarantineReports, '--output', unquarantinedOutput],
    { encoding: 'utf8' }
  );
  assert.notStrictEqual(unquarantinedResult.status, 0, 'Invalid report normalized without explicit quarantine');
  assert.match(`${unquarantinedResult.stdout}\n${unquarantinedResult.stderr}`, /manual resolution required/);
  assert.strictEqual(fs.existsSync(unquarantinedOutput), false, 'Unquarantined invalid report produced output');

  const quarantineResult = spawnSync(
    process.execPath,
    [
      normReportsScript,
      '--input', quarantineReports,
      '--output', quarantineProductionOutput,
      '--quarantine-manifest', quarantineManifest,
      '--quarantine-output', quarantineAuditOutput
    ],
    { encoding: 'utf8' }
  );
  process.stdout.write(quarantineResult.stdout || '');
  process.stderr.write(quarantineResult.stderr || '');
  assert.strictEqual(quarantineResult.status, 0, 'Explicit report quarantine failed');
  assert.match(quarantineResult.stdout, /Total records read: 2/);
  assert.match(quarantineResult.stdout, /Normalized records: 1/);
  assert.match(quarantineResult.stdout, /Quarantined records: 1/);
  assert.match(quarantineResult.stdout, /Errors encountered: 0/);

  const quarantineSourceRecords = JSON.parse(fs.readFileSync(quarantineReports, 'utf8'));
  const quarantineManifestEntries = JSON.parse(fs.readFileSync(quarantineManifest, 'utf8'));
  const quarantineProductionRecords = JSON.parse(fs.readFileSync(quarantineProductionOutput, 'utf8'));
  const quarantineAuditRecords = JSON.parse(fs.readFileSync(quarantineAuditOutput, 'utf8'));
  assert.deepStrictEqual(quarantineProductionRecords.map(record => record.id), ['production-draft']);
  assert.strictEqual(quarantineAuditRecords.length, 1);
  assert.deepStrictEqual(quarantineAuditRecords[0].record, quarantineSourceRecords[1]);
  assert.strictEqual(quarantineAuditRecords[0].reason, quarantineManifestEntries[0].reason);
  assert.strictEqual(quarantineAuditRecords[0].disposition, quarantineManifestEntries[0].disposition);
  assert.ok(!quarantineProductionRecords.some(record => record.id === quarantineAuditRecords[0].record.id));

  const invalidManifests = [
    {
      name: 'duplicate-ids',
      entries: [quarantineManifestEntries[0], quarantineManifestEntries[0]],
      expected: /duplicate ID/
    },
    {
      name: 'missing-reason',
      entries: [{ id: 'fixture-approved-missing-conclusion', disposition: 'EXCLUDE_FROM_PRODUCTION_MIGRATION' }],
      expected: /non-empty reason/
    },
    {
      name: 'missing-source-id',
      entries: [{ id: 'not-in-source', reason: 'Test missing ID', disposition: 'EXCLUDE_FROM_PRODUCTION_MIGRATION' }],
      expected: /does not exist in the source/
    }
  ];
  invalidManifests.forEach(testCase => {
    const manifestPath = path.join(normalizationTempDir, `${testCase.name}.manifest.json`);
    const productionPath = path.join(normalizationTempDir, `${testCase.name}.canonical.json`);
    const auditPath = path.join(normalizationTempDir, `${testCase.name}.quarantine.json`);
    fs.writeFileSync(manifestPath, JSON.stringify(testCase.entries, null, 2), 'utf8');
    const result = spawnSync(
      process.execPath,
      [
        normReportsScript,
        '--input', quarantineReports,
        '--output', productionPath,
        '--quarantine-manifest', manifestPath,
        '--quarantine-output', auditPath
      ],
      { encoding: 'utf8' }
    );
    assert.notStrictEqual(result.status, 0, `Invalid quarantine manifest ${testCase.name} unexpectedly passed`);
    assert.match(`${result.stdout}\n${result.stderr}`, testCase.expected);
    assert.strictEqual(fs.existsSync(productionPath), false);
    assert.strictEqual(fs.existsSync(auditPath), false);
  });
  console.log('   [OK] Report quarantine is explicit, lossless, and manifest-validated.');

  const [template] = JSON.parse(fs.readFileSync(canonicalTemplates, 'utf8'));
  const [inputTypeTemplate, completedWorkflowTemplate] = JSON.parse(fs.readFileSync(canonicalInputTypeTemplates, 'utf8'));
  const [inputTypeSource] = JSON.parse(fs.readFileSync(legacyInputTypeTemplates, 'utf8'));
  const [report] = JSON.parse(fs.readFileSync(canonicalReports, 'utf8'));
  const [
    draftIncompleteReport,
    submittedWithoutReviewReport,
    submittedPlaceholderReport,
    approvedFailedReport,
    needsFollowUpLegacyReport
  ] = JSON.parse(fs.readFileSync(canonicalUnfinishedReports, 'utf8'));
  const firstTemplateItem = template.checklist_items.find(item => item.id === 'item-legacy-1');
  const secondTemplateItem = template.checklist_items.find(item => item.id === 'item-legacy-2');
  const firstReportItem = report.checklist_items.find(item => item.id === 'item-legacy-1');

  assert.strictEqual(template.standard_code, 'SPLN-LEGACY');
  assert.strictEqual(template.category, 'Tiang Besi');
  assert.deepStrictEqual(firstTemplateItem.choices, ['PASS', 'FAIL']);
  assert.strictEqual(firstTemplateItem.required_photo, true);
  assert.strictEqual(firstTemplateItem.is_critical, true);
  assert.strictEqual(secondTemplateItem.validation_rule.min_value, 80);
  assert.strictEqual(secondTemplateItem.validation_rule.max_value, 150);
  assert.strictEqual(template.migration_metadata.unknown_fields.truly_unknown_field_1, 'value1');
  assert.strictEqual(template.migration_metadata.unknown_fields['checklist_items.item-legacy-2.truly_unknown_field_2'], 'value2');

  assert.strictEqual(inputTypeTemplate.checklist_items.length, inputTypeSource.checklistItems.length);
  assert.strictEqual(inputTypeTemplate.workflow_status, 'IN_PROGRESS');
  assert.strictEqual(inputTypeTemplate.migration_metadata.legacy_workflow_status, '  On   Progress  ');
  assert.strictEqual(completedWorkflowTemplate.workflow_status, 'COMPLETED');
  assert.strictEqual(completedWorkflowTemplate.migration_metadata.legacy_workflow_status, ' selesai ');
  const normalizedInputTypes = Object.fromEntries(
    inputTypeTemplate.checklist_items.map(item => [item.id, item.input_type])
  );
  assert.deepStrictEqual(normalizedInputTypes, {
    'type-booleancheck': 'boolean',
    'type-number': 'number',
    'type-choice-upper': 'choice',
    'type-text': 'text',
    'type-choice-lower': 'choice',
    'type-whitespace': 'boolean',
    'duplicate-source': 'text',
    'duplicate-source__duplicate_2': 'number'
  });
  assert.deepStrictEqual(
    inputTypeTemplate.checklist_items.slice(0, 6).map(item => item.category),
    ['Fisik', 'Dimensi', 'Provisioning', 'Teks', 'Assurance', 'Construction']
  );
  const migratedDuplicate = inputTypeTemplate.checklist_items.find(
    item => item.id === 'duplicate-source__duplicate_2'
  );
  assert.deepStrictEqual(migratedDuplicate.migration_metadata, {
    original_id: 'duplicate-source',
    duplicate_id_occurrence: 2
  });

  assert.strictEqual(draftIncompleteReport.status, 'DRAFT');
  assert.strictEqual(draftIncompleteReport.admin_review.conclusion, null);
  assert.deepStrictEqual(draftIncompleteReport.migration_metadata.conclusion_migration, {
    original_value: '  Belum   Lengkap  ',
    canonical_value: null,
    reason: 'UNFINISHED_REPORT',
    source_status: 'DRAFT'
  });
  assert.strictEqual(submittedWithoutReviewReport.status, 'SUBMITTED');
  assert.strictEqual(submittedWithoutReviewReport.admin_review, null);
  assert.strictEqual(submittedPlaceholderReport.status, 'SUBMITTED');
  assert.strictEqual(submittedPlaceholderReport.admin_review.conclusion, null);
  assert.strictEqual(submittedPlaceholderReport.migration_metadata.conclusion_migration.source_status, 'SUBMITTED');
  assert.strictEqual(approvedFailedReport.status, 'APPROVED');
  assert.strictEqual(approvedFailedReport.admin_review.conclusion, 'NOT_PASSED');
  assert.strictEqual(needsFollowUpLegacyReport.status, 'NEEDS_FOLLOW_UP');
  assert.strictEqual(needsFollowUpLegacyReport.admin_review.conclusion, 'NOT_PASSED');

  assert.deepStrictEqual(report.location, {
    site_id: 'site-1',
    site_name: 'Main Warehouse',
    area: 'Zone A',
    detail_location: 'Corner A'
  });
  assert.deepStrictEqual(report.admin_review, {
    admin_note: 'Passed review',
    conclusion: 'PASSED',
    reviewed_at: '2026-07-09T09:30:00Z',
    reviewed_by: 'Supervisor John'
  });
  assert.deepStrictEqual(report.general_photos, ['report-overview.jpg']);
  assert.strictEqual(report.staff_note, 'Legacy report testing');
  assert.strictEqual(report.revision_number, 1);
  assert.deepStrictEqual(report.migration_metadata.legacy_revision_history, [
    { rev: 1, note: 'initial draft' }
  ]);
  assert.deepStrictEqual(firstReportItem.item_photos, ['photo1.jpg']);
  assert.strictEqual(report.migration_metadata.unknown_fields.truly_unknown_field_3, 'value3');
  assert.strictEqual(report.migration_metadata.unknown_fields['checklist_items.item-legacy-1.truly_unknown_field_4'], 'value4');

  const unknownFieldPaths = [
    ...Object.keys(template.migration_metadata.unknown_fields),
    ...Object.keys(report.migration_metadata.unknown_fields),
    ...Object.keys(inputTypeTemplate.migration_metadata?.unknown_fields || {})
  ].join('\n');
  [
    'standardCode', 'checklistItems', 'adminReview', 'siteId', 'siteName',
    'detailLocation', 'adminNote', 'reviewedAt', 'reviewedBy', 'staffNote',
    'generalPhotos', 'revisionNumber', 'revisionHistory', 'category', 'status'
  ].forEach(alias => {
    assert.ok(!unknownFieldPaths.includes(alias), `Consumed alias was reported as unknown: ${alias}`);
  });
  console.log('   [OK] Canonical alias preservation and unknown-field assertions passed.');
} catch (err) {
  normalizationError = err;
} finally {
  fs.rmSync(normalizationTempDir, { recursive: true, force: true });
}

if (normalizationError) {
  console.error('[FAIL] Normalizer validation against test fixtures failed:', normalizationError.message);
  process.exit(1);
}

console.log('\n=== All Checks Passed Successfully! ===');
process.exit(0);
