const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const migration = fs.readFileSync(path.join(
  __dirname,
  '../../supabase/migrations/20260903000100_add_qc_material_master_data.sql'
), 'utf8');
const familyMigration = fs.readFileSync(path.join(
  __dirname,
  '../../supabase/migrations/20260904000100_add_qc_material_families.sql'
), 'utf8');

test('master-data migration creates constrained persistent entities and no warehouse relation', () => {
  for (const table of ['qc_materials', 'qc_vendor_materials', 'qc_warehouse_plants']) {
    assert.match(migration, new RegExp(`create table public\\.${table}`));
    assert.match(migration, new RegExp(`alter table public\\.${table} enable row level security`));
    assert.match(migration, new RegExp(`create trigger ${table}_set_updated_at`));
  }

  assert.match(migration, /material_description text,/);
  assert.doesNotMatch(migration, /material_description text not null/);
  assert.match(migration, /primary key \(vendor, material_id, brand\)/);
  assert.match(migration, /foreign key \(material_id\)[\s\S]*references public\.qc_materials/);
  assert.match(migration, /qc_materials_id_case_insensitive_uidx/);
  assert.match(migration, /qc_vendor_materials_identity_case_insensitive_uidx/);
  assert.match(migration, /qc_vendor_materials_vendor_material_active_idx/);
  assert.match(migration, /qc_vendor_materials_material_vendor_active_idx/);
  assert.match(migration, /qc_warehouse_plants_plant_case_insensitive_uidx/);

  const warehouseTable = migration.match(
    /create table public\.qc_warehouse_plants \(([\s\S]*?)\n\);/
  )[1];
  assert.doesNotMatch(warehouseTable, /vendor|material_id/);
});

test('material-family migration adds a stable cable family relation', () => {
  assert.match(familyMigration, /create table public\.qc_material_families/);
  assert.match(familyMigration, /alter table public\.qc_material_families enable row level security/);
  assert.match(familyMigration, /create trigger qc_material_families_set_updated_at/);
  assert.match(familyMigration, /alter table public\.qc_materials[\s\S]*add column family_id text/);
  assert.match(familyMigration,
    /foreign key \(family_id\)[\s\S]*references public\.qc_material_families \(family_id\)/);
  assert.match(familyMigration, /qc_materials_family_active_idx/);
});
