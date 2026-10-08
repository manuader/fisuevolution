set client_min_messages = notice;
begin;

create function pg_temp.h(seed text) returns text language sql immutable
  as $$ select encode(sha256(convert_to(seed, 'UTF8')), 'hex') $$;

set local role service_role;

do $$
declare
  s record;
  f record;
  r public.runs;
begin
  select * into s from public.start_run(pg_temp.h('reloj'), '2.0.0', '2026-10-08 10:00Z');
  if s.started_at <> '2026-10-08 10:00Z'::timestamptz then
    raise exception 'started_at no es el del servidor: %', s.started_at;
  end if;
  select * into f from public.finish_run(pg_temp.h('reloj'), s.run_id, 200000, '2026-10-09 18:14Z');
  select * into r from public.runs where id = s.run_id;
  if f.real_seconds <> 116040 or r.real_seconds <> 116040 or r.played_seconds <> 116040 then
    raise exception 'tiempos: real % / % jugado %', f.real_seconds, r.real_seconds, r.played_seconds;
  end if;
  if f.status <> 'finished' or r.finished_at <> '2026-10-09 18:14Z'::timestamptz then
    raise exception 'el sello no quedó: % %', f.status, r.finished_at;
  end if;
  select * into s from public.start_run(pg_temp.h('reloj'), '2.0.0', '2026-10-10 10:00Z');
  perform public.finish_run(pg_temp.h('reloj'), s.run_id, 99999, '2026-10-11 18:14Z');
  if (select played_seconds from public.runs where id = s.run_id) <> 99999 then
    raise exception 'un jugado menor al real no se respetó';
  end if;
  raise notice 'OK el tiempo real lo pone el servidor y el jugado se recorta al real';
end $$;

do $$
declare
  first_run uuid;
  second_run uuid;
  player uuid;
begin
  select run_id into first_run from public.start_run(pg_temp.h('doble'), '2.0.0', '2026-10-08 10:00Z');
  select run_id into second_run from public.start_run(pg_temp.h('doble'), '2.0.0', '2026-10-08 11:00Z');
  select id into player from public.players where install_id_hash = pg_temp.h('doble');
  if (select status from public.runs where id = first_run) <> 'abandoned' then
    raise exception 'la primera no quedó abandonada';
  end if;
  if (select count(*) from public.runs where player_id = player and status = 'active') <> 1
     or (select status from public.runs where id = second_run) <> 'active' then
    raise exception 'no hay exactamente una activa';
  end if;
  if (select count(*) from public.players where install_id_hash = pg_temp.h('doble')) <> 1 then
    raise exception 'el jugador se duplicó';
  end if;
  raise notice 'OK una partida activa por jugador: la anterior queda abandonada';
end $$;

do $$
declare
  run uuid;
  f record;
begin
  select run_id into run from public.start_run(pg_temp.h('rapido'), '2.0.0', '2026-10-08 10:00Z');
  select * into f from public.finish_run(pg_temp.h('rapido'), run, 100, '2026-10-08 13:00Z');
  if f.status <> 'review' or f.real_seconds <> 10800 then
    raise exception 'una de 3 h quedó % (%)', f.status, f.real_seconds;
  end if;
  perform public.set_run_name(pg_temp.h('rapido'), run, 'Veloz', 'ok', '2026-10-08 13:01Z');
  if exists (select 1 from public.leaderboard where run_id = run) then
    raise exception 'una partida en review aparece en el ranking';
  end if;
  raise notice 'OK bajo el piso queda en review y no se publica';
end $$;

do $$
declare
  run uuid;
  gone uuid;
begin
  select run_id into run from public.start_run(pg_temp.h('duenio'), '2.0.0', '2026-10-08 10:00Z');
  begin
    perform public.finish_run(pg_temp.h('intruso'), run, 1, '2026-10-09 10:00Z');
    raise exception 'otro jugador pudo sellar la partida';
  exception when sqlstate 'P0403' then
    null;
  end;
  begin
    perform public.finish_run(pg_temp.h('intruso'), gen_random_uuid(), 1, '2026-10-09 10:00Z');
    raise exception 'una partida inexistente no dio not_owner';
  exception when sqlstate 'P0403' then
    null;
  end;
  gone := run;
  perform public.start_run(pg_temp.h('duenio'), '2.0.0', '2026-10-08 11:00Z');
  begin
    perform public.finish_run(pg_temp.h('duenio'), gone, 1, '2026-10-09 10:00Z');
    raise exception 'se pudo sellar una abandonada';
  exception when sqlstate 'P0409' then
    null;
  end;
  if (select status from public.runs where id = gone) <> 'abandoned' then
    raise exception 'la abandonada cambió';
  end if;
  raise notice 'OK una partida ajena da P0403 y una abandonada P0409';
