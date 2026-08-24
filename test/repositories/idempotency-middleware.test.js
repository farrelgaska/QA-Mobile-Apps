const test = require('node:test');
const assert = require('node:assert/strict');
const idempotencyMiddleware = require('../../src/middleware/idempotency');

const run = raw => {
  const req = { headers: {} };
  if (raw !== undefined) req.headers['idempotency-key'] = raw;
  let error;
  idempotencyMiddleware(req, {}, value => { error = value; });
  return { req, error };
};

test('Idempotency-Key accepts current client keys and the maximum length', () => {
  assert.equal(run('mobile-1724300000000-123456').req.idempotencyKey, 'mobile-1724300000000-123456');
  assert.equal(run('k'.repeat(255)).req.idempotencyKey.length, 255);
  assert.equal(run(undefined).req.idempotencyKey, null);
});

test('Idempotency-Key rejects empty, whitespace-only, and over-limit values', () => {
  for (const key of ['', '   ', 'k'.repeat(256)]) {
    const { error } = run(key);
    assert.equal(error.code, 'INVALID_IDEMPOTENCY_KEY');
    assert.equal(error.status, 400);
  }
});
