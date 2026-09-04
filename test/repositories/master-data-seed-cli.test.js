const test = require('node:test');
const assert = require('node:assert/strict');

const { seedMasterData } = require('../../scripts/seed/master-data');

const recordingPool = ({ fail = false } = {}) => {
  const commands = [];
  let released = false;
  let connected = false;
  const client = {
    query: async text => {
      commands.push(text);
      if (fail && text.includes('qc_vendor_materials')) throw new Error('seed failed');
      return { rows: [], rowCount: 0 };
    },
    release: () => { released = true; }
  };
  return {
    commands,
    get released() { return released; },
    get connected() { return connected; },
    connect: async () => { connected = true; return client; }
  };
};

test('master-data-only seed is transactional, repeatable, and non-destructive', async () => {
  const pool = recordingPool();
  const options = {
    pool,
    activeEnvironment: { APP_ENV: 'development', DATA_PROVIDER: 'postgres' }
  };
  assert.deepEqual(await seedMasterData(options), {
    material_families: 14, materials: 419, vendor_materials: 385, warehouses: 442
  });
  assert.deepEqual(await seedMasterData(options), {
    material_families: 14, materials: 419, vendor_materials: 385, warehouses: 442
  });
  assert.equal(pool.commands.filter(command => command === 'BEGIN').length, 2);
  assert.equal(pool.commands.filter(command => command === 'COMMIT').length, 2);
  assert.equal(pool.commands.some(command => /delete|truncate/i.test(command)), false);
  assert.equal(pool.released, true);
});

test('production master-data seed requires explicit confirmation before connecting', async () => {
  const pool = recordingPool();
  await assert.rejects(
    seedMasterData({
      pool,
      activeEnvironment: { APP_ENV: 'production', DATA_PROVIDER: 'postgres' }
    }),
    /requires --confirm-production/
  );
  assert.equal(pool.connected, false);

  await assert.doesNotReject(seedMasterData({
    pool,
    activeEnvironment: { APP_ENV: 'production', DATA_PROVIDER: 'postgres' },
    confirmProduction: true
  }));
  assert.equal(pool.connected, true);
});

test('master-data seed rejects broken material references before connecting', async () => {
  const pool = recordingPool();
  await assert.rejects(seedMasterData({
    pool,
    activeEnvironment: { APP_ENV: 'production', DATA_PROVIDER: 'postgres' },
    confirmProduction: true,
    data: {
      material_families: [],
      materials: [{ material_id: 'MAT-1', material_description: 'Material', active: true }],
      vendor_materials: [{ material_id: 'mat-1' }, { material_id: 'MISSING' }],
      warehouses: []
    }
  }), /mat-1, MISSING/);
  assert.equal(pool.connected, false);
});

test('master-data seed rejects missing family references before connecting', async () => {
  const pool = recordingPool();
  await assert.rejects(seedMasterData({
    pool,
    activeEnvironment: { APP_ENV: 'production', DATA_PROVIDER: 'postgres' },
    confirmProduction: true,
    data: {
      material_families: [],
      materials: [{
        material_id: 'MAT-1', material_description: 'Material',
        family_id: 'cable-missing', active: true
      }],
      vendor_materials: [],
      warehouses: []
    }
  }), /cable-missing/);
  assert.equal(pool.connected, false);
});

test('master-data-only seed rolls back on failure', async () => {
  const pool = recordingPool({ fail: true });
  await assert.rejects(seedMasterData({
    pool,
    activeEnvironment: { APP_ENV: 'development', DATA_PROVIDER: 'postgres' }
  }), /seed failed/);
  assert.equal(pool.commands.includes('ROLLBACK'), true);
  assert.equal(pool.commands.includes('COMMIT'), false);
  assert.equal(pool.released, true);
});
