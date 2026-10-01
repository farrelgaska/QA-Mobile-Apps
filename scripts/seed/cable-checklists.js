const { canonicalTemplateInput } = require('../../src/repositories/postgres/mappers');

const item = (id, parameter_name, input_type, standard_text = '', extra = {}) => ({
  id, parameter_name, input_type, standard_text, is_required: true,
  required_photo: false, category: 'Pemeriksaan Sampel', ...extra
});
const common = [
  item('haspel', 'Nomor Haspel', 'text', '', { category: 'Identitas Sampel' }),
  item('core', 'Core ke', 'number', '', { min_value: 1, category: 'Identitas Sampel' }),
  item('warna_core', 'Warna Core', 'text', '', { category: 'Identitas Sampel' }),
  item('redaman_1310', 'Redaman λ 1310 nm', 'number', '<= 0.35 dB/km', {
    max_value: 0.35, unit: 'dB/km', required_photo: true
  }),
  item('redaman_1550', 'Redaman λ 1550 nm', 'number', '<= 0.215 dB/km', {
    max_value: 0.215, unit: 'dB/km'
  }),
  item('panjang_otdr', 'Panjang hasil ukur OTDR', 'number', '>= 4000 m', {
    min_value: 4000, unit: 'm'
  }),
  item('kontinuitas', 'Kontinuitas', 'choice', '✔ / ✖', {
    choice_options: [
      { id: 'pass', label: '✔', value: '✔', outcome: 'PASS', position: 0 },
      { id: 'fail', label: '✖', value: '✖', outcome: 'FAIL', position: 1 }
    ]
  }),
  // The form overlaps at five years; text keeps this an Admin-reviewed observation.
  item('tahun_produksi', 'Tahun Produksi', 'text', '≤ 5 Tahun / ≥ 5 Tahun')
];

const definitions = [
  ['QC_CABLE_DUCT', 'Kabel Duct', 'TA-FR-048-014-03', 'G.625D'],
  ['QC_CABLE_AERIAL', 'Kabel Aerial', 'TA-FR-048-014-02', 'G.652D/G.655C/G.655D/G.655E/G.656'],
  ['QC_CABLE_ADSS', 'Kabel ADSS', 'TA-FR-048-014-04', 'G.652D/G.655C/G.655D']
];
const cableChecklists = definitions.map(([id, name, form_code, cableType]) => canonicalTemplateInput({
  id, type: 'MATERIAL', name, form_code, category: 'CABLE', version: 2,
  description: `Pemeriksaan per sampel ${name}; Tipe Kabel: ${cableType}`,
  checklist_items: (id === 'QC_CABLE_AERIAL'
    ? [common[0], item('penandaan', 'Penandaan', 'text'), ...common.slice(1)]
    : common).map((entry, position) => ({ ...entry, position }))
}));

const seedCableChecklists = async (client, templateRepository) => {
  for (const template of cableChecklists) {
    const inserted = await client.query(
      `insert into public.qc_templates
         (id, type, name, description, form_code, category, segment,
          standard_code, is_active, version, created_at, updated_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       on conflict (id) do nothing returning id`,
      [template.id, template.type, template.name, template.description,
        template.form_code, template.category, template.segment,
        template.standard_code, template.is_active, template.version,
        template.created_at, template.updated_at]
    );
    if (inserted.rowCount) {
      await templateRepository._insertItems(client, template.id, template.checklist_items);
    }
  }
  await client.query(
    "update public.qc_templates set is_active = false where id in ('CABLE_AERIAL', 'CABLE_DUCT', 'CABLE_ADSS')"
  );
};

module.exports = { cableChecklists, seedCableChecklists };
