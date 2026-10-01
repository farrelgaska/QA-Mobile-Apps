begin;

create table public.qc_materials (
  material_id text primary key,
  material_description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint qc_materials_id_not_blank check (btrim(material_id) <> ''),
  constraint qc_materials_description_not_blank check (
    material_description is null or btrim(material_description) <> ''
  )
);

create unique index qc_materials_id_case_insensitive_uidx
  on public.qc_materials (lower(material_id));

create table public.qc_vendor_materials (
  vendor text not null,
  material_id text not null,
  sap_material_id text,
  material_name text not null,
  category text not null default '',
  manufacturer text not null default '',
  brand text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (vendor, material_id, brand),
  constraint qc_vendor_materials_material_fk
    foreign key (material_id)
    references public.qc_materials (material_id)
    on update cascade
    on delete restrict,
  constraint qc_vendor_materials_vendor_not_blank check (btrim(vendor) <> ''),
  constraint qc_vendor_materials_material_name_not_blank check (btrim(material_name) <> ''),
  constraint qc_vendor_materials_sap_id_not_blank check (
    sap_material_id is null or btrim(sap_material_id) <> ''
  ),
  constraint qc_vendor_materials_brand_not_blank check (btrim(brand) <> '')
);

create unique index qc_vendor_materials_identity_case_insensitive_uidx
  on public.qc_vendor_materials (lower(vendor), lower(material_id), lower(brand));
create index qc_vendor_materials_vendor_material_active_idx
  on public.qc_vendor_materials (lower(vendor), lower(material_id))
  where is_active;
create index qc_vendor_materials_material_vendor_active_idx
  on public.qc_vendor_materials (lower(material_id), lower(vendor))
  where is_active;

create table public.qc_warehouse_plants (
  plant text primary key,
  name text not null,
  area text not null default '',
  branch text not null default '',
  region text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint qc_warehouse_plants_plant_not_blank check (btrim(plant) <> ''),
  constraint qc_warehouse_plants_name_not_blank check (btrim(name) <> '')
);

create unique index qc_warehouse_plants_plant_case_insensitive_uidx
  on public.qc_warehouse_plants (lower(plant));

create trigger qc_materials_set_updated_at
before update on public.qc_materials
for each row execute function public.set_updated_at();
create trigger qc_vendor_materials_set_updated_at
before update on public.qc_vendor_materials
for each row execute function public.set_updated_at();
create trigger qc_warehouse_plants_set_updated_at
before update on public.qc_warehouse_plants
for each row execute function public.set_updated_at();

alter table public.qc_materials enable row level security;
alter table public.qc_vendor_materials enable row level security;
alter table public.qc_warehouse_plants enable row level security;

commit;
