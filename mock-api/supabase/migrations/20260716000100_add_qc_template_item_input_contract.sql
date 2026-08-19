begin;

alter table public.qc_template_items
  add column if not exists min_value numeric,
  add column if not exists max_value numeric,
  add column if not exists choice_options jsonb not null default '[]'::jsonb;

alter table public.qc_template_items
  alter column unit drop not null;

alter table public.qc_template_items
  drop constraint if exists qc_template_items_bounds_check;

alter table public.qc_template_items
  add constraint qc_template_items_bounds_check check (
    min_value is null
    or max_value is null
    or min_value <= max_value
  );

alter table public.qc_template_items
  drop constraint if exists qc_template_items_choice_options_array_check;

alter table public.qc_template_items
  add constraint qc_template_items_choice_options_array_check check (
    jsonb_typeof(choice_options) = 'array'
  );

commit;
