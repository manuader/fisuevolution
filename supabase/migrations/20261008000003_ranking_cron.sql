-- requires: pg_cron
-- El reintento de los nombres pendientes: cada 15 minutos el cron llama a la función
-- remoderate. La URL del proyecto y el secreto viven en el Vault (ver supabase/README.md).
-- En local se saltea; se prueba en el despliegue real.
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'ranking-remoderate',
  '*/15 * * * *',
  $$ select net.http_post(
       url := (select decrypted_secret from vault.decrypted_secrets where name = 'ranking_project_url')
              || '/functions/v1/remoderate',
       headers := jsonb_build_object(
         'Authorization',
         'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'ranking_remoderate_secret'))
     ) $$
);
