set client_min_messages = notice;
begin;

-- Las vistas del panel (2.1 F7 T1, …20261016000003): con datos sembrados como postgres (received_at a mano, días
-- relativos a hoy en UTC), cada vista da lo esperado; anon y authenticated no las leen; service_role sí.
-- Los días de las vistas son UTC aunque la sesión esté en otra zona.
set local timezone = 'America/Argentina/Buenos_Aires';

create function pg_temp.d(p_offset integer, p_hour integer default 12) returns timestamptz language sql as $$
  select ((now() at time zone 'UTC')::date + p_offset)::timestamp at time zone 'UTC' + make_interval(hours => p_hour)
$$;

create function pg_temp.ev(p_install text, p_session text, p_at timestamptz, p_name text, p_props jsonb,
                           p_storefront text default 'ARG') returns void language sql as $$
  insert into public.telemetry_events
    (received_at, install_id, session_id, client_ts, name, app_version, build, os_version, device_model, storefront,
     props)
  values
    (p_at, ('00000000-0000-4000-8000-' || lpad(p_install, 12, '0'))::uuid,
     ('00000000-0000-4000-9000-' || lpad(p_session, 12, '0'))::uuid, p_at, p_name, '2.1.0', '500', '18.1',
     'iPhone16,2', p_storefront, p_props)
$$;

-- A: llega hace 10 días (D), segmento mid, ve un brazo de moments y otro de vej, convierte y vuelve D+1 y D+7.
-- B: llega en D, sin segmento, control de moments, un banner en USA; no vuelve.
-- C: llega hoy, segmento high: su cohorte todavía no maduró.
-- E: un progress con un max_tier absurdo.
do $$
begin
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10), 'session_start', '{"n": 1}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10) + interval '1 minute', 'segment',
    '{"id": "mid", "ver": "seed", "src": "rules"}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10) + interval '2 minutes', 'exposure',
    '{"exp": "moments", "arm": "ff_merge", "ver": "3"}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10) + interval '2 minutes', 'exposure',
    '{"exp": "vej", "arm": "model", "ver": "1"}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10) + interval '3 minutes', 'offer',
    '{"site": "moment.ff_merge", "stage": "shown", "ctx": "floor_full"}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10) + interval '4 minutes', 'offer',
    '{"site": "moment.ff_merge", "stage": "accepted", "ctx": "floor_full"}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10) + interval '5 minutes', 'ad_impression',
    '{"format": "rewarded", "site": "moment.ff_merge", "micros": 20000, "currency": "USD", "precision": "precise"}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10) + interval '5 minutes', 'offer',
    '{"site": "moment.ff_merge", "stage": "completed", "ctx": "floor_full"}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10) + interval '6 minutes', 'ad_impression',
    '{"format": "interstitial", "site": "prestige", "micros": 5000, "currency": "USD", "precision": "estimated"}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10) + interval '7 minutes', 'ad_impression',
    '{"format": "rewarded", "site": "ads.watch.double_earnings", "micros": 10000, "currency": "USD",
      "precision": "precise"}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 10) + interval '8 minutes', 'offer',
    '{"site": "ads.watch.double_earnings", "stage": "shown"}');
  perform pg_temp.ev('a', 'a1', pg_temp.d(-10, 11), 'progress', '{"max_tier": 3, "active_minutes": 60, "prestige": 0}');
  perform pg_temp.ev('a', 'a2', pg_temp.d(-9, 10), 'session_start', '{"n": 2}');
  perform pg_temp.ev('a', 'a2', pg_temp.d(-9, 11), 'progress', '{"max_tier": 5, "active_minutes": 180, "prestige": 0}');
  perform pg_temp.ev('a', 'a3', pg_temp.d(-3, 10), 'session_start', '{"n": 3}');

  perform pg_temp.ev('b', 'b1', pg_temp.d(-10, 20), 'session_start', '{"n": 1}', 'USA');
  perform pg_temp.ev('b', 'b1', pg_temp.d(-10, 20) + interval '1 minute', 'exposure',
    '{"exp": "moments", "arm": "control", "ver": "3"}', 'USA');
  perform pg_temp.ev('b', 'b1', pg_temp.d(-10, 20) + interval '2 minutes', 'ad_impression',
    '{"format": "banner", "site": "bottom", "micros": 1000, "currency": "USD", "precision": "estimated"}', 'USA');
  perform pg_temp.ev('b', 'b1', pg_temp.d(-10, 22), 'progress', '{"max_tier": 2, "active_minutes": 120, "prestige": 0}',
    'USA');

  perform pg_temp.ev('c', 'c1', pg_temp.d(0, 0), 'session_start', '{"n": 1}');
  perform pg_temp.ev('c', 'c1', pg_temp.d(0, 0) + interval '1 minute', 'segment',
    '{"id": "high", "ver": "seed", "src": "rules"}');

  perform pg_temp.ev('e', 'e1', pg_temp.d(-5, 10), 'segment', '{"id": "low", "ver": "seed", "src": "rules"}');
  perform pg_temp.ev('e', 'e1', pg_temp.d(-5, 11), 'progress',
    '{"max_tier": 1000000, "active_minutes": 30, "prestige": 1}');
