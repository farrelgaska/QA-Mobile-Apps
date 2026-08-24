const env = require('../src/config/env');

async function main() {
  const isDryRun = process.argv.includes('--dry-run');
  if (isDryRun) {
    console.log('Running in DRY-RUN mode. No data will be mutated.');
  }

  if (env.APP_ENV === 'production') {
    console.error('FATAL: Cannot run backfill script in production environment.');
    process.exit(1);
  }



  const { reportRepository, templateRepository } = require('../src/repositories');
  const { getPool } = require('../src/database/postgres');

  console.log('Starting template_snapshot backfill...');
  try {
    const reports = await reportRepository.findAll();
    let updatedCount = 0;

    for (const report of reports) {
      if (report.template_snapshot) {
        continue;
      }
      if (!report.template_id) {
        console.warn(`Report ${report.id} has no template_id. Skipping.`);
        continue;
      }

      const template = await templateRepository.findById(report.template_id);
      if (!template) {
        console.warn(`Template ${report.template_id} not found for report ${report.id}. Skipping.`);
        continue;
      }

      if (!isDryRun) {
        await reportRepository.update(report.id, { template_snapshot: template });
      }
      updatedCount++;
      console.log(`${isDryRun ? '[DRY-RUN] Would update' : 'Updated'} report ${report.id} with snapshot from template ${template.id}`);
    }

    console.log(`Backfill complete. ${isDryRun ? 'Would update' : 'Updated'} ${updatedCount} reports.`);
  } catch (error) {
    console.error('Backfill failed:', error);
    process.exit(1);
  } finally {
    try {
      const pool = getPool();
      if (pool) await pool.end();
    } catch (_) {}
  }
}

if (require.main === module) {
  main();
}
