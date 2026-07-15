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

test('PostgreSQL pool defaults to two connections without opening a connection', async () => {
  const config = parseEnvironment({
    DATA_PROVIDER: 'postgres',
    DATABASE_URL: 'postgresql://placeholder:placeholder@localhost:5432/placeholder',
    DATABASE_SSL: 'false'
  });
  const pool = createPool(config);
  assert.equal(pool.options.max, 2);
  assert.equal(pool.options.connectionString.includes('placeholder'), true);
  await pool.end();
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
