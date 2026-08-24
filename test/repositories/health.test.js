const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');

process.env.DATA_PROVIDER = 'json';
process.env.DATABASE_URL = 'postgresql://SECRET_USER:SECRET_PASSWORD@SECRET_HOST:6543/SECRET_DATABASE';
delete process.env.VERCEL;

const { createHealthRouter } = require('../../src/routes/health.routes');

test('health reports the data provider without leaking DATABASE_URL', async t => {
  const app = express();
  app.use('/health', createHealthRouter({
    provider: 'json',
    checkDatabase: async () => false,
    config: {
      APP_ENV: 'development',
      STORAGE_PROVIDER: 'local'
    }
  }));
  const server = app.listen(0);
  t.after(() => server.close());
  await new Promise(resolve => server.once('listening', resolve));
  const response = await fetch(`http://127.0.0.1:${server.address().port}/health`);
  const body = await response.json();
  const serialized = JSON.stringify(body);

  assert.equal(response.status, 200);
  assert.equal(body.status, 'OK');
  assert.equal(body.alive, true);
  assert.equal(body.ready, true);
  assert.equal(body.environment, 'development');
  assert.equal(body.data_provider, 'json');
  assert.equal(body.database_reachable, false);
  assert.equal(body.storage_provider, 'local');
  assert.equal(body.storage_configured, true);
  assert.equal(serialized.includes('SECRET_USER'), false);
  assert.equal(serialized.includes('SECRET_PASSWORD'), false);
  assert.equal(serialized.includes(process.env.DATABASE_URL), false);
});

test('health reports degraded readiness for production local storage', async t => {
  const app = express();
  app.use('/health', createHealthRouter({
    provider: 'postgres',
    checkDatabase: async () => true,
    config: {
      APP_ENV: 'production',
      STORAGE_PROVIDER: 'local'
    }
  }));
  const server = app.listen(0);
  t.after(() => server.close());
  await new Promise(resolve => server.once('listening', resolve));

  const response = await fetch(`http://127.0.0.1:${server.address().port}/health`);
  const body = await response.json();

  assert.equal(body.alive, true);
  assert.equal(body.ready, false);
  assert.equal(body.status, 'DEGRADED');
  assert.equal(body.database_reachable, true);
  assert.equal(body.storage_provider, 'local');
  assert.equal(body.storage_configured, false);
});
