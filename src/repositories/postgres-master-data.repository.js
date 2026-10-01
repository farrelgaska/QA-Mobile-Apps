const { getPool } = require('../database/postgres');
const { isTransientPostgresError, databaseUnavailable } = require('./repository-errors');

const display = value => String(value ?? '').trim().replace(/\s+/g, ' ');
const normalize = value => display(value).toLowerCase();

class PostgresMasterDataRepository {
  constructor(pool = getPool()) {
    this.pool = pool;
  }

  findMaterialFamilies({ q = '', category = '' } = {}) {
    return this._read(async client => {
      const result = await client.query(
        `select family_id, name, category, template_id, true as active
         from public.qc_material_families
         where is_active
           and ($1 = '' or lower(category) = $1)
           and ($2 = '' or lower(family_id) like '%' || $2 || '%'
             or lower(name) like '%' || $2 || '%')
         order by name`,
        [normalize(category), normalize(q)]
      );
      return result.rows;
    });
  }

  async _read(work) {
    for (let attempt = 0; attempt < 2; attempt++) {
      let client;
      let releaseError;
      try {
        client = await this.pool.connect();
        return await work(client);
      } catch (error) {
        if (!isTransientPostgresError(error)) throw error;
        releaseError = error;
        if (attempt === 1) throw databaseUnavailable(error);
      } finally {
        if (client) client.release(releaseError);
      }
    }
  }

  findVendors({ q = '', materialId = '' } = {}) {
    return this._read(async client => {
      const result = await client.query(
        `select distinct vm.vendor, true as active
         from public.qc_vendor_materials as vm
         join public.qc_materials as material on material.material_id = vm.material_id
         where vm.is_active and material.is_active
           and ($1 = '' or lower(vm.vendor) like '%' || $1 || '%')
           and ($2 = '' or lower(vm.material_id) = $2)
         order by vm.vendor`,
        [normalize(q), normalize(materialId)]
      );
      return result.rows;
    });
  }

  findMaterials({ q = '', vendor = '', familyId = '' } = {}) {
    return this._read(async client => {
      const result = await client.query(
        `with material_names as (
           select vm.material_id,
             case when count(distinct lower(vm.material_name)) = 1
               then min(vm.material_name) end as material_name
           from public.qc_vendor_materials as vm
           where vm.is_active and ($1 = '' or lower(vm.vendor) = $1)
           group by vm.material_id
         )
         select material.material_id, material.material_description, material.core_count, material.family_id,
           names.material_name, true as active
         from public.qc_materials as material
         left join material_names as names on names.material_id = material.material_id
         where material.is_active
           and ($1 = '' or names.material_id is not null)
           and ($3 = '' or lower(coalesce(material.family_id, '')) = $3)
           and ($2 = ''
             or lower(material.material_id) like '%' || $2 || '%'
             or lower(coalesce(material.material_description, '')) like '%' || $2 || '%'
             or lower(coalesce(names.material_name, '')) like '%' || $2 || '%')
         order by material.material_id`,
        [normalize(vendor), normalize(q), normalize(familyId)]
      );
      return result.rows;
    });
  }

  findMaterialById(materialId) {
    return this._read(async client => {
      const result = await client.query(
        `with material_names as (
           select vm.material_id,
             case when count(distinct lower(vm.material_name)) = 1
               then min(vm.material_name) end as material_name
           from public.qc_vendor_materials as vm
           where vm.is_active
           group by vm.material_id
         )
         select material.material_id, material.material_description, material.core_count, material.family_id,
           names.material_name, true as active
         from public.qc_materials as material
         left join material_names as names on names.material_id = material.material_id
         where material.is_active and lower(material.material_id) = $1`,
        [normalize(materialId)]
      );
      return result.rows[0];
    });
  }

  findBrands({ vendor, materialId }) {
    return this._read(async client => {
      const result = await client.query(
        `select distinct on (lower(vm.brand))
           vm.vendor, vm.material_id, vm.brand, vm.manufacturer, vm.material_name,
           material.material_description, vm.sap_material_id, vm.category, true as active
         from public.qc_vendor_materials as vm
         join public.qc_materials as material on material.material_id = vm.material_id
         where vm.is_active and material.is_active
           and lower(vm.vendor) = $1 and lower(vm.material_id) = $2
         order by lower(vm.brand), vm.brand, vm.manufacturer`,
        [normalize(vendor), normalize(materialId)]
      );
      let canonicalMaterialId = result.rows[0]?.material_id;
      if (!canonicalMaterialId) {
        const material = await client.query(
          `select material_id from public.qc_materials
           where is_active and lower(material_id) = $1`,
          [normalize(materialId)]
        );
        canonicalMaterialId = material.rows[0]?.material_id;
      }
      const choices = result.rows.map(({ vendor: _vendor, material_id: _materialId, ...choice }) => choice);
      return {
        vendor: result.rows[0]?.vendor ?? String(vendor).trim(),
        material_id: canonicalMaterialId ?? String(materialId).trim(),
        choices,
        resolved: choices.length === 1 ? choices[0] : null
      };
    });
  }