end $$;

-- Las cuatro vistas existen, son security_invoker y sólo service_role las lee.
do $$
declare
  v text;
begin
  foreach v in array array['panel_value_daily', 'panel_offer_funnel', 'panel_retention', 'panel_pacing'] loop
    if not exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
                   where n.nspname = 'public' and c.relname = v and c.relkind = 'v'
                     and 'security_invoker=on' = any(c.reloptions)) then
      raise exception 'falta la vista % o no es security_invoker', v;
    end if;
    if has_table_privilege('anon', 'public.' || v, 'select')
       or has_table_privilege('authenticated', 'public.' || v, 'select') then
      raise exception 'anon o authenticated tienen select sobre %', v;
    end if;
    if not has_table_privilege('service_role', 'public.' || v, 'select') then
      raise exception 'service_role no puede leer %', v;
    end if;
  end loop;
  raise notice 'OK las cuatro vistas del panel son security_invoker y sólo service_role tiene select';
end $$;

-- anon y authenticated chocan al leerlas.
do $$
declare
  r text;
  v text;
  n bigint;
begin
  foreach r in array array['anon', 'authenticated'] loop
    foreach v in array array['panel_value_daily', 'panel_offer_funnel', 'panel_retention', 'panel_pacing'] loop
      execute format('set local role %I', r);
      begin
        execute format('select count(*) from public.%I', v) into n;
        reset role;
        raise exception '% pudo leer %', r, v;
      exception when insufficient_privilege then
        reset role;
      end;
    end loop;
  end loop;
  raise notice 'OK anon y authenticated no leen ninguna vista del panel';
end $$;

-- panel_value_daily: ingreso por instalación-día por segmento, país y formato.
set local role service_role;
do $$
declare
  dd date := (now() at time zone 'UTC')::date - 10;
  r record;
begin
  select * into strict r from public.panel_value_daily
  where dia = dd and segmento = 'mid' and pais = 'ARG' and formato = 'rewarded';
  if r.instalaciones <> 1 or r.impresiones <> 2 or r.micros <> 30000 or r.moneda <> 'USD'
     or r.ingreso <> 0.03 or r.ingreso_por_instalacion_dia <> 0.03 then
    raise exception 'rewarded de mid en ARG el día D no da 1 instalación, 2 impresiones y 0.03: %', r;
  end if;
  select * into strict r from public.panel_value_daily
  where dia = dd and segmento = 'mid' and pais = 'ARG' and formato = 'interstitial';
  if r.impresiones <> 1 or r.ingreso_por_instalacion_dia <> 0.005 then
    raise exception 'interstitial de mid en ARG el día D no da 0.005: %', r;
  end if;
  select * into strict r from public.panel_value_daily
  where dia = dd and segmento = 'sin_dato' and pais = 'USA';
  if r.formato <> 'banner' or r.micros <> 1000 or r.instalaciones <> 1 then
    raise exception 'B (sin segmento, USA) no da su banner de 1000 micros: %', r;
  end if;
  -- A vuelve en D+1 sin ver videos: cuenta con 0, formato vacío.
  select * into strict r from public.panel_value_daily where dia = dd + 1;
  if r.segmento <> 'mid' or r.formato is not null or r.moneda is not null or r.instalaciones <> 1
     or r.impresiones <> 0 or r.ingreso_por_instalacion_dia <> 0 then
    raise exception 'el día D+1 de A no sale con ingreso 0 y formato vacío: %', r;
  end if;
  select * into strict r from public.panel_value_daily where dia = dd + 10;
  if r.segmento <> 'high' or r.instalaciones <> 1 then
    raise exception 'C hoy no sale en high: %', r;
  end if;
  if (select count(*) from public.panel_value_daily where dia = dd) <> 3 then
    raise exception 'el día D tiene filas de más o de menos: %',
      (select count(*) from public.panel_value_daily where dia = dd);
  end if;
  raise notice 'OK panel_value_daily: ingreso por instalación-día por segmento, país y formato (0 sin videos)';
