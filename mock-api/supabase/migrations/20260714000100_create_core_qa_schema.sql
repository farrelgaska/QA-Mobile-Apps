begin;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.qc_templates (
  id text primary key,
  type text not null,
  name text not null,
  description text not null default '',
  form_code text not null default '',
  category text not null default '',
  segment text not null default 'construction',
  standard_code text not null default '',
  is_active boolean not null default true,
  workflow_status text,
  version integer not null default 1,
  migration_metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint qc_templates_id_not_blank check (btrim(id) <> ''),
  constraint qc_templates_type_check check (type in ('MATERIAL', 'WORK')),
  constraint qc_templates_workflow_status_check check (
    workflow_status is null or workflow_status in ('IN_PROGRESS', 'COMPLETED')
  ),
  constraint qc_templates_version_positive check (version > 0),
  constraint qc_templates_migration_metadata_object check (
    migration_metadata is null or jsonb_typeof(migration_metadata) = 'object'
  )
);

create unique index qc_templates_form_code_version_uidx
  on public.qc_templates (form_code, version)
  where form_code <> '';
create index qc_templates_type_active_idx
  on public.qc_templates (type, is_active);
create index qc_templates_workflow_status_idx
  on public.qc_templates (workflow_status)
  where workflow_status is not null;
create index qc_templates_standard_code_idx
  on public.qc_templates (standard_code)
  where standard_code <> '';

create table public.qc_template_items (
  template_id text not null,
  id text not null,
  parameter_name text not null,
  input_type text not null,
  standard_text text not null default '',
  unit text not null default '',
  is_required boolean not null,
  required_photo boolean not null,
  is_active boolean not null default true,
  is_critical boolean not null default false,
  position integer not null default 0,
  choices text[] not null default '{}'::text[],
  category text not null default '',
  validation_type text,
  validation_min_value numeric,
  validation_max_value numeric,
  validation_exact_value jsonb,
  migration_metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (template_id, id),
  constraint qc_template_items_template_fk
    foreign key (template_id)
    references public.qc_templates (id)
    on update cascade
    on delete cascade,
  constraint qc_template_items_id_not_blank check (btrim(id) <> ''),
  constraint qc_template_items_input_type_check check (
    input_type in ('number', 'text', 'choice', 'boolean')
  ),
  constraint qc_template_items_position_nonnegative check (position >= 0),
  constraint qc_template_items_validation_range_check check (
    validation_min_value is null
    or validation_max_value is null
    or validation_min_value <= validation_max_value
  ),
  constraint qc_template_items_migration_metadata_object check (
    migration_metadata is null or jsonb_typeof(migration_metadata) = 'object'
  ),
  constraint qc_template_items_template_position_unique
    unique (template_id, position)
    deferrable initially immediate
);

create index qc_template_items_template_active_idx
  on public.qc_template_items (template_id, is_active, position);
create index qc_template_items_input_type_idx
  on public.qc_template_items (input_type);
create index qc_template_items_category_idx
  on public.qc_template_items (category)
  where category <> '';

create table public.qc_reports (
  id text primary key,
  type text not null,
  template_id text,
  form_code text not null default '',
  title text not null,
  status text not null default 'DRAFT',
  staff_name text not null default '',
  staff_nik text not null default '',
  site_id text not null default '',
  site_name text not null default '',
  area text not null default '',
  detail_location text not null default '',
  general_info jsonb not null default '{}'::jsonb,
  staff_note text not null default '',
  submitted_at timestamptz,
  revision_number integer not null default 1,
  migration_metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint qc_reports_template_fk
    foreign key (template_id)
    references public.qc_templates (id)
    on update cascade
    on delete set null,
  constraint qc_reports_id_not_blank check (btrim(id) <> ''),
  constraint qc_reports_type_check check (type in ('MATERIAL', 'WORK')),
  constraint qc_reports_status_check check (
    status in ('DRAFT', 'SUBMITTED', 'NEEDS_FOLLOW_UP', 'APPROVED')
  ),
  constraint qc_reports_revision_number_positive check (revision_number > 0),
  constraint qc_reports_general_info_object check (jsonb_typeof(general_info) = 'object'),
  constraint qc_reports_migration_metadata_object check (
    migration_metadata is null or jsonb_typeof(migration_metadata) = 'object'
  )
);

create index qc_reports_status_submitted_at_idx
  on public.qc_reports (status, submitted_at desc);
create index qc_reports_template_id_idx
  on public.qc_reports (template_id)
  where template_id is not null;
create index qc_reports_form_code_idx
  on public.qc_reports (form_code)
  where form_code <> '';
create index qc_reports_staff_nik_idx
  on public.qc_reports (staff_nik)
  where staff_nik <> '';
create index qc_reports_site_id_idx
  on public.qc_reports (site_id)
  where site_id <> '';

create table public.qc_report_items (
  report_id text not null,
  id text not null,
  parameter_name text not null,
  input_type text not null,
  standard_text text not null default '',
  unit text not null default '',
  actual_value text not null default '',
  staff_note text not null default '',
  admin_evaluation text not null default 'PENDING',
  admin_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (report_id, id),
  constraint qc_report_items_report_fk
    foreign key (report_id)
    references public.qc_reports (id)
    on update cascade
    on delete cascade,
  constraint qc_report_items_id_not_blank check (btrim(id) <> ''),
  constraint qc_report_items_input_type_check check (
    input_type in ('number', 'text', 'choice', 'boolean')
  ),
  constraint qc_report_items_admin_evaluation_check check (
    admin_evaluation in ('PASS', 'FAIL', 'NEEDS_REVIEW', 'PENDING')
  )
);

