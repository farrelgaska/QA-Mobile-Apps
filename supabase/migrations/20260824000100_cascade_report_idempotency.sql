-- Remove legacy orphan claims, then keep report/idempotency lifecycle atomic.
delete from public.api_idempotency_keys as key
where key.scope = 'create_report'
  and not exists (
    select 1 from public.qc_reports as report where report.id = key.resource_id
  );

alter table public.api_idempotency_keys
  add constraint api_idempotency_keys_resource_id_fkey
  foreign key (resource_id) references public.qc_reports(id)
  on delete cascade
  deferrable initially deferred;
