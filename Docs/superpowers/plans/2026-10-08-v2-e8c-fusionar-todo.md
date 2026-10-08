# E8c — La cadena animada de "Fusionar todo" · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que "Fusionar todo" (PLAN-v2 §2 y E2a) **se vea**: al comprarlo por ORO o ganarlo por
video, los pares del piso se funden **uno detrás del otro, en cadena rápida y sin cortes**, con un
contador "×2 ×3 …" que crece, un "plin" que sube de tono en cada eslabón y un remate al final; cada
**tier nuevo se celebra entero** (el reveal de siempre), porque el jugador está mirando. Un toque
**apura** la cadena (corta el reveal en curso y sigue), nunca la borra. Es la fila "La cadena animada
de Fusionar todo" de `tasks.md` §5 E8: "E2a la deja a E8; ningún plan la toma".

**Architecture:** el **plan** ya existe y no se toca: `BoardChangePlanner.planMergeAll` (E2a T6)
arma la secuencia y `GameState.enqueueMergeAll(onFloor:origin:)` (E2a T14) la encola en el embudo
de E1, donde **cada par se juega en su propio turno `.boardCelebration`**. Eso hoy anda (el botón
del panel de debug), pero no es una cadena: entre par y par la cola le da el turno a lo que esté
esperando (el logro del primer merge, el aviso de "ya podés contratar acá"), el ritmo es el de un
cambio suelto (0,35 s de entrada + 0,35 s de destaque por par: siete pares son ~8 s sin contar los
reveals), las fusiones del embudo **no suenan**, y un toque saltea un par por vez. E8c le suma tres
cosas chicas: (1) cada cambio del plan lleva su **eslabón** (`BoardChange.Chain`: id, índice,
largo), sellado por el planificador, así cualquier llamador (ORO de E6a, video de E13/E7b-b,
debug) hereda la cadena sin hacer nada; (2) la escena **conserva el turno** de un eslabón al
siguiente (`GameState.beginNextChainLink(after:)`, que renueva el reloj del watchdog con
`CelebrationQueue.renew`), con un **tempo** propio y puro (`MergeAllTempo`); y (3) la puesta en
escena: el contador, el tono que sube, el remate y el anuncio de VoiceOver. La lógica de plata no
se mueve: cada eslabón se aplica con el mismo `BoardChangeApplier` de siempre.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SpriteKit ·
SwiftUI (sólo el anuncio de AX) · AVFoundation (`AVAudioPlayer.rate`) · Core Haptics · XCUITest ·
XcodeGen (el `.xcodeproj` no se versiona) · Python 3 (`Tools/audio-synth/generate_audio.py`,
`Tools/v2/catalogo.py`).

**Fuente:** `Docs/PLAN-v2.md` §2 (fila "Fusionar todo (crítica)": "los tiers nuevos se celebran
igual, porque el jugador está mirando"), E2a (`:552-556`: "se anima en cadena rápida; un tier nuevo
se celebra"), E6 (`:903`: 20 ORO, 5/día), E7 (`:997`: el video `boost`), E8 (`:1541`: "la cadena de
Fusionar todo" va **por código**), E13 (`:1317`: "Fusionar todo por video" reemplaza a la Evolución
gratis) y la verificación (`:1607`: "Fusionar todo con un tier nuevo en el medio, que se celebra").
`tasks.md` §3 (calientes y tibios), §5 E2a (T6/T14 ✅), E6a T6, E7b-b T1/T2, E13 T2, E13b. El código
en `8ae35db`. Las decisiones del dueño de PLAN-v2 están **cerradas**; lo que el texto deja abierto
está en "Para el dueño / dudas", con un default que no frena.

**Rama de la épica:** `v2/e8-fusionar`, desde `version-2`. Cada tarea sale de su punta en un
worktree propio (manual, en `.claude/worktrees.nosync/v2i-e8c-tN`, mientras `.claude/worktrees` sea
un symlink: `tasks.md` §4.2) y el controlador integra de a una. Los IDs de `tasks.md` son
`E8c-T1` … `E8c-T10` (no chocan con `E8-T*` ni `E8b-T*`).

**Fuera de este plan** (ya planificado en otro lado, no se duplica):
- **Quién dispara** "Fusionar todo": por ORO, **E6a T6** (`Origin.oroShop`, tope 5/día, 20 ORO,
  `blocker == .nothingToDo` sin pares); por video en Regalos, **E13 T2** (`Origin.rewardedMergeAll`,
  el video `merge_all` de `rewarded_ads.json`, que reemplaza a `accelerate_evolution`); por video en
  la columna, **E7b-b T1/T2** (el mismo video de E13 T2). E8c funciona con el origen `.debug` y no
  espera a ninguno: cuando lleguen, la cadena ya está.
- **El perfil `.ads` del simulador** con "Fusionar todo": **E2b T6/T9**.
- **La lección** `.mergeAllVideo`: **E7b-b T5** / **E9b T1**.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning rompe
  el build. Nada de `Timer` para lógica de juego (regla 2 del HANDOFF): los tiempos de la cadena
  son `SKAction` encadenadas **por completion** (como `runBoardCelebration`), nunca por offsets
  calculados.
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate`** al agregar un archivo
  Swift, un `.caf` o un test, en el mismo paso en que se crea.
- **Ningún cambio del tablero se aplica en el acto** (regla de E1, repetida por E6a): la cadena es
  una sucesión de cambios del embudo, revalidados en su turno. E8c **no** agrega un camino que
  aplique fusiones por fuera de `confirmBoardChange` / `settleInFlightBoardChange`.
- **La plata no se toca**: ningún eslabón cambia lo que paga una fusión (el reintegro y el
  amortiguador de E2a viven en `TowerActions.applyMerge`, que el embudo ya usa). `pacing-sim` no se
  mueve. Si una tarea ve que necesita tocar `TowerActions`, `+Bonus` o `PlayerState`, para con
  `NEEDS_CONTEXT`.
- **Strings nuevos, es + en, por `Tools/v2/catalogo.py`** (formato canónico, trampa 29). La tarea
  escribe sus claves en `Tools/v2/claves-pendientes/e8c-tN.json`; **ninguna tarea de E8c es dueña
  del catálogo**: aplica en su worktree para correr sus tests, **commitea sólo el archivo de
  `claves-pendientes/`** y descarta el catálogo
  (`git checkout -- FisuEvolution/Resources/Localizable.xcstrings`). E8c suma **una** clave.
- **Los números de un texto salen del dato** (`%@` + `String(x)`, trampa 5). El "×3" del contador
  es un símbolo y un número armados con `String`, no una clave (no hay palabra que traducir).
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos** (trampa
  9a-bis). E8c no suma controles: el UI test lee los marcadores que ya existen (`board.units`,
  `board.revealed`, de `RootView`).
- **Reduce Motion**: sin rebote del contador, sin pulso del remate, destaque y deslizamiento al
  mínimo (como `runAssistedMerge`); los reveals siguen (ya respetan Reduce Motion).
- Código nuevo limpio y con pocos comentarios (regla del dueño); **el comentario que miente se
  corrige** en el commit que lo vuelve mentira (en `BoardChange.swift`: "E6 (por ORO) y E7b (por
  video) lo llaman"; en `BoardScene`: "Cubre navegar al piso, destacar el par…" del timeout).
- **Commits en español, estilo de la casa** (`feat(fusionar): …`, `feat(audio): …`,
  `test(fusionar): …`), **SIN `Co-Authored-By`**. Staging selectivo por archivo y
  `git diff --cached --stat` antes de cada commit.
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración, ledger,
  journal y `tasks.md`. Ningún subagente toca `Docs/`, `handoffs/`, el journal, `tasks.md` ni
  `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

```bash
Tools/v2/oraculo.sh tarea <Clases de FisuEvolutionTests>   # EconomyKit entero + build + esas clases
```

- `tarea` corre EconomyKit entero (ahí entran `MergeAllPlannerTests` y `CelebrationQueueTests`) y
  sólo las clases de `FisuEvolutionTests` que se le pasan. El `rapido` lo corre el controlador una
  vez por ola; el `completo` (UI en la matriz), al cerrar.
- Los **UI tests** que una tarea agrega se corren aislados con la **receta R** de
  `Docs/superpowers/plans/2026-10-07-v2-e4a-visitantes-eventos.md` ("Receta R"), con
  `-only-testing:FisuEvolutionUITests/<Clase>`, simulador propio por UDID que se apaga y borra.
- La tarea de audio corre además `cd Tools/audio-synth && python3 generate_audio.py --only
  sfx_merge_all_done` (o el modo que el script tenga para uno solo: mirar su `--help`); no cuenta
  como "compilando" para el tope de 3.
- ⚠️ "0 tests" con éxito no prueba nada: la salida tiene que nombrar las clases. Ante un rojo en
  masa, `uptime` y `ps aux | grep '[x]codebuild'` antes de culpar al código.
- `pacing-sim`: ninguna tarea lo mueve (cero economía).

## Las referencias de PLAN-v2, verificadas contra el árbol (`8ae35db`)

