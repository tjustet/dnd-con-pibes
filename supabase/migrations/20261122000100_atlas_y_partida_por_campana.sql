alter table public.ciudades add column campaign_id uuid references public.campaigns(id) on delete cascade;
update public.ciudades c set campaign_id = (
 select (array_agg(distinct s.campaign_id))[1] from public.tiendas_sesion s where s.ciudad_id=c.id
 having count(distinct s.campaign_id)=1 and count(*)=count(s.campaign_id)
);
alter table public.ciudades alter column campaign_id set not null;
create index ciudades_campana_nombre_idx on public.ciudades(campaign_id,nombre);
alter table public.ciudades add constraint ciudades_id_campana_key unique(id,campaign_id);
alter table public.tiendas_sesion add constraint tienda_ciudad_campana_fk foreign key(ciudad_id,campaign_id)
 references public.ciudades(id,campaign_id) on delete cascade;
alter table public.tiendas_sesion add constraint tienda_ciudad_con_campana check(ciudad_id is null or campaign_id is not null);
create index tiendas_sesion_ciudad_campana_idx on public.tiendas_sesion(ciudad_id,campaign_id);

-- Conservar las plantillas anteriores y reutilizar los artículos del catálogo.
with candidatos as (
 select distinct on (lower(trim(v->>'nombre'))) trim(v->>'nombre') nombre,p.tipo,
 (v->>'precio_cobre')::integer precio,v->>'bono' bono
 from public.tiendas_plantilla p cross join lateral jsonb_array_elements(p.inventario_base) v
 where nullif(trim(v->>'nombre'),'') is not null and (v->>'precio_cobre') ~ '^[0-9]{1,9}$'
 order by lower(trim(v->>'nombre')),p.id
)
insert into public.items_base(nombre,tipo,precio_cobre,bono,nivel)
 select c.nombre,c.tipo,c.precio,c.bono,0 from candidatos c
 where not exists(select 1 from public.items_base i where lower(trim(i.nombre))=lower(c.nombre));

create function public.dnd_fundar_ciudad(p_campana uuid,p_id uuid,p_nombre text,p_tamano text,p_descripcion text,p_tipos text[])
returns uuid language plpgsql security invoker set search_path='' as $$
declare rubro text; stock jsonb; limite integer; plantilla public.tiendas_plantilla%rowtype;
begin
 if not exists(select 1 from public.campaigns where id=p_campana and dm_id=auth.uid())
 then raise exception 'Solo el director de esta campaña puede fundar un asentamiento'; end if;
 limite:=case p_tamano when 'aldea' then 2 when 'pueblo' then 3 when 'ciudad' then 5 when 'metropolis' then 7 end;
 if p_id is null or nullif(trim(p_nombre),'') is null or length(p_nombre)>120 or limite is null or p_tipos is null
 or cardinality(p_tipos)>50 or exists(select 1 from unnest(p_tipos) t group by t having t is null or trim(t)='' or length(t)>80 or count(*)>1)
 then raise exception 'Revisá el nombre, el tamaño y los locales'; end if;
 insert into public.ciudades(id,campaign_id,nombre,tamano,descripcion) values(p_id,p_campana,trim(p_nombre),p_tamano,p_descripcion)
 on conflict(id) do nothing;
 if not found then
   if exists(select 1 from public.ciudades where id=p_id and campaign_id=p_campana and nombre=trim(p_nombre) and tamano=p_tamano)
   then return p_id; end if;
   raise exception 'El identificador de la fundación ya está en uso';
 end if;
 foreach rubro in array p_tipos loop
   select * into plantilla from public.tiendas_plantilla p where lower(p.tipo)=lower(rubro) order by p.id limit 1;
   with recomendados as (
    select i.id,greatest(1,coalesce((v->>'cantidad')::integer,1)) cantidad,pos
    from jsonb_array_elements(plantilla.inventario_base) with ordinality t(v,pos)
    cross join lateral (select b.id from public.items_base b where lower(trim(b.nombre))=lower(trim(v->>'nombre'))
      order by (b.precio_cobre=(v->>'precio_cobre')::integer) desc nulls last,b.nivel,b.id limit 1) i
   ), surtido as (
    select distinct on(id) id,cantidad,pos from recomendados order by id,pos
   ), opciones as (
    select id,cantidad,0 prioridad,pos::double precision orden from surtido
    union all
    select i.id,2,1,random() from public.items_base i where coalesce(i.nivel,0)<=limite
    and not exists(select 1 from surtido s where s.id=i.id)
    and exists(select 1 from public.mapeo_tiendas m where lower(m.tipo_tienda)=lower(rubro) and m.categorias_permitidas ? i.tipo)
   )
   select coalesce(jsonb_agg(jsonb_build_object('tabla','items_base','item_id',id,'cantidad',cantidad) order by prioridad,orden),'[]')
     into stock from (select * from opciones order by prioridad,orden limit limite+1) oferta;
   insert into public.tiendas_sesion(ciudad_id,campaign_id,tipo,plantilla_id,nombre_personalizado,inventario_actual,empleados)
   values(p_id,p_campana,rubro,plantilla.id,rubro||' de '||trim(p_nombre),stock,'[]');
 end loop;
 return p_id;
