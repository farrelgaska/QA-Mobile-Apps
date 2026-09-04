const test = require('node:test');
const assert = require('node:assert/strict');

const masterData = require('../../data/qc-material-master-data.json');
const { PostgresMasterDataRepository } = require('../../src/repositories/postgres-master-data.repository');

class RecordingExecutor {
  constructor() {
    this.queries = [];
  }

  async query(text, parameters = []) {
    this.queries.push({ text, parameters });
    return { rows: [], rowCount: 0 };
  }
}

test('PostgreSQL master seed batches idempotent upserts with expected unique records', async () => {
  const executor = new RecordingExecutor();
  const repository = new PostgresMasterDataRepository(executor);

  const first = await repository.seed(masterData, executor);
  const second = await repository.seed(masterData, executor);

  assert.deepEqual(first, {
    material_families: 14, materials: 419, vendor_materials: 385, warehouses: 442
  });
  assert.deepEqual(second, first);
  assert.equal(executor.queries.length, 8);
  assert.ok(executor.queries.every(query => /on conflict/i.test(query.text)));
  assert.ok(executor.queries.every(query => !/truncate|delete from/i.test(query.text)));

  const families = JSON.parse(executor.queries[0].parameters[0]);
  const materials = JSON.parse(executor.queries[1].parameters[0]);
  const mappings = JSON.parse(executor.queries[2].parameters[0]);
  const warehouses = JSON.parse(executor.queries[3].parameters[0]);
  assert.equal(new Set(families.map(item => item.family_id.toLowerCase())).size, 14);
  assert.equal(new Set(materials.map(item => item.material_id.toLowerCase())).size, 419);
  assert.equal(new Set(warehouses.map(item => item.plant.toLowerCase())).size, 442);
  assert.equal(new Set(mappings.map(item =>
    [item.vendor, item.material_id, item.brand].map(value => value.toLowerCase()).join('\0')
  )).size, 385);
  const materialIds = new Set(materials.map(item => item.material_id));
  assert.ok(mappings.every(item => materialIds.has(item.material_id)));

  for (const materialId of [
    'DC-OF-SM-12D-MTEL',
    'DC-OF-SM-288D-MTEL',
    'DC-OF-SM-96D-TLIN'
  ]) {
    assert.deepEqual(
      materials.find(item => item.material_id === materialId),
      {
        material_id: materialId,
        material_description: null,
        family_id: materialId === 'DC-OF-SM-96D-TLIN'
          ? 'cable-kd-fo-sm-g652d-marking-telin'
          : 'cable-kd-fo-sm-g652d-marking-mitratel',
        active: true
      }
    );
  }
});

test('PostgreSQL master seed uses the material-master canonical ID for mappings', async () => {
  const executor = new RecordingExecutor();
  await new PostgresMasterDataRepository(executor).seed({
    material_families: [{ family_id: 'cable-adss', name: 'Cable ADSS', category: 'CABLE', active: true }],
    materials: [{
      material_id: ' AC-ADSS-144D-MREP ', material_description: 'ALISTA',
      family_id: 'cable-adss', active: true
    }],
    vendor_materials: [{
      vendor: 'Vendor', material_id: 'AC-ADSS-144D-Mrep', material_name: 'Cable',
      sap_material_id: null, category: '', manufacturer: 'Factory', brand: 'Brand', active: true
    }],
    warehouses: []
  }, executor);

  assert.equal(JSON.parse(executor.queries[1].parameters[0])[0].material_id, 'AC-ADSS-144D-MREP');
  assert.equal(JSON.parse(executor.queries[2].parameters[0])[0].material_id, 'AC-ADSS-144D-MREP');
});

class MasterDataPool {
  constructor() {
    this.queries = [];
    this.releaseCount = 0;
  }

