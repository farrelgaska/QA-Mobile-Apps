const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const fs = require('fs');

const { PostgresReportRepository } = require('../../src/repositories/postgres-report.repository');
const { JsonReportRepository } = require('../../src/repositories/json-report.repository');
const { idempotencyConflict } = require('../../src/repositories/repository-errors');
const { fingerprintReportCreate } = require('../../src/utils/request-fingerprint');

test('Idempotency - PostgreSQL', async (t) => {
  const mockClient = {
    query: async () => ({ rows: [], rowCount: 0 }),
    release: () => {}
  };
  const mockPool = {
    connect: async () => mockClient
  };
  const repository = new PostgresReportRepository(mockPool, { now: () => new Date('2026-08-22T00:00:00Z') });

  // Stub internal methods
  let rootWritten = false;
  repository._writeRoot = async () => { rootWritten = true; };
  repository._writeChildren = async () => {};
  repository._findById = async (client, id) => ({ id, type: 'PEKERJAAN', status: 'DRAFT', checklist_items: [] });

  const payload = {
    id: 'QC-WRK-123',
    type: 'PEKERJAAN',
    status: 'DRAFT',
    checklist_items: []
  };

  await t.test('claims key and creates report on first request in atomic transaction', async () => {
    rootWritten = false;
    let queries = [];
    mockClient.query = async (sql) => {
      queries.push(sql.trim().substring(0, 30));
      if (sql.includes('insert into public.api_idempotency_keys')) {
        return { rowCount: 1, rows: [{ key: 'IDEM-001' }] };
      }
      return { rows: [], rowCount: 0 };
    };

    const result = await repository.createWithIdempotency(payload, 'IDEM-001');
    assert.equal(result.replayed, false);
    assert.equal(result.report.id, 'QC-WRK-123');
    assert.equal(rootWritten, true);

    assert.ok(queries.some(q => q.includes('BEGIN')));
    assert.ok(queries.some(q => q.includes('insert into public.api_idempot')));
    assert.ok(queries.some(q => q.includes('COMMIT')));
  });

  await t.test('replays successfully when blocked concurrent request wakes up to a completed row', async () => {
    rootWritten = false;
    mockClient.query = async (sql) => {
      if (sql.includes('insert into public.api_idempotency_keys')) {
        return { rowCount: 0 };
      }
      if (sql.includes('select request_hash, resource_id')) {
        const { canonicalReportInput } = require('../../src/repositories/postgres/mappers');
        const { normalizeQCEvidenceCaptureMetadata } = require('../../src/contracts/qc-evidence-capture-metadata');
        const canonical = canonicalReportInput(normalizeQCEvidenceCaptureMetadata(payload, { now: () => new Date('2026-08-22T00:00:00Z') }));
        const hash = fingerprintReportCreate(canonical);
        return { rows: [{ request_hash: hash, resource_id: 'QC-WRK-123' }] };
      }
      return { rows: [], rowCount: 0 };
    };

    const result = await repository.createWithIdempotency(payload, 'IDEM-002');
    assert.equal(result.replayed, true);
    assert.equal(result.report.id, 'QC-WRK-123');
    assert.equal(rootWritten, false); // DB was not modified
  });

  await t.test('throws IDEMPOTENCY_CONFLICT when payload hash differs from committed row', async () => {
    mockClient.query = async (sql) => {
      if (sql.includes('insert into public.api_idempotency_keys')) return { rowCount: 0 };
      if (sql.includes('select request_hash, resource_id')) {
        return { rows: [{ request_hash: 'different-hash', resource_id: 'QC-WRK-999' }] };
      }
      return { rows: [], rowCount: 0 };
    };

    await assert.rejects(
      repository.createWithIdempotency(payload, 'IDEM-004'),
      { code: 'IDEMPOTENCY_CONFLICT' }
    );
  });

  await t.test('returns a retryable conflict if concurrency resolution has no row', async () => {
    mockClient.query = async (sql) => {
      if (sql.includes('insert into public.api_idempotency_keys')) return { rowCount: 0 };
      if (sql.includes('select request_hash, resource_id')) {
        return { rows: [] };
      }
      return { rows: [], rowCount: 0 };
    };

    await assert.rejects(
      repository.createWithIdempotency(payload, 'IDEM-004'),
      { code: 'IDEMPOTENCY_IN_PROGRESS', status: 409 }
    );
  });

  await t.test('rejects a stale replay target instead of returning success', async () => {
    mockClient.query = async (sql) => {
      if (sql.includes('insert into public.api_idempotency_keys')) return { rowCount: 0 };
      if (sql.includes('select request_hash, resource_id')) {
        const { canonicalReportInput } = require('../../src/repositories/postgres/mappers');
        const { normalizeQCEvidenceCaptureMetadata } = require('../../src/contracts/qc-evidence-capture-metadata');
        const canonical = canonicalReportInput(normalizeQCEvidenceCaptureMetadata(payload, { now: () => new Date('2026-08-22T00:00:00Z') }));
        return { rows: [{ request_hash: fingerprintReportCreate(canonical), resource_id: payload.id }] };
      }
      return { rows: [], rowCount: 0 };
    };
    repository._findById = async () => null;

    await assert.rejects(
      repository.createWithIdempotency(payload, 'IDEM-STALE'),
      { code: 'IDEMPOTENCY_REPLAY_UNAVAILABLE', status: 409 }
    );
  });
});

