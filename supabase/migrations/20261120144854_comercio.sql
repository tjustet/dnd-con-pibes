create table if not exists public.dnd_aportes (
  campana uuid not null references public.campaigns(id) on delete cascade,
  pedido uuid not null,
  personaje uuid not null references public.characters(id) on delete cascade,
  beneficiario uuid not null references public.characters(id) on delete cascade,
  maximo bigint not null check (maximo >= 0),
  primary key (campana, pedido, personaje)
);
alter table public.dnd_aportes enable row level security;
revoke all on public.dnd_aportes from public, anon, authenticated;
grant select, insert on public.dnd_aportes to authenticated;
drop policy if exists aporte_propio on public.dnd_aportes;
create policy aporte_propio on public.dnd_aportes for insert to authenticated with check (
  exists (select 1 from public.characters j where j.id = personaje and j.campaign_id = campana
          and lower(j.player_email) = lower(auth.jwt()->>'email'))
);
drop policy if exists consultar_aporte on public.dnd_aportes;
create policy consultar_aporte on public.dnd_aportes for select to authenticated using (
  exists (select 1 from public.characters j where j.id = personaje and lower(j.player_email) = lower(auth.jwt()->>'email'))
  or exists (select 1 from public.campaigns c join public.profiles p on p.id = c.dm_id
             where c.id = campana and (p.id = auth.uid() or lower(p.email) = lower(auth.jwt()->>'email')))
);

create table if not exists public.dnd_ventas (
  campana uuid not null references public.campaigns(id) on delete cascade,
  operacion uuid not null,
  primary key (campana, operacion)
);
alter table public.dnd_ventas enable row level security;
revoke all on public.dnd_ventas from public, anon, authenticated;
grant select, insert on public.dnd_ventas to authenticated;
drop policy if exists venta_dm on public.dnd_ventas;
create policy venta_dm on public.dnd_ventas for all to authenticated using (
  exists (select 1 from public.campaigns c join public.profiles p on p.id = c.dm_id
          where c.id = campana and (p.id = auth.uid() or lower(p.email) = lower(auth.jwt()->>'email')))
);

-- Las ventas y la aprobación de pedidos se resuelven dentro de una sola transacción.
-- El llamador conserva sus permisos y las políticas RLS de las tablas.
create or replace function public.dnd_vender(
  p_campana uuid, p_tienda text, p_lineas jsonb, p_operacion uuid, p_pedido text default null
) returns void language plpgsql security invoker set search_path = '' as $$
declare
  camp public.campaigns%rowtype;
  local_comercio public.tiendas_sesion%rowtype;
  comprador public.characters%rowtype;
  pagador public.characters%rowtype;
  linea jsonb;
  objeto jsonb;
  existencia jsonb;
  stock jsonb;
  pedido jsonb;
  monedero jsonb;
  saldo bigint;
  coste bigint;
  cantidad integer;
  precio bigint;
  indice integer;