create index qc_report_items_report_evaluation_idx
  on public.qc_report_items (report_id, admin_evaluation);

create table public.qc_report_admin_reviews (
  report_id text primary key,
  admin_note text not null default '',
  conclusion text,
  reviewed_at timestamptz,
  reviewed_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint qc_report_admin_reviews_report_fk
    foreign key (report_id)
    references public.qc_reports (id)
    on update cascade
    on delete cascade,
  constraint qc_report_admin_reviews_conclusion_check check (
    conclusion is null
    or conclusion in ('PASSED', 'NOT_PASSED')
  )
);

create index qc_report_admin_reviews_conclusion_idx
  on public.qc_report_admin_reviews (conclusion)
  where conclusion is not null;
create index qc_report_admin_reviews_reviewed_by_idx
  on public.qc_report_admin_reviews (reviewed_by)
  where reviewed_by is not null;

create table public.qc_report_attachments (
  id bigint generated by default as identity primary key,
  report_id text not null,
  report_item_id text,
  attachment_scope text not null,
  uri text not null,
  sort_order integer not null default 0,
  file_name text,
  content_type text,
  byte_size bigint,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint qc_report_attachments_report_fk
    foreign key (report_id)
    references public.qc_reports (id)
    on update cascade
    on delete cascade,
  constraint qc_report_attachments_report_item_fk
    foreign key (report_id, report_item_id)
    references public.qc_report_items (report_id, id)
    on update cascade
    on delete cascade,
  constraint qc_report_attachments_scope_check check (
    (attachment_scope = 'GENERAL' and report_item_id is null)
    or (attachment_scope = 'ITEM' and report_item_id is not null)
  ),
  constraint qc_report_attachments_uri_not_blank check (btrim(uri) <> ''),
  constraint qc_report_attachments_sort_order_nonnegative check (sort_order >= 0),
  constraint qc_report_attachments_byte_size_nonnegative check (byte_size is null or byte_size >= 0),
  constraint qc_report_attachments_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index qc_report_attachments_general_order_uidx
  on public.qc_report_attachments (report_id, sort_order)
  where attachment_scope = 'GENERAL';
create unique index qc_report_attachments_item_order_uidx
  on public.qc_report_attachments (report_id, report_item_id, sort_order)
  where attachment_scope = 'ITEM';
create index qc_report_attachments_report_idx
  on public.qc_report_attachments (report_id);
create index qc_report_attachments_report_item_idx
  on public.qc_report_attachments (report_id, report_item_id)
  where report_item_id is not null;

create or replace function public.validate_qc_report_final_conclusion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_report_id text;
  report_status text;
  review_conclusion text;
begin
  if tg_table_name = 'qc_reports' then
    target_report_id := case when tg_op = 'DELETE' then old.id else new.id end;
  else
    target_report_id := case when tg_op = 'DELETE' then old.report_id else new.report_id end;
  end if;

  select report.status, review.conclusion
    into report_status, review_conclusion
  from public.qc_reports as report
  left join public.qc_report_admin_reviews as review
    on review.report_id = report.id
  where report.id = target_report_id;

  if not found then
    return null;
  end if;

  if report_status in ('NEEDS_FOLLOW_UP', 'APPROVED')
     and review_conclusion is null then
    raise exception using
      errcode = '23514',
      message = format(
        'Report %s with status %s requires an explicit final conclusion',
        target_report_id,
        report_status
      );
  end if;

  return null;
end;
$$;

revoke all on function public.validate_qc_report_final_conclusion() from public;

create constraint trigger qc_reports_final_conclusion_check
after insert or update on public.qc_reports
deferrable initially deferred
for each row
execute function public.validate_qc_report_final_conclusion();

create constraint trigger qc_report_admin_reviews_final_conclusion_check
after insert or update or delete on public.qc_report_admin_reviews
deferrable initially deferred
for each row
execute function public.validate_qc_report_final_conclusion();

create trigger qc_templates_set_updated_at
before update on public.qc_templates
for each row execute function public.set_updated_at();
create trigger qc_template_items_set_updated_at
before update on public.qc_template_items
for each row execute function public.set_updated_at();
create trigger qc_reports_set_updated_at
before update on public.qc_reports
for each row execute function public.set_updated_at();
create trigger qc_report_items_set_updated_at
before update on public.qc_report_items
for each row execute function public.set_updated_at();
create trigger qc_report_admin_reviews_set_updated_at
before update on public.qc_report_admin_reviews
for each row execute function public.set_updated_at();
create trigger qc_report_attachments_set_updated_at
before update on public.qc_report_attachments
for each row execute function public.set_updated_at();

alter table public.qc_templates enable row level security;
alter table public.qc_template_items enable row level security;
alter table public.qc_reports enable row level security;
alter table public.qc_report_items enable row level security;
alter table public.qc_report_admin_reviews enable row level security;
alter table public.qc_report_attachments enable row level security;

commit;
