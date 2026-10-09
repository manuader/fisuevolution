# SESION 2026-10-08 — v2, relevo 13: el ascensor y la barra con plan, E13b casi entera, el ranking con backend y las cinemáticas con arte

Relevo 13 de la ejecución autónoma de la 2.0 (sesión `local_8e9a945b`), despertado a las 19:03 por la
rutina `fisu-v2-relevo-a` con el `LOCK` libre. Controlador opus; implementadores sonnet en worktrees
manuales (`worktrees.nosync/v2i-<tarea>`); planificadores y revisores opus. Todo pasó por la rama de
integración **`v2i/integ-r13`**. Cerró con 0 subagentes en vuelo, a ~303k de contexto: la regla de 250k
(no arrancar tarea grande) se incumplió por no medir el contexto en cada borde (ver trampas).

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`4ab1817`**, pusheado; `rapido` VERDE: EK 605 · unit 816 + 1 declarado (`theOwnersTargetsAreMet`) · release 0 |
| `v2i/integ-r13` | **`a74d6e7`** = `4ab1817` + E13b T5 (cabina) + estos docs. **Sin `rapido`**: E13b T5 entró después del que dio verde |
| Progreso | **87 de 243 tareas activas (35,8 %)**; el denominador subió de 210 porque se sumaron E8b (12), E8c (10) y E13b (11), menos una salteada |

El `rapido` se corrió sobre `4ab1817` (E13b T9 era la última tarea integrada) mientras la revisión opus de
E13b T5 devolvía arreglos. Verde → `version-2` avanzó por fast-forward y se pusheó. La cabina (T5) se mergeó
a la rama de integración recién después, sin `rapido`: es el primer paso del relevo 14.

## Lo que se integró

### Planes (opus, sin compilar)

| Plan | Commit | Qué dejó |
|---|---|---|
| **P-E13b** el ascensor y la barra (ítems 13–14, prioridad alta del dueño) | `2560366` (merge `f395ac2`, filas en `db5b5de`) | 11 tareas, 14 dudas con default. No toca `RootView` ni `GameState`: `ElevatorRide` se monta en `FisuEvolutionApp`. Duda 1: la barra sale ya, sin esperar a E3b T4 |
| **P-E8b** las cinemáticas (lado Swift) | `f035a5d` (merge + filas `8ae35db`) | 12 tareas, incluye los ajustes de `video_assets.py` y los 18 loops. Ojo: ver "El fondo blanco" |
| **P-E8c** "Fusionar todo" encadenado | `85274f3` (merge + filas `448770c`) | 10 tareas. Un solo 🔥 (`BoardScene`); el `planMergeAll` real es `BoardChangePlanner` |

### Tareas

| Tarea | Commit | Oráculo y nota |
|---|---|---|
| **release-ops (base de la integración)** | `8eec356` | merge --no-ff de `v2/release-ops` (`367880a` mediación, `fb85f70` sesión): `releaseops` 13 tests; `admob sync-code --dry-run` "Sin cambios" |
| **E9b T6** `resetEpoch` y `resolveAcrossReset` | `8e50efa` + arreglos `cccde55` (merge `8d1eeeb`) | EK 569; `ResetEpochTests` 10; revisión opus |
| **E12 T6** `RankingState` (EK) | `97c15fa` + arreglos `ab3492a` | EK 599, 29 tests propios; revisión opus |
| **E12 T3** moderación (Deno) | `f61195b` | `supabase/test.sh` sql 23 · deno 52; SDK 0.131.0, deno 2.9.7 por brew |
| **E8 T6** visitantes y especiales | `d74f330` | 52 claves `npcs`, 13 MB; pipeline 65; tarea unit 60 |
| **E3b T5** renombre y `GameState+Projections` | `61a661d` | tarea unit 31 |
| **E13b T4** clips y cuadros de la cabina | `93a76cf` (merge `a8bc234`) | 4 recursos (~1,5 MB); sin despill; pipeline OK |
| **E12 T4** cuatro Edge Functions | `3ab325d` + arreglos `30cf56a` (merge `4404d21`) | `test.sh` sql 24 · deno 75; revisión opus |
| **E8b T7** `seenCinematics` | `4714671` (merge `65e2e2f`) | EK 604; revisión opus por el controlador: Approved |
| **E8b T1** `video_assets.py`: retrato arriba y magenta | `25c6b35` (merge `8dea80b`) | los 18 de croma miden sin error |
| **E12 T5** cron, propuesta de lista, `deploy.sh` | `27e9986` + `e9a2027` | `test.sh` sql 25 · deno 80; `deploy.sh` sin correr |
| **E13 T6** la Startup evoluciona dos tiers abajo o paga | `bc878cc` | tarea unit 53; catálogo (quitar 1, aplicar 2); revisión opus (plata): Approved |
| **E8b T2** retratos sobre blanco por conectividad | (merge en integ) | pipeline 80 OK; 29–51 s por loop |
| **E13b T1** el director del viaje | `8b090d4` (merge `806c19e`) | tarea unit 9 |
| **E13b T2** la placa colgante | `a7f6eea` (+ claves `c5ed8fa`) | tarea unit 8; `ElevatorLED` público; tocó `PanelFrames.swift` |
| **E13b T3** los sonidos del ascensor | `440e610` | 4 `.caf` (269 KB) sin escuchar |
| **E8b T3** los 18 loops y 3 cinemáticas | `2a6cb5e` | pipeline 82 OK; +10 MB de bundle; masters no versionados |
| **E13b T9** la Tienda sale de la barra | `98d7d9f` | tarea unit 89 + UI a mano (BottomMenu, ProgressiveTabs, HUDRedesign 8 en 26.5; Store 2 en 18.6); catálogo (quitar 1, aplicar 1) |
| **E13b T5** la cabina y la vista del viaje | `f008f85` + `d3d3b7c` + `6fb8e83` (merge `a74d6e7`) | tarea unit 23 + `ChestAnimationTests`; revisión opus; **sin `rapido`** |

