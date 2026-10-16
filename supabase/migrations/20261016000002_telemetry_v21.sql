-- La telemetría de la 2.1 (E15 F1 T6, contrato C6; R4): tres eventos nuevos y una clave opcional en offer.
-- No toca la de F0 (…20261015000001): reemplaza sus dos checks por los ampliados. Lo demás (la política, los
-- permisos de anon, el interruptor, la retención) queda igual.
--   segment  {id, ver, src}               el segmento de valor, sólo al cambiar
--   exposure {exp, arm, ver}              el jugador vio un brazo de un experimento (F3, F6)
--   progress {max_tier, active_minutes, prestige}   junto con cada session_end (ritmo real, F7)
--   offer    + ctx opcional               el momento de necesidad que sacó la oferta (F3)
-- OJO al aplicar: la app 2.1 manda progress con cada session_end aunque la personalización esté apagada. Esta
-- migración va ANTES que el binario 2.1 con la telemetría prendida: sin ella, el lote entero vuelve 400 y se pierde.
alter table public.telemetry_events drop constraint telemetry_events_name_check;
alter table public.telemetry_events add constraint telemetry_events_name_check check (name in (
  'session_start', 'session_end', 'ad_impression', 'offer', 'purchase', 'prestige',
  'segment', 'exposure', 'progress'));

-- Las claves de props por evento (C4 + C6): las mismas, todas presentes (source y ctx son opcionales), cada una
-- con su tipo y su largo. Los de F0 quedan como estaban, salvo ctx en offer.
alter table public.telemetry_events drop constraint telemetry_props_by_name;
alter table public.telemetry_events add constraint telemetry_props_by_name check (coalesce(case name
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
    props - array['site', 'stage', 'ctx'] = '{}'::jsonb
    and jsonb_typeof(props -> 'site') = 'string' and char_length(props ->> 'site') <= 64
    and jsonb_typeof(props -> 'stage') = 'string' and char_length(props ->> 'stage') <= 32
    and (not props ? 'ctx'
         or (jsonb_typeof(props -> 'ctx') = 'string'
             and (props ->> 'ctx') in ('floor_full', 'price_wall', 'mattress_ready', 'back_offline')))
  when 'purchase' then
    props - 'product' = '{}'::jsonb
    and jsonb_typeof(props -> 'product') = 'string' and char_length(props ->> 'product') <= 128
  when 'prestige' then props - 'count' = '{}'::jsonb and jsonb_typeof(props -> 'count') = 'number'
  when 'segment' then
    props - array['id', 'ver', 'src'] = '{}'::jsonb
    and jsonb_typeof(props -> 'id') = 'string' and (props ->> 'id') in ('base', 'low', 'mid', 'high')
    and jsonb_typeof(props -> 'ver') = 'string' and char_length(props ->> 'ver') <= 32
    and jsonb_typeof(props -> 'src') = 'string' and char_length(props ->> 'src') <= 32
  when 'exposure' then
    props - array['exp', 'arm', 'ver'] = '{}'::jsonb
    and jsonb_typeof(props -> 'exp') = 'string' and char_length(props ->> 'exp') <= 32
    and jsonb_typeof(props -> 'arm') = 'string' and char_length(props ->> 'arm') <= 32
    and jsonb_typeof(props -> 'ver') = 'string' and char_length(props ->> 'ver') <= 32
  when 'progress' then
    props - array['max_tier', 'active_minutes', 'prestige'] = '{}'::jsonb
    and jsonb_typeof(props -> 'max_tier') = 'number' and (props -> 'max_tier') >= '0'::jsonb
    and jsonb_typeof(props -> 'active_minutes') = 'number' and (props -> 'active_minutes') >= '0'::jsonb
    and jsonb_typeof(props -> 'prestige') = 'number' and (props -> 'prestige') >= '0'::jsonb
end, false));