| Lo que cita el plan | Dónde está hoy | Qué significa para E8c |
|---|---|---|
| `TowerActions.planMergeAll(floor:)` (PLAN-v2 `:552`) | **no existe con ese nombre**: E2a T6 lo puso junto a sus hermanos, `BoardChangePlanner.planMergeAll(floorOrdinal:state:tower:tiers:floorTable:config:origin:)` (`BoardChange.swift:102-126`); planea sobre una copia, del par más bajo para arriba, nunca el par de carrera, nunca un ascenso sin lugar | **no se toca el algoritmo**: T1 sólo le hace sellar el eslabón a cada cambio |
| "pasa por el embudo `BoardChange` de E1" | `GameState.enqueueMergeAll(onFloor:origin:) -> Int` (`GameState+BoardChanges.swift:22-31`), **sin llamadores** fuera de `debugMergeAllOnVisibleFloor` (`+Debug:98`) y el botón `debug.e2a.mergeAll` (`DebugPanelView:135`) | E8c no le agrega llamadores de juego (son de E6a/E13/E7b-b): usa el de debug |
| "se anima en cadena rápida" | cada cambio es **un turno** `.boardCelebration` aparte: `BoardScene.startBoardCelebrationIfItsTurn` (`:367`) → `beginNextBoardChange` → `playBoardChange` (`:1080`: entrada `boardChangeBeat` 0,35 s, o `flightMaxDuration + 0,1` si viaja) → `performBoardChange` (destaque 0,35 s + `runAssistedMerge`, `assistedMergeSlide` 0,18 s) → `presentResolution(…, withinTurn: true)` (`:808`) → `finishBoardChangeTurn` (`:1160`) o `runBoardCelebration` → `celebrationFinished(.boardCelebration)` | T7: al terminar un eslabón la escena pide el siguiente **sin soltar el turno**, con el tempo de `MergeAllTempo` (T3) |
| "de a una" (la cola) | `CelebrationQueue.promoteIfIdle` elige por prioridad **entre lo pendiente**: al soltar el turno, `.boardCelebration` (3) todavía no se re-encoló (lo hace `syncCelebrations` después) y gana `.achievements` (6) o `.towerNotice` (6): lo pinea `BoardGestureTests` ("el primer merge trae su logro, que pasa antes que el tablero") | por eso la cadena **tiene que** conservar el turno (T5/T7); el logro y el aviso salen al final de la cadena |
| el watchdog | `CelebrationKind.boardCelebration.timeout` = 14 s **por ítem** (`CelebrationQueue.swift:66`) | una cadena de 19 eslabones con 4 reveals dura ~16 s: T2 suma `renew(_:)` y T5 lo llama en cada eslabón |
| "un tier nuevo se celebra" | `presentResolution` arma `PendingBoardCelebration` con `evolvedTo` y `runBoardCelebration` hace vuelo → `runEvolutionReveal` (flash + scrim, `hold` 1,5 s) → piso nuevo; `markRevealed(tier:)` al arrancar | **ya pasa** por eslabón; T7 lo conserva y encadena el siguiente desde su `finish` |
| el HUD durante la celebración | `celebrationHidesUI` = `.boardCelebration && boardCelebrationShowsSomethingNew`; `setBoardCelebrationShowsSomethingNew` **sólo prende** y `releasePayload(.boardCelebration)` la baja al soltar el turno (`+Celebrations:40-46`, `:211-218`) | conservando el turno, el HUD quedaría apagado desde el primer reveal hasta el final: T5 la baja en cada borde de eslabón (duda 3) |
| el toque | `BoardScene.touchesBegan` (`:647`): `skipCurrentCelebration()` pasado `skipFloor` 0,6 s → `releasePayload` → `settleInFlightBoardChange` (aplica en silencio) | con el turno conservado, un toque mataría **la cadena entera** (lo pendiente quedaría para el turno siguiente, con el logro en el medio): T8 lo cambia por "apurar" dentro de la cadena (duda 1) |
| el sonido de una fusión | la del jugador suena en `GameState+Actions.swift:182` (`.merge` o `.evolution`); **las del embudo no suenan** (`applyBoardChange` no llama a `audio`; la escena sólo hace `playHaptic(.merge)` en `:840`) | T4: `playBoardMergeFeedback(chainIndex:)` con el tono que sube; T7 lo llama |
| `AudioManager.play(_:)` | sin `rate`; `throttleWindow` 0,08 s por SFX (`:59`); `preloadSFX` construye los players | T4 suma `play(_:rate:)` con `enableRate` y el remate `sfx_merge_all_done` |
| `HapticsManager.Pattern` | `merge`, `purchase`, `error`, `evolution`, `rarity`… | T4 suma `.mergeAllFinale` |
| marcadores para el UI test | `board.units` y `board.revealed` (`RootView.swift:353-359`), los que lee `BoardChangeUITests` | T9 los reusa: no toca `RootView` |
| el fixture de UI del embudo | `--uitest-board-change` → `debugPlanBoardChange()` en `finishBootstrap` (`+Bootstrap:114`) | T9 suma `--uitest-merge-all` al lado |
| el piso del callejón | `economy.json`: `alley` tiers 1–4, capacidad 10 (15 con la perilla de E2a T4) | 8 Homeless en el callejón = **7 eslabones** (4 + 2 + 1) y tres tiers nuevos (2, 3, 4) sin salir del piso: es el fixture de T5, T7 y T9 |

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` (tibio) | `BoardChange.Chain` (`id`, `index`, `count`, `isLast`); `planMergeAll` lo sella; `replanned` lo conserva | 1 |
| `Packages/EconomyKit/Tests/EconomyKitTests/MergeAllPlannerTests.swift` | los eslabones del plan | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` (tibio) | `renew(_:)`: el ítem en pantalla reinicia su reloj | 2 |
| `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift` | el renew | 2 |
| `FisuEvolution/Scenes/MergeAllTempo.swift` (nuevo) | los tiempos de un eslabón (entrada, destaque, deslizamiento), el tono, el presupuesto | 3 |
| `FisuEvolutionTests/MergeAllTempoTests.swift` (nuevo) | | 3 |
| `FisuEvolution/Audio/AudioManager.swift` (tibio) | `SFX.mergeAllDone`, `play(_:rate:)` | 4 |
| `FisuEvolution/Managers/HapticsManager.swift` | `Pattern.mergeAllFinale` | 4 |
| `FisuEvolution/Game/State/GameState+Services.swift` | `playBoardMergeFeedback(chainIndex:evolved:)`, `playMergeAllFinale()` | 4 |
| `Tools/audio-synth/generate_audio.py`, `FisuEvolution/Resources/Audio/sfx_merge_all_done.caf` | el remate sintetizado | 4 |
| `FisuEvolution/Game/State/GameState+BoardChanges.swift` (tibio) | `beginNextChainLink(after:)`, `hurryChainLink()` | 5 |
| `FisuEvolution/Game/State/GameState+Celebrations.swift` (tibio) | `renewBoardTurnForNextLink()` | 5 |
| `FisuEvolution/Game/State/GameState+Debug.swift` (tibio) | `debugSeedMergeAll(homeless:)` (`#if DEBUG`) | 5 |
| `FisuEvolutionTests/MergeAllChainWiringTests.swift` (nuevo) | el turno de la cadena | 5 |
| `FisuEvolution/Scenes/Nodes/MergeAllComboNode.swift` (nuevo) | el contador "×N" y su remate | 6 |
| `FisuEvolutionTests/MergeAllComboNodeTests.swift` (nuevo) | | 6 |
| `FisuEvolution/Scenes/BoardScene.swift` (🔥) | la cadena conserva el turno y usa el tempo (T7); el toque apura, el contador, el remate y VoiceOver (T8) | 7, 8 |
| `FisuEvolutionTests/MergeAllChainSceneTests.swift` (nuevo) | la escena encadena, apura y cierra | 7, 8 |
| `FisuEvolution/Game/State/GameState+Bootstrap.swift` (tibio) | `--uitest-merge-all` | 9 |
| `FisuEvolutionUITests/MergeAllChainUITests.swift` (nuevo) | la cadena entera en el simulador, con y sin toques | 9 |

## Orden, olas y paralelismo

**Archivos calientes.** E8c toca **un solo 🔥 del run: `BoardScene.swift`** (T7 y T8, de a una y en
la ventana libre de la escena; hoy la tiene pendiente E13 T11 ⏳, y detrás E4b T1/T6/T9, E5b T3,
E6b T5). **No toca** `GameState.swift` (la cadena vive en el `BoardChange`: no hace falta una
propiedad nueva), `RootView.swift`, `ContentSystems.swift`, `+Bonus`, `PlayerState.swift`,
`TowerActions.swift`, `SettingsView.swift` ni `project.yml`. El catálogo va por snapshot.

| T | Qué | Archivos (🔥 / tibios) | Depende de | Revisión · modelo |
|---|---|---|---|---|
| 1 | el eslabón en el plan (EK) | `BoardChange.swift` (tibio), `MergeAllPlannerTests` | — (E2a T6 ✅) | **opus** (el embudo del tablero: la igualdad de `revalidate`) · sonnet |
| 2 | el reloj del turno se renueva (EK) | `CelebrationQueue.swift` (tibio), `CelebrationQueueTests` | — | sonnet · sonnet |
| 3 | el tempo de la cadena, puro | nuevos (`MergeAllTempo.swift`, `MergeAllTempoTests`) | — | ninguna · sonnet |
| 4 | el tono que sube y el remate | `AudioManager` (tibio), `HapticsManager`, `+Services`, `generate_audio.py`, 1 `.caf`, `AudioManagerTests` | — | ninguna · sonnet |
| 5 | el turno de la cadena en `GameState` | `+BoardChanges` (tibio), `+Celebrations` (tibio), `+Debug` (tibio), nuevo `MergeAllChainWiringTests` | T1, T2 | **opus** (el turno del tablero, el watchdog, el skip) · sonnet |
| 6 | el contador "×N" | nuevos (`MergeAllComboNode.swift`, `MergeAllComboNodeTests`); catálogo (snapshot, 1 clave) | — | ninguna · sonnet |
| 7 | la escena encadena sin soltar el turno | 🔥 `BoardScene`; nuevo `MergeAllChainSceneTests` | T3, T4, T5; ventana de `BoardScene` | **opus** (el tablero: turno, completions, abortos) · sonnet |
| 8 | el toque apura; contador, remate y VoiceOver | 🔥 `BoardScene`; `MergeAllChainSceneTests` | T6, T7 | **opus** (toques contra el turno) · sonnet |
| 9 | el fixture y el UI test | `+Bootstrap` (tibio), nuevo `MergeAllChainUITests` | T8 | sonnet · sonnet |
| 10 | cierre | `Docs/` (controlador) | T1–T9 | — |

```
Ola 1 (ya)        T1 ║ T2 ║ T3            (≤ 3 compilando)
Ola 2             T5 ║ T4 ║ T6            (T5 cuando T1 y T2 estén integradas)
Ola 3             T7                      (en la ventana de BoardScene)
Ola 4             T8
Ola 5             T9
Cierre            T10
```

**Reglas del paralelismo:**

1. **El camino a "lo que se ve"** es T1 → T5 → T7 → T8. T2, T3, T4 y T6 corren al costado.
2. **De a una sobre el mismo archivo** dentro de la épica: T7 → T8 (`BoardScene`,
   `MergeAllChainSceneTests`).
3. **Fuera de la épica, en serie** (funciones distintas, conflictos de texto chicos):
   - `BoardChange.swift` (EK): E13 T2 (`rewardedInstantMerge` → `rewardedMergeAll`), E6a T6
     (`oroShop`), E7b-b T1. Si E13 T2 entró antes, T1 de acá sólo rebasa; si entra después, sus
     `BoardChange(...)` no pasan `chain:` (el parámetro tiene default) y nada cambia.
   - `CelebrationQueue.swift`: E4b T1/T4, E6a T12, **E8b T8** (suma `.cinematic`): T2 es una
     función suelta, cualquier orden.
   - `+BoardChanges`: E13 T2, E6a T6, E7b-b T1, E4b T9, E8b T10, E12 T11. `+Celebrations`: E4b T1/T4,
     E6a T12, E8b T8, E12 T11. `+Debug`/`+Bootstrap`: E4b T1/T2/T4/T9, E8b T8/T10, E12 T11.
   - `AudioManager`: **E13b T3** (cuatro SFX y `stop(_:)`), E5b, E4b T6, E8b T9: en serie; si E13b
     T3 entró, T4 rebasa sobre su `enum SFX`.
   - `BoardScene` 🔥: E13 T11 (⏳, la moneda sobre quien genera), E4b T1/T6/T9, E5b T3, E6b T5.
4. Tope de **3 compilando** en todo el run (`tasks.md` §3).
5. **E8c no espera a ningún disparador** (E6a T6, E13 T2, E7b-b T2): con el sello en el
   planificador, el día que lleguen ya traen la cadena. Y ellos no esperan a E8c: sin T7, la
   cadena se juega como hoy (un turno por par, más lenta, con el logro en el medio).

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| EK: un estado y una torre con unidades | `try fxStateAndTower(units: ["a": 4])`, `fxTiers()`, `fxConfig()` | `Packages/EconomyKit/Tests/EconomyKitTests/` (los usa `MergeAllPlannerTests`) |
| `GameState` arrancado con el contenido real | `await makeGameState()` | `FisuEvolutionTests/Support/GameStateFixture.swift` |
| el turno del tablero | `syncCelebrations()`, `showing`, `celebrationFinished(_:)`, `skipCurrentCelebration()`, `tick(delta:)` (watchdog) | `+Celebrations`, `+FrameLoop` |
| los cambios | `pendingBoardChanges`, `inFlightBoardChange`, `beginNextBoardChange()`, `confirmBoardChange(id:)`, `settleInFlightBoardChange()`, `enqueueMergeAll(onFloor:origin:)` | `+BoardChanges` |
| una escena sin `SKView` | `BoardScene(gameState:)` + `scene.layoutBoard()` + `scene.update(_:)`; `debugIsPlayingBoardChange`, `debugHoldInHand(slot:)` | `BoardScene.swift` (`#if DEBUG`), patrón de `BoardGestureTests` |
| los logros que se cruzan | `debugSeedAchievements()`; el primer merge ya trae uno (`BoardGestureTests:193`) | `+Debug` |
| el piso a la vista | `visiblePlacements`, `visibleFloorOrdinal` | `GameState` |
| UI: unidades y tier revelado | `app.otherElements["board.units"].value`, `["board.revealed"].value` | `RootView`, patrón de `BoardChangeUITests` |

