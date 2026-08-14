const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const demoAuthMiddleware = require('../src/middleware/auth');
const env = require('../src/config/env');

describe('demoAuthMiddleware', () => {
  it('should pass through when ADMIN_DEMO_TOKEN is not set', () => {
    let nextCalled = false;
    const req = { headers: {} };
    const res = {};
    const next = () => { nextCalled = true; };

    // Default env has no ADMIN_DEMO_TOKEN
    demoAuthMiddleware(req, res, next);
    assert.equal(nextCalled, true);
  });
});
