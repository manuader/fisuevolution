-- La telemetría anónima de la 2.0 (E15 F0). La app inserta con la clave anon; nadie de afuera lee.
-- Tres candados: el interruptor (settings.telemetry_enabled, sembrado en false) que mira la única
-- política, las columnas que anon puede escribir (nunca id ni received_at) y los checks de C4.
-- Sin límite de frecuencia por instalación: riesgo aceptado (ver supabase/README.md).
create table public.telemetry_events (
  id uuid primary key default gen_random_uuid(),
  received_at timestamptz not null default now(),
  install_id uuid not null,
  session_id uuid not null,
  client_ts timestamptz not null,
  name text not null check (name in ('session_start', 'session_end', 'ad_impression', 'offer', 'purchase', 'prestige')),
  app_version text not null check (char_length(app_version) <= 16),
  build text not null check (char_length(build) <= 16),
  os_version text not null check (char_length(os_version) <= 16),
  device_model text not null check (char_length(device_model) <= 32),
  storefront text check (storefront is null or storefront ~ '^[A-Z]{3}$'),
  props jsonb not null default '{}'::jsonb
    check (jsonb_typeof(props) = 'object' and pg_column_size(props) <= 2048),
  -- Las claves de props por evento (C4): las mismas, todas presentes (source es opcional), cada una
  -- con su tipo y su largo. Una clave de más, de menos o un texto que no corresponde rechaza la fila.
  constraint telemetry_props_by_name check (coalesce(case name
    when 'session_start' then props - 'n' = '{}'::jsonb and jsonb_typeof(props -> 'n') = 'number'
    when 'session_end' then props - 'seconds' = '{}'::jsonb and jsonb_typeof(props -> 'seconds') = 'number'
    when 'ad_impression' then
      props - array['format', 'site', 'micros', 'currency', 'precision', 'source'] = '{}'::jsonb
      and jsonb_typeof(props -> 'format') = 'string' and char_length(props ->> 'format') <= 32
      and jsonb_typeof(props -> 'site') = 'string' and char_length(props ->> 'site') <= 64
      and jsonb_typeof(props -> 'micros') = 'number'
      and jsonb_typeof(props -> 'currency') = 'string' and (props ->> 'currency') ~ '^[A-Z]{3}$'
      and jsonb_typeof(props -> 'precision') = 'string' and char_length(props ->> 'precision') <= 32
      and (not props ? 'source'
           or (jsonb_typeof(props -> 'source') = 'string' and char_length(props ->> 'source') <= 32))
    when 'offer' then
      props - array['site', 'stage'] = '{}'::jsonb
      and jsonb_typeof(props -> 'site') = 'string' and char_length(props ->> 'site') <= 64
      and jsonb_typeof(props -> 'stage') = 'string' and char_length(props ->> 'stage') <= 32
    when 'purchase' then
      props - 'product' = '{}'::jsonb
      and jsonb_typeof(props -> 'product') = 'string' and char_length(props ->> 'product') <= 128
    when 'prestige' then props - 'count' = '{}'::jsonb and jsonb_typeof(props -> 'count') = 'number'
  end, false)),
  -- La hora del teléfono, a ±30 días de la llegada (received_at la pone el servidor: es now()).
  check (client_ts between received_at - interval '30 days' and received_at + interval '30 days')
);
create index telemetry_events_by_name on public.telemetry_events(name, received_at);
create index telemetry_events_by_install on public.telemetry_events(install_id, received_at);

insert into public.settings (key, value) values ('telemetry_enabled', 'false'::jsonb);

-- Sólo un true explícito prende; sin la fila, o con cualquier otro valor, está apagado.
create function public.telemetry_enabled() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select value = 'true'::jsonb from public.settings where key = 'telemetry_enabled'), false)
$$;

-- La retención: la llama el cron (…000002) una vez por día.
create function public.cleanup_telemetry(p_now timestamptz) returns integer
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_deleted integer;
begin
  delete from telemetry_events where received_at < p_now - interval '400 days';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end $$;

alter table public.telemetry_events enable row level security;
create policy telemetry_insert_when_enabled on public.telemetry_events
  for insert to anon with check (public.telemetry_enabled());

revoke all on public.telemetry_events from public, anon, authenticated;
grant insert (install_id, session_id, client_ts, name, app_version, build, os_version, device_model, storefront, props)
  on public.telemetry_events to anon;

revoke execute on function public.telemetry_enabled() from public, anon, authenticated;
grant execute on function public.telemetry_enabled() to anon, service_role;
revoke execute on function public.cleanup_telemetry(timestamptz) from public, anon, authenticated;
grant execute on function public.cleanup_telemetry(timestamptz) to service_role;
