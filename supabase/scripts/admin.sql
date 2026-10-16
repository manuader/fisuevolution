-- Consultas del dueño, para el SQL editor del panel de Supabase. Se corren de a una.

-- 1) La cola de review: partidas que llegaron a Dios en menos del piso (tiempo sospechoso).
select r.id as run_id, r.name, r.name_status, r.real_seconds,
       round(r.real_seconds / 3600.0, 1) as horas_reales,
       round(r.played_seconds / 3600.0, 1) as horas_jugadas,
       r.finished_at, r.app_version
from runs r
where r.status = 'review'
order by r.finished_at;

-- 2) Los nombres con 3 o más reportes (el umbral vive en settings.reports_to_hide).
select r.id as run_id, r.name, r.name_status, r.status, count(x.*) as reportes,
       round(r.real_seconds / 3600.0, 1) as horas_reales
from runs r
join reports x on x.run_id = r.id
group by r.id
having count(x.*) >= 3
order by reportes desc;

-- 3) Nombres que la moderación todavía no resolvió (pending), con sus intentos.
select id as run_id, name, moderation_attempts, name_updated_at
from runs
where name_status = 'pending'
order by name_updated_at;

-- 4) Aprobar una partida en review (pasa a finished y entra al ranking).
select approve_run('<run_id>');

-- 5) Ocultar una partida (sale del ranking para siempre).
select hide_run('<run_id>');

-- 6) Perdonar los reportes de una partida.
select clear_reports('<run_id>');

-- 7) Cambiar el piso de tiempo real para llegar a Dios (segundos; 54675 = 15,2 h, la mitad del .max).
update settings set value = to_jsonb(54675) where key = 'min_real_seconds_to_god';

-- 8) El interruptor del ranking: false apaga las cuatro funciones de la app (responden 503).
update settings set value = 'false'::jsonb where key = 'ranking_enabled';
update settings set value = 'true'::jsonb where key = 'ranking_enabled';

-- 9) El estado del cron (corridas de los últimos 2 días).
select jobname, status, return_message, start_time
from cron.job_run_details d join cron.job j using (jobid)
where j.jobname = 'ranking-remoderate' and start_time > now() - interval '2 days'
order by start_time desc limit 20;

-- ── Telemetría (E15) ────────────────────────────────────────────────────────────────────────
-- Anónima: install_id es el UUID de instalación de la app (no el IDFA). Se guarda 400 días.
-- OJO: un build de DEBUG con --telemetry-debug escribe en ESTA tabla (producción). Para las cifras
-- reales, filtrar los build de desarrollo: `and build <> '<build de prueba>'` en cada consulta.

-- 10) El interruptor de la telemetría. Arranca en false. Prenderlo SÓLO con la política de
--     privacidad, los términos y la etiqueta de App Store Connect ya actualizados (🔒 O6).
--     Apagar (la que se corre por defecto):
update settings set value = 'false'::jsonb where key = 'telemetry_enabled';
--     Prender (descomentar a mano, nunca de pasada):
-- update settings set value = 'true'::jsonb where key = 'telemetry_enabled';

-- 11) Impresiones y eCPM por país × formato (últimos 30 días). eCPM = valor medio × 1000.
--     Cada moneda sale en su fila (la moneda es parte del agrupamiento): los importes no se suman
--     entre monedas. AdMob informa en la moneda de la cuenta, así que en la práctica hay una sola.
select coalesce(storefront, '???') as pais,
       props ->> 'format' as formato,
       props ->> 'currency' as moneda,
       count(*) as impresiones,
       round(sum((props ->> 'micros')::bigint) / 1e6, 2) as ingreso,
       round(avg((props ->> 'micros')::bigint) / 1e3, 2) as ecpm
from telemetry_events
where name = 'ad_impression' and received_at > now() - interval '30 days'
group by 1, 2, 3
order by impresiones desc;

-- 12) El embudo por lugar (últimos 30 días): mostrado → aceptado → completado; sin video y descartado.
select props ->> 'site' as lugar,
       count(*) filter (where props ->> 'stage' = 'shown') as mostrado,
       count(*) filter (where props ->> 'stage' = 'accepted') as aceptado,
       count(*) filter (where props ->> 'stage' = 'completed') as completado,
       count(*) filter (where props ->> 'stage' = 'unfilled') as sin_video,
       count(*) filter (where props ->> 'stage' = 'dismissed') as descartado,
       round(100.0 * count(*) filter (where props ->> 'stage' = 'completed')
             / nullif(count(*) filter (where props ->> 'stage' = 'shown'), 0), 1) as conversion_pct
from telemetry_events
where name = 'offer' and received_at > now() - interval '30 days'
group by 1
order by mostrado desc;

-- 13) Sesiones por día (últimos 60 días) y su duración mediana.
select date_trunc('day', received_at)::date as dia,
       count(*) filter (where name = 'session_start') as sesiones,
       percentile_cont(0.5) within group (order by (props ->> 'seconds')::int)
         filter (where name = 'session_end') as mediana_segundos
from telemetry_events
where name in ('session_start', 'session_end') and received_at > now() - interval '60 days'
group by 1
order by 1 desc;

-- 14) Instalaciones activas por día (últimos 60 días).
select date_trunc('day', received_at)::date as dia,
       count(distinct install_id) as instalaciones_activas