end $$;
reset role;

-- panel_offer_funnel: la fila total, la del brazo de moments (sólo su site) y la de vej (toda la sesión).
set local role service_role;
do $$
declare
  r record;
begin
  select * into strict r from public.panel_offer_funnel where site = 'moment.ff_merge' and exp is null;
  if r.ctx <> 'floor_full' or r.mostradas <> 1 or r.aceptadas <> 1 or r.completadas <> 1
     or r.conversion <> 1 or r.aceptacion <> 1 or r.completado <> 1 then
    raise exception 'la fila total de moment.ff_merge no da 1/1/1: %', r;
  end if;
  select * into strict r from public.panel_offer_funnel where site = 'moment.ff_merge' and exp = 'moments';
  if r.arm <> 'ff_merge' or r.ver <> '3' or r.mostradas <> 1 or r.completadas <> 1 then
    raise exception 'el brazo ff_merge de moments no da su embudo: %', r;
  end if;
  select * into strict r from public.panel_offer_funnel where site = 'ads.watch.double_earnings' and exp is null;
  if r.ctx is not null or r.mostradas <> 1 or r.aceptadas <> 0 or r.completado is not null or r.conversion <> 0 then
    raise exception 'la oferta sin ctx no da 1 mostrada y 0 conversión: %', r;
  end if;
  if exists (select 1 from public.panel_offer_funnel where site = 'ads.watch.double_earnings' and exp = 'moments') then
    raise exception 'una oferta que no es moment.<arm> quedó en el brazo de moments';
  end if;
  select * into strict r from public.panel_offer_funnel where site = 'ads.watch.double_earnings' and exp = 'vej';
  if r.arm <> 'model' or r.ver <> '1' or r.mostradas <> 1 then
    raise exception 'vej no se lleva las ofertas de su sesión: %', r;
  end if;
  if exists (select 1 from public.panel_offer_funnel where arm = 'control') then
    raise exception 'el control de moments (no muestra nada) tiene embudo';
  end if;
  if (select count(*) from public.panel_offer_funnel) <> 5 then
    raise exception 'el embudo tiene % filas, se esperaban 5', (select count(*) from public.panel_offer_funnel);
  end if;
  raise notice 'OK panel_offer_funnel: total, moments por su site y vej por sesión; el control no suma';
end $$;
reset role;

-- panel_retention: cohortes de instalación y por brazo, sólo maduras.
set local role service_role;
do $$
declare
  dd date := (now() at time zone 'UTC')::date - 10;
  r record;
begin
  select * into strict r from public.panel_retention where exp is null and segmento = 'mid';
  if r.dia0 <> dd or r.instalaciones <> 1 or r.d1_elegibles <> 1 or r.d1_retenidas <> 1 or r.d1 <> 1
     or r.d7_elegibles <> 1 or r.d7_retenidas <> 1 or r.d7 <> 1 then
    raise exception 'A (mid) no da D1 y D7 = 1: %', r;
  end if;
  select * into strict r from public.panel_retention where exp is null and segmento = 'sin_dato';
  if r.dia0 <> dd or r.d1_elegibles <> 1 or r.d1_retenidas <> 0 or r.d1 <> 0 or r.d7 <> 0 then
    raise exception 'B (sin_dato) no da D1 y D7 = 0: %', r;
  end if;
  select * into strict r from public.panel_retention where exp is null and segmento = 'high';
  if r.dia0 <> dd + 10 or r.instalaciones <> 1 or r.d1_elegibles <> 0 or r.d1 is not null or r.d7 is not null then
    raise exception 'C (hoy) cuenta como elegible: %', r;
  end if;
  select * into strict r from public.panel_retention where exp = 'moments' and arm = 'ff_merge';
  if r.segmento <> 'mid' or r.dia0 <> dd or r.d1 <> 1 or r.d7 <> 1 then
    raise exception 'el brazo ff_merge no da 1/1: %', r;
  end if;
  select * into strict r from public.panel_retention where exp = 'moments' and arm = 'control';
  if r.segmento <> 'sin_dato' or r.d1_elegibles <> 1 or r.d1 <> 0 or r.d7 <> 0 then
    raise exception 'el control no da 0/0: %', r;
  end if;
  select * into strict r from public.panel_retention where exp = 'vej';
  if r.arm <> 'model' or r.instalaciones <> 1 then
    raise exception 'vej no tiene su brazo: %', r;
  end if;
  if (select count(*) from public.panel_retention) <> 6 then
    raise exception 'la retención tiene % filas, se esperaban 6', (select count(*) from public.panel_retention);
  end if;
  raise notice 'OK panel_retention: D1/D7 por cohorte de instalación y por brazo, sólo cohortes maduras';
