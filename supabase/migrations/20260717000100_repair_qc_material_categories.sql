begin;

do $migration$
declare
  missing_template_ids text;
begin
  with expected_categories (id, category) as (
    values
      ('tiang_7m_2_segmen', 'Tiang Besi'),
      ('tiang_besi_7m_3_segmen', 'Tiang Besi'),
      ('tiang_besi_9m_3_segmen', 'Tiang Besi'),
      ('tiang_galvanis_6m_tanpa_sambungan', 'Tiang Besi'),
      ('tiang_beton_7m', 'Tiang Beton'),
      ('tiang_beton_9m', 'Tiang Beton')
  )
  select string_agg(expected.id, ', ' order by expected.id)
    into missing_template_ids
  from expected_categories as expected
  left join public.qc_templates as template
    on template.id = expected.id
  where template.id is null;

  if missing_template_ids is not null then
    raise exception using
      errcode = 'P0001',
      message = format(
        'Required QC Material template IDs are missing: %s',
        missing_template_ids
      );
  end if;
end;
$migration$;

update public.qc_templates as template
set category = expected.category
from (
  values
    ('tiang_7m_2_segmen', 'Tiang Besi'),
    ('tiang_besi_7m_3_segmen', 'Tiang Besi'),
    ('tiang_besi_9m_3_segmen', 'Tiang Besi'),
    ('tiang_galvanis_6m_tanpa_sambungan', 'Tiang Besi'),
    ('tiang_beton_7m', 'Tiang Beton'),
    ('tiang_beton_9m', 'Tiang Beton')
) as expected (id, category)
where template.id = expected.id
  and template.type = 'MATERIAL'
  and template.category is distinct from expected.category;

do $migration$
declare
  invalid_templates text;
begin
  with expected_categories (id, category) as (
    values
      ('tiang_7m_2_segmen', 'Tiang Besi'),
      ('tiang_besi_7m_3_segmen', 'Tiang Besi'),
      ('tiang_besi_9m_3_segmen', 'Tiang Besi'),
      ('tiang_galvanis_6m_tanpa_sambungan', 'Tiang Besi'),
      ('tiang_beton_7m', 'Tiang Beton'),
      ('tiang_beton_9m', 'Tiang Beton')
  )
  select string_agg(
      format(
        '%s (type=%s, category=%s, expected_category=%s)',
        expected.id,
        coalesce(template.type, '<missing>'),
        coalesce(template.category, '<missing>'),
        expected.category
      ),
      ', ' order by expected.id
    )
    into invalid_templates
  from expected_categories as expected
  left join public.qc_templates as template
    on template.id = expected.id
  where template.id is null
     or template.type is distinct from 'MATERIAL'
     or template.category is distinct from expected.category;

  if invalid_templates is not null then
    raise exception using
      errcode = 'P0001',
      message = format(
        'QC Material template category assertion failed: %s',
        invalid_templates
      );
  end if;
end;
$migration$;

commit;
