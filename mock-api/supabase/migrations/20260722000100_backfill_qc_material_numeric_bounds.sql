begin;

create temporary table _qc_material_numeric_bound_candidates on commit drop as
select
  t.id as template_id,
  i.id as item_id,
  i.standard_text,
  i.validation_type,
  i.min_value,
  i.max_value,
  i.validation_min_value,
  i.validation_max_value
from public.qc_templates t
join public.qc_template_items i on i.template_id = t.id
where t.type = 'MATERIAL'
  and i.input_type = 'number';

create temporary table _qc_material_numeric_bound_derivations on commit drop as
with parsed as (
  select
    candidate.*,
    regexp_match(
      candidate.standard_text,
      '^[[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*(?:[[:alpha:]]+)?[[:space:]]*[+][[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*%[[:space:]]*-[[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*%[[:space:]]*$',
      'i'
    ) as asymmetric_percentage_parts,
    regexp_match(
      candidate.standard_text,
      '^[[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*(?:[[:alpha:]]+)?[[:space:]]*±[[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*%[[:space:]]*$',
      'i'
    ) as symmetric_percentage_parts,
    regexp_match(
      candidate.standard_text,
      '^[[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*(?:[[:alpha:]]+)?[[:space:]]*±[[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*(?:[[:alpha:]]+)?[[:space:]]*$',
      'i'
    ) as absolute_tolerance_parts,
    regexp_match(
      candidate.standard_text,
      '^[[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*-[[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*(?:[[:alpha:]]+)?[[:space:]]*$',
      'i'
    ) as explicit_range_parts,
    regexp_match(
      candidate.standard_text,
      '^[[:space:]]*(?:≥|>=|minimal[[:space:]]+)[[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*(?:[[:alpha:]]+)?[[:space:]]*$',
      'i'
    ) as explicit_minimum_parts,
    case when upper(coalesce(candidate.validation_type, '')) = 'EXACT' then
      regexp_match(
        candidate.standard_text,
        '^[[:space:]]*([0-9]+(?:[.,][0-9]+)?)[[:space:]]*(?:[[:alpha:]]+)?[[:space:]]*$',
        'i'
      )
    end as exact_number_parts
  from _qc_material_numeric_bound_candidates candidate
), derived as (
  select
    template_id,
    item_id,
    case
      when asymmetric_percentage_parts is not null then 'ASYMMETRIC_PERCENTAGE_TOLERANCE'
      when symmetric_percentage_parts is not null then 'SYMMETRIC_PERCENTAGE_TOLERANCE'
      when absolute_tolerance_parts is not null then 'ABSOLUTE_TOLERANCE'
      when explicit_range_parts is not null then 'EXPLICIT_RANGE'
      when explicit_minimum_parts is not null then 'EXPLICIT_MINIMUM'
      when exact_number_parts is not null then 'VALIDATION_QUALIFIED_EXACT'
    end as recognized_format,
    case
      when asymmetric_percentage_parts is not null then 'RANGE'
      when symmetric_percentage_parts is not null then 'RANGE'
      when absolute_tolerance_parts is not null then 'RANGE'
      when explicit_range_parts is not null then 'RANGE'
      when explicit_minimum_parts is not null then 'MIN'
      when exact_number_parts is not null then 'EXACT'
    end as derived_validation_type,
    case
      when asymmetric_percentage_parts is not null then
        replace(asymmetric_percentage_parts[1], ',', '.')::numeric
          * (1 - replace(asymmetric_percentage_parts[3], ',', '.')::numeric / 100)
      when symmetric_percentage_parts is not null then
        replace(symmetric_percentage_parts[1], ',', '.')::numeric
          * (1 - replace(symmetric_percentage_parts[2], ',', '.')::numeric / 100)
      when absolute_tolerance_parts is not null then
        replace(absolute_tolerance_parts[1], ',', '.')::numeric
          - replace(absolute_tolerance_parts[2], ',', '.')::numeric
      when explicit_range_parts is not null then
        replace(explicit_range_parts[1], ',', '.')::numeric
      when explicit_minimum_parts is not null then
        replace(explicit_minimum_parts[1], ',', '.')::numeric
      when exact_number_parts is not null then
        replace(exact_number_parts[1], ',', '.')::numeric
    end as derived_min_value,
    case
      when asymmetric_percentage_parts is not null then
        replace(asymmetric_percentage_parts[1], ',', '.')::numeric
          * (1 + replace(asymmetric_percentage_parts[2], ',', '.')::numeric / 100)
      when symmetric_percentage_parts is not null then
        replace(symmetric_percentage_parts[1], ',', '.')::numeric
          * (1 + replace(symmetric_percentage_parts[2], ',', '.')::numeric / 100)
      when absolute_tolerance_parts is not null then
        replace(absolute_tolerance_parts[1], ',', '.')::numeric
          + replace(absolute_tolerance_parts[2], ',', '.')::numeric
      when explicit_range_parts is not null then
        replace(explicit_range_parts[2], ',', '.')::numeric
      when exact_number_parts is not null then
        replace(exact_number_parts[1], ',', '.')::numeric
    end as derived_max_value
  from parsed
)
select *
from derived
where recognized_format is not null
  and derived_min_value is not null
  and (derived_max_value is null or derived_min_value <= derived_max_value);

do $$
declare
  updated_count integer;
  unsupported_count integer;
  unsupported_items text;
begin
  update public.qc_template_items item
  set
    min_value = derivation.derived_min_value,
    max_value = derivation.derived_max_value,
    validation_type = derivation.derived_validation_type,
    validation_min_value = derivation.derived_min_value,
    validation_max_value = derivation.derived_max_value
  from _qc_material_numeric_bound_derivations derivation
  where item.template_id = derivation.template_id
    and item.id = derivation.item_id
    and item.min_value is null
    and item.max_value is null
    and item.validation_min_value is null
    and item.validation_max_value is null;

  get diagnostics updated_count = row_count;

  if exists (
    select 1
    from _qc_material_numeric_bound_candidates candidate
    join public.qc_template_items item
      on item.template_id = candidate.template_id
      and item.id = candidate.item_id
    where item.standard_text is distinct from candidate.standard_text
  ) then
    raise exception 'QC Material numeric bounds migration changed standard_text';
  end if;

  select count(*)
  into unsupported_count
  from _qc_material_numeric_bound_candidates candidate
  left join _qc_material_numeric_bound_derivations derivation
    on derivation.template_id = candidate.template_id
    and derivation.item_id = candidate.item_id
  where derivation.item_id is null;

  select string_agg(
    format(
      'template_id=%s item_id=%s standard_text=%L',
      candidate.template_id,
      candidate.item_id,
      candidate.standard_text
    ),
    E'\n'
    order by candidate.template_id, candidate.item_id
  )
  into unsupported_items
  from _qc_material_numeric_bound_candidates candidate
  left join _qc_material_numeric_bound_derivations derivation
    on derivation.template_id = candidate.template_id
    and derivation.item_id = candidate.item_id
  where derivation.item_id is null;

  raise notice
    'QC Material numeric bounds: updated %, unsupported %',
    updated_count,
    unsupported_count;

  if unsupported_count > 0 then
    raise notice 'Unsupported QC Material numeric standards:%', E'\n' || unsupported_items;
  end if;
end $$;

commit;