---

### Task 1: El eslabón en el plan

**Objetivo:** cada cambio que arma `planMergeAll` sabe que es parte de una cadena: cuál
(`chain.id`, el mismo para todo el plan), en qué lugar (`index`, desde 0) y de cuántos (`count`).
Replanear un eslabón (otros slots, misma intención) conserva su sello. Nada más cambia: los otros
planificadores dejan `chain` en `nil`.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/MergeAllPlannerTests.swift`

**Interfaces:**
- Produces: `BoardChange.Chain` (`public struct`, `Sendable, Equatable`: `id: UUID`, `index: Int`,
  `count: Int`, `isLast: Bool`); `BoardChange.chain: Chain?`; `BoardChange.init(id:kind:origin:chain:)`
  con `chain: Chain? = nil`.

**Oráculo:** `Tools/v2/oraculo.sh tarea BoardChangeWiringTests DebugEconomyKnobsTests BoardGestureTests`
**Revisión:** **opus** (la igualdad de `BoardChange` es la que compara `confirmBoardChange`) ·
**Modelo:** sonnet.

- [ ] **Step 0: Pararse en la base**

```bash
grep -n "public static func planMergeAll\|func replanned\|public init(id: UUID" Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift
grep -rn "BoardChange(" --include='*.swift' FisuEvolution Packages | grep -v "Tests" | head
```

Expected: `planMergeAll` en ~`:102`, `replanned` en ~`:50`, y los `BoardChange(` de los
planificadores (ninguno pasa `chain:`). Si `Origin` ya tiene `rewardedMergeAll` u `oroShop`, no
importa: no se tocan.

- [ ] **Step 1: Los tests, en rojo** (al final de `MergeAllPlannerTests`)

```swift
    @Test("cada cambio del plan es un eslabón de la misma cadena, en orden")
    func everyChangeIsALinkOfTheSameChain() throws {
        var fx = try fxStateAndTower(units: ["a": 4])
        fx.state.run.chosenCareerPath = "prog"
        let changes = plan(fx)
        let chains = changes.compactMap(\.chain)
        #expect(chains.count == changes.count)
        #expect(Set(chains.map(\.id)).count == 1)
        #expect(chains.map(\.index) == [0, 1, 2])
        #expect(chains.allSatisfy { $0.count == 3 })
        #expect(chains.map(\.isLast) == [false, false, true])
    }

    @Test("dos planes son dos cadenas")
    func twoPlansAreTwoChains() throws {
        let fx = try fxStateAndTower(units: ["a": 4])
        #expect(plan(fx).first?.chain?.id != plan(fx).first?.chain?.id)
    }

    @Test("replanear un eslabón con otros slots conserva el sello")
    func revalidationKeepsTheLink() throws {
        var fx = try fxStateAndTower(units: ["a": 3])
        let link = try #require(plan(fx).first)
        guard case let .merge(ordinal, typeId, source, _, _) = link.kind else { Issue.record("no es un merge"); return }
        // Se mueve el primero del par a un slot libre: el plan miró otro.
        let free = try #require(fx.tower.floors[ordinal].firstFreeSlot())
        fx.tower.floors[ordinal].slots[free] = typeId
        fx.tower.floors[ordinal].slots[source] = nil
        let replanned = try #require(BoardChangePlanner.revalidate(
            link, state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable
        ))
        #expect(replanned.kind != link.kind)
        #expect(replanned.chain == link.chain)
        #expect(replanned.id == link.id)
    }

    @Test("los cambios sueltos no son cadena")
    func singleChangesHaveNoChain() throws {
        var fx = try fxStateAndTower(units: ["a": 2])
        fx.state.run.chosenCareerPath = "prog"
        let auto = BoardChangePlanner.planAutoMerge(
            state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: .debug
        )
        #expect(auto?.chain == nil)
    }
```

Run: `swift test --package-path Packages/EconomyKit --filter MergeAllPlannerTests`
Expected: no compila (`chain`).

- [ ] **Step 2: El sello**

En `BoardChange`:

```swift
    /// Un eslabón de "Fusionar todo": la escena encadena los de la misma cadena
    /// en un solo turno, con su ritmo y su contador.
    public struct Chain: Sendable, Equatable {
        public let id: UUID
        public let index: Int
        public let count: Int

        public init(id: UUID, index: Int, count: Int) {
            self.id = id
            self.index = index
            self.count = count
        }

        public var isLast: Bool { index == count - 1 }
    }

    public let id: UUID
    public let kind: Kind
    public let origin: Origin
    public let chain: Chain?

    public init(id: UUID = UUID(), kind: Kind, origin: Origin, chain: Chain? = nil) {
        self.id = id
        self.kind = kind
        self.origin = origin
        self.chain = chain
    }
```

`replanned(_:)` pasa `chain: chain`. En `planMergeAll`, después del bucle (el largo recién se sabe
al final):

```swift
        let chainID = UUID()
        return plan.enumerated().map { index, change in
            BoardChange(id: change.id, kind: change.kind, origin: change.origin,
                        chain: Chain(id: chainID, index: index, count: plan.count))
        }
```

El doc de `planMergeAll` suma una línea: "Cada cambio lleva su eslabón (`chain`): la escena los
juega en un solo turno." En `GameState+BoardChanges.swift` **no** se toca nada en esta tarea, salvo
el comentario de `enqueueMergeAll` si ya miente (si E6a T6 / E13 T2 todavía no entraron, sigue
siendo cierto: no se toca).

- [ ] **Step 3: Verde**

Run: `swift test --package-path Packages/EconomyKit --filter MergeAllPlannerTests` → los 11 tests
(7 de antes + 4) en verde; después el oráculo de la tarea.

- [ ] **Step 4: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift Packages/EconomyKit/Tests/EconomyKitTests/MergeAllPlannerTests.swift
git diff --cached --stat
git commit -m "feat(fusionar): cada par de Fusionar todo sabe que es un eslabón de su cadena"
```

---

### Task 2: El reloj del turno se renueva

**Objetivo:** el ítem que está en pantalla puede reiniciar su reloj: el watchdog cuida **cada
eslabón** (14 s), no la cadena entera. Renovar otro kind, o con nada en pantalla, no hace nada.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift`

**Interfaces:**
- Produces: `CelebrationQueue.renew(_ kind: CelebrationKind)` (`public mutating`).

**Oráculo:** `Tools/v2/oraculo.sh tarea CelebrationWiringTests`
**Revisión:** sonnet · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo**

```swift
    @Test("renovar reinicia el reloj del que está en pantalla, y sólo el suyo")
    func renewRestartsTheClockOfTheCurrentOne() {
        var queue = CelebrationQueue()
        queue.enqueue(.boardCelebration)
        #expect(queue.tick(10) == nil)
        queue.renew(.boardCelebration)
        #expect(queue.elapsed == 0)
        #expect(queue.tick(10) == nil, "sin el renew, a los 20 s el watchdog lo habría cortado")
        queue.renew(.towerNotice)
        #expect(queue.elapsed == 10, "renovar a otro no toca el reloj")
        #expect(queue.tick(5) == .boardCelebration, "el watchdog sigue vivo")
    }

    @Test("renovar también vuelve a poner el piso del skip")
    func renewResetsTheSkipFloor() {
        var queue = CelebrationQueue()
        queue.enqueue(.boardCelebration)
        _ = queue.tick(1)
        queue.renew(.boardCelebration)
        #expect(queue.skip() == false, "recién renovado, un toque no lo saltea")
    }
```

Run: `swift test --package-path Packages/EconomyKit --filter CelebrationQueueTests` → no compila.

- [ ] **Step 2: `renew`**

Al lado de `finish(_:)`:

```swift
    /// El ítem en pantalla empieza de nuevo su reloj: lo usa una celebración
    /// hecha de partes (los eslabones de "Fusionar todo"), donde el watchdog
    /// cuida cada parte y no la suma.
    public mutating func renew(_ kind: CelebrationKind) {
        guard current == kind else { return }
        elapsed = 0
    }
```

El comentario de `timeout` de `.boardCelebration` ("Cubre navegar al piso, destacar el par…")
suma: "En una cadena, por eslabón (`renew`)."

- [ ] **Step 3: Verde y commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift
git commit -m "feat(cola): el ítem en pantalla puede renovar su reloj"
```

---

### Task 3: El tempo de la cadena, puro

**Objetivo:** los números de la cadena en un solo lugar y testeados: cuánto espera un eslabón antes
de arrancar (el primero, lo de siempre: viaje o pausa; los siguientes, casi nada), cuánto se
destaca el par, cuánto tarda en deslizarse, a qué tono suena, y el presupuesto: **siete eslabones
sin reveals entran en 3,5 s** (hoy, ~8 s). Con Reduce Motion, todo al mínimo. Sin SpriteKit.

**Files:**
- Create: `FisuEvolution/Scenes/MergeAllTempo.swift`
- Create: `FisuEvolutionTests/MergeAllTempoTests.swift`
- `xcodegen generate`

**Interfaces:**
- Produces: `struct MergeAllTempo: Equatable` (`init(reduceMotion:)`; `leadIn(index:travels:) ->
  TimeInterval`; `beat(index:)`; `slide(index:)`; `pitch(index:) -> Float`; `linkDuration(index:)`;
  `static let firstBeat`, `travelLeadIn`, `chainBeat`, `chainSlide`, `maxPitch`).

**Oráculo:** `Tools/v2/oraculo.sh tarea MergeAllTempoTests`
**Revisión:** ninguna · **Modelo:** sonnet.

- [ ] **Step 0:** `grep -n "boardChangeBeat\|assistedMergeSlide\|flightMaxDuration\|static func flightDuration" FisuEvolution/Scenes/BoardScene.swift`
  → 0,35 / 0,18 / 0,9 y la función estática interna. Los tres primeros son `private`: el tempo
  los **copia** con su nombre en el comentario (no se abren en `BoardScene`, que es 🔥 y no es de
  esta tarea); el test pinea contra `BoardScene.flightDuration`, que sí se ve.

- [ ] **Step 1: Los tests, en rojo**

