-- Recupera las cuatro estructuras vacías con sus claves originales y acceso administrativo.
create table public.attacks (
  id uuid default gen_random_uuid() not null,
  character_id uuid not null,
  nombre_ataque text not null,
  dado_danio text not null,
  bonificador_ataque integer default 0,
  bonificador_danio integer default 0
);
create table public.dice_rolls (
  id uuid default gen_random_uuid() not null,
  campaign_id uuid not null,
  character_name text not null,
  roll_type text not null,
  result integer not null,
  details text,
  created_at timestamp with time zone default now()
);
create table public.tiendas (
  id uuid default gen_random_uuid() not null,
  ciudad_id uuid,
  nombre text not null,
  tipo text not null,
  npc_id uuid,
  inventario jsonb default '[]'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
create table public.tiendas_jugadores (
  id uuid default gen_random_uuid() not null,
  campaign_id uuid,
  creado_por_pj_id uuid,
  nombre text not null,
  tipo text not null,
  imagen_url text,
  inventario jsonb default '[]'::jsonb,
  notas_jugador text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.attacks add constraint attacks_pkey PRIMARY KEY (id);
alter table public.dice_rolls add constraint dice_rolls_pkey PRIMARY KEY (id);
alter table public.tiendas add constraint tiendas_pkey PRIMARY KEY (id);
alter table public.tiendas_jugadores add constraint tiendas_jugadores_pkey PRIMARY KEY (id);
alter table public.attacks add constraint attacks_character_id_fkey FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE;
alter table public.dice_rolls add constraint dice_rolls_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE;
alter table public.tiendas add constraint tiendas_ciudad_id_fkey FOREIGN KEY (ciudad_id) REFERENCES ciudades(id) ON DELETE CASCADE;
alter table public.tiendas add constraint tiendas_npc_id_fkey FOREIGN KEY (npc_id) REFERENCES characters(id) ON DELETE SET NULL;
alter table public.tiendas_jugadores add constraint tiendas_jugadores_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE;
alter table public.tiendas_jugadores add constraint tiendas_jugadores_creado_por_pj_id_fkey FOREIGN KEY (creado_por_pj_id) REFERENCES characters(id) ON DELETE CASCADE;
alter table public.attacks enable row level security;
revoke all on public.attacks from public,anon,authenticated;
alter table public.dice_rolls enable row level security;
revoke all on public.dice_rolls from public,anon,authenticated;
alter table public.tiendas enable row level security;
revoke all on public.tiendas from public,anon,authenticated;
alter table public.tiendas_jugadores enable row level security;
revoke all on public.tiendas_jugadores from public,anon,authenticated;