begin
  select * into strict camp from public.campaigns where id = p_campana for update;
  if auth.uid() is null or not exists (
    select 1 from public.profiles p where p.id = camp.dm_id
    and (p.id = auth.uid() or lower(p.email) = lower(auth.jwt()->>'email'))
  ) then raise exception 'Solo el DM de la campaña puede aprobar un trato'; end if;

  select * into strict local_comercio from public.tiendas_sesion
    where id::text = p_tienda and campaign_id = p_campana for update;
  if p_operacion is null then raise exception 'Falta identificar la operación'; end if;
  insert into public.dnd_ventas(campana, operacion) values (p_campana,p_operacion) on conflict do nothing;
  if not found then return; end if;
  if p_pedido is not null then
    pedido := camp.mesa_estado::jsonb #> array['carritos',p_pedido];
    if pedido->>'estado' = 'aprobado' and pedido->>'id' = p_operacion::text then return; end if;
    if pedido->>'estado' is distinct from 'pagando' or pedido->>'tienda' is distinct from p_tienda
      or pedido->>'id' is distinct from p_operacion::text then raise exception 'El pedido ya cambió'; end if;
    p_lineas := pedido->'items';
    if pedido->>'patrocinador' is not null and not exists (
      select 1 from public.dnd_aportes a where a.campana = p_campana and a.pedido = p_operacion
        and a.personaje::text = pedido->>'patrocinador' and a.beneficiario::text = p_pedido
        and a.maximo >= (select sum((i->>'unidades')::integer * (i->>'precio')::bigint) from jsonb_array_elements(p_lineas) i)
    ) then raise exception 'Falta la autorización del compañero'; end if;
  end if;
  if jsonb_typeof(p_lineas) is distinct from 'array' or jsonb_array_length(p_lineas) = 0
    then raise exception 'El pedido está vacío'; end if;
  stock := coalesce(local_comercio.inventario_actual::jsonb,'[]');
  for linea in select value from jsonb_array_elements(p_lineas) loop
    cantidad := (linea->>'unidades')::integer;
    precio := (linea->>'precio')::bigint;
    if cantidad is null or cantidad < 1 or precio is null or precio < 0 then raise exception 'Revisá cantidades y precios'; end if;
    select (pos - 1)::int, item into strict indice, existencia
      from jsonb_array_elements(stock) with ordinality as refs(item,pos)
      where item->>'item_id' = linea->>'item_id' and item->>'tabla' = linea->>'tabla';
    if coalesce((existencia->>'cantidad')::integer,0) < cantidad then raise exception 'Stock insuficiente'; end if;
    if linea->>'tabla' = 'items_base' then
      select to_jsonb(i) into strict objeto from public.items_base i where i.id::text = linea->>'item_id';
    elsif linea->>'tabla' = 'items_jugadores' then
      select to_jsonb(i) into strict objeto from public.items_jugadores i
        where i.id::text = linea->>'item_id' and i.campaign_id = p_campana;
    else raise exception 'Catálogo desconocido'; end if;
    if p_pedido is not null and precio is distinct from (objeto->>'precio_cobre')::bigint
      then raise exception 'El precio cambió. Volvé a armar el pedido'; end if;
    select * into strict comprador from public.characters where campaign_id = p_campana
      and id::text = coalesce(p_pedido, linea->>'comprador') for update;
    select * into strict pagador from public.characters where campaign_id = p_campana
      and id::text = coalesce(pedido->>'patrocinador', comprador.id::text) for update;
    monedero := to_jsonb(pagador)->'monedas';
    saldo := coalesce(pagador.monedas_platino,0)::bigint * 10000 + coalesce(pagador.monedas_oro,0)::bigint * 1000
           + coalesce(pagador.monedas_plata,0)::bigint * 100 + coalesce(pagador.monedas_cobre,0);
    if saldo = 0 then
      saldo := coalesce((monedero->>'ppt')::bigint,0)*10000 + coalesce((monedero->>'po')::bigint,0)*1000
             + coalesce((monedero->>'plata')::bigint,0)*100 + coalesce((monedero->>'pc')::bigint,0);
    end if;
    coste := cantidad * precio;
    if saldo < coste then raise exception 'Fondos insuficientes para %', pagador.nombre_pj; end if;
    saldo := saldo - coste;
    update public.characters set monedas_platino = saldo / 10000, monedas_oro = saldo % 10000 / 1000,
      monedas_plata = saldo % 1000 / 100, monedas_cobre = saldo % 100 where id = pagador.id;
    if not found then raise exception 'No se pudo registrar el pago'; end if;
    if to_jsonb(pagador) ? 'monedas' then
      execute 'update public.characters set monedas = $1 where id = $2'
        using jsonb_build_object('ppt',saldo/10000,'po',saldo%10000/1000,'plata',saldo%1000/100,'pc',saldo%100),pagador.id;
    end if;
    update public.characters set inventario = coalesce(inventario::jsonb,'[]') || jsonb_build_array(jsonb_build_object(
      'nombre', objeto->>'nombre', 'cant', cantidad, 'peso', objeto->>'peso', 'nota', coalesce(objeto->>'bono',''), 'equipado', false
    )) where id = comprador.id;
    if not found then raise exception 'No se pudo entregar el objeto'; end if;
    stock := jsonb_set(stock,array[indice::text,'cantidad'],to_jsonb((existencia->>'cantidad')::integer - cantidad));
  end loop;
  update public.tiendas_sesion set inventario_actual = stock where id = local_comercio.id;
  if not found then raise exception 'No se pudo actualizar el stock'; end if;
  if p_pedido is not null then
    update public.campaigns set mesa_estado = jsonb_set(camp.mesa_estado::jsonb,array['carritos',p_pedido,'estado'],'"aprobado"') where id = p_campana;
    if not found then raise exception 'No se pudo cerrar el pedido'; end if;
  end if;
end;
$$;
revoke all on function public.dnd_vender(uuid,text,jsonb,uuid,text) from public, anon;
grant execute on function public.dnd_vender(uuid,text,jsonb,uuid,text) to authenticated;
