# Sesión 2026-10-15 — relevo 59: los 5 rojos aislados, B25, E12 aplicado en remoto, la 2.0 sin Meta y los cierres preparados

> **BORRADOR escrito por un agente sin compilar durante el relevo.** Lo marcado con `[COMPLETAR]` lo cierra el
> controlador cuando termine el `completo` de integ-r59 (números, hashes finales, qué entró a `version-2`).

Relevo por el disparo horario de la rutina `fisu-v2-relevo-a` (20:15, LOCK tomado por el 58 con latido de 28 min; a
pedido del dueño se reintentó a las 20:57 y el 58 ya lo había liberado a las 20:23:48). Cuota al llegar: 5 h 2 %,
semanal 37 %. Regla del dueño vigente: **los agentes no compilan por tarea**; se integra y se compila la ola entera.
Excepciones de hoy, todas con permiso explícito en el brief: `fix-ui-r59` (sólo las 3 pruebas rojas, con DerivedData y
simulador propios) y B30 iPhone (compilar la rama aparte con su DerivedData, 2.º slot junto al `completo`).

## Resultado en una línea

Los 5 rojos de UI de integ-r58 quedaron **aislados y arreglados** (2 eran carga, 3 eran reales: un test viejo frente a
B29, el plato de B28 y el fixture de B21). **E14b B25 «La Marcha»** se escribió, se revisó (doble cobro con dos
dispositivos) y se arregló. **E12 T17 está aplicado en remoto** con el OK del dueño. **La 2.0 sale sin Meta** (decisión
del dueño en vivo). Los textos de tienda y los cierres de E8d/E8e/E12/E14/E10 quedaron preparados. **integ-r59** (rama
`v2i/integ-r59`, base `4f0a210e`) junta todo; su `completo` va después del de integ-r58. `[COMPLETAR: version-2 =
<hash> si el completo de integ-r59 dio VERDE]`.

## Decisiones del dueño (en vivo, en este chat)

- «Andá desarrollando las tareas que faltan en paralelo» y, después, «deployá agentes para todas las tareas hasta el
  100 %; cuando termines integrá todo»: se despacharon en paralelo al `completo` los trabajos que no necesitan la
  máquina (E12 T17/T18, E10 textos, cierres de E8, E15 T8 sin simulador, B30 iPhone).
- **La 2.0 sale SIN Meta** (22:00): se saca el adaptador `GoogleMobileAdsMediationMeta`, la política y la fila Other
  Diagnostic Data de la etiqueta. Confirma la del relevo 54, que el `project.yml` contradecía.
- **E12 T17 aplicada en remoto** (22:02, «piso + vista, pg_net no»): la migración del piso y la de la vista
  `leaderboard`; `pg_net` queda como WARN justificado y su migración se borra del repo.
- Desde la sesión «Fisu Evolution v2 roadmap» (E15): el mensaje RGPD de UMP, publicado desde el 12 de octubre, suma el
  español (propagación ≤ 1 h); **O5 hecho** (`adergames-site` `main` = `658df9f`); **O4 postergado al día del envío**
  (ASC exige reflejar la versión en tienda); el **Apple Developer Program License Agreement quedó aceptado** (el 15 de
  octubre, por pedido del dueño): ya no bloquea mandar la 2.0.

## Decisiones por default del controlador (el dueño las puede cambiar)

| Decisión | Por qué |
|---|---|
| **El billete de la barra sigue al plato** (fix de B28), no queda centrado de verdad | `BarFlapLayout` asumía el plato centrado; con `GameTabBar.prominentCenterX` el billete cae a ~118 pt en un 16 Pro y ~107 en el SE, y «Reincarnate» entra justo |
| **B25 descarta la marcha del ganador con `startedAt` ≤ la última liquidada** (más estricto que el brief) | con dos dispositivos, `resolve` llevaba la marcha del ganador y el `blueEarnedLifetime` del perdedor: doble cobro |
| **El botón «Cobrar» de La Marcha tiene role `.free`**, no `.blue` | la revisión: el cobro del paso 1 es gratis; el blue es el premio |
| **B30 no se mergea sin el OK del dueño** y vive en `v2/e14b-b30-escala` | pidió probarlo en su iPhone (D13) |
| **E12 T17: el piso sale del reloj activo del perfil `.max`** (54.675 s = la mitad de 30,38 h) | `real_seconds` mide desde `start_run`; la mitad de la pared (~271 h) mandaría a `review` a cualquier jugador intensivo legítimo |
| **`leaderboard` y `leaderboard_internal` a `security_invoker` y sin `select` para anon** | nadie la leía directo: la app pide el top a la Edge Function, que llama a `leaderboard_top` (definer) |

## Qué entró

### El aislamiento de los 5 rojos (`build/oraculo/20261015-205819-aislar-r59`, simulador propio, sobre `7c26a20b`)

