const environment = require('../../src/config/env');
const { getPool } = require('../../src/database/postgres');
const { PostgresMasterDataRepository } = require('../../src/repositories/postgres-master-data.repository');
const { PostgresTemplateRepository } = require('../../src/repositories/postgres-template.repository');
const { seedCableChecklists } = require('./cable-checklists');
const { assertSafeToMutate } = require('./guard');
const masterData = require('../../data/qc-material-master-data.json');

const validateMasterDataReferences = data => {
  const familyCounts = new Map();
  const cableTypes = new Set(['QC_CABLE_DUCT', 'QC_CABLE_AERIAL', 'QC_CABLE_ADSS']);
  for (const family of data.material_families) {
    familyCounts.set(family.family_id, (familyCounts.get(family.family_id) || 0) + 1);
    if (family.category === 'CABLE' && !cableTypes.has(family.template_id)) {
      throw new Error(`Cable family ${family.family_id} has no valid checklist type`);
    }
  }
  const materialCounts = new Map();
  for (const material of data.materials) {
    materialCounts.set(material.material_id, (materialCounts.get(material.material_id) || 0) + 1);
  }
  const offendingIds = [...new Set(data.vendor_materials
    .filter(mapping => materialCounts.get(mapping.material_id) !== 1)
    .map(mapping => mapping.material_id))];
  if (offendingIds.length > 0) {
    throw new Error(
      `QC Material seed has vendor material IDs without exactly one matching material row: ${offendingIds.join(', ')}`
    );
  }
  const offendingFamilies = [...new Set(data.materials
    .filter(material => material.family_id && familyCounts.get(material.family_id) !== 1)
    .map(material => material.family_id))];
  if (offendingFamilies.length > 0) {
    throw new Error(
      `QC Material seed has family IDs without exactly one family row: ${offendingFamilies.join(', ')}`
    );
  }
  const unmappedCableIds = [...new Set(data.vendor_materials
    .filter(mapping => !data.materials.find(material =>
      material.material_id === mapping.material_id && material.family_id))
    .map(mapping => mapping.material_id))];
  if (unmappedCableIds.length > 0) {
    throw new Error(`QC Material seed has cable IDs without a family: ${unmappedCableIds.join(', ')}`);
  }
};

const seedMasterData = async ({
  pool,
  activeEnvironment = process.env,
  confirmProduction = false,
  data = masterData
} = {}) => {
  const appEnv = (activeEnvironment.APP_ENV || environment.APP_ENV).trim().toLowerCase();
  const dataProvider = (activeEnvironment.DATA_PROVIDER || environment.DATA_PROVIDER).trim().toLowerCase();
  if (dataProvider !== 'postgres') {
    throw new Error('QC Material database seed requires DATA_PROVIDER=postgres');
  }
  if (appEnv === 'production') {
    if (!confirmProduction) {
      throw new Error('Production QC Material seed requires --confirm-production');
    }
  } else {
    assertSafeToMutate(activeEnvironment);
  }

  validateMasterDataReferences(data);
  const databasePool = pool || getPool();
  const client = await databasePool.connect();
  try {
    await client.query('BEGIN');
    await seedCableChecklists(client, new PostgresTemplateRepository(databasePool));
    const counts = await new PostgresMasterDataRepository(databasePool).seed(data, client);
    await client.query('COMMIT');
    return counts;
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    throw error;
  } finally {
    client.release();
  }
};

const run = async args => {
  const unknown = args.filter(argument => argument !== '--confirm-production');
  if (unknown.length > 0) {
    throw new Error('Usage: master-data.js [--confirm-production]');
  }
  const counts = await seedMasterData({
    confirmProduction: args.includes('--confirm-production')
  });
  console.log(
    `Seeded QC Material master data: ${counts.material_families} families, ` +
    `${counts.materials} materials, ` +
    `${counts.vendor_materials} vendor mappings, ${counts.warehouses} warehouses.`
  );
  await getPool().end();
};

if (require.main === module) {
  run(process.argv.slice(2)).catch(error => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = { seedMasterData, run, validateMasterDataReferences };