end $$;
reset role;

-- Una instalación cuenta en cada brazo que vio, con día 0 = su primer exposure a ese brazo (el bandido de moments
-- elige por momento). A ve pw_cash en D+7: no vuelve D+8 (D1 = 0) y su D7 todavía no maduró.
do $$
begin
  perform pg_temp.ev('a', 'a3', pg_temp.d(-3, 10) + interval '1 minute', 'exposure',
    '{"exp": "moments", "arm": "pw_cash", "ver": "3"}');
  perform pg_temp.ev('a', 'a4', pg_temp.d(-1, 10), 'exposure', '{"exp": "moments", "arm": "ff_merge", "ver": "3"}');
end $$;
set local role service_role;
do $$
declare
  dd date := (now() at time zone 'UTC')::date - 10;
  r record;
begin
  select * into strict r from public.panel_retention where exp = 'moments' and arm = 'pw_cash';
  if r.dia0 <> dd + 7 or r.segmento <> 'mid' or r.d1_elegibles <> 1 or r.d1 <> 0 or r.d7_elegibles <> 0 then
    raise exception 'el segundo brazo de A no arranca en su primer exposure: %', r;
  end if;
  select * into strict r from public.panel_retention where exp = 'moments' and arm = 'ff_merge';
  if r.dia0 <> dd or r.instalaciones <> 1 then
    raise exception 'un exposure repetido movió el día 0 del brazo o lo contó dos veces: %', r;
  end if;
  raise notice 'OK panel_retention cuenta cada brazo que vio la instalación, desde su primer exposure a ese brazo';
end $$;
reset role;

-- panel_pacing: horas activas hasta cada tier, por segmento y reencarnación; el tier se recorta a 64.
set local role service_role;
do $$
declare
  r record;
begin
  select * into strict r from public.panel_pacing where segmento = 'mid' and prestige = 0 and tier = 3;
  if r.instalaciones <> 1 or r.horas_p50 <> 1 then
    raise exception 'A no llega al tier 3 en 1 hora: %', r;
  end if;
  select * into strict r from public.panel_pacing where segmento = 'mid' and prestige = 0 and tier = 5;
  if r.horas_p25 <> 3 or r.horas_p50 <> 3 or r.horas_p75 <> 3 then
    raise exception 'A no llega al tier 5 en 3 horas: %', r;
  end if;
  if exists (select 1 from public.panel_pacing where segmento = 'mid' and tier = 6) then
    raise exception 'A aparece en un tier al que no llegó';
  end if;
  select * into strict r from public.panel_pacing where segmento = 'sin_dato' and tier = 2;
  if r.horas_p50 <> 2 then
    raise exception 'B no llega al tier 2 en 2 horas: %', r;
  end if;
  select * into strict r from public.panel_pacing where segmento = 'sin_dato' and tier = 1;
  if r.instalaciones <> 1 then
    raise exception 'B no cuenta en el tier 1: %', r;
  end if;
  if (select max(tier) from public.panel_pacing where segmento = 'low') <> 64
     or (select count(*) from public.panel_pacing where segmento = 'low' and prestige = 1) <> 64 then
    raise exception 'el max_tier absurdo no quedó recortado a 64';
  end if;
  raise notice 'OK panel_pacing: horas activas hasta cada tier por segmento y reencarnación, tier recortado a 64';
end $$;
reset role;

rollback;