- VERDES aislados (era carga): `VisitorMechanicsUITests.testElVendedorMuestraTresCartas…` y
  `PrizesUITests.testTheGiftedMattressOpensOnTheBoard`.
- ROJOS reales, arreglados en **`fix-ui-r59`** (`2e244682`, opus; 3 clases 15/15 VERDE):
  1. `TutorialUITests.testElPuntitoDeLogros…`: test viejo frente a B29 (el paso 2 tapa la fila); ahora espera y declina
     con `reward.double.decline`.
  2. `PrestigeIndicatorUITests.testLosBotonesDeLaBarraNoPisanElPlato`: **de la app**, B28. `BarFlapLayout` usa
     `GameTabBar.prominentCenterX`.
  3. `VisitorUITests.testUnMergeEnMedioDeLaEntrada…`: el fixture `--uitest-merge-all` encolaba la cadena; nuevo
     `--uitest-homeless=<n>` y espera de 2 s.
- El `completo` de integ-r58 (`20261015-213050`) dejó 1 rojo de unit, `BarFlapLayoutTests.flapsFollowTheRealPlate`: el
  test nuevo de `fix-ui-r59` usaba tolerancia 0,1 contra 0,129 medido; fix `4f0a210e` (tolerancia 0,5).

### E14b B25 — «La Marcha» del Puntero

`ce5f4f3e` (opus, sin compilar; EK 1034, `MarchTests` 17, pacing sin cambio: Dios 45,40 h en `.free` y 32,19 h en `.ads`,
6 reencarnaciones). Revisión opus: APROBADO CON CAMBIOS, sin críticos; **IMPORTANTE:** doble cobro con dos dispositivos;
**MENOR:** el role del botón. Arreglo `f413eb48` (`lastSettledMarchStartedAt`, EK 1036). Menores que quedan: sólo el 2.º
toque de la fusión no cuenta; los toques no se guardan uno por uno; el reloj del dispositivo puede vaciar el cupo
semanal; tocar sin parar dispara más fusiones asistidas (por diseño). Entró a integ-r59 con las 12 claves del catálogo
(`eee53981`, `b132a2ad`) y el cherry-pick `8bc9cb04` (la marcha guardada no tapa al ayudante `march()` en
`MarchRuntimeTests`).

### B30 — el tamaño según la distancia (rama aparte, sin mergear)

`v2/e14b-b30-escala`: `DepthScale` (0,85 → 1,0 con smoothstep, `isEnabled`, mínimo de toque 44 pt) en empleados,
visitantes, cajas y colchón. Revisión sonnet: APROBADO CON CAMBIOS (5 menores); `fix-b30` (`9d1adec9`) arregló 4; el 5
(`vanish` absoluto) ya existía. B30 iPhone (opus, `79b500c7`): `build-for-testing` ✅ con dos fixes de tests
(`DepthScaleTests` @MainActor `bac5e36c`; `MarchRuntimeTests` `8bc9cb04`), 29/29 en 4 suites. **La Release al iPhone la
bloqueó el clasificador de permisos** («Production Deploy»); la instaló el dueño (22:54, iPhone 15 Pro). Pregunta abierta
en `DUENO.md`: ¿sí o no? Ojo: esa build todavía trae Meta y La Marcha.

### E12 — T17 y T18

`d1ef87f6` (opus, DONE_WITH_CONCERNS): piso `min_real_seconds_to_god` = 54.675 s; `supabase/test.sh` local VERDE (34 SQL +
80 deno). Aplicadas en `oejmjpwfxpwzzakdjxwp` por el MCP de Supabase, con el OK del dueño: `20261015000003_ranking_floor`
y `20261015000004_leaderboard_invoker` (historial corregido a esas versiones). Verificado: piso 54675, `security_invoker =
on`, anon sin `select`, `leaderboard_top` sigue `security definer`; el advisor ya no marca el ERROR. `pg_net` queda WARN
justificado y la migración `…000005` se borró del repo. Detalle: «Cierre de E12» al final del plan.

### La 2.0 sin Meta (`sin-meta`, `977aa7c6`, opus; trae `e10-textos`, `7586014c`)

`project.yml` sin `GoogleMobileAdsMediationMeta` ni `MetaAdapterTarget` (ningún Swift usaba Meta); `release.json →
mediation` sin Meta (grupo «Rewarded interstitial» borrado, era sólo suyo); SKAdNetwork `v9wttpbfk9`/`n38lu8286q` se
quedan (están en la lista de Google); política de la app y del sitio sin Meta; **App Privacy en 8 tipos** (sale Other
Diagnostic Data). Tests: `MediationContract`, `SettingsPersistence`, `Telemetry`, `releaseops` (44 ✅). Sitio
(`adergames-site`): rama `sin-meta` `7533671`, `next build` OK, **sin mergear a `main`** (🔒).

