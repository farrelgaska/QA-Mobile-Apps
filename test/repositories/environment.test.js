const test = require('node:test');
const assert = require('node:assert/strict');
const { parseEnvironment } = require('../../src/config/env');
const { createPool, createPoolManager } = require('../../src/database/postgres');

test('JSON is the default provider and PostgreSQL requires DATABASE_URL', () => {
  assert.equal(parseEnvironment({}).DATA_PROVIDER, 'json');
  assert.throws(
    () => parseEnvironment({ DATA_PROVIDER: 'postgres' }),
    /DATABASE_URL is required/
  );
});

test('PostgreSQL pool uses bounded timeout and keepalive defaults without opening a connection', async () => {
  const config = parseEnvironment({
    DATA_PROVIDER: 'postgres',
    DATABASE_URL: 'postgresql://placeholder:placeholder@localhost:5432/placeholder',
    DATABASE_SSL: 'false'
  });
  const pool = createPool(config);
  assert.equal(pool.options.max, 2);
  assert.equal(pool.options.connectionTimeoutMillis, 10000);
  assert.equal(pool.options.idleTimeoutMillis, 30000);
  assert.equal(pool.options.keepAlive, true);
  assert.equal(pool.options.ssl, false);
  assert.equal(pool.options.connectionString.includes('placeholder'), true);
  await pool.end();
});

test('PostgreSQL pool preserves configurable Supabase SSL and logs idle client errors', () => {
  class RecordingPool {
    constructor(options) {
      this.options = options;
      this.listeners = {};
    }

    on(event, listener) {
      this.listeners[event] = listener;
      return this;
    }
  }

  const logged = [];
  const pool = createPool(
    parseEnvironment({
      DATA_PROVIDER: 'postgres',
      DATABASE_URL:
        'postgresql://postgres.project:password@region.pooler.supabase.com:6543/postgres',
      DATABASE_POOL_MAX: '4',
      DATABASE_CONNECTION_TIMEOUT_MS: '12000',
      DATABASE_IDLE_TIMEOUT_MS: '45000',
      DATABASE_KEEP_ALIVE: 'true',
      DATABASE_SSL: 'true',
      DATABASE_SSL_REJECT_UNAUTHORIZED: 'false'
    }),
    RecordingPool,
    { error: (...args) => logged.push(args) }
  );

  assert.equal(pool.options.max, 4);
  assert.equal(pool.options.connectionTimeoutMillis, 12000);
  assert.equal(pool.options.idleTimeoutMillis, 45000);
  assert.equal(pool.options.keepAlive, true);
  assert.deepEqual(pool.options.ssl, { rejectUnauthorized: false });

  const idleError = Object.assign(
    new Error('Connection terminated unexpectedly'),
    { code: 'ECONNRESET' }
  );
  assert.doesNotThrow(() => pool.listeners.error(idleError));
  assert.deepEqual(logged, [[
    'database_idle_client_error',
    {
      code: 'ECONNRESET',
      error_name: 'Error'
    }
  ]]);
});

test('STORAGE_PROVIDER is reserved for supported object storage providers', () => {
  assert.equal(parseEnvironment({ STORAGE_PROVIDER: 's3' }).STORAGE_PROVIDER, 's3');
  assert.throws(() => parseEnvironment({ STORAGE_PROVIDER: 'postgres' }), /supabase.*s3.*gcs/);
});

test('Supabase Storage provider requires both backend credentials', () => {
  assert.throws(
    () => parseEnvironment({ STORAGE_PROVIDER: 'supabase' }),
    /required when STORAGE_PROVIDER=supabase/
  );
  assert.throws(
    () => parseEnvironment({
      STORAGE_PROVIDER: 'supabase',
      SUPABASE_URL: 'https://example.supabase.co'
    }),
    /required when STORAGE_PROVIDER=supabase/
  );
  const config = parseEnvironment({
    STORAGE_PROVIDER: 'supabase',
    SUPABASE_URL: 'https://example.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'placeholder'
  });
  assert.equal(config.STORAGE_PROVIDER, 'supabase');
  assert.equal(config.SUPABASE_URL, 'https://example.supabase.co');
  assert.equal(config.SUPABASE_SERVICE_ROLE_KEY, 'placeholder');
});

test('pool manager creates one shared pool and attaches it once on Vercel', () => {
  const sharedPool = { query: async () => ({ rows: [{ '?column?': 1 }] }) };
  let created = 0;
  let attached = 0;
  const manager = createPoolManager({
    config: { DATA_PROVIDER: 'postgres', VERCEL: true },
    poolFactory: () => { created++; return sharedPool; },
    attachPool: pool => { assert.equal(pool, sharedPool); attached++; }
  });

  assert.equal(manager.getPool(), sharedPool);
  assert.equal(manager.getPool(), sharedPool);
  assert.equal(created, 1);
  assert.equal(attached, 1);
});

test('local pool manager does not register the pool with Vercel', () => {
  let attached = 0;
  const manager = createPoolManager({
    config: { DATA_PROVIDER: 'postgres', VERCEL: false },
    poolFactory: () => ({}),
    attachPool: () => { attached++; }
  });
  assert.equal(manager.getPool(), manager.getPool());
  assert.equal(attached, 0);
});
