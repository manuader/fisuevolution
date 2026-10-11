# SESION 2026-10-11 — v2, relevo 32: el director del tutorial, la columna con lecciones y botón de video, las pintas con video, el arnés de capturas y dos arreglos que valían una ola

La ola AD. El relevo 32 arrancó a las 03:22 con el disparo horario de la rutina `fisu-v2-relevo-a`: a las 03:01 la puerta había dado el `LOCK` del 31 vivo, el dueño pidió «continúa» y a las 03:22 el `LOCK` estaba libre. Cuota en 5 h 13 %, semanal 71 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`), E9a T4 en opus (el director), y **dos revisiones opus de código** (E9a T3 y E9a T4). Todo pasó por **`v2i/integ-r32`** (BASE `version-2` en `6a5643d`, 233 de 283, que es también `origin`). El `comun.md` del 31 se había perdido con su worktree (`.superpowers/` está gitignored) y se reescribió en `v2i-integ-r32/.superpowers/sdd/ola-r32/comun.md`. Latido: `scratchpad/latido.sh`.
`fisu-v2-relevo-b` no existe. `DUENO.md`: sin pedidos nuevos (los `[ ]` abiertos esperan al dueño: skins con video, mediación SPM, segunda tanda, blocklist → E12 T16). Carga: 1,8 al arrancar. El contexto llegó a 274k a las 06:15: desde ahí no se despacharon tareas nuevas, sólo arreglos y oráculos.
**E6b T8 no se despachó:** su cierre exige el OK del dueño en vivo.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`748a7a7`** (= `v2i/integ-r32`, fast-forward, pusheado), desde `6a5643d` |
| Progreso | 233 al llegar → **240 de 283 (84,8 %)** (el `grep` de `tasks.md` §2, con `[a-f]?`) |
| `completo` | `582c8ee` **ROJO por 5, todos resueltos** (ver «El `completo`»). Resto VERDE: EK 863 · unit 1625 · UI 139 · store 18+2 · iPad 4 · SE 2 · pipeline 97 · pacing-sim Dios 31,34 h · 13 reencarnaciones · Release 0 |
| `rapido` | `74d1ac4` VERDE (EK 863 · unit 1603), `0a9cd77` VERDE (unit 1609), **`3959b49` VERDE** (EK 863 · unit 1625 + 1 rojo, `ArtPacksTests.sharedUntilLastRelease`, aislado VERDE 8/8: flake · Release 0) |
| En vuelo al cierre | ninguno |

## Lo que se integró

| Tarea | Commits | Verificación y revisión | Desvíos y carries |
|---|---|---|---|
| **Arreglo `MenuPagerView`** (sin fila) | `8fcc0c41` | `RankingTabUITests` 4/10 rojos → **0/10** con `-test-iterations 10`; `MenuPagerUITests`+`RankingTabUITests` 8/8; tarea `MenuSessionTests` VERDE. El controlador leyó el diff | `onScrollGeometryChange` → `pageIndex` por offset; `settle(on:)` único; **su línea salió de `Tools/v2/rojos-declarados.txt`**. Carry: `settle` dispara a mitad de arrastre al cruzar la mitad → `menuPageChanged` (`markTabOpened`/tip) puede marcar una pestaña vista y volver |
| **Arreglo del pager, 2.ª vez** | `0ae6ff0d` | `CustomizationUITests` 5/5; `RankingTab` 0/10; `MenuPagerUITests` 2/2; tarea `MenuSessionTests` VERDE | `guard moving` en `onScrollGeometryChange`. Ver «El `completo`» |
| **E9a T3** las banderas cableadas | `049ec895` + arreglos `a4ecc201` | tarea VERDE EK 863 · unit 65 (59 tras los arreglos); RED por mutación: las 3 del cableado tiran 2 rojos cada una, `introducedIn` todo `.v1` tira 1. **Revisión opus: Approved con arreglos** | `TutorialFlags` en todos los lectores; migración en `finishBootstrap` (+Bootstrap) que **sólo enciende**; `introducedIn` v1 = 8 lecciones. Arreglos: tests por `bootstrap()` con repo inyectado, `veteranKnownLessonsAreExplicit` (el anterior era tautológico), comentario de `+Debug`. Riesgo de save OK (veterano, a medio núcleo, una sola vez, prefijo, notificaciones) |
| **Arreglo `VideoPlaybackPolicy`** (#21) | `cafda289` | tarea `VideoPlayerPoolTests` VERDE EK 863 · unit 19; RED: 1 rojo en `launchPolicyBranches`. Diff leído | forcedStill sólo con `XCTestConfigurationFilePath` o `--uitest*` sin `--uitest-video`. **Los UI con `--uitest-video` ahora reproducen de verdad** |
| **E10 T6** arnés de capturas | `689c91be` | 17 Pro Max 8/8 en 1320×2868 e iPad 13" 8/8 en 2064×2752, VERDE; miré la 01 | `AppStoreScreenshotTests` reescrito (4 tests por idioma, menú deslizable por ids); `Tools/v2/capturas.sh` nuevo; PNG en `build/capturas-r32/`. Carries a E10 T9: aro azul sobre el callejón en `--screenshot-mode`, ~9 personajes y no 15 (torre llena), ranking con nombres reales, 07 = ficha (interpretación), 6,3" sin correr |
| **E10 T4** `adergames-site` | `3f03716` en la rama LOCAL `fisu-v2-release` | `npm run build` OK; `ads.json` igual; 0 AppLovin/Mintegral | `app-ads.txt` ya traía Unity + Meta en `main` (`91aa0ba`); `legal.ts` y `terms.ts` en espejo. **Sin push.** Carry al dueño: `terms.md` §3 dice «No tenemos servidores» pese al ranking (texto legal, no se tocó) |
| **E7b-b T5** las lecciones de la columna | `c31cda6d` (+ 3 claves) | tarea EK 863 · unit 44 + 1 rojo esperado (`LocalizationCompleteness`, claves en `claves-pendientes/e7b-b-t5.json`, aplicadas al integrar) | lecciones `.sideRail` y `.mergeAllVideo`; `.wheel` señala `.sideWheel`; la persiana queda abierta mientras su lección esté activa; `sideRailOpened`; `RestingLessonAnchors` sacado. Carry: una partida nueva dispara la lección de la columna al terminar el núcleo; clave vieja `tutorial.tip.wheel` sin uso |
| **E8e T8** las pintas con video | `74674598` + `5c5b9e61` + `b8defeef` | tarea EK 863 · unit 22; 39 py OK. Primer pase sin RED por mutación → devuelto: fallback a base tiraba `ArtClipsTests` + `sheetClip`, pero `skinWithoutClipRevealsStill` era vacuo → endurecido; sin `isSelected`/`owned` → `sheetClip` rojo; `odr_tag` con id completo → test py rojo | `validate_id`/`odr_tag` con `<tipo>__<pinta>`; `CharacterPortrait` recibe clip (sólo la opción seleccionada y tuya con clip propio); el reveal monta sólo el clip de la pinta. Sin clips de pintas todavía |
| **E7b-b T7** el botón de video completo y el mapa de ubicaciones | `f5e57653` (+ clave `ads.preparing`) | tarea VERDE EK 863 · unit 12; RED: `everyOfferUsesItsUnit` rojo sin `placement` | `placement` obligatorio; precarga + sondeo 250 ms ×20 y luego 2 s, cancelado en `onDisappear`; «Cargando…» con `StateBadge`; **P0 preservado** (`d57d11f`); 3 llamadores → `.visitor`; `AdPlacementMapTests`. Carry al dueño: sin red el botón queda en «Cargando…». UI al `completo` del 33: Prizes, SideRail, Visitor, EventChip, Wheel, Regalos/Offline/Cofre/Diario/Carrera (primer sondeo asíncrono) |
| **E9a T4** el director | `b9178ce8` + arreglos `af4921fb` | tarea VERDE EK 863 · unit 65 → 69; RED de compilación + mutación 3/10 → RED por las 4 mutaciones. **Revisión opus: Approved con arreglos** | `GameState+Tutorial.swift`: `TutorialEngine` + director; 19 lecciones a un paso `legacyStep`; ritmo 20 s; watchdog 180 s por `advanceTutorial(delta:)`; `--uitest-lesson`/`--uitest-tutorial-lock`. Arreglos: guard «corrida de cola sin turno no avanza», `aStaleTip…` con pendiente armado + `aPendingTipIsNotBurnedByItsSignal`, tests de timeout/tap/`.store`, `releaseTutorialTurn` sólo corridas de cola, `startTutorialRun` suelta la anterior |

El controlador leyó cada diff antes de mergear, y no se tocó el árbol de `integ` mientras corría un oráculo. Los worktrees de tarea se borraron al integrar (1,7 GB el del pager).

## La secuencia de oráculos

1. **`rapido` `74d1ac4`** (05:29): VERDE sobre pager, E9a T3, `VideoPlaybackPolicy` y E10 T6 → E9a T3 ✅, E10 T6 ✅. `version-2` ff a `f44de0a`.
2. **`rapido2` `0a9cd77`** (05:57): VERDE sobre E7b-b T5 + claves y E8e T8 → ✅ las dos. `version-2` ff a `32da0d8` (238 de 283).
3. **`completo` `582c8ee`** (07:37): ROJO por 5 (siguiente sección). `version-2` **no** se movió.
4. **`rapido3` `3959b49`** (08:40): VERDE (un flake aislado VERDE) → E7b-b T7 ✅, E9a T4 ✅. `version-2` ff a `748a7a7`.

## El `completo`: cinco rojos, tres causas

- **`ElevatorRideTests.skipWhileOpeningDoesNotDingTwice`** y **`AscentRenderingUITests.testCharactersStayVisibleAfterTheFirstAscent`:** 3/3 verdes aislados; flake de carga (el segundo con un timeout de 137 s).
- **`CustomizationUITests` ×3: rojo REAL.** Un agente de triaje (sonnet, worktree detach `v2i-triaje-r32`) los aisló rojos y bisectó contra `32da0d8`: el culpable era **`b0ccc638`, mi propio arreglo de `MenuPagerView`**. El `onScrollGeometryChange` reporta índice 0 al abrir (offset 0 antes del `scrollTo(start)`) y `settle(Mejoras)` pisaba la página de arranque: **un bug de producción** (abrir el menú en Pintas caía en Mejoras). El merge del pager sólo había corrido Ranking/MenuPager, no los UI que abren el menú en otra página. Arreglo `0ae6ff0d` (`guard moving`).
- Con el `completo` de `582c8ee` (rojos restantes verdes aislados) más el `rapido3` se promovió `version-2`.

## Las revisiones opus

- **E9a T3 — Approved con arreglos.** Obligatorios: (1) tests por `bootstrap()` con repo inyectado + RED por 3 mutaciones del cableado, (2) `newMechanicsAreNotKnown` era tautológico → conjunto explícito; menor: comentario de `+Debug`. Hechos en `a4ecc201`. Carry: CloudKit no restaura sobre local vacío → ese veterano queda como instalación nueva (igual que en la v1).
- **E9a T4 — Approved con arreglos.** Sin camino alcanzable que congele la cola ni queme lecciones en T4 (salidas por `releaseTutorialTurn`, debug reset limpio, veterano OK, `--uitest` bajo DEBUG, tick barato). Obligatorios: (1) guard «corrida de cola sin turno no avanza» en `progressTutorialRun` (latente para T5/E9b), (2) `aStaleTip…` sin dientes. Menores: tests de timeout/tap/`.store`, blindaje de `releaseTutorialTurn`/`startTutorialRun`, `--uitest-lesson` inválido. Hechos en `af4921fb`. **Carries serios:** T6 (una lección mostrada con elegibilidad muerta bloquea la cola hasta los 180 s del watchdog cuando se saque el timeout de 12 s de `.tutorialTip`: retirarla marcando, o red por tiempo de pared), T7 (`openPage` vs `uiCoversBoard`), E9b (`SideRailView` mira `step.target`).

## Trampas nuevas

- **Arreglar un paginador con `onScrollGeometryChange` sin `guard moving` asienta la página 0 con el scroll programático inicial:** abrir el menú en otra pestaña caía en Mejoras. **Un cambio en el pager corre también los UI que abren el menú en otra página (`CustomizationUITests`).**
- **`.superpowers/` está gitignored:** el `comun.md` de una ola muere con su worktree de integración; el siguiente relevo lo reescribe (o se copia antes de barrer).
- **Con `-disableAutomaticPackageResolution` un worktree nuevo falla sin `Package.resolved`.**
- **Un test «sin clip queda quieto» puede ser vacuo si no prueba que hubo reveal** (E8e T8).
- **Con `VideoPlaybackPolicy` arreglado los UI con `--uitest-video` reproducen de verdad:** más carga; un `AscentRenderingUITests` tardó 137 s.
- **Los flakes de carga de este relevo** (`ElevatorRideTests`, `AscentRenderingUITests`, `ArtPacksTests.sharedUntilLastRelease`) pasan aislados: un rojo del `completo` se aísla antes de culpar a la ola, y si es real se bisecta.
- Siguen: los briefs con la ruta absoluta del protocolo y «prohibido `find /`», las claves por snapshot, un oráculo por vez y nada de tocar `integ` mientras corre, ≤ 3 compilando, esperar por PID (nunca `pgrep -f`), borrar sólo el simulador propio por UDID.

## Para el dueño

- **Publicar el sitio** (rama local `fisu-v2-release`, `3f03716`): `git merge --ff-only fisu-v2-release && git push origin main`. Y **`terms.md` §3** («No tenemos servidores»): contradice al ranking; es texto legal.
- **E6b T8** espera tu OK en vivo.
- **Sin red el botón de video queda en «Cargando…»** (E7b-b T7): ¿está bien o querés un mensaje?
- **Una partida nueva dispara la lección de la columna** apenas termina el núcleo (giro listo): ¿se pospone?
- **Un veterano que se reinstala es una instalación nueva** (CloudKit no restaura sobre local vacío; igual que en la v1).
- Siguen los del 31: la medición del spike en tu SE, B22, `releaseops asc builds` real, publicar notas y políticas, `PREGUNTAS-DUENO.md`, mirar lo animado de E8e en un iPhone.

## Lo descartado

- **Culpar a la carga por los `CustomizationUITests`:** falsado por el bisect; era el arreglo del pager.
- **Despachar E6b T8 sin el OK del dueño:** su cierre exige verlo en vivo.
- **Despachar más tareas pasado el contexto de 250k** (274k a las 06:15): sólo arreglos y oráculos.
- **Un `rapido` por merge:** un `completo` y un `rapido` por tanda, más los `rapido` de promoción cuando hay que mover `version-2`.

## Cierre

- Subagentes de tarea en vuelo al cerrar: 0. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla; quedan `v2i-integ-r32` y `v2i-docs-r32` (más los de relevos anteriores si no se barrieron). Un `--apply` por worktree, con el shell fuera de él. `v2-e8-recortes`, `v2-e8e-plan` y el de `v2/estudio-assets` **no son `v2i-*`: no tocar.** El worktree del sitio (`adergames-site.worktrees/fisu-v2`) queda: el dueño publica desde esa rama.
