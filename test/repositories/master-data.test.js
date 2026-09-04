const test = require('node:test');
const assert = require('node:assert/strict');

process.env.APP_ENV = 'development';
process.env.DATA_PROVIDER = 'json';
delete process.env.VERCEL;

const app = require('../../src/app');
const masterData = require('../../data/qc-material-master-data.json');
const masterDataRepository = require('../../src/repositories/json-master-data.repository');
const { MasterDataRepository } = require('../../src/repositories/json-master-data.repository');
const {
  addCableFamilies, cableFamilyId, cableFamilyName
} = require('../../scripts/seed/cable-families');

const withServer = async callback => {
  const server = app.listen(0);
  await new Promise(resolve => server.once('listening', resolve));
  try {
    await callback(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
};

test('vendor and material lists search and filter in both directions', () => {
  assert.equal(masterData.material_families.length, 14);
  assert.equal(masterData.materials.length, 419);
  assert.equal(masterData.vendor_materials.length, 385);
  assert.equal(masterData.warehouses.length, 442);
  const materialIds = new Set(masterData.materials.map(item => item.material_id));
  assert.ok(masterData.vendor_materials.every(item => materialIds.has(item.material_id)));
  assert.equal(masterDataRepository.findVendors().length, 23);
  assert.equal(masterDataRepository.findMaterials().length, 419);
  const vendors = masterDataRepository.findVendors({ q: 'komputindo' });
  assert.deepEqual(vendors, [{ vendor: 'ADHISAKTI SOLUSI KOMPUTINDO', active: true }]);

  const materials = masterDataRepository.findMaterials({
    vendor: '  adhisaKti   solusi komputindo  '
  });
  assert.ok(materials.length > 1);
  assert.ok(materials.some(item => item.material_id === 'DC-OF-SM-12D'));
  assert.ok(materials.every(item => item.material_name));
  assert.ok(masterDataRepository.findMaterials({ q: 'single mode 12' })
    .some(item => item.material_id === 'DC-OF-SM-12D'));

  const matchingVendors = masterDataRepository.findVendors({ materialId: 'dc-of-sm-12d' });
  assert.ok(matchingVendors.length > 1);
  assert.ok(matchingVendors.some(item => item.vendor === 'ADHISAKTI SOLUSI KOMPUTINDO'));
});

test('cable families remove only core count and map every cable row exactly once', () => {
  assert.equal(cableFamilyName('KD FO Single Mode 12 core G 652D'), 'KD FO Single Mode G 652D');
  assert.equal(cableFamilyName('KU FO ADSS 96 C G652D Marking Myrep'),
    'KU FO ADSS G652D Marking Myrep');
  assert.equal(cableFamilyName('KD FO Single Mode 12 core G 655C'),
    'KD FO Single Mode G 655C');
  assert.notEqual(
    cableFamilyId('KD FO Single Mode 12 core G652D'),
    cableFamilyId('KU FO Single Mode 12 core G652D')
  );
  assert.notEqual(
    cableFamilyId('KU FO ADSS 24 C G652D Marking Myrep'),
    cableFamilyId('KU FO ADSS 24 C G652D Marking JLM')
  );
  assert.notEqual(
    cableFamilyId('KD FO Single Mode 12 core G652D'),
    cableFamilyId('KD FO Single Mode 12 core G655C')
  );

  const rebuilt = addCableFamilies(masterData);
  assert.deepEqual(rebuilt.material_families, masterData.material_families);
  assert.equal(rebuilt.materials.filter(item => item.family_id).length, 53);
  assert.ok(masterData.vendor_materials.every(mapping =>
    rebuilt.materials.find(material =>
      material.material_id === mapping.material_id && material.family_id)));

  const families = masterDataRepository.findMaterialFamilies({ category: 'cable' });
  assert.equal(families.length, 14);
  const myrep = families.find(item => item.name === 'KU FO ADSS G652D Marking Myrep');
  assert.equal(myrep.family_id, 'cable-ku-fo-adss-g652d-marking-myrep');
  assert.equal(masterDataRepository.findMaterials({ familyId: myrep.family_id }).length, 6);
});

test('vendor and material resolve one brand, while unknown and ambiguous combinations do not', () => {
  const resolved = masterDataRepository.findBrands({
    vendor: 'adhisakti solusi komputindo',
    materialId: ' DC-OF-SM-12D '
  });
  assert.equal(resolved.choices.length, 1);
  assert.equal(resolved.resolved.brand, 'SUPERFIBER');
  assert.equal(resolved.resolved.material_name, 'KD FO Single Mode 12 core G 652D');
  assert.equal(resolved.resolved.material_description, 'KD FO Single Mode 12 core G 652D');
  assert.equal('warehouse' in resolved, false);

  const unknown = masterDataRepository.findBrands({ vendor: 'UNKNOWN', materialId: 'UNKNOWN' });
  assert.deepEqual(unknown.choices, []);
  assert.equal(unknown.resolved, null);

  const ambiguous = new MasterDataRepository({
    materials: [{ material_id: 'MAT-1', material_description: 'Material', active: true }],
    vendor_materials: [
      {
        vendor: 'Vendor', material_id: 'MAT-1', material_name: 'Material',
        sap_material_id: 'SAP-1', category: 'Cable', manufacturer: 'Factory A',
        brand: 'Brand A', active: true
      },
      {
        vendor: 'Vendor', material_id: 'MAT-1', material_name: 'Material',
        sap_material_id: 'SAP-1', category: 'Cable', manufacturer: 'Factory B',
        brand: 'Brand B', active: true
      }
    ],
    warehouses: []
  }).findBrands({ vendor: 'vendor', materialId: 'mat-1' });
  assert.deepEqual(ambiguous.choices.map(item => item.brand), ['Brand A', 'Brand B']);
  assert.equal(ambiguous.resolved, null);
});

test('material description and independent warehouse metadata are available', () => {
  assert.deepEqual(masterDataRepository.findMaterialById('dc-of-sm-12d'), {
    material_id: 'DC-OF-SM-12D',
    material_description: 'KD FO Single Mode 12 core G 652D',
    material_name: 'KD FO Single Mode 12 core G 652D',
    family_id: 'cable-kd-fo-single-mode-g652d',
    active: true
  });

  const batam = masterDataRepository.findWarehouses({ q: 'Batam' });
  assert.ok(batam.length > 1);
  assert.equal(masterDataRepository.findWarehouses().length, 442);
  assert.deepEqual(masterDataRepository.findWarehouseByPlant('1308'), {
    plant: '1308',
    name: 'Batam',
    area: '1',
    branch: 'Batam',
    region: 'SUMBAGTENG',
    active: true
  });
});

test('master-data HTTP endpoints preserve error, CORS, and request-id contracts', async () => {
  await withServer(async baseUrl => {
    const families = await fetch(`${baseUrl}/master-data/material-families?category=CABLE`);
    assert.equal((await families.json()).length, 14);

    const vendors = await fetch(`${baseUrl}/master-data/vendors?q=komputindo`);
    assert.deepEqual(await vendors.json(), [
      { vendor: 'ADHISAKTI SOLUSI KOMPUTINDO', active: true }
    ]);

    const materials = await fetch(
      `${baseUrl}/master-data/materials?vendor=ADHISAKTI%20SOLUSI%20KOMPUTINDO`
    );
    assert.ok((await materials.json()).some(item => item.material_id === 'DC-OF-SM-12D'));

    const familyMaterials = await fetch(
      `${baseUrl}/master-data/materials?family_id=cable-ku-fo-adss-g652d-marking-myrep`
    );
    assert.equal((await familyMaterials.json()).length, 6);

    const materialVendors = await fetch(
      `${baseUrl}/master-data/vendors?material_id=DC-OF-SM-12D`
    );
    assert.ok((await materialVendors.json()).length > 1);

    const material = await fetch(`${baseUrl}/master-data/materials/DC-OF-SM-12D`);
    assert.equal((await material.json()).material_description, 'KD FO Single Mode 12 core G 652D');

    const response = await fetch(
      `${baseUrl}/master-data/brands?vendor=ADHISAKTI%20SOLUSI%20KOMPUTINDO&material_id=DC-OF-SM-12D`,
      { headers: { origin: 'http://localhost:5173', 'x-request-id': 'master-data-test' } }
    );
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('x-request-id'), 'master-data-test');
    assert.equal(response.headers.get('access-control-allow-origin'), 'http://localhost:5173');
    assert.equal((await response.json()).resolved.brand, 'SUPERFIBER');

    const missingQuery = await fetch(`${baseUrl}/master-data/brands?vendor=Vendor`);
    assert.equal(missingQuery.status, 400);
    assert.deepEqual(await missingQuery.json(), {
      code: 'VALIDATION_ERROR',
      message: 'Data yang dikirim tidak valid.',
      status: 400,
      error: { code: 'VALIDATION_ERROR', message: 'Data yang dikirim tidak valid.' }
    });

    const missingWarehouse = await fetch(`${baseUrl}/master-data/warehouses/9999`);
    assert.equal(missingWarehouse.status, 404);
    assert.equal((await missingWarehouse.json()).code, 'NOT_FOUND');

    const warehouseSearch = await fetch(`${baseUrl}/master-data/warehouses?q=Batam`);
    assert.ok((await warehouseSearch.json()).some(item => item.plant === '1308'));

    const warehouse = await fetch(`${baseUrl}/master-data/warehouses/1308`);
    assert.equal((await warehouse.json()).region, 'SUMBAGTENG');

    const independentWarehouses = await fetch(
      `${baseUrl}/master-data/warehouses?vendor=UNKNOWN&material_id=UNKNOWN`
    );
    assert.equal(independentWarehouses.status, 200);
    assert.equal((await independentWarehouses.json()).length, 442);
  });
});
