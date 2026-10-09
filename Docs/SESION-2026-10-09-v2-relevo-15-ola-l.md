# SESION 2026-10-09 — v2, relevo 15: el ascensor montado, el pool de videos y el store del ranking

Relevo 15 de la ejecución autónoma de la 2.0, despertado a las 23:03 del 8 de octubre por la rutina
`fisu-v2-relevo-a` con el `LOCK` libre (lo había liberado el relevo 14 a las 22:19). Controlador opus; implementadores
sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); revisores opus. Todo pasó por la rama de integración
**`v2i/integ-r15`** (BASE `version-2` en `fa8781a`). Cerró con 0 subagentes en vuelo, a ~245k de contexto: la regla de
250k se respetó y desde ahí no se despachó nada nuevo, sólo se terminó lo que estaba en vuelo.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | `fa8781a` (los docs de arranque del relevo; el relevo 14 había dejado `246beb7`). Avanza por fast-forward a `integ-r15` si el `rapido` da verde |
| `v2i/integ-r15` | **`e6e8c53`** = las seis tareas de abajo. `rapido`: RAPIDO_PENDIENTE |
| Progreso | **92 de 254 en `version-2`; 92 + 6 = 98 de 254 (38,6 %)** si el `rapido` de `integ-r15` da VERDE (`tasks.md` §2) |

El paso 1 del handoff (el `rapido` de `integ-r14` y su fast-forward) ya lo había hecho el relevo 14: las cinco tareas
de esa rama son ✅ y entran en las 92.

## Lo que se integró

| Tarea | Commits | Oráculo y nota |
|---|---|---|
| **E8d T6** sonidos nuevos A (11 `.caf`) | `7c31fc8` (merge `0079647`) | tarea unit 12; revisión ninguna por plan |
| **E3b T7** el botón del atajo nunca desaparece | `06990b0` + `dc08eb9` (merge `e1bab70`) | tarea unit 24, luego QuickHire 3, Tutorial 6, BottomMenu y FisuJobs verdes; revisión: lectura del controlador |
| **E8d T2** `VideoPlayerPool` y `VideoPlaybackPolicy` | `e097c1e` + `0866227` | tarea unit 12, luego 19; revisión opus |
| **E12 T8** `RankingStore` | `40e6eaf` + `b5c8a55` | tarea unit 18, luego EK 607 · unit 29; revisión opus |
| **E13b T6** el viaje montado encima de `RootView` | `5e8b9a5` + `7fcd753` + `323e4bc` (merge `c90bd4e` de `integ-r15`) | tarea unit 28, luego 40, luego 44; UI ElevatorRide 3 (16 Pro e iPad), FloorMap 2, CareerChoice 2, AscentRendering 1; revisión opus |
| **E8d T3** `AnimatedArtView` | `cd38b39` + `e31b466` (merge `e6e8c53`) | tarea unit 4, luego 9; revisión opus |

### E8d T6 — los sonidos A

11 `.caf` a −18/−24 dB RMS (paquete, colchón, visitante, tienda, revelación, cable). `AudioManager` ganó `Gain`
(acción/ambiente), `startAmbient` y `talkPitch`. Lo que todavía no suena tiene dueño en `pendingWiring` (E5b T2/T3,
E4b T3, E6a T8, E8d T5/T9/T10); `elevatorCases` los cablea E13b T6. Sin revisión: la tarea es mecánica. 🔒 Oír los
sonidos es del dueño (E8d G7) y no frena nada.

### E3b T7 — el atajo que no desaparece

`QuickHireButton` usa el `blocker` de T6: gris, "Piso lleno", temblor, y la lección sólo se marca con `blocker == nil`.
Long press de 0,45 s → `onChoose` (lo cablea E13b T8 desde `RootView`); pin y chevron. El catálogo suma 4 claves
(`e3b-t7.json`).

- **Riesgo que el controlador vio al leer el diff:** si el `Button` no recibe la acción después del long press,
  `longPressFired` se traga el próximo toque. Se devolvió con un UI test "mantener 1 s, soltar, tocar compra".