from telemetry_events
where received_at > now() - interval '60 days'
group by 1
order by 1 desc;

-- 15) El estado del cron de retención (corridas de los últimos 7 días).
select jobname, status, return_message, start_time
from cron.job_run_details d join cron.job j using (jobid)
where j.jobname = 'telemetry-retention' and start_time > now() - interval '7 days'
order by start_time desc limit 10;

-- ── Personalización (2.1, E15 F1) ───────────────────────────────────────────────────────────
-- La app pide personalization_config(): con el interruptor apagado recibe null y todos juegan la base.
-- Arranca apagado. Prenderlo SÓLO con la privacidad de la 2.1 aprobada (E15 F1 T9) y una config validada.

-- 16) El interruptor de la personalización. Apagar (la que se corre por defecto; todos vuelven a la base):
update settings set value = 'false'::jsonb where key = 'personalization_enabled';
--     Prender (descomentar a mano, nunca de pasada):
-- update settings set value = 'true'::jsonb where key = 'personalization_enabled';

-- 17) Cargar una config. ANTES validarla con pacing-sim (la base de 45 h igual para todos) y con los tests de las
--     tablas: la app descarta una sección que no valida, pero una que valida y está mal cambia el juego de verdad.
--     Subir "version" en cada carga. Tope: 64 KB (si pasa, la función devuelve null).
--     (descomentar a mano y pegar el JSON entre los $json$)
-- update settings set value = $json$
-- { "version": 1, "sections": { "player_value": { … } } }
-- $json$::jsonb where key = 'personalization_config';

-- 18) Leer el interruptor y la config cargada (su versión, sus secciones y su tamaño).
select key, value -> 'version' as version,
       (select array_agg(s order by s) from jsonb_object_keys(value -> 'sections') s) as secciones,
       octet_length(value::text) as bytes
from settings where key = 'personalization_config'
union all
select key, value, null, null from settings where key = 'personalization_enabled';

-- ── Telemetría de la 2.1 (E15 F1 T6) ────────────────────────────────────────────────────────
-- Necesita …20261016000002_telemetry_v21.sql aplicada (segment, exposure, progress y ctx en offer).
-- El segmento de una instalación en un día es el último `segment` que mandó hasta el fin de ese día; sin ninguno,
-- «sin_dato» (instalaciones de la 2.0, o sin consentimiento o con la personalización apagada: juegan la base).
-- Mismo cuidado que arriba con los build de desarrollo.

-- 19) Ingreso por instalación-día por segmento (últimos 30 días). Las instalaciones son las activas del día (con
--     cualquier evento), así que las que no vieron un video cuentan con 0. Una moneda por fila, como la 11; un
--     segmento-día sin impresiones sale con moneda vacía e ingreso 0.
with activas as (
  select install_id, date_trunc('day', received_at)::date as dia
  from telemetry_events
  where received_at > now() - interval '30 days'
  group by 1, 2
),
con_segmento as (
  select a.install_id, a.dia, coalesce(s.id, 'sin_dato') as segmento
  from activas a
  left join lateral (
    select e.props ->> 'id' as id
    from telemetry_events e
    where e.name = 'segment' and e.install_id = a.install_id and e.received_at < a.dia + interval '1 day'
    order by e.received_at desc
    limit 1
  ) s on true
),
ingresos as (
  select install_id, date_trunc('day', received_at)::date as dia, props ->> 'currency' as moneda,
         sum((props ->> 'micros')::bigint) as micros
  from telemetry_events
  where name = 'ad_impression' and received_at > now() - interval '30 days'
  group by 1, 2, 3
),
por_segmento as (
  select dia, segmento, count(*) as instalaciones from con_segmento group by 1, 2
),
ingreso_por_segmento as (
  select c.dia, c.segmento, i.moneda, sum(i.micros) as micros
  from con_segmento c join ingresos i using (install_id, dia)
  group by 1, 2, 3
)
select p.dia, p.segmento, p.instalaciones, g.moneda,
       round(coalesce(g.micros, 0) / 1e6, 2) as ingreso,
       round(coalesce(g.micros, 0) / 1e6 / p.instalaciones, 4) as ingreso_por_instalacion_dia
from por_segmento p
left join ingreso_por_segmento g using (dia, segmento)
order by p.dia desc, p.segmento, g.moneda;

-- 20) El reparto de segmentos por día (últimos 30 días): instalaciones activas en cada uno y su porcentaje.
with activas as (
  select install_id, date_trunc('day', received_at)::date as dia
  from telemetry_events
  where received_at > now() - interval '30 days'
  group by 1, 2
),
con_segmento as (
  select a.install_id, a.dia, coalesce(s.id, 'sin_dato') as segmento
  from activas a
  left join lateral (
    select e.props ->> 'id' as id
    from telemetry_events e
    where e.name = 'segment' and e.install_id = a.install_id and e.received_at < a.dia + interval '1 day'
    order by e.received_at desc
    limit 1
  ) s on true
)
select dia, segmento, count(*) as instalaciones,
       round(100.0 * count(*) / sum(count(*)) over (partition by dia), 1) as pct
from con_segmento
group by 1, 2
order by 1 desc, 2;
