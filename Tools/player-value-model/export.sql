-- Export para entrenar el valor por jugador (F6-T4). Lo corre el DUEÑO con service_role (psql),
-- contra la telemetría de la 2.x; el resultado va a un CSV LOCAL que lee train.py.
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f export.sql --csv > export.csv
-- Un renglón por instalación, SIN install_id (no hace falta para entrenar ni se debe sacar).
-- Features = los primeros 7 días desde la primera aparición; etiqueta = ingreso de publicidad de los días 8-37
-- (día 7 inclusive hasta el 36). Sólo instalaciones con 37 días completos (la etiqueta no se corta).
with first_seen as (
  select install_id, min(received_at) as t0
  from public.telemetry_events group by install_id
  having min(received_at) <= now() - interval '37 days'
), ev as (
  select e.*, f.t0, e.received_at - f.t0 as age
  from public.telemetry_events e join first_seen f using (install_id)
)
select
  (t0 at time zone 'UTC')::date                                                        as cohort_day,
  (array_agg(storefront order by received_at desc) filter (where storefront is not null))[1] as storefront,
  (array_agg(device_model order by received_at desc))[1]                               as device_model,
  count(*) filter (where name = 'session_start' and age < interval '7 days')           as sessions_7d,
  avg((props ->> 'seconds')::numeric) filter (where name = 'session_end' and age < interval '7 days') as mean_session_seconds,
  count(*) filter (where name = 'ad_impression' and props ->> 'format' = 'rewarded' and age < interval '7 days') as rewarded_count,
  avg((props ->> 'micros')::numeric) filter (where name = 'ad_impression' and props ->> 'format' = 'rewarded' and age < interval '7 days') as avg_rewarded_micros,
  (count(*) filter (where name = 'purchase' and age < interval '7 days') > 0)::int      as has_purchased,
  count(*) filter (where name = 'offer' and age < interval '7 days')                    as offers_seen,
  count(*) filter (where name = 'prestige' and age < interval '7 days')                 as prestige_count,
  -- micros de la moneda del anuncio; USD si la cuenta de AdMob es USD (verificar antes de entrenar)
  coalesce(sum((props ->> 'micros')::numeric) filter (where name = 'ad_impression'
           and age >= interval '7 days' and age < interval '37 days'), 0) / 1000000.0   as revenue_usd
from ev
group by install_id, t0;
