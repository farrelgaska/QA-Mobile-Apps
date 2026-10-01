begin;

alter table public.qc_materials add column core_count integer;
alter table public.qc_materials add constraint qc_materials_core_count_positive
  check (core_count is null or core_count > 0);

-- Version 2 leaves legacy template IDs, items, and report snapshots intact.
insert into public.qc_templates
  (id, type, name, description, form_code, category, segment, standard_code, is_active, version)
values
  ('QC_CABLE_DUCT', 'MATERIAL', 'Kabel Duct', 'Pemeriksaan per sampel Kabel Duct; Tipe Kabel: G.625D', 'TA-FR-048-014-03', 'CABLE', 'construction', '', true, 2),
  ('QC_CABLE_AERIAL', 'MATERIAL', 'Kabel Aerial', 'Pemeriksaan per sampel Kabel Aerial; Tipe Kabel: G.652D/G.655C/G.655D/G.655E/G.656', 'TA-FR-048-014-02', 'CABLE', 'construction', '', true, 2),
  ('QC_CABLE_ADSS', 'MATERIAL', 'Kabel ADSS', 'Pemeriksaan per sampel Kabel ADSS; Tipe Kabel: G.652D/G.655C/G.655D', 'TA-FR-048-014-04', 'CABLE', 'construction', '', true, 2)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  form_code = excluded.form_code,
  category = excluded.category,
  is_active = true,
  version = excluded.version;

insert into public.qc_template_items
  (template_id, id, parameter_name, input_type, standard_text, min_value,
   max_value, unit, is_required, required_photo, category, position, choice_options)
