const test = require('node:test');
const assert = require('node:assert/strict');

process.env.DATA_PROVIDER = 'json';
delete process.env.VERCEL;

const repositories = require('../../src/repositories');
const existingTemplates = new Set(['MAT-HTTP']);
const existingReports = new Set(['QC-HTTP']);

repositories.templateRepository.delete = async id => {
  if (!existingTemplates.delete(id)) {
    const error = new Error(`Template with ID ${id} not found`);
    error.statusCode = 404;
    throw error;
  }
};
repositories.reportRepository.delete = async id => {
  if (!existingReports.delete(id)) {
    const error = new Error(`Report with ID ${id} not found`);
    error.statusCode = 404;
    throw error;
  }
};

const app = require('../../src/app');

test('aggregate DELETE endpoints return 204 once and 404 for missing IDs', async t => {
  const server = app.listen(0);
  t.after(() => server.close());
  await new Promise(resolve => server.once('listening', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  const templateDeleted = await fetch(`${baseUrl}/templates/MAT-HTTP`, { method: 'DELETE' });
  assert.equal(templateDeleted.status, 204);
  assert.equal(await templateDeleted.text(), '');

  const reportDeleted = await fetch(`${baseUrl}/reports/QC-HTTP`, { method: 'DELETE' });
  assert.equal(reportDeleted.status, 204);
  assert.equal(await reportDeleted.text(), '');

  const originalConsoleError = console.error;
  console.error = () => {};
  try {
    const templateMissing = await fetch(`${baseUrl}/templates/MAT-MISSING`, { method: 'DELETE' });
    assert.equal(templateMissing.status, 404);
    assert.deepEqual(await templateMissing.json(), { error: 'Template with ID MAT-MISSING not found' });

    const reportMissing = await fetch(`${baseUrl}/reports/QC-MISSING`, { method: 'DELETE' });
    assert.equal(reportMissing.status, 404);
    assert.deepEqual(await reportMissing.json(), { error: 'Report with ID QC-MISSING not found' });
  } finally {
    console.error = originalConsoleError;
  }
});