```swift
import Testing
@testable import FisuEvolution

@Suite("Fusionar todo: el tempo de la cadena")
struct MergeAllTempoTests {
    let tempo = MergeAllTempo(reduceMotion: false)

    @Test("el primer eslabón entra como cualquier cambio; los siguientes, casi sin pausa")
    func onlyTheFirstLinkWaits() {
        #expect(tempo.leadIn(index: 0, travels: false) == MergeAllTempo.firstBeat)
        #expect(tempo.leadIn(index: 0, travels: true) >= BoardScene.flightDuration(floors: 9, totalFloors: 10))
        #expect(tempo.leadIn(index: 1, travels: false) < 0.1)
        #expect(tempo.leadIn(index: 3, travels: true) >= BoardScene.flightDuration(floors: 9, totalFloors: 10),
                "si el jugador se fue de piso a mitad de cadena, se vuelve volando")
    }

    @Test("siete eslabones sin reveals entran en 3,5 s, y el primero es el más lento")
    func sevenLinksFitTheBudget() {
        let total = (0..<7).map { tempo.linkDuration(index: $0) }.reduce(0, +)
        #expect(total <= 3.5)
        #expect(tempo.linkDuration(index: 0) > tempo.linkDuration(index: 1))
        #expect(tempo.beat(index: 1) < 0.35, "más rápido que el destaque de un cambio suelto")
        #expect(tempo.slide(index: 1) <= 0.18)
    }

    @Test("el tono sube eslabón a eslabón y se planta en el techo")
    func pitchClimbsAndCaps() {
        #expect(tempo.pitch(index: 0) == 1)
        #expect(tempo.pitch(index: 1) > tempo.pitch(index: 0))
        #expect(tempo.pitch(index: 30) == MergeAllTempo.maxPitch)
        #expect((0..<30).map(tempo.pitch).allSatisfy { $0 <= MergeAllTempo.maxPitch })
    }

    @Test("con Reduce Motion, sin pausas ni deslizamiento")
    func reduceMotionCollapses() {
        let calm = MergeAllTempo(reduceMotion: true)
        #expect(calm.leadIn(index: 0, travels: true) <= 0.2)
        #expect(calm.slide(index: 0) <= 0.01)
        #expect((0..<7).map { calm.linkDuration(index: $0) }.reduce(0, +) <= 1.5)
    }
}
```

- [ ] **Step 2: `MergeAllTempo.swift`**

```swift
import Foundation

/// El ritmo de "Fusionar todo": el primer par entra como cualquier cambio del
/// tablero y los siguientes se funden casi sin pausa, con un tono que sube.
struct MergeAllTempo: Equatable {
    /// `BoardScene.boardChangeBeat`: la pausa de un cambio suelto.
    static let firstBeat: TimeInterval = 0.35
    /// `BoardScene.flightMaxDuration` + 0,1: volver al piso de la cadena.
    static let travelLeadIn: TimeInterval = 1.0
    static let chainLeadIn: TimeInterval = 0.04
    static let chainBeat: TimeInterval = 0.12
    /// `BoardScene.assistedMergeSlide`.
    static let firstSlide: TimeInterval = 0.18
    static let chainSlide: TimeInterval = 0.14
    /// El "plin" sube un semitono por eslabón hasta una sexta (rate de AVAudioPlayer).
    static let semitone: Float = 1.059_463
    static let maxPitch: Float = 1.5

    let reduceMotion: Bool

    func leadIn(index: Int, travels: Bool) -> TimeInterval {
        if reduceMotion { return travels ? 0.2 : 0.05 }
        if travels { return Self.travelLeadIn }
        return index == 0 ? Self.firstBeat : Self.chainLeadIn
    }

    func beat(index: Int) -> TimeInterval {
        if reduceMotion { return 0.05 }
        return index == 0 ? Self.firstBeat : Self.chainBeat
    }

    func slide(index: Int) -> TimeInterval {
        if reduceMotion { return 0.01 }
        return index == 0 ? Self.firstSlide : Self.chainSlide
    }

    func pitch(index: Int) -> Float {
        min(Self.maxPitch, pow(Self.semitone, Float(max(0, index))))
    }

    /// Lo que tarda un eslabón sin reveal, sin viajar: el presupuesto.
    func linkDuration(index: Int) -> TimeInterval {
        leadIn(index: index, travels: false) + beat(index: index) + slide(index: index)
    }
}
```

Con los números de arriba: el primero 0,88 s y cada uno de los otros 0,30 s → siete = 2,68 s
(≤ 3,5); con Reduce Motion, 0,11 s cada uno. Si el test de `travelLeadIn` falla porque
`flightDuration` cambió, se sube `travelLeadIn`, no se baja el test.

- [ ] **Step 3: Verde y commit**

```bash
/opt/homebrew/bin/xcodegen generate
git add FisuEvolution/Scenes/MergeAllTempo.swift FisuEvolutionTests/MergeAllTempoTests.swift
git commit -m "feat(fusionar): el tempo de la cadena — el primero entra, los demás vuelan"
```

---

### Task 4: El tono que sube y el remate

**Objetivo:** las fusiones del embudo suenan (hoy son mudas): el "plin" de siempre (`sfx_merge`, o
`sfx_evolution` si trae un tier nuevo) a un `rate` que sube eslabón a eslabón; al cerrar una cadena
de dos o más, un remate corto (`sfx_merge_all_done`: un acorde mayor que sube, ~0,6 s) con su
háptico (`.mergeAllFinale`: tres golpes que crecen). Sin escena: lo llamará T7/T8.

**Files:**
- Modify: `FisuEvolution/Audio/AudioManager.swift`, `FisuEvolution/Managers/HapticsManager.swift`,
  `FisuEvolution/Game/State/GameState+Services.swift`, `Tools/audio-synth/generate_audio.py`
- Create: `FisuEvolution/Resources/Audio/sfx_merge_all_done.caf`
- Modify: `FisuEvolutionTests/AudioManagerTests.swift`
- `xcodegen generate` (el `.caf` nuevo)

**Interfaces:**
- Produces: `AudioManager.SFX.mergeAllDone`; `AudioManager.play(_:rate:)` (`rate` 0,5–2; `play(_:)`
  queda como `play(_:rate: 1)`); `HapticsManager.Pattern.mergeAllFinale`;
  `GameState.playBoardMergeFeedback(chainIndex: Int?, evolved: Bool)`,
  `GameState.playMergeAllFinale()`.

**Oráculo:** `Tools/v2/oraculo.sh tarea AudioManagerTests AudioWiringTests`
**Revisión:** ninguna · **Modelo:** sonnet.

- [ ] **Step 0:** `grep -n "case elevatorDing\|func play(_ sfx\|enableRate\|preloadSFX" FisuEvolution/Audio/AudioManager.swift`
  y `grep -n "^def sfx_\|^SFX = {\|\"sfx_" Tools/audio-synth/generate_audio.py | tail -20`. Si E13b
  T3 ya sumó sus cuatro SFX y `stop(_:)`, se suma detrás de ellos. `AudioManagerTests` cuenta "los
  diez SFX" en el texto de un test: el número pasa a salir de `SFX.allCases.count` si el texto lo
  nombra (no cambiar el `#expect`, que ya compara contra `allCases`).

- [ ] **Step 1: Los tests, en rojo** (`AudioManagerTests`)

```swift
    @Test("el remate de Fusionar todo existe en el bundle y se precarga")
    func mergeAllFinaleIsBundled() async {
        let audio = AudioManager()
        await audio.preloadSFX()
        #expect(audio.preparedSFX.contains(.mergeAllDone))
    }

    @Test("play con rate deja el player con rate habilitado y el rate pedido, acotado")
    func playWithRateSetsTheRate() async {
        let audio = AudioManager()
        await audio.preloadSFX()
        audio.play(.merge, rate: 1.3)
        #expect(audio.debugRate(of: .merge) == 1.3)
        audio.play(.coin, rate: 9)
        #expect(audio.debugRate(of: .coin) == 2, "AVAudioPlayer acepta 0,5–2")
    }
```

(`debugRate(of:)` es `#if DEBUG`, al lado de `preparedSFX`: devuelve `sfxPlayers[sfx]?.rate`. Si
el volumen de SFX del test es 0, `play` sale antes: el test pone `audio.sfxVolume = 1` primero, o
usa el mismo truco que el test de "sin precarga" de la suite.)

- [ ] **Step 2: El remate sintetizado**

En `generate_audio.py`, al lado de `sfx_merge`:

```python
def sfx_merge_all_done():
    """Remate de Fusionar todo ~600 ms: acorde mayor que sube (C5-E5-G5-C6) y brillo."""
    dur = 0.600
    buf = [0.0] * int(dur * SR)
    for i, f in enumerate([523.25, 659.26, 783.99, 1046.5]):
        t0 = 0.06 * i
        render_tone(buf, t0, dur - t0, f, "square", 0.45, env_perc(dur - t0, attack=0.004, curve=3.5),
                    detune_cents=(-6.0 if i % 2 else 6.0))
    render_tone(buf, 0.24, dur - 0.24, glide(2093.0, 2637.0, dur - 0.24), "sine", 0.25,
                env_perc(dur - 0.24, attack=0.01, curve=3.0))
    return buf
```

y `"sfx_merge_all_done": sfx_merge_all_done,` en el dict `SFX`. Correr el script para ese solo
SFX (mirar `--help`; si no hay modo de uno, correrlo entero y **commitear sólo el `.caf` nuevo**:
`git status` no debe mostrar los otros `.caf` modificados; si cambian por no determinismo,
`git checkout --` de esos). Escuchar el resultado con `afplay` antes de seguir.

- [ ] **Step 3: `AudioManager`, `HapticsManager`, `+Services`**

- `case mergeAllDone = "sfx_merge_all_done"` con un doc de una línea.
- `play(_ sfx: SFX, rate: Float = 1)`: al construir el player, `player.enableRate = true` **antes**
  de `prepareToPlay` (también en `preloadSFX`); en cada play `player.rate = min(2, max(0.5, rate))`.
  El `throttleWindow` no cambia (0,08 s: los eslabones van a ≥ 0,3 s).
- `HapticsManager`: `case mergeAllFinale` → tres `transient` en 0 / 0,08 / 0,18 s con intensidad
  0,5 / 0,7 / 1,0 y sharpness 0,5 / 0,6 / 0,8.
- `GameState+Services`:

```swift
    /// Las fusiones que no hizo el jugador también suenan; en "Fusionar todo"
    /// el plin sube de tono eslabón a eslabón.
    func playBoardMergeFeedback(chainIndex: Int?, evolved: Bool) {
        let rate = chainIndex.map { MergeAllTempo(reduceMotion: false).pitch(index: $0) } ?? 1
        audio?.play(evolved ? .evolution : .merge, rate: evolved ? 1 : rate)
        haptics?.play(.merge)
    }

    func playMergeAllFinale() {
        audio?.play(.mergeAllDone)
        haptics?.play(.mergeAllFinale)
    }
```

(El háptico `.merge` que hoy hace la escena en `presentResolution` pasa a esta función en T7: no se
duplica.)

- [ ] **Step 4: Verde y commit**

```bash
/opt/homebrew/bin/xcodegen generate
git add FisuEvolution/Audio/AudioManager.swift FisuEvolution/Managers/HapticsManager.swift \
  FisuEvolution/Game/State/GameState+Services.swift Tools/audio-synth/generate_audio.py \
  FisuEvolution/Resources/Audio/sfx_merge_all_done.caf FisuEvolutionTests/AudioManagerTests.swift
git commit -m "feat(audio): el plin de Fusionar todo sube de tono y la cadena cierra con un remate"
```

---

### Task 5: El turno de la cadena en `GameState`

