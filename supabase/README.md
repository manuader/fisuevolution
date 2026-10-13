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
| Secretos de las funciones | `REMODERATE_SECRET` | Autoriza al cron a llamar a `remoderate`. **Opcional:** si no está, la función usa el mismo valor del Vault (`ranking_remoderate_secret`) |
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

## El despliegue real (2026-10-12, E12 T16)

Proyecto `oejmjpwfxpwzzakdjxwp` (FisuEvolution, us-west-2). Se desplegó con el conector de Supabase (MCP), no con la
CLI:

- Las 5 migraciones aplicadas con `apply_migration`. Las versiones de `supabase_migrations.schema_migrations` se
  renombraron a las de los archivos (`20261008000001`…`20261009000001`) para que un `supabase db push` futuro no
  intente aplicarlas de nuevo.
- El Vault tiene `ranking_project_url` y `ranking_remoderate_secret`. Este último se generó dentro de la base
  (`gen_random_bytes`): nadie lo vio. Las funciones lo leen del Vault, así que no hace falta cargar
  `REMODERATE_SECRET` a mano.
- Las 5 funciones desplegadas con `verify_jwt` como en `config.toml`. La **clave publicable**
  (`sb_publishable_…`) pasa el gateway con `verify_jwt = true`: es la que lleva la app. La JWT `anon` legada
  también anda.
- `ANTHROPIC_API_KEY` ya estaba cargada por el dueño: la prueba de humo aprobó un nombre con Haiku.

La prueba de humo, contra el proyecto real:
- un nombre normal → `ok` y rank 1;
- una palabra de la lista → `rejected`;
- un nombre inválido → 400;
- el ranking, los reportes, `remoderate` sin secreto → 401;
- el GET → 405;
- sin clave → 401;
- el cuerpo del cron ejecutado a mano → 200.

Para la prueba se bajó `min_real_seconds_to_god` a 0 y después se restauró a 36000. Los datos de prueba se borraron.

El linter de seguridad marca tres cosas, todas a propósito o menores:
- las 6 tablas tienen RLS y ninguna política: nadie las lee directo;
- la vista `leaderboard` es `security definer`: es el top público, sin `player_id`;
- `pg_net` está en el esquema `public`.
