set client_min_messages = notice;
begin;

-- Un evento válido de C4, insertado con las columnas que manda la app (nunca id ni received_at).
create function pg_temp.send(p_name text, p_props jsonb, p_client_ts timestamptz default now(),
                             p_app_version text default '2.0.0', p_device_model text default 'iPhone16,2',
                             p_storefront text default 'ARG') returns void language sql as $$
  insert into public.telemetry_events
    (install_id, session_id, client_ts, name, app_version, build, os_version, device_model, storefront, props)
  values
    ('6f1c2a5e-0c1e-4a57-9a0b-2b1f0d7a9c11', '0b7d9a1e-6c3f-4e2a-8d5b-7f1a2c3d4e5f', p_client_ts, p_name,
     p_app_version, '412', '18.1', p_device_model, p_storefront, p_props)
$$;
grant execute on function pg_temp.send(text, jsonb, timestamptz, text, text, text) to anon, authenticated;

do $$
begin
  if (select value from public.settings where key = 'telemetry_enabled') is distinct from 'false'::jsonb then
    raise exception 'el interruptor no arranca sembrado en false';
  end if;
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'telemetry_events' and c.relkind = 'r' and c.relrowsecurity
  ) then
    raise exception 'falta telemetry_events o no tiene RLS';
  end if;
  if (select count(*) from pg_policies where schemaname = 'public' and tablename = 'telemetry_events') <> 1
     or not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'telemetry_events'
                    and cmd = 'INSERT' and roles = array['anon']::name[]) then
    raise exception 'telemetry_events no tiene exactamente una política, de insert para anon';
  end if;
  if not exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'telemetry_events'
                 and indexdef like '%(name, received_at)%')
     or not exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'telemetry_events'
                    and indexdef like '%(install_id, received_at)%') then
    raise exception 'faltan los índices por nombre y por instalación';
  end if;
  raise notice 'OK telemetry_events existe con RLS, una sola política de insert, sus índices y el interruptor en false';
end $$;

-- Interruptor apagado: anon pregunta y recibe false, y no puede insertar.
set local role anon;
do $$
begin
  if public.telemetry_enabled() is distinct from false then
    raise exception 'con el interruptor apagado telemetry_enabled() no dice false';
  end if;
  begin
    perform pg_temp.send('session_start', '{"n": 1}');
    raise exception 'anon insertó con el interruptor apagado';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'OK interruptor apagado: anon lee false y no inserta';
end $$;
reset role;

do $$
begin
  if (select count(*) from public.telemetry_events) <> 0 then
    raise exception 'quedó un evento con el interruptor apagado';
  end if;
end $$;

-- Cualquier valor que no sea un true explícito es apagado, y sin la fila también.
do $$
begin
  update public.settings set value = '"true"'::jsonb where key = 'telemetry_enabled';
  if public.telemetry_enabled() then
    raise exception 'el texto "true" prendió el interruptor';
  end if;
  update public.settings set value = '1'::jsonb where key = 'telemetry_enabled';
  if public.telemetry_enabled() then
    raise exception 'un 1 prendió el interruptor';
  end if;
  delete from public.settings where key = 'telemetry_enabled';
  if public.telemetry_enabled() is distinct from false then
    raise exception 'sin la fila telemetry_enabled() no dice false';
  end if;
  insert into public.settings (key, value) values ('telemetry_enabled', 'true'::jsonb);
  raise notice 'OK sólo un true explícito prende el interruptor; sin la fila, apagado';
end $$;

-- Interruptor prendido: anon inserta los seis eventos, pero no lee, no actualiza ni borra.
set local role anon;
do $$
declare
  n integer;
begin
  if public.telemetry_enabled() is distinct from true then
    raise exception 'con el interruptor prendido telemetry_enabled() no dice true';
  end if;
  perform pg_temp.send('session_start', '{"n": 3}');
  perform pg_temp.send('session_end', '{"seconds": 412}');
  perform pg_temp.send('ad_impression', '{"format": "rewarded", "site": "doubleEarnings", "micros": 10000,
    "currency": "USD", "precision": "precise", "source": "Google"}');
  perform pg_temp.send('offer', '{"site": "ads.watch.double_earnings", "stage": "shown"}');
  perform pg_temp.send('purchase', '{"product": "com.adergames.fisuevolution.pack1"}');
  perform pg_temp.send('prestige', '{"count": 2}', p_storefront => null);

  begin
    select count(*) into n from public.telemetry_events;
    raise exception 'anon pudo leer telemetry_events';
  exception when insufficient_privilege then
    null;
  end;
  begin
    update public.telemetry_events set name = name;
    raise exception 'anon pudo actualizar telemetry_events';
  exception when insufficient_privilege then
    null;
  end;
  begin
    delete from public.telemetry_events;
    raise exception 'anon pudo borrar telemetry_events';
  exception when insufficient_privilege then
    null;
  end;
  begin
    insert into public.telemetry_events
      (install_id, session_id, client_ts, name, app_version, build, os_version, device_model, props, received_at)
    values (gen_random_uuid(), gen_random_uuid(), now(), 'session_start', '2.0.0', '1', '18.1', 'iPhone16,2',
            '{}', now() - interval '500 days');
    raise exception 'anon pudo elegir received_at';
  exception when insufficient_privilege then
    null;
  end;
  begin
    insert into public.telemetry_events
      (id, install_id, session_id, client_ts, name, app_version, build, os_version, device_model, props)
    values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), now(), 'session_start', '2.0.0', '1', '18.1',
            'iPhone16,2', '{}');
    raise exception 'anon pudo elegir el id';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform public.cleanup_telemetry(now());
    raise exception 'anon pudo ejecutar cleanup_telemetry';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'OK interruptor prendido: anon inserta los seis eventos y no lee, actualiza, borra ni elige id o received_at';