**Objetivo:** que la escena pueda pedir el eslabón siguiente **dentro del mismo turno**: si lo
próximo en la fila es de la misma cadena y el tablero sigue a la vista, arranca (revalidado como
siempre), el watchdog vuelve a cero y la bandera de "algo nuevo" se recalcula para ese eslabón (el
HUD vuelve entre reveal y reveal). Si no —una hoja tapó el tablero, la fila cambió—, `nil`, y la
escena suelta el turno como hoy: lo que quedó de la cadena se juega en el turno siguiente. Y
"apurar": asentar en silencio el eslabón en vuelo sin soltar el turno. Más el fixture de debug que
usan esta tarea, T7 y T9.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+BoardChanges.swift`
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift`
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift`
- Create: `FisuEvolutionTests/MergeAllChainWiringTests.swift`
- `xcodegen generate`

**Interfaces:**
- Consumes: T1 (`BoardChange.chain`), T2 (`CelebrationQueue.renew`).
- Produces: `GameState.beginNextChainLink(after: BoardChange.Chain) -> BoardChange?`;
  `GameState.hurryChainLink()`; `GameState.renewBoardTurnForNextLink()` (en `+Celebrations`, junto
  a `publishCelebration`, que es privada); `GameState.debugSeedMergeAll(homeless: Int) -> Int`
  (`#if DEBUG`: completa el callejón hasta `homeless` Homeless y encola "Fusionar todo" con
  `.debug`; devuelve cuántos eslabones).

**Oráculo:** `Tools/v2/oraculo.sh tarea MergeAllChainWiringTests BoardChangeWiringTests CelebrationWiringTests BoardGestureTests DebugEconomyKnobsTests`
**Revisión:** **opus** (el turno del tablero: un error acá congela la cola o se come una
celebración) · **Modelo:** sonnet.

- [ ] **Step 0: Pararse en la base**

```bash
grep -n "func beginNextBoardChange\|func settleInFlightBoardChange\|func enqueueMergeAll" FisuEvolution/Game/State/GameState+BoardChanges.swift
grep -n "private func publishCelebration\|case .boardCelebration:" FisuEvolution/Game/State/GameState+Celebrations.swift
grep -n "public struct Chain\|func renew" Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift
```

Si T1 o T2 no están en la base, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo** (`FisuEvolutionTests/MergeAllChainWiringTests.swift`)

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Fusionar todo: el turno de la cadena")
@MainActor
struct MergeAllChainWiringTests {
    /// Ocho Homeless en el callejón: siete eslabones (4 + 2 + 1) y tres tiers nuevos.
    private func chainOnTheBoard() async throws -> (GameState, Int) {
        let gameState = await makeGameState()
        let links = gameState.debugSeedMergeAll(homeless: 8)
        gameState.syncCelebrations()
        return (gameState, links)
    }

    /// Lo que hace la escena con un eslabón: arrancarlo y confirmarlo.
    private func playLink(_ gameState: GameState, _ change: BoardChange) {
        _ = gameState.confirmBoardChange(id: change.id)
    }

    @Test("el fixture arma la cadena del callejón")
    func theFixtureSeedsSevenLinks() async throws {
        let (gameState, links) = try await chainOnTheBoard()
        #expect(links == 7)
        #expect(gameState.pendingBoardChanges.compactMap(\.chain?.index) == Array(0..<7))
        #expect(gameState.showing == .boardCelebration)
    }

    @Test("los siete eslabones se juegan en un solo turno, y el logro espera al final")
    func theWholeChainIsOneTurn() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        var change = try #require(gameState.beginNextBoardChange())
        var played = 0
        while true {
            playLink(gameState, change)
            played += 1
            #expect(gameState.showing == .boardCelebration, "eslabón \(played): nadie le gana el turno")
            guard let chain = change.chain, let next = gameState.beginNextChainLink(after: chain) else { break }
            #expect(next.chain?.id == chain.id)
            #expect(next.chain?.index == chain.index + 1)
            change = next
        }
        #expect(played == 7)
        #expect(gameState.pendingBoardChanges.isEmpty)
        let homeless = gameState.player?.run.units["homeless"] ?? 0
        #expect(homeless == 0)
        #expect(gameState.player?.run.units["cartonero"] == 1)
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.showing == .achievements || gameState.showing == .boardCelebration,
                "el logro del primer merge sale recién ahora (o la red revela antes)")
    }

    @Test("el watchdog cuida cada eslabón, no la cadena")
    func theWatchdogIsPerLink() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        var change = try #require(gameState.beginNextBoardChange())
        for _ in 0..<3 {
            for _ in 0..<10 { gameState.tick(delta: 1) }
            #expect(gameState.inFlightBoardChange == change, "a los 10 s de un eslabón, sigue en vuelo")
            playLink(gameState, change)
            change = try #require(gameState.beginNextChainLink(after: try #require(change.chain)))
        }
        #expect(gameState.showing == .boardCelebration)
    }

    @Test("una hoja que tapa el tablero corta la cadena; el resto se juega en el turno siguiente")
    func aSheetBreaksTheChainAndItResumes() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        let first = try #require(gameState.beginNextBoardChange())
        playLink(gameState, first)
        gameState.uiCoversBoard = true
        #expect(gameState.beginNextChainLink(after: try #require(first.chain)) == nil)
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.pendingBoardChanges.count == 6)
        gameState.uiCoversBoard = false
        gameState.syncCelebrations()
        if gameState.showing == .achievements { gameState.celebrationFinished(.achievements) }
        let resumed = try #require(gameState.beginNextBoardChange())
        #expect(resumed.chain?.index == 1, "el contador sigue donde quedó")
    }

    @Test("si lo próximo no es de la cadena, el turno se suelta")
    func aForeignChangeEndsTheTurn() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        let first = try #require(gameState.beginNextBoardChange())
        let foreign = BoardChange(kind: .arrival(typeId: "homeless"), origin: .debug)
        gameState.pendingBoardChanges.insert(foreign, at: 0)
        playLink(gameState, first)
        #expect(gameState.beginNextChainLink(after: try #require(first.chain)) == nil)
    }

    @Test("entre eslabones el HUD vuelve: la bandera de algo nuevo es de cada uno")
    func theHUDComesBackBetweenLinks() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        var change = try #require(gameState.beginNextBoardChange())
        // El primer eslabón trae al Trapito (tier 2, nuevo): apaga el HUD.
        #expect(gameState.celebrationHidesUI)
        gameState.markRevealed(tier: 2)
        playLink(gameState, change)
        // El segundo es otro Trapito: nada nuevo.
        change = try #require(gameState.beginNextChainLink(after: try #require(change.chain)))
        #expect(gameState.celebrationHidesUI == false)
    }

    @Test("apurar asienta el eslabón en vuelo sin soltar el turno")
    func hurrySettlesWithoutReleasing() async throws {
        let (gameState, _) = try await chainOnTheBoard()
        let first = try #require(gameState.beginNextBoardChange())
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.hurryChainLink()
        #expect(gameState.inFlightBoardChange == nil)
        #expect(gameState.player?.run.totalUnits == units - 1)
        #expect(gameState.showing == .boardCelebration)
        #expect(gameState.beginNextChainLink(after: try #require(first.chain))?.chain?.index == 1)
    }
}
```

(Si el fixture del arranque no deja **un** Homeless en el callejón, `debugSeedMergeAll` igual
completa hasta 8; el `#expect(links == 7)` es el que avisa si el contenido cambió: se ajusta el
número, no se borra el test. Los tiers 2–4 del callejón son de `economy.json`: Trapito,
Limpiavidrios, Cartonero.)

Run: oráculo de la tarea → no compila.

- [ ] **Step 2: `+Celebrations`**

```swift
    /// El eslabón siguiente de "Fusionar todo" sigue en el mismo turno: el reloj
    /// vuelve a cero y la bandera de "algo nuevo" pasa a ser la suya (la del
    /// eslabón anterior ya se vio: si sobreviviera, el HUD quedaría apagado
    /// hasta el final de la cadena).
    func renewBoardTurnForNextLink() {
        guard celebrations.current == .boardCelebration else { return }
        celebrations.renew(.boardCelebration)
        boardCelebrationShowsSomethingNew = false
        publishCelebration()
    }
```

- [ ] **Step 3: `+BoardChanges`**

```swift
    /// El eslabón siguiente de la misma cadena, en el mismo turno. `nil` si el
    /// tablero dejó de estar a la vista o lo próximo es otra cosa: la escena
    /// suelta el turno y lo que queda se juega en el siguiente.
    func beginNextChainLink(after chain: BoardChange.Chain) -> BoardChange? {
        guard !chain.isLast, inFlightBoardChange == nil, boardIsVisibleForChanges,
              celebrations.current == .boardCelebration,
              pendingBoardChanges.first?.chain?.id == chain.id
        else { return nil }
        renewBoardTurnForNextLink()
        return beginNextBoardChange()
    }

    /// El toque dentro de una cadena: el eslabón en vuelo se asienta en
    /// silencio y el turno sigue.
    func hurryChainLink() {
        settleInFlightBoardChange()
    }
```

⚠️ `beginNextBoardChange` descarta los inválidos de adelante y puede terminar arrancando el primer
**válido**, que ya no sea de la cadena (los dos eslabones restantes quedaron inválidos porque el
jugador fusionó a mano en el medio): se acepta, es un cambio del tablero en el turno del tablero.
La escena decide el tempo por `next.chain`, así que lo juega como un cambio suelto.

`enqueueMergeAll`: el comentario suma "Cada par es un eslabón (`chain`): la escena los juega en un
solo turno."

- [ ] **Step 4: `+Debug`** (dentro del `#if DEBUG` que ya tiene `debugMergeAllOnVisibleFloor`)

```swift
    /// El callejón con `homeless` Homeless y "Fusionar todo" encolado: la cadena
    /// entera, con tres tiers nuevos, sin salir del piso.
    @discardableResult
    func debugSeedMergeAll(homeless count: Int) -> Int {
        guard let content, var player, var tower else { return 0 }
        let present = tower.placements(onFloor: 0).filter { $0.typeId == "homeless" }.count
        for _ in present..<max(present, count) {
            guard let slot = tower.floors[0].firstFreeSlot() else { break }
            tower.floors[0].slots[slot] = "homeless"
            player.run.units["homeless", default: 0] += 1
        }
        player.run.markSeen("homeless")
        self.player = player
        self.tower = tower
        bumpBoard()
        setVisibleFloor(0)
        return enqueueMergeAll(onFloor: 0, origin: .debug)
    }
```

(`setVisibleFloor` existe en `+Tower`; si su firma cambió, usar la que haya. La capacidad del
callejón es 10: 8 entran siempre.)

- [ ] **Step 5: Verde y commit**

```bash
/opt/homebrew/bin/xcodegen generate
git add FisuEvolution/Game/State/GameState+BoardChanges.swift FisuEvolution/Game/State/GameState+Celebrations.swift \
  FisuEvolution/Game/State/GameState+Debug.swift FisuEvolutionTests/MergeAllChainWiringTests.swift
git commit -m "feat(fusionar): la cadena se juega en un solo turno del tablero"
```

---

### Task 6: El contador "×N"

**Objetivo:** un nodo chico de SpriteKit que la escena cuelga arriba del piso: aparece en el
segundo eslabón ("×2"), late con cada uno ("×3", "×4"…), y al cerrar la cadena hace un último pulso
más grande y se va. Con Reduce Motion, cambia el número sin rebote. Más el texto del anuncio de
VoiceOver del final (la única clave de E8c).

**Files:**
- Create: `FisuEvolution/Scenes/Nodes/MergeAllComboNode.swift`
- Create: `FisuEvolutionTests/MergeAllComboNodeTests.swift`
- Create: `Tools/v2/claves-pendientes/e8c-t6.json`
- `xcodegen generate`

