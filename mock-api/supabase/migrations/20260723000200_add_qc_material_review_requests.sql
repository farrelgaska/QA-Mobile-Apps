begin;

create or replace function public.qc_text_array_is_unique(values_to_check text[])
returns boolean
language sql
immutable
strict
as $$
  select cardinality(values_to_check) =
    (select count(distinct value) from unnest(values_to_check) as entries(value));
$$;

create or replace function public.qc_integer_array_is_unique(values_to_check integer[])
returns boolean
language sql
immutable
strict
as $$
  select cardinality(values_to_check) =
    (select count(distinct value) from unnest(values_to_check) as entries(value));
$$;

create or replace function public.qc_sample_id_array_is_valid(values_to_check text[])
returns boolean
language sql
immutable
strict
as $$
  select not exists (
    select 1
    from unnest(values_to_check) as entries(sample_id)
    where sample_id !~ '^[A-Za-z0-9_-]{1,128}$'
  );
$$;

create or replace function public.qc_positive_integer_array_is_valid(values_to_check integer[])
returns boolean
language sql
immutable
strict
as $$
  select not exists (
    select 1
    from unnest(values_to_check) as entries(sample_number)
    where sample_number <= 0
  );
$$;

alter table public.qc_reports
  add column if not exists review_requested boolean not null default false,
  add column if not exists review_requested_at timestamptz,
  add column if not exists review_requested_by_role text,
  add column if not exists review_failed_sample_count integer,
  add column if not exists review_failed_sample_ids text[] not null default '{}',
  add column if not exists review_failed_sample_numbers integer[] not null default '{}';

alter table public.qc_reports
  drop constraint if exists qc_reports_review_request_snapshot_check;

alter table public.qc_reports
  add constraint qc_reports_review_request_snapshot_check check (
    (
      review_requested = false
      and review_requested_at is null
      and review_requested_by_role is null
      and review_failed_sample_count is null
      and cardinality(review_failed_sample_ids) = 0
      and cardinality(review_failed_sample_numbers) = 0
    )
    or
    (
      review_requested = true
      and type = 'MATERIAL'
      and review_requested_at is not null
      and review_requested_by_role = 'STAFF_WAREHOUSE'
      and review_failed_sample_count >= 2
      and cardinality(review_failed_sample_ids) = review_failed_sample_count
      and cardinality(review_failed_sample_numbers) = review_failed_sample_count
      and public.qc_text_array_is_unique(review_failed_sample_ids)
      and public.qc_integer_array_is_unique(review_failed_sample_numbers)
      and public.qc_sample_id_array_is_valid(review_failed_sample_ids)
      and public.qc_positive_integer_array_is_valid(review_failed_sample_numbers)
    )
  );

create index if not exists qc_reports_review_requested_at_idx
  on public.qc_reports (review_requested_at)
  where review_requested = true;

commit;
