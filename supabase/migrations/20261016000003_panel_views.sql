-- El panel de valor por jugador (2.1 E15 F7 T1; R4, R6): cuatro vistas sobre la telemetría, de lectura sólo para
-- service_role (como admin.sql). security_invoker: la vista lee con los permisos de quien la consulta, y anon y
-- authenticated no leen ni la vista ni la tabla. Necesita …20261016000002_telemetry_v21.sql (segment, exposure,
-- progress y ctx en offer).
-- Las mismas reglas que admin.sql (19/20) y que los guardianes de F7 T3 (…000004):
--   · el día es received_at en UTC (la hora del servidor, no la del teléfono);
--   · el segmento de una instalación en un momento es el último `segment` que mandó hasta ahí; sin ninguno,
--     «sin_dato» (2.0, sin consentimiento o con la personalización apagada: juegan la base);
--   · en la retención por brazo cuenta cada (instalación, brazo) que vio: día 0 = su primer `exposure` a ese brazo
--     (en vej el balde es estable y da uno solo; en moments el bandido elige por momento y pueden ser varios);
--   · D1/D7: algún session_start el día 0 + 1 / + 7; sólo cuentan las cohortes maduras (día 0 + N < hoy UTC).
-- Los build de desarrollo entran igual: filtrar por app_version como en admin.sql si hace falta.

-- Ingreso por instalación-día por segmento, país y formato. Las instalaciones son las activas del día en ese
-- segmento y país (con cualquier evento), así que las que no vieron un video cuentan con 0. Una moneda por fila;
-- un segmento-país-día sin impresiones sale con formato y moneda vacíos e ingreso 0.
create view public.panel_value_daily with (security_invoker = on) as
with activas as (
  select install_id, (received_at at time zone 'UTC')::date as dia, coalesce(max(storefront), 'sin_dato') as pais
  from public.telemetry_events
  group by 1, 2
),
con_segmento as (
  select a.install_id, a.dia, a.pais, coalesce(s.id, 'sin_dato') as segmento
  from activas a
  left join lateral (
    select e.props ->> 'id' as id
    from public.telemetry_events e
    where e.name = 'segment' and e.install_id = a.install_id
      and e.received_at < (a.dia + 1)::timestamp at time zone 'UTC'
    order by e.received_at desc
    limit 1
  ) s on true
),
impresiones as (
  select install_id, (received_at at time zone 'UTC')::date as dia, props ->> 'format' as formato,
         props ->> 'currency' as moneda, count(*) as impresiones, sum((props ->> 'micros')::numeric) as micros
  from public.telemetry_events
  where name = 'ad_impression'
  group by 1, 2, 3, 4
),
instalaciones as (
  select dia, segmento, pais, count(*) as instalaciones from con_segmento group by 1, 2, 3
),
por_formato as (
  select c.dia, c.segmento, c.pais, i.formato, i.moneda, sum(i.impresiones) as impresiones, sum(i.micros) as micros
  from con_segmento c join impresiones i using (install_id, dia)
  group by 1, 2, 3, 4, 5
)
select n.dia, n.segmento, n.pais, f.formato, f.moneda, n.instalaciones,
       coalesce(f.impresiones, 0) as impresiones,
       coalesce(f.micros, 0) as micros,
       round(coalesce(f.micros, 0) / 1e6, 6) as ingreso,
       round(coalesce(f.micros, 0) / 1e6 / n.instalaciones, 6) as ingreso_por_instalacion_dia
from instalaciones n
left join por_formato f using (dia, segmento, pais);

-- El embudo de las ofertas por día, site, ctx y brazo. Cada offer cuenta una vez en la fila total (exp, arm y ver
-- vacíos) y una vez por cada experimento al que estuvo expuesta su sesión: el (exp, arm, ver) del último exposure de
-- ese exp en la misma sesión hasta la oferta. En `moments` (el bandido de F3) sólo cuenta el site `moment.<arm>`
-- del brazo expuesto. aceptacion = aceptadas / mostradas, completado = completadas / aceptadas,
-- conversion = completadas / mostradas (vacías sin denominador).
create view public.panel_offer_funnel with (security_invoker = on) as
with ofertas as (
  select o.id, o.session_id, o.received_at, (o.received_at at time zone 'UTC')::date as dia,
         o.props ->> 'site' as site, o.props ->> 'ctx' as ctx, o.props ->> 'stage' as stage
  from public.telemetry_events o
  where o.name = 'offer'
),
atribuidas as (
  select o.dia, o.site, o.ctx, null::text as exp, null::text as arm, null::text as ver, o.stage
  from ofertas o
  union all
  select o.dia, o.site, o.ctx, x.exp, x.arm, x.ver, o.stage
  from ofertas o
  join lateral (
    select distinct on (e.props ->> 'exp') e.props ->> 'exp' as exp, e.props ->> 'arm' as arm,
           e.props ->> 'ver' as ver
    from public.telemetry_events e
    where e.name = 'exposure' and e.session_id = o.session_id and e.received_at <= o.received_at
    order by e.props ->> 'exp', e.received_at desc
  ) x on x.exp <> 'moments' or o.site = 'moment.' || x.arm
),
contadas as (
  select dia, site, ctx, exp, arm, ver,
         count(*) filter (where stage = 'shown') as mostradas,
         count(*) filter (where stage = 'accepted') as aceptadas,
         count(*) filter (where stage = 'completed') as completadas,
         count(*) filter (where stage = 'unfilled') as sin_video,
         count(*) filter (where stage = 'dismissed') as descartadas
  from atribuidas
  group by 1, 2, 3, 4, 5, 6
)
select dia, site, ctx, exp, arm, ver, mostradas, aceptadas, completadas, sin_video, descartadas,
       round(aceptadas::numeric / nullif(mostradas, 0), 4) as aceptacion,
       round(completadas::numeric / nullif(aceptadas, 0), 4) as completado,
       round(completadas::numeric / nullif(mostradas, 0), 4) as conversion
