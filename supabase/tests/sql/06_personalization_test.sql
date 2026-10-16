set client_min_messages = notice;
begin;

-- Lo sembrado: el interruptor en false y la config en la versión 0 vacía; la función es security definer y fija
-- su search_path.
do $$
begin
  if (select value from public.settings where key = 'personalization_enabled') is distinct from 'false'::jsonb then
    raise exception 'el interruptor de la personalización no arranca sembrado en false';
  end if;
  if (select value from public.settings where key = 'personalization_config')
     is distinct from '{"version": 0, "sections": {}}'::jsonb then
    raise exception 'la config no arranca en la versión 0 vacía';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'personalization_config' and p.pronargs = 0
      and p.prosecdef and p.provolatile = 's' and p.proconfig = array['search_path=""']
  ) then
    raise exception 'personalization_config() no es stable security definer con search_path vacío';
  end if;
  raise notice 'OK el interruptor arranca en false, la config en la versión 0 y la función es security definer';
end $$;

-- Apagado: anon pregunta y recibe null.
set local role anon;
do $$
begin
  if public.personalization_config() is not null then
    raise exception 'con el interruptor apagado personalization_config() no devuelve null';
  end if;
  raise notice 'OK interruptor apagado: anon recibe null';
end $$;
reset role;

-- Cualquier valor que no sea un true explícito es apagado, y sin la fila también.
do $$
begin
  update public.settings set value = '"true"'::jsonb where key = 'personalization_enabled';
  if public.personalization_config() is not null then
    raise exception 'el texto "true" prendió la personalización';
  end if;
  update public.settings set value = '1'::jsonb where key = 'personalization_enabled';
  if public.personalization_config() is not null then
    raise exception 'un 1 prendió la personalización';
  end if;
  update public.settings set value = 'null'::jsonb where key = 'personalization_enabled';
  if public.personalization_config() is not null then
    raise exception 'un null de JSON prendió la personalización';
  end if;
  delete from public.settings where key = 'personalization_enabled';
  if public.personalization_config() is not null then
    raise exception 'sin la fila del interruptor personalization_config() no devuelve null';
  end if;
  insert into public.settings (key, value) values ('personalization_enabled', 'true'::jsonb);
  raise notice 'OK sólo un true explícito prende la personalización; sin la fila, apagada';
end $$;

-- Prendido: anon recibe la config tal cual (la sembrada y una cargada después).
update public.settings
set value = '{"version": 3, "sections": {"player_value": {"weights": {"country": 0.6, "device": 0.4}}}}'::jsonb
where key = 'personalization_config';
set local role anon;
do $$
begin
  if public.personalization_config()
     is distinct from '{"version": 3, "sections": {"player_value": {"weights": {"country": 0.6, "device": 0.4}}}}'::jsonb then
    raise exception 'con el interruptor prendido no llega la config cargada: %', public.personalization_config();
  end if;
  raise notice 'OK interruptor prendido: anon recibe la config';
end $$;
reset role;

-- Prendido pero con una config que no sirve (no es objeto, pasa de 64 KB o falta la fila): null, la app juega la base.
do $$
begin
  update public.settings set value = '[1, 2]'::jsonb where key = 'personalization_config';
  if public.personalization_config() is not null then
    raise exception 'una config que es un arreglo salió';
  end if;
  update public.settings
  set value = jsonb_build_object('version', 1, 'sections', jsonb_build_object('x',
    (select string_agg(md5(i::text), '') from generate_series(1, 2100) i)))
  where key = 'personalization_config';
  if public.personalization_config() is not null then
    raise exception 'una config de más de 64 KB salió';
  end if;
  delete from public.settings where key = 'personalization_config';
  if public.personalization_config() is not null then
    raise exception 'sin la fila de la config personalization_config() no devuelve null';
  end if;
  insert into public.settings (key, value) values ('personalization_config', '{"version": 0, "sections": {}}'::jsonb);
  if public.personalization_config() is distinct from '{"version": 0, "sections": {}}'::jsonb then
    raise exception 'la config de nuevo sembrada no salió';
  end if;
  raise notice 'OK una config que no es objeto, que pasa de 64 KB o que falta devuelve null';
end $$;

-- anon no lee ni escribe settings directo (ni el interruptor ni la config): sólo la función.
set local role anon;
do $$
declare
  v jsonb;
begin
  begin
    select value into v from public.settings where key = 'personalization_config';
    raise exception 'anon pudo leer settings';
  exception when insufficient_privilege then
    null;
  end;
  begin
    update public.settings set value = 'true'::jsonb where key = 'personalization_enabled';
    raise exception 'anon pudo prender el interruptor';
  exception when insufficient_privilege then
    null;
  end;
  begin
    insert into public.settings (key, value) values ('personalization_x', '{}'::jsonb);
    raise exception 'anon pudo insertar en settings';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'OK anon no lee ni escribe settings directo';
end $$;
reset role;

-- authenticated no tiene nada: ni la función ni la tabla.
set local role authenticated;
do $$
declare
  v jsonb;
begin
  begin
    v := public.personalization_config();
    raise exception 'authenticated pudo ejecutar personalization_config';
  exception when insufficient_privilege then
    null;
  end;
  begin
    select value into v from public.settings where key = 'personalization_config';
    raise exception 'authenticated pudo leer settings';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'OK authenticated no ejecuta personalization_config ni lee settings';
end $$;
reset role;

rollback;
