set client_min_messages = notice;
begin;

-- Los guardianes del panel (2.1 F7 T3, …20261016000004): panel_bandit_priors y panel_retention_guard. Los eventos
-- se siembran como postgres, con la hora del servidor elegida (received_at) para armar las cohortes.
create function pg_temp.ev(p_install uuid, p_session uuid, p_name text, p_props jsonb, p_at timestamptz)
returns void language sql as $$
  insert into public.telemetry_events
    (received_at, install_id, session_id, client_ts, name, app_version, build, os_version, device_model, storefront,
     props)
  values (p_at, p_install, p_session, p_at, p_name, '2.1.0', '500', '18.1', 'iPhone16,2', 'ARG', p_props)
$$;

create function pg_temp.offers(p_session uuid, p_site text, p_stage text, p_count integer) returns void
language sql as $$
  select pg_temp.ev('11111111-1111-1111-1111-111111111111', p_session, 'offer',
    jsonb_build_object('site', p_site, 'stage', p_stage), '2026-10-12 10:00+00')
  from generate_series(1, p_count)
$$;

-- El embudo de moments por versión: s1 vio pw_small en v1 (3 mostradas, 1 completada, 2 rechazadas); s2 vio
-- pw_small en v0 (no cuenta para v1); s1 también tiene ofertas de ff_merge sin exposición a ff_merge (no cuentan);
-- s3 vio ff_merge en v1 sin ofertas; s4 vio el control; s5 vio pw_big en v1 con 30 mostradas y 10 completadas;
-- s6 vio un brazo de otro experimento (no aparece).
do $$
declare
  i uuid := '11111111-1111-1111-1111-111111111111';
  s1 uuid := 'a0000000-0000-0000-0000-000000000001';
  s2 uuid := 'a0000000-0000-0000-0000-000000000002';
  s3 uuid := 'a0000000-0000-0000-0000-000000000003';
  s4 uuid := 'a0000000-0000-0000-0000-000000000004';
  s5 uuid := 'a0000000-0000-0000-0000-000000000005';
  s6 uuid := 'a0000000-0000-0000-0000-000000000006';
begin
  perform pg_temp.ev(i, s1, 'exposure', '{"exp": "moments", "arm": "pw_small", "ver": "v1"}', '2026-10-12 09:00+00');
  perform pg_temp.offers(s1, 'moment.pw_small', 'shown', 3);
  perform pg_temp.offers(s1, 'moment.pw_small', 'accepted', 1);
  perform pg_temp.offers(s1, 'moment.pw_small', 'completed', 1);
  perform pg_temp.offers(s1, 'moment.pw_small', 'dismissed', 2);
  perform pg_temp.offers(s1, 'moment.ff_merge', 'shown', 4);
  perform pg_temp.offers(s1, 'moment.ff_merge', 'completed', 4);
  perform pg_temp.ev(i, s2, 'exposure', '{"exp": "moments", "arm": "pw_small", "ver": "v0"}', '2026-10-12 09:00+00');
  perform pg_temp.offers(s2, 'moment.pw_small', 'shown', 5);
  perform pg_temp.offers(s2, 'moment.pw_small', 'completed', 5);
  perform pg_temp.ev(i, s3, 'exposure', '{"exp": "moments", "arm": "ff_merge", "ver": "v1"}', '2026-10-12 09:00+00');
  perform pg_temp.ev(i, s4, 'exposure', '{"exp": "moments", "arm": "control", "ver": "v1"}', '2026-10-12 09:00+00');
  perform pg_temp.ev(i, s5, 'exposure', '{"exp": "moments", "arm": "pw_big", "ver": "v1"}', '2026-10-12 09:00+00');
  perform pg_temp.ev(i, s5, 'exposure', '{"exp": "moments", "arm": "pw_big", "ver": "v1"}', '2026-10-12 09:30+00');
  perform pg_temp.offers(s5, 'moment.pw_big', 'shown', 30);
  perform pg_temp.offers(s5, 'moment.pw_big', 'completed', 10);
  perform pg_temp.ev(i, s6, 'exposure', '{"exp": "otro", "arm": "model", "ver": "v1"}', '2026-10-12 09:00+00');
end $$;

do $$
declare
  r record;
