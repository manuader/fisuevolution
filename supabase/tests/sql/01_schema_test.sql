set client_min_messages = notice;

do $$
declare
  t text;
begin
  foreach t in array array['players', 'runs', 'reports', 'blocklist', 'settings', 'api_calls'] loop
    if not exists (
      select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = t and c.relkind = 'r' and c.relrowsecurity
    ) then
      raise exception 'falta la tabla % o no tiene RLS', t;
    end if;
  end loop;
  raise notice 'OK las seis tablas existen con RLS prendido';
end $$;

do $$
begin
  if exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity
  ) then
    raise exception 'hay una tabla de public sin RLS';
  end if;
  raise notice 'OK ninguna tabla de public queda sin RLS';
end $$;

do $$
begin
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and tablename = 'runs' and indexname = 'runs_one_active_per_player'
      and indexdef like 'CREATE UNIQUE INDEX%' and indexdef like '%WHERE (status = ''active''%'
  ) then
    raise exception 'falta el índice único parcial de una partida activa por jugador';
  end if;
  raise notice 'OK una sola partida activa por jugador, por índice';
end $$;

do $$
begin
  if not exists (select 1 from pg_views where schemaname = 'public' and viewname = 'leaderboard') then
    raise exception 'falta la vista leaderboard';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'leaderboard' and column_name = 'player_id'
  ) then
    raise exception 'la vista pública expone player_id';
  end if;
  raise notice 'OK la vista leaderboard existe y no expone player_id';
end $$;

do $$
begin
  if (select (value)::int from public.settings where key = 'min_real_seconds_to_god') is distinct from 36000
     or (select (value)::boolean from public.settings where key = 'ranking_enabled') is distinct from true
     or (select (value)::int from public.settings where key = 'rate_limit_per_hour') is distinct from 30
     or (select (value)::int from public.settings where key = 'reports_to_hide') is distinct from 3 then
    raise exception 'los settings iniciales no son los esperados';
  end if;
  raise notice 'OK los settings arrancan con el piso, el interruptor, el límite y los reportes';
end $$;
