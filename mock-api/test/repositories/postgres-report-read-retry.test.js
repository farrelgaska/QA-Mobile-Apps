const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');

const {
  isTransientPostgresError
} = require('../../src/repositories/repository-errors');
const {
  PostgresReportRepository
} = require('../../src/repositories/postgres-report.repository');
const {
  createGetReports
} = require('../../src/controllers/report.controller');
const errorHandler = require('../../src/middleware/error-handler');

class SequencedReadPool {
  constructor(outcomes) {
    this.outcomes = outcomes;
    this.connectCount = 0;
    this.clients = [];
  }

  async connect() {
    const outcome = this.outcomes[this.connectCount];
    this.connectCount += 1;
    if (outcome?.connectError) throw outcome.connectError;

    const client = {
      releaseArguments: [],
      queryCount: 0,
      query: async () => {
        client.queryCount += 1;
        if (outcome?.queryError) throw outcome.queryError;
        return { rows: [], rowCount: 0 };
      },
      release: error => {
        client.releaseArguments.push(error);
      }
    };
    this.clients.push(client);
    return client;
  }
}

const transientError = message => Object.assign(new Error(message), {
  code: 'ECONNRESET'
});

const requestReports = async (t, repository) => {
  const app = express();
  app.get('/reports', createGetReports(repository));
  app.use(errorHandler);
  const server = app.listen(0);
  t.after(() => new Promise((resolve, reject) => {
    server.close(error => error ? reject(error) : resolve());
    server.closeAllConnections();
  }));
  await new Promise(resolve => server.once('listening', resolve));
  return fetch(`http://127.0.0.1:${server.address().port}/reports`);
};

test('successful first report request preserves the report response contract', async t => {
  const pool = new SequencedReadPool([{}]);
  const response = await requestReports(
    t,
    new PostgresReportRepository(pool)
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), []);
  assert.equal(pool.connectCount, 1);
  assert.deepEqual(pool.clients[0].releaseArguments, [undefined]);
});

test('transient report read failure retries once with a fresh checkout', async t => {
  const firstError = transientError(
    'Connection terminated due to connection timeout'
  );
  const pool = new SequencedReadPool([
    { queryError: firstError },
    {}
  ]);
  const response = await requestReports(
    t,
    new PostgresReportRepository(pool)
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), []);
  assert.equal(pool.connectCount, 2);
  assert.equal(pool.clients.length, 2);
  assert.notEqual(pool.clients[0], pool.clients[1]);
  assert.deepEqual(pool.clients[0].releaseArguments, [firstError]);
  assert.deepEqual(pool.clients[1].releaseArguments, [undefined]);
});

test('repeated transient report read failure returns a clean HTTP 503', async t => {
  t.mock.method(console, 'error', () => {});
  const pool = new SequencedReadPool([
    {
      queryError: transientError('Connection terminated unexpectedly')
    },
    {
      connectError: Object.assign(new Error('connection closed'), {
        code: 'ETIMEDOUT'
      })
    }
  ]);
  const response = await requestReports(
    t,
    new PostgresReportRepository(pool)
  );
  const body = await response.json();

  assert.equal(response.status, 503);
  assert.deepEqual(body, {
    error: 'Database temporarily unavailable. Please try again.'
  });
  assert.equal(pool.connectCount, 2);
  assert.equal(JSON.stringify(body).includes('stack'), false);
  assert.equal(JSON.stringify(body).includes('terminated'), false);
});

test('non-transient database errors are not retried', async t => {
  t.mock.method(console, 'error', () => {});
  const syntaxError = Object.assign(
    new Error('syntax error at or near "select"'),
    { code: '42601' }
  );
  const pool = new SequencedReadPool([{ queryError: syntaxError }]);
  const response = await requestReports(
    t,
    new PostgresReportRepository(pool)
  );

  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), {
    error: 'Internal Server Error'
  });
  assert.equal(pool.connectCount, 1);
  assert.deepEqual(pool.clients[0].releaseArguments, [undefined]);
});

test('transient classifier is limited to connection failures', () => {
  for (const error of [
    new Error('Connection terminated due to connection timeout'),
    new Error('Connection terminated unexpectedly'),
    new Error('connection closed'),
    Object.assign(new Error('socket reset'), { code: 'ECONNRESET' }),
    Object.assign(new Error('socket timeout'), { code: 'ETIMEDOUT' }),
    Object.assign(new Error('connection failure'), { code: '08006' }),
    Object.assign(new Error('outer error'), {
      cause: new Error('Connection terminated unexpectedly')
    })
  ]) {
    assert.equal(isTransientPostgresError(error), true);
  }

  for (const error of [
    Object.assign(new Error('syntax error'), { code: '42601' }),
    Object.assign(new Error('permission denied'), { code: '42501' }),
    Object.assign(new Error('authentication failed'), { code: '28P01' }),
    Object.assign(new Error('check violation'), { code: '23514' })
  ]) {
    assert.equal(isTransientPostgresError(error), false);
  }
});