values
  ('QC_CABLE_DUCT', 'haspel', 'Nomor Haspel', 'text', '', null, null, null, true, false, 'Identitas Sampel', 0, '[]'::jsonb),
  ('QC_CABLE_DUCT', 'core', 'Core ke', 'number', '', 1, null, null, true, false, 'Identitas Sampel', 1, '[]'::jsonb),
  ('QC_CABLE_DUCT', 'warna_core', 'Warna Core', 'text', '', null, null, null, true, false, 'Identitas Sampel', 2, '[]'::jsonb),
  ('QC_CABLE_DUCT', 'redaman_1310', 'Redaman λ 1310 nm', 'number', '<= 0.35 dB/km', null, 0.35, 'dB/km', true, true, 'Pemeriksaan Sampel', 3, '[]'::jsonb),
  ('QC_CABLE_DUCT', 'redaman_1550', 'Redaman λ 1550 nm', 'number', '<= 0.215 dB/km', null, 0.215, 'dB/km', true, false, 'Pemeriksaan Sampel', 4, '[]'::jsonb),
  ('QC_CABLE_DUCT', 'panjang_otdr', 'Panjang hasil ukur OTDR', 'number', '>= 4000 m', 4000, null, 'm', true, false, 'Pemeriksaan Sampel', 5, '[]'::jsonb),
  ('QC_CABLE_DUCT', 'kontinuitas', 'Kontinuitas', 'choice', '✔ / ✖', null, null, null, true, false, 'Pemeriksaan Sampel', 6, '[{"id":"pass","label":"✔","value":"✔","outcome":"PASS","position":0},{"id":"fail","label":"✖","value":"✖","outcome":"FAIL","position":1}]'::jsonb),
  ('QC_CABLE_DUCT', 'tahun_produksi', 'Tahun Produksi', 'text', '≤ 5 Tahun / ≥ 5 Tahun', null, null, null, true, false, 'Pemeriksaan Sampel', 7, '[]'::jsonb),
  ('QC_CABLE_AERIAL', 'haspel', 'Nomor Haspel', 'text', '', null, null, null, true, false, 'Identitas Sampel', 0, '[]'::jsonb),
  ('QC_CABLE_AERIAL', 'penandaan', 'Penandaan', 'text', '', null, null, null, true, false, 'Pemeriksaan Sampel', 1, '[]'::jsonb),
  ('QC_CABLE_AERIAL', 'core', 'Core ke', 'number', '', 1, null, null, true, false, 'Identitas Sampel', 2, '[]'::jsonb),
  ('QC_CABLE_AERIAL', 'warna_core', 'Warna Core', 'text', '', null, null, null, true, false, 'Identitas Sampel', 3, '[]'::jsonb),
  ('QC_CABLE_AERIAL', 'redaman_1310', 'Redaman λ 1310 nm', 'number', '<= 0.35 dB/km', null, 0.35, 'dB/km', true, true, 'Pemeriksaan Sampel', 4, '[]'::jsonb),
  ('QC_CABLE_AERIAL', 'redaman_1550', 'Redaman λ 1550 nm', 'number', '<= 0.215 dB/km', null, 0.215, 'dB/km', true, false, 'Pemeriksaan Sampel', 5, '[]'::jsonb),
  ('QC_CABLE_AERIAL', 'panjang_otdr', 'Panjang hasil ukur OTDR', 'number', '>= 4000 m', 4000, null, 'm', true, false, 'Pemeriksaan Sampel', 6, '[]'::jsonb),
  ('QC_CABLE_AERIAL', 'kontinuitas', 'Kontinuitas', 'choice', '✔ / ✖', null, null, null, true, false, 'Pemeriksaan Sampel', 7, '[{"id":"pass","label":"✔","value":"✔","outcome":"PASS","position":0},{"id":"fail","label":"✖","value":"✖","outcome":"FAIL","position":1}]'::jsonb),
  ('QC_CABLE_AERIAL', 'tahun_produksi', 'Tahun Produksi', 'text', '≤ 5 Tahun / ≥ 5 Tahun', null, null, null, true, false, 'Pemeriksaan Sampel', 8, '[]'::jsonb),
  ('QC_CABLE_ADSS', 'haspel', 'Nomor Haspel', 'text', '', null, null, null, true, false, 'Identitas Sampel', 0, '[]'::jsonb),
  ('QC_CABLE_ADSS', 'core', 'Core ke', 'number', '', 1, null, null, true, false, 'Identitas Sampel', 1, '[]'::jsonb),
  ('QC_CABLE_ADSS', 'warna_core', 'Warna Core', 'text', '', null, null, null, true, false, 'Identitas Sampel', 2, '[]'::jsonb),
  ('QC_CABLE_ADSS', 'redaman_1310', 'Redaman λ 1310 nm', 'number', '<= 0.35 dB/km', null, 0.35, 'dB/km', true, true, 'Pemeriksaan Sampel', 3, '[]'::jsonb),
  ('QC_CABLE_ADSS', 'redaman_1550', 'Redaman λ 1550 nm', 'number', '<= 0.215 dB/km', null, 0.215, 'dB/km', true, false, 'Pemeriksaan Sampel', 4, '[]'::jsonb),
  ('QC_CABLE_ADSS', 'panjang_otdr', 'Panjang hasil ukur OTDR', 'number', '>= 4000 m', 4000, null, 'm', true, false, 'Pemeriksaan Sampel', 5, '[]'::jsonb),
  ('QC_CABLE_ADSS', 'kontinuitas', 'Kontinuitas', 'choice', '✔ / ✖', null, null, null, true, false, 'Pemeriksaan Sampel', 6, '[{"id":"pass","label":"✔","value":"✔","outcome":"PASS","position":0},{"id":"fail","label":"✖","value":"✖","outcome":"FAIL","position":1}]'::jsonb),
  ('QC_CABLE_ADSS', 'tahun_produksi', 'Tahun Produksi', 'text', '≤ 5 Tahun / ≥ 5 Tahun', null, null, null, true, false, 'Pemeriksaan Sampel', 7, '[]'::jsonb)
on conflict (template_id, id) do update set
  parameter_name = excluded.parameter_name,
  input_type = excluded.input_type,
  standard_text = excluded.standard_text,
  min_value = excluded.min_value,
  max_value = excluded.max_value,
  unit = excluded.unit,
  is_required = excluded.is_required,
  required_photo = excluded.required_photo,
  category = excluded.category,
  position = excluded.position,
  choice_options = excluded.choice_options;

