-- Los guardianes del panel de la 2.1 (E15 F7 T3; R6): los priors del bandido y el límite de retención por brazo.
-- SÓLO INFORMAN: no escriben nada. Pegar los priors o apagar un brazo es editar la config a mano (🔒 P4/P5).
-- Leen telemetry_events directo (no dependen de las vistas de …000003). Security definer con search_path fijo, como
-- todas las de public (02_rls_test), y sólo service_role las ejecuta.
--
-- Cómo se cuenta:
--   - Una sesión «vio» un brazo de un experimento si mandó exposure {exp, arm, ver} (F3-T5: una vez por sesión y
--     brazo; F6: exp = 'vej').
--   - El embudo de un brazo de moments = los offer con site 'moment.<arm>' de las sesiones que lo vieron.
--   - La retención de un brazo = las instalaciones que lo vieron, con día 0 = el día (UTC) de su primera exposición
--     a ESE brazo; D1/D7 = volvió a abrir (session_start) justo ese día + 1 / + 7. Una cohorte cuenta sólo cuando su
--     día ya terminó (día 0 + N antes del día de p_as_of). En moments el bandido elige por momento: una instalación
--     puede caer en varios brazos y cuenta en cada uno (la comparación es contra quien vio el control, no un A/B
--     puro). En vej el balde es estable: cada instalación cae en uno solo.

-- Los priors Beta por brazo para la sección moments de la config: α = 1 + completadas, β = 1 + mostradas −
-- completadas. Con más de p_cap pseudo-cuentas se escalan las dos a p_cap (se conserva la media): el teléfono
-- sigue aprendiendo encima en vez de quedar congelado por un prior enorme.
create function public.panel_bandit_priors(p_version text, p_cap integer default 200)
returns table (arm text, shown bigint, completed bigint, alpha numeric, beta numeric)
language sql stable security definer set search_path = '' as $$
  with exposed as (
    select distinct e.session_id, e.props ->> 'arm' as arm
    from public.telemetry_events e
    where e.name = 'exposure' and e.props ->> 'exp' = 'moments' and e.props ->> 'ver' = p_version
  ), funnel as (
    select x.arm,
      count(o.id) filter (where o.props ->> 'stage' = 'shown') as shown,
      count(o.id) filter (where o.props ->> 'stage' = 'completed') as completed
    from exposed x
    left join public.telemetry_events o
      on o.name = 'offer' and o.session_id = x.session_id and o.props ->> 'site' = 'moment.' || x.arm
    group by x.arm
  ), counts as (
    select f.arm, f.shown, f.completed,
      least(f.completed, f.shown) as wins,
      f.shown - least(f.completed, f.shown) as losses
    from funnel f
  ), scaled as (
    select c.*,
      case when c.shown > greatest(p_cap, 0) then greatest(p_cap, 0)::numeric / c.shown else 1 end as k
    from counts c
  )
  select s.arm, s.shown, s.completed,
    round(1 + s.wins * s.k, 4) as alpha,
    round(1 + s.losses * s.k, 4) as beta
  from scaled s
  order by s.arm
$$;

