const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { describe, it, beforeEach, after } = require('node:test');
const { handleJsonProvider } = require('../../scripts/seed/cli');
const baselineTemplates = require('../../scripts/seed/baseline.json');

describe('Canonical Tooling - JSON Provider', () => {
  const tempDir = path.join(__dirname, 'temp-json-data');
  const tempReports = path.join(tempDir, 'reports.json');
  const tempTemplates = path.join(tempDir, 'templates.json');
  const tempIdempotency = path.join(tempDir, 'idempotency.json');

  beforeEach(() => {
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
    fs.mkdirSync(tempDir, { recursive: true });
  });

  after(() => {
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
  });

  it('reset => produces 0 reports and EXACTLY canonical templates (removes custom)', async () => {
    // Populate dummy report and drifted+custom templates
    fs.writeFileSync(tempReports, JSON.stringify([{ id: 'r1' }]));
    fs.writeFileSync(tempIdempotency, JSON.stringify({ 'create_report::key': { resource_id: 'r1' } }));

    const drifted = JSON.parse(JSON.stringify(baselineTemplates[0]));
    drifted.name = 'Drifted Name';
    const userTemplate = { id: 'user-1', name: 'User Template' };

    fs.writeFileSync(tempTemplates, JSON.stringify([drifted, userTemplate]));

    await handleJsonProvider('reset', tempReports, tempTemplates);

    const reports = JSON.parse(fs.readFileSync(tempReports, 'utf8'));
    assert.strictEqual(reports.length, 0, 'Reports should be completely empty');
    assert.deepStrictEqual(JSON.parse(fs.readFileSync(tempIdempotency, 'utf8')), {});

    const templates = JSON.parse(fs.readFileSync(tempTemplates, 'utf8'));
    assert.strictEqual(templates.length, baselineTemplates.length, 'Should have exactly the canonical templates count');
    assert.strictEqual(templates.find(t => t.id === 'user-1'), undefined, 'Custom template must be removed on reset');
    assert.strictEqual(templates[0].name, baselineTemplates[0].name, 'Drifted template must be restored');
  });

  it('seed => creates canonical templates without touching reports or custom templates', async () => {
    fs.writeFileSync(tempReports, JSON.stringify([{ id: 'r1' }]));
    const idempotency = { 'create_report::key': { resource_id: 'r1' } };
    fs.writeFileSync(tempIdempotency, JSON.stringify(idempotency));
    const userTemplate = { id: 'user-1', name: 'User Template' };
    fs.writeFileSync(tempTemplates, JSON.stringify([userTemplate]));

    await handleJsonProvider('seed', tempReports, tempTemplates);

    const reports = JSON.parse(fs.readFileSync(tempReports, 'utf8'));
    assert.strictEqual(reports.length, 1, 'Reports should be untouched');
    assert.deepStrictEqual(JSON.parse(fs.readFileSync(tempIdempotency, 'utf8')), idempotency);

    const templates = JSON.parse(fs.readFileSync(tempTemplates, 'utf8'));
    assert.strictEqual(templates.length, baselineTemplates.length + 1);
    assert.ok(templates.find(t => t.id === 'user-1'), 'Custom template is preserved on seed');
  });

  it('reseed => results in 0 reports and exactly canonical templates', async () => {
    fs.writeFileSync(tempReports, JSON.stringify([{ id: 'r1' }]));
    fs.writeFileSync(tempIdempotency, JSON.stringify({ 'create_report::key': { resource_id: 'r1' } }));

    await handleJsonProvider('reseed', tempReports, tempTemplates);

    const reports = JSON.parse(fs.readFileSync(tempReports, 'utf8'));
    assert.strictEqual(reports.length, 0);
    assert.deepStrictEqual(JSON.parse(fs.readFileSync(tempIdempotency, 'utf8')), {});

    const templates = JSON.parse(fs.readFileSync(tempTemplates, 'utf8'));
    assert.strictEqual(templates.length, baselineTemplates.length);
  });

  it('seed is idempotent and fixes drift', async () => {
    // Create a drifted version of the first canonical template
    const drifted = JSON.parse(JSON.stringify(baselineTemplates[0]));
    drifted.name = 'Drifted Name';

    // Add a non-canonical user template
    const userTemplate = { id: 'user-1', name: 'User Template' };

    fs.writeFileSync(tempTemplates, JSON.stringify([drifted, userTemplate]));

    await handleJsonProvider('seed', tempReports, tempTemplates);

    const templates = JSON.parse(fs.readFileSync(tempTemplates, 'utf8'));

    // Should have canonical length + 1 user template
    assert.strictEqual(templates.length, baselineTemplates.length + 1);

    // The drifted template should be restored
    const restored = templates.find(t => t.id === drifted.id);
    assert.strictEqual(restored.name, baselineTemplates[0].name);

    // The user template should be preserved
    const preservedUser = templates.find(t => t.id === 'user-1');
    assert.strictEqual(preservedUser.name, 'User Template');
  });
});
