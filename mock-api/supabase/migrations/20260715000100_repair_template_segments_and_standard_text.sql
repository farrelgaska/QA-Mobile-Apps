begin;

do $migration$
declare
  missing_template_ids text;
  missing_item_ids text;
begin
  with required_templates (id) as (
    values
      ('pek-1'),
      ('pek-2'),
      ('pek-3'),
      ('pek-4'),
      ('pek-5'),
      ('pek-6'),
      ('pek-7'),
      ('tiang_7m_2_segmen'),
      ('tiang_besi_7m_3_segmen'),
      ('tiang_beton_7m'),
      ('tiang_beton_9m')
  )
  select string_agg(required.id, ', ' order by required.id)
    into missing_template_ids
  from required_templates as required
  left join public.qc_templates as template
    on template.id = required.id
  where template.id is null;

  if missing_template_ids is not null then
    raise exception using
      errcode = 'P0001',
      message = format(
        'Required QC template IDs are missing: %s',
        missing_template_ids
      );
  end if;

  with required_items (template_id, id) as (
    values
      ('pek-1', 'pek-1-c3'),
      ('tiang_7m_2_segmen', 't72-9'),
      ('tiang_7m_2_segmen', 't72-10'),
      ('tiang_7m_2_segmen', 't72-11'),
      ('tiang_besi_7m_3_segmen', 'tb73-6'),
      ('tiang_besi_7m_3_segmen', 'tb73-7'),
      ('tiang_besi_7m_3_segmen', 'tb73-14'),
      ('tiang_beton_7m', 'tb7-3'),
      ('tiang_beton_7m', 'tb7-4'),
      ('tiang_beton_7m', 'tb7-5'),
      ('tiang_beton_7m', 'tb7-6'),
      ('tiang_beton_9m', 'tb9-9')
  )
  select string_agg(
      format('%s/%s', required.template_id, required.id),
      ', ' order by required.template_id, required.id
    )
    into missing_item_ids
  from required_items as required
  left join public.qc_template_items as item
    on item.template_id = required.template_id
   and item.id = required.id
  where item.id is null;

  if missing_item_ids is not null then
    raise exception using
      errcode = 'P0001',
      message = format(
        'Required QC template item IDs are missing: %s',
        missing_item_ids
      );
  end if;
end;
$migration$;

update public.qc_templates as template
set segment = expected.segment
from (
  values
    ('pek-1', 'provisioning'),
    ('pek-2', 'provisioning'),
    ('pek-3', 'assurance'),
    ('pek-4', 'assurance'),
    ('pek-5', 'construction'),
    ('pek-6', 'construction'),
    ('pek-7', 'construction')
) as expected (id, segment)
where template.id = expected.id
  and template.type = 'WORK'
  and template.segment is distinct from expected.segment;

update public.qc_template_items as item
set standard_text = expected.standard_text
from (
  values
    ('pek-1', 'pek-1-c3', 'Nilai redaman ≤ -24 dBm'),
    ('tiang_7m_2_segmen', 't72-9', '≥ 52,5 kg'),
    ('tiang_7m_2_segmen', 't72-10', '≥ 3 mm'),
    ('tiang_7m_2_segmen', 't72-11', '≥ 40 cm'),
    ('tiang_besi_7m_3_segmen', 'tb73-6', '≥ 40 cm'),
    ('tiang_besi_7m_3_segmen', 'tb73-7', '≥ 3 mm'),
    ('tiang_besi_7m_3_segmen', 'tb73-14', '≥ 71,4 kg'),
    ('tiang_beton_7m', 'tb7-3', '≥ 0,25 m'),
    ('tiang_beton_7m', 'tb7-4', '≥ 0,35 m'),
    ('tiang_beton_7m', 'tb7-5', '≥ 0,35 m'),
    ('tiang_beton_7m', 'tb7-6', '≥ 7 m'),
    ('tiang_beton_9m', 'tb9-9', '≥ 9 m')
) as expected (template_id, id, standard_text)
where item.template_id = expected.template_id
  and item.id = expected.id
  and item.standard_text is distinct from expected.standard_text;

do $migration$
declare
  incorrect_segments text;
  incorrect_standard_texts text;
begin
  with expected_segments (id, segment) as (
    values
      ('pek-1', 'provisioning'),
      ('pek-2', 'provisioning'),
      ('pek-3', 'assurance'),
      ('pek-4', 'assurance'),
      ('pek-5', 'construction'),
      ('pek-6', 'construction'),
      ('pek-7', 'construction')
  )
  select string_agg(
      format(
        '%s (type=%s, segment=%s, expected=%s)',
        expected.id,
        coalesce(template.type, '<missing>'),
        coalesce(template.segment, '<missing>'),
        expected.segment
      ),
      ', ' order by expected.id
    )
    into incorrect_segments
  from expected_segments as expected
  left join public.qc_templates as template
    on template.id = expected.id
  where template.id is null
     or template.type is distinct from 'WORK'
     or template.segment is distinct from expected.segment;

  if incorrect_segments is not null then
    raise exception using
      errcode = 'P0001',
      message = format(
        'QC WORK template segment assertion failed: %s',
        incorrect_segments
      );
  end if;

  with expected_texts (template_id, id, standard_text) as (
    values
      ('pek-1', 'pek-1-c3', 'Nilai redaman ≤ -24 dBm'),
      ('tiang_7m_2_segmen', 't72-9', '≥ 52,5 kg'),
      ('tiang_7m_2_segmen', 't72-10', '≥ 3 mm'),
      ('tiang_7m_2_segmen', 't72-11', '≥ 40 cm'),
      ('tiang_besi_7m_3_segmen', 'tb73-6', '≥ 40 cm'),
      ('tiang_besi_7m_3_segmen', 'tb73-7', '≥ 3 mm'),
      ('tiang_besi_7m_3_segmen', 'tb73-14', '≥ 71,4 kg'),
      ('tiang_beton_7m', 'tb7-3', '≥ 0,25 m'),
      ('tiang_beton_7m', 'tb7-4', '≥ 0,35 m'),
      ('tiang_beton_7m', 'tb7-5', '≥ 0,35 m'),
      ('tiang_beton_7m', 'tb7-6', '≥ 7 m'),
      ('tiang_beton_9m', 'tb9-9', '≥ 9 m')
  )
  select string_agg(
      format(
        '%s/%s (actual=%s, expected=%s)',
        expected.template_id,
        expected.id,
        coalesce(item.standard_text, '<missing>'),
        expected.standard_text
      ),
      ', ' order by expected.template_id, expected.id
    )
    into incorrect_standard_texts
  from expected_texts as expected
  left join public.qc_template_items as item
    on item.template_id = expected.template_id
   and item.id = expected.id
  where item.id is null
     or item.standard_text is distinct from expected.standard_text;

  if incorrect_standard_texts is not null then
    raise exception using
      errcode = 'P0001',
      message = format(
        'QC template item standard_text assertion failed: %s',
        incorrect_standard_texts
      );
  end if;
end;
$migration$;

commit;
