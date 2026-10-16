set client_min_messages = notice;
begin;

-- Los eventos de la 2.1 (C6, …20261016000002): segment, exposure, progress y ctx en offer. Como anon, con el
-- interruptor prendido: el camino real.
create function pg_temp.send(p_name text, p_props jsonb) returns void language sql as $$
  insert into public.telemetry_events
    (install_id, session_id, client_ts, name, app_version, build, os_version, device_model, storefront, props)
  values
    ('6f1c2a5e-0c1e-4a57-9a0b-2b1f0d7a9c11', '0b7d9a1e-6c3f-4e2a-8d5b-7f1a2c3d4e5f', now(), p_name,
     '2.1.0', '500', '18.1', 'iPhone16,2', 'ARG', p_props)
$$;
grant execute on function pg_temp.send(text, jsonb) to anon;

update public.settings set value = 'true'::jsonb where key = 'telemetry_enabled';

-- Los dos checks siguen siendo uno de cada uno: la migración reemplaza, no suma.
do $$
begin
  if (select count(*) from pg_constraint where conrelid = 'public.telemetry_events'::regclass
      and conname in ('telemetry_events_name_check', 'telemetry_props_by_name')) <> 2 then
    raise exception 'faltan los checks de nombre y de props, o están con otro nombre';
  end if;
  if (select count(*) from pg_constraint where conrelid = 'public.telemetry_events'::regclass
      and contype = 'c' and pg_get_constraintdef(oid) like '%session_start%') <> 2 then
    raise exception 'quedó un check viejo de nombre o de props al lado del nuevo';
  end if;
  raise notice 'OK los checks de nombre y de props quedaron reemplazados, uno de cada uno';
end $$;

-- Lo válido entra: los tres eventos nuevos, offer con cada ctx y sin ctx, los bordes de largo.
set local role anon;
do $$
begin
  perform pg_temp.send('segment', '{"id": "mid", "ver": "seed-2026-10-16", "src": "rules"}');
  perform pg_temp.send('segment', '{"id": "base", "ver": "3", "src": "tree-1"}');
  perform pg_temp.send('segment', jsonb_build_object('id', 'high', 'ver', repeat('v', 32), 'src', repeat('s', 32)));
  perform pg_temp.send('exposure', '{"exp": "moments", "arm": "ff_merge", "ver": "3"}');
  perform pg_temp.send('exposure', jsonb_build_object('exp', repeat('e', 32), 'arm', repeat('a', 32),
    'ver', repeat('v', 32)));
  perform pg_temp.send('progress', '{"max_tier": 12, "active_minutes": 340, "prestige": 2}');
  perform pg_temp.send('progress', '{"max_tier": 0, "active_minutes": 0, "prestige": 0}');
  perform pg_temp.send('offer', '{"site": "moment.ff_merge", "stage": "shown", "ctx": "floor_full"}');
  perform pg_temp.send('offer', '{"site": "moment.pw", "stage": "accepted", "ctx": "price_wall"}');
  perform pg_temp.send('offer', '{"site": "moment.mr", "stage": "completed", "ctx": "mattress_ready"}');
  perform pg_temp.send('offer', '{"site": "moment.bo", "stage": "dismissed", "ctx": "back_offline"}');
  raise notice 'OK segment, exposure, progress y offer con cada ctx entran, con sus bordes de largo';
end $$;
reset role;

do $$
begin
  if (select count(*) from public.telemetry_events) <> 11 then
    raise exception 'se esperaban 11 eventos, hay %', (select count(*) from public.telemetry_events);
  end if;
end $$;

-- Los seis de F0 siguen entrando igual (offer sin ctx incluido).
set local role anon;
do $$
begin
  perform pg_temp.send('session_start', '{"n": 3}');
  perform pg_temp.send('session_end', '{"seconds": 412}');
  perform pg_temp.send('ad_impression', '{"format": "rewarded", "site": "doubleEarnings", "micros": 10000,
    "currency": "USD", "precision": "precise", "source": "Google"}');
  perform pg_temp.send('offer', '{"site": "ads.watch.double_earnings", "stage": "shown"}');
  perform pg_temp.send('purchase', '{"product": "com.adergames.fisuevolution.pack1"}');
  perform pg_temp.send('prestige', '{"count": 2}');
  raise notice 'OK los seis eventos de F0 siguen entrando como antes';
end $$;
reset role;

-- Cada check rechaza su basura.
set local role anon;
do $$
declare
  c record;
