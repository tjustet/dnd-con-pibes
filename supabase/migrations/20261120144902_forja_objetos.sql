alter table public.items_jugadores add column nivel_objeto smallint not null default 0
  check (nivel_objeto between 0 and 10);

create function public.dnd_forjar_objeto(p_tienda uuid, p_nombre text, p_cantidad integer,
  p_precio integer, p_bono text, p_nivel smallint)
returns public.items_jugadores language plpgsql security invoker set search_path = '' as $$
declare
  local public.tiendas_sesion%rowtype;
  objeto public.items_jugadores%rowtype;
begin
  select * into strict local from public.tiendas_sesion where id = p_tienda for update;
  if auth.uid() is null or not exists (
    select 1 from public.campaigns c join public.profiles p on p.id = c.dm_id
    where c.id = local.campaign_id and (p.id = auth.uid() or lower(p.email) = lower(auth.jwt()->>'email'))
  ) then raise exception 'Solo el DM puede forjar en esta tienda'; end if;
  if nullif(trim(p_nombre),'') is null or coalesce(p_cantidad,0) < 1
    or coalesce(p_precio,-1) < 0 then raise exception 'Revisá nombre, cantidad y precio'; end if;
  insert into public.items_jugadores(campaign_id,nombre,tipo,precio_cobre,bono,nivel_objeto)
  values (local.campaign_id,trim(p_nombre),coalesce(nullif(local.tipo,''),'Objeto'),p_precio,p_bono,p_nivel)
  returning * into objeto;
  update public.tiendas_sesion set inventario_actual = coalesce(inventario_actual,'[]'::jsonb)
    || jsonb_build_array(jsonb_build_object('item_id',objeto.id,'cantidad',p_cantidad,'tabla','items_jugadores'))
    where id = p_tienda;
  if not found then raise exception 'No se pudo actualizar el stock'; end if;
  return objeto;
end;
$$;
revoke all on function public.dnd_forjar_objeto(uuid,text,integer,integer,text,smallint) from public, anon;
grant execute on function public.dnd_forjar_objeto(uuid,text,integer,integer,text,smallint) to authenticated;
