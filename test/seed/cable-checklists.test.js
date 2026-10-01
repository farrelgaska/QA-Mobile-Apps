const test = require('node:test');
const assert = require('node:assert/strict');
const data = require('../../data/qc-material-master-data.json');
const jsonTemplates = require('../../data/templates.json');
const { cableChecklists } = require('../../scripts/seed/cable-checklists');
const { addCableFamilies } = require('../../scripts/seed/cable-families');
const { MasterDataRepository } = require('../../src/repositories/json-master-data.repository');

test('all 53 cable IDs resolve through stored families to exactly three QC templates', () => {
  const templates = new Map(cableChecklists.map(template => [template.id, template]));
  assert.deepEqual([...templates.keys()].sort(), [
    'QC_CABLE_ADSS', 'QC_CABLE_AERIAL', 'QC_CABLE_DUCT'
  ]);
  assert.equal(data.vendor_materials.length, 385);
  assert.equal(data.material_families.length, 14);
  assert.deepEqual(addCableFamilies(data).material_families, data.material_families);
  const families = new Map(data.material_families.map(family => [family.family_id, family]));
  const materials = data.materials.filter(material => material.family_id);
  assert.equal(materials.length, 53);
  assert.equal(new Set(materials.map(material => material.material_id.toLowerCase())).size, 53);
  assert.deepEqual([...new Set(materials.map(material => material.core_count))].sort((a, b) => a - b),
    [6, 12, 24, 36, 48, 96, 144, 288]);
  const counts = {};
  const repository = new MasterDataRepository(data);
  for (const material of materials) {
    const resolved = repository.findMaterialById(material.material_id);
    const templateId = families.get(resolved.family_id)?.template_id;
    assert.ok(templates.has(templateId), material.material_id);
    assert.equal(resolved.core_count, material.core_count);
    assert.ok(Number.isInteger(resolved.core_count) && resolved.core_count > 0);
    assert.equal('sample_count' in resolved, false);
    counts[templateId] = (counts[templateId] || 0) + 1;
  }
  assert.deepEqual(counts, {
    QC_CABLE_ADSS: 19, QC_CABLE_AERIAL: 14, QC_CABLE_DUCT: 20
  });
  for (const [id, materialId] of [
    ['QC_CABLE_AERIAL', 'AC-OF-SM-24D'],
    ['QC_CABLE_DUCT', 'DC-OF-SM-24D'],
    ['QC_CABLE_ADSS', 'AC-OF-SM-ADSS-24D']
  ]) {
    assert.equal(families.get(repository.findMaterialById(materialId).family_id).template_id, id);
  }
  for (const id of ['DC-OF-SM-12D-MTEL', 'DC-OF-SM-288D-MTEL', 'DC-OF-SM-96D-TLIN']) {
    assert.ok(repository.findMaterialById(id).material_description);
  }
});

test('official cable parameters, inclusive bounds, and Admin approval separation', () => {
  for (const template of cableChecklists) {
    const items = new Map(template.checklist_items.map(item => [item.id, item]));
    assert.deepEqual([...items.keys()].filter(id => id !== 'penandaan'), [
      'haspel', 'core', 'warna_core', 'redaman_1310', 'redaman_1550',
      'panjang_otdr', 'kontinuitas', 'tahun_produksi'
    ]);
    assert.equal(items.has('penandaan'), template.id === 'QC_CABLE_AERIAL');
    assert.equal(items.get('penandaan')?.input_type, template.id === 'QC_CABLE_AERIAL' ? 'text' : undefined);
    assert.equal(items.get('core').input_type, 'number');
    assert.equal(items.get('core').min_value, 1);
    assert.equal(items.get('warna_core').input_type, 'text');
    assert.equal(items.get('tahun_produksi').input_type, 'text');
    assert.equal(items.get('tahun_produksi').standard_text, '≤ 5 Tahun / ≥ 5 Tahun');
    assert.deepEqual(items.get('kontinuitas').choice_options.map(option => option.value), ['✔', '✖']);
    for (const [id, bound, unit] of [
      ['redaman_1310', 0.35, 'dB/km'],
      ['redaman_1550', 0.215, 'dB/km']
    ]) {
      const item = items.get(id);
      assert.equal(item.max_value, bound);
      assert.equal(item.unit, unit);
      assert.equal(bound <= item.max_value, true);
      assert.equal(bound + 0.001 <= item.max_value, false);
    }
    const otdr = items.get('panjang_otdr');
    assert.equal(otdr.min_value, 4000);
    assert.equal(otdr.unit, 'm');
    assert.equal(4000 >= otdr.min_value, true);
    assert.equal(3999 >= otdr.min_value, false);
    assert.equal(items.has('kesimpulan'), false);
    assert.equal(JSON.stringify(template.checklist_items).includes('Diterima'), false);
    assert.equal(JSON.stringify(template.checklist_items).includes('Ditolak'), false);
    assert.deepEqual(jsonTemplates.find(item => item.id === template.id).checklist_items,
      template.checklist_items);
  }
  assert.match(cableChecklists.find(item => item.id === 'QC_CABLE_DUCT').description, /G\.625D/);
  assert.ok(jsonTemplates.filter(item => item.category === 'CABLE' && item.is_active).length === 3);
  assert.ok(jsonTemplates.filter(item => /^CABLE_/.test(item.id)).every(item => item.is_active === false));
});
