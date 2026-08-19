begin;

alter table public.qc_reports
  add column sample_count integer not null default 1;

alter table public.qc_reports
  add constraint qc_reports_sample_count_positive check (sample_count > 0);

create or replace function public.are_canonical_qc_evidence_paths(paths text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(bool_and(
    object_path is not null and object_path ~
      '^reports/[A-Za-z0-9_-]{1,128}/(general/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}|checklist/[A-Za-z0-9_-]{1,128}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.(jpg|png|webp|heic)$'
  ), true)
  from unnest(paths) as evidence(object_path);
$$;

create table public.qc_report_samples (
  report_id text not null,
  id text not null,
  sample_number integer not null,
  inspection_status text not null default 'NOT_STARTED',
  notes text not null default '',
  photo_paths text[] not null default '{}',
  position integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (report_id, id),
  constraint qc_report_samples_report_fk
    foreign key (report_id)
    references public.qc_reports (id)
    on update cascade
    on delete cascade,
  constraint qc_report_samples_id_safe check (
    id ~ '^[A-Za-z0-9_-]{1,128}$'
  ),
  constraint qc_report_samples_number_positive check (sample_number > 0),
  constraint qc_report_samples_number_unique unique (report_id, sample_number),
  constraint qc_report_samples_status_check check (
    inspection_status in ('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED')
  ),
  constraint qc_report_samples_photo_paths_check check (
    public.are_canonical_qc_evidence_paths(photo_paths)
  ),
  constraint qc_report_samples_position_nonnegative check (position >= 0),
  constraint qc_report_samples_position_unique unique (report_id, position)
);

create index qc_report_samples_report_status_idx
  on public.qc_report_samples (report_id, inspection_status);

create table public.qc_report_sample_answers (
  report_id text not null,
  sample_id text not null,
  checklist_item_id text not null,
  input_type text not null,
  actual_value jsonb not null default '""'::jsonb,
  note text not null default '',
  photo_paths text[] not null default '{}',
  standard_text text not null default '',
  standard_value numeric,
  unit text not null default '',
  upper_tolerance numeric,
  lower_tolerance numeric,
  minimum_value numeric,
  maximum_value numeric,
  evaluation_status text not null default 'NOT_EVALUATED',
  position integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (report_id, sample_id, checklist_item_id),
  constraint qc_report_sample_answers_sample_fk
    foreign key (report_id, sample_id)
    references public.qc_report_samples (report_id, id)
    on update cascade
    on delete cascade,
  constraint qc_report_sample_answers_item_id_not_blank check (
    btrim(checklist_item_id) <> ''
  ),
  constraint qc_report_sample_answers_input_type_check check (
    input_type in ('number', 'text', 'choice', 'boolean')
  ),
  constraint qc_report_sample_answers_actual_value_check check (
    actual_value = 'null'::jsonb
    or jsonb_typeof(actual_value) in ('string', 'number', 'boolean')
  ),
  constraint qc_report_sample_answers_photo_paths_check check (
    public.are_canonical_qc_evidence_paths(photo_paths)
  ),
  constraint qc_report_sample_answers_range_check check (
    minimum_value is null
    or maximum_value is null
    or minimum_value <= maximum_value
  ),
  constraint qc_report_sample_answers_evaluation_check check (
    evaluation_status in ('NOT_EVALUATED', 'WITHIN_STANDARD', 'OUT_OF_STANDARD')
  ),
  constraint qc_report_sample_answers_position_nonnegative check (position >= 0),
  constraint qc_report_sample_answers_position_unique
    unique (report_id, sample_id, position)
);

create index qc_report_sample_answers_evaluation_idx
  on public.qc_report_sample_answers (report_id, sample_id, evaluation_status);

create trigger qc_report_samples_set_updated_at
before update on public.qc_report_samples
for each row execute function public.set_updated_at();

create trigger qc_report_sample_answers_set_updated_at
before update on public.qc_report_sample_answers
for each row execute function public.set_updated_at();

alter table public.qc_report_samples enable row level security;
alter table public.qc_report_sample_answers enable row level security;

commit;
