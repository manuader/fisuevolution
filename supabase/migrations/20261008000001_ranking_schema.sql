create table public.players (
  id uuid primary key default gen_random_uuid(),
  install_id_hash text not null unique check (install_id_hash ~ '^[0-9a-f]{64}$'),
  last_name text check (last_name is null or char_length(last_name) between 1 and 15),
  created_at timestamptz not null default now()
);

create type public.run_status as enum ('active', 'finished', 'review', 'hidden', 'abandoned');
create type public.name_status as enum ('ok', 'pending', 'rejected', 'missing');

create table public.runs (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  started_at timestamptz not null,
  finished_at timestamptz,
  real_seconds integer check (real_seconds >= 0),
  played_seconds integer check (played_seconds >= 0),
  name text check (name is null or char_length(name) between 1 and 15),
  name_updated_at timestamptz,
  status public.run_status not null default 'active',
  name_status public.name_status not null default 'missing',
  moderation_attempts integer not null default 0,
  app_version text not null check (char_length(app_version) <= 32)
);
create unique index runs_one_active_per_player on public.runs(player_id) where status = 'active';
create index runs_board on public.runs(real_seconds, finished_at) where status = 'finished';
create index runs_by_player on public.runs(player_id);
create index runs_pending_names on public.runs(name_updated_at) where name_status = 'pending';

create table public.reports (
  run_id uuid not null references public.runs(id) on delete cascade,
  reporter_player_id uuid not null references public.players(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (run_id, reporter_player_id)
);

create table public.blocklist (
  term text not null,
  lang text not null check (lang in ('es', 'en')),
  primary key (term, lang)
);

create table public.settings (key text primary key, value jsonb not null);
insert into public.settings (key, value) values
  ('ranking_enabled', 'true'),
  ('min_real_seconds_to_god', '36000'),
  ('rate_limit_per_hour', '30'),
  ('reports_to_hide', '3');

create table public.api_calls (
  install_id_hash text not null check (install_id_hash ~ '^[0-9a-f]{64}$'),
  at timestamptz not null default now()
);
create index api_calls_recent on public.api_calls(install_id_hash, at);

alter table public.players enable row level security;
alter table public.runs enable row level security;
alter table public.reports enable row level security;
alter table public.blocklist enable row level security;
alter table public.settings enable row level security;
alter table public.api_calls enable row level security;
-- Sin políticas: anon y authenticated no ven ni escriben ninguna tabla.

-- La mejor partida publicada de cada jugador. Se publican sólo las finished con nombre ok o
-- pending; display_name es null ("Anónimo") si el nombre está pendiente o juntó los reportes
-- que ocultan. Sólo la usan las funciones: lleva player_id.
create view public.leaderboard_internal with (security_invoker = false) as
with eligible as (
  select r.*, (select count(*) from public.reports p where p.run_id = r.id) as report_count
  from public.runs r
  where r.status = 'finished' and r.name_status in ('ok', 'pending')
), best as (
  select distinct on (player_id) * from eligible
  order by player_id, real_seconds, finished_at, id
)
select id as run_id,
       player_id,
       case when name_status = 'ok'
             and report_count < (select (value)::int from public.settings where key = 'reports_to_hide')
            then name end as display_name,
       real_seconds,
       played_seconds,
       finished_at,
       rank() over (order by real_seconds, finished_at) as rank
from best;

-- La cara pública: lo mismo sin player_id.
create view public.leaderboard with (security_invoker = false) as
select run_id, display_name, real_seconds, played_seconds, finished_at, rank
from public.leaderboard_internal;

revoke all on all tables in schema public from public, anon, authenticated;
alter default privileges in schema public revoke all on tables from public, anon, authenticated;
grant select on public.leaderboard to anon, authenticated;