end $$;

do $$
declare
  run uuid;
  a record;
  b record;
begin
  select run_id into run from public.start_run(pg_temp.h('reintento'), '2.0.0', '2026-10-08 10:00Z');
  select * into a from public.finish_run(pg_temp.h('reintento'), run, 50000, '2026-10-09 10:00Z');
  select * into b from public.finish_run(pg_temp.h('reintento'), run, 70000, '2026-10-10 10:00Z');
  if a is distinct from b then
    raise exception 'el reintento cambió el sello: % vs %', a, b;
  end if;
  if (select finished_at from public.runs where id = run) <> '2026-10-09 10:00Z'::timestamptz
     or (select played_seconds from public.runs where id = run) <> 50000 then
    raise exception 'el reintento tocó la fila';
  end if;
  raise notice 'OK sellar dos veces devuelve lo mismo y no toca la partida';
end $$;

do $$
declare
  run uuid;
  n record;
  sealed public.runs;
  after public.runs;
begin
  select run_id into run from public.start_run(pg_temp.h('nombre'), '2.0.0', '2026-10-08 10:00Z');
  perform public.finish_run(pg_temp.h('nombre'), run, 3600, '2026-10-09 10:00Z');
  select * into sealed from public.runs where id = run;

  select * into n from public.set_run_name(pg_temp.h('nombre'), run, 'Juan', 'rejected', '2026-10-09 10:01Z');
  if n.name_status <> 'rejected' or n.rank is not null then
    raise exception 'el rechazo devolvió %', n;
  end if;
  select * into n from public.set_run_name(pg_temp.h('nombre'), run, 'Juana', 'ok', '2026-10-09 10:02Z');
  if n.name_status <> 'ok' or n.rank is null then
    raise exception 'la aprobación devolvió %', n;
  end if;
  select * into after from public.runs where id = run;
  if after.name <> 'Juana' or after.real_seconds <> sealed.real_seconds
     or after.played_seconds <> sealed.played_seconds or after.finished_at <> sealed.finished_at then
    raise exception 'el nombre tocó los tiempos o no quedó: %', after;
  end if;
  if (select last_name from public.players where install_id_hash = pg_temp.h('nombre')) <> 'Juana' then
    raise exception 'last_name no se actualizó';
  end if;

  select * into n from public.set_run_name(pg_temp.h('nombre'), run, 'Otro', 'ok', '2026-10-09 10:03Z');
  if n.name_status <> 'ok' or (select name from public.runs where id = run) <> 'Juana' then
    raise exception 'un nombre aprobado cambió';
  end if;

  begin
    perform public.set_run_name(pg_temp.h('intruso'), run, 'Hack', 'ok', '2026-10-09 10:04Z');
    raise exception 'otro jugador pudo nombrar la partida';
  exception when sqlstate 'P0403' then
    null;
  end;
  raise notice 'OK rechazo y reenvío sobre la misma partida, sin tocar los tiempos ni un nombre aprobado';
end $$;

do $$
declare
  active_run uuid;
  pending_run uuid;
begin
  select run_id into active_run from public.start_run(pg_temp.h('activa'), '2.0.0', '2026-10-08 10:00Z');
  begin
    perform public.set_run_name(pg_temp.h('activa'), active_run, 'Apurado', 'ok', '2026-10-08 10:01Z');
    raise exception 'se nombró una partida sin sellar';
  exception when sqlstate 'P0409' then
    null;
  end;

  select run_id into pending_run from public.start_run(pg_temp.h('pendiente'), '2.0.0', '2026-10-08 10:00Z');
  perform public.finish_run(pg_temp.h('pendiente'), pending_run, 1, '2026-10-09 10:00Z');
  perform public.set_run_name(pg_temp.h('pendiente'), pending_run, 'Lento', 'pending', '2026-10-09 10:01Z');
  perform public.set_run_name(pg_temp.h('pendiente'), pending_run, 'Lento', 'pending', '2026-10-09 10:20Z');
  if (select moderation_attempts from public.runs where id = pending_run) <> 2 then
    raise exception 'moderation_attempts no sumó con pending';
  end if;
  if (select last_name from public.players where install_id_hash = pg_temp.h('pendiente')) is not null then
    raise exception 'un nombre pendiente llegó a last_name';
  end if;
  begin
    perform public.set_run_name(pg_temp.h('pendiente'), pending_run, 'Lento', 'missing', '2026-10-09 10:21Z');
    raise exception 'se aceptó missing como resultado de moderación';
  exception when sqlstate '22023' then
    null;
  end;
  raise notice 'OK sólo se nombra una partida sellada y pending cuenta los intentos';
