begin;

create table public.qc_material_families (
  family_id text primary key,
  name text not null,
  category text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint qc_material_families_id_not_blank check (btrim(family_id) <> ''),
  constraint qc_material_families_name_not_blank check (btrim(name) <> ''),
  constraint qc_material_families_category_not_blank check (btrim(category) <> '')
);

create unique index qc_material_families_id_case_insensitive_uidx
  on public.qc_material_families (lower(family_id));
create unique index qc_material_families_name_category_case_insensitive_uidx
  on public.qc_material_families (lower(name), lower(category));

create trigger qc_material_families_set_updated_at
before update on public.qc_material_families
for each row execute function public.set_updated_at();

alter table public.qc_material_families enable row level security;

alter table public.qc_materials
  add column family_id text,
  add constraint qc_materials_family_fk
    foreign key (family_id)
    references public.qc_material_families (family_id)
    on update cascade
    on delete restrict;

create index qc_materials_family_active_idx
  on public.qc_materials (lower(family_id))
  where is_active and family_id is not null;

commit;