end $$;
revoke all on function public.dnd_fundar_ciudad(uuid,uuid,text,text,text,text[]) from public,anon;
grant execute on function public.dnd_fundar_ciudad(uuid,uuid,text,text,text,text[]) to authenticated;

create schema dnd_privado;
revoke all on schema dnd_privado from public,anon,authenticated;
grant usage on schema dnd_privado to authenticated;
create function dnd_privado.director(camp uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.campaigns where id=camp and dm_id=(select auth.uid()))
$$;
create function dnd_privado.es_dm() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles where id=(select auth.uid()) and is_dm)
$$;
create function dnd_privado.miembro(camp uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.characters where campaign_id=camp and coalesce(tipo,'pj')='pj' and lower(player_email)=lower(nullif((select auth.jwt())->>'email','')))
$$;
create function dnd_privado.controla(camp uuid,pj uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.characters j where j.id=pj and j.campaign_id=camp and coalesce(tipo,'pj')='pj'
 and (lower(j.player_email)=lower(nullif((select auth.jwt())->>'email','')) or dnd_privado.director(camp)))
$$;
revoke all on all functions in schema dnd_privado from public,anon;
grant execute on all functions in schema dnd_privado to authenticated;
alter table public.characters add column creador_id uuid references public.profiles(id) on delete set null;
update public.characters j set creador_id=c.dm_id from public.campaigns c where j.campaign_id=c.id;
update public.characters set creador_id=(select (array_agg(id))[1] from public.profiles where is_dm having count(*)=1)
 where campaign_id is null and creador_id is null;
do $$ begin
 if exists(select 1 from public.characters where campaign_id is null and creador_id is null and nullif(player_email,'') is null)
 then raise exception 'Hay fichas independientes sin autor identificable'; end if;