from contadas;

-- La retención D1/D7 por cohorte, segmento y brazo. Las filas con exp y arm vacíos son las cohortes de instalación
-- (día 0 = el del primer session_start); las otras, una por brazo de cada experimento: la instalación cuenta en
-- cada brazo que vio, con día 0 = su primer exposure a ese brazo. El segmento es el de la instalación al cierre
-- del día 0.
-- d1 / d7 = retenidas / elegibles; elegibles = las instalaciones de cohortes ya maduras para ese día.
create view public.panel_retention with (security_invoker = on) as
with hoy as (
  select (now() at time zone 'UTC')::date as dia
),
sesiones as (
  select distinct install_id, (received_at at time zone 'UTC')::date as dia
  from public.telemetry_events
  where name = 'session_start'
),
cohortes as (
  select install_id, null::text as exp, null::text as arm, min(dia) as dia0
  from sesiones
  group by 1
  union all
  (select distinct on (install_id, props ->> 'exp', props ->> 'arm')
          install_id, props ->> 'exp', props ->> 'arm', (received_at at time zone 'UTC')::date
   from public.telemetry_events
   where name = 'exposure'
   order by install_id, props ->> 'exp', props ->> 'arm', received_at)
),
marcadas as (
  select c.dia0, coalesce(s.id, 'sin_dato') as segmento, c.exp, c.arm,
         c.dia0 + 1 < h.dia as d1_madura,
         c.dia0 + 7 < h.dia as d7_madura,
         exists (select 1 from sesiones v where v.install_id = c.install_id and v.dia = c.dia0 + 1) as volvio_d1,
         exists (select 1 from sesiones v where v.install_id = c.install_id and v.dia = c.dia0 + 7) as volvio_d7
  from cohortes c
  cross join hoy h
  left join lateral (
    select e.props ->> 'id' as id
    from public.telemetry_events e
    where e.name = 'segment' and e.install_id = c.install_id
      and e.received_at < (c.dia0 + 1)::timestamp at time zone 'UTC'
    order by e.received_at desc
    limit 1
  ) s on true
),
contadas as (
  select dia0, segmento, exp, arm, count(*) as instalaciones,
         count(*) filter (where d1_madura) as d1_elegibles,
         count(*) filter (where d1_madura and volvio_d1) as d1_retenidas,
         count(*) filter (where d7_madura) as d7_elegibles,
         count(*) filter (where d7_madura and volvio_d7) as d7_retenidas
  from marcadas
  group by 1, 2, 3, 4
)
select dia0, segmento, exp, arm, instalaciones,
       d1_elegibles, d1_retenidas, round(d1_retenidas::numeric / nullif(d1_elegibles, 0), 4) as d1,
       d7_elegibles, d7_retenidas, round(d7_retenidas::numeric / nullif(d7_elegibles, 0), 4) as d7
from contadas;

-- El ritmo real (de `progress`): las horas activas de la partida hasta llegar a cada tier, por segmento y por
-- reencarnación (el tier vuelve a 1 al reencarnar; los minutos son de toda la partida), para comparar con
-- pacing-sim. Una instalación llega a un tier en el primer progress (menos minutos) con max_tier ≥ ese tier y
-- ese prestige; su segmento es el de ese momento. El tier se recorta a 64 (el juego tiene menos): un max_tier
-- absurdo no infla la vista.
create view public.panel_pacing with (security_invoker = on) as
with progresos as (
  select p.install_id, p.received_at, (p.props ->> 'prestige')::numeric as prestige,
         least((p.props ->> 'max_tier')::numeric, 64)::integer as max_tier,
         (p.props ->> 'active_minutes')::numeric as minutos
  from public.telemetry_events p
  where p.name = 'progress'
),
llegadas as (
  select distinct on (p.install_id, p.prestige, t.tier)
         p.install_id, p.received_at, p.prestige, t.tier, p.minutos
  from progresos p
  cross join lateral generate_series(1, p.max_tier) as t(tier)
  order by p.install_id, p.prestige, t.tier, p.minutos, p.received_at
),
con_segmento as (
  select l.*, coalesce(s.id, 'sin_dato') as segmento
  from llegadas l
  left join lateral (
    select e.props ->> 'id' as id
    from public.telemetry_events e
    where e.name = 'segment' and e.install_id = l.install_id and e.received_at <= l.received_at
    order by e.received_at desc
    limit 1
  ) s on true
)
select segmento, prestige, tier, count(*) as instalaciones,
       round((percentile_cont(0.25) within group (order by minutos) / 60)::numeric, 2) as horas_p25,
       round((percentile_cont(0.50) within group (order by minutos) / 60)::numeric, 2) as horas_p50,
       round((percentile_cont(0.75) within group (order by minutos) / 60)::numeric, 2) as horas_p75
from con_segmento
group by 1, 2, 3;

revoke all on public.panel_value_daily, public.panel_offer_funnel, public.panel_retention, public.panel_pacing
  from public, anon, authenticated;
grant select on public.panel_value_daily, public.panel_offer_funnel, public.panel_retention, public.panel_pacing
  to service_role;
