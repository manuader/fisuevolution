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

## Telemetría (E15 F0) — APLICADA (2026-10-15, interruptor en false)

> **Aplicada en `oejmjpwfxpwzzakdjxwp` el 2026-10-15** (🔒 O2, con el OK del dueño): las dos migraciones de `37ff5f26`,
> registradas en `supabase_migrations.schema_migrations` como `20261015000001` y `20261015000002` (las mismas del repo,
> así `db push` no las reaplica). Verificado: `telemetry_enabled` en false, RLS y política, cron `telemetry-retention`,
> insert de anon rechazado, 0 filas. **Desde ahora, cualquier cambio a este SQL va en una migración NUEVA; no se editan
> las aplicadas.**
>
> Lo que sigue abajo describe el esquema tal como quedó.

Las migraciones `…20261015000001_telemetry_schema.sql` y `…20261015000002_telemetry_retention.sql` están probadas
en local (`05_telemetry_test.sql`) y aplicadas en el proyecto real (ver arriba). La de retención necesita `pg_cron`
(en local se saltea).

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

El linter de seguridad marcaba tres cosas:
- las 6 tablas tienen RLS y ninguna política: nadie las lee directo (a propósito, queda);
- la vista `leaderboard` era `security definer`: `…000004_leaderboard_invoker.sql` la pasa a
  `security_invoker` y le saca el `select` a anon. El top público lo sirve la función
  `leaderboard`, nunca la vista;
- `pg_net` estaba en el esquema `public`: `…000005_pg_net_schema.sql` la baja y la vuelve a crear
  en `extensions` (no admite `SET SCHEMA`).

## Personalización (2.1, E15 F1) — SIN APLICAR (interruptor en false)

`…20261016000001_personalization_config.sql` está probada en local (`06_personalization_test.sql`) y **no está
aplicada** en el proyecto real. Aplicarla es 🔒 P4: con el OK del dueño, como las de la telemetría (`db push` o el
conector, registrando la misma versión en `supabase_migrations.schema_migrations`). Aplicada, no cambia nada: el
interruptor queda en `false`.

Qué agrega:
- Dos filas en `public.settings`: `personalization_enabled` (`false`) y `personalization_config`
  (`{"version": 0, "sections": {}}`). La config es la del contrato C3: `version` y una sección por fase
  (`player_value`, `segments`, `moments`); la app decodifica cada una por separado y una que falta o no valida deja
  esa fase en la base.
- La función `public.personalization_config()` (`anon`, `POST /rest/v1/rpc/personalization_config`): devuelve
  `null` salvo con un `true` explícito en el interruptor, y entonces la config, si es un objeto de hasta 64 KB.
  `null` = la base para todos.
- Ningún permiso nuevo sobre la tabla: `anon` sigue sin leer `settings` directo, sólo esta función.

Se prende, se apaga, se carga y se lee con `scripts/admin.sql` (16–18). Una config se valida **antes** de cargarla
(`pacing-sim` y los tests de las tablas). **Cambios al esquema o a la función = migración nueva; no se edita una
migración ya escrita** (tampoco esta, una vez aplicada).

## Telemetría de la 2.1 (E15 F1 T6) — SIN APLICAR

`…20261016000002_telemetry_v21.sql` está escrita contra la tabla de F0 y **no está aplicada** (🔒 P4, con el OK del
dueño, como las otras). No edita la migración de F0: reemplaza sus dos `check` (el de `name` y
`telemetry_props_by_name`) por los ampliados; la política, los permisos y el interruptor quedan igual. La prueba es
`07_telemetry_v21_test.sql`.

| Evento | `props` (claves cerradas) | Cuándo |
|---|---|---|
| `segment` | `id` (`base`/`low`/`mid`/`high`), `ver` (versión de las tablas, ≤ 32), `src` (`rules` o `tree-<v>`, ≤ 32) | en la primera sesión y sólo cuando cambia (F1 T5) |
| `exposure` | `exp`, `arm`, `ver` (≤ 32 cada uno) | al ver un brazo de un experimento, una vez por sesión y brazo (F3, F6) |
| `progress` | `max_tier`, `active_minutes`, `prestige` (números ≥ 0) | junto con cada `session_end` |
| `offer` | suma `ctx` **opcional**: `floor_full`, `price_wall`, `mattress_ready` o `back_offline` | cuando la oferta sale por un momento (F3) |

**Orden al publicar:** la app 2.1 manda `progress` con cada `session_end` aunque la personalización esté apagada. Con
la telemetría prendida, esta migración se aplica **antes** de que salga el binario 2.1: si no, el `check` rechaza el
lote entero (400) y la app lo descarta, con los eventos de F0 adentro.

`segment` queda `[VERIFICAR CON ABOGADO]` (App Store 5.1.2(iii): un dato por instalación; E15 F1 T9), y la
personalización sale apagada hasta esa revisión. Si el abogado lo objeta, la app deja de emitirlo (F1 T5) y el `check`
puede quedar como está. Las consultas por segmento están en `scripts/admin.sql` (19–20).

## El panel del valor por jugador (2.1, E15 F7)

Las vistas (`…20261016000003_panel_views.sql`) y los guardianes (`…20261016000004_panel_guards.sql`) leen la telemetría
y **sólo informan**: nada se apaga ni se carga solo. Hasta aplicarlas (🔒 P4) las consultas no andan. Las consultas son
`scripts/admin.sql` (21–28, sección «Panel (2.1)») y el envoltorio `Tools/v21/panel.sh` las corre con `psql`:

```
PANEL_DB_URL='postgresql://…' Tools/v21/panel.sh todo      # o: semana | segmentos | brazos | retencion | ritmo | guardian | priors
```

La URL la pasa el dueño en el momento; no se guarda en el repo. Rutina de la semana: `semana` (ingreso por
instalación-día por segmento), `brazos` y `retencion` (embudo y D1/D7 por brazo), `ritmo` (horas reales contra
`pacing-sim --segment-matrix`) y `guardian`. Un brazo en `apagar` (peor que el control por más de 1 punto en D1 o D7,
con significancia) se saca editando la config (admin.sql 17, subiendo la versión): decisión del dueño (P4/P5). Con
`pocos_datos` no se concluye nada. `priors` devuelve `alpha`/`beta` por brazo (con tope de 200 pseudo-cuentas) para pegar
en `sections.moments.arms[]` de la config; con menos de 100 mostradas por brazo se dejan planos.
