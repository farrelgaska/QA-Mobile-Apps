const fs = require('fs');
const path = require('path');
const { assertSafeToMutate } = require('./guard');
const { DATA_PROVIDER: dataProvider, REPORTS_FILE, TEMPLATES_FILE } = require('../../src/config/env');
const { getPool } = require('../../src/database/postgres');
const { PostgresTemplateRepository } = require('../../src/repositories/postgres-template.repository');
const { canonicalTemplateInput } = require('../../src/repositories/postgres/mappers');

// Load canonical baseline
const baselineTemplates = require('./baseline.json');

function writeJsonSafely(filePath, data) {
  const tempPath = `${filePath}.${Date.now()}.tmp`;
  try {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(tempPath, JSON.stringify(data, null, 2), 'utf-8');
    fs.renameSync(tempPath, filePath);
  } catch (e) {
    if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
    throw e;
  }
}

async function handleJsonProvider(command, reportsPath, templatesPath) {
  if (command === 'reset' || command === 'reseed') {
    console.log(`[JSON] Resetting environment to clean baseline...`);
    writeJsonSafely(reportsPath, []);
    writeJsonSafely(path.join(path.dirname(reportsPath), 'idempotency.json'), {});
    writeJsonSafely(templatesPath, baselineTemplates);
    console.log(`[JSON] Dropped all reports. Reset to ${baselineTemplates.length} canonical templates.`);
    return; // reset/reseed is complete
  }

  if (command === 'seed') {
    console.log(`[JSON] Seeding templates at ${templatesPath} ...`);
    let currentTemplates = [];
    if (fs.existsSync(templatesPath)) {
      try { currentTemplates = JSON.parse(fs.readFileSync(templatesPath, 'utf8')); } catch (_) {}
    }

    const baselineMap = new Map(baselineTemplates.map(t => [t.id, t]));
    const newTemplates = currentTemplates.map(t => baselineMap.has(t.id) ? baselineMap.get(t.id) : t);

    // Add missing canonical templates
    const existingIds = new Set(newTemplates.map(t => t.id));
    for (const t of baselineTemplates) {
      if (!existingIds.has(t.id)) newTemplates.push(t);
    }

    writeJsonSafely(templatesPath, newTemplates);
    console.log(`[JSON] Seeded canonical templates. Total templates: ${newTemplates.length}.`);
  }
}

async function handlePostgresProvider(command) {
  const pool = getPool();
  // We do not connect immediately to ensure guard works before connection
  let client;

  try {
    client = await pool.connect();
    const templateRepo = new PostgresTemplateRepository(pool);

    await client.query('BEGIN');

    if (command === 'reset' || command === 'reseed') {
      console.log('[Postgres] Resetting environment to clean baseline...');
      await client.query("DELETE FROM public.api_idempotency_keys WHERE scope = 'create_report'");
      await client.query('DELETE FROM public.qc_reports');
      await client.query('DELETE FROM public.qc_templates');

      for (const tpl of baselineTemplates) {
        const canonical = canonicalTemplateInput(tpl);
        await templateRepo._insertRoot(client, canonical);
        await templateRepo._insertItems(client, canonical.id, canonical.checklist_items);
      }
      console.log(`[Postgres] Dropped all reports and non-canonical templates. Restored ${baselineTemplates.length} canonical templates.`);
    } else if (command === 'seed') {
      console.log('[Postgres] Seeding canonical templates (Idempotent upsert) ...');
      let created = 0;
      let updated = 0;

      for (const tpl of baselineTemplates) {
        const existing = await templateRepo._findById(client, tpl.id, true);
        const canonical = canonicalTemplateInput(tpl);
        if (existing) {
          await client.query('DELETE FROM public.qc_templates WHERE id = $1', [tpl.id]);
          await templateRepo._insertRoot(client, canonical);
          await templateRepo._insertItems(client, canonical.id, canonical.checklist_items);
          updated++;
        } else {
          await templateRepo._insertRoot(client, canonical);
          await templateRepo._insertItems(client, canonical.id, canonical.checklist_items);
          created++;
        }
      }
      console.log(`[Postgres] Seeded ${created} new templates, restored ${updated} existing templates to canonical baseline.`);
    }

    await client.query('COMMIT');
  } catch (err) {
    if (client) {
      try { await client.query('ROLLBACK'); } catch (_) {}
    }
    console.error('[Postgres] Transaction failed, rolled back.');
    throw err;
  } finally {
    if (client) client.release();
    // In cli mode, we need to end the pool to exit process
    if (require.main === module) {
      await pool.end();
    }
  }
}

async function run() {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!['seed', 'reset', 'reseed'].includes(command)) {
    console.error('Usage: npm run db:<seed|reset|reseed>');
    process.exit(1);
  }

  // Injectable paths for testing
  const reportsPath = process.env.TEST_REPORTS_FILE || REPORTS_FILE;
  const templatesPath = process.env.TEST_TEMPLATES_FILE || TEMPLATES_FILE;

  try {
    assertSafeToMutate();

    if (dataProvider === 'json') {
      await handleJsonProvider(command, reportsPath, templatesPath);
    } else if (dataProvider === 'postgres') {
      await handlePostgresProvider(command);
    } else {
      throw new Error(`Unsupported DATA_PROVIDER: ${dataProvider}`);
    }

    console.log(`[Tooling] Command "${command}" executed successfully.`);
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

// If run directly
if (require.main === module) {
  run();
} else {
  // Export for testing
  module.exports = { handleJsonProvider, handlePostgresProvider };
}