begin
  for c in
    select * from (values
      ('un nombre que todavía no existe', $q$ select pg_temp.send('ledger_summary', '{"n": 1}') $q$),
      -- segment
      ('segment sin props', $q$ select pg_temp.send('segment', '{}') $q$),
      ('segment sin src', $q$ select pg_temp.send('segment', '{"id": "mid", "ver": "1"}') $q$),
      ('segment con una clave de más', $q$ select pg_temp.send('segment', '{"id": "mid", "ver": "1", "src": "rules",
        "country": "ARG"}') $q$),
      ('segment con id fuera de la lista', $q$ select pg_temp.send('segment', '{"id": "whale", "ver": "1",
        "src": "rules"}') $q$),
      ('segment con id en mayúscula', $q$ select pg_temp.send('segment', '{"id": "MID", "ver": "1", "src": "rules"}') $q$),
      ('segment con id numérico', $q$ select pg_temp.send('segment', '{"id": 2, "ver": "1", "src": "rules"}') $q$),
      ('segment con ver de 33', $q$ select pg_temp.send('segment', jsonb_build_object('id', 'low',
        'ver', repeat('v', 33), 'src', 'rules')) $q$),
      ('segment con src de 33', $q$ select pg_temp.send('segment', jsonb_build_object('id', 'low', 'ver', '1',
        'src', repeat('s', 33))) $q$),
      -- exposure
      ('exposure sin arm', $q$ select pg_temp.send('exposure', '{"exp": "moments", "ver": "3"}') $q$),
      ('exposure con una clave de más', $q$ select pg_temp.send('exposure', '{"exp": "moments", "arm": "a",
        "ver": "3", "segment": "high"}') $q$),
      ('exposure con arm de 33', $q$ select pg_temp.send('exposure', jsonb_build_object('exp', 'moments',
        'arm', repeat('a', 33), 'ver', '3')) $q$),
      ('exposure con ver numérico', $q$ select pg_temp.send('exposure', '{"exp": "moments", "arm": "a",
        "ver": 3}') $q$),
      -- progress
      ('progress sin prestige', $q$ select pg_temp.send('progress', '{"max_tier": 12, "active_minutes": 340}') $q$),
      ('progress con una clave de más', $q$ select pg_temp.send('progress', '{"max_tier": 12, "active_minutes": 340,
        "prestige": 2, "coins": 1e9}') $q$),
      ('progress con max_tier de texto', $q$ select pg_temp.send('progress', '{"max_tier": "12",
        "active_minutes": 340, "prestige": 2}') $q$),
      ('progress con minutos negativos', $q$ select pg_temp.send('progress', '{"max_tier": 12,
        "active_minutes": -1, "prestige": 2}') $q$),
      ('progress con prestige negativo', $q$ select pg_temp.send('progress', '{"max_tier": 12,
        "active_minutes": 1, "prestige": -2}') $q$),
      -- offer con ctx
      ('offer con ctx desconocido', $q$ select pg_temp.send('offer', '{"site": "moment.x", "stage": "shown",
        "ctx": "rage_quit"}') $q$),
      ('offer con ctx numérico', $q$ select pg_temp.send('offer', '{"site": "moment.x", "stage": "shown",
        "ctx": 1}') $q$),
      ('offer con ctx null', $q$ select pg_temp.send('offer', '{"site": "moment.x", "stage": "shown",
        "ctx": null}') $q$),
      ('offer con ctx y una clave de más', $q$ select pg_temp.send('offer', '{"site": "moment.x", "stage": "shown",
        "ctx": "floor_full", "arm": "ff_merge"}') $q$),
      -- las claves de un evento no valen en otro
      ('session_end con las claves de progress', $q$ select pg_temp.send('session_end', '{"seconds": 1,
        "max_tier": 3}') $q$),
      ('prestige con ctx', $q$ select pg_temp.send('prestige', '{"count": 1, "ctx": "floor_full"}') $q$)
    ) as t(what, stmt)
  loop
    begin
      execute c.stmt;
      raise exception 'el check dejó pasar: %', c.what;
    exception when check_violation then
      null;
    end;
  end loop;
  raise notice 'OK cada check de la 2.1 rechaza su basura (claves de más o de menos, id y ctx fuera de la lista)';
end $$;
reset role;

-- anon sigue sin leer: los eventos nuevos no abren nada.
set local role anon;
do $$
declare
  n integer;
begin
  begin
    select count(*) into n from public.telemetry_events where name = 'segment';
    raise exception 'anon pudo leer telemetry_events';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'OK anon inserta los eventos de la 2.1 pero no los lee';
end $$;
reset role;

-- Con el interruptor apagado, los nuevos tampoco entran.
update public.settings set value = 'false'::jsonb where key = 'telemetry_enabled';
set local role anon;
do $$
begin
  begin
    perform pg_temp.send('segment', '{"id": "mid", "ver": "1", "src": "rules"}');
    raise exception 'anon insertó un segment con el interruptor apagado';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'OK con el interruptor apagado, los eventos de la 2.1 tampoco entran';
end $$;
reset role;

rollback;