Las tareas de E12 que no compilan la app (T3, T4, T5) corrieron con `supabase/test.sh` y no consumieron cupo
de simulador. Con T6 de E13 salió además la primera tanda de `catalogo.py quitar` (E13 T6 la creó en el
relevo 12; acá se usó por primera vez: quitar 1, aplicar 2).

## Revisiones opus y sus arreglos

- **E9b T6** — Approved con arreglos. **I1:** el camino de la misma época no acreditaba el ORO del perdedor
  (con tres dispositivos se perdía ORO y se rompía la asociatividad; preexistente). **I2:** el filtro no usaba
  `creditedPurchases` (duplicación de la v1). Arreglo `cccde55`: ayudante `unseenOro` en las dos ramas y un test
  de tres dispositivos en los tres órdenes.
- **E12 T6** — Approved con arreglos. **I1:** una partida vieja se volvía elegible por conflicto: la fase más
  avanzada sólo gana con el mismo `runId`. **I2:** `max` de `playedSeconds` entre partidas distintas. Arreglo
  `ab3492a`: `isSameGame` por `runId`, `max`/OR bajo ese guard y `CarriedSubmission.sealed`.
- **E12 T4** — Approved con arreglos. **I1:** `start-run` idempotente con `clientRunId` (se editaron las
  migraciones de T2). **I2:** Haiku después del chequeo de dueño (no gasta API en nombres ajenos). **I3:** los
  reportes sólo de jugadores con partida sellada. Arreglo `30cf56a` (+ lint dentro de `test.sh`).
- **E13 T6** — Approved sin arreglos (la plata se mira dos veces: lo reviso yo y lo reviso opus).
- **E8b T7** — la revisó el controlador (Approved): es una propiedad nueva en `meta.engagement`, no toca
  lógica de save.
- **E13b T5** — Approved con arreglos, cinco Important: **I1** el `body` creaba players; **I2** sin respaldo si
  el clip fallaba; **I3** el `expiry` no se cancelaba al viajar; **I4** Reduce Motion con video, que ahora usa la
  cabina vectorial con fades; **I5** el parpadeo, resuelto con dos vistas apiladas. Arreglo `6fb8e83`: lookups que
  no crean, respaldo vectorial si el item queda `.failed`, `cancelExpiry`, fades = `VectorCabin`, dos capas y
  thumbnails de a dos.

## Carries por tarea

- **E9b T6 → T7/T8:** el reset sube la época y lleva las compras; `OffersState.purchases` (E6a T1) debe cruzar en
  `resolveAcrossReset`; `seenCinematics` (E8b T7) también. Las compras no-ORO no cruzan el reset: documentarlo. Un
  build viejo que reescribe el save pierde la época (aviso al dueño). **E13 T3:** los campos de cuenta nuevos se
  suman a `resolveAcrossReset`.
- **E12 T6 → T8/T10/T11/T12:** el reenvío de `carriedSubmission` es idempotente (409 = hecho); `Phase` es
  `Codable` sintetizado, así que T10 lee `(try? …) ?? .legacy`; `pendingWork .start` antes del núcleo del
  tutorial (el start sólo tras `newGameStarted`); dos resets sin red pierden la llegada arrastrada. **E12 T7:**
  `RankingState.awaitingStart` guarda el `clientRunId`.
- **E12 T4 → T5/T16:** limpieza de `api_calls` y `players` y límite por IP (T5, hecho en parte); `prepare: false`
  en postgres (T16); `deploy.sh` y `haikuClassifier` sin probar contra la API real (T16 / dueño).
