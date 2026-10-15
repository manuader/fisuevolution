-- requires: pg_cron
-- La retención de la telemetría: una vez por día se borra lo recibido hace más de 400 días
-- (un año y un mes, para comparar contra el mismo mes del año anterior).
-- En local se saltea; se prueba en el despliegue real.
create extension if not exists pg_cron;

select cron.schedule(
  'telemetry-retention',
  '17 4 * * *',
  $$ select public.cleanup_telemetry(now()) $$
);
