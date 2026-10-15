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

## Telemetría (E15 F0) — en el repo, SIN aplicar

Las migraciones `…20261015000001_telemetry_schema.sql` y `…20261015000002_telemetry_retention.sql` están escritas y
probadas en local (`05_telemetry_test.sql`), pero **no están aplicadas** en el proyecto real. Aplicarlas es del dueño
(🔒 O2), después de la verificación de F0: `supabase db push` con el proyecto enlazado, o el SQL editor (las dos en
orden). La de retención necesita `pg_cron` (en local se saltea).

Qué guarda `public.telemetry_events`, una fila por evento:

| Columna | Qué |
|---|---|
| `install_id` | el UUID de instalación de la app (Keychain, no sincronizable). No es el IDFA ni el IDFV |
| `session_id` | un UUID nuevo en cada sesión |
| `client_ts`, `received_at` | la hora del teléfono (a ±30 días) y la de llegada (la pone el servidor) |
| `name` | `session_start`, `session_end`, `ad_impression`, `offer`, `purchase` o `prestige` |
| `app_version`, `build`, `os_version`, `device_model` | versión de la app y de iOS, modelo de máquina (`iPhone16,2`) |
| `storefront` | el país de la tienda (ISO alfa-3) o null |
| `props` | un objeto chico (≤ 2 KB) con claves cerradas por evento: número de sesión, duración, valor de la impresión, lugar y etapa de la oferta, producto comprado, cantidad de reencarnaciones |

Qué **no** guarda la tabla: ni IDFA, ni IDFV, ni el nombre del ranking, ni la IP, ni texto libre, ni precios ni
transacciones. La IP **sí** queda, fuera de la tabla, en los logs del gateway/PostgREST de Supabase durante su
retención (la del plan): los textos de privacidad (E15 T7) lo tienen que decir así, no «ni la IP».
Se borra a los **400 días** (cron `telemetry-retention`, una vez por día).

Los candados:
- **El interruptor** `settings.telemetry_enabled` arranca en `false`. La única política de la tabla (insert para
  `anon`) lo mira: apagado, el insert falla aunque la app se equivoque. La app lo pregunta con
  `POST /rest/v1/rpc/telemetry_enabled`. Se prende y apaga con `scripts/admin.sql` (10), **sólo** con la privacidad,
  los términos y la etiqueta de App Store Connect actualizados (🔒 O6).
- `anon` sólo inserta, y sólo las columnas de arriba (nunca `id` ni `received_at`). Nadie de afuera lee, actualiza ni
  borra; `authenticated` no tiene nada.
- Los `check` rechazan nombres fuera de la lista, textos largos, `props` que no sea objeto o pase de 2 KB, y horas
  del teléfono corridas más de 30 días. `props` además tiene sus claves cerradas por evento (C4): ni una de más ni
  de menos (`source` de `ad_impression` es opcional), números donde van números y textos acotados (`site` ≤ 64,
  `product` ≤ 128, el resto ≤ 32, `currency` tres mayúsculas; `XXX` es «sin moneda»).
- **Riesgo aceptado: no hay límite de frecuencia.** Con la clave anon (que va en la app) cualquiera puede insertar
  filas válidas en cantidad mientras el interruptor esté prendido. Los checks acotan el tamaño de cada fila, no la
  cantidad. Si pasa: apagar el interruptor (`scripts/admin.sql` 10) y borrar por `install_id`/`received_at`.
- Un build de DEBUG con `--telemetry-debug` escribe en producción: para las cifras reales, filtrar por `build` (ver `scripts/admin.sql`).

Las consultas de lectura (impresiones y eCPM por país × formato, el embudo por lugar, sesiones e instalaciones
activas por día) están en `scripts/admin.sql` (11–15).

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