  async connect() {
    return {
      query: async (text, parameters = []) => {
        this.queries.push({ text, parameters });
        if (text.includes('from public.qc_material_families')) {
          return { rows: [{ family_id: 'cable-1', name: 'Cable 1', category: 'CABLE', active: true }] };
        }
        if (text.includes('select distinct vm.vendor')) {
          return { rows: [{ vendor: 'Vendor A', active: true }] };
        }
        if (text.includes('with material_names') && parameters.length === 2) {
          return { rows: [{
            material_id: 'MAT-1', material_description: 'Description', family_id: 'cable-1',
            material_name: 'Mapped name', active: true
          }] };
        }
        if (text.includes('with material_names')) {
          return { rows: [{
            material_id: 'MAT-1', material_description: 'Description', family_id: 'cable-1',
            material_name: 'Mapped name', active: true
          }] };
        }
        if (text.includes('select distinct on')) {
          return { rows: [{
            vendor: 'Vendor A', material_id: 'MAT-1', brand: 'Brand A',
            manufacturer: 'Factory A', material_name: 'Mapped name',
            material_description: 'Description', sap_material_id: 'SAP-1',
            category: 'Cable', active: true
          }] };
        }
        if (text.includes("or lower(plant) like")) {
          return { rows: [{
            plant: '1308', name: 'Batam', area: '1', branch: 'Batam',
            region: 'SUMBAGTENG', active: true
          }] };
        }
        if (text.includes('from public.qc_warehouse_plants')) {
          return { rows: [{
            plant: '1308', name: 'Batam', area: '1', branch: 'Batam',
            region: 'SUMBAGTENG', active: true
          }] };
        }
        return { rows: [] };
      },
      release: () => { this.releaseCount += 1; }
    };
  }
}

test('PostgreSQL provider filters every master-data endpoint in database queries', async () => {
  const pool = new MasterDataPool();
  const repository = new PostgresMasterDataRepository(pool);

  assert.equal((await repository.findMaterialFamilies({
    category: ' CABLE ', q: ' Cable '
  }))[0].family_id, 'cable-1');
  assert.deepEqual(await repository.findVendors({
    q: '  VENDOR  ', materialId: ' MAT-1 '
  }), [{ vendor: 'Vendor A', active: true }]);
  assert.equal((await repository.findMaterials({
    vendor: ' vendor a ', q: ' Name ', familyId: ' CABLE-1 '
  }))[0].material_id, 'MAT-1');
  assert.equal((await repository.findMaterialById(' mat-1 ')).material_description, 'Description');
  assert.equal((await repository.findBrands({ vendor: ' vendor a ', materialId: ' mat-1 ' })).resolved.brand, 'Brand A');
  assert.equal((await repository.findWarehouses({ q: ' BATAM ' }))[0].plant, '1308');
  assert.equal((await repository.findWarehouseByPlant(' 1308 ')).region, 'SUMBAGTENG');

  assert.deepEqual(pool.queries[0].parameters, ['cable', 'cable']);
  assert.deepEqual(pool.queries[1].parameters, ['vendor', 'mat-1']);
  assert.deepEqual(pool.queries[2].parameters, ['vendor a', 'name', 'cable-1']);
  assert.deepEqual(pool.queries[3].parameters, ['mat-1']);
  assert.deepEqual(pool.queries[4].parameters, ['vendor a', 'mat-1']);
  assert.deepEqual(pool.queries[5].parameters, ['batam']);
  assert.deepEqual(pool.queries[6].parameters, ['1308']);
  assert.ok(pool.queries.some(query => query.text.includes('public.qc_vendor_materials')));
  assert.ok(pool.queries.some(query => query.text.includes('public.qc_materials')));
  assert.ok(pool.queries.some(query => query.text.includes('public.qc_warehouse_plants')));
  assert.equal(pool.releaseCount, 7);
});

test('PostgreSQL unknown vendor/material combinations return empty brand choices', async () => {
  const pool = {
    connect: async () => ({
      query: async () => ({ rows: [] }),
      release: () => {}
    })
  };
  const result = await new PostgresMasterDataRepository(pool).findBrands({
    vendor: 'Unknown', materialId: 'Unknown'
  });
  assert.deepEqual(result, {
    vendor: 'Unknown', material_id: 'Unknown', choices: [], resolved: null
  });
});