end $$;
alter table public.characters alter column creador_id set default auth.uid();
create index personajes_creador_idx on public.characters(creador_id);
create index personajes_campana_correo_idx on public.characters(campaign_id,lower(player_email));
alter function public.handle_new_user() set search_path='';
do $$ declare t text; begin
 foreach t in array array['profiles','campaigns','characters','ciudades','tiendas_sesion','campana_notas','ataques_comunidad','efectos','items_base','items_jugadores','lugares','objetos','mapeo_tiendas','tiendas_plantilla'] loop
  execute format('drop policy %I on public.%I','Policy with security definer functions',t);
  execute format('revoke all on public.%I from public, anon, authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
 end loop;
 foreach t in array array['ciudades','tiendas_sesion','campana_notas','items_jugadores'] loop
  execute format('create policy director_campana on public.%I for all to authenticated using (dnd_privado.director(campaign_id)) with check (dnd_privado.director(campaign_id))',t);
  execute format('grant insert,update,delete on public.%I to authenticated',t);
 end loop;
 foreach t in array array['ataques_comunidad','efectos','items_base','mapeo_tiendas','tiendas_plantilla'] loop
  execute format('create policy catalogo on public.%I for select to authenticated using (true)',t);
 end loop;
end $$;
create policy leer_perfiles on public.profiles for select to authenticated using (id=(select auth.uid()) or (select dnd_privado.es_dm()));
create policy leer_campana on public.campaigns for select to authenticated using (dm_id=(select auth.uid()));
create policy crear_campana on public.campaigns for insert to authenticated with check (dm_id=(select auth.uid()) and (select dnd_privado.es_dm()));
create policy editar_campana on public.campaigns for update to authenticated using (dm_id=(select auth.uid())) with check (dm_id=(select auth.uid()));
create policy borrar_campana on public.campaigns for delete to authenticated using (dm_id=(select auth.uid()));
grant insert,update,delete on public.campaigns to authenticated;
create policy leer_fichas on public.characters for select to authenticated using (
 dnd_privado.director(campaign_id) or (campaign_id is null and creador_id=(select auth.uid())) or es_publico or
 (coalesce(tipo,'pj')='pj' and lower(player_email)=lower(nullif((select auth.jwt())->>'email','')))
);
create policy gestionar_fichas on public.characters for all to authenticated using (
 dnd_privado.director(campaign_id) or (campaign_id is null and creador_id=(select auth.uid()))
) with check (dnd_privado.director(campaign_id) or (campaign_id is null and creador_id=(select auth.uid())));
create policy editar_ficha_propia on public.characters for update to authenticated using (
 coalesce(tipo,'pj')='pj' and lower(player_email)=lower(nullif((select auth.jwt())->>'email',''))
) with check (coalesce(tipo,'pj')='pj' and lower(player_email)=lower(nullif((select auth.jwt())->>'email','')));
create function dnd_privado.proteger_asignacion() returns trigger language plpgsql set search_path='' as $$
begin
 if current_user='authenticated' and not dnd_privado.director(old.campaign_id) and
  (new.id is distinct from old.id or new.creador_id is distinct from old.creador_id or new.campaign_id is distinct from old.campaign_id
   or (old.campaign_id is not null and (new.player_email is distinct from old.player_email or new.tipo is distinct from old.tipo)))
 then raise exception 'Solo el director puede cambiar la asignación de una ficha de campaña'; end if;
 return new;
end $$;
create trigger proteger_asignacion before update on public.characters for each row execute function dnd_privado.proteger_asignacion();
grant insert,update,delete on public.characters to authenticated;
create policy publicar_ataque on public.ataques_comunidad for insert to authenticated with check (true);
grant insert on public.ataques_comunidad to authenticated;
create policy leer_lugares on public.lugares for select to authenticated using (es_comunidad or autor_id=(select auth.uid()) or dnd_privado.director(campaign_id));
create policy leer_objetos on public.objetos for select to authenticated using (es_comunidad or autor_id=(select auth.uid()));
alter table public.campaigns add column historial_dm jsonb not null default '[]';
update public.campaigns set historial_dm=coalesce(historial_dados,'[]'),historial_dados=(
 select coalesce(jsonb_agg(r order by pos),'[]') from jsonb_array_elements(historial_dados) with ordinality f(r,pos)
 where not coalesce((r->>'oculto')::boolean,false)
);
create table public.campana_publicada (
 id uuid primary key references public.campaigns(id) on delete cascade,dm_id uuid,nombre_campanya text,
 entidad_visible jsonb,historial_dados jsonb,revision uuid not null default gen_random_uuid()
);
alter table public.campana_publicada enable row level security;
revoke all on public.campana_publicada from public,anon,authenticated;
grant select on public.campana_publicada to authenticated;
create policy partida_visible on public.campana_publicada for select to authenticated using (dm_id=(select auth.uid()) or dnd_privado.miembro(id));
insert into public.campana_publicada(id,dm_id,nombre_campanya,entidad_visible,historial_dados)
 select id,dm_id,nombre_campanya,mesa_estado->'entidadVisible',historial_dados from public.campaigns;
create function dnd_privado.publicar_campana() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and (new.dm_id,new.nombre_campanya,new.historial_dados,new.mesa_estado->'entidadVisible',new.mesa_estado->'tiendaVisible',new.mesa_estado->'carritos')
 is not distinct from (old.dm_id,old.nombre_campanya,old.historial_dados,old.mesa_estado->'entidadVisible',old.mesa_estado->'tiendaVisible',old.mesa_estado->'carritos')
 then return new; end if;
 insert into public.campana_publicada(id,dm_id,nombre_campanya,entidad_visible,historial_dados)
 values(new.id,new.dm_id,new.nombre_campanya,new.mesa_estado->'entidadVisible',new.historial_dados)
 on conflict(id) do update set dm_id=excluded.dm_id,nombre_campanya=excluded.nombre_campanya,
 entidad_visible=excluded.entidad_visible,historial_dados=excluded.historial_dados,revision=gen_random_uuid();
 return new;
end $$;
create trigger publicar_campana after insert or update on public.campaigns for each row execute function dnd_privado.publicar_campana();
alter publication supabase_realtime add table public.campana_publicada;
create function public.dnd_aliados(p_campana uuid,p_personaje uuid) returns table(id uuid,nombre_pj text)
language sql stable security definer set search_path='' as $$
 select j.id,j.nombre_pj from public.characters j where j.campaign_id=p_campana and j.id<>p_personaje and coalesce(j.tipo,'pj')='pj'
 and dnd_privado.controla(p_campana,p_personaje) order by j.nombre_pj
$$;
create function public.dnd_mercado_jugador(p_campana uuid,p_personaje uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare mesa jsonb; tienda jsonb; carritos jsonb;
begin
 if not dnd_privado.controla(p_campana,p_personaje) then raise exception 'Esta ficha no tiene acceso al mercado'; end if;
 select mesa_estado into mesa from public.campaigns where id=p_campana;
 tienda:=mesa->'tiendaVisible';
 if tienda->>'targets' is not null and tienda->>'targets'<>'all' and not ((tienda->'targets') ? p_personaje::text)
 then tienda:=jsonb_build_object('id',tienda->'id','sesion',tienda->'sesion','targets','[]'::jsonb); end if;
 select coalesce(jsonb_object_agg(k,v),'{}') into carritos from jsonb_each(coalesce(mesa->'carritos','{}')) s(k,v)
 where k=p_personaje::text or v->>'ayudante'=p_personaje::text;
 return jsonb_build_object('tiendaVisible',tienda,'carritos',carritos);
end $$;
create function dnd_privado.anteponer(historial jsonb,tirada jsonb) returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_array(tirada) || coalesce((select jsonb_agg(r order by pos) from
 (select r,pos from jsonb_array_elements(coalesce(historial,'[]')) with ordinality f(r,pos)
 where r->>'id' is distinct from tirada->>'id' order by pos limit 29) anteriores),'[]')
$$;
create function public.dnd_registrar_tirada(p_campana uuid,p_tirada jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.campaigns%rowtype; director boolean; publica jsonb; completa jsonb;
begin
 select * into strict c from public.campaigns where id=p_campana for update;
 director:=c.dm_id=(select auth.uid());
 if jsonb_typeof(p_tirada) is distinct from 'object' or nullif(p_tirada->>'id','') is null or length(p_tirada::text)>20000 then raise exception 'Tirada inválida'; end if;
 if director is not true and (coalesce((p_tirada->>'oculto')::boolean,false) or not exists(
 select 1 from public.characters where campaign_id=p_campana and coalesce(tipo,'pj')='pj' and nombre_pj=p_tirada->>'tirador'
 and lower(player_email)=lower(nullif((select auth.jwt())->>'email','')))) then raise exception 'No tenés permiso para registrar esta tirada'; end if;
 if exists(select 1 from jsonb_array_elements(c.historial_dm || coalesce(c.historial_dados,'[]')) r where r->>'id'=p_tirada->>'id')
 then return case when director then c.historial_dm else c.historial_dados end; end if;
 completa:=dnd_privado.anteponer(c.historial_dm,p_tirada);
 publica:=case when coalesce((p_tirada->>'oculto')::boolean,false) then c.historial_dados else dnd_privado.anteponer(c.historial_dados,p_tirada) end;
 update public.campaigns set historial_dm=completa,historial_dados=publica where id=p_campana;
 return case when director then completa else publica end;
end $$;

create function public.dnd_pedido(p_campana uuid,p_personaje uuid,p_previo jsonb,p_nuevo jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare mesa jsonb; tienda jsonb; previo jsonb; linea jsonb; articulo jsonb; total bigint:=0; unidades integer; aliado uuid;
begin
 if not dnd_privado.controla(p_campana,p_personaje) then raise exception 'El personaje no te pertenece'; end if;
 select mesa_estado into strict mesa from public.campaigns where id=p_campana for update;
 tienda:=mesa->'tiendaVisible'; previo:=mesa#>array['carritos',p_personaje::text];
 if jsonb_typeof(p_nuevo) is distinct from 'object' or jsonb_typeof(p_nuevo->'items') is distinct from 'array'
 or nullif(p_nuevo->>'id','')::uuid is null or jsonb_array_length(p_nuevo->'items')>100
 or coalesce(p_nuevo->>'estado','') not in ('comprando','pagando') or (p_nuevo-array['id','estado','ayudante','tienda','sesion','items','total'])<>'{}'
 then raise exception 'Pedido inválido'; end if;
 if previo=p_nuevo then return; end if;
 if tienda->>'id' is null or tienda->>'sesion' is null or tienda->>'id' is distinct from p_nuevo->>'tienda'
 or tienda->>'sesion' is distinct from p_nuevo->>'sesion' or (tienda->>'targets' is not null and tienda->>'targets'<>'all' and not ((tienda->'targets') ? p_personaje::text))
 or previo->>'id' is distinct from p_previo->>'id' or previo->>'estado' is distinct from p_previo->>'estado'
 or (previo->>'estado'='pagando' and previo->>'sesion'=tienda->>'sesion') then raise exception 'El catálogo o el pedido cambió. Actualizá la tienda'; end if;
 if exists(select 1 from jsonb_array_elements(p_nuevo->'items') l group by l->>'item_id',l->>'tabla' having count(*)>1) then raise exception 'Hay artículos repetidos'; end if;
 for linea in select jsonb_array_elements(p_nuevo->'items') loop
   select a into strict articulo from jsonb_array_elements(tienda->'inventario') a where a->>'id'=linea->>'item_id' and a->>'tabla_origen'=linea->>'tabla';
   unidades:=(linea->>'unidades')::integer;
   if unidades is null or unidades<1 or unidades>coalesce((articulo->>'stock_local')::integer,0)
   or (linea->>'precio')::bigint is distinct from coalesce((articulo->>'precio_cobre')::bigint,0) then raise exception 'Cambió el precio o el stock'; end if;
   total:=total+unidades*(linea->>'precio')::bigint;
 end loop;
 aliado:=(p_nuevo->>'ayudante')::uuid;
 if (p_nuevo->>'total')::bigint is distinct from total or (p_nuevo->>'estado'='pagando' and jsonb_array_length(p_nuevo->'items')=0)
 or (aliado is not null and (aliado=p_personaje or total<=0 or p_nuevo->>'estado'<>'comprando' or not exists(
 select 1 from public.characters where id=aliado and campaign_id=p_campana and coalesce(tipo,'pj')='pj')))
 then raise exception 'Revisá el total y el aliado'; end if;
 update public.campaigns set mesa_estado=jsonb_set(mesa,'{carritos}',coalesce(mesa->'carritos','{}') || jsonb_build_object(p_personaje::text,p_nuevo)) where id=p_campana;
end $$;
create function public.dnd_responder_ayuda(p_campana uuid,p_personaje uuid,p_comprador uuid,p_pedido uuid,p_aceptar boolean)
returns void language plpgsql security definer set search_path='' as $$
declare mesa jsonb; cart jsonb;
begin
 if not dnd_privado.controla(p_campana,p_personaje) or p_personaje=p_comprador then raise exception 'Aliado inválido'; end if;
 select mesa_estado into strict mesa from public.campaigns where id=p_campana for update;
 cart:=mesa#>array['carritos',p_comprador::text];
 if cart->>'id' is distinct from p_pedido::text or cart->>'estado' is distinct from 'comprando'
 or cart->>'ayudante' is distinct from p_personaje::text or cart->>'tienda' is distinct from mesa#>>'{tiendaVisible,id}'
 or cart->>'sesion' is distinct from mesa#>>'{tiendaVisible,sesion}' then raise exception 'La solicitud cambió'; end if;
 cart:=cart-'ayudante';
 if p_aceptar then
  insert into public.dnd_aportes(campana,pedido,personaje,beneficiario,maximo)
  values(p_campana,p_pedido,p_personaje,p_comprador,(cart->>'total')::bigint) on conflict(campana,pedido,personaje) do nothing;
  if not exists(select 1 from public.dnd_aportes where campana=p_campana and pedido=p_pedido and personaje=p_personaje
   and beneficiario=p_comprador and maximo=(cart->>'total')::bigint) then raise exception 'La autorización anterior no coincide'; end if;
  cart:=cart || jsonb_build_object('patrocinador',p_personaje,'estado','pagando');
 else cart:=cart || jsonb_build_object('ayudaRechazadaPor',p_personaje); end if;
 update public.campaigns set mesa_estado=jsonb_set(mesa,array['carritos',p_comprador::text],cart) where id=p_campana;
end $$;
revoke insert on public.dnd_aportes from authenticated;
revoke all on function public.dnd_aliados(uuid,uuid),public.dnd_mercado_jugador(uuid,uuid),public.dnd_registrar_tirada(uuid,jsonb),
 public.dnd_pedido(uuid,uuid,jsonb,jsonb),public.dnd_responder_ayuda(uuid,uuid,uuid,uuid,boolean) from public,anon;
grant execute on function public.dnd_aliados(uuid,uuid),public.dnd_mercado_jugador(uuid,uuid),public.dnd_registrar_tirada(uuid,jsonb),
 public.dnd_pedido(uuid,uuid,jsonb,jsonb),public.dnd_responder_ayuda(uuid,uuid,uuid,uuid,boolean) to authenticated;

-- También separar las tiradas secretas enviadas desde pestañas antiguas.
create function dnd_privado.compatibilidad_dados() returns trigger language plpgsql set search_path='' as $$
declare r jsonb; originales jsonb:=coalesce(old.historial_dados,'[]');
begin
 if new.historial_dm is distinct from old.historial_dm or new.historial_dados is not distinct from old.historial_dados then return new; end if;
 if new.historial_dados='[]' then new.historial_dm:='[]'; return new; end if;
 for r in select fila from jsonb_array_elements(new.historial_dados) with ordinality f(fila,pos)
 where not exists(select 1 from jsonb_array_elements(originales) previo where previo->>'id'=fila->>'id') order by pos desc loop
   new.historial_dm:=dnd_privado.anteponer(new.historial_dm,r);
 end loop;
 select coalesce(jsonb_agg(fila order by pos),'[]') into new.historial_dados from jsonb_array_elements(new.historial_dados)
 with ordinality f(fila,pos) where not coalesce((fila->>'oculto')::boolean,false);
 return new;
end $$;
create trigger separar_historial_anterior before update of historial_dados on public.campaigns for each row execute function dnd_privado.compatibilidad_dados();