**Interfaces:**
- Produces: `final class MergeAllComboNode: SKNode` (`init(reduceMotion:)`; `show(link: BoardChange.Chain)`;
  `finish(completion:)`; `text: String?` para los tests; `static func announcement(merges: Int) -> String`;
  `static let nodeName = "mergeAllCombo"`).

**Oráculo:** `Tools/v2/oraculo.sh tarea MergeAllComboNodeTests LocalizationCompletenessTests`
**Revisión:** ninguna · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo**

```swift
import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("Fusionar todo: el contador")
@MainActor
struct MergeAllComboNodeTests {
    private func link(_ index: Int, of count: Int) -> BoardChange.Chain {
        BoardChange.Chain(id: UUID(), index: index, count: count)
    }

    @Test("el primer eslabón no muestra nada; del segundo en adelante, ×N")
    func countsFromTheSecondLink() {
        let combo = MergeAllComboNode(reduceMotion: true)
        combo.show(link: link(0, of: 4))
        #expect(combo.text == nil)
        #expect(combo.alpha == 0)
        combo.show(link: link(1, of: 4))
        #expect(combo.text == "×2")
        combo.show(link: link(3, of: 4))
        #expect(combo.text == "×4")
    }

    @Test("con movimiento, cada eslabón late; con Reduce Motion, no")
    func pulsesOnlyWithMotion() {
        let lively = MergeAllComboNode(reduceMotion: false)
        lively.show(link: link(1, of: 3))
        #expect(lively.action(forKey: MergeAllComboNode.pulseKey) != nil)
        let calm = MergeAllComboNode(reduceMotion: true)
        calm.show(link: link(1, of: 3))
        #expect(calm.action(forKey: MergeAllComboNode.pulseKey) == nil)
    }

    @Test("el anuncio dice cuántas fusiones hubo, con el número del dato")
    func announcementCarriesTheCount() {
        #expect(MergeAllComboNode.announcement(merges: 7).contains("7"))
    }
}
```

- [ ] **Step 2: El nodo**

- Un `SKLabelNode(fontNamed: "AvenirNext-Heavy")` (la fuente de los carteles de la escena,
  `BoardScene.swift:1326`), 34 pt, crema de la paleta (`PaletteCream` → `SKColor`, como los otros
  rótulos de la escena; si no hay puente, `SKColor(white: 1, alpha: 1)` con sombra), con una
  sombra ink (un segundo label desplazado 2 pt, `PaletteInk` al 60 %).
- `name = nodeName`, `zPosition = 180` (debajo del scrim del reveal, 195: el reveal lo tapa).
- `show(link:)`: `index == 0` → `alpha = 0`, `text = nil`. Si no, `text = "×\(index + 1)"`,
  `alpha = 1`, y con movimiento `run(.sequence([.scale(to: 1.25, duration: 0.06), .scale(to: 1.0,
  duration: 0.1)]), withKey: pulseKey)`.
- `finish(completion:)`: con movimiento, `scale 1.5` + `fadeOut` en 0,35 s; sin, `fadeOut` 0,2 s;
  después `removeFromParent()` y `completion()`. Si nunca se mostró (cadena de 1), completa en el
  acto.
- `announcement(merges:)`: `String(format: String(localized: "merge_all.chain.done %@"), String(merges))`.

- [ ] **Step 3: La clave** (`Tools/v2/claves-pendientes/e8c-t6.json`, formato de `catalogo.py`)

```json
{
  "merge_all.chain.done %@": {"es": "Fusionar todo: %@ fusiones", "en": "Merge all: %@ merges"}
}
```

Aplicar en el worktree (`python3 Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e8c-t6.json`),
correr el oráculo, y **descartar el catálogo** antes del commit.

- [ ] **Step 4: Verde y commit**

```bash
/opt/homebrew/bin/xcodegen generate
git checkout -- FisuEvolution/Resources/Localizable.xcstrings
git add FisuEvolution/Scenes/Nodes/MergeAllComboNode.swift FisuEvolutionTests/MergeAllComboNodeTests.swift Tools/v2/claves-pendientes/e8c-t6.json
git commit -m "feat(fusionar): el contador ×N de la cadena"
```

---

### Task 7: La escena encadena sin soltar el turno

**Objetivo:** en `BoardScene`, cuando termina un eslabón (sin reveal: `finishBoardChangeTurn`; con
reveal: el `finish` de `runBoardCelebration`), la escena pide `beginNextChainLink(after:)` y, si hay,
lo reproduce **en el mismo turno**; si no, suelta el turno como hoy. Cada eslabón usa el tempo de
`MergeAllTempo` (entrada, destaque, deslizamiento) y suena con `playBoardMergeFeedback`. Los
reveals de tiers nuevos quedan **enteros**. Sin contador ni toque todavía (T8).

**Files:**
- Modify: 🔥 `FisuEvolution/Scenes/BoardScene.swift`
- Create: `FisuEvolutionTests/MergeAllChainSceneTests.swift`
- `xcodegen generate`

**Interfaces:**
- Consumes: T3 (`MergeAllTempo`), T4 (`playBoardMergeFeedback`), T5 (`beginNextChainLink`,
  `debugSeedMergeAll`).
- Produces (DEBUG): `BoardScene.debugCompleteBoardChangeStep()` (corre, sin `SKView`, la misma
  completion que dispararía la acción en curso del eslabón: confirma y sigue), `debugPlayingChain:
  BoardChange.Chain?`.

**Oráculo:** `Tools/v2/oraculo.sh tarea MergeAllChainSceneTests MergeAllChainWiringTests BoardGestureTests BoardChangeWiringTests CelebrationWiringTests`
**Revisión:** **opus** (el turno y sus tres salidas: fin, toque, watchdog; ningún completion tardío
puede liberar el turno del eslabón siguiente) · **Modelo:** sonnet.

- [ ] **Step 0: Pararse en la base**

```bash
grep -n "private func playBoardChange\|private func performBoardChange\|private func finishBoardChangeTurn\|private func runBoardCelebration\|private func runAssistedMerge\|private func presentResolution\|gameState.playHaptic(.merge)" FisuEvolution/Scenes/BoardScene.swift
```

Si E13 T11 u otra tarea tiene `BoardScene` en vuelo, **no se arranca** (un dueño por 🔥).

- [ ] **Step 1: Los tests, en rojo** (`FisuEvolutionTests/MergeAllChainSceneTests.swift`)

```swift
import EconomyKit
import SpriteKit
import Testing
@testable import FisuEvolution

/// Sin `SKView` nadie evalúa las `SKAction`: la escena expone en DEBUG el paso
/// que dispararía la acción en curso (patrón de `BoardGestureTests`).
@Suite("Fusionar todo: la escena encadena")
@MainActor
struct MergeAllChainSceneTests {
    private func sceneWithChain() async -> (BoardScene, GameState) {
        let gameState = await makeGameState()
        gameState.debugSeedMergeAll(homeless: 8)
        let scene = BoardScene(gameState: gameState)
        scene.layoutBoard()
        gameState.syncCelebrations()
        return (scene, gameState)
    }

    @Test("los siete eslabones corren en un turno: nadie se mete en el medio")
    func theSceneKeepsTheTurn() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        #expect(scene.debugPlayingChain?.index == 0)
        var guardrail = 0
        while scene.debugIsPlayingBoardChange || scene.debugPlayingChain != nil, guardrail < 60 {
            #expect(gameState.showing == .boardCelebration)
            scene.debugCompleteBoardChangeStep()
            guardrail += 1
        }
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.player?.run.units["cartonero"] == 1)
        #expect(gameState.player?.run.revealedTier == 4, "los tres tiers nuevos se revelaron en la cadena")
        #expect(gameState.showing != .boardCelebration, "al final, el turno se suelta")
    }

    @Test("una hoja a mitad de cadena suelta el turno y la cadena sigue después")
    func aSheetPausesTheChain() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        scene.debugCompleteBoardChangeStep()
        gameState.uiCoversBoard = true
        for _ in 0..<6 where gameState.showing == .boardCelebration { scene.debugCompleteBoardChangeStep() }
        #expect(gameState.showing != .boardCelebration)
        #expect(!gameState.pendingBoardChanges.isEmpty)
    }

    @Test("el watchdog que asienta un eslabón corta la escena sin trabar la cadena")
    func watchdogMidChain() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        for _ in 0..<15 { gameState.tick(delta: 1) }
        scene.update(2)
        #expect(scene.debugPlayingChain == nil || gameState.inFlightBoardChange != nil,
                "o cortó, o arrancó el turno siguiente con el eslabón que sigue")
    }
}
```

(El bucle llama `debugCompleteBoardChangeStep` hasta que la escena no tenga nada en curso; un
paso es "lo que haría la próxima acción encargada": entrada → destaque → deslizamiento → reveal →
eslabón siguiente. Si un paso no avanza nada, el `guardrail` corta y el test falla por las
expectativas de abajo, no cuelga.)

- [ ] **Step 2: El eslabón en la escena**

1. Estado nuevo: `private var playingChain: BoardChange.Chain?` (lo pone `playBoardChange`, lo
   limpia el fin de la cadena y `abortBoardCelebration`) y `private var tempo: MergeAllTempo {
   MergeAllTempo(reduceMotion: Self.prefersReducedMotion) }`.
2. `playBoardChange(_:)`: `playingChain = change.chain`; la entrada pasa a
   `change.chain.map { tempo.leadIn(index: $0.index, travels: travels) } ?? (lo de hoy)`.
3. `performBoardChange(_:)`: el destaque es `change.chain.map { tempo.beat(index: $0.index) } ??
   Self.boardChangeBeat`; `runAssistedMerge` recibe `slide:` (parámetro nuevo con default
   `Self.assistedMergeSlide`, que es lo único que cambia de esa función).
4. `presentResolution(_:at:sourceNode:withinTurn:)`: el `gameState.playHaptic(.merge)` de la rama
   sin novedad pasa a `gameState.playBoardMergeFeedback(chainIndex: playingChain?.index, evolved:
   false)` **sólo cuando `withinTurn`** (el merge del jugador ya suena en `+Actions`: no se duplica;
   el jugador sigue con su `playHaptic(.merge)`); con `evolvedTo != nil`, `evolved: true`.
5. **El borde del eslabón**, un solo lugar para las dos salidas:

```swift
    /// Terminó un cambio del tablero (con o sin reveal). Si es un eslabón de
    /// "Fusionar todo" y hay otro, sigue en el mismo turno; si no, lo suelta.
    private func endBoardChangeTurn() {
        playingBoardChange = nil
        guard boardCelebrationRunning else { return }
        if let chain = playingChain, let next = gameState.beginNextChainLink(after: chain) {
            playBoardChange(next)
            return
        }
        playingChain = nil
        boardCelebrationRunning = false
        gameState.celebrationFinished(.boardCelebration)
    }
```

   `finishBoardChangeTurn()` pasa a llamar `endBoardChangeTurn()`; en `runBoardCelebration`, el
   `finish` (el que hoy hace `celebrationFinished`) también, **conservando** su guarda de
   `boardCelebrationRunning` (un completion tardío de un reveal salteado no puede encadenar).
   ⚠️ `runBoardCelebration` también corre para el merge del jugador y la red de reveal: ahí
   `playingChain` es `nil` y el comportamiento no cambia.