update public.qc_material_families
set template_id = case template_id
  when 'CABLE_AERIAL' then 'QC_CABLE_AERIAL'
  when 'CABLE_DUCT' then 'QC_CABLE_DUCT'
  when 'CABLE_ADSS' then 'QC_CABLE_ADSS'
end
where category = 'CABLE'
  and template_id in ('CABLE_AERIAL', 'CABLE_DUCT', 'CABLE_ADSS');

update public.qc_materials as material
set core_count = source.core_count
from (values
  ('AC-ADSS-144D-MREP', 144),
  ('AC-ADSS-24D-MREP', 24),
  ('AC-ADSS-288D-MREP', 288),
  ('AC-ADSS-36D-MREP', 36),
  ('AC-ADSS-48D-MREP', 48),
  ('AC-ADSS-96D-MREP', 96),
  ('AC-OF-ADSS-100-12C', 12),
  ('AC-OF-ADSS-100-24C', 24),
  ('AC-OF-ADSS-100-48C', 48),
  ('AC-OF-ADSS-100-96C', 96),
  ('AC-OF-ADSS-12D-JLM', 12),
  ('AC-OF-ADSS-24D-JLM', 24),
  ('AC-OF-ADSS-48D-JLM', 48),
  ('AC-OF-ADSS-6C-MTEL', 6),
  ('AC-OF-ADSS-96D-JLM', 96),
  ('AC-OF-SM-12-SC', 12),
  ('AC-OF-SM-12C', 12),
  ('AC-OF-SM-12D', 12),
  ('AC-OF-SM-12D-MTEL', 12),
  ('AC-OF-SM-24-SC', 24),
  ('AC-OF-SM-24C', 24),
  ('AC-OF-SM-24D', 24),
  ('AC-OF-SM-24D-MTEL', 24),
  ('AC-OF-SM-48C', 48),
  ('AC-OF-SM-48D', 48),
  ('AC-OF-SM-48D-MTEL', 48),
  ('AC-OF-SM-96C', 96),
  ('AC-OF-SM-96D', 96),
  ('AC-OF-SM-96D-MTEL', 96),
  ('AC-OF-SM-ADSS-12D', 12),
  ('AC-OF-SM-ADSS-24D', 24),
  ('AC-OF-SM-ADSS-48D', 48),
  ('AC-OF-SM-ADSS-96D', 96),
  ('DC-OF-SM-12-SC', 12),
  ('DC-OF-SM-12C', 12),
  ('DC-OF-SM-12D', 12),
  ('DC-OF-SM-12D-MTEL', 12),
  ('DC-OF-SM-144D', 144),
  ('DC-OF-SM-144D-MTEL', 144),
  ('DC-OF-SM-144D-TLIN', 144),
  ('DC-OF-SM-24-SC', 24),
  ('DC-OF-SM-24C', 24),
  ('DC-OF-SM-24D', 24),
  ('DC-OF-SM-24D-MTEL', 24),
  ('DC-OF-SM-288D', 288),
  ('DC-OF-SM-288D-MTEL', 288),
  ('DC-OF-SM-48C', 48),
  ('DC-OF-SM-48D', 48),
  ('DC-OF-SM-48D-MTEL', 48),
  ('DC-OF-SM-96C', 96),
  ('DC-OF-SM-96D', 96),
  ('DC-OF-SM-96D-MTEL', 96),
  ('DC-OF-SM-96D-TLIN', 96)
) as source(material_id, core_count)
where lower(material.material_id) = lower(source.material_id)
  and material.family_id in (
    select family_id from public.qc_material_families where category = 'CABLE'
  );

update public.qc_materials as material
set material_description = source.material_description
from (values
  ('DC-OF-SM-12D-MTEL', 'KD FO SM 12 core G652D Marking Mitratel'),
  ('DC-OF-SM-288D-MTEL', 'KD FO SM 288 core G652D Marking Mitratel'),
  ('DC-OF-SM-96D-TLIN', 'KD FO SM 96 core G652D Marking Telin')
) as source(material_id, material_description)
where lower(material.material_id) = lower(source.material_id)
  and material.material_description is null;

update public.qc_templates
set is_active = false
where id in ('CABLE_AERIAL', 'CABLE_DUCT', 'CABLE_ADSS');

commit;
