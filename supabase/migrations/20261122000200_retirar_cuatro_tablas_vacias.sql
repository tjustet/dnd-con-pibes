-- Cancelar si alguna tabla recibió filas o adquirió dependencias.
lock table public.attacks,public.dice_rolls,public.tiendas,public.tiendas_jugadores in access exclusive mode;
do $$ begin
 if exists(select from public.attacks) or exists(select from public.dice_rolls) or exists(select from public.tiendas) or exists(select from public.tiendas_jugadores)
 then raise exception 'Las tablas anteriores contienen registros. Cancelada la limpieza'; end if;
end $$;
drop table public.attacks,public.dice_rolls,public.tiendas,public.tiendas_jugadores restrict;