- **Arreglo `dc08eb9`:** un `DragGesture` baja la bandera 250 ms después de soltar, y el UI test nuevo ("un toque tras
  mantener compra") quedó verde.

### E8d T2 — el pool de videos

`VideoPlayerPool` (≤ 3 vivos, roles, suspensiones, reservas) y la política `VideoPlaybackPolicy`; reemplaza `VideoSlot`
(E8b T5). **Revisión opus: Approved con arreglos**, todos hechos:

- `forcedStill` apaga la cinemática (en el borrador la dejaba viva).
- `policy` quedó legible desde afuera.
- `recompute` reentrante: se leyó la versión final (`notified`) y está bien.
- `suspendsVideoPool(active:reason:)` con guard, y `launch(arguments:environment:xctestLoaded:)` puro.
- Tests con conteo de avisos y mutantes.

### E12 T8 — el store del ranking

`RankingStore` con `startAttemptId` (el `clientRunId` del intento) y persistencia **antes** del `start-run`. La duda
que quedó al despachar (`playedSeconds` en 0 en la llegada arrastrada) la resolvió la revisión opus contra
`supabase/functions`. **Approved con arreglos**, hechos:

- `CarriedSubmission.playedSeconds` (cambio de EK; el controlador leyó el diff).
- Reintento sin nombre ante `invalidName`; `nameError` aparte de `entryPrompt`.
- `offerCardIfDue()` en `reachedGod` y en `becameActive`, sin fugas de `scheduled`, la tarjeta se reconstruye; guards
  contra respuestas viejas; cliente suspendible en los tests.

### E13b T6 — el viaje montado

El overlay vive en `FisuEvolutionApp` (el mapa viaja); bajo `--uitest*` el viaje dura 0 s, así los UI tests de siempre no
cambian. Primera entrega `DONE_WITH_CONCERNS`: UI tests sin correr y motor a gain 0,4 a ojo. Chocó con E8d T6 en
`AudioManager.play` → se devolvió para mergear `integ-r15` y usar `Gain`/`startAmbient`. **Revisión opus: Approved con
arreglos**, hechos:

- `.idle` = llegado, sin el parpadeo al salir.
- UI test `--uitest-elevator-ride-slow` para saltear con viaje lento; doble ding al saltear en `.opening` corregido.
- Mapeo `Cue` → sonido puro y pinado por tests (`ElevatorSound`).
- `.isModal` en la cabina; `prepare()` no calienta con Reduce Motion; `requestFromMap` ignora con un viaje en curso.
- iPad verificado: el `onDisappear` del mapa dispara (ElevatorRide 3 en 16 Pro e iPad).

### E8d T3 — `AnimatedArtView`

Póster instantáneo, video con fundido, `loop` o `once`. Reemplaza `LoopingPortraitView` (E8b T5). **Revisión opus:
Approved con arreglos**, hechos:

- El video es un overlay del póster (no un `ZStack` hermano); `.id(url|rol)`.
- Un `.once` no revive tras terminar; desmontar no cuenta como terminar (no llama `onEnd`); vigía de 1 s para el `.once`.
- `.loop` siempre pide lease; al agotar el sondeo suelta todo (`giveUp`).
- `art.video` es live/still.
- **El publisher de `isReadyForDisplay` no disparó en el simulador**, así que quedó el sondeo de 50 ms × 40 (ver trampas).

## Decisiones de este relevo

- **El `rapido` y el fast-forward a `version-2` quedan para el cierre,** no por tarea; mientras corre un oráculo en
  `version-2` no se mergea ahí.
- **Con la máquina cargada no se compila de a tres.** A las 02:35 la carga rondaba 600 (ver trampas); el controlador
  dejó dos compilaciones y no despachó una tercera. Las colgadas de `xcodebuild` venían de ahí.
- **No se toca la sesión del dueño** aunque sea la causa de la carga (la segunda tanda de videos en `v2-e8-videos`).
- **Terminar lo en vuelo es válido durante el cierre** (revisiones y arreglos), pero tarea nueva no.
- **Los menores que no muerden se dejan anotados** (el test de `queue.play()` de T3 es débil) en vez de reabrir al
  implementador.

## Trampas nuevas

- **Un `xcodebuild` de tests puede no salir nunca.** Dos casos: después de `Test run with…` el proceso sigue vivo
  (E12 T8 esperó 2 h 16 min con los 18 tests ya terminados en 1 s, y el proceso lanzó `simctl diagnose`; E13b T6 relanzó
  el runner de UI 2 h 23 min), o se queda en `Resolve Package Graph` bajo carga. Se salió con
  `-disableAutomaticPackageResolution -skipPackageUpdates` y el simulador ya booteado. Poner timeouts, mirar `etime` en
  cada borde y no esperar más de 15 minutos.
- **La carga de la máquina por la sesión del dueño.** La segunda tanda de videos (`tanda2.sh` →
  `video_assets.py personaje <id>`, multiproceso, en `v2-e8-videos`) más Vorssaint llevaron la carga a ~600. Con eso: no
  más de 2 compilando.
- **`pkill -f "until ! pgrep"` mata bucles ajenos.** El agente de E8d T3 cortó así su propio `until pgrep`, y el patrón
  también habría matado los de otras sesiones. Nunca; cortar sólo por PID propio.
- **Un agente que pasó un oráculo al fondo por timeout se re-despierta.** El de E8d T6 ya había entregado y seguía
  despertándose por su propio oráculo (3 veces). `TaskStop` sólo después de que entregó.
- **El publisher de `isReadyForDisplay` no dispara en el simulador.** `AVPlayerLayer` no lo publica ahí; el sondeo queda
  como camino real y el publisher habría que probarlo en un dispositivo.
- **`AudioWiringTests` sólo ve `audio?.play(`:** `startAmbient` no cuenta y `AudioWiringTests` no escanea `UI/Elevator`.

## Carries por tarea

- **E13b T6 → T8:** `elevatorKeypadOpened()` al desplegar la placa; `openKeypad()` calienta la cabina; **los popups de
  `RootView` se dibujan encima de la cabina**; el motor sigue a gain 0,4 a ojo.
- **E3b T7 → T8:** `onChoose` del long press lo cablea `RootView`.
- **E12 T8 → T10 / T9 / T11:** `GameState` conforma `RankingStateHost` (T10); T9 y T11 leen
  `board`/`myRuns`/`entryPrompt`/`nameError`/`isSubmitting`/`isEnabled`; `godTier` sin uso todavía; la config remota sigue
  `null` hasta T16.
- **E8d T2 → T3/T4/T10:** guardar el `Lease` y crear el player sólo con `isLive`; T10 usa `suspend(.elevatorRide)` y
  `reserve()`; la cinemática ignora las suspensiones (si el viaje debe apagarla, cambiar `liveIDs`).
- **E8d T3 → T12:** la capa no re-resuelve la URL (lo cubre `.id`); bajo `suspendsVideoPool`, `.once` no llama `onEnd`.
- **E8d T6:** el motor sigue a −8,5 dB (bajarlo con `.ambient` o `SFX_RMS_DB`); `pendingWiring` con dueños.
- **Siguen vigentes** los del relevo 14: HEVC con alfa a ×5 en un iPhone real (E13b T11 / E8d G3), los stills de la
  cabina con la línea verde (regenerar con `cabina-cuadros`), `resolveAcrossReset`, `carriedSubmission`.

## Oráculo

- `rapido` sobre `integ-r15` (`e6e8c53`): RAPIDO_PENDIENTE
- Tareas: E8d T6 unit 12 · E3b T7 unit 24 + UI QuickHire 3 / Tutorial 6 / BottomMenu 4 / FisuJobs 2 / HUDRedesign 3 ·
  E8d T2 unit 19 · E12 T8 EK 607 · unit 29 · E13b T6 unit 44 + UI ElevatorRide 3 / FloorMap 2 / CareerChoice 2 /
  AscentRendering 1 · E8d T3 unit 9.
- No se corrió un `completo` nuevo; el de referencia sigue siendo el `--limpio` de `c94f75f`.

## Lo descartado

- Un viaje que dependa del mapa visible: `pendingFromMap` y el `onDismiss` del `fisuSheet` quedaron como respaldo
  defensivo, no como camino principal (el `onDisappear` dispara en iPad).
- Reintentar el publisher de `isReadyForDisplay` en el simulador: no dispara; se mantiene el sondeo.

## Cierre

- Subagentes en vuelo: **0**. `LOCK`: lo libera el controlador.
- Worktrees borrados al integrar cada tarea (E8d T6, E3b T7, E8d T2, E12 T8, E13b T6, E8d T3). Queda `v2i-docs-r15` y el
  `v2i-integ-r15`, para el barrido final (`limpiar-worktrees.sh`, todo ya en GitHub). No se tocaron `version-2` ni
  `v2-e8-videos` (masters del dueño sin commitear, a propósito).
- Siguen los tres simuladores `oraculo-26-5-*` del relevo 10 (los borra el dueño).
- Cuota al cierre: 5 h ~4 %, semanal ~46 %.
