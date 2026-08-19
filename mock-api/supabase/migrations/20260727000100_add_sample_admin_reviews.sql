begin;

alter table public.qc_report_sample_answers
  add column if not exists admin_evaluation text not null default 'NEEDS_REVIEW',
  add column if not exists admin_note text not null default '';

alter table public.qc_report_sample_answers
  drop constraint if exists qc_report_sample_answers_admin_evaluation_check;

alter table public.qc_report_sample_answers
  add constraint qc_report_sample_answers_admin_evaluation_check check (
    admin_evaluation in ('PASS', 'FAIL', 'NEEDS_REVIEW')
  );

create index if not exists qc_report_sample_answers_admin_evaluation_idx
  on public.qc_report_sample_answers (
    report_id,
    sample_id,
    admin_evaluation
  );

commit;