begin
  if (select array_agg(arm order by arm) from public.panel_bandit_priors('v1'))
     <> array['control', 'ff_merge', 'pw_big', 'pw_small'] then
    raise exception 'los brazos de v1 no son control, ff_merge, pw_big, pw_small: %',
      (select array_agg(arm order by arm) from public.panel_bandit_priors('v1'));
  end if;
  select * into r from public.panel_bandit_priors('v1') where arm = 'pw_small';
  if (r.shown, r.completed, r.alpha, r.beta) <> (3::bigint, 1::bigint, 2::numeric, 3::numeric) then
    raise exception 'pw_small: se esperaba 3 mostradas, 1 completada, α 2, β 3; dio %', r;
  end if;
  raise notice 'OK α = 1 + completadas, β = 1 + mostradas − completadas, sólo con las sesiones expuestas a esa versión';

  select * into r from public.panel_bandit_priors('v1') where arm = 'ff_merge';
  if (r.shown, r.completed, r.alpha, r.beta) <> (0::bigint, 0::bigint, 1::numeric, 1::numeric) then
    raise exception 'ff_merge: las ofertas de una sesión sin exposición a ff_merge contaron: %', r;
  end if;
  select * into r from public.panel_bandit_priors('v1') where arm = 'control';
  if (r.alpha, r.beta) <> (1::numeric, 1::numeric) then
    raise exception 'el control debía quedar plano (1, 1): %', r;
  end if;
  raise notice 'OK un brazo visto sin ofertas y el control quedan con el prior plano α = β = 1';

  select * into r from public.panel_bandit_priors('v1') where arm = 'pw_big';
  if (r.shown, r.alpha, r.beta) <> (30::bigint, 11::numeric, 21::numeric) then
    raise exception 'pw_big sin tope: se esperaba α 11, β 21 (y la exposición repetida no duplica): %', r;
  end if;
  select * into r from public.panel_bandit_priors('v1', 20) where arm = 'pw_big';
  if (r.alpha, r.beta) <> (7.6667::numeric, 14.3333::numeric) then
    raise exception 'pw_big con tope 20: se esperaba α 7,6667 y β 14,3333 (misma media, 20 pseudo-cuentas): %', r;
  end if;
  select * into r from public.panel_bandit_priors('v1', 20) where arm = 'pw_small';
  if (r.alpha, r.beta) <> (2::numeric, 3::numeric) then
    raise exception 'pw_small está bajo el tope y no debía escalar: %', r;
  end if;
  raise notice 'OK el tope de pseudo-cuentas escala α−1 y β−1 conservando la media; bajo el tope no toca nada';

  if exists (select 1 from public.panel_bandit_priors('v9')) then
    raise exception 'una versión sin exposiciones devolvió filas';
  end if;
  raise notice 'OK una versión sin exposiciones no devuelve brazos (ni los de otro experimento)';
end $$;

-- La retención de vej (control 'rules'), al 2026-11-01, exposición el 2026-10-10:
--   rules 100 instalaciones: 60 vuelven el día 1, 30 el día 7; una vuelve a exponerse el 10-20 (no mueve su día 0)
--         y todas abren también el mismo día 0 (no es D1).
--   model 100: 40 vuelven el día 1, 30 el día 7 → D1 −20 puntos con significancia → apagar.
--   alt   100: 59 el día 1 (−1 punto justo: no alcanza), 30 el día 7 → ok.
--   tiny  5 el 10-10 sin volver + 1 el 10-30 que vuelve el 10-31 (madura para D1, no para D7) → pocos_datos.
-- Una sesión del día 1 a las 23:30 UTC cuenta en ese día.
do $$
declare
  n integer;
  inst uuid;
  arm_name text;
  d1 integer;
  d7 integer;
begin
  for arm_name, n, d1, d7 in
    select * from (values ('rules', 100, 60, 30), ('model', 100, 40, 30), ('alt', 100, 59, 30), ('tiny', 5, 0, 0))
      as t(a, n, d1, d7)
  loop
    for k in 1 .. n loop
      inst := md5(arm_name || k)::uuid;
      perform pg_temp.ev(inst, gen_random_uuid(), 'exposure',
        jsonb_build_object('exp', 'vej', 'arm', arm_name, 'ver', 'v1'), '2026-10-10 12:00+00');
      perform pg_temp.ev(inst, gen_random_uuid(), 'session_start', '{"n": 1}', '2026-10-10 12:00+00');
      if k <= d1 then
        perform pg_temp.ev(inst, gen_random_uuid(), 'session_start', '{"n": 2}', '2026-10-11 23:30+00');
      end if;
      if k <= d7 then
        perform pg_temp.ev(inst, gen_random_uuid(), 'session_start', '{"n": 3}', '2026-10-17 08:00+00');
      end if;
    end loop;
  end loop;
  perform pg_temp.ev(md5('rules1')::uuid, gen_random_uuid(), 'exposure',
    '{"exp": "vej", "arm": "rules", "ver": "v2"}', '2026-10-20 12:00+00');
  inst := md5('tiny-late')::uuid;
  perform pg_temp.ev(inst, gen_random_uuid(), 'exposure', '{"exp": "vej", "arm": "tiny", "ver": "v1"}',
    '2026-10-30 12:00+00');
  perform pg_temp.ev(inst, gen_random_uuid(), 'session_start', '{"n": 2}', '2026-10-31 12:00+00');
end $$;

do $$
declare
  r record;
