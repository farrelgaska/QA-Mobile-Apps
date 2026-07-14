const test = require('node:test');
const assert = require('node:assert/strict');

process.env.DATA_PROVIDER = 'json';
process.env.DATABASE_URL = 'postgresql://SECRET_USER:SECRET_PASSWORD@SECRET_HOST:6543/SECRET_DATABASE';
delete process.env.VERCEL;

const app = require('../../src/app');

test('health reports the data provider without leaking DATABASE_URL', async t => {
  const server = app.listen(0);
  t.after(() => server.close());
  await new Promise(resolve => server.once('listening', resolve));
  const response = await fetch(`http://127.0.0.1:${server.address().port}/health`);
  const body = await response.json();
  const serialized = JSON.stringify(body);

  assert.equal(response.status, 200);
  assert.equal(body.data_provider, 'json');
  assert.equal(body.database_reachable, false);
  assert.equal('storage_provider' in body, false);
  assert.equal(serialized.includes('SECRET_USER'), false);
  assert.equal(serialized.includes('SECRET_PASSWORD'), false);
  assert.equal(serialized.includes(process.env.DATABASE_URL), false);
});
