-- Todas reciben la hora del handler (el reloj del servidor, nunca un dato del cliente).
-- Errores: P0403 la partida no es del jugador, P0409 la partida no está en el estado pedido.

create function public.setting_int(p_key text) returns integer
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  return (select (value)::int from settings where key = p_key);
end $$;

create function public.ranking_settings() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  return (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from settings);
end $$;

create function public.player_id_for(p_hash text) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_id uuid;
begin
  insert into players (install_id_hash) values (p_hash)
  on conflict (install_id_hash) do nothing;
  select id into v_id from players where install_id_hash = p_hash;
  return v_id;
end $$;

create function public.hit_rate_limit(p_hash text, p_now timestamptz) returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_calls integer;
begin
  delete from api_calls where install_id_hash = p_hash and at <= p_now - interval '1 hour';
  insert into api_calls (install_id_hash, at) values (p_hash, p_now);
  select count(*) into v_calls from api_calls
  where install_id_hash = p_hash and at > p_now - interval '1 hour';
  return v_calls > setting_int('rate_limit_per_hour');
end $$;

create function public.start_run(p_hash text, p_app_version text, p_now timestamptz)
returns table (run_id uuid, started_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_player uuid := player_id_for(p_hash);
begin
  perform 1 from players p where p.id = v_player for update;
  update runs r set status = 'abandoned' where r.player_id = v_player and r.status = 'active';
  return query
    insert into runs as r (player_id, started_at, app_version)
    values (v_player, p_now, p_app_version)
    returning r.id, r.started_at;
end $$;

create function public.owned_run_for_update(p_hash text, p_run_id uuid) returns public.runs
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_run runs;
begin
  select r.* into v_run from runs r
  join players p on p.id = r.player_id
  where r.id = p_run_id and p.install_id_hash = p_hash
  for update of r;
  if not found then
    raise exception 'not_owner' using errcode = 'P0403';
  end if;
  return v_run;
end $$;

create function public.finish_run(p_hash text, p_run_id uuid, p_played integer, p_now timestamptz)
returns table (status public.run_status, name_status public.name_status, real_seconds integer)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_run runs := owned_run_for_update(p_hash, p_run_id);
  v_real integer;
begin
  if v_run.status in ('finished', 'review') then
    return query select v_run.status, v_run.name_status, v_run.real_seconds;
    return;
  end if;
  if v_run.status <> 'active' then
    raise exception 'not_active' using errcode = 'P0409';
  end if;
  v_real := greatest(0, floor(extract(epoch from p_now - v_run.started_at)))::integer;
  return query
    update runs r set
      finished_at = p_now,
      real_seconds = v_real,
      played_seconds = least(greatest(coalesce(p_played, 0), 0), v_real),
      status = case when v_real < setting_int('min_real_seconds_to_god')
                    then 'review'::run_status else 'finished'::run_status end
    where r.id = v_run.id
    returning r.status, r.name_status, r.real_seconds;
end $$;

create function public.set_run_name(
  p_hash text, p_run_id uuid, p_name text, p_name_status public.name_status, p_now timestamptz)
returns table (name_status public.name_status, rank bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_run runs := owned_run_for_update(p_hash, p_run_id);
begin
  if p_name is null or p_name_status not in ('ok', 'pending', 'rejected') then
    raise exception 'invalid name_status %', p_name_status using errcode = '22023';
  end if;
  if v_run.status not in ('finished', 'review') then
    raise exception 'not_sealed' using errcode = 'P0409';
  end if;
  if v_run.name_status <> 'ok' then
    update runs r set
      name = p_name,
      name_status = p_name_status,
      name_updated_at = p_now,
      moderation_attempts = r.moderation_attempts + case when p_name_status = 'pending' then 1 else 0 end
    where r.id = v_run.id;
    if p_name_status = 'ok' then
      update players p set last_name = p_name where p.id = v_run.player_id;
    end if;
  end if;
  return query
    select r.name_status, (select l.rank from leaderboard_internal l where l.run_id = r.id)
    from runs r where r.id = v_run.id;
end $$;

create function public.report_run(p_hash text, p_run_id uuid, p_now timestamptz) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_reporter uuid := player_id_for(p_hash);
begin
  insert into reports (run_id, reporter_player_id, created_at)
  select r.id, v_reporter, p_now from runs r
  where r.id = p_run_id and r.player_id <> v_reporter
  on conflict do nothing;
end $$;

create function public.leaderboard_top(p_hash text, p_limit integer default 100)
returns table (run_id uuid, rank bigint, display_name text, real_seconds integer,
               played_seconds integer, finished_at timestamptz, is_me boolean)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  return query
    select l.run_id, l.rank, l.display_name, l.real_seconds, l.played_seconds, l.finished_at,
           coalesce(p.install_id_hash = p_hash, false)
    from leaderboard_internal l
    join players p on p.id = l.player_id
    order by l.rank, l.finished_at, l.run_id
    limit greatest(0, least(coalesce(p_limit, 100), 500));
end $$;

create function public.my_rank(p_hash text)
returns table (run_id uuid, rank bigint, display_name text, real_seconds integer,
               played_seconds integer, finished_at timestamptz, is_me boolean)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  return query
    select l.run_id, l.rank, l.display_name, l.real_seconds, l.played_seconds, l.finished_at, true
    from leaderboard_internal l
    join players p on p.id = l.player_id
    where p.install_id_hash = p_hash;
end $$;

create function public.my_runs(p_hash text)
returns table (run_id uuid, started_at timestamptz, finished_at timestamptz, real_seconds integer,
               played_seconds integer, name text, name_status public.name_status,
               status public.run_status)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  return query
    select r.id, r.started_at, r.finished_at, r.real_seconds, r.played_seconds, r.name,
           r.name_status, r.status
    from runs r
    join players p on p.id = r.player_id
    where p.install_id_hash = p_hash and r.status in ('finished', 'review')
    order by r.finished_at desc;
end $$;

create function public.pending_names(p_older_than interval, p_limit integer, p_now timestamptz default now())
returns table (run_id uuid, install_id_hash text, name text, moderation_attempts integer)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  return query
    select r.id, p.install_id_hash, r.name, r.moderation_attempts
    from runs r
    join players p on p.id = r.player_id
    where r.name_status = 'pending'
      and r.status in ('finished', 'review')
      and r.moderation_attempts < 20
      and r.name_updated_at <= p_now - p_older_than
    order by r.name_updated_at
    limit greatest(0, p_limit);
end $$;

-- Las del dueño, desde el editor SQL del panel.
create function public.approve_run(p_run_id uuid) returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update runs set status = 'finished' where id = p_run_id and status = 'review';
  return found;
end $$;

create function public.hide_run(p_run_id uuid) returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update runs set status = 'hidden' where id = p_run_id and status in ('finished', 'review');
  return found;
end $$;

create function public.clear_reports(p_run_id uuid) returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  delete from reports where run_id = p_run_id;
  return found;
end $$;

revoke execute on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
grant execute on all functions in schema public to service_role;
