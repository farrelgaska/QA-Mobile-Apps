begin;

alter table public.qc_report_items
  add column if not exists staff_evaluation text not null default 'NOT_EVALUATED';

alter table public.qc_report_items
  drop constraint if exists qc_report_items_staff_evaluation_check;

alter table public.qc_report_items
  add constraint qc_report_items_staff_evaluation_check
  check (staff_evaluation in (
    'NOT_EVALUATED',
    'WITHIN_STANDARD',
    'OUT_OF_STANDARD'
  ));

commit;