end $$;
reset role;

do $$
begin
  if (select count(*) from public.telemetry_events) <> 6 then
    raise exception 'se esperaban 6 eventos, hay %', (select count(*) from public.telemetry_events);
  end if;
  if exists (select 1 from public.telemetry_events where received_at is null or id is null) then
    raise exception 'el servidor no completó id y received_at';
  end if;
end $$;

-- authenticated no tiene nada: ni insertar, ni leer, ni preguntar por el interruptor.
set local role authenticated;
do $$
declare
  n integer;
begin
  begin
    perform pg_temp.send('session_start', '{"n": 1}');
    raise exception 'authenticated pudo insertar';
  exception when insufficient_privilege then
    null;
  end;
  begin
    select count(*) into n from public.telemetry_events;
    raise exception 'authenticated pudo leer';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform public.telemetry_enabled();
    raise exception 'authenticated pudo ejecutar telemetry_enabled';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'OK authenticated no inserta, no lee ni pregunta por el interruptor';
end $$;
reset role;

-- Cada check rechaza su basura (como anon, con el interruptor prendido: el camino real).
set local role anon;
do $$
declare
  c record;
begin
  for c in
    select * from (values
      ('nombre fuera de la lista', $q$ select pg_temp.send('install', '{}') $q$),
      ('app_version de 17', $q$ select pg_temp.send('session_start', '{}', p_app_version => repeat('9', 17)) $q$),
      ('device_model de 33', $q$ select pg_temp.send('session_start', '{}', p_device_model => repeat('x', 33)) $q$),
      ('storefront de 2 letras', $q$ select pg_temp.send('session_start', '{}', p_storefront => 'AR') $q$),
      ('storefront en minúscula', $q$ select pg_temp.send('session_start', '{}', p_storefront => 'arg') $q$),
      ('props que es un arreglo', $q$ select pg_temp.send('session_start', '[1, 2]') $q$),
      ('props que es un texto', $q$ select pg_temp.send('session_start', '"hola"') $q$),
      ('props de más de 2 KB', $q$ select pg_temp.send('session_start',
                                   jsonb_build_object('x', (select string_agg(md5(i::text), '')
                                                            from generate_series(1, 80) i))) $q$),
      ('client_ts de hace 31 días', $q$ select pg_temp.send('session_start', '{}', now() - interval '31 days') $q$),
      ('client_ts de dentro de 31 días', $q$ select pg_temp.send('session_start', '{}', now() + interval '31 days') $q$)
    ) as t(what, stmt)
  loop
    begin
      execute c.stmt;
      raise exception 'el check dejó pasar: %', c.what;
    exception when check_violation then
      null;
    end;
  end loop;
  begin
    perform pg_temp.send(null, '{}');
    raise exception 'el check dejó pasar: name null';
  exception when not_null_violation then
    null;
  end;
  perform pg_temp.send('session_start', '{}', now() - interval '29 days', repeat('9', 16), repeat('x', 32), 'USA');
  raise notice 'OK cada check rechaza su basura y el borde válido entra';
end $$;
reset role;

-- La retención: lo de más de 400 días se borra, lo demás queda.
do $$
declare
  deleted integer;
begin
  insert into public.telemetry_events
    (install_id, session_id, client_ts, name, app_version, build, os_version, device_model, props, received_at)
  values
    (gen_random_uuid(), gen_random_uuid(), '2025-08-01Z', 'session_start', '2.0.0', '1', '18.1', 'iPhone16,2', '{}',
     '2025-08-01Z'),
    (gen_random_uuid(), gen_random_uuid(), '2025-09-20Z', 'session_start', '2.0.0', '1', '18.1', 'iPhone16,2', '{}',
     '2025-09-20Z');
  deleted := public.cleanup_telemetry('2026-10-15Z');
  if deleted <> 1 then
    raise exception 'cleanup_telemetry borró % (se esperaba 1)', deleted;
  end if;
  if exists (select 1 from public.telemetry_events where received_at = '2025-08-01Z')
     or not exists (select 1 from public.telemetry_events where received_at = '2025-09-20Z') then
    raise exception 'la retención borró lo que no era';
  end if;
  raise notice 'OK la retención borra lo de más de 400 días y deja lo demás';
end $$;

-- El cron de la retención: pg_cron no existe en el Postgres local; donde existe, el job tiene que estar.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if not exists (select 1 from cron.job where jobname = 'telemetry-retention'
                   and command like '%cleanup_telemetry%') then
      raise exception 'falta el cron telemetry-retention';
    end if;
    raise notice 'OK el cron telemetry-retention existe';
  elsif exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    raise exception 'pg_cron está disponible pero la migración de retención no corrió';
  else
    raise notice 'OK el cron telemetry-retention se saltea en local (sin pg_cron), como ranking-remoderate';
  end if;
end $$;

rollback;
