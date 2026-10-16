-- El linter de Supabase marca las vistas security definer (ERROR). Con security_invoker la vista
-- usa los permisos de quien la lee: las funciones del ranking (security definer, dueño postgres)
-- la siguen leyendo igual, y anon ya no la lee directo. Nadie la leía así: la app pide el top a la
-- Edge Function `leaderboard`, que llama a leaderboard_top con service_role.
alter view public.leaderboard_internal set (security_invoker = on);
alter view public.leaderboard set (security_invoker = on);
revoke select on public.leaderboard from anon, authenticated;