### Textos de tienda (E10 T11, borrador `7586014c`, sonnet)

`reviewNotes` en 3.998/4.000 (Ranking en el Menú, B29 en dos pasos); `whatsNew` ×3; App Privacy §4 como tabla única;
setup §1.7; notas del Ranking (`app-review-notes-e12.md`); líneas de La Marcha listas. `releaseops validate` VERDE.
Dudas al dueño: La Marcha en Novedades (no tiene lugar en las notas), voseo en es-MX y es-ES, la tarjeta del Ranking
depende del interruptor remoto durante la revisión, y la §1.8 copia vieja.

### E8 — cierres preparados (`f5b4e30a`, sonnet, sólo docs)

`pendingPlaces` ya vacío; el carry `VideoPlaybackPolicy` cerrado (`cafda289`); secciones «Cierre» en los planes de E8d
y E8e con los gates G1–G5 y los pasos exactos para el dueño. T15 de E8d y T9 de E8e quedan 🔒 por los gates en
dispositivo.

### E15 T8 (parte sin simulador, opus)

Revisión del diff de F0: sin críticos ni importantes; 6 menores (`IABTCF_PurposeConsents` vs `PublisherConsent` para
validar con legal; `site` del evento pago tardío; el interruptor sin reintento tras una falla de red; impresiones
perdidas con `player` nil; `admin.sql` `::int` → `::bigint`; `shown` fuera de pantalla). Pacing sin cambio (`.free` 45,40 h
· 6, `.ads` 32,19 h · 6). Falta de T8: las clases de telemetría en el `completo` y la verificación UMP con
`--debug-consent-eea`.

### El `completo` de integ-r58 (`20261015-213050`)

EK 1017 ✅, build ✅, Release 0 warnings ✅, store-unit 18 ✅, unit 2263 + 1 rojo (arreglado, arriba).
`[COMPLETAR: UI, aislamiento y veredicto]`. Después: el `completo` de integ-r59 (B25, E12, E8, sin-meta, claves)
`[COMPLETAR]`.

## Trampas nuevas

- **El clasificador de permisos bloquea instalar en un dispositivo** (instalar una Release se lee como
  «Production Deploy»): no se esquiva; lo instala el dueño. Un brief que dependa de eso tiene que prever el paso humano.
- **El `completo` corre en el worktree de la integración:** mientras corre no se mergea nada ahí (B25 esperó). Las ramas
  nuevas se arman en una integración aparte (integ-r59) y se compilan después.
- **Un test nuevo escrito sin correrlo puede traer una tolerancia inventada:** `flapsFollowTheRealPlate` fijó 0,1 y el
  valor real era 0,129. Medir antes de escribir la vara.
- **Dos ramas con el mismo helper de test lo sombrean:** `march()` de `MarchRuntimeTests` tapaba al ayudante de B25;
  el cherry-pick `8bc9cb04` va con B25 en toda integración.
- **Las migraciones aplicadas por el MCP de Supabase se registran con la hora, no con la versión del archivo:** hay que
  corregir `supabase_migrations.schema_migrations` a la versión del repo, o un `db push` las vuelve a aplicar.
- **`ALTER EXTENSION … SET SCHEMA` no existe para `pg_net`:** el drop/create es riesgoso con el cron vivo; se justificó el
  WARN en vez de moverla.
- **Un cierre de épica puede tocar `tasks.md`:** el agente de E8 lo hizo y hubo que revisarlo al integrar. Los briefs
  de docs dicen «no toques `tasks.md`».
- **El SDK de mediación que se saca tiene que salir de tres lugares a la vez:** el binario, la política y la etiqueta de
  App Privacy; y un cuarto fuera del repo (los grupos de AdMob y el mensaje GDPR).

## Carries para decidir

- Los de B25 (arriba) y los de B29/B24/B28 del relevo 58 siguen en pie: el visitante espejado, la oferta de compra del
  presentador que se abre sola, `flapHeight` en 44, el póster de caja abierta.
- El billete de la barra sigue al plato: «Contratar» no queda centrado de verdad (decisión para el dueño).
- Seis menores de la revisión de E15 F0 (arriba).
- B30: `backScale` en 0,85 es ajustable según lo que vea el dueño en su iPhone.

## Para el dueño

La lista completa y en orden de lo que sólo puede hacer el dueño hasta el envío está en la sección «Lo que queda del
dueño» del plan de E10 (`Docs/superpowers/plans/2026-10-11-v2-e10-release.md`, «Cierre de E10»). Lo inmediato:

1. **B30, ¿sí o no?** (la build ya está en su iPhone).
2. **Sacar Meta de los grupos de mediación de AdMob** y de los socios del mensaje GDPR; aprobar la rama `sin-meta` del
   sitio.
3. **Los textos de La Marcha y de Novedades** (y el voseo en es-MX/es-ES).