6. `abortBoardCelebration()`: `playingChain = nil`.
7. DEBUG: `debugPlayingChain` y `debugCompleteBoardChangeStep()`. La forma más simple y fiel:
   guardar en DEBUG la última `SKAction` encargada con `boardChangeActionKey` (o la de
   `assistedMerge` / el scrim del reveal) y, en el paso, sacarla y correr su bloque final. Si eso
   obliga a duplicar lógica, alternativa aceptable: que el paso llame en orden las mismas
   funciones privadas (`performBoardChange`, la completion de `runAssistedMerge`, el `finish` del
   reveal) según en qué etapa está el eslabón (`enum DebugChainStage`). Lo que se pinea es el
   turno, no la animación.
8. Comentarios que mienten: el de `startBoardCelebrationIfItsTurn` ("Decide qué reproduce el
   turno…") suma "o, en una cadena, el eslabón siguiente (`endBoardChangeTurn`)".

- [ ] **Step 3: Verde** (oráculo de la tarea; `BoardGestureTests` y `BoardChangeWiringTests` en
  verde **sin tocarlos**: un cambio suelto se comporta igual).

- [ ] **Step 4: A mano** (simulador 16 Pro, panel de debug → "Fusionar todo" sobre 8 Homeless, o el
  fixture de T9 si ya existe localmente): la cadena corre sin cortes, el plin sube, los tres reveals
  se ven enteros, el logro sale al final. Una grabación corta para el controlador.

- [ ] **Step 5: Commit**

```bash
/opt/homebrew/bin/xcodegen generate
git add FisuEvolution/Scenes/BoardScene.swift FisuEvolutionTests/MergeAllChainSceneTests.swift
git commit -m "feat(fusionar): la escena encadena los pares sin soltar el turno, a su ritmo"
```

---

### Task 8: El toque apura; contador, remate y VoiceOver

**Objetivo:** dentro de una cadena, un toque (pasado `skipFloor`) **apura**: corta el reveal o el
deslizamiento en curso, asienta el eslabón en silencio (`hurryChainLink`) y sigue con el siguiente;
la cadena nunca desaparece de un toque y su último tier nuevo se revela igual (la red de
`typePendingReveal`). Fuera de una cadena, el toque hace lo de siempre. El contador de T6 se cuelga
en `cameraOverlay` arriba del campo; al cerrar una cadena de 2 o más, remate (`playMergeAllFinale`),
último pulso del contador y anuncio de VoiceOver con el total.

**Files:**
- Modify: 🔥 `FisuEvolution/Scenes/BoardScene.swift`
- Modify: `FisuEvolutionTests/MergeAllChainSceneTests.swift`

**Interfaces:**
- Consumes: T4 (`playMergeAllFinale`), T5 (`hurryChainLink`), T6 (`MergeAllComboNode`), T7.
- Produces (DEBUG): `BoardScene.debugComboText: String?`, `debugTapDuringCelebration()` (la misma
  rama de `touchesBegan` sin `UITouch`).

**Oráculo:** `Tools/v2/oraculo.sh tarea MergeAllChainSceneTests MergeAllChainWiringTests MergeAllComboNodeTests BoardGestureTests CelebrationWiringTests LocalizationCompletenessTests`
**Revisión:** **opus** (un toque contra el turno: el bug típico es encadenar desde un completion
que ya se abortó) · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo** (en `MergeAllChainSceneTests`)

```swift
    @Test("un toque a mitad de cadena apura: el eslabón se asienta y la cadena sigue")
    func aTapHurriesTheChain() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        gameState.tick(delta: 1)                       // pasado el piso del skip
        let pending = gameState.pendingBoardChanges.count
        scene.debugTapDuringCelebration()
        #expect(gameState.showing == .boardCelebration, "el toque no se come la cadena")
        #expect(gameState.pendingBoardChanges.count == pending - 1, "arrancó el eslabón siguiente")
        #expect(scene.debugPlayingChain?.index == 1)
    }

    @Test("tocando sin parar, la cadena termina igual y el tier más alto se revela")
    func tappingThroughStillReveals() async {
        let (scene, gameState) = await sceneWithChain()
        scene.update(1)
        for step in 0..<80 where gameState.showing == .boardCelebration || !gameState.pendingBoardChanges.isEmpty {
            gameState.tick(delta: 1)
            scene.debugTapDuringCelebration()
            scene.update(TimeInterval(2 + step))
        }
        #expect(gameState.player?.run.units["cartonero"] == 1)
        #expect(gameState.player?.run.revealedTier == 4)
    }

    @Test("el contador cuenta desde el segundo eslabón")
    func theComboCounts() async {
        let (scene, _) = await sceneWithChain()
        scene.update(1)
        #expect(scene.debugComboText == nil)
        scene.debugCompleteBoardChangeStep()   // hasta que arranque el eslabón 1
        while scene.debugPlayingChain?.index == 0 { scene.debugCompleteBoardChangeStep() }
        #expect(scene.debugComboText == "×2")
    }

    @Test("fuera de una cadena, el toque saltea como siempre")
    func outsideAChainTheTapSkips() async {
        let gameState = await makeGameState()
        gameState.debugPlanBoardChange()
        let scene = BoardScene(gameState: gameState)
        scene.layoutBoard()
        gameState.syncCelebrations()
        scene.update(1)
        gameState.tick(delta: 1)
        scene.debugTapDuringCelebration()
        #expect(gameState.inFlightBoardChange == nil)
        #expect(scene.debugIsPlayingBoardChange == false)
    }
```

- [ ] **Step 2: El toque**

En `touchesBegan`, antes de `skipCurrentCelebration()`:

```swift
        if playingChain != nil {
            if gameState.celebrations.elapsed >= CelebrationQueue.skipFloor { hurryChain() }
            return
        }
```

(dentro de una cadena el toque no juega: es lo mismo que hoy hace `guard playingBoardChange == nil`
para un cambio suelto) y la función:

```swift
    /// El toque dentro de "Fusionar todo": se corta lo que esté en pantalla, el
    /// eslabón se asienta en silencio y la cadena sigue con el próximo.
    private func hurryChain() {
        removeAction(forKey: Self.boardChangeActionKey)
        for node in characterNodes.values { node.removeAction(forKey: "assistedMerge") }
        for layer in [cameraOverlay, backgroundLayer] {
            for node in layer.children where node.name?.hasPrefix(Self.celebrationNodePrefix) == true {
                node.removeAllActions()
                node.removeFromParent()
            }
        }
        clearMergeCandidates()
        gameState.hurryChainLink()
        layoutBoard()
        endBoardChangeTurn()
    }
```

⚠️ El `run(_:completion:)` del scrim del reveal **no** dispara su completion si la acción se saca
con `removeAllActions` (por eso el reveal cortado no encadena dos veces); el test "tocando sin
parar" es el que lo pinea. Si `celebrations` no es visible desde la escena, exponer en `GameState`
`var celebrationCanBeSkipped: Bool` en `+Celebrations` (una línea) en vez de leer la cola.

- [ ] **Step 3: El contador y el remate**

- `private var combo: MergeAllComboNode?`: en `playBoardChange`, si `change.chain` y no hay
  `combo`, se crea (`reduceMotion: Self.prefersReducedMotion`) y se cuelga en `cameraOverlay`,
  centrado, a `PlayLayout`… arriba del campo (debajo del HUD: usar la misma referencia que el
  reveal, `Self.revealLayout(size:)`, o el borde superior del campo); `combo.show(link:)` en cada
  eslabón, **al confirmarse** (en `presentResolution`, junto al sonido).
- Fin de la cadena (en `endBoardChangeTurn`, rama que suelta el turno con `playingChain != nil`):
  si `chain.count >= 2`, `gameState.playMergeAllFinale()`, `combo?.finish {}` y
  `UIAccessibility.post(notification: .announcement, argument:
  MergeAllComboNode.announcement(merges: chain.count))`; `combo = nil`.
- `abortBoardCelebration()` saca el combo (`combo?.removeFromParent(); combo = nil`): un watchdog o
  un background no dejan un "×4" colgado.

- [ ] **Step 4: Verde y a mano** (oráculo; en el simulador del 16 Pro y del SE, con Reduce Motion
  apagado y prendido: la cadena de 7 sin tocar, tocando sin parar, y una hoja abierta en el medio).
  Grabación para el controlador.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Scenes/BoardScene.swift FisuEvolutionTests/MergeAllChainSceneTests.swift
git commit -m "feat(fusionar): el toque apura la cadena, el contador cuenta y el final suena"
```

---

### Task 9: El fixture y el UI test

**Objetivo:** `--uitest-merge-all` arma la cadena del callejón al arrancar (8 Homeless + "Fusionar
todo" con `.debug`), y `MergeAllChainUITests` la ve terminar en el simulador: las unidades bajan a
1, el tier revelado llega a 4 y el HUD vuelve; otra vez tocando el tablero sin parar. Pinea que la
cadena **no se traba** (el modo de falla de una cola global) y que **cabe en su presupuesto**.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Bootstrap.swift`
- Create: `FisuEvolutionUITests/MergeAllChainUITests.swift`
- `xcodegen generate`

**Interfaces:**
- Consumes: T5 (`debugSeedMergeAll`), T7/T8.

**Oráculo:** `Tools/v2/oraculo.sh tarea MergeAllChainWiringTests` + la **receta R** con
`-only-testing:FisuEvolutionUITests/MergeAllChainUITests` y
`-only-testing:FisuEvolutionUITests/BoardChangeUITests` (en un 16 Pro con UDID propio).
**Revisión:** sonnet · **Modelo:** sonnet.

- [ ] **Step 1: El argumento** (en `finishBootstrap`, al lado de `--uitest-board-change`):

```swift
        if ProcessInfo.processInfo.arguments.contains("--uitest-merge-all") {
            debugSeedMergeAll(homeless: 8)
        }
```

- [ ] **Step 2: El UI test**

```swift
import XCTest

/// "Fusionar todo" se ve entero: siete pares en cadena, tres tiers nuevos, y la
/// cola no se traba (PLAN-v2, verificación: "Fusionar todo con un tier nuevo en
/// el medio, que se celebra").
final class MergeAllChainUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-merge-all"]
        app.launch()
        return app
    }

    private func waitForTheEnd(_ app: XCUIApplication, timeout: TimeInterval) {
        let units = app.otherElements["board.units"]
        let revealed = app.otherElements["board.revealed"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: units)
        expectation(for: NSPredicate(format: "value == %@", "4"), evaluatedWith: revealed)
        waitForExpectations(timeout: timeout)
    }

    @MainActor
    func testLaCadenaTerminaYRevelaLosTresTiers() {
        let app = launch()
        // 7 eslabones (~2,7 s) + 3 reveals (~2 s c/u) + el arranque: 20 s de techo.
        waitForTheEnd(app, timeout: 20)
        XCTAssertTrue(app.buttons["hud.map"].waitForExistence(timeout: 5), "el HUD volvió")
    }

    @MainActor
    func testTocandoSinPararLaCadenaTerminaIgual() {
        let app = launch()
        let board = app.otherElements["board.floor"]
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        for _ in 0..<20 { board.tap() }
        waitForTheEnd(app, timeout: 20)
    }
}
```

(Si `hud.map` cambió de id con E13b, usar el ícono del HUD que siga existiendo; `board.floor` es el
marcador de `RootView` y no es un botón: si `tap()` sobre él no llega a la escena, tocar en
`app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))`.)

- [ ] **Step 3: Verde y commit**

```bash
/opt/homebrew/bin/xcodegen generate
git add FisuEvolution/Game/State/GameState+Bootstrap.swift FisuEvolutionUITests/MergeAllChainUITests.swift
git commit -m "test(fusionar): la cadena entera en el simulador, con y sin toques"
```

---

### Task 10: Cierre de E8c (controlador)

- [ ] **Step 1:** `Tools/v2/oraculo.sh completo` sobre la punta de `v2/e8-fusionar` con `version-2`
  mergeada → VERDE, con `MergeAllPlannerTests`, `CelebrationQueueTests`, `MergeAllTempoTests`,
  `MergeAllChainWiringTests`, `MergeAllComboNodeTests`, `MergeAllChainSceneTests` y
  `MergeAllChainUITests` en la salida.
- [ ] **Step 2: A mano**, en el 16 Pro y el SE, Reduce Motion apagado y prendido: la cadena del
  fixture sin tocar; tocando sin parar; con una hoja abierta en el medio (Mejoras) y volviendo;
  irse a background a mitad de cadena y volver (todo asentado, el tier más alto se revela); si E6a
  T6 o E13 T2 ya entraron, una vez por ORO y una por video. Una grabación de cada una para el dueño.
- [ ] **Step 3: Docs.** `Docs/SESION-<fecha>-v2-e8c.md` (tabla por tarea con su commit y el porqué
  de cada default de "Para el dueño"); `Docs/HANDOFF.md` §4 (E8c), §5 (la cadena: un turno, el
  toque apura, los reveals enteros; los defaults que el dueño no cambió), §7 (las trampas nuevas:
  p. ej. "la cola elige entre lo pendiente: un ítem que suelta el turno y se re-encola después
  pierde contra el que ya esperaba"), §9 (este plan y la sesión). `tasks.md`: las filas de abajo y
  los carries a sus épicas; la fila "La cadena animada de Fusionar todo" de §5 E8 pasa a ✅. Journal
  y `LOCK`.

---

## Lo que E8c le deja a otras épicas

- **E6a T6** (comprar "Fusionar todo" con ORO), **E13 T2** (el video `merge_all` en Regalos) y
  **E7b-b T2** (el mismo video en la columna): **nada que hacer** para tener la cadena; vienen por
  `enqueueMergeAll`, que sella los eslabones. Lo único: si alguno arma sus propios `BoardChange` a
  partir del plan (no debería), tiene que pasar `chain:`. Sus tests pueden pinear
  `pendingBoardChanges.allSatisfy { $0.chain != nil }`. La compensación de un eslabón descartado
  (`discardBoardChange`) **no cambia**: E13 decidió que `.rewardedMergeAll` no compensa, y E6a
  decide la de `.oroShop` (un eslabón que se cae por una fusión a mano en el medio no devuelve
  ORO: lo comprado fue "fusionar lo que haya", y se fusionó).
- **E7b-b T1** (`mergeAllPairsOnVisibleFloor`): cuenta `planMergeAll(...).count`, que es el largo
  de la cadena (`chain.count`): no cambia.
- **E2b T6/T9** (perfil `.ads`): la cadena no cambia lo que paga una fusión; el simulador sigue
  aplicando el plan entero en el acto, sin animación (está bien: no hay escena).
- **E8b T8** (`.cinematic` en `CelebrationQueue`): `renew(_:)` es una función suelta; en serie con
  T2 en el mismo archivo, cualquier orden. Si una cinemática necesita conservar el turno por
  partes, puede reusar `renew`.
- **E13b T6** (el viaje en cabina): un viaje a mitad de cadena cambia el piso a la vista; el
  eslabón siguiente vuelve al piso de la cadena **volando** (`MergeAllTempo.leadIn(…, travels:
  true)`). Si el dueño prefiere que la cabina no se pueda llamar durante la cadena, E13b T6 mira
  `gameState.showing == .boardCelebration` en `ElevatorRide.select`/`openKeypad` (duda 8).
- **E9b T1** (currículo): la lección `.mergeAllVideo` de E7b-b T5 puede decir "tocá para apurar";
  nada obligatorio.
- **E10** (release): el `.caf` suma ~50 KB. Las notas a App Review no cambian.
- **E4b T1/T6/T9, E5b T3, E6b T5, E13 T11** (los otros dueños de `BoardScene`): `endBoardChangeTurn`
  es **el** borde del turno de un cambio del tablero; quien sume una salida nueva de la escena la
  hace pasar por ahí, no por `celebrationFinished` directo.

## Para el dueño / dudas

Ninguna frena: la ejecución sigue con el default anotado hasta que el dueño diga otra cosa.

1. **Un toque apura la cadena, no la corta.** Hoy un toque saltea el ítem entero; con la cadena en
   un solo turno, eso borraría el show que el jugador acaba de pagar (20 ORO o un video), y el
   toque es el verbo principal del juego (se toca sin parar). **Default:** dentro de la cadena, un
   toque corta el reveal o el deslizamiento en curso y sigue con el eslabón siguiente; el último
   tier nuevo se revela igual. Alternativa: un toque asienta toda la cadena y revela una vez.
2. **Los reveals de la cadena son enteros** (1,5 s de pausa, como cualquier tier nuevo): PLAN-v2
   dice "se celebran igual". Con siete pares y tres tiers nuevos, la cadena dura ~9 s; con
   diecinueve y cuatro, ~14 s. Alternativa: reveal corto (0,8 s) dentro de la cadena, un número en
   `runEvolutionReveal`.
3. **El HUD vuelve entre eslabón y eslabón**: sólo se apaga durante el reveal de un tier nuevo
   (como hoy en un cambio suelto). Alternativa: apagado durante toda la cadena, que se ve más
   "show" pero tapa la plata subiendo.
4. **Si una hoja tapa el tablero a mitad de cadena** (el jugador abre Mejoras), la cadena se pausa
   y sigue al volver, con el contador donde quedó ("×4"). Lo que esperaba (el logro) puede salir
   antes de que siga. Alternativa: asentar el resto en silencio.
5. **El contador es "×N" sin palabras**, desde el segundo par, arriba del piso; VoiceOver anuncia
   al final "Fusionar todo: 7 fusiones". Alternativa: "¡Combo ×N!" (una clave más).
6. **El tono sube un semitono por par** (el mismo `sfx_merge` a otro `rate`, techo de una sexta) y
   la cadena cierra con un acorde corto; un tier nuevo suena con `sfx_evolution` sin cambiar el
   tono. Una cadena de un solo par no tiene remate ni contador (es una fusión).
7. **Durante la cadena el jugador no arrastra** (como hoy durante un cambio suelto): la cadena de 7
   dura ~3 s sin reveals y el toque la apura. Alternativa: dejar arrastrar en los huecos entre
   eslabones (la revalidación lo aguanta, pero la cadena se vuelve impredecible).
8. **El ascensor durante la cadena se puede llamar** (E13b no se toca): el eslabón siguiente
   vuelve volando al piso de la cadena. Alternativa: la placa y el mapa no responden mientras
   `showing == .boardCelebration` (carry a E13b T6, arriba).
9. **Lo que llega con prioridad alta durante la cadena espera** (offline, diario: prioridad 1),
   porque el turno no se suelta. En la práctica no pasa (esos llegan al abrir la app, y la cadena se
   dispara con un botón). La elección de carrera no puede aparecer en el medio: el planificador
   nunca toca el par que la pide.
10. **El nombre del método** es el del árbol, `BoardChangePlanner.planMergeAll(floorOrdinal:…)`, y
    no el `TowerActions.planMergeAll(floor:)` de PLAN-v2 `:552`: E2a T6 ya lo decidió (vive con sus
    hermanos y planea sobre una copia). No se renombra.
11. **E8c no espera a los disparadores** (ORO, video): se prueba con el panel de debug y el fixture
    `--uitest-merge-all`. Los disparadores no esperan a E8c.

## Filas para `tasks.md`

Para reemplazar la fila "La cadena animada de Fusionar todo" de §5 E8 (queda ✅ con el cierre de E8c
T10) y sumar una sección "E8c — La cadena animada de Fusionar todo
(`2026-10-08-v2-e8c-fusionar-todo.md`)" debajo de E8b. La rama de la épica, `v2/e8-fusionar`, va a
la tabla "Ramas de épica" de §1. En §3.1 suma: `BoardScene.swift` (E8c T7, T8). En §3.2 suma:
`BoardChange.swift` (E8c T1), `CelebrationQueue.swift` (E8c T2), `AudioManager.swift` (E8c T4),
`+BoardChanges`, `+Celebrations`, `+Debug` (E8c T5), `+Bootstrap` (E8c T9). En §4.2 #9, la mitad
"cadena animada de Fusionar todo" queda planificada. Carries a E6a T6, E13 T2, E7b-b T1/T2, E8b T8,
E13b T6 y los dueños de `BoardScene` (arriba).

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E8c | Plan de E8c: la cadena animada de Fusionar todo | ✅ | — | — | (el commit de este plan) | 10 tareas (T1–T10); `2026-10-08-v2-e8c-fusionar-todo.md`; 11 dudas con default; **un solo 🔥 (BoardScene, T7/T8); no toca GameState ni RootView** |
| E8c-T1 | El eslabón en el plan (`BoardChange.Chain`) | ⏳ | E2a-T6 ✅ | BoardChange.swift (tibio: E13 T2, E6a T6, E7b-b T1), MergeAllPlannerTests | | EK; sonnet, **rev. opus** (la igualdad que compara `confirmBoardChange`); ola 1 |
| E8c-T2 | El reloj del turno se renueva (`CelebrationQueue.renew`) | ⏳ | — | CelebrationQueue.swift (tibio: E4b T1, E8b T8, E6a T12) | | EK; sonnet; ola 1 |
| E8c-T3 | El tempo de la cadena, puro (`MergeAllTempo`) | ⏳ | — | nuevos (`Scenes/MergeAllTempo.swift`) | | revisión ninguna; 7 pares ≤ 3,5 s; ola 1 |
| E8c-T4 | El plin que sube de tono y el remate | ⏳ | — | AudioManager (tibio: E13b T3, E5b), HapticsManager, +Services, generate_audio.py, 1 `.caf` | | revisión ninguna; las fusiones del embudo hoy no suenan |
| E8c-T5 | El turno de la cadena en GameState | ⛔ | T1, T2 | +BoardChanges, +Celebrations, +Debug (tibios) | | sonnet, **rev. opus** (turno, watchdog, HUD); crea `debugSeedMergeAll` |
| E8c-T6 | El contador "×N" | ⏳ | — | nuevos (`Scenes/Nodes/MergeAllComboNode.swift`); catálogo (snapshot, 1 clave) | | revisión ninguna; `claves-pendientes/e8c-t6.json` |
| E8c-T7 | La escena encadena sin soltar el turno | ⛔ | T3, T4, T5; ventana de BoardScene (tras E13 T11) | 🔥 BoardScene | | sonnet, **rev. opus**; `endBoardChangeTurn` es el borde único; grabación |
| E8c-T8 | El toque apura; contador, remate y VoiceOver | ⛔ | T6, T7 | 🔥 BoardScene | | sonnet, **rev. opus**; duda 1 (apura, no corta); SE + Reduce Motion |
| E8c-T9 | El fixture `--uitest-merge-all` y `MergeAllChainUITests` | ⛔ | T8 | +Bootstrap (tibio) | | sonnet; receta R en un 16 Pro |
| E8c-T10 | Cierre de E8c (controlador) | ⛔ | T1–T9 | `Docs/` | | `completo`; grabaciones para el dueño (sin tocar, tocando, por ORO/video si ya existen) |
