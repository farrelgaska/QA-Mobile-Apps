import assert from 'node:assert/strict';
import test from 'node:test';

import { ApiError, fetchReport, fetchReports } from '../src/services/reportApi.ts';

test('Admin report list excludes drafts', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response(JSON.stringify([
    { id: 'draft', status: 'DRAFT' },
    { id: 'submitted', status: 'SUBMITTED' },
    { id: 'approved', status: 'APPROVED' },
  ]), { status: 200, headers: { 'content-type': 'application/json' } });

  try {
    assert.deepEqual((await fetchReports()).map(report => report.id), [
      'submitted',
      'approved',
    ]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('report API accepts canonical errors and the nested compatibility mirror', async () => {
  const originalFetch = globalThis.fetch;
  const cases = [
    {
      body: { code: 'DATABASE_TIMEOUT', message: 'Database request timed out', status: 503 },
      status: 503,
      code: 'DATABASE_TIMEOUT',
    },
    {
      body: { error: { code: 'REPORT_ALREADY_EXISTS', message: 'Duplicate report' } },
      status: 409,
      code: 'REPORT_ALREADY_EXISTS',
    },
  ];

  try {
    for (const entry of cases) {
      globalThis.fetch = async () => new Response(JSON.stringify(entry.body), {
        status: entry.status,
        headers: { 'content-type': 'application/json' },
      });

      await assert.rejects(fetchReport('REG-ERROR'), error => {
        assert.ok(error instanceof ApiError);
        assert.equal(error.status, entry.status);
        assert.equal(error.code, entry.code);
        return true;
      });
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});
