'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.APP_ENV = 'production';
process.env.CORS_ORIGINS = 'https://qa-mobile-app.vercel.app';
process.env.DATA_PROVIDER = 'json';

const app = require('../../src/app');

test('production report-detail preflight allows required headers only for the allowed origin', async t => {
  const server = app.listen(0);
  t.after(() => new Promise(resolve => server.close(resolve)));
  await new Promise(resolve => server.once('listening', resolve));
  const url = `http://127.0.0.1:${server.address().port}/reports/QC-CORS-1`;
  const preflight = origin => fetch(url, {
    method: 'OPTIONS',
    headers: {
      Origin: origin,
      'Access-Control-Request-Method': 'GET',
      'Access-Control-Request-Headers': 'cache-control'
    }
  });

  const allowed = await preflight('https://qa-mobile-app.vercel.app');
  assert.equal(allowed.status, 204);
  assert.equal(allowed.headers.get('access-control-allow-origin'), 'https://qa-mobile-app.vercel.app');
  assert.match(allowed.headers.get('access-control-allow-methods'), /(?:^|,)GET(?:,|$)/);
  assert.deepEqual(
    new Set(allowed.headers.get('access-control-allow-headers').toLowerCase().split(',')),
    new Set(['content-type', 'authorization', 'idempotency-key', 'x-request-id', 'cache-control'])
  );

  const disallowed = await preflight('https://evil.example');
  assert.equal(disallowed.headers.get('access-control-allow-origin'), null);
  assert.equal(disallowed.headers.get('access-control-allow-headers'), null);
});
