set client_min_messages = notice;
begin;

create function pg_temp.h(seed text) returns text language sql immutable
  as $$ select encode(sha256(convert_to(seed, 'UTF8')), 'hex') $$;

set local role service_role;

do $$
declare
  c record;
  sealed uuid;
begin
  -- api_calls: una de hace 61 minutos (se va) y una de hace 59 (se queda).
  insert into public.api_calls (install_id_hash, at) values
    (pg_temp.h('a'), '2026-10-08 08:59Z'), (pg_temp.h('a'), '2026-10-08 09:01Z');

  -- Jugadores viejos: uno con partida sellada (se queda), uno sin nada (se va),
  -- uno con una activa reciente (se queda), uno sólo con una abandonada vieja (se va),
  -- uno nuevo sin nada (se queda).
  insert into public.players (install_id_hash, created_at) values
    (pg_temp.h('sellado'), '2026-01-01Z'), (pg_temp.h('vacio'), '2026-01-01Z'),
    (pg_temp.h('activo'), '2026-01-01Z'), (pg_temp.h('abandonado'), '2026-01-01Z'),
    (pg_temp.h('nuevo'), '2026-10-01Z');
  select run_id into sealed from public.start_run(pg_temp.h('sellado'), '2.0.0', '2026-01-02 00:00Z');
  perform public.finish_run(pg_temp.h('sellado'), sealed, 1, '2026-01-03 00:00Z');
  perform public.start_run(pg_temp.h('activo'), '2.0.0', '2026-09-20 00:00Z');
  perform public.start_run(pg_temp.h('abandonado'), '2.0.0', '2026-01-02 00:00Z');
  update public.runs set status = 'abandoned' where player_id = (select id from public.players where install_id_hash = pg_temp.h('abandonado'));

  select * into c from public.cleanup_ranking('2026-10-08 10:00Z');
  if c.api_calls_deleted <> 1 or (select count(*) from public.api_calls) <> 1 then
    raise exception 'api_calls: % borradas, quedan %', c.api_calls_deleted, (select count(*) from public.api_calls);
  end if;
  if c.players_deleted <> 2 then
    raise exception 'players borrados: %', c.players_deleted;
  end if;
  if (select array_agg(install_id_hash order by install_id_hash) from public.players)
     is distinct from (select array_agg(pg_temp.h(s) order by pg_temp.h(s)) from unnest(array['sellado', 'activo', 'nuevo']) s) then
    raise exception 'quedaron los jugadores equivocados';
  end if;
  raise notice 'OK la limpieza borra api_calls de más de una hora y jugadores muertos, no los que tienen partida';
end $$;

rollback;