test('Idempotency - JSON Provider', async (t) => {
  const tempDir = path.join(__dirname, '..', 'fixtures', 'temp_idempotency');
  const reportsFile = path.join(tempDir, 'reports.json');
  const idempFile = path.join(tempDir, 'idempotency.json');

  if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });
  fs.writeFileSync(reportsFile, '[]');
  if (fs.existsSync(idempFile)) fs.unlinkSync(idempFile);

  const repository = new JsonReportRepository(reportsFile, {
    now: () => new Date('2026-08-22T00:00:00Z'),
    idempotencyFilePath: idempFile
  });

  const payload = {
    id: 'QC-WRK-JSON-1',
    type: 'PEKERJAAN',
    status: 'DRAFT',
    checklist_items: []
  };

  await t.test('claims key and creates report persistently', async () => {
    const result = repository.createWithIdempotency(payload, 'IDEM-JSON-1');
    assert.equal(result.replayed, false);
    assert.equal(result.report.id, 'QC-WRK-JSON-1');

    const store = JSON.parse(fs.readFileSync(idempFile, 'utf-8'));
    assert.equal(store['create_report::IDEM-JSON-1'].resource_id, 'QC-WRK-JSON-1');
  });

  await t.test('survives process restart for replay', async () => {
    const payload2 = { ...payload, id: 'QC-WRK-JSON-2' };
    repository.createWithIdempotency(payload2, 'IDEM-JSON-2');

    const repo2 = new JsonReportRepository(reportsFile, { idempotencyFilePath: idempFile });
    const result = repo2.createWithIdempotency(payload2, 'IDEM-JSON-2');
    assert.equal(result.replayed, true);

    const reports = JSON.parse(fs.readFileSync(reportsFile, 'utf-8'));
    assert.equal(reports.length, 2); // 1 + 2
  });

  await t.test('rejects on different payload', async () => {
    const payload3 = { ...payload, id: 'QC-WRK-JSON-3' };
    repository.createWithIdempotency(payload3, 'IDEM-JSON-3');

    const changedPayload = { ...payload3, staff_note: 'different' };
    assert.throws(
      () => repository.createWithIdempotency(changedPayload, 'IDEM-JSON-3'),
      { code: 'IDEMPOTENCY_CONFLICT' }
    );
  });

  await t.test('deleting a report removes its idempotency claims', () => {
    const payload4 = { ...payload, id: 'QC-WRK-JSON-4' };
    repository.createWithIdempotency(payload4, 'IDEM-JSON-4');
    repository.delete(payload4.id);

    const store = JSON.parse(fs.readFileSync(idempFile, 'utf-8'));
    assert.equal(store['create_report::IDEM-JSON-4'], undefined);
  });

  await t.test('rejects a stale JSON replay target instead of returning success', () => {
    const payload5 = { ...payload, id: 'QC-WRK-JSON-5' };
    const canonical = require('../../src/repositories/postgres/mappers').canonicalReportInput(
      require('../../src/contracts/qc-evidence-capture-metadata').normalizeQCEvidenceCaptureMetadata(
        payload5,
        { now: () => new Date('2026-08-22T00:00:00Z') }
      )
    );
    const store = repository._readIdempotency();
    store['create_report::IDEM-JSON-5'] = {
      request_hash: fingerprintReportCreate(canonical),
      resource_id: payload5.id
    };
    repository._writeIdempotency(store);

    assert.throws(
      () => repository.createWithIdempotency(payload5, 'IDEM-JSON-5'),
      { code: 'IDEMPOTENCY_REPLAY_UNAVAILABLE', status: 409 }
    );
  });
});