end $$;

do $$
declare
  fast_run uuid;
  slow_run uuid;
  pending_run uuid;
  missing_run uuid;
  rejected_run uuid;
  row_pending record;
begin
  -- El mismo jugador, dos partidas: la de 20 h y después la de 30 h.
  select run_id into fast_run from public.start_run(pg_temp.h('mejor'), '2.0.0', '2026-10-01 00:00Z');
  perform public.finish_run(pg_temp.h('mejor'), fast_run, 1, '2026-10-01 20:00Z');
  perform public.set_run_name(pg_temp.h('mejor'), fast_run, 'Mejor', 'ok', '2026-10-01 20:01Z');
  select run_id into slow_run from public.start_run(pg_temp.h('mejor'), '2.0.0', '2026-10-02 00:00Z');
  perform public.finish_run(pg_temp.h('mejor'), slow_run, 1, '2026-10-03 06:00Z');
  perform public.set_run_name(pg_temp.h('mejor'), slow_run, 'Mejor', 'ok', '2026-10-03 06:01Z');

  select run_id into pending_run from public.start_run(pg_temp.h('vista-p'), '2.0.0', '2026-10-01 00:00Z');
  perform public.finish_run(pg_temp.h('vista-p'), pending_run, 1, '2026-10-02 00:00Z');
  perform public.set_run_name(pg_temp.h('vista-p'), pending_run, 'Espera', 'pending', '2026-10-02 00:01Z');

  select run_id into missing_run from public.start_run(pg_temp.h('vista-m'), '2.0.0', '2026-10-01 00:00Z');
  perform public.finish_run(pg_temp.h('vista-m'), missing_run, 1, '2026-10-02 00:00Z');

  select run_id into rejected_run from public.start_run(pg_temp.h('vista-r'), '2.0.0', '2026-10-01 00:00Z');
  perform public.finish_run(pg_temp.h('vista-r'), rejected_run, 1, '2026-10-02 00:00Z');
  perform public.set_run_name(pg_temp.h('vista-r'), rejected_run, 'Feo', 'rejected', '2026-10-02 00:01Z');

  if not exists (select 1 from public.leaderboard where run_id = fast_run and display_name = 'Mejor')
     or exists (select 1 from public.leaderboard where run_id = slow_run) then
    raise exception 'del mismo jugador no aparece sólo la mejor';
  end if;
  select * into row_pending from public.leaderboard where run_id = pending_run;
  if not found or row_pending.display_name is not null then
    raise exception 'la pendiente no aparece como Anónimo';
  end if;
  if exists (select 1 from public.leaderboard where run_id in (missing_run, rejected_run)) then
    raise exception 'missing o rejected aparecen en el ranking';
  end if;
  if (select rank from public.leaderboard where run_id = fast_run)
     >= (select rank from public.leaderboard where run_id = pending_run) then
    raise exception 'el orden no es por tiempo real';
  end if;
  raise notice 'OK la vista publica la mejor de cada jugador, pending como Anónimo, sin missing ni rejected';
end $$;

do $$
declare
  run uuid;
