-- Migration: Add template_snapshot to qc_reports
begin;

alter table public.qc_reports
add column template_snapshot jsonb;

create index qc_reports_template_snapshot_idx
on public.qc_reports using gin (template_snapshot);

commit;
