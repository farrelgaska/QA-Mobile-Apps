const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const AppError = require('../../src/utils/AppError');
const { createLogger } = require('../../src/utils/logger');
const {
  createObservabilityMiddleware,
  MAX_REQUEST_ID_LENGTH
} = require('../../src/middleware/observability');
const { createErrorHandler } = require('../../src/middleware/error-handler');
const idempotencyMiddleware = require('../../src/middleware/idempotency');

const captureLog = () => {
  const entries = [];
  const log = Object.fromEntries(
    ['debug', 'info', 'warn', 'error'].map(level => [
      level,
      (event, fields) => entries.push({ level, event, ...fields })
    ])
  );
  return { entries, log };
};

const withServer = async (app, callback) => {
  const server = app.listen(0);
  await new Promise(resolve => server.once('listening', resolve));
  try {
    await callback(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
};

test('structured logger emits one JSON-compatible object per line', () => {
  const messages = [];
  const logger = createLogger({
    sink: { info: message => messages.push(message) },
    now: () => new Date('2026-08-24T00:00:00.000Z')
  });

  logger.info('test_event', { request_id: 'req-1', status: 200 });

  assert.deepEqual(JSON.parse(messages[0]), {
    timestamp: '2026-08-24T00:00:00.000Z',
    level: 'info',
    event: 'test_event',
    request_id: 'req-1',
    status: 200
  });
});

test('request IDs are generated, safely reused, bounded, and returned', async () => {
  const { entries, log } = captureLog();
  let generated = 0;
  let time = 100;
  const app = express();
  app.use(createObservabilityMiddleware({
    log,
    now: () => time += 5,
    createRequestId: () => `generated-${++generated}`
  }));
  app.get('/ok', (req, res) => res.json({ request_id: req.requestId }));

  await withServer(app, async baseUrl => {
    const generatedResponse = await fetch(`${baseUrl}/ok`);
    assert.equal(generatedResponse.headers.get('x-request-id'), 'generated-1');

    const reusedResponse = await fetch(`${baseUrl}/ok`, {
      headers: { 'x-request-id': 'support.case-123:retry_2' }
    });
    assert.equal(reusedResponse.headers.get('x-request-id'), 'support.case-123:retry_2');

    const oversizedResponse = await fetch(`${baseUrl}/ok`, {
      headers: { 'x-request-id': 'a'.repeat(MAX_REQUEST_ID_LENGTH + 1) }
    });
    assert.equal(oversizedResponse.headers.get('x-request-id'), 'generated-2');
  });

  assert.equal(entries.length, 3);
  assert.deepEqual(entries[0], {
    level: 'info',
    event: 'http_request_completed',
    request_id: 'generated-1',
    method: 'GET',
    path: '/ok',
    status: 200,
    duration_ms: 5
  });
});

test('5xx errors retain correlation and emit a sanitized structured error event', async () => {
  const { entries, log } = captureLog();
  const app = express();
  app.use(createObservabilityMiddleware({ log, createRequestId: () => 'req-500' }));
  app.get('/boom', (_req, _res, next) => next(new Error('secret internal detail')));
  app.use(createErrorHandler({ log, environment: 'production' }));

  await withServer(app, async baseUrl => {
    const response = await fetch(`${baseUrl}/boom`, {
      headers: {
        authorization: 'Bearer SECRET_TOKEN',
        cookie: 'session=SECRET_COOKIE'
      }
    });
    assert.equal(response.headers.get('x-request-id'), 'req-500');
    assert.deepEqual(await response.json(), {
      code: 'INTERNAL_ERROR',
      message: 'Terjadi kesalahan internal.',
      status: 500,
      error: { code: 'INTERNAL_ERROR', message: 'Terjadi kesalahan internal.' }
    });
  });

  const errorEntry = entries.find(entry => entry.event === 'request_failed');
  assert.equal(errorEntry.level, 'error');
  assert.equal(errorEntry.request_id, 'req-500');
  assert.equal(errorEntry.code, 'INTERNAL_ERROR');
  assert.equal('stack' in errorEntry, false);
  const serialized = JSON.stringify(entries);
  assert.equal(serialized.includes('secret internal detail'), false);
  assert.equal(serialized.includes('SECRET_TOKEN'), false);
  assert.equal(serialized.includes('SECRET_COOKIE'), false);
});

test('expected 4xx errors log a key fingerprint without leaking key, stack, or cause', async () => {
  const { entries, log } = captureLog();
  const app = express();
  app.use(createObservabilityMiddleware({ log, createRequestId: () => 'req-409' }));
  app.post('/conflict', idempotencyMiddleware, (_req, _res, next) => next(new AppError({
    status: 409,
    code: 'IDEMPOTENCY_CONFLICT',
    message: 'Idempotency conflict.',
    cause: new Error('raw cause secret')
  })));
  app.use(createErrorHandler({ log, environment: 'development' }));

  await withServer(app, async baseUrl => {
    const response = await fetch(`${baseUrl}/conflict`, {
      method: 'POST',
      headers: { 'idempotency-key': 'top-secret-replay-key' }
    });
    const body = await response.json();
    assert.equal(response.headers.get('x-request-id'), 'req-409');
    assert.equal(body.code, 'IDEMPOTENCY_CONFLICT');
    assert.equal('stack' in body, false);
    assert.equal('cause' in body, false);
  });

  const conflict = entries.find(entry => entry.event === 'idempotency_conflict');
  assert.equal(conflict.level, 'warn');
  assert.equal(conflict.request_id, 'req-409');
  assert.match(conflict.idempotency_key_fingerprint, /^[0-9a-f]{16}$/);
  const serialized = JSON.stringify(entries);
  assert.equal(serialized.includes('top-secret-replay-key'), false);
  assert.equal(serialized.includes('raw cause secret'), false);
});
