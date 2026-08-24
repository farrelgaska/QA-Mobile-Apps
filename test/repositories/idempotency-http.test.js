const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

process.env.DATA_PROVIDER = 'json';
delete process.env.VERCEL;

const repositories = require('../../src/repositories');
const { JsonReportRepository } = require('../../src/repositories/json-report.repository');
const app = require('../../src/app');

test('POST /reports creates, replays, conflicts, and rejects invalid idempotency keys', async t => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'qa-idempotency-http-'));
  t.after(() => fs.rmSync(tempDir, { recursive: true, force: true }));

  const repository = new JsonReportRepository(path.join(tempDir, 'reports.json'), {
    idempotencyFilePath: path.join(tempDir, 'idempotency.json'),
    now: () => new Date('2026-08-24T00:00:00Z')
  });
  for (const method of ['create', 'createWithIdempotency', 'findAll', 'findById', 'delete']) {
    repositories.reportRepository[method] = repository[method].bind(repository);
  }

  const server = app.listen(0);
  t.after(() => new Promise(resolve => server.close(resolve)));
  await new Promise(resolve => server.once('listening', resolve));
  const url = `http://127.0.0.1:${server.address().port}/reports`;
  const payload = {
    id: 'QC-IDEM-HTTP-1',
    type: 'PEKERJAAN',
    title: 'HTTP idempotency',
    status: 'DRAFT',
    staff: { name: 'Staff', nik: 'S-1' },
    location: {},
    checklist_items: []
  };
  const submit = (body, key) => fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'idempotency-key': key },
    body: JSON.stringify(body)
  });

  const first = await submit(payload, 'HTTP-IDEM-1');
  assert.equal(first.status, 201);
  assert.equal((await first.json()).id, payload.id);

  const replay = await submit(payload, 'HTTP-IDEM-1');
  assert.equal(replay.status, 200);
  assert.equal(replay.headers.get('idempotency-replayed'), 'true');
  assert.equal((await replay.json()).id, payload.id);
  assert.equal(repository.findAll().length, 1);

  const conflict = await submit({ ...payload, staff_note: 'changed' }, 'HTTP-IDEM-1');
  assert.equal(conflict.status, 409);
  assert.deepEqual(await conflict.json(), {
    code: 'IDEMPOTENCY_CONFLICT',
    message: 'Kunci pengiriman sudah digunakan untuk data yang berbeda.',
    status: 409,
    error: {
      code: 'IDEMPOTENCY_CONFLICT',
      message: 'Kunci pengiriman sudah digunakan untuk data yang berbeda.'
    }
  });

  const invalid = await submit({ ...payload, id: 'QC-IDEM-HTTP-2' }, 'k'.repeat(256));
  assert.equal(invalid.status, 400);
  const invalidBody = await invalid.json();
  assert.equal(invalidBody.code, 'INVALID_IDEMPOTENCY_KEY');
  assert.equal(invalidBody.status, 400);
  assert.equal(repository.findAll().length, 1);

  repository.delete(payload.id);
  assert.equal(repository._readIdempotency()['create_report::HTTP-IDEM-1'], undefined);
});
