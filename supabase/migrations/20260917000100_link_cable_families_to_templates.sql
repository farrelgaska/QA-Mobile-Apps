begin;

alter table public.qc_material_families
  add column template_id text,
  add constraint qc_material_families_template_fk
    foreign key (template_id) references public.qc_templates (id)
    on update cascade on delete restrict;

create index qc_material_families_template_idx
  on public.qc_material_families (template_id)
  where template_id is not null;

commit;
