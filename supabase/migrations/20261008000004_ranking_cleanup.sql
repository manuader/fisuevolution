-- La limpieza que corre junto al cron de remoderate:
--  * api_calls: sólo cuenta la última hora, lo anterior sobra.
--  * players: un jugador sin ninguna partida sellada (finished, review, hidden) y sin actividad
--    en 90 días es basura (instalaciones descartables); sus partidas activas o abandonadas
--    caen en cascada. Una partida activa reciente protege al jugador: el tiempo real corre
--    por días, así que 90 días sin siquiera arrancar una partida es abandono.
create function public.cleanup_ranking(p_now timestamptz)
returns table (api_calls_deleted integer, players_deleted integer)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_calls integer;
  v_players integer;
begin
  delete from api_calls where at <= p_now - interval '1 hour';
  get diagnostics v_calls = row_count;

  delete from players p
  where p.created_at <= p_now - interval '90 days'
    and not exists (
      select 1 from runs r
      where r.player_id = p.id
        and (r.status in ('finished', 'review', 'hidden') or r.started_at > p_now - interval '90 days'))
    and not exists (select 1 from reports x where x.reporter_player_id = p.id);
  get diagnostics v_players = row_count;

  return query select v_calls, v_players;
end $$;

revoke execute on function public.cleanup_ranking(timestamptz) from public, anon, authenticated;
grant execute on function public.cleanup_ranking(timestamptz) to service_role;