begin
  select run_id into run from public.start_run(pg_temp.h('reportado'), '2.0.0', '2026-10-01 00:00Z');
  perform public.finish_run(pg_temp.h('reportado'), run, 1, '2026-10-02 00:00Z');
  perform public.set_run_name(pg_temp.h('reportado'), run, 'Polemico', 'ok', '2026-10-02 00:01Z');

  perform public.report_run(pg_temp.h('reportado'), run, '2026-10-02 01:00Z');
  perform public.report_run(pg_temp.h('rep-1'), run, '2026-10-02 01:00Z');
  perform public.report_run(pg_temp.h('rep-1'), run, '2026-10-02 01:01Z');
  perform public.report_run(pg_temp.h('rep-2'), run, '2026-10-02 01:02Z');
  if (select display_name from public.leaderboard where run_id = run) is distinct from 'Polemico' then
    raise exception 'dos reportes distintos (más uno propio y uno repetido) ya lo ocultaron';
  end if;
  if (select count(*) from public.reports where run_id = run) <> 2 then
    raise exception 'el autorreporte o el repetido contaron';
  end if;
  perform public.report_run(pg_temp.h('rep-3'), run, '2026-10-02 01:03Z');
  if (select display_name from public.leaderboard where run_id = run) is not null then
    raise exception 'con tres reportes el nombre sigue a la vista';
  end if;
  perform public.report_run(pg_temp.h('rep-4'), gen_random_uuid(), '2026-10-02 01:04Z');

  perform public.clear_reports(run);
  if (select display_name from public.leaderboard where run_id = run) is distinct from 'Polemico' then
    raise exception 'clear_reports no devolvió el nombre';
  end if;
  raise notice 'OK tres reportes distintos lo vuelven Anónimo; el propio y el repetido no cuentan';
end $$;

do $$
declare
  i integer;
  limited boolean;
begin
  for i in 1..30 loop
    if public.hit_rate_limit(pg_temp.h('ansioso'), '2026-10-08 10:00Z'::timestamptz + make_interval(secs => i)) then
      raise exception 'la llamada % ya dio límite', i;
    end if;
  end loop;
  limited := public.hit_rate_limit(pg_temp.h('ansioso'), '2026-10-08 10:00:31Z');
  if not limited then
    raise exception 'la llamada 31 no dio límite';
  end if;
  if public.hit_rate_limit(pg_temp.h('otro-ansioso'), '2026-10-08 10:00:32Z') then
    raise exception 'el límite de uno frenó a otro';
  end if;
  if public.hit_rate_limit(pg_temp.h('ansioso'), '2026-10-08 11:01:32Z') then
    raise exception 'a la hora y un minuto sigue limitado';
  end if;
  if (select count(*) from public.api_calls where install_id_hash = pg_temp.h('ansioso')) <> 1 then
    raise exception 'no se limpiaron las llamadas viejas';
  end if;
  raise notice 'OK la llamada 31 de la hora da límite y a la hora y un minuto se libera';
end $$;

do $$
declare
  run uuid;
  hidden_run uuid;
begin
  select run_id into run from public.start_run(pg_temp.h('revisada'), '2.0.0', '2026-10-08 10:00Z');
  perform public.finish_run(pg_temp.h('revisada'), run, 1, '2026-10-08 12:00Z');
  perform public.set_run_name(pg_temp.h('revisada'), run, 'Rapidito', 'ok', '2026-10-08 12:01Z');
  if not public.approve_run(run) then
    raise exception 'approve_run no encontró la review';
  end if;
  if (select status from public.runs where id = run) <> 'finished' then
    raise exception 'approve_run no pasó review a finished';
  end if;
  if not exists (select 1 from public.leaderboard where run_id = run) then
    raise exception 'la aprobada no aparece';
  end if;
  if public.approve_run(run) then
    raise exception 'approve_run aprobó algo que no estaba en review';
  end if;

  select run_id into hidden_run from public.start_run(pg_temp.h('oculta'), '2.0.0', '2026-10-01 00:00Z');
  perform public.finish_run(pg_temp.h('oculta'), hidden_run, 1, '2026-10-02 00:00Z');
  perform public.set_run_name(pg_temp.h('oculta'), hidden_run, 'Oculta', 'ok', '2026-10-02 00:01Z');
  if not public.hide_run(hidden_run) then
    raise exception 'hide_run no encontró la partida';
  end if;
  if exists (select 1 from public.leaderboard where run_id = hidden_run) then
    raise exception 'hide_run no la sacó de la vista';
  end if;
  raise notice 'OK el dueño aprueba una review y oculta una partida';
end $$;

do $$
declare
  run uuid;
  top_row record;
  me record;
  mine_count integer;
  i integer;
  other uuid;
