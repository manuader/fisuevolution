# Backend del ranking (E12)

Supabase: migraciones SQL, cinco Edge Functions (`start-run`, `finish-run`, `leaderboard`,
`report`, `remoderate`) y la lógica pura en `functions/_shared/`. Se prueba entero en local.

## Probar

    supabase/test.sh          # todo: Postgres temporal + tests SQL + lint y tests de Deno
    supabase/test.sh --sql    # sólo SQL
    supabase/test.sh --deno   # sólo Deno (la integración con base se saltea)

Necesita Postgres 15+ de Homebrew (`postgresql@16`) y `deno`. Los tests no usan la red.

## Secretos

| Dónde | Nombre | Para qué |
|---|---|---|
| Secretos de las funciones | `ANTHROPIC_API_KEY` | Haiku modera los nombres. Sin ella todo queda `pending` |
| Secretos de las funciones | `REMODERATE_SECRET` | Autoriza al cron a llamar a `remoderate` |
| Vault (SQL editor) | `ranking_project_url` | URL del proyecto, la usa el cron |
| Vault (SQL editor) | `ranking_remoderate_secret` | el mismo valor de `REMODERATE_SECRET` |

## Desplegar

Con el proyecto enlazado (`supabase link`): `supabase/scripts/deploy.sh`. Corre el oráculo, hace
`db push`, despliega las cinco funciones e imprime los pasos manuales de los secretos.

La migración del cron (`…000003_ranking_cron.sql`) necesita `pg_cron` y `pg_net`: sólo corre en el
proyecto real. `remoderate` cada 15 minutos reintenta hasta 50 nombres pendientes y limpia
`api_calls` de más de una hora y jugadores sin partida sellada ni actividad en 90 días.

## Lista de palabras

`blocklist/propuesta.txt` es una **propuesta, no está activa**. Cuando la apruebes:
`deno run --allow-read --allow-write supabase/scripts/blocklist_to_sql.ts` genera la migración y el
próximo deploy la aplica.

## Revisar desde el panel

`scripts/admin.sql` tiene las consultas: cola de review con sus tiempos, nombres con 3 o más
reportes, aprobar u ocultar una partida, perdonar reportes, cambiar el piso de tiempo y el
interruptor del ranking.
