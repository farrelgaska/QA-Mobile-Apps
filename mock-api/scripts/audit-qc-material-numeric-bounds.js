const { getPool } = require('../src/database/postgres');
const { deriveQcMaterialNumericBounds } = require('../src/contracts/qc-material-numeric-bounds');

const auditQcMaterialNumericBounds = rows => {
  const supported = [];
  const unsupported = [];

  for (const row of rows) {
    const bounds = deriveQcMaterialNumericBounds(row.standard_text, row.validation_type);
    if (!bounds) {
      unsupported.push({
        template_id: row.template_id,
        item_id: row.item_id,
        standard_text: row.standard_text
      });
      continue;
    }

    supported.push({ ...row, bounds });
  }

  const needsBackfill = row => row.min_value === null
    && row.max_value === null
    && row.validation_min_value === null
    && row.validation_max_value === null;

  return {
    numeric_material_items: rows.length,
    supported_items: supported.length,
    would_update: supported.filter(needsBackfill).length,
    unsupported_items: unsupported.length,
    unsupported
  };
};

const run = async () => {
  const pool = getPool();
  try {
    const result = await pool.query(`
      select
        t.id as template_id,
        i.id as item_id,
        i.standard_text,
        i.validation_type,
        i.min_value,
        i.max_value,
        i.validation_min_value,
        i.validation_max_value
      from qc_templates t
      join qc_template_items i on i.template_id = t.id
      where t.type = 'MATERIAL'
        and i.input_type = 'number'
      order by t.id, i.position, i.id
    `);
    console.log(JSON.stringify(auditQcMaterialNumericBounds(result.rows), null, 2));
  } finally {
    await pool.end();
  }
};

if (require.main === module) {
  run().catch(error => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { auditQcMaterialNumericBounds };