begin
  if (select array_agg(arm) from public.panel_retention_guard('vej', 'rules', '2026-11-01 00:00+00'))
     <> array['rules', 'alt', 'model', 'tiny'] then
    raise exception 'los brazos o su orden (control primero) no son los esperados: %',
      (select array_agg(arm) from public.panel_retention_guard('vej', 'rules', '2026-11-01 00:00+00'));
  end if;

  select * into r from public.panel_retention_guard('vej', 'rules', '2026-11-01 00:00+00') where arm = 'rules';
  if (r.d1_n, r.d1_rate, r.d7_n, r.d7_rate, r.verdict) <> (100::bigint, 0.6::numeric, 100::bigint, 0.3::numeric,
      'control') or r.d1_diff is not null or r.d7_lo is not null then
    raise exception 'rules: se esperaba D1 0,6 y D7 0,3 sobre 100, sin diferencia propia, control: %', r;
  end if;
  raise notice 'OK el control: D1 y D7 sobre sus cohortes maduras, sin diferencia contra sí mismo';

  select * into r from public.panel_retention_guard('vej', 'rules', '2026-11-01 00:00+00') where arm = 'model';
  if (r.d1_rate, r.d1_diff, r.d1_lo, r.d1_hi, r.verdict)
     <> (0.4::numeric, -0.2::numeric, -0.3358::numeric, -0.0642::numeric, 'apagar') then
    raise exception 'model: se esperaba D1 0,4, −0,2 [−0,3358; −0,0642] y apagar: %', r;
  end if;
  if (r.d7_diff, r.d7_lo, r.d7_hi) <> (0::numeric, -0.1270::numeric, 0.1270::numeric) then
    raise exception 'model: D7 igual al control, se esperaba 0 [−0,127; 0,127]: %', r;
  end if;
  raise notice 'OK peor por más de 1 punto con el intervalo abajo de 0 marca apagar (con D7 igual alcanza D1)';

  select * into r from public.panel_retention_guard('vej', 'rules', '2026-11-01 00:00+00') where arm = 'alt';
  if (r.d1_diff, r.verdict) <> (-0.01::numeric, 'ok') then
    raise exception 'alt: 1 punto justo no es «más de 1 punto»; se esperaba −0,01 y ok: %', r;
  end if;
  raise notice 'OK 1 punto justo abajo del control no apaga';

  select * into r from public.panel_retention_guard('vej', 'rules', '2026-11-01 00:00+00') where arm = 'tiny';
  if (r.d1_n, r.d7_n, r.verdict) <> (6::bigint, 5::bigint, 'pocos_datos') then
    raise exception 'tiny: se esperaba D1 sobre 6 (la tardía madura), D7 sobre 5, pocos_datos: %', r;
  end if;
  raise notice 'OK una cohorte cuenta sólo con su día terminado, y bajo el mínimo es pocos_datos aunque sea peor';

  select * into r from public.panel_retention_guard('vej', 'rules', '2026-11-01 00:00+00', 5) where arm = 'tiny';
  if r.verdict <> 'apagar' then
    raise exception 'tiny con mínimo 5: D1 0 contra 0,6 debía apagar: %', r;
  end if;
  select * into r from public.panel_retention_guard('vej', 'rules', '2026-10-11 00:00+00') where arm = 'model';
  if (r.d1_n, r.d7_n, r.verdict) <> (0::bigint, 0::bigint, 'pocos_datos') then
    raise exception 'al 10-11 el día 1 no terminó: se esperaba D1 y D7 sobre 0 y pocos_datos: %', r;
  end if;
  raise notice 'OK el mínimo de instalaciones es un parámetro, y p_as_of corta las cohortes inmaduras';

  select * into r from public.panel_retention_guard('vej', 'rules', '2026-10-15 00:00+00') where arm = 'model';
  if (r.d1_n, r.d7_n, r.verdict) <> (100::bigint, 0::bigint, 'apagar') then
    raise exception 'al 10-15 D1 está maduro y es peor: debía apagar aunque D7 no tenga datos: %', r;
  end if;
  if exists (select 1 from public.panel_retention_guard('moments', 'control', '2026-11-01 00:00+00')
             where verdict not in ('control', 'pocos_datos')) then
    raise exception 'moments, con una sola instalación por brazo, no debía dar otra cosa que pocos_datos';
  end if;
  raise notice 'OK apagar gana aunque el otro horizonte no tenga datos; bajo el mínimo no hay veredicto';
end $$;

-- Sólo service_role las ejecuta: anon y authenticated no.
set local role anon;
do $$
begin
  begin
    perform public.panel_bandit_priors('v1');
    raise exception 'anon pudo ejecutar panel_bandit_priors';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform public.panel_retention_guard('vej', 'rules');
    raise exception 'anon pudo ejecutar panel_retention_guard';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'OK anon no ejecuta los guardianes';
end $$;
reset role;

set local role authenticated;
do $$
begin
  begin
    perform public.panel_bandit_priors('v1');
    raise exception 'authenticated pudo ejecutar panel_bandit_priors';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform public.panel_retention_guard('vej', 'rules');
    raise exception 'authenticated pudo ejecutar panel_retention_guard';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'OK authenticated no ejecuta los guardianes';
end $$;
reset role;

set local role service_role;
do $$
begin
  if (select count(*) from public.panel_bandit_priors('v1')) <> 4
     or (select count(*) from public.panel_retention_guard('vej', 'rules', '2026-11-01 00:00+00')) <> 4 then
    raise exception 'service_role no ve lo mismo que postgres';
  end if;
  raise notice 'OK service_role ejecuta los dos y ve los mismos brazos';
end $$;
reset role;

rollback;
