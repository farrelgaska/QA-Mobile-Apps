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
  t.after(() => new Promise((resolve, reject) => {
    server.close(error => error ? reject(error) : resolve());
    server.closeAllConnections();
  }));
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

test('known final-conclusion domain violations return HTTP 422', async t => {
  repositories.reportRepository.create = async () => {
    const error = new Error(
      'Report QC-INVALID-FINAL with status NEEDS_FOLLOW_UP requires an explicit final conclusion'
    );
    error.statusCode = 422;
    throw error;
  };

  const server = app.listen(0);
  t.after(() => new Promise((resolve, reject) => {
    server.close(error => error ? reject(error) : resolve());
    server.closeAllConnections();
  }));
  await new Promise(resolve => server.once('listening', resolve));
  const originalConsoleError = console.error;
  console.error = () => {};
  try {
    const response = await fetch(
      `http://127.0.0.1:${server.address().port}/reports`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          id: 'QC-INVALID-FINAL',
          type: 'MATERIAL',
          title: 'Invalid final state',
          status: 'NEEDS_FOLLOW_UP',
          staff: { name: 'Warehouse Staff', nik: 'WH-1' },
          location: {},
          checklist_items: []
        })
      }
    );

    assert.equal(response.status, 422);
    assert.deepEqual(await response.json(), {
      error: 'Report QC-INVALID-FINAL with status NEEDS_FOLLOW_UP requires an explicit final conclusion'
    });
  } finally {
    console.error = originalConsoleError;
  }
});