-- El límite de retención de R6 por brazo de un experimento: D1 y D7 contra el control, con la diferencia y su
-- intervalo de 95 % (aproximación normal de dos proporciones). verdict:
--   'control'      el brazo de referencia;
--   'apagar'       en D1 o en D7 es peor que el control por más de 1 punto (diferencia < −0,01) y con significancia
--                  (el intervalo entero queda abajo de 0);
--   'pocos_datos'  a D1 o a D7 le faltan p_min_n instalaciones maduras en el brazo o en el control;
--   'ok'           ninguna de las anteriores.
-- p_control: 'control' en moments, 'rules' en vej.
create function public.panel_retention_guard(
  p_exp text,
  p_control text default 'control',
  p_as_of timestamptz default now(),
  p_min_n integer default 100
)
returns table (
  arm text,
  d1_n bigint, d1_rate numeric, d1_diff numeric, d1_lo numeric, d1_hi numeric,
  d7_n bigint, d7_rate numeric, d7_diff numeric, d7_lo numeric, d7_hi numeric,
  verdict text
)
language sql stable security definer set search_path = '' as $$
  with first_seen as (
    select e.install_id, e.props ->> 'arm' as arm, min((e.received_at at time zone 'UTC')::date) as day0
    from public.telemetry_events e
    where e.name = 'exposure' and e.props ->> 'exp' = p_exp
    group by e.install_id, e.props ->> 'arm'
  ), starts as (
    select distinct s.install_id, (s.received_at at time zone 'UTC')::date as day
    from public.telemetry_events s
    where s.name = 'session_start'
  ), cohort as (
    select f.arm,
      count(*) filter (where f.day0 + 1 < (p_as_of at time zone 'UTC')::date) as d1_n,
      count(*) filter (where f.day0 + 1 < (p_as_of at time zone 'UTC')::date
        and exists (select 1 from starts s where s.install_id = f.install_id and s.day = f.day0 + 1)) as d1_k,
      count(*) filter (where f.day0 + 7 < (p_as_of at time zone 'UTC')::date) as d7_n,
      count(*) filter (where f.day0 + 7 < (p_as_of at time zone 'UTC')::date
        and exists (select 1 from starts s where s.install_id = f.install_id and s.day = f.day0 + 7)) as d7_k
    from first_seen f
    group by f.arm
  ), rates as (
    select c.arm, c.d1_n, c.d7_n,
      c.d1_k::numeric / nullif(c.d1_n, 0) as p1,
      c.d7_k::numeric / nullif(c.d7_n, 0) as p7
    from cohort c
  ), compared as (
    select r.arm, r.d1_n, r.d7_n, r.p1, r.p7,
      r.arm = p_control as is_control,
      coalesce(r.d1_n >= p_min_n and k.d1_n >= p_min_n, false) as d1_enough,
      coalesce(r.d7_n >= p_min_n and k.d7_n >= p_min_n, false) as d7_enough,
      r.p1 - k.p1 as diff1,
      sqrt(r.p1 * (1 - r.p1) / r.d1_n + k.p1 * (1 - k.p1) / k.d1_n) as se1,
      r.p7 - k.p7 as diff7,
      sqrt(r.p7 * (1 - r.p7) / r.d7_n + k.p7 * (1 - k.p7) / k.d7_n) as se7
    from rates r
    left join rates k on k.arm = p_control
  ), flagged as (
    select c.*,
      (c.d1_enough and c.diff1 < -0.01 and c.diff1 + 1.96 * c.se1 < 0)
        or (c.d7_enough and c.diff7 < -0.01 and c.diff7 + 1.96 * c.se7 < 0) as worse
    from compared c
  )
  select f.arm,
    f.d1_n, round(f.p1, 4),
    case when not f.is_control then round(f.diff1, 4) end,
    case when not f.is_control then round(f.diff1 - 1.96 * f.se1, 4) end,
    case when not f.is_control then round(f.diff1 + 1.96 * f.se1, 4) end,
    f.d7_n, round(f.p7, 4),
    case when not f.is_control then round(f.diff7, 4) end,
    case when not f.is_control then round(f.diff7 - 1.96 * f.se7, 4) end,
    case when not f.is_control then round(f.diff7 + 1.96 * f.se7, 4) end,
    case
      when f.is_control then 'control'
      when f.worse then 'apagar'
      when not (f.d1_enough and f.d7_enough) then 'pocos_datos'
      else 'ok'
    end
  from flagged f
  order by f.is_control desc, f.arm
$$;

revoke execute on function public.panel_bandit_priors(text, integer) from public, anon, authenticated;
grant execute on function public.panel_bandit_priors(text, integer) to service_role;
revoke execute on function public.panel_retention_guard(text, text, timestamptz, integer)
  from public, anon, authenticated;
grant execute on function public.panel_retention_guard(text, text, timestamptz, integer) to service_role;
