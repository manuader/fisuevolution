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

-- 7) Cambiar el piso de tiempo real para llegar a Dios (segundos; 36000 = 10 h).
update settings set value = to_jsonb(36000) where key = 'min_real_seconds_to_god';

-- 8) El interruptor del ranking: false apaga las cuatro funciones de la app (responden 503).
update settings set value = 'false'::jsonb where key = 'ranking_enabled';
update settings set value = 'true'::jsonb where key = 'ranking_enabled';

-- 9) El estado del cron (corridas de los últimos 2 días).
select jobname, status, return_message, start_time
from cron.job_run_details d join cron.job j using (jobid)
where j.jobname = 'ranking-remoderate' and start_time > now() - interval '2 days'
order by start_time desc limit 20;