  findWarehouses({ q = '' } = {}) {
    return this._read(async client => {
      const result = await client.query(
        `select plant, name, area, branch, region, true as active
         from public.qc_warehouse_plants
         where is_active and ($1 = ''
           or lower(plant) like '%' || $1 || '%'
           or lower(name) like '%' || $1 || '%'
           or lower(branch) like '%' || $1 || '%'
           or lower(region) like '%' || $1 || '%')
         order by plant`,
        [normalize(q)]
      );
      return result.rows;
    });
  }

  findWarehouseByPlant(plant) {
    return this._read(async client => {
      const result = await client.query(
        `select plant, name, area, branch, region, true as active
         from public.qc_warehouse_plants
         where is_active and lower(plant) = $1`,
        [normalize(plant)]
      );
      return result.rows[0];
    });
  }

  async seed(masterData, executor = this.pool) {
    const materials = new Map(masterData.materials.map(item => {
      const material = { ...item, material_id: display(item.material_id) };
      return [normalize(material.material_id), material];
    }));
    for (const mapping of masterData.vendor_materials) {
      if (!materials.has(normalize(mapping.material_id))) {
        materials.set(normalize(mapping.material_id), {
          material_id: display(mapping.material_id),
          material_description: null,
          active: mapping.active
        });
      }
    }
    const vendorMaterials = masterData.vendor_materials.map(mapping => ({
      ...mapping,
      material_id: materials.get(normalize(mapping.material_id)).material_id
    }));

    await executor.query(
      `insert into public.qc_material_families (family_id, name, category, template_id, is_active)
       select family_id, name, category, template_id, active
       from jsonb_to_recordset($1::jsonb)
         as seed(family_id text, name text, category text, template_id text, active boolean)
       on conflict (lower(family_id)) do update set
         family_id = excluded.family_id,
         name = excluded.name,
         category = excluded.category,
         template_id = excluded.template_id,
         is_active = excluded.is_active`,
      [JSON.stringify(masterData.material_families)]
    );
    await executor.query(
      `insert into public.qc_materials (material_id, material_description, core_count, family_id, is_active)
       select material_id, material_description, core_count, family_id, active
       from jsonb_to_recordset($1::jsonb)
         as seed(material_id text, material_description text, core_count integer, family_id text, active boolean)
       on conflict (lower(material_id)) do update set
         material_id = excluded.material_id,
         material_description = excluded.material_description,
         core_count = excluded.core_count,
         family_id = excluded.family_id,
         is_active = excluded.is_active`,
      [JSON.stringify([...materials.values()])]
    );
    await executor.query(
      `insert into public.qc_vendor_materials (
         vendor, material_id, sap_material_id, material_name, category,
         manufacturer, brand, is_active
       )
       select vendor, material_id, sap_material_id, material_name, category,
         manufacturer, brand, active
       from jsonb_to_recordset($1::jsonb) as seed(
         vendor text, material_id text, sap_material_id text, material_name text,
         category text, manufacturer text, brand text, active boolean
       )
       on conflict (lower(vendor), lower(material_id), lower(brand)) do update set
         vendor = excluded.vendor,
         material_id = excluded.material_id,
         brand = excluded.brand,
         sap_material_id = excluded.sap_material_id,
         material_name = excluded.material_name,
         category = excluded.category,
         manufacturer = excluded.manufacturer,
         is_active = excluded.is_active`,
      [JSON.stringify(vendorMaterials)]
    );
    await executor.query(
      `insert into public.qc_warehouse_plants (plant, name, area, branch, region, is_active)
       select plant, name, area, branch, region, active
       from jsonb_to_recordset($1::jsonb)
         as seed(plant text, name text, area text, branch text, region text, active boolean)
       on conflict (lower(plant)) do update set
         plant = excluded.plant,
         name = excluded.name,
         area = excluded.area,
         branch = excluded.branch,
         region = excluded.region,
         is_active = excluded.is_active`,
      [JSON.stringify(masterData.warehouses)]
    );

    return {
      material_families: masterData.material_families.length,
      materials: materials.size,
      vendor_materials: vendorMaterials.length,
      warehouses: masterData.warehouses.length
    };
  }
}

module.exports = { PostgresMasterDataRepository };