begin
  delete from public.players;
  for i in 1..5 loop
    select run_id into other from public.start_run(pg_temp.h('top-' || i), '2.0.0', '2026-09-01 00:00Z');
    perform public.finish_run(pg_temp.h('top-' || i), other, 1, '2026-09-01 00:00Z'::timestamptz + make_interval(hours => 10 + i));
    perform public.set_run_name(pg_temp.h('top-' || i), other, 'Top' || i, 'ok', '2026-09-03 00:00Z');
  end loop;
  select run_id into run from public.start_run(pg_temp.h('yo'), '2.0.0', '2026-09-01 00:00Z');
  perform public.finish_run(pg_temp.h('yo'), run, 1, '2026-09-08 00:00Z');
  perform public.set_run_name(pg_temp.h('yo'), run, 'Yo', 'ok', '2026-09-08 00:01Z');

  if (select count(*) from public.leaderboard_top(pg_temp.h('yo'), 3)) <> 3 then
    raise exception 'leaderboard_top no respeta el límite';
  end if;
  select * into top_row from public.leaderboard_top(pg_temp.h('top-1'), 3) limit 1;
  if top_row.display_name <> 'Top1' or not top_row.is_me or top_row.rank <> 1 then
    raise exception 'el primero del top: %', top_row;
  end if;
  if exists (select 1 from public.leaderboard_top(pg_temp.h('yo'), 3) where is_me) then
    raise exception 'is_me marcó a otro';
  end if;
  select * into me from public.my_rank(pg_temp.h('yo'));
  if not found or me.run_id <> run or not me.is_me
     or me.rank <> (select rank from public.leaderboard where run_id = run) then
    raise exception 'my_rank: %', me;
  end if;
  if exists (select 1 from public.my_rank(pg_temp.h('nadie'))) then
    raise exception 'my_rank devolvió algo para un desconocido';
  end if;

  perform public.start_run(pg_temp.h('yo'), '2.0.0', '2026-09-09 00:00Z');
  select count(*) into mine_count from public.my_runs(pg_temp.h('yo'));
  if mine_count <> 1 or not exists (
       select 1 from public.my_runs(pg_temp.h('yo'))
       where run_id = run and name = 'Yo' and name_status = 'ok' and status = 'finished'
         and real_seconds = 604800 and finished_at = '2026-09-08 00:00Z'::timestamptz) then
    raise exception 'my_runs no trae sólo las selladas propias';
  end if;
  raise notice 'OK leaderboard_top, my_rank y my_runs, con is_me';
end $$;

do $$
declare
  ready uuid;
  fresh uuid;
  exhausted uuid;
  cfg jsonb;
begin
  select run_id into ready from public.start_run(pg_temp.h('cola-1'), '2.0.0', '2026-10-01 00:00Z');
  perform public.finish_run(pg_temp.h('cola-1'), ready, 1, '2026-10-02 00:00Z');
  perform public.set_run_name(pg_temp.h('cola-1'), ready, 'Viejo', 'pending', '2026-10-02 00:00Z');

  select run_id into fresh from public.start_run(pg_temp.h('cola-2'), '2.0.0', '2026-10-01 00:00Z');
  perform public.finish_run(pg_temp.h('cola-2'), fresh, 1, '2026-10-02 00:00Z');
  perform public.set_run_name(pg_temp.h('cola-2'), fresh, 'Nuevo', 'pending', '2026-10-02 00:10Z');

  select run_id into exhausted from public.start_run(pg_temp.h('cola-3'), '2.0.0', '2026-10-01 00:00Z');
  perform public.finish_run(pg_temp.h('cola-3'), exhausted, 1, '2026-10-02 00:00Z');
  perform public.set_run_name(pg_temp.h('cola-3'), exhausted, 'Cansado', 'pending', '2026-10-02 00:00Z');
  update public.runs set moderation_attempts = 20 where id = exhausted;

  if (select array_agg(run_id) from public.pending_names('15 minutes', 50, '2026-10-02 00:20Z')) <> array[ready]
     or (select install_id_hash from public.pending_names('15 minutes', 50, '2026-10-02 00:20Z')) <> pg_temp.h('cola-1') then
    raise exception 'pending_names no trae sólo la vieja con intentos';
  end if;

  cfg := public.ranking_settings();
  if (cfg ->> 'ranking_enabled')::boolean is distinct from true
     or (cfg ->> 'min_real_seconds_to_god')::int <> 36000 then
    raise exception 'ranking_settings: %', cfg;
  end if;
  raise notice 'OK pending_names para el cron y ranking_settings para los handlers';
end $$;

rollback;
