set client_min_messages = notice;

-- Los permisos, mirados desde el catálogo: cubren también lo que sumen migraciones futuras.
do $$
declare
  r record;
  who text;
begin
  foreach who in array array['anon', 'authenticated'] loop
    for r in
      select c.oid, c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p')
    loop
      if has_table_privilege(who, r.oid, 'INSERT') or has_table_privilege(who, r.oid, 'UPDATE')
         or has_table_privilege(who, r.oid, 'DELETE') or has_table_privilege(who, r.oid, 'TRUNCATE') then
        raise exception '% puede escribir en %', who, r.relname;
      end if;
      if r.relname <> 'leaderboard' and (
           has_table_privilege(who, r.oid, 'SELECT')
           or has_any_column_privilege(who, r.oid, 'SELECT')) then
        raise exception '% puede leer %', who, r.relname;
      end if;
    end loop;
    for r in
      select p.oid, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
    loop
      if has_function_privilege(who, r.oid, 'EXECUTE') then
        raise exception '% puede ejecutar %', who, r.proname;
      end if;
    end loop;
  end loop;
  raise notice 'OK anon y authenticated no escriben nada, no leen tablas ni ejecutan funciones';
end $$;

do $$
declare
  r record;
begin
  for r in
    select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and (not p.prosecdef
      or not coalesce(array_to_string(p.proconfig, ',') like '%search_path=public%', false))
  loop
    raise exception 'la función % no es security definer con search_path fijo', r.proname;
  end loop;
  if not has_function_privilege('service_role', 'public.start_run(text, text, timestamptz)', 'EXECUTE') then
    raise exception 'service_role no puede ejecutar start_run';
  end if;
  raise notice 'OK las funciones son security definer con search_path fijo y sólo para service_role';
end $$;

set role anon;

do $$
declare
  t text;
  col text;
  verb text;
  stmt text;
begin
  foreach t in array array['players', 'runs', 'reports', 'blocklist', 'settings', 'api_calls'] loop
    select a.attname into col from pg_attribute a
    where a.attrelid = format('public.%I', t)::regclass and a.attnum = 1;
    foreach verb in array array['insert', 'update', 'delete', 'select'] loop
      stmt := case verb
        when 'insert' then format('insert into public.%I default values', t)
        when 'update' then format('update public.%I set %I = %I', t, col, col)
        when 'delete' then format('delete from public.%I', t)
        else format('select count(*) from public.%I', t)
      end;
      begin
        execute stmt;
        raise exception 'anon pudo hacer % en %', verb, t;
      exception when insufficient_privilege then
        null;
      end;
    end loop;
  end loop;
  raise notice 'OK anon no inserta, actualiza, borra ni lee ninguna tabla';
end $$;

do $$
declare
  n integer;
begin
  select count(*) into n from public.leaderboard;
  begin
    perform public.start_run(repeat('a', 64), '2.0.0', now());
    raise exception 'anon pudo ejecutar start_run';
  exception when insufficient_privilege then
    null;
  end;
  begin
    insert into public.leaderboard (run_id) values (gen_random_uuid());
    raise exception 'anon pudo insertar en la vista';
  exception when insufficient_privilege or feature_not_supported or object_not_in_prerequisite_state then
    null;
  end;
  raise notice 'OK anon lee la vista leaderboard y no ejecuta start_run';
end $$;

reset role;
set role authenticated;

do $$
declare
  n integer;
begin
  select count(*) into n from public.leaderboard;
  begin
    perform count(*) from public.runs;
    raise exception 'authenticated pudo leer runs';
  exception when insufficient_privilege then
    null;
  end;
  begin
    insert into public.players (install_id_hash) values (repeat('b', 64));
    raise exception 'authenticated pudo insertar en players';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform public.finish_run(repeat('a', 64), gen_random_uuid(), 1, now());
    raise exception 'authenticated pudo ejecutar finish_run';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'OK authenticated tiene los mismos candados que anon';
end $$;

reset role;