- **E12 T3:** `haikuClassifier` sin probar contra la API real; SDK fijado en 0.131.0.
- **E8 T6 → T7:** `assets_manifest.json` pasó a E8 T7 (en serie).
- **E8b T3:** el dueño mira `sp_contador_dios` (el saco blanco quedó comido: regenerar con otro color o fondo) y
  `sp_bug_simulacion` (sale chico). Masters no versionados (~41 MB). En un iPhone real (HEVC con alfa por
  hardware) y la memoria, a E8b T12 / E8 T10.
- **E8b T2 → T3:** mirar el cuello del lagarto (hecho: sin comerse). 29–51 s por loop escalando a 512 antes de
  recortar.
- **E13b T2:** `PanelFrames` (`MetalTone`, `PanelScrew`) pasaron a internos; `ui_elevator_spring` no tiene arte
  (resorte vectorial); las previews no se miraron (T8 saca capturas).
- **E13b T3:** el motor queda a −8,5 dB RMS (los otros, −17 a −24): bajarlo de volumen al reproducirlo (T6).
  `AudioManager.stop(.elevatorMotor)` al saltear.
- **E13b T5 → T6:** `prepare()` al abrir la placa y en `requestFromMap`; `release()` si se cierra sin viajar;
  montar `ElevatorRideView` con `.environment(gameState)` sólo con `phase != .idle`. La memoria del SE y el
  parpadeo siguen sin medir (T11, en device).
- **E13b T9:** queda `TabUnlockCondition.secondSession` sin uso; `sixTabsFitTheSE` lo rehace T10; hay
  comentarios "seis pantallas" ajenos a limpiar; carry a E3b T4: son cinco páginas.
- **E13 T6:** la Startup ahora aplica siempre que haya plata (cambio de conducta, aprobado en la revisión).
- **Los de la ola I y H siguen vigentes** (ver los docs de los relevos 11 y 12).

## El fondo blanco: el dueño cambió los loops a mitad de camino

A las 19:05 la sesión del dueño cambió los loops de Higgsfield de fondo croma a **fondo blanco** y movió los de
croma a `loops-croma-descartados/`. P-E8b (que se estaba escribiendo) ya los daba por croma, así que sumó una
tarea nueva, T2, que recorta el blanco **por conectividad** desde el borde (no por umbral: no se come el blanco
de adentro del personaje). El costo medido: 29–51 s por loop. Los 18 loops de croma que miden sin error en T1
quedan como respaldo.

## El solape con la sesión del dueño: `v2/e8-videos` hizo lo mismo en paralelo

