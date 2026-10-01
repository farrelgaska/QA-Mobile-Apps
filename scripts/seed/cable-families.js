const fs = require('node:fs');
const path = require('node:path');

const dataPath = path.join(__dirname, '../../data/qc-material-master-data.json');
const coreCountPattern = /\b\d+\s+(?:core|c)\b/gi;
const display = value => String(value ?? '').trim().replace(/\s+/g, ' ');

const cableFamilyName = materialName => {
  const source = display(materialName);
  const matches = source.match(coreCountPattern) || [];
  if (matches.length !== 1) {
    throw new Error(`Expected exactly one core count in cable material name: ${source}`);
  }
  return display(source.replace(coreCountPattern, ''));
};

const cableFamilyKey = materialName => cableFamilyName(materialName)
  .toLowerCase()
  // The source uses both "G 652D" and "G652D" for the same fiber standard.
  .replace(/\bg\s+(\d{3}[a-z])\b/g, 'g$1');

const cableFamilyId = materialName => `cable-${cableFamilyKey(materialName)
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/^-|-$/g, '')}`;

// Provisional business mapping from the source material classification.
const cableChecklistId = materialName => {
  const name = display(materialName);
  if (/^KD FO\b/i.test(name)) return 'QC_CABLE_DUCT';
  if (/^KU (?:FO|Fiber Optik)\b/i.test(name) && /\bADSS\b/i.test(name)) return 'QC_CABLE_ADSS';
  if (/^KU FO\b/i.test(name)) return 'QC_CABLE_AERIAL';
  throw new Error(`Cable checklist classification needs confirmation: ${name}`);
};

const addCableFamilies = masterData => {
  const familiesByKey = new Map();
  const familyByMaterialId = new Map();

  for (const mapping of masterData.vendor_materials) {
    const key = cableFamilyKey(mapping.material_name);
    const family = familiesByKey.get(key) || {
      family_id: cableFamilyId(mapping.material_name),
      name: cableFamilyName(mapping.material_name),
      category: 'CABLE',
      template_id: cableChecklistId(mapping.material_name),
      active: false
    };
    if (family.template_id !== cableChecklistId(mapping.material_name)) {
      throw new Error(`Cable family has conflicting checklist types: ${family.name}`);
    }
    family.active ||= mapping.active;
    familiesByKey.set(key, family);

    const materialId = display(mapping.material_id).toLowerCase();
    const currentFamilyId = familyByMaterialId.get(materialId);
    if (currentFamilyId && currentFamilyId !== family.family_id) {
      throw new Error(`Material ${mapping.material_id} maps to multiple cable families`);
    }
    familyByMaterialId.set(materialId, family.family_id);
  }

  const familyIds = [...familiesByKey.values()].map(item => item.family_id);
  if (new Set(familyIds).size !== familyIds.length) {
    throw new Error('Normalized cable family IDs are not unique');
  }

  const materials = masterData.materials.map(material => ({
    ...material,
    family_id: familyByMaterialId.get(display(material.material_id).toLowerCase()) ?? null
  }));
  const materialIds = new Set(materials.map(item => display(item.material_id).toLowerCase()));
  const missing = [...familyByMaterialId.keys()].filter(materialId => !materialIds.has(materialId));
  if (missing.length > 0) {
    throw new Error(`Cable material IDs missing from material master: ${missing.join(', ')}`);
  }

  return {
    material_families: [...familiesByKey.values()].sort((left, right) =>
      left.name.localeCompare(right.name, 'id', { sensitivity: 'base' })),
    materials,
    vendor_materials: masterData.vendor_materials,
    warehouses: masterData.warehouses
  };
};

if (require.main === module) {
  const masterData = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  const result = addCableFamilies(masterData);
  fs.writeFileSync(dataPath, `${JSON.stringify(result, null, 2)}\n`);
  console.log(
    `Built ${result.material_families.length} cable families and ` +
    `${result.materials.filter(item => item.family_id).length} material mappings.`
  );
}

module.exports = { addCableFamilies, cableFamilyId, cableFamilyKey, cableFamilyName, cableChecklistId };
