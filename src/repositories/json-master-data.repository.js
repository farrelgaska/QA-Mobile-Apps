const data = require('../../data/qc-material-master-data.json');

const normalize = value => String(value ?? '').trim().replace(/\s+/g, ' ').toLowerCase();
const byDisplayValue = (left, right) => left.localeCompare(right, 'id', { sensitivity: 'base' });

class MasterDataRepository {
  constructor(masterData = data) {
    this.materialFamilies = masterData.material_families;
    this.materials = masterData.materials;
    this.vendorMaterials = masterData.vendor_materials;
    this.warehouses = masterData.warehouses;
  }

  // ponytail: linear scans fit the 1,243-row read-only seed; add indexes only if measured latency grows.
  _activeMappings() {
    return this.vendorMaterials.filter(item => item.active);
  }

  _materialChoice(materialId, mappings = this._activeMappings()) {
    const normalizedId = normalize(materialId);
    const master = this.materials.find(item => item.active && normalize(item.material_id) === normalizedId);
    const related = mappings.filter(item => normalize(item.material_id) === normalizedId);
    if (!master && related.length === 0) return undefined;
    const names = new Map(related.map(item => [normalize(item.material_name), item.material_name]));
    return {
      material_id: master?.material_id ?? related[0].material_id,
      material_description: master?.material_description ?? null,
      core_count: master?.core_count ?? null,
      material_name: names.size === 1 ? names.values().next().value : null,
      family_id: master?.family_id ?? null,
      active: true
    };
  }

  findMaterialFamilies({ q = '', category = '' } = {}) {
    const query = normalize(q);
    const normalizedCategory = normalize(category);
    return this.materialFamilies
      .filter(item => item.active &&
        (!normalizedCategory || normalize(item.category) === normalizedCategory) &&
        (!query || [item.family_id, item.name].some(value => normalize(value).includes(query))))
      .map(item => ({ ...item }))
      .sort((left, right) => byDisplayValue(left.name, right.name));
  }

  findVendors({ q = '', materialId = '' } = {}) {
    const query = normalize(q);
    const normalizedMaterialId = normalize(materialId);
    const vendors = new Map();
    for (const item of this._activeMappings()) {
      if (normalizedMaterialId && normalize(item.material_id) !== normalizedMaterialId) continue;
      if (query && !normalize(item.vendor).includes(query)) continue;
      vendors.set(normalize(item.vendor), { vendor: item.vendor, active: true });
    }
    return [...vendors.values()].sort((left, right) => byDisplayValue(left.vendor, right.vendor));
  }

  findMaterials({ q = '', vendor = '', familyId = '' } = {}) {
    const query = normalize(q);
    const normalizedVendor = normalize(vendor);
    const normalizedFamilyId = normalize(familyId);
    const mappings = this._activeMappings().filter(
      item => !normalizedVendor || normalize(item.vendor) === normalizedVendor
    );
    const materialIds = normalizedVendor
      ? mappings.map(item => item.material_id)
      : [...this.materials.filter(item => item.active).map(item => item.material_id),
        ...mappings.map(item => item.material_id)];
    const choices = new Map();
    for (const materialId of materialIds) {
      const choice = this._materialChoice(materialId, mappings);
      if (!choice) continue;
      if (normalizedFamilyId && normalize(choice.family_id) !== normalizedFamilyId) continue;
      if (query && ![choice.material_id, choice.material_description, choice.material_name]
        .some(value => normalize(value).includes(query))) continue;
      choices.set(normalize(choice.material_id), choice);
    }
    return [...choices.values()].sort(
      (left, right) => byDisplayValue(left.material_id, right.material_id)
    );
  }

  findMaterialById(materialId) {
    return this._materialChoice(materialId);
  }

  findBrands({ vendor, materialId }) {
    const normalizedVendor = normalize(vendor);
    const normalizedMaterialId = normalize(materialId);
    const mappings = this._activeMappings().filter(item =>
      normalize(item.vendor) === normalizedVendor &&
      normalize(item.material_id) === normalizedMaterialId
    );
    const material = this._materialChoice(materialId, mappings);
    const choices = new Map();
    for (const item of mappings) {
      choices.set(normalize(item.brand), {
        brand: item.brand,
        manufacturer: item.manufacturer,
        material_name: item.material_name,
        material_description: material?.material_description ?? null,
        sap_material_id: item.sap_material_id,
        category: item.category,
        active: true
      });
    }
    const sortedChoices = [...choices.values()].sort(
      (left, right) => byDisplayValue(left.brand, right.brand)
    );
    return {
      vendor: mappings[0]?.vendor ?? String(vendor).trim(),
      material_id: material?.material_id ?? String(materialId).trim(),
      choices: sortedChoices,
      resolved: sortedChoices.length === 1 ? sortedChoices[0] : null
    };
  }

  findWarehouses({ q = '' } = {}) {
    const query = normalize(q);
    return this.warehouses
      .filter(item => item.active && (!query || [item.plant, item.name, item.branch, item.region]
        .some(value => normalize(value).includes(query))))
      .map(item => ({ ...item }))
      .sort((left, right) => byDisplayValue(left.plant, right.plant));
  }

  findWarehouseByPlant(plant) {
    const normalizedPlant = normalize(plant);
    const warehouse = this.warehouses.find(
      item => item.active && normalize(item.plant) === normalizedPlant
    );
    return warehouse ? { ...warehouse } : undefined;
  }
}

module.exports = new MasterDataRepository();
module.exports.MasterDataRepository = MasterDataRepository;
module.exports.normalize = normalize;