**Lo primero que hay que reconciliar en el relevo 14.** Según la bandeja del dueño (`DUENO.md`, secciones "todo el
juego animado" y "primera tanda de videos lista"), **en paralelo a este relevo** una sesión del dueño integró los
mismos videos en la rama **`v2/e8-videos`** (base `0db7746`): `4164fed` (PLAN-v2 E8), `60126cb` (`video_assets.py`
con recorte de blanco y los kinds `objeto` y `cabina`) y `c739f2f` (27 piezas: 18 retratos, 4 de Paquete/Colchón,
2 de cabina, 3 cinemáticas, más `loops_manifest.json` con `portraits/objects/cabin/cinematics`).

Este relevo integró trabajo **solapado** en `version-2`/`integ-r13`: E13b T4 (la cabina, `video_assets.py ascensor`,
manifest con `cinematics.ascensor_*` y `stills`) y E8b T1–T3 (retrato arriba + magenta, blanco por conectividad,
los 18 loops y 3 cinemáticas, manifest). Son dos versiones de `video_assets.py`, de `loops_manifest.json` y de
`Resources/Loops` y `Resources/Cinematics`.

El dueño fijó además **dos reglas**:

1. **Sólo entra al juego lo marcado `va` en `video/revision.json`.** Los 18 retratos que E8b T3 integró **no
   pasaron por esa revisión**: hay que sacar del juego lo que no esté `va`.
2. **El lado Swift se planifica según la spec nueva** `Docs/superpowers/specs/2026-10-08-v2-e8-animaciones-design.md`
   (rama `v2/e8-animaciones-docs`): `VideoPlayerPool` de a lo sumo 3, `AnimatedArtView`/`LoopingVideoNode`,
   On-Demand Resources y los fps como gate. Puede **reemplazar parte del plan P-E8b (T4–T12)** y **tocar E13b T5/T6**
   (la cabina).

Por eso, en el relevo 14, **no se despachan E8b T4 en adelante ni E13b T6 hasta reconciliar** (ver `tasks.md` §4.1,
paso 1). Las ramas del dueño no se tocan.

## Oráculo

- `rapido` sobre **`4ab1817`: VERDE** — EK 605 · unit 816 + 1 declarado (`theOwnersTargetsAreMet`) · release 0.
  `version-2` avanzó por fast-forward y se pusheó.
- `v2i/integ-r13` (`a74d6e7`, suma E13b T5): **sin `rapido`**.
- Tareas: E8 T6 unit 60 · E3b T5 unit 31 · E13 T6 unit 53 · E13b T1 unit 9 · T2 unit 8 · T9 unit 89 (+ UI) · T5
  unit 23 + `ChestAnimationTests`. Backend: `supabase/test.sh` sql 25 · deno 80. Pipeline 82.
- El `completo --limpio` de E1 T16 es el de `c94f75f` (relevo 12); no se corrió uno nuevo. El siguiente `completo`
  va al cierre de E13b (T11).

## Decisiones de este relevo

- **No se mergea a `version-2` con un oráculo corriendo ahí**: E13b T5 esperó al `rapido` de `4ab1817` y entró
  a la rama de integración después.
- **Un solo escritor de `video_assets.py`:** E13b T4 (ascensor) va antes de E8b T1 (retrato).
- **El ascensor y la barra no esperan a E3b T4:** la barra de cinco sale ya (duda 1 de P-E13b).
- **Dos planes grandes (E8b, E8c) con un solo 🔥 cada uno** (`GameState` dos propiedades; `BoardScene`).
- **Masters de video fuera del repo** (~41 MB): no se versionan.

## Trampas nuevas

- **Dos sesiones integrando los mismos videos.** Mientras este relevo hacía E13b T4 y E8b T1–T3, la sesión del
  dueño armó `v2/e8-videos` con su propio `video_assets.py` y manifest. Antes de tocar un pipeline de arte,
  leer `DUENO.md` y `git branch -a` por ramas del dueño que lo toquen; y sólo entra al juego lo marcado `va`.
- **Medir el contexto en cada borde.** E13b T3 salió con el contexto ya en ~300k. La regla de 250k (no
  arrancar una tarea grande) no se cumplió porque nadie midió: el cierre fue forzado. Medir en cada borde, no al
  despachar.
- **Una base vieja duplica los archivos nuevos.** E13b T5 se hizo sobre `806c19e`, y para cuando volvió T2 había
  agregado `ElevatorLED` en otro archivo: duplicado. Se devolvió con "merge de integ, sacar el duplicado, usar
  `MetalTone`/`PanelScrew`". Los briefs de tareas que dependen de una hermana en vuelo traen el merge de la
  hermana antes de empezar.
- **Un agente puede avisar trabajo de fondo propio al terminar.** E8b T1 y E13b T1 lo hicieron: hay que
  preguntar y esperar a que cierren antes de borrar su worktree.
- **`Distribution/release/` y los masters crecen el repo sin avisar.** Los masters (+41 MB) quedaron fuera de git
  a propósito; los loops y las cinemáticas suman +10 MB al bundle (el doble de lo estimado).
- **`xcodegen generate` tras agregar recursos nuevos** (E13b T4): sin él el recurso no entra al target.
- **Los carries se pierden entre agentes.** El de "state de lookups" en `ElevatorCabin` (el `body` que crea
  players) pasó la primera revisión del implementador; lo vio opus. Las vistas con AVFoundation van a revisión
  opus siempre.

## Lo descartado

- Un `ElevatorLED` propio en la cabina (duplicado con T2): se usa el compartido.
- Los 18 loops con croma: quedaron como respaldo en `loops-croma-descartados/`, no como camino.
- El despill del key de la cabina: viraba el amarillo (E13b T4).
- Esperar a E3b T4 para sacar la Tienda de la barra: P-E13b la saca ya.

## Cierre

- Subagentes en vuelo: **0**. El `rapido` corrió en el worktree `v2i-integ-r13`; `version-2` quedó en `4ab1817`.
- Worktrees borrados en el relevo: `v2i-plan-e8`, `e8-t1…t5`, `e8-t8`, `plan-e12`, `e12-t1`, `e12-t2`, `plan-e13`,
  `e13-t1`, `fix-cofre`, `fix-despedir`, `fix-terminos`, `integ-r12` (16 en total, ≈ 13,9 GB), y durante el relevo
  los de cada tarea al integrarla. Quedan `version-2` (protegido), `v2-e12-plan` y `v2-release-ops` (de la
  sesión del dueño; no se tocan).
- Hojas de contacto de los loops en `build/e8b-contacto/` del checkout principal.
- Siguen los tres simuladores `oraculo-26-5-*` del relevo 10 (los borra el dueño).
- Cuota al cierre: 5 h 23 %, semanal 43 %.
