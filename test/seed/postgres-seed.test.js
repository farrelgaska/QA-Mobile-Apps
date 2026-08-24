const assert = require('assert');
const { describe, it, beforeEach, afterEach } = require('node:test');
const pg = require('pg');
const env = require('../../src/config/env');

// Mock pg.Pool before requiring cli
const executedQueries = [];
let shouldFailOnDelete = false;

const mockClient = {
  query: async (text, params) => {
    executedQueries.push(text);
    if (shouldFailOnDelete && text.includes('DELETE FROM public.qc_reports')) {
      throw new Error('Simulated destructive failure');
    }
    if (text.toLowerCase().includes('select')) {
      return { rows: [] };
    }
    return { rowCount: 1 };
  },
  release: () => {
    executedQueries.push('RELEASE');
  }
};

const originalConnect = pg.Pool.prototype.connect;
pg.Pool.prototype.connect = async () => mockClient;

const originalDataProvider = env.DATA_PROVIDER;
env.DATA_PROVIDER = 'postgres';

// Now require cli
const { handlePostgresProvider } = require('../../scripts/seed/cli');

describe('Canonical Tooling - Postgres Provider', () => {
  beforeEach(() => {
    executedQueries.length = 0;
    shouldFailOnDelete = false;
  });

  afterEach(() => {
    // We don't restore originalConnect because all tests in this file need it,
    // but in a larger suite we would restore it after().
  });

  it('reset opens transaction, executes destructive commands, inserts templates, and commits', async () => {
    await handlePostgresProvider('reset');

    // Verify sequence
    assert.strictEqual(executedQueries[0], 'BEGIN');

    // Both delete commands must run
    const deletes = executedQueries.filter(q => q.includes('DELETE'));
    assert.ok(deletes.some(q => q.includes('DELETE FROM public.api_idempotency_keys')), 'report idempotency keys must be deleted');
    assert.ok(deletes.some(q => q.includes('DELETE FROM public.qc_reports')), 'qc_reports must be deleted');
    assert.ok(deletes.some(q => q.includes('DELETE FROM public.qc_templates')), 'qc_templates must be deleted');

    // Must insert templates (we have 13, each has a root and item insert)
    const inserts = executedQueries.filter(q => q.includes('insert into public.qc_templates'));
    assert.ok(inserts.length > 0, 'Should insert canonical templates');

    // Must commit
    assert.strictEqual(executedQueries[executedQueries.length - 2], 'COMMIT');
    assert.strictEqual(executedQueries[executedQueries.length - 1], 'RELEASE');
  });

  it('failure during reset triggers ROLLBACK and does not COMMIT', async () => {
    shouldFailOnDelete = true;

    try {
      await handlePostgresProvider('reset');
      assert.fail('Should have thrown an error');
    } catch (e) {
      assert.strictEqual(e.message, 'Simulated destructive failure');
    }

    assert.strictEqual(executedQueries[0], 'BEGIN');

    // The query that fails
    assert.ok(executedQueries.includes('DELETE FROM public.qc_reports'));

    // Should rollback
    assert.ok(executedQueries.includes('ROLLBACK'));
    assert.ok(!executedQueries.includes('COMMIT'), 'Must NOT commit on failure');
    assert.strictEqual(executedQueries[executedQueries.length - 1], 'RELEASE');
  });

  it('seed opens transaction, does not delete reports, upserts templates, and commits', async () => {
    await handlePostgresProvider('seed');

    assert.strictEqual(executedQueries[0], 'BEGIN');

    const deletes = executedQueries.filter(q => q.includes('DELETE'));
    assert.ok(!deletes.some(q => q.includes('DELETE FROM public.api_idempotency_keys')), 'idempotency keys must NOT be deleted during seed');
    assert.ok(!deletes.some(q => q.includes('DELETE FROM public.qc_reports')), 'qc_reports must NOT be deleted during seed');

    // Still must commit
    assert.strictEqual(executedQueries[executedQueries.length - 2], 'COMMIT');
  });
});
