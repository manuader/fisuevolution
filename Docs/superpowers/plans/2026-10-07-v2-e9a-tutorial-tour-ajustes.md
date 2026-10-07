# E9a — Tutorial v2, el motor: no salteable, el candado de 5 s, un solo renderer y las banderas nuevas · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que el tutorial de la 2.0 no se pueda saltear y enseñe con cartel y dedo: los mensajes
explicativos habilitan "Entendido" a los 5 s fijos, los pasos de acción avanzan sólo haciéndolos,
el toque al tablero ya no saltea nada, un paso trabado se libera a los 3 min, y todo —el núcleo,
las lecciones, el coach dentro de las hojas y las tarjetas de las primeras veces— sale de **un solo
modelo** (`TutorialStep`) y **un solo renderer** (`TutorialOverlay`). Las banderas pasan a
`tutorial.v2.*` con una migración pura que reconoce a los veteranos de la v1.

**Architecture:** lo que se puede calcular sin UI vive puro en EconomyKit: el reloj del paso
(`TutorialStepClock`: candado de 5 s y watchdog de 180 s), el ritmo (`TutorialPacing`: 20 s entre
lecciones y 1 s de tablero quieto) y la migración de banderas (`TutorialMigration`). En la app, un
modelo de valor (`TutorialStep` = `explain | action(TutorialSignal)` con superficie `board |
page | characterSheet | embedded`) y un estado de corrida (`TutorialRun`) que maneja **un director**
(`GameState+Tutorial`): arranca el núcleo, elige lecciones, avanza por señales —contadores del save
comparados contra la foto del inicio del paso (`TutorialProbe`) o eventos que ya mandan las vistas
(`tutorialTipCompleted`, `tutorialTipHandled(opening:)`)—, cuenta el reloj con el tick que ya
existe (`advanceCelebrations`) y nunca con un `Timer`. Las lecciones siguen viajando por la
`CelebrationQueue` como `.tutorialTip`, que pasa a no tener timeout ni ser salteable. La UI sólo
lee `gameState.tutorialRun`: el overlay de la raíz para lo que está sobre el tablero,
`TutorialSheetCoach` adentro de cada página del menú y de la ficha, y `TutorialInlineCard`
adentro de los popups que alojan una primera vez.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI
(`TimelineView`, `keyframeAnimator`, `overlayPreferenceValue`) · EconomyKit (SPM puro, `Sendable`)
· Swift Testing · XCUITest · XcodeGen.

**Fuente:** `Docs/PLAN-v2.md` §4 "E9 — Tutorial v2 + Tour de novedades + Ajustes" (motor,
currículo, persistencia, tests), §2 ("Tutorial (ítem 14)", "Válvulas del tutorial": decisiones
del dueño, no se re-litigan), §0.1 (agentes concurrentes) y §4 (árbol: E9 va después de E7b). Lo
que dejaron las otras épicas está en "Lo que E9 hereda". **El currículo completo, el Tour, el
repaso y los Ajustes (reset) son de E9b** (`2026-10-07-v2-e9b-tutorial-tour-ajustes.md`).

**Rama de la épica:** `v2/e9-tutorial`, desde `version-2` con E7b integrada (PLAN-v2 §4). Cada
tarea sale de su punta en un worktree propio y el controlador integra de a una.

## Global Constraints (valen también para E9b)

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`. **Nada de
  `Timer`** (regla 2): el candado y el watchdog se cuentan con el delta del tick
  (`advanceCelebrations(delta:)`, que ya llega clampeado); los tests inyectan deltas.
- **El `.xcodeproj` no se versiona**: `/opt/homebrew/bin/xcodegen generate` en el mismo paso en
  que se crea o se borra un archivo Swift o de test.
- **No salteable** (PLAN-v2 §2): se borra "Saltar" (`tutorial.skip`); el toque al tablero no
  saltea ninguna lección (`CelebrationKind.tutorialTip.isSkippable == false`); los mensajes
  explicativos habilitan "Entendido" a los **5 s fijos** (`TutorialStepClock.explainLock`); un
  paso de acción **sólo** avanza con su señal, salvo el watchdog de **180 s**, que lo libera
  **sin premio y con log** (`Log.lifecycle`). "Terminar repaso" existe **sólo** en el repaso
  pedido desde Ajustes (E9b).
- **Ritmo**: una lección por vez, ≥ 20 s entre el fin de una y el nacimiento de la siguiente, y
  sólo nace si el tablero no se tocó en el último segundo (`TutorialPacing`). Una lección nace
  sólo con la cola libre (`showing == nil`): así toma el turno en el acto y la foto del inicio
  del paso es la buena.
- **Relojes**: los que tienen paciencia se congelan mientras un paso bloquea. Sale gratis de que
  las lecciones viajen por la cola (`isCalmMoment` exige `celebrations.current == nil`, E4a T8) y
  de que el núcleo encienda `tutorialPhaseActive`; T5 y T6 lo pinean con un test. **No se
  renombra `tutorialPhaseActive`**: lo leen E4a, E5a, E7a/E7b y los anuncios.
- **Banderas**: las de la **partida** son `tutorial.v2.completed`, `tutorial.v2.version`,
  `tutorial.v2.tourPending`, `tutorial.lesson.<id>`, `ftue.tapped/.spawned/.merged`,
  `tutorial.sessionsAfterPhase` y `tabs.new` (E3a T9); se van con `--uitest-reset` y con el
  "Resetear partida" de E9b. Las del **dispositivo** (idioma, audio, hápticos, partículas,
  `settings.notifications*`, `notifications.card.*`, `ads.pacing`, UMP, ATT) no se tocan nunca.
  Todo acceso pasa por `TutorialFlags` (nadie más escribe `"fisuTutorialDone"` ni
  `"tutorial.v2.*"` a mano).
- **Nada nuevo corre bajo XCTest ni bajo `--uitest*` salvo que el test lo pida**: el director de
  lecciones sigue apagado (`tutorialLessonsAutorun`, trampa 27; `--uitest-lessons` lo prende).
  Puertas nuevas, todas en `applyLaunchArgumentDefaults` (`+Debug`): `--uitest-tutorial-lock=<s>`
  (cambia los 5 s, para fixtures), `--uitest-lesson=<id>` (fuerza una lección, implica
  `--uitest-lessons`) y, en E9b, `--uitest-veteran`.
- **Sólo el Fisura** (`fisura_wave`, `fisura_celebrate`): ninguna pose nueva, ningún SF Symbol de
  persona. La mano es la `TapHereHand` de siempre; las nuevas (`HoldHand`, `SwipeHand`) la
  reusan.
- **Reduce Motion**: las manos no laten ni se deslizan (quedan quietas con una flecha), el relleno
  del candado salta de a 0,5 s, las transiciones colapsan (`motion(_:)` devuelve `nil`). Cada
  tarea con movimiento se mira en el simulador en los dos sentidos.
- **Strings**: es + en en el mismo commit que la vista, **sólo** con `Tools/v2/catalogo.py
  aplicar <snapshot.json>` y `Tools/v2/catalogo.py quitar <clave>…` (lo suma E4a T9; formato
  canónico, trampa 29). Cambiar el texto de una clave existente = `quitar` + `aplicar` en el mismo
  commit. Si la tarea no es dueña del catálogo en su ola, deja
  `Tools/v2/claves-pendientes/e9a-tN.json` (y `e9a-tN.quitar`) y el controlador lo aplica.
- **`accessibilityIdentifier` en cada control, jamás en un contenedor** (trampa 9a-bis); los
  marcadores para tests van de fondo y de 1×1 (trampa 9). Los valores de accesibilidad que
  comparan los tests van **sin traducir** (`locked`/`unlocked`, el id del paso).
- **FisuJobs es la referencia visual**: pergamino, `PanelCard`/`GameCard`, `ActionPill`,
  `PillBackground`, paleta (`PaletteYellow`, `PaletteGreen`, `PaletteOrange`, `PaletteInk`,
  `PaletteParchment`, `PaletteBrown`) y `Tokens`. Nada del sistema (ni `Button` con estilo
  `.borderedProminent`, ni alertas).
- **Commits** en español, estilo de la casa (`feat(tutorial): …`, `test(tutorial): …`,
  `refactor(tutorial): …`), **SIN `Co-Authored-By`** (regla del dueño). Staging por ruta y
  `git diff --cached --stat` antes de cada commit.
- **Paso 0 de cada tarea**: los nombres de otras épicas que este plan usa salieron de sus planes,
  no del árbol (E9 corre después de E7b). Cada tarea arranca con un `grep` de lo que consume; si
  algo no existe con ese nombre, se usa el que haya y se anota en el reporte; si no existe en
  ninguna forma, `NEEDS_CONTEXT`.

## Verificación

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5) + Release
Tools/v2/oraculo.sh completo          # + Store (18.6) + UI en la matriz + pipeline + pacing-sim
```

- `VERDE` sólo si todo está verde salvo `Tools/v2/rojos-declarados.txt`. E9 no declara rojos.
  Los tests nuevos entran solos (corre las suites enteras): un VERDE con la misma cuenta que
  antes no probó nada (HANDOFF §6).
- `rapido` al cerrar T1–T4 y T9; `completo` al cerrar T5–T8 (cambian lo que se ve y la suite
  `TutorialUITests`) y la épica (T10).
- ⚠️ `TutorialUITests` y `TutorialLockUITests` miden tiempos reales: con la máquina cargada, las
  esperas van con `waitForExistence(timeout: 10)` y los asserts de "todavía bloqueado" se hacen
  **antes** del segundo 3 (margen de 2 s contra el candado de 5).

**Receta R — correr UNA suite para ver el rojo y el verde:**

```bash
# EconomyKit: --filter matchea el NOMBRE DEL TIPO, no el @Suite("…")
swift test --package-path Packages/EconomyKit --filter "TutorialLockTests|TutorialPacingTests|TutorialMigrationTests"
```

```bash
# App: simulador propio por UDID, DerivedData absoluto, filtro por SUITE
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e9-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e9" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e9" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/TutorialDirectorTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
```

⚠️ **Una corrida que no nombra los tests esperados no probó nada** ("0 tests" con éxito es el
modo de falla de `--filter` y `-only-testing:`). Ante un rojo en masa: `uptime`,
`ps aux | grep '[x]codebuild'` y las rutas de los `SwiftCompile` (trampas 16, 33 y 44).

## Las referencias de PLAN-v2 E9, verificadas contra el árbol (`32d1300`)

| Lo que cita el plan | Dónde está hoy | Qué hace E9a |
|---|---|---|
| "se corta el acople `isSkippable = timeout != nil` (`CelebrationQueue.swift:64-81`)" | `CelebrationQueue.swift:81` (`public var isSkippable: Bool { timeout != nil }`); `.tutorialTip`: prioridad 7, timeout 12 (`:53`, `:75`) | T1 lo hace explícito sin cambiar nada; T6 pone `.tutorialTip` en `timeout nil` y no salteable |
| "el toque al tablero ya no saltea" | `BoardScene.touchesBegan` → `gameState.skipCurrentCelebration()` (`BoardScene.swift:623`) → `celebrations.skip()` | T6 (por `isSkippable`); T4 cuelga de ahí el "tablero tocado" del ritmo, sin tocar `BoardScene` |
| "Se borra el botón «Saltar» (`TutorialOverlay.swift:503-518`)" | `TutorialCard.skipButton` (`TutorialOverlay.swift:507-519`), `onSkip: finish` (`:216`) | T5 |
| "Un solo renderer (`TutorialOverlay` absorbe las lecciones)" | dos: `TutorialOverlay` (fase, con scrim) y `TutorialTipView` (lecciones, sin scrim), montados juntos en `RootView.swift:234-245` | T5 (núcleo) y T6 (lecciones; `TutorialTipView` se borra) |
| `TutorialStep { explain \| action(signal) }` | no existe: la fase es un `[Step]` privado con `Completion` (`TutorialOverlay.swift:28-95`); cada lección es un caso de `GameState.TutorialLesson` (`GameState+TutorialTips.swift:18-92`) con un solo destino | T2 (modelo), T4 (director) |
| "Explicar: «Entendido» a los 5 s, el candado en el estado, con el tick" | hoy el globo cierra al toque ("¡Dale!", `tutorial.tip.gotit`) y el turno muere a los 12 s | T1 (reloj puro), T4 (en el tick), T5/T6 (botón con relleno) |
| "Dos manos: `TapHereHand` y una nueva `SwipeHand`" | `TapHereHand` (`TutorialOverlay.swift:358-379`), usada también por FisuJobs, Logros y Pintas | T7 suma `SwipeHand` y `HoldHand` (el atajo pide "mantener presionado") |
| "`TutorialSheetCoach` adentro de cada página del menú" | la única guía adentro de una hoja es `TutorialJobsHint` (`FisuJobsView.swift:604-633`); las preferencias de ancla no cruzan la presentación de una hoja | T7 |
| "Ritmo: 20 s entre lecciones; sin toques al tablero en el último segundo" | el director dispara en cuanto hay señal (`GameState+TutorialTips.swift:125-141`) | T1 (puro), T4 |
| "Watchdog: un paso de acción trabado 3 min se libera" | sólo existe el de la cola (`advanceCelebrations`, `GameState+Celebrations.swift:122-131`) | T1 (puro), T4 |
| "Primeras veces interactivas: `TutorialInlineCard`" | no existe | T8 (offline, carrera, primer visitante) |
| "Persistencia: `tutorial.v2.completed`, `tutorial.v2.version`; `TutorialMigration` pura" | `fisuTutorialDone` (`@AppStorage` en `TutorialOverlay.swift:20` y `RootView.swift:113`; gate del bootstrap `GameState.swift:752`; `+Debug` `:29`, `:49`, `:260`, `:435`; `CelebrationWiringTests.swift:469-480`) | T1 (migración pura), T2 (`TutorialFlags`), T3 (cableado) |
| "`core.tap` → `core.hire` → `core.merge` → `core.finish`, que entrega el cofre" | pasos `tap`/`hire`/`merge`/`finish` (`TutorialOverlay.swift:74-95`); el cierre es `tutorialPhaseFinished()` (`GameState+Celebrations.swift:91-97`) → `grantWelcomeChest()` | T5: el núcleo pasa al director y el cierre se llama `finishTutorialCore()` |
| `TutorialCoverageTests` ("una mecánica sin lección no compila o pone el test en rojo") | no existe | T9 (registro `TutorialMechanic`, con huecos declarados que E9b vacía) |

## Lo que E9 hereda de otras épicas (y el paso 0 que lo comprueba)

| Pieza | La deja | La usa E9a | `grep` del paso 0 |
|---|---|---|---|
| lecciones con el sistema de hoy: `.share` | E3b T9 | T4 (migran al modelo), T9 | `case share` en `GameState+TutorialTips.swift` |
| `.visitor`, `.eventChip`, `.album` y sus anclas | E4b T3, T4, T8 | T4, T9 | `case visitor\|case eventChip\|case album` |
| `.packages`, `.mattress`, `.wheel`; `.sidePackages`, `.sideMattress` | E5b T5 | T4, T9 | `case packages\|case mattress\|case wheel` |
| `.sideRail`, `.mergeAllVideo`; `.sideRail`, `.sideWheel`, `.sideBoost` (la ruleta pasó a `.sideWheel`) | E7b-b T3, T5 | T4, T9 | `case sideRail\|case mergeAllVideo\|sideWheel` |
| anclas `.oroShop`, `.offerChip` (sin lección) | E6a T8, T12 | E9b | `case oroShop\|case offerChip` en `TutorialAnchor.swift` |
| `isCalmMoment` (escena activa, sin hoja, sin celebración, sin núcleo) | E4a T8 | T5, T6 (test de relojes) | `var isCalmMoment` |
| `GameState+Menu`: `menuDidOpen(at:)`, `menuPageChanged(to:)`, `menuDidClose()`; `MenuPagerView`/`MenuPage` | E3b T3, T4 | T4 (página abierta, `pagerMoved`), T7 (coach en `MenuPage`) | `func menuPageChanged` |
| `QuickHirePicker`, `quickHireOffer`, `meta.quickHirePinnedTypeId` | E3b T5–T8, E1 T4 | T2 (sonda: fijado), T7 (`pickerOpened`) | `struct QuickHirePicker\|var quickHireOffer` |
| `TabUnlockSignals.tutorialCoreDone` lee `"fisuTutorialDone"`; `GameState.newTabsKey` (`"tabs.new"`) | E3a T9 | T3 (pasa a `TutorialFlags`) | `fisuTutorialDone` en `GameState+Tabs.swift` |
| `notificationsLaunched(tutorialDone:)` (default `"fisuTutorialDone"`) y `requestProvisionalNotifications()` dentro de `tutorialPhaseFinished()` | E11 T6 | T3 (default), T5 (se muda al cierre renombrado) | `requestProvisionalNotifications\|notificationsLaunched` |
| `NotificationPermissionCard.lessonID = "notifications.permission"` | E11 T5 | T9 (registro) | `lessonID` |
| el popup del visitante (`VisitorPopupView` o el nombre que haya), `visitorPopup` | E4b T3 | T8 | `visitorPopup` |
| `Tools/v2/catalogo.py quitar` | E4a T9 | T5, T6, T9 | `def quitar` en `Tools/v2/catalogo.py` |
| `debugResetSave` con lo que cada épica le sumó | E1 T9, E4a, E4b | T5 (revive el núcleo con el director) | `func debugResetSave` |

## El paso, de punta a punta

```
refreshProjections (8 Hz) ─► refreshTutorial()
   ├─ hay corrida: probe = tutorialProbe() ─► ¿la señal del paso se cumplió (contra la foto del inicio)?
   │      sí ─► advance: index += 1, nueva foto, reloj nuevo ─► ¿terminó? ─► finishRun
   │      paso de hoja con la hoja cerrada ─► rewind al último paso de tablero
   └─ no hay corrida: núcleo vivo ─► startCore · si no ─► ¿pacing.mayStartLesson y showing == nil?
          ─► primera lección no dada y elegible ─► tutorialRun = .lesson(l) ─► celebrations.enqueue(.tutorialTip)

tick ─► advanceCelebrations(delta) ─► advanceTutorial(delta)
   ├─ pacing.tick(delta)
   └─ paso visible: clock.tick(delta) ─► explain: clock.canConfirm publica `unlocked` (una vez)
                                      ─► action: clock.watchdogExpired ─► log + advance (sin premio)

vistas ─► tutorialTipCompleted(l) / tutorialTipHandled(opening:) / tutorialSignal(.pickerOpened…)
          = eventos de la corrida;  "Entendido" ─► confirmTutorialStep() (no hace nada con el candado puesto)
BoardScene.touchesBegan ─► skipCurrentCelebration() ─► pacing.boardTouched() (y ya no saltea lecciones)
```

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/TutorialClock.swift` | **nuevo** — `TutorialStepClock`, `TutorialPacing` | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/TutorialMigration.swift` | **nuevo** — de las banderas de la v1 a las de la 2.0 | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` | `isSkippable` explícito (T1); `.tutorialTip` sin timeout ni salto (T6) | 1, 6 |
| `FisuEvolution/Game/Tutorial/TutorialStep.swift` | **nuevo** — `TutorialStep`, `TutorialSignal`, `TutorialEvent`, `TutorialProbe` | 2 |
| `FisuEvolution/Game/Tutorial/TutorialRun.swift` | **nuevo** — la corrida: guion, índice, foto, avance, rebobinado | 2 |
| `FisuEvolution/Game/Tutorial/TutorialFlags.swift` | **nuevo** — las banderas en `UserDefaults` y la migración aplicada | 2, 3 |
| `FisuEvolution/Game/Tutorial/TutorialCurriculum.swift` | **nuevo** — el núcleo (T5), el registro de mecánicas (T9); E9b suma el Tour | 5, 9 |
| `FisuEvolution/Game/State/GameState.swift` 🔥 | `tutorialRun`, `tutorialEngine`; el gate del bootstrap; `refreshTutorial()` | 3, 4 |
| `FisuEvolution/Game/State/GameState+Tutorial.swift` | **nuevo** — el director | 4–8 |
| `FisuEvolution/Game/State/GameState+TutorialTips.swift` | el catálogo de lecciones: `steps`, `introducedIn`; el director viejo se va a `+Tutorial` | 4, 6 |
| `FisuEvolution/Game/State/GameState+Celebrations.swift` | `advanceTutorial` en el tick, `boardTouched` en el salto, `finishTutorialCore()`, `releasePayload(.tutorialTip)` | 4, 5, 6 |
| `FisuEvolution/Game/State/GameState+Debug.swift` | puertas; `--uitest-reset`/`--uitest-skip-tutorial` por `TutorialFlags`; `debugResetSave` | 3, 4, 5 |
| `FisuEvolution/App/RootView.swift` 🔥 | `@AppStorage` de la ficha (T3); se va `TutorialTipView` (T6) | 3, 6 |
| `FisuEvolution/UI/Tutorial/TutorialOverlay.swift` | el renderer único | 5, 6 |
| `FisuEvolution/UI/Tutorial/TutorialCard.swift` | **nuevo** — la tarjeta y `TutorialConfirmButton` (relleno del candado) | 5 |
| `FisuEvolution/UI/Tutorial/TutorialHands.swift` | **nuevo** — `TapHereHand` (mudada), `HoldHand`, `SwipeHand`, `TutorialHandView` | 7 |
| `FisuEvolution/UI/Tutorial/TutorialSheetCoach.swift` | **nuevo** — el coach adentro de las hojas | 7 |
| `FisuEvolution/UI/Tutorial/TutorialInlineCard.swift` | **nuevo** — la tarjeta de las primeras veces | 8 |
| `FisuEvolution/UI/Tutorial/TutorialTipView.swift` | **se borra** | 6 |
| `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` | `.pickerFace`, `.menuPager` | 7 |
| tests | EK: `TutorialLockTests`, `TutorialPacingTests`, `TutorialMigrationTests`, `CelebrationQueueTests`; app: `TutorialModelTests`, `TutorialFlagsTests`, `TutorialDirectorTests`, `TutorialCoreTests`, `TutorialTipsTests` (reescrita), `TutorialInlineTests`, `TutorialCoverageTests`, `TutorialCurriculumTests`, `CelebrationWiringTests`; UI: `TutorialUITests` (reescrita), `TutorialLockUITests` | 1–9 |

## Orden, olas y paralelismo

| T | Qué | 🔥 calientes | Tibios / compartidos | Depende de | Modelo |
|---|---|---|---|---|---|
| 1 | relojes y migración, puros | — | `CelebrationQueue.swift` (EK; últimos: E1 T10, E4b T1/T4, E6a T12) | E6a-T12 (último en la cola) | sonnet |
| 2 | el modelo y las banderas | — | — | T1 | sonnet |
| 3 | las banderas cableadas | `GameState.swift`, `RootView.swift` | `+Debug`, `+Tabs` (E3a T9), `+Notifications` (E11 T6), `TutorialOverlay`, `CelebrationWiringTests` | T2; **E3a-T9, E11-T6** | sonnet (revisión opus) |
| 4 | el director | `GameState.swift` | `+TutorialTips` (E3b T9, E4b T3/T4/T8, E5b T5, E6a T8/T12, E7b-b T3/T5), `+Celebrations`, `+Menu` (E3b T4), `+Debug`, `TutorialTipView` | T3; **E7b-b-T5** (último en `+TutorialTips`) | opus |
| 5 | el núcleo en el director, sin "Saltar" | — | `TutorialOverlay`, `+Celebrations`, `+Notifications`, `+Debug`, `FisuJobsView`, catálogo | T4 | opus |
| 6 | las lecciones en el renderer único | `RootView.swift`, catálogo | `CelebrationQueue` (EK), `TutorialOverlay`, `+Celebrations` | T5 | opus |
| 7 | el coach en las hojas y las manos | — | `MenuPagerView` (E3b T3), `CharacterSheetView` (E3b T2), `FisuJobsView`, `QuickHirePicker` (E3b T8), `TutorialAnchor`, catálogo (snapshot) | T6 | sonnet |
| 8 | las tarjetas de las primeras veces | — | `OfflineEarningsView` (E3a T6, E11 T5), `CareerChoiceView` (E7b-b T6), el popup del visitante (E4b T3), catálogo (snapshot) | T6 | sonnet |
| 9 | el registro de cobertura y la lista de claves | — | `TutorialCurriculum`, tests | T7, T8 | sonnet |
| 10 | cierre de E9a (controlador) | — | `Docs/` | T1–T9 | controlador |

```
Ola 1 (fría)                             T1 relojes y migración ║ (E9b T6 ResetPlan, si E9b arranca en paralelo)
Ola 2 (fría)                             T2 modelo y banderas
Ola 3 (caliente: GameState + RootView)   T3 banderas cableadas
Ola 4 (caliente: GameState)              T4 el director
Ola 5                                    T5 el núcleo
Ola 6 (caliente: RootView + catálogo)    T6 las lecciones en el renderer
Ola 7                                    T7 coach y manos ║ T8 tarjetas de primeras veces (snapshot)
Ola 8                                    T9 cobertura → T10 cierre
```

**Con E9b**: E9b T1–T3 (el currículo) esperan a E9a T9; E9b T4–T5 (Tour, repaso) a E9a T6; la
parte del reset (E9b T6–T9) sólo necesita E9a T3 (banderas) y puede correr al lado de E9a T4–T9
salvo en `SettingsView` (dueña única por ola: E9b T5 y T9 de a una) y `GameState.swift` (E9b no
lo toca). Las tareas puras (E9a T1, E9b T6, E9b T7) pueden adelantarse antes de que cierre E7b si
el controlador quiere ocupar un cupo: sus dependencias reales son las de su fila.

## Helpers de test que EXISTEN

| Necesidad | Qué usar | Dónde |
|---|---|---|
| un `GameState` cargado en memoria con el director prendido | el `makeGameState()` privado de `TutorialTipsTests` (barre los defaults de lecciones, repositorio en memoria, `tutorialLessonsAutorun = true`) | `FisuEvolutionTests/TutorialTipsTests.swift:17-31` |
| armar la fase a mano | `beginTutorialPhase()`; bajo XCTest el bootstrap no la arranca | `GameState+Celebrations.swift:69-73`, `GameState.swift:740-760` |
| plata, logros, cofres | `debugGrantCoins()`, `debugSeedAchievements()`, `debugAwardChest()` | `GameState+Debug.swift` |
| avanzar el tiempo sin esperar | `advanceCelebrations(delta:)` (y desde T4, `advanceTutorial(delta:)`) | `GameState+Celebrations.swift:122` |
| los defaults sin pisar al host | guardar y restaurar la clave (patrón de `TabUnlockWiringTests`, E3a T9) | E3a T9 |
| leer el catálogo fuente | `LocalizationCompletenessTests.catalog("Localizable")` y `.problems(of:in:)` (estáticos) | `FisuEvolutionTests/LocalizationCompletenessTests.swift:186-200` |
| UI: partida nueva / sin tutorial / lecciones prendidas | `--uitest-reset`, `--uitest-skip-tutorial`, `--uitest-coins`, `--uitest-lessons` | `+Debug`; HANDOFF §6 |
| UI: tocar el recorte del tablero | `tapSpotlight` y el helper de merge de `TutorialUITests` (reintentan releyendo el estado) | `FisuEvolutionUITests/TutorialUITests.swift` |

---

### Task 1: Los relojes y la migración, puros en EconomyKit

**Objetivo:** las tres reglas que no necesitan UI, con sus números de PLAN-v2 fijados por test: el
candado de 5 s y el watchdog de 180 s (`TutorialStepClock`), el ritmo de 20 s / 1 s
(`TutorialPacing`) y qué hacer con las banderas de la v1 (`TutorialMigration`). Más el corte del
acople `isSkippable = timeout != nil`, **sin cambiar ningún valor** (el cambio de conducta de
`.tutorialTip` es de T6, cuando el renderer ya sabe esperar el candado).

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/TutorialClock.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/TutorialMigration.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` (`isSkippable`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/TutorialLockTests.swift`, `TutorialPacingTests.swift`, `TutorialMigrationTests.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift`

**Interfaces:**
- Produces: `public struct TutorialStepClock: Sendable, Equatable` (`enum Kind { explain, action }`;
  `static let explainLock: TimeInterval = 5`; `static let actionWatchdog: TimeInterval = 180`;
  `init(kind:lock:)`; `elapsed`; `mutating tick(_:)`; `canConfirm`; `lockProgress: Double`;
  `watchdogExpired`).
- Produces: `public struct TutorialPacing: Sendable, Equatable` (`static let gapBetweenLessons = 20`,
  `static let quietBoard = 1`; `tick(_:)`, `lessonEnded()`, `boardTouched()`, `mayStartLesson`).
- Produces: `public enum TutorialMigration` con `struct Input` (`hasSave`, `storedVersion: Int?`,
  `legacyCoreDone`, `legacyLessonsDone: Set<String>`), `struct Plan` (`coreCompleted`,
  `tourPending`, `lessonsDone: Set<String>`, `version`) y
  `static func plan(_:currentVersion:veteranKnownLessons:) -> Plan?` (`nil` = ya migrado).
- Produces: `CelebrationKind.isSkippable` como `switch` propio.

- [ ] **Step 0: La cola de hoy**

Run: `grep -n "case \.\|timeout\|isSkippable" Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift`
Expected: los casos de `timeout` (E1 T10, E4b y E6a pueden haber sumado kinds). Anotá cuáles
tienen timeout distinto de `nil`: son exactamente los salteables de hoy.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/TutorialLockTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("El candado y el watchdog de un paso del tutorial")
struct TutorialLockTests {
    @Test("explicar: bloqueado a 4,9 s y libre a 5,0 s")
    func theLockOpensAtFiveSeconds() {
        var clock = TutorialStepClock(kind: .explain)
        clock.tick(4.9)
        #expect(!clock.canConfirm)
        #expect(clock.lockProgress < 1)
        var fresh = TutorialStepClock(kind: .explain)
        fresh.tick(5.0)
        #expect(fresh.canConfirm)
        #expect(fresh.lockProgress == 1)
    }

    @Test("el candado se cuenta de a pedacitos, como el tick")
    func theLockAddsUpTicks() {
        var clock = TutorialStepClock(kind: .explain)
        for _ in 0..<49 { clock.tick(0.1) }
        #expect(!clock.canConfirm, "4,9 s en 49 ticks")
        clock.tick(0.2)
        #expect(clock.canConfirm)
    }

    @Test("un delta negativo no hace retroceder el reloj")
    func negativeDeltasAreIgnored() {
        var clock = TutorialStepClock(kind: .explain)
        clock.tick(3)
        clock.tick(-10)
        #expect(clock.elapsed == 3)
    }

    @Test("un paso de acción nunca se confirma con el botón: sólo con su señal")
    func actionsNeverConfirm() {
        var clock = TutorialStepClock(kind: .action)
        clock.tick(60)
        #expect(!clock.canConfirm)
        #expect(clock.lockProgress == 1, "un paso de acción no dibuja candado")
    }

    @Test("el watchdog libera un paso de acción a los 180 s, y nunca uno de explicar")
    func theWatchdogFiresOnlyOnActions() {
        var action = TutorialStepClock(kind: .action)
        action.tick(179.9)
        #expect(!action.watchdogExpired)
        action.tick(0.1)
        #expect(action.watchdogExpired)
        var explain = TutorialStepClock(kind: .explain)
        explain.tick(1000)
        #expect(!explain.watchdogExpired)
    }

    @Test("los números son los del dueño")
    func theOwnersNumbers() {
        #expect(TutorialStepClock.explainLock == 5)
        #expect(TutorialStepClock.actionWatchdog == 180)
    }

    @Test("un candado corto (el fixture de UI) se respeta")
    func aShortLockForFixtures() {
        var clock = TutorialStepClock(kind: .explain, lock: 0.3)
        clock.tick(0.3)
        #expect(clock.canConfirm)
    }
}
```

`Packages/EconomyKit/Tests/EconomyKitTests/TutorialPacingTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("El ritmo de las lecciones")
struct TutorialPacingTests {
    @Test("al arrancar no hay nada que esperar")
    func freshPacingAllows() {
        #expect(TutorialPacing().mayStartLesson)
    }

    @Test("20 s entre el fin de una lección y la siguiente")
    func twentySecondsBetweenLessons() {
        var pacing = TutorialPacing()
        pacing.lessonEnded()
        pacing.tick(19.9)
        #expect(!pacing.mayStartLesson)
        pacing.tick(0.1)
        #expect(pacing.mayStartLesson)
    }

    @Test("un toque al tablero en el último segundo la frena: no se come taps")
    func aRecentBoardTouchHolds() {
        var pacing = TutorialPacing()
        pacing.boardTouched()
        pacing.tick(0.9)
        #expect(!pacing.mayStartLesson)
        pacing.tick(0.1)
        #expect(pacing.mayStartLesson)
    }

    @Test("las dos esperas se suman: manda la más larga")
    func bothWaitsApply() {
        var pacing = TutorialPacing()
        pacing.lessonEnded()
        pacing.tick(25)
        pacing.boardTouched()
        #expect(!pacing.mayStartLesson)
        pacing.tick(1)
        #expect(pacing.mayStartLesson)
    }
}
```

`Packages/EconomyKit/Tests/EconomyKitTests/TutorialMigrationTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("De las banderas de la v1 a las de la 2.0")
struct TutorialMigrationTests {
    private let known: Set<String> = ["upgrades", "skins", "gifts"]

    private func plan(hasSave: Bool, version: Int? = nil, coreDone: Bool = false,
                      lessons: Set<String> = []) -> TutorialMigration.Plan? {
        TutorialMigration.plan(
            .init(hasSave: hasSave, storedVersion: version, legacyCoreDone: coreDone, legacyLessonsDone: lessons),
            currentVersion: 1,
            veteranKnownLessons: known
        )
    }

    @Test("ya migrado: no se toca nada")
    func alreadyMigrated() {
        #expect(plan(hasSave: true, version: 1, coreDone: true) == nil)
        #expect(plan(hasSave: false, version: 1) == nil)
    }

    @Test("instalación nueva: núcleo por delante, sin Tour")
    func freshInstall() {
        let result = plan(hasSave: false, coreDone: true)
        #expect(result == .init(coreCompleted: false, tourPending: false, lessonsDone: [], version: 1),
                "sin save no hay veterano, aunque quede una bandera vieja de otra instalación")
    }

    @Test("veterano de la v1 (save + núcleo hecho): Tour, y lo que la v1 ya enseñaba queda dado")
    func veteran() {
        let result = plan(hasSave: true, coreDone: true, lessons: ["store", "prestige"])
        #expect(result?.coreCompleted == true)
        #expect(result?.tourPending == true)
        #expect(result?.lessonsDone == ["store", "prestige", "upgrades", "skins", "gifts"])
        #expect(result?.version == 1)
    }

    @Test("save de la v1 a medio núcleo: sigue el núcleo, sin Tour")
    func halfwayThroughTheCore() {
        let result = plan(hasSave: true, coreDone: false, lessons: [])
        #expect(result == .init(coreCompleted: false, tourPending: false, lessonsDone: [], version: 1))
    }
}
```

En `CelebrationQueueTests.swift`, un test nuevo (no cambia los que hay):

```swift
    @Test("salteable sigue siendo exactamente lo que se cierra solo (hasta que E9 lo cambie a propósito)")
    func skippableMatchesTimeoutForNow() {
        for kind in CelebrationKind.allCases {
            #expect(kind.isSkippable == (kind.timeout != nil), "\(kind)")
        }
    }
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "TutorialLockTests|TutorialPacingTests|TutorialMigrationTests|CelebrationQueueTests"`
Expected: no compila (`TutorialStepClock`, `TutorialPacing`, `TutorialMigration` no existen).

- [ ] **Step 3: Los relojes**

`Packages/EconomyKit/Sources/EconomyKit/TutorialClock.swift`:

```swift
import Foundation

/// El reloj de UN paso del tutorial (PLAN-v2 E9). Lo avanza el tick del juego, nunca un
/// `Timer`: así el candado vive en el estado y los tests inyectan segundos.
///
/// - Explicar: "Entendido" se habilita a los 5 s fijos. No es salteable.
/// - Acción: avanza sólo con su señal; si en 3 min no llegó, el watchdog lo libera (sin premio).
public struct TutorialStepClock: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case explain
        case action
    }

    public static let explainLock: TimeInterval = 5
    public static let actionWatchdog: TimeInterval = 180

    public let kind: Kind
    public let lock: TimeInterval
    public private(set) var elapsed: TimeInterval = 0

    public init(kind: Kind, lock: TimeInterval = TutorialStepClock.explainLock) {
        self.kind = kind
        self.lock = lock
    }

    public mutating func tick(_ delta: TimeInterval) {
        elapsed += max(0, delta)
    }

    public var canConfirm: Bool {
        kind == .explain && elapsed >= lock
    }

    /// Lo que dibuja el relleno del botón: 0 → 1 durante el candado.
    public var lockProgress: Double {
        guard kind == .explain, lock > 0 else { return 1 }
        return min(1, elapsed / lock)
    }

    public var watchdogExpired: Bool {
        kind == .action && elapsed >= Self.actionWatchdog
    }
}

/// El ritmo de las lecciones (PLAN-v2 E9): una por vez, 20 s entre el fin de una y la
/// siguiente, y nunca con el dedo todavía en el tablero (una lección que nace en medio de una
/// ráfaga de toques se come el siguiente).
public struct TutorialPacing: Sendable, Equatable {
    public static let gapBetweenLessons: TimeInterval = 20
    public static let quietBoard: TimeInterval = 1

    public private(set) var sinceLessonEnded: TimeInterval = .infinity
    public private(set) var sinceBoardTouch: TimeInterval = .infinity

    public init() {}

    public mutating func tick(_ delta: TimeInterval) {
        let step = max(0, delta)
        sinceLessonEnded += step
        sinceBoardTouch += step
    }

    public mutating func lessonEnded() {
        sinceLessonEnded = 0
    }

    public mutating func boardTouched() {
        sinceBoardTouch = 0
    }

    public var mayStartLesson: Bool {
        sinceLessonEnded >= Self.gapBetweenLessons && sinceBoardTouch >= Self.quietBoard
    }
}
```

- [ ] **Step 4: La migración**

`Packages/EconomyKit/Sources/EconomyKit/TutorialMigration.swift`:

```swift
import Foundation

/// Qué hacer con las banderas del tutorial la primera vez que arranca la 2.0 (PLAN-v2 E9).
///
/// Pura: la app lee `UserDefaults` y le pasa lo que encontró; lo que devuelve es lo que se
/// escribe. Un veterano es quien **tiene save y no tiene versión**: recibe el Tour, y lo que la
/// v1 ya le enseñaba se da por visto (lo nuevo se le enseña en su primera ocurrencia).
public enum TutorialMigration {
    public struct Input: Sendable, Equatable {
        public var hasSave: Bool
        public var storedVersion: Int?
        public var legacyCoreDone: Bool
        public var legacyLessonsDone: Set<String>

        public init(hasSave: Bool, storedVersion: Int?, legacyCoreDone: Bool, legacyLessonsDone: Set<String>) {
            self.hasSave = hasSave
            self.storedVersion = storedVersion
            self.legacyCoreDone = legacyCoreDone
            self.legacyLessonsDone = legacyLessonsDone
        }
    }

    public struct Plan: Sendable, Equatable {
        public var coreCompleted: Bool
        public var tourPending: Bool
        public var lessonsDone: Set<String>
        public var version: Int

        public init(coreCompleted: Bool, tourPending: Bool, lessonsDone: Set<String>, version: Int) {
            self.coreCompleted = coreCompleted
            self.tourPending = tourPending
            self.lessonsDone = lessonsDone
            self.version = version
        }
    }

    /// `nil` = ya está migrado. `veteranKnownLessons` son las lecciones de mecánicas que la v1
    /// ya tenía (las declara la app: `TutorialLesson.introducedIn == .v1`).
    public static func plan(_ input: Input, currentVersion: Int, veteranKnownLessons: Set<String>) -> Plan? {
        guard input.storedVersion == nil else { return nil }
        guard input.hasSave else {
            return Plan(coreCompleted: false, tourPending: false, lessonsDone: [], version: currentVersion)
        }
        guard input.legacyCoreDone else {
            return Plan(coreCompleted: false, tourPending: false,
                        lessonsDone: input.legacyLessonsDone, version: currentVersion)
        }
        return Plan(coreCompleted: true, tourPending: true,
                    lessonsDone: input.legacyLessonsDone.union(veteranKnownLessons),
                    version: currentVersion)
    }
}
```

- [ ] **Step 5: `isSkippable`, explícito**

En `CelebrationQueue.swift`, reemplazar `public var isSkippable: Bool { timeout != nil }` por un
`switch` con **la misma partición** que anotaste en el Step 0 (los que hoy tienen timeout →
`true`; el resto → `false`). Con los kinds de `32d1300`:

```swift
    /// Se puede saltear con un tap lo que se cierra solo, con una excepción a propósito: las
    /// lecciones del tutorial (PLAN-v2 E9: no salteable) — ver T6. Un sheet tiene su botón: un
    /// tap al vacío no lo cierra.
    public var isSkippable: Bool {
        switch self {
        case .offlineEarnings, .dailyReward, .careerChoice,
             .skinAward, .specialDrop, .chestOpening: false
        case .boardCelebration, .eventBanner, .achievements, .towerNotice, .tutorialTip: true
        }
    }
```

(Si E4b/E6a sumaron kinds, van del lado que diga su `timeout`; el test del Step 1 lo vigila.)

- [ ] **Step 6: Verde**

Run: `swift test --package-path Packages/EconomyKit --filter "TutorialLockTests|TutorialPacingTests|TutorialMigrationTests|CelebrationQueueTests"`
Expected: PASS, con los nombres de los cuatro suites en la salida. Después `swift test --package-path Packages/EconomyKit` entero → PASS.

- [ ] **Step 7: Oráculo y commit**

Run: `Tools/v2/oraculo.sh rapido` → `VERDE` (EK +16 tests).

```bash
git add Packages/EconomyKit/Sources/EconomyKit/TutorialClock.swift
git add Packages/EconomyKit/Sources/EconomyKit/TutorialMigration.swift
git add Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/TutorialLockTests.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/TutorialPacingTests.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/TutorialMigrationTests.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift
git diff --cached --stat
git commit -m "feat(tutorial): el candado de 5 s, el watchdog, el ritmo y la migración, puros"
```

---

### Task 2: El modelo del paso y las banderas

**Objetivo:** los tipos de valor que usa todo lo demás, sin cablear nada todavía: el paso
(`TutorialStep`), qué lo hace avanzar (`TutorialSignal`, evaluada contra una foto `TutorialProbe` y
los eventos de la corrida), la corrida (`TutorialRun`, con avance y rebobinado puros) y el único
lugar que lee y escribe las banderas (`TutorialFlags`).

**Files:**
- Create: `FisuEvolution/Game/Tutorial/TutorialStep.swift`
- Create: `FisuEvolution/Game/Tutorial/TutorialRun.swift`
- Create: `FisuEvolution/Game/Tutorial/TutorialFlags.swift`
- Create: `FisuEvolutionTests/TutorialModelTests.swift`, `FisuEvolutionTests/TutorialFlagsTests.swift`

**Interfaces:**
- Consumes: `TutorialStepClock`, `TutorialMigration` (T1); `GameScreen`; `TutorialTarget`;
  `GameState.TutorialBoardTarget`; `GameState.TutorialLesson` (sólo como tipo).
- Produces:
  - `struct TutorialStep: Equatable, Sendable` (`id`, `kind: Kind`, `target: TutorialTarget?`,
    `windows: [TutorialTarget]`, `boardTarget: GameState.TutorialBoardTarget?`, `surface: Surface`,
    `hand: Hand`, `textKey: String`, `pose: String`); `enum Kind { explain, action(TutorialSignal) }`;
    `enum Surface { board, page(GameScreen), characterSheet, embedded }`;
    `enum Hand { none, tap, hold, swipe(SwipeDirection) }`; `enum SwipeDirection { left, right, up, down }`;
    `var clockKind: TutorialStepClock.Kind`; constructores `explain(_:text:on:…)` y `act(_:_:text:on:…)`.
  - `enum TutorialSignal: Hashable, Sendable` (`coreTappedAndAffordable`, `coreHired`, `coreMerged`,
    `tapped`, `hired`, `merged`, `upgradeBought`, `passiveUnlocked`, `floorChanged`, `pinned`,
    `unpinned`, `lessonAction`, `screenOpened(GameScreen)`, `pagerMoved`, `pickerOpened`,
    `elevatorExpanded`, `characterSheetOpened`) con
    `isSatisfied(baseline:now:events:lesson:) -> Bool`.
  - `enum TutorialEvent: Hashable, Sendable` (`lessonAction(String)`, `screenOpened(GameScreen)`,
    `pagerMoved`, `pickerOpened`, `elevatorExpanded`, `characterSheetOpened`).
  - `struct TutorialProbe: Equatable, Sendable` (`taps`, `hires`, `merges`, `upgradeLevels`,
    `passivesUnlocked`, `visibleFloor`, `pinnedTypeId`, `canAffordSpawn`, `ftueTapped`,
    `ftueSpawned`, `ftueMerged`).
  - `struct TutorialRun: Equatable` (`enum Script { core, lesson(String), tour, replay }`, `steps`,
    `index`, `baseline`, `events`, `unlocked`, `step`, `isFinished`, `isDemo`,
    `mutating advance(probe:)`, `mutating rewindToBoard(probe:) -> Bool`, `isStepSatisfied(probe:)`).
  - `enum TutorialFlags` (claves; `coreCompleted(in:)`, `setCoreCompleted(_:in:)`,
    `tourPending(in:)`, `setTourPending(_:in:)`, `isLessonDone(_:in:)`, `markLessonDone(_:in:)`,
    `lessonKey(_:)`, `wipeGameFlags(in:)`, `markCurrent(in:)`,
    `migrate(hasSave:veteranKnownLessons:in:) -> TutorialMigration.Plan?`).

El guion lleva el **id** de la lección (`String`) y no el enum, para que `TutorialRun` no dependa
del catálogo y el registro de cobertura (T9) pueda nombrar lecciones de tarjeta como
`notifications.permission`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/TutorialModelTests.swift`:

```swift
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El modelo del paso y de la corrida")
struct TutorialModelTests {
    private let base = TutorialProbe()

    @Test("las señales de contador miran el cambio desde el inicio del paso, no el total")
    func counterSignalsAreRelative() {
        var start = base
        start.merges = 7
        var now = start
        #expect(!TutorialSignal.merged.isSatisfied(baseline: start, now: now, events: [], lesson: nil),
                "siete fusiones de antes no cumplen el paso")
        now.merges = 8
        #expect(TutorialSignal.merged.isSatisfied(baseline: start, now: now, events: [], lesson: nil))
    }

    @Test("las del núcleo son absolutas: retomar a mitad de camino no rehace nada")
    func coreSignalsAreAbsolute() {
        var now = base
        now.ftueSpawned = true
        #expect(TutorialSignal.coreHired.isSatisfied(baseline: now, now: now, events: [], lesson: nil))
        now.ftueTapped = true
        #expect(!TutorialSignal.coreTappedAndAffordable.isSatisfied(baseline: now, now: now, events: [], lesson: nil),
                "tocó, pero todavía no le alcanza para contratar")
        now.canAffordSpawn = true
        #expect(TutorialSignal.coreTappedAndAffordable.isSatisfied(baseline: now, now: now, events: [], lesson: nil))
    }

    @Test("fijar y soltar miran el pin del atajo")
    func pinSignals() {
        var now = base
        #expect(!TutorialSignal.pinned.isSatisfied(baseline: base, now: now, events: [], lesson: nil))
        now.pinnedTypeId = "homeless"
        #expect(TutorialSignal.pinned.isSatisfied(baseline: base, now: now, events: [], lesson: nil))
        #expect(TutorialSignal.unpinned.isSatisfied(baseline: now, now: base, events: [], lesson: nil))
        #expect(!TutorialSignal.unpinned.isSatisfied(baseline: base, now: base, events: [], lesson: nil),
                "soltar pide haber tenido algo fijado al empezar el paso")
    }

    @Test("la acción firma es la de la lección que corre, no la de otra")
    func lessonActionIsScoped() {
        let events: Set<TutorialEvent> = [.lessonAction("elevator")]
        #expect(TutorialSignal.lessonAction.isSatisfied(baseline: base, now: base, events: events, lesson: "elevator"))
        #expect(!TutorialSignal.lessonAction.isSatisfied(baseline: base, now: base, events: events, lesson: "prestige"))
    }

    @Test("abrir una pantalla cumple sólo esa pantalla")
    func screenOpened() {
        let events: Set<TutorialEvent> = [.screenOpened(.upgrades)]
        #expect(TutorialSignal.screenOpened(.upgrades).isSatisfied(baseline: base, now: base, events: events, lesson: nil))
        #expect(!TutorialSignal.screenOpened(.gifts).isSatisfied(baseline: base, now: base, events: events, lesson: nil))
    }

    @Test("avanzar renueva la foto, borra los eventos y vuelve a cerrar el candado")
    func advancing() {
        var run = TutorialRun(script: .lesson("passive"), steps: [
            .act("passive.open", .screenOpened(.upgrades), text: "tutorial.passive.open", on: .upgrades),
            .explain("passive.done", text: "tutorial.passive.done", surface: .page(.upgrades)),
        ], probe: base)
        run.events.insert(.screenOpened(.upgrades))
        run.unlocked = true
        #expect(run.isStepSatisfied(probe: base))
        var later = base
        later.taps = 3
        run.advance(probe: later)
        #expect(run.index == 1)
        #expect(run.baseline == later)
        #expect(run.events.isEmpty)
        #expect(!run.unlocked)
        #expect(!run.isStepSatisfied(probe: later), "un paso de explicar se cumple con el botón, no solo")
        run.advance(probe: later)
        #expect(run.isFinished)
        #expect(run.step == nil)
    }

    @Test("con la hoja cerrada, un paso de hoja vuelve al último paso de tablero")
    func rewindingToTheBoard() {
        var run = TutorialRun(script: .lesson("upgrades"), steps: [
            .act("upgrades.open", .screenOpened(.upgrades), text: "tutorial.upgrades.open", on: .upgrades),
            .act("upgrades.buy", .upgradeBought, text: "tutorial.upgrades.buy", on: nil, surface: .page(.upgrades)),
        ], probe: base)
        run.advance(probe: base)
        #expect(run.rewindToBoard(probe: base))
        #expect(run.index == 0)
        #expect(!run.rewindToBoard(probe: base), "un paso de tablero no rebobina")
    }

    @Test("el Tour y el repaso son demostraciones")
    func demoScripts() {
        #expect(TutorialRun(script: .tour, steps: [], probe: base).isDemo)
        #expect(TutorialRun(script: .replay, steps: [], probe: base).isDemo)
        #expect(!TutorialRun(script: .core, steps: [], probe: base).isDemo)
    }
}
```

`FisuEvolutionTests/TutorialFlagsTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Las banderas del tutorial")
struct TutorialFlagsTests {
    private func scratch() -> UserDefaults {
        let name = "tutorial-flags-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("el veterano de la v1: núcleo hecho, Tour pendiente, lecciones de la v1 dadas")
    func veteranMigration() {
        let defaults = scratch()
        defaults.set(true, forKey: TutorialFlags.legacyCompletedKey)
        defaults.set(true, forKey: "tutorial.lesson.store")
        let plan = TutorialFlags.migrate(hasSave: true, veteranKnownLessons: ["upgrades"], in: defaults)
        #expect(plan?.tourPending == true)
        #expect(TutorialFlags.coreCompleted(in: defaults))
        #expect(TutorialFlags.tourPending(in: defaults))
        #expect(TutorialFlags.isLessonDone("store", in: defaults))
        #expect(TutorialFlags.isLessonDone("upgrades", in: defaults))
        #expect(defaults.integer(forKey: TutorialFlags.versionKey) == TutorialFlags.currentVersion)
        #expect(defaults.object(forKey: TutorialFlags.legacyCompletedKey) == nil, "la bandera vieja se va")
        #expect(TutorialFlags.migrate(hasSave: true, veteranKnownLessons: [], in: defaults) == nil,
                "la segunda vez no hace nada")
    }

    @Test("borrar la partida se lleva las banderas de juego y deja las del dispositivo")
    func wipeKeepsDeviceFlags() {
        let defaults = scratch()
        TutorialFlags.setCoreCompleted(true, in: defaults)
        TutorialFlags.setTourPending(true, in: defaults)
        TutorialFlags.markLessonDone("upgrades", in: defaults)
        defaults.set(true, forKey: "ftue.merged")
        defaults.set(3, forKey: TutorialFlags.sessionsAfterCoreKey)
        defaults.set(["skins"], forKey: TutorialFlags.newTabsKey)
        defaults.set(["en"], forKey: "AppleLanguages")
        defaults.set("en", forKey: "settings.language")
        defaults.set(false, forKey: "settings.notificationsEnabled")
        defaults.set(0.3, forKey: "settings.musicVolume")

        TutorialFlags.wipeGameFlags(in: defaults)

        #expect(!TutorialFlags.coreCompleted(in: defaults))
        #expect(!TutorialFlags.tourPending(in: defaults))
        #expect(!TutorialFlags.isLessonDone("upgrades", in: defaults))
        #expect(!defaults.bool(forKey: "ftue.merged"))
        #expect(defaults.object(forKey: TutorialFlags.sessionsAfterCoreKey) == nil)
        #expect(defaults.object(forKey: TutorialFlags.newTabsKey) == nil)
        #expect(defaults.integer(forKey: TutorialFlags.versionKey) == TutorialFlags.currentVersion,
                "una partida borrada no es un veterano: no vuelve a pedir el Tour")
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["en"])
        #expect(defaults.string(forKey: "settings.language") == "en")
        #expect(defaults.object(forKey: "settings.notificationsEnabled") as? Bool == false)
        #expect(defaults.double(forKey: "settings.musicVolume") == 0.3)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/TutorialModelTests -only-testing:FisuEvolutionTests/TutorialFlagsTests`.
Expected: no compila (`TutorialProbe`, `TutorialRun`, `TutorialFlags` no existen).

- [ ] **Step 3: El paso**

`FisuEvolution/Game/Tutorial/TutorialStep.swift`:

```swift
import EconomyKit
import Foundation

/// Un paso del tutorial v2 (PLAN-v2 E9): o explica (y "Entendido" espera 5 s) o pide una
/// acción (y sólo avanza haciéndola). Es un valor: el núcleo, las lecciones, el Tour y el
/// repaso son listas de esto.
struct TutorialStep: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case explain
        case action(TutorialSignal)
    }

    /// Dónde se dibuja. El overlay de la raíz sólo dibuja `board`; las hojas tienen su coach
    /// (`TutorialSheetCoach`) y los popups su tarjeta (`TutorialInlineCard`).
    enum Surface: Equatable, Sendable {
        case board
        case page(GameScreen)
        case characterSheet
        case embedded
    }

    enum SwipeDirection: Equatable, Sendable {
        case left, right, up, down
    }

    enum Hand: Equatable, Sendable {
        case none
        case tap
        case hold
        case swipe(SwipeDirection)
    }

    /// Lo que publica el marcador `tutorial.step` (sin traducir).
    let id: String
    let kind: Kind
    let target: TutorialTarget?
    var windows: [TutorialTarget] = []
    var boardTarget: GameState.TutorialBoardTarget?
    var surface: Surface = .board
    var hand: Hand = .tap
    /// La clave del cartel, escrita entera (la busca `TutorialCurriculumTests`).
    let textKey: String
    var pose = "fisura_wave"

    var clockKind: TutorialStepClock.Kind {
        if case .action = kind { return .action }
        return .explain
    }

    var signal: TutorialSignal? {
        if case .action(let signal) = kind { return signal }
        return nil
    }

    static func explain(
        _ id: String, text: String, on target: TutorialTarget? = nil,
        surface: Surface = .board, hand: Hand = .none, pose: String = "fisura_wave"
    ) -> TutorialStep {
        TutorialStep(id: id, kind: .explain, target: target, surface: surface, hand: hand, textKey: text, pose: pose)
    }

    static func act(
        _ id: String, _ signal: TutorialSignal, text: String, on target: TutorialTarget?,
        surface: Surface = .board, hand: Hand = .tap, windows: [TutorialTarget] = [],
        boardTarget: GameState.TutorialBoardTarget? = nil
    ) -> TutorialStep {
        TutorialStep(id: id, kind: .action(signal), target: target, windows: windows,
                     boardTarget: boardTarget, surface: surface, hand: hand, textKey: text)
    }
}

/// La foto de lo que el tutorial mira, tomada al empezar cada paso y en cada refresh. Son
/// contadores del save y proyecciones ya publicadas: armarla cuesta una docena de lecturas.
struct TutorialProbe: Equatable, Sendable {
    var taps = 0
    var hires = 0
    var merges = 0
    var upgradeLevels = 0
    var passivesUnlocked = 0
    var visibleFloor = 0
    var pinnedTypeId: String?
    var canAffordSpawn = false
    var ftueTapped = false
    var ftueSpawned = false
    var ftueMerged = false
}

/// Lo que las vistas avisan y no queda en el save.
enum TutorialEvent: Hashable, Sendable {
    /// La acción firma de una lección (`tutorialTipCompleted`): abrir el mapa, reencarnar,
    /// contratar con el atajo, tocar un acceso de la columna…
    case lessonAction(String)
    case screenOpened(GameScreen)
    case pagerMoved
    case pickerOpened
    case elevatorExpanded
    case characterSheetOpened
}

/// Qué hace avanzar un paso de acción.
enum TutorialSignal: Hashable, Sendable {
    /// Núcleo: tocó y ya le alcanza para contratar (las dos cosas, o el paso siguiente
    /// iluminaría un botón impagable con el resto bloqueado).
    case coreTappedAndAffordable
    case coreHired
    case coreMerged
    case tapped
    case hired
    case merged
    case upgradeBought
    case passiveUnlocked
    case floorChanged
    case pinned
    case unpinned
    case lessonAction
    case screenOpened(GameScreen)
    case pagerMoved
    case pickerOpened
    case elevatorExpanded
    case characterSheetOpened

    /// Las del núcleo son absolutas (los milestones `ftue.*` persisten: retomar a mitad no
    /// rehace nada); las demás miran el cambio desde el inicio del paso.
    func isSatisfied(baseline: TutorialProbe, now: TutorialProbe, events: Set<TutorialEvent>, lesson: String?) -> Bool {
        switch self {
        case .coreTappedAndAffordable: now.ftueTapped && now.canAffordSpawn
        case .coreHired: now.ftueSpawned
        case .coreMerged: now.ftueMerged
        case .tapped: now.taps > baseline.taps
        case .hired: now.hires > baseline.hires
        case .merged: now.merges > baseline.merges
        case .upgradeBought: now.upgradeLevels > baseline.upgradeLevels
        case .passiveUnlocked: now.passivesUnlocked > baseline.passivesUnlocked
        case .floorChanged: now.visibleFloor != baseline.visibleFloor
        case .pinned: now.pinnedTypeId != nil && now.pinnedTypeId != baseline.pinnedTypeId
        case .unpinned: baseline.pinnedTypeId != nil && now.pinnedTypeId == nil
        case .lessonAction: lesson.map { events.contains(.lessonAction($0)) } ?? false
        case .screenOpened(let screen): events.contains(.screenOpened(screen))
        case .pagerMoved: events.contains(.pagerMoved)
        case .pickerOpened: events.contains(.pickerOpened)
        case .elevatorExpanded: events.contains(.elevatorExpanded)
        case .characterSheetOpened: events.contains(.characterSheetOpened)
        }
    }
}
```

- [ ] **Step 4: La corrida**

`FisuEvolution/Game/Tutorial/TutorialRun.swift`:

```swift
import Foundation

/// Lo que el tutorial está mostrando ahora: un guion, en qué paso va y contra qué foto se
/// mide. Pura: el director (`GameState+Tutorial`) la mueve; la UI sólo la lee.
struct TutorialRun: Equatable {
    enum Script: Equatable {
        case core
        /// El id de la lección (`TutorialLesson.rawValue`, o el de una tarjeta).
        case lesson(String)
        case tour
        case replay
    }

    let script: Script
    let steps: [TutorialStep]
    private(set) var index = 0
    private(set) var baseline: TutorialProbe
    var events: Set<TutorialEvent> = []
    /// El candado del paso actual ya se abrió. Se publica una vez por paso (no por frame).
    var unlocked = false

    init(script: Script, steps: [TutorialStep], probe: TutorialProbe) {
        self.script = script
        self.steps = steps
        self.baseline = probe
    }

    var step: TutorialStep? { steps.indices.contains(index) ? steps[index] : nil }
    var isFinished: Bool { index >= steps.count }
    /// El Tour y el repaso señalan y explican, sin exigir acciones: el estado es arbitrario.
    var isDemo: Bool { script == .tour || script == .replay }

    var lessonID: String? {
        if case .lesson(let id) = script { return id }
        return nil
    }

    func isStepSatisfied(probe: TutorialProbe) -> Bool {
        guard let signal = step?.signal else { return false }
        return signal.isSatisfied(baseline: baseline, now: probe, events: events, lesson: lessonID)
    }

    mutating func advance(probe: TutorialProbe) {
        index += 1
        baseline = probe
        events.removeAll()
        unlocked = false
    }

    /// Un paso que vive en una hoja no tiene sentido con la hoja cerrada: vuelve al último
    /// paso de tablero (el que la abre). Devuelve si rebobinó.
    mutating func rewindToBoard(probe: TutorialProbe) -> Bool {
        guard let step, step.surface != .board, step.surface != .embedded,
              let board = steps[..<index].lastIndex(where: { $0.surface == .board }) else { return false }
        index = board
        baseline = probe
        events.removeAll()
        unlocked = false
        return true
    }
}
```

- [ ] **Step 5: Las banderas**

`FisuEvolution/Game/Tutorial/TutorialFlags.swift`:

```swift
import EconomyKit
import Foundation

/// Las banderas del tutorial en `UserDefaults` (PLAN-v2 E9). Es el único lugar que las nombra:
/// nadie más escribe `fisuTutorialDone` ni `tutorial.v2.*` a mano.
///
/// Son de la **partida** (se van con `--uitest-reset` y con "Resetear partida"); las del
/// dispositivo —idioma, audio, avisos, UMP, ATT— no pasan por acá.
enum TutorialFlags {
    static let currentVersion = 1
    static let versionKey = "tutorial.v2.version"
    static let completedKey = "tutorial.v2.completed"
    static let tourPendingKey = "tutorial.v2.tourPending"
    /// La de la v1. Sólo la lee la migración.
    static let legacyCompletedKey = "fisuTutorialDone"
    static let lessonPrefix = "tutorial.lesson."
    static let milestoneKeys = ["ftue.tapped", "ftue.spawned", "ftue.merged"]
    static let sessionsAfterCoreKey = "tutorial.sessionsAfterPhase"
    /// El "¡Nuevo!" de las pestañas (E3a T9, `GameState.newTabsKey`): una partida nueva las
    /// vuelve a cerrar, así que sus "¡Nuevo!" también se van.
    static let newTabsKey = "tabs.new"

    static func lessonKey(_ id: String) -> String { lessonPrefix + id }

    static func coreCompleted(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: completedKey)
    }

    static func setCoreCompleted(_ done: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(done, forKey: completedKey)
    }

    static func tourPending(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: tourPendingKey)
    }

    static func setTourPending(_ pending: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(pending, forKey: tourPendingKey)
    }

    static func isLessonDone(_ id: String, in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: lessonKey(id))
    }

    static func markLessonDone(_ id: String, in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: lessonKey(id))
    }

    /// Deja la instalación en la versión de hoy (sin Tour pendiente).
    static func markCurrent(in defaults: UserDefaults = .standard) {
        defaults.set(currentVersion, forKey: versionKey)
    }

    /// Una partida nueva de verdad: el núcleo vuelve, las lecciones también, y no es un
    /// veterano (la versión queda puesta).
    static func wipeGameFlags(in defaults: UserDefaults = .standard) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(lessonPrefix) {
            defaults.removeObject(forKey: key)
        }
        for key in milestoneKeys { defaults.set(false, forKey: key) }
        defaults.removeObject(forKey: sessionsAfterCoreKey)
        defaults.removeObject(forKey: newTabsKey)
        defaults.removeObject(forKey: legacyCompletedKey)
        setCoreCompleted(false, in: defaults)
        setTourPending(false, in: defaults)
        markCurrent(in: defaults)
    }

    /// Corre una vez por instalación, en el bootstrap.
    @discardableResult
    static func migrate(hasSave: Bool, veteranKnownLessons: Set<String>,
                        in defaults: UserDefaults = .standard) -> TutorialMigration.Plan? {
        let legacyLessons = Set(defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(lessonPrefix) && defaults.bool(forKey: $0) }
            .map { String($0.dropFirst(lessonPrefix.count)) })
        let input = TutorialMigration.Input(
            hasSave: hasSave,
            storedVersion: defaults.object(forKey: versionKey) as? Int,
            legacyCoreDone: defaults.bool(forKey: legacyCompletedKey),
            legacyLessonsDone: legacyLessons
        )
        guard let plan = TutorialMigration.plan(input, currentVersion: currentVersion,
                                                veteranKnownLessons: veteranKnownLessons) else { return nil }
        setCoreCompleted(plan.coreCompleted, in: defaults)
        setTourPending(plan.tourPending, in: defaults)
        for id in plan.lessonsDone { markLessonDone(id, in: defaults) }
        defaults.set(plan.version, forKey: versionKey)
        defaults.removeObject(forKey: legacyCompletedKey)
        return plan
    }
}
```

- [ ] **Step 6: Verde**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialModelTests -only-testing:FisuEvolutionTests/TutorialFlagsTests`
Expected: PASS (11 tests).

- [ ] **Step 7: Oráculo y commit**

Run: `Tools/v2/oraculo.sh rapido` → `VERDE`.

```bash
git add FisuEvolution/Game/Tutorial/TutorialStep.swift FisuEvolution/Game/Tutorial/TutorialRun.swift
git add FisuEvolution/Game/Tutorial/TutorialFlags.swift
git add FisuEvolutionTests/TutorialModelTests.swift FisuEvolutionTests/TutorialFlagsTests.swift
git diff --cached --stat
git commit -m "feat(tutorial): el paso, la corrida y las banderas de la 2.0, como valores"
```

---

### Task 3: Las banderas cableadas — `tutorial.v2.*` en todos los lectores y la migración en el arranque

**Objetivo:** que nadie lea más `"fisuTutorialDone"`: el arranque corre la migración (un veterano
queda con el núcleo hecho y el Tour pendiente), el gate del núcleo y todos los lectores pasan por
`TutorialFlags`, y las puertas de UI escriben las banderas nuevas. **Sin cambio de conducta** para
una instalación nueva ni para los tests de UI de hoy.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState.swift` 🔥 (`finishBootstrap`: la migración y el gate)
- Modify: `FisuEvolution/App/RootView.swift` 🔥 (`@AppStorage` de la ficha, `:113`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialOverlay.swift` (`@AppStorage`, `:20`)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`applyLaunchArgumentDefaults`, `:256-260`, `debugResetSave`)
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift` (`introducedIn`, `wipeTutorialLessonProgress`)
- Modify: `FisuEvolution/Game/State/GameState+Tabs.swift` (E3a T9: `tutorialCoreDone`)
- Modify: `FisuEvolution/Game/State/GameState+Notifications.swift` (E11 T6: el default de `notificationsLaunched`)
- Modify: `FisuEvolutionTests/CelebrationWiringTests.swift` (`:469-480`), `FisuEvolutionTests/TabUnlockWiringTests.swift` (E3a T9: las claves que guarda y restaura)
- Create: `FisuEvolutionTests/TutorialBootstrapTests.swift`

**Interfaces:**
- Consumes: `TutorialFlags` (T2).
- Produces: `GameState.TutorialLesson.introducedIn: TutorialRelease` (`enum TutorialRelease { v1, v2 }`),
  `static var veteranKnownLessons: Set<String>`; `GameState.applyTutorialMigration(hasSave:)`.

- [ ] **Step 0: Los lectores**

Run: `grep -rn "fisuTutorialDone" --include='*.swift' FisuEvolution FisuEvolutionTests FisuEvolutionUITests`
Expected: `GameState.swift` (gate), `RootView.swift`, `TutorialOverlay.swift`, `+Debug` (cuatro),
`+Tabs` (E3a T9), `+Notifications` (E11 T6), `CelebrationWiringTests`, `TabUnlockWiringTests` y el
comentario de `LaunchSmokeTests`. Cada uno (salvo el comentario y la migración) pasa a
`TutorialFlags`. Si aparece otro, se suma a la lista y al reporte.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/TutorialBootstrapTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La migración corre en el arranque. Bajo XCTest el gate del núcleo sigue apagado (cada test
/// arma su escenario), pero la migración sí corre: es lo que hace al veterano.
@Suite("Las banderas del tutorial en el arranque", .serialized)
@MainActor
struct TutorialBootstrapTests {
    private let keys = [TutorialFlags.versionKey, TutorialFlags.completedKey,
                        TutorialFlags.tourPendingKey, TutorialFlags.legacyCompletedKey]

    private func withSavedDefaults(_ body: () async throws -> Void) async rethrows {
        let defaults = UserDefaults.standard
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        for key in keys { defaults.removeObject(forKey: key) }
        try await body()
    }

    @Test("un veterano (save + la bandera de la v1) arranca con el núcleo hecho y el Tour pendiente")
    func veteranBoot() async throws {
        try await withSavedDefaults {
            UserDefaults.standard.set(true, forKey: TutorialFlags.legacyCompletedKey)
            let gameState = GameState(repository: PlayerStateRepository(
                persistence: PersistenceController(inMemory: true),
                snapshotURL: FileManager.default.temporaryDirectory.appending(path: "boot-\(UUID().uuidString).json")
            ))
            gameState.applyTutorialMigration(hasSave: true)
            #expect(TutorialFlags.coreCompleted())
            #expect(TutorialFlags.tourPending())
            for id in GameState.TutorialLesson.veteranKnownLessons {
                #expect(TutorialFlags.isLessonDone(id), "\(id): la v1 ya la enseñaba")
            }
        }
    }

    @Test("lo nuevo de la 2.0 no se da por visto: se le enseña al veterano la primera vez")
    func newMechanicsAreNotKnown() {
        let known = GameState.TutorialLesson.veteranKnownLessons
        for lesson in GameState.TutorialLesson.allCases where lesson.introducedIn == .v2 {
            #expect(!known.contains(lesson.rawValue), "\(lesson)")
        }
    }
}
```

En `CelebrationWiringTests.swift:469-480`, el test que hoy escribe y lee `"fisuTutorialDone"`
pasa a `TutorialFlags.setCoreCompleted(true)` / `TutorialFlags.coreCompleted()` (misma aserción).

- [ ] **Step 2: Verlo fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialBootstrapTests`.
Expected: no compila (`applyTutorialMigration`, `veteranKnownLessons`, `introducedIn` no existen).

- [ ] **Step 3: Qué enseñaba la v1**

En `GameState+TutorialTips.swift`, junto al `enum TutorialLesson`:

```swift
    /// En qué versión nació la mecánica que enseña la lección. Al veterano de la v1 se le dan
    /// por vistas las de la v1 (`TutorialMigration`); las de la 2.0 las ve en su primera vez.
    enum TutorialRelease: Equatable, Sendable {
        case v1
        case v2
    }
```

y en `extension GameState.TutorialLesson` (o adentro del enum):

```swift
        var introducedIn: TutorialRelease {
            switch self {
            case .upgrades, .elevator, .skins, .achievements, .oroUpgrades, .gifts, .store, .prestige: .v1
            // El atajo cambió entero (pin, nunca desaparece): al veterano se lo enseña el Tour.
            case .quickHire: .v2
            default: .v2
            }
        }

        static var veteranKnownLessons: Set<String> {
            Set(allCases.filter { $0.introducedIn == .v1 }.map(\.rawValue))
        }
```

⚠️ El `default` existe sólo hasta E9b T1–T3, que reescriben el `switch` entero, caso por caso,
con las lecciones nuevas (`TutorialCoverageTests` lo vigila: T9). `wipeTutorialLessonProgress()`
pasa a delegar en `TutorialFlags.wipeGameFlags()` **sólo para las lecciones y el contador** (no
toca el núcleo: lo sigue usando `--uitest-reset`, que ya resetea todo por su lado):

```swift
    func wipeTutorialLessonProgress() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(TutorialFlags.lessonPrefix) {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: TutorialFlags.sessionsAfterCoreKey)
    }
```

- [ ] **Step 4: La migración en el arranque (🔥 `GameState.swift`)**

En una extensión nueva al final de `GameState+TutorialTips.swift` (archivo tibio, no el caliente):

```swift
extension GameState {
    /// Corre una vez por instalación (las siguientes es un `nil`). Un veterano es quien tiene
    /// save y ninguna versión: queda con el núcleo hecho y el Tour pendiente (E9b).
    func applyTutorialMigration(hasSave: Bool) {
        guard let plan = TutorialFlags.migrate(hasSave: hasSave,
                                                veteranKnownLessons: TutorialLesson.veteranKnownLessons)
        else { return }
        Log.lifecycle.info("tutorial migrado: núcleo \(plan.coreCompleted), tour \(plan.tourPending)")
    }
}
```

En `GameState.swift`, `finishBootstrap(isFreshInstall:)`, el bloque del gate (hoy `:740-760`)
queda así (la migración va **fuera** del `if` de XCTest: los tests la ejercitan; el gate no):

```swift
        applyTutorialMigration(hasSave: !isFreshInstall)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            if !TutorialFlags.coreCompleted() {
                beginTutorialPhase()
            } else {
                let sessions = UserDefaults.standard.integer(forKey: TutorialFlags.sessionsAfterCoreKey)
                UserDefaults.standard.set(sessions + 1, forKey: TutorialFlags.sessionsAfterCoreKey)
            }
        }
```

(conservando los comentarios que ya tiene ese bloque). `Self.sessionsAfterPhaseKey` queda como
alias de `TutorialFlags.sessionsAfterCoreKey` para no romper a E3a T9:
`static let sessionsAfterPhaseKey = TutorialFlags.sessionsAfterCoreKey`.

⚠️ `applyLaunchArgumentDefaults` corre **antes** del bootstrap: con `--uitest-reset` la
versión queda puesta (Step 5) y la migración devuelve `nil`. Un `--uitest-*` nunca es veterano
salvo `--uitest-veteran` (E9b T4).

- [ ] **Step 5: Los demás lectores**

- `RootView.swift:113` 🔥: `@AppStorage(TutorialFlags.completedKey) private var tutorialDone = false`.
- `TutorialOverlay.swift:20`: `@AppStorage(TutorialFlags.completedKey) private var done = false`
  (T5 lo borra: el núcleo pasa al director).
- `+Debug`, `applyLaunchArgumentDefaults`: en el bloque de `--uitest-reset`, las cuatro líneas de
  `fisuTutorialDone`/`ftue.*` pasan a `TutorialFlags.wipeGameFlags(in: defaults)` (más el espejo
  en memoria `ftueTapped = false`… que ya está); en `--uitest-skip-tutorial`/`--uitest-open-sheet`:
  `TutorialFlags.setCoreCompleted(true, in: defaults); TutorialFlags.markCurrent(in: defaults)`.
  En `:256-260` (el fixture que deja la ficha abierta): `TutorialFlags.setCoreCompleted(true)`.
  En `debugResetSave`: `TutorialFlags.wipeGameFlags()` en lugar de las cuatro líneas.
- `+Tabs` (E3a T9): `tutorialCoreDone: TutorialFlags.coreCompleted()`.
- `+Notifications` (E11 T6): `tutorialDone: Bool = TutorialFlags.coreCompleted()`.
- `TabUnlockWiringTests` (E3a T9): guarda y restaura `TutorialFlags.completedKey` en lugar de
  `"fisuTutorialDone"`.

Run: `grep -rn "fisuTutorialDone" --include='*.swift' FisuEvolution FisuEvolutionTests FisuEvolutionUITests`
Expected: sólo `TutorialFlags.swift` (la constante legacy) y el comentario de `LaunchSmokeTests`.

- [ ] **Step 6: Verde, UI y oráculo**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialBootstrapTests -only-testing:FisuEvolutionTests/CelebrationWiringTests -only-testing:FisuEvolutionTests/TabUnlockWiringTests -only-testing:FisuEvolutionTests/TutorialTipsTests`
→ PASS. UI: `-only-testing:FisuEvolutionUITests/TutorialUITests -only-testing:FisuEvolutionUITests/LaunchSmokeTests -only-testing:FisuEvolutionUITests/ProgressiveTabsUITests`
→ PASS sin cambios (la conducta no cambió). `Tools/v2/oraculo.sh rapido` → `VERDE`.

A mano (simulador propio): instalar la build de `version-2` **sin** E9 (o una v1), jugar el núcleo,
instalar ésta encima: el núcleo no vuelve y `defaults read <bundle> tutorial.v2.tourPending` = 1.
Captura del `defaults read` al reporte.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/State/GameState.swift FisuEvolution/App/RootView.swift
git add FisuEvolution/UI/Tutorial/TutorialOverlay.swift FisuEvolution/Game/State/GameState+Debug.swift
git add FisuEvolution/Game/State/GameState+TutorialTips.swift FisuEvolution/Game/State/GameState+Tabs.swift
git add FisuEvolution/Game/State/GameState+Notifications.swift
git add FisuEvolutionTests/TutorialBootstrapTests.swift FisuEvolutionTests/CelebrationWiringTests.swift
git add FisuEvolutionTests/TabUnlockWiringTests.swift
git diff --cached --stat
git commit -m "feat(tutorial): las banderas de la 2.0 y el veterano reconocido al arrancar"
```

---

### Task 4: El director — una corrida, pasos con señal, ritmo y watchdog

**Objetivo:** reemplazar el director de lecciones de la v1 por uno que corre **guiones de
pasos**: cada lección declara sus `steps`, el director arma la corrida (`tutorialRun`), la avanza
por señales contra la foto del inicio del paso, cuenta el reloj con el tick y respeta el ritmo.
**Todas las lecciones de hoy migran a un paso** que repite exactamente su conducta de hoy (señalar
y cumplirse al hacer lo que señalan): el renderer sigue siendo `TutorialTipView` hasta T6.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState.swift` 🔥 (`tutorialRun`, `tutorialEngine`, `tutorialTip` como alias; `refreshTutorial()` en `refreshProjections`)
- Create: `FisuEvolution/Game/State/GameState+Tutorial.swift`
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift` (`steps`; el director viejo sale)
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift` (`advanceCelebrations`, `skipCurrentCelebration`, `releasePayload(.tutorialTip)`)
- Modify: `FisuEvolution/Game/State/GameState+Menu.swift` (E3b: la página abierta, `pagerMoved`)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`--uitest-tutorial-lock`, `--uitest-lesson`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialTipView.swift` (lee el paso: texto y ancla)
- Create: `FisuEvolutionTests/TutorialDirectorTests.swift`
- Modify: `FisuEvolutionTests/TutorialTipsTests.swift` (los que miraban el timeout de 12 s)

**Interfaces:**
- Consumes: T1, T2, T3; `isCalmMoment` (E4a T8); `menuPageChanged(to:)` (E3b T4).
- Produces (todo `@MainActor`, en `GameState`):
  - `var tutorialRun: TutorialRun?` (observado), `@ObservationIgnored var tutorialEngine: TutorialEngine`
    (`struct TutorialEngine { var clock; var pacing; var openPage: GameScreen?; var lockSeconds }`);
  - `var tutorialTip: TutorialTip?` pasa a **calculada** (`tutorialRun` con `.lesson(id)` →
    `TutorialTip(lesson:)`): E4b, E5b y E7b-b la leen en sus tests y siguen compilando;
  - `refreshTutorial()`, `advanceTutorial(delta:)`, `confirmTutorialStep()`,
    `tutorialSignal(_ event: TutorialEvent)`, `tutorialProbe() -> TutorialProbe`,
    `var tutorialStepIsVisible: Bool`, `var tutorialLockProgress: Double`;
  - se conservan con la misma firma (las llaman vistas de E3–E7b): `tutorialTipCompleted(_:)`,
    `tutorialTipHandled(opening:)`, `dismissTutorialTip()`, `markLessonDone(_:)`;
  - `TutorialLesson.steps: [TutorialStep]`.

- [ ] **Step 0: Lo que heredó el director**

Run: `grep -n "case \|func isEligible\|tutorialTipCompleted\|tutorialTipHandled" FisuEvolution/Game/State/GameState+TutorialTips.swift`
y `grep -rn "tutorialTipCompleted(\|tutorialTipHandled(\|tutorialTip?\.\|\.tutorialTip\b" --include='*.swift' FisuEvolution FisuEvolutionTests | grep -v "+TutorialTips"`.
Expected: las 18 lecciones (las 9 de la v1 + `share`, `visitor`, `eventChip`, `album`,
`packages`, `mattress`, `wheel`, `sideRail`, `mergeAllVideo`) y la lista de llamadores. Cada
llamador sigue funcionando sin cambios: el director viejo se reemplaza **detrás** de esas firmas.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/TutorialDirectorTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El director del tutorial v2", .serialized)
@MainActor
struct TutorialDirectorTests {
    private func makeGameState() async -> GameState {
        for lesson in GameState.TutorialLesson.allCases {
            UserDefaults.standard.removeObject(forKey: lesson.defaultsKey)
        }
        UserDefaults.standard.removeObject(forKey: TutorialFlags.sessionsAfterCoreKey)
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "director-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        return gameState
    }

    @Test("una lección nace como corrida de pasos y toma el turno de la cola")
    func aLessonBecomesARun() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .lesson("upgrades"))
        #expect(gameState.tutorialRun?.step != nil)
        #expect(gameState.showing == .tutorialTip)
        #expect(gameState.tutorialTip?.lesson == .upgrades, "el alias que leen los tests de E4b/E5b/E7b-b")
    }

    @Test("hacer lo que señala la cumple, y la siguiente espera 20 s")
    func pacingAfterALesson() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        gameState.tutorialTipHandled(opening: .upgrades)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.upgrades.defaultsKey))
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "a los 0 s del fin no nace otra (con plata, el atajo ya es elegible)")
        gameState.advanceTutorial(delta: 20)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun != nil)
    }

    @Test("con el dedo en el tablero en el último segundo no nace ninguna")
    func quietBoard() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        _ = gameState.skipCurrentCelebration()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        gameState.advanceTutorial(delta: 1)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun != nil)
    }

    @Test("el reloj del paso corre sólo con el paso a la vista")
    func theClockRunsOnlyWhenVisible() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        gameState.uiCoversBoard = true
        gameState.advanceTutorial(delta: 3)
        #expect(gameState.tutorialEngine.clock.elapsed == 0)
        gameState.uiCoversBoard = false
        gameState.advanceTutorial(delta: 3)
        #expect(gameState.tutorialEngine.clock.elapsed == 3)
    }

    @Test("un paso de acción trabado 3 min se libera, sin premio, y la lección queda dada")
    func theWatchdog() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        let oro = gameState.player?.meta.oro
        let coins = gameState.player?.run.coins
        gameState.advanceTutorial(delta: 179)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun != nil)
        gameState.advanceTutorial(delta: 1)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.upgrades.defaultsKey))
        #expect(gameState.player?.meta.oro == oro)
        #expect(gameState.player?.run.coins == coins)
    }

    @Test("«Entendido» no hace nada con el candado puesto")
    func confirmRespectsTheLock() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: [
            .explain("probe.one", text: "tutorial.step.finish"),
            .explain("probe.two", text: "tutorial.step.finish"),
        ])
        gameState.advanceTutorial(delta: 4.9)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun?.index == 0)
        gameState.advanceTutorial(delta: 0.1)
        #expect(gameState.tutorialRun?.unlocked == true)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun?.index == 1)
        #expect(gameState.tutorialRun?.unlocked == false, "el paso siguiente vuelve a esperar sus 5 s")
    }

    @Test("una lección en pantalla congela los relojes con paciencia (no es un momento calmo)")
    func lessonsFreezePatience() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.showing == .tutorialTip)
        #expect(!gameState.isCalmMoment)
    }
}
```

`startTutorialRun(_:steps:)` es interno (lo usan T5, E9b y los tests: arma la corrida, encola
`.tutorialTip` salvo para `.core`, y reinicia el reloj).

En `TutorialTipsTests.swift`: el test que contaba con el timeout de 12 s (o con el tap que
saltea) pasa a usar `advanceTutorial(delta: 180)` (watchdog) para "una lección ignorada se da
igual"; los demás no cambian (las firmas que usan siguen).

- [ ] **Step 2: Verlo fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/TutorialDirectorTests`.
Expected: no compila (`tutorialRun`, `advanceTutorial`, `startTutorialRun` no existen).

- [ ] **Step 3: El estado (🔥 `GameState.swift`)**

Al lado de `tutorialPhaseActive` (`:280`):

```swift
    /// Lo que el tutorial está mostrando (PLAN-v2 E9): el núcleo, una lección, el Tour o el
    /// repaso. La UI sólo lee esto; lo mueve el director (`+Tutorial`).
    var tutorialRun: TutorialRun?
    /// El reloj del paso, el ritmo y la página abierta: cambian por frame, así que no se
    /// observan. La UI que dibuja el candado los lee por `TimelineView`.
    @ObservationIgnored var tutorialEngine = TutorialEngine()
```

Se borra la almacenada `var tutorialTip: TutorialTip?` (`:349`): pasa a calculada en `+Tutorial`.
En `refreshProjections()`, la última línea `refreshTutorialTip()` pasa a `refreshTutorial()`.

- [ ] **Step 4: Los pasos de las lecciones de hoy**

En `GameState+TutorialTips.swift`, cada lección declara sus pasos. Hasta E9b, **uno**, que repite
lo de hoy: si tiene pantalla de destino, abrirla; si no, la acción firma (`tutorialTipCompleted`).
Sale del `anchorTarget`, `destinationScreen` y `textKey` que ya tiene:

```swift
        /// El guion de la lección (PLAN-v2 E9). E9b los reescribe uno por uno; hasta entonces,
        /// uno solo: el destino de siempre, con el texto de siempre.
        var steps: [TutorialStep] {
            [legacyStep]
        }

        var legacyStep: TutorialStep {
            let signal: TutorialSignal = destinationScreen.map { .screenOpened($0) } ?? .lessonAction
            return .act("\(rawValue).legacy", signal, text: textKey, on: anchorTarget)
        }
```

- [ ] **Step 5: El director**

`FisuEvolution/Game/State/GameState+Tutorial.swift`:

```swift
import EconomyKit
import Foundation

/// El reloj, el ritmo y la página abierta del tutorial: cambian por frame y no se observan.
struct TutorialEngine {
    var clock = TutorialStepClock(kind: .explain)
    var pacing = TutorialPacing()
    /// La página del menú a la vista (`menuDidOpen`/`menuPageChanged`); `nil` con el tablero.
    var openPage: GameScreen?
    /// 5 s; `--uitest-tutorial-lock=<s>` lo baja para los fixtures de UI.
    var lockSeconds = TutorialStepClock.explainLock
}

/// El director del tutorial v2 (PLAN-v2 E9): arranca guiones, los avanza por señales, cuenta
/// el candado con el tick y respeta el ritmo. Es la única puerta de entrada y de salida.
extension GameState {
    /// El alias de la v1: lo leen las vistas y los tests de E3b–E7b-b.
    var tutorialTip: TutorialTip? {
        guard let id = tutorialRun?.lessonID, let lesson = TutorialLesson(rawValue: id) else { return nil }
        return TutorialTip(lesson: lesson)
    }

    // MARK: Entradas

    /// Corre al final de `refreshProjections` (8 Hz) contra señales ya publicadas.
    func refreshTutorial() {
        guard phase == .ready else { return }
        if !uiCoversBoard { tutorialEngine.openPage = nil }
        if tutorialRun != nil {
            progressTutorialRun()
            return
        }
        startNextLessonIfDue()
    }

    /// Lo llama `advanceCelebrations(delta:)`, que corre en cada tick con el delta clampeado.
    func advanceTutorial(delta: TimeInterval) {
        tutorialEngine.pacing.tick(delta)
        guard tutorialStepIsVisible, var run = tutorialRun else { return }
        tutorialEngine.clock.tick(delta)
        if tutorialEngine.clock.canConfirm, !run.unlocked {
            run.unlocked = true
            tutorialRun = run
        }
        if tutorialEngine.clock.watchdogExpired, let step = run.step {
            Log.lifecycle.error("tutorial: paso trabado liberado por watchdog: \(step.id, privacy: .public)")
            advanceTutorialStep()
        }
    }

    /// El botón "Entendido". Con el candado puesto no hace nada (la tarjeta tiembla).
    func confirmTutorialStep() {
        guard let run = tutorialRun, run.step?.clockKind == .explain, run.unlocked else { return }
        advanceTutorialStep()
    }

    /// Lo que avisan las vistas y no queda en el save.
    func tutorialSignal(_ event: TutorialEvent) {
        guard var run = tutorialRun else { return }
        run.events.insert(event)
        tutorialRun = run
        progressTutorialRun()
    }

    /// El jugador hizo la acción firma de la lección (abrió el mapa, reencarnó…).
    func tutorialTipCompleted(_ lesson: TutorialLesson) {
        tutorialSignal(.lessonAction(lesson.rawValue))
    }

    /// Abrió (o deslizó hasta) una pestaña.
    func tutorialTipHandled(opening screen: GameScreen) {
        tutorialEngine.openPage = screen
        tutorialSignal(.screenOpened(screen))
    }

    /// El botón del globo de la v1 (`TutorialTipView`, hasta T6): termina la lección.
    func dismissTutorialTip() {
        guard showing == .tutorialTip else { return }
        celebrationFinished(.tutorialTip)
    }

    // MARK: Lo que la UI lee

    var tutorialStepIsVisible: Bool {
        guard let run = tutorialRun, let step = run.step else { return false }
        if run.script == .core {
            guard showing == nil else { return false }
        } else if !isInlineRun(run) {
            guard showing == .tutorialTip else { return false }
        }
        switch step.surface {
        case .board: return !uiCoversBoard
        case .page(let screen): return tutorialEngine.openPage == screen
        case .characterSheet: return characterSheet != nil
        case .embedded: return true
        }
    }

    var tutorialLockProgress: Double { tutorialEngine.clock.lockProgress }

    func tutorialProbe() -> TutorialProbe {
        guard let player else { return TutorialProbe() }
        return TutorialProbe(
            taps: player.meta.stats.totalTapsEver,
            hires: player.meta.stats.totalHiresEver,
            merges: player.meta.stats.totalMergesEver,
            upgradeLevels: player.run.charUpgradeLevels.values.reduce(0, +)
                + player.meta.oroUpgradeLevels.values.reduce(0, +),
            passivesUnlocked: player.run.passiveUnlocked.values.filter { $0 }.count,
            visibleFloor: visibleFloorOrdinal,
            pinnedTypeId: player.meta.quickHirePinnedTypeId,
            canAffordSpawn: canAffordSpawn,
            ftueTapped: ftueTapped,
            ftueSpawned: ftueSpawned,
            ftueMerged: ftueMerged
        )
    }

    // MARK: El guion

    func startTutorialRun(_ script: TutorialRun.Script, steps: [TutorialStep]) {
        tutorialRun = TutorialRun(script: script, steps: steps, probe: tutorialProbe())
        resetTutorialClock()
        if script != .core, !(tutorialRun.map(isInlineRun) ?? false) {
            celebrations.enqueue(.tutorialTip)
            publishCelebration()
        }
    }

    private func startNextLessonIfDue() {
        guard tutorialLessonsAutorun, !tutorialPhaseActive, showing == nil,
              tutorialEngine.pacing.mayStartLesson,
              !uiCoversBoard, characterSheet == nil, shareCardSubject == nil,
              let lesson = TutorialLesson.allCases.first(where: { !isLessonDone($0) && isEligible($0) })
        else { return }
        startTutorialRun(.lesson(lesson.rawValue), steps: lesson.steps)
    }

    private func progressTutorialRun() {
        guard var run = tutorialRun else { return }
        let probe = tutorialProbe()
        // La regla de oro hasta el último frame: una lección que todavía no tomó el turno y
        // cuya condición murió se retira SIN marcarse.
        if let id = run.lessonID, let lesson = TutorialLesson(rawValue: id),
           showing != .tutorialTip, run.index == 0, !isEligible(lesson) {
            tutorialRun = nil
            celebrations.finish(.tutorialTip)
            return
        }
        if !uiCoversBoard, run.rewindToBoard(probe: probe) {
            tutorialRun = run
            resetTutorialClock()
            return
        }
        if run.isStepSatisfied(probe: probe) {
            advanceTutorialStep()
        }
    }

    func advanceTutorialStep() {
        guard var run = tutorialRun else { return }
        run.advance(probe: tutorialProbe())
        if run.isFinished {
            tutorialRun = run
            finishTutorialRun()
        } else {
            tutorialRun = run
            resetTutorialClock()
        }
    }

    /// Fin de corrida. Las lecciones salen por la cola (`releasePayload` las marca dadas).
    func finishTutorialRun() {
        guard let run = tutorialRun else { return }
        switch run.script {
        case .core:
            tutorialRun = nil
            finishTutorialCore()
        case .lesson:
            if isInlineRun(run) {
                if let id = run.lessonID { TutorialFlags.markLessonDone(id) }
                tutorialRun = nil
                tutorialEngine.pacing.lessonEnded()
            } else {
                celebrationFinished(.tutorialTip)
            }
        case .tour, .replay:
            celebrationFinished(.tutorialTip)
        }
    }

    private func resetTutorialClock() {
        let kind = tutorialRun?.step?.clockKind ?? .explain
        tutorialEngine.clock = TutorialStepClock(kind: kind, lock: tutorialEngine.lockSeconds)
    }

    /// Las tarjetas de las primeras veces (T8) no pasan por la cola: las aloja su popup.
    func isInlineRun(_ run: TutorialRun) -> Bool {
        run.steps.first?.surface == .embedded
    }
}
```

`isEligible(_:)` e `isLessonDone(_:)` siguen en `+TutorialTips` (pasan de `private` a internos
para que los use `+Tutorial`); `isLessonDone` lee `TutorialFlags.isLessonDone(rawValue)` y
`markLessonDone` escribe `TutorialFlags.markLessonDone(rawValue)`. La función vieja
`refreshTutorialTip()` y su cuerpo se **borran**. `finishTutorialCore()` es de T5: hasta entonces,
el `case .core` llama a `tutorialPhaseFinished()`.

- [ ] **Step 6: El tick, el tablero y la salida (`+Celebrations`)**

```swift
    func advanceCelebrations(delta: TimeInterval) {
        advanceTutorial(delta: delta)
        guard let expired = celebrations.tick(delta) else { return }
        // (el resto, igual)
    }

    @discardableResult
    func skipCurrentCelebration() -> Bool {
        tutorialEngine.pacing.boardTouched()
        guard let showingNow = celebrations.current else { return false }
        // (el resto, igual)
    }
```

`releasePayload(for: .tutorialTip)`:

```swift
        case .tutorialTip:
            // Su turno terminó (el último paso, el watchdog o —hasta T6— el timeout): la
            // lección queda dada y el ritmo empieza a contar. El Tour y el repaso no marcan
            // lecciones acá: lo hacen al terminar (E9b).
            if let id = tutorialRun?.lessonID { TutorialFlags.markLessonDone(id) }
            tutorialRun = nil
            tutorialEngine.pacing.lessonEnded()
```

`publishCelebration()` pasa de `private` a interno (lo llama `startTutorialRun`).

- [ ] **Step 7: La página abierta (`+Menu`, E3b)**

```swift
    func menuDidOpen(at screen: GameScreen) {
        tutorialTipHandled(opening: screen)
    }

    func menuPageChanged(to screen: GameScreen) {
        tutorialTipHandled(opening: screen)
        tutorialSignal(.pagerMoved)
        markTabOpened(screen)
    }
```

(conservando lo que E3b T4 haya sumado). `menuDidClose()` suma `tutorialEngine.openPage = nil`.

- [ ] **Step 8: Las puertas (`+Debug`)**

En `applyLaunchArgumentDefaults`:

```swift
        if let lock = arguments.first(where: { $0.hasPrefix("--uitest-tutorial-lock=") })?
            .split(separator: "=").last.flatMap({ TimeInterval($0) }) {
            tutorialEngine.lockSeconds = lock
        }
        if let forced = arguments.first(where: { $0.hasPrefix("--uitest-lesson=") })?
            .split(separator: "=").last.map(String.init) {
            tutorialEngine.forcedLesson = forced
        }
```

con `var forcedLesson: String?` en `TutorialEngine`, y en `startNextLessonIfDue()` la lección
forzada gana sobre el orden (si no está dada; `--uitest-lesson` implica `--uitest-lessons`: se
suma a la condición que deja `tutorialLessonsAutorun` prendido).

- [ ] **Step 9: `TutorialTipView` lee el paso**

`TutorialTipView.marks(_:)` usa `gameState.tutorialRun?.step` para el ancla (`step.target`) y el
texto (`LocalizedStringKey(step.textKey)`); `visibleTip` pasa a
`gameState.tutorialStepIsVisible ? gameState.tutorialTip : nil`. Nada más: el renderer único es
T6.

- [ ] **Step 10: Verde y oráculo**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialDirectorTests -only-testing:FisuEvolutionTests/TutorialTipsTests -only-testing:FisuEvolutionTests/CelebrationWiringTests -only-testing:FisuEvolutionTests/MenuSessionTests`
→ PASS. Los de lecciones de otras épicas (`PrizeAccessTests`, los de E4b y E7b-b que miran
`tutorialTip?.lesson`) → PASS sin cambios. UI: `TutorialUITests` → PASS (la lección de Mejoras
nace y se cumple igual). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 11: Commit**

```bash
git add FisuEvolution/Game/State/GameState.swift FisuEvolution/Game/State/GameState+Tutorial.swift
git add FisuEvolution/Game/State/GameState+TutorialTips.swift FisuEvolution/Game/State/GameState+Celebrations.swift
git add FisuEvolution/Game/State/GameState+Menu.swift FisuEvolution/Game/State/GameState+Debug.swift
git add FisuEvolution/UI/Tutorial/TutorialTipView.swift
git add FisuEvolutionTests/TutorialDirectorTests.swift FisuEvolutionTests/TutorialTipsTests.swift
git diff --cached --stat
git commit -m "feat(tutorial): el director v2 — guiones de pasos, ritmo de 20 s y watchdog de 3 min"
```

---

### Task 5: El núcleo en el director — sin "Saltar", con el cierre que espera 5 s

**Objetivo:** que el núcleo (`core.tap` → `core.hire` → `core.merge` → `core.finish`) sea un
guion más del director en vez del `@State` del overlay: se retoma solo en el primer paso no
cumplido, "Saltar" desaparece, el cierre es un paso de explicar con su candado de 5 s y su botón
"¡Vamos!", y al cerrarlo cae el cofre de bienvenida (una sola vez por save) y el permiso
provisional de E11.

**Files:**
- Create: `FisuEvolution/Game/Tutorial/TutorialCurriculum.swift` (`TutorialCurriculum.core`)
- Create: `FisuEvolution/UI/Tutorial/TutorialCard.swift` (la tarjeta y `TutorialConfirmButton`, mudadas de `TutorialOverlay`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialOverlay.swift` (lee `tutorialRun`; sin `@State step`, sin `@AppStorage`, sin "Saltar")
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift` (`beginTutorialPhase`, `finishTutorialCore()` — ex `tutorialPhaseFinished()`)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`debugResetSave`)
- Modify: `FisuEvolution/UI/Jobs/FisuJobsView.swift` (si llama a `tutorialPhaseFinished`; si no, sin cambios)
- Modify: los llamadores de `tutorialPhaseFinished()` (Step 0)
- Strings: `tutorial.skip` se va (`.quitar`); `tutorial.confirm` (nueva)
- Create: `FisuEvolutionTests/TutorialCoreTests.swift`
- Modify: `FisuEvolutionUITests/TutorialUITests.swift`

**Interfaces:**
- Consumes: T4 (`startTutorialRun`, `confirmTutorialStep`, `tutorialStepIsVisible`, `tutorialLockProgress`).
- Produces: `enum TutorialCurriculum { static let core: [TutorialStep] }`;
  `GameState.finishTutorialCore()`; `struct TutorialCard: View`
  (`step`, `index`, `total`, `unlocked`, `lockProgress: () -> Double`, `confirmKey`, `onConfirm`,
  `onEnd: (() -> Void)?`); `struct TutorialConfirmButton: View`; ids `tutorial.confirm` (valor
  `locked`/`unlocked`) y `tutorial.done` (el del cierre).

- [ ] **Step 0: Quién cierra la fase hoy**

Run: `grep -rn "tutorialPhaseFinished" --include='*.swift' FisuEvolution FisuEvolutionTests`
Expected: `TutorialOverlay` (dos), `+Celebrations` (la definición, con el
`requestProvisionalNotifications()` de E11 T6 adentro), `+Tutorial` (T4) y tests. Todos pasan a
`finishTutorialCore()`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/TutorialCoreTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El núcleo del tutorial en el director", .serialized)
@MainActor
struct TutorialCoreTests {
    private func makeGameState() async -> GameState {
        for key in TutorialFlags.milestoneKeys { UserDefaults.standard.set(false, forKey: key) }
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "core-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        return gameState
    }

    @Test("empieza en core.tap y avanza por acciones")
    func walksTheCore() async {
        let gameState = await makeGameState()
        gameState.beginTutorialPhase()
        #expect(gameState.tutorialRun?.script == .core)
        #expect(gameState.tutorialRun?.step?.id == "core.tap")
        gameState.debugGrantCoins()
        gameState.ftueTapped = true
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "core.hire")
    }

    @Test("retoma en el primer paso no cumplido (los milestones persisten)")
    func resumes() async {
        let gameState = await makeGameState()
        gameState.ftueTapped = true
        gameState.ftueSpawned = true
        gameState.beginTutorialPhase()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "core.merge")
    }

    @Test("el cierre espera 5 s, entrega el cofre una vez y termina la fase")
    func theFinishStep() async {
        let gameState = await makeGameState()
        gameState.ftueTapped = true
        gameState.ftueSpawned = true
        gameState.ftueMerged = true
        gameState.debugGrantCoins()
        gameState.beginTutorialPhase()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "core.finish")
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialPhaseActive, "con el candado puesto, «¡Vamos!» no hace nada")
        gameState.advanceTutorial(delta: 5)
        gameState.confirmTutorialStep()
        #expect(!gameState.tutorialPhaseActive)
        #expect(gameState.tutorialRun == nil)
        #expect(TutorialFlags.coreCompleted())
        #expect(gameState.player?.meta.welcomeChestGiven == true)
    }

    @Test("durante el núcleo no hay momento calmo: no nacen paquetes, colchones ni visitantes")
    func noCalmDuringTheCore() async {
        let gameState = await makeGameState()
        gameState.beginTutorialPhase()
        #expect(!gameState.isCalmMoment)
    }
}
```

`ftueTapped`/`ftueSpawned`/`ftueMerged` ya son internos (`GameState.swift:439-441`); si no lo
son, el test usa `debugMarkFTUE(tapped:spawned:merged:)` y se suma a `+Debug`.

En `TutorialUITests.swift`:
- `testSaltearCierraElTutorialYDevuelveLosControles` se **reemplaza** por
  `testNoHayBotonDeSaltear` (con `--uitest-reset`: `app.buttons["tutorial.skip"]` no existe y
  tocar el scrim no cambia `tutorial.step`).
- `testRecorreElTutorialEnteroHastaElFinal` lanza con `--uitest-tutorial-lock=0.3` y, en el
  cierre, espera `tutorial.confirm` con valor `unlocked` antes de tocar `tutorial.done`.
- los valores de `tutorial.step` pasan de `tap`/`hire`/`merge`/`finish` a
  `core.tap`/`core.hire`/`core.merge`/`core.finish`.

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/TutorialCoreTests`.
Expected: rojo (`tutorialRun` es `nil` con la fase puesta: el núcleo todavía vive en la vista).

- [ ] **Step 3: El guion del núcleo**

`FisuEvolution/Game/Tutorial/TutorialCurriculum.swift`:

```swift
import Foundation

/// El currículo del tutorial v2 (PLAN-v2 E9). El núcleo va acá; las lecciones, en su
/// `TutorialLesson.steps`; el Tour, en E9b.
enum TutorialCurriculum {
    /// Tocar → contratar → fusionar → cierre. Secuencial, con scrim, y el cierre entrega el
    /// cofre de bienvenida. Los textos son los del núcleo de la v1 (ya en el catálogo).
    static let core: [TutorialStep] = [
        .act("core.tap", .coreTappedAndAffordable, text: "tutorial.step.tap", on: .boardUnit,
             windows: [.coins], boardTarget: .anyUnit),
        .act("core.hire", .coreHired, text: "tutorial.step.hire", on: .hire, windows: [.coins]),
        .act("core.merge", .coreMerged, text: "tutorial.step.merge", on: .boardUnit, boardTarget: .mergePair),
        .explain("core.finish", text: "tutorial.step.finish", pose: "fisura_celebrate"),
    ]
}
```

- [ ] **Step 4: El director corre el núcleo (`+Celebrations`)**

```swift
    func beginTutorialPhase() {
        tutorialPhaseActive = true
        celebrations.restrict(to: [.boardCelebration])
        publishCelebration()
        startTutorialRun(.core, steps: TutorialCurriculum.core)
        refreshTutorial()
    }

    /// El cierre del núcleo (`core.finish`): se levanta la restricción, lo retenido desfila y
    /// cae el cofre de bienvenida (una vez por save: `welcomeChestGiven`). Lo llama sólo el
    /// director al confirmar el último paso del núcleo —nunca el repaso—.
    func finishTutorialCore() {
        guard tutorialPhaseActive else { return }
        tutorialPhaseActive = false
        TutorialFlags.setCoreCompleted(true)
        celebrations.restrict(to: nil)
        grantWelcomeChest()
        requestProvisionalNotifications()
        syncCelebrations()
    }
```

(`requestProvisionalNotifications()` es la línea que E11 T6 puso en `tutorialPhaseFinished`: se
muda con el cierre. Los comentarios largos de la función vieja sobre el cofre se conservan.)

En `+Tutorial.progressTutorialRun`, el núcleo avanza **en bucle** mientras el paso esté cumplido
(retomar a mitad de camino):

```swift
        if run.script == .core {
            while var current = tutorialRun, current.step?.signal != nil, current.isStepSatisfied(probe: probe) {
                current.advance(probe: probe)
                tutorialRun = current
                resetTutorialClock()
            }
            tutorialBoardTarget = tutorialRun?.step?.boardTarget
            return
        }
```

`tutorialBoardTarget` (lo lee `BoardScene` para el recorte) lo escribe ahora el director, no el
overlay. `debugResetSave`: después de `TutorialFlags.wipeGameFlags()`, `tutorialRun = nil` y
`beginTutorialPhase()` (como hoy).

- [ ] **Step 5: La tarjeta, mudada y con el candado**

`FisuEvolution/UI/Tutorial/TutorialCard.swift`: la `TutorialCard` de `TutorialOverlay.swift`
(`:414-548`) se muda **igual** (pergamino, retrato 96×112, dots), con estos cambios:
sin `skipButton` ni `onSkip`; el botón del pie es `TutorialConfirmButton` para todo paso de
explicar (no sólo el último); y un `onEnd` opcional que dibuja "Terminar repaso" (E9b T5).

```swift
/// "Entendido" (o "¡Vamos!" en el cierre): se llena durante el candado y recién ahí confirma.
/// Nunca se deshabilita: con el candado puesto, tiembla.
struct TutorialConfirmButton: View {
    let titleKey: LocalizedStringKey
    let identifier: String
    let unlocked: Bool
    let progress: () -> Double
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes = 0

    var body: some View {
        Button {
            if unlocked { action() } else { shakes += 1 }
        } label: {
            TimelineView(reduceMotion ? .periodic(from: .now, by: 0.5) : .animation) { _ in
                let fill = unlocked ? 1 : progress()
                Text(titleKey)
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color("PaletteGreen").opacity(0.45))
                                Capsule().fill(Color("PaletteGreen"))
                                    .frame(width: proxy.size.width * fill)
                            }
                        }
                    }
                    .overlay(Capsule().strokeBorder(Color("PaletteGreen").deepened(), lineWidth: 2))
            }
        }
        .buttonStyle(.plain)
        .keyframeAnimator(initialValue: 0.0, trigger: shakes) { content, x in
            content.offset(x: reduceMotion ? 0 : x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-8, duration: 0.06)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(-4, duration: 0.06)
                LinearKeyframe(0, duration: 0.06)
            }
        }
        .accessibilityIdentifier(identifier)
        .accessibilityValue(Text(verbatim: unlocked ? "unlocked" : "locked"))
    }
}
```

(`deepened()` es el de la casa, `GameArt`; si el botón del cierre usaba `ArtButton(art: "ui_btn_buy")`,
se puede conservar ese arte como fondo en lugar de las cápsulas: lo que importa es el relleno y
el temblor.) El cierre usa `titleKey: "tutorial.done"`, `identifier: "tutorial.done"`; los demás
pasos de explicar, `"tutorial.confirm"` / `"tutorial.confirm"`.

- [ ] **Step 6: El overlay lee la corrida**

`TutorialOverlay`:
- se borran `@AppStorage`, `@State step`, `Completion`, `Step`, `steps`, `progress`,
  `isSatisfied`, `advanceWhileSatisfied` y `finish` (todo eso es del director ahora);
- `body`: `if let run = gameState.tutorialRun, run.script == .core, gameState.tutorialStepIsVisible, let step = run.step { overlay(run, step) }`;
- `holeRect(for: step)` igual que hoy pero con `step.target`;
- `card`: `TutorialCard(step: step, index: run.index, total: run.steps.count, unlocked: run.unlocked, lockProgress: { gameState.tutorialLockProgress }, confirmKey: step.id == "core.finish" ? "tutorial.done" : "tutorial.confirm", onConfirm: gameState.confirmTutorialStep, onEnd: nil)`;
  la tarjeta muestra el botón sólo si `step.clockKind == .explain`;
- los marcadores: `tutorial.step` con `step.id`, `tutorial.spotlight` igual que hoy;
- se conservan el scrim con su `contentShape` (lo que impide saltear sin hacer), el anillo, la
  mano y los comentarios de las trampas de AX.

- [ ] **Step 7: Los textos**

`Tools/v2/claves-pendientes/e9a-t5.json`:

```json
{
  "tutorial.confirm": {"es": "Entendido", "en": "Got it"}
}
```

`Tools/v2/claves-pendientes/e9a-t5.quitar`: `tutorial.skip`. Aplicar con `Tools/v2/catalogo.py
aplicar …` y `Tools/v2/catalogo.py quitar tutorial.skip` si la ola le da el catálogo a esta
tarea; si no, los deja para el controlador.

- [ ] **Step 8: Verde, a mano y oráculo**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialCoreTests -only-testing:FisuEvolutionTests/TutorialDirectorTests -only-testing:FisuEvolutionTests/CelebrationWiringTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests`
→ PASS. UI: `-only-testing:FisuEvolutionUITests/TutorialUITests` → PASS. A mano, con
`--uitest-reset`: el núcleo entero; el cierre se llena en 5 s y tiembla si se toca antes; matar
la app en `core.merge` y volver retoma ahí; Reduce Motion prendido y apagado. Capturas al
reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 9: Commit**

```bash
git add FisuEvolution/Game/Tutorial/TutorialCurriculum.swift FisuEvolution/UI/Tutorial/TutorialCard.swift
git add FisuEvolution/UI/Tutorial/TutorialOverlay.swift FisuEvolution/Game/State/GameState+Celebrations.swift
git add FisuEvolution/Game/State/GameState+Tutorial.swift FisuEvolution/Game/State/GameState+Debug.swift
git add FisuEvolutionTests/TutorialCoreTests.swift FisuEvolutionUITests/TutorialUITests.swift
# + los llamadores de tutorialPhaseFinished del Step 0
# + el catálogo o Tools/v2/claves-pendientes/e9a-t5.{json,quitar}, según la ola
git diff --cached --stat
git commit -m "feat(tutorial): el núcleo en el director, sin Saltar y con el cierre que espera 5 s"
```

---

### Task 6: Las lecciones en el renderer único — no salteables, con scrim y "Entendido"

**Objetivo:** que las lecciones se dibujen con el mismo overlay que el núcleo (`TutorialTipView`
se borra), que ya no se puedan saltear (`.tutorialTip` sin timeout y con `isSkippable == false`:
el toque al tablero no las cierra) y que los pasos de explicar esperen sus 5 s. Una lección pone
scrim (más liviano que el del núcleo) con el recorte sobre lo que señala: sólo se puede hacer lo
que pide.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` (`.tutorialTip`: `timeout nil`, no salteable)
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift`
- Modify: `FisuEvolution/UI/Tutorial/TutorialOverlay.swift` (dibuja toda corrida de tablero)
- Delete: `FisuEvolution/UI/Tutorial/TutorialTipView.swift`
- Modify: `FisuEvolution/App/RootView.swift` 🔥 (`:241`, se va `TutorialTipView(anchors:)`)
- Modify: `FisuEvolution/Game/State/GameState+Tutorial.swift` (`dismissTutorialTip` se borra)
- Strings: `tutorial.tip.gotit` se va (`.quitar`)
- Modify: `FisuEvolutionTests/TutorialTipsTests.swift`, `FisuEvolutionTests/TutorialDirectorTests.swift`
- Create: `FisuEvolutionUITests/TutorialLockUITests.swift`
- Modify: `FisuEvolutionUITests/TutorialUITests.swift` (`testLaLeccionDeMejorasSenalaYSeCumpleAlAbrir`, `testLaLeccionDePintasNaceConLaPintaDelCofreDeBienvenida`)

**Interfaces:**
- Consumes: T4, T5 (`TutorialCard`, `TutorialConfirmButton`).
- Produces: `CelebrationKind.tutorialTip.timeout == nil`, `.isSkippable == false`; marcador
  `tutorial.tip` (valor = id de la lección) en el overlay único.

- [ ] **Step 0: Quién usa lo que se va**

Run: `grep -rn "TutorialTipView\|dismissTutorialTip\|tutorial.tip.dismiss\|tutorial.tip.gotit" --include='*.swift' FisuEvolution FisuEvolutionTests FisuEvolutionUITests`
Expected: `RootView`, `+Tutorial`, `TutorialTipView` y los UI tests de lecciones (de E9 y de
E4b/E5b/E7b-b si tocan "¡Dale!"). Los UI tests que tocaban `tutorial.tip.dismiss` pasan a
esperar `tutorial.confirm` `unlocked` (con `--uitest-tutorial-lock=0.3`) o a hacer la acción.

- [ ] **Step 1: Los tests, en rojo**

En `CelebrationQueueTests.swift`, el test de T1 pasa a:

```swift
    @Test("salteable es lo que se cierra solo, salvo las lecciones: no salteables ni con timeout")
    func lessonsAreNeitherSkippableNorTimed() {
        #expect(CelebrationKind.tutorialTip.timeout == nil)
        #expect(!CelebrationKind.tutorialTip.isSkippable)
        for kind in CelebrationKind.allCases where kind != .tutorialTip {
            #expect(kind.isSkippable == (kind.timeout != nil), "\(kind)")
        }
    }

    @Test("un toque no saltea una lección, por más que haya pasado el piso")
    func aTapDoesNotSkipALesson() {
        var queue = CelebrationQueue()
        queue.enqueue(.tutorialTip)
        _ = queue.tick(30)
        #expect(!queue.skip())
        #expect(queue.current == .tutorialTip)
    }
```

En `TutorialDirectorTests.swift`:

```swift
    @Test("el toque al tablero no saltea la lección")
    func theBoardTapDoesNotSkip() async {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        gameState.advanceCelebrations(delta: 5)
        #expect(!gameState.skipCurrentCelebration())
        #expect(gameState.showing == .tutorialTip)
        #expect(gameState.tutorialRun != nil)
    }
```

`FisuEvolutionUITests/TutorialLockUITests.swift` (el candado **real**, sin fixture):

```swift
import XCTest

/// El candado de 5 s de verdad (PLAN-v2 E9). El resto de las suites lo baja con
/// `--uitest-tutorial-lock=0.3`; ésta no.
final class TutorialLockUITests: XCTestCase {
    func testEntendidoEsperaCincoSegundosYTiembla() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-lesson=probe_explain"]
        app.launch()
        let confirm = app.buttons["tutorial.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertEqual(confirm.value as? String, "locked")
        confirm.tap()
        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertEqual(step.value as? String, "probe_explain.one", "con el candado puesto no avanza")
        let unlocked = NSPredicate(format: "value == 'unlocked'")
        expectation(for: unlocked, evaluatedWith: confirm)
        waitForExpectations(timeout: 8)
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tutorial.step"].waitForNonExistence(timeout: 5))
    }

    func testElToqueAlTableroNoCierraLaLeccion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-lesson=probe_explain"]
        app.launch()
        let tip = app.descendants(matching: .any)["tutorial.tip"]
        XCTAssertTrue(tip.waitForExistence(timeout: 10))
        for _ in 0..<5 { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap() }
        XCTAssertTrue(tip.exists, "tocar el tablero ya no saltea")
    }
}
```

`probe_explain` es una lección **sólo de DEBUG** para estos tests: en `+Tutorial`, bajo
`#if DEBUG`, `--uitest-lesson=probe_explain` arranca
`startTutorialRun(.lesson("probe_explain"), steps: [.explain("probe_explain.one", text: "tutorial.confirm")])`
en lugar de buscar el caso en `TutorialLesson`. (No se registra en el currículo ni en la
cobertura.)

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter CelebrationQueueTests` → rojo
(timeout 12, salteable). Receta R con `TutorialDirectorTests` → rojo (`theBoardTapDoesNotSkip`).

- [ ] **Step 3: La cola**

En `CelebrationQueue.swift`: `case .tutorialTip: nil` en `timeout` (con el comentario: "una
lección no se va sola: la cierra su último paso, o el watchdog de 3 min del tutorial (PLAN-v2
E9)") y `.tutorialTip` pasa al lado `false` de `isSkippable`.

- [ ] **Step 4: Un solo renderer**

`TutorialOverlay.body`:

```swift
    var body: some View {
        if let run = gameState.tutorialRun, gameState.tutorialStepIsVisible,
           let step = run.step, step.surface == .board {
            overlay(run, step)
        }
    }
```

y en `overlay(_:_:)`:
- el scrim: `Color.black.opacity(run.script == .core ? 0.68 : 0.55)`; en una **demostración**
  (`run.isDemo`) el scrim no deja pasar nada (`contentShape` sin agujero): sólo se mira;
- el marcador `tutorial.tip` (de fondo, 1×1, valor `run.lessonID ?? "tour"`/`"replay"`) se suma a
  los dos que ya hay, para los tests de E4b/E5b/E7b-b;
- la mano: `TutorialHandView(hand: step.hand, hole: hole, screen: proxy.size)` cuando T7 exista;
  hasta entonces, la `TutorialHand` de hoy para `.tap` y nada para el resto;
- la tarjeta: la `TutorialCard` de T5 para todo paso (los de acción sin botón; los de explicar
  con `tutorial.confirm`).

`RootView.swift:234-245` 🔥: el `ZStack` queda sólo con `TutorialOverlay(anchors: resolved)`.
Se borran `TutorialTipView.swift` (y `xcodegen generate`) y `dismissTutorialTip()`.

- [ ] **Step 5: Los textos**

`Tools/v2/claves-pendientes/e9a-t6.quitar`: `tutorial.tip.gotit`.

- [ ] **Step 6: Verde, a mano y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS. Receta R con
`TutorialDirectorTests`, `TutorialTipsTests`, `CelebrationWiringTests`, `PrizeAccessTests` →
PASS. UI: `TutorialUITests`, `TutorialLockUITests` y los de lecciones de otras épicas
(`grep -ln "tutorial.tip" FisuEvolutionUITests`) → PASS. A mano con `--uitest-skip-tutorial
--uitest-coins --uitest-lessons`: la lección de Mejoras con scrim y el recorte en la pestaña; tocar
el tablero no hace nada; abrir Mejoras la cumple. Capturas al reporte (SE y iPad 13").
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift
git add FisuEvolution/UI/Tutorial/TutorialOverlay.swift FisuEvolution/App/RootView.swift
git add FisuEvolution/Game/State/GameState+Tutorial.swift
git rm FisuEvolution/UI/Tutorial/TutorialTipView.swift
git add FisuEvolutionTests/TutorialTipsTests.swift FisuEvolutionTests/TutorialDirectorTests.swift
git add FisuEvolutionUITests/TutorialLockUITests.swift FisuEvolutionUITests/TutorialUITests.swift
# + los UI tests de otras épicas del Step 0, y el catálogo o e9a-t6.quitar
git diff --cached --stat
git commit -m "feat(tutorial): un solo renderer — las lecciones no se saltean y esperan su candado"
```

---

### Task 7: El coach adentro de las hojas, y las manos de mantener y deslizar

**Objetivo:** que un paso pueda vivir **adentro** de una página del menú o de la ficha (hoy una
hoja no le pasa el ancla a la pantalla que la presenta: las preferencias no cruzan la
presentación), y que la mano diga el gesto: tocar (`TapHereHand`), mantener (`HoldHand`) o
deslizar (`SwipeHand`). La banda de FisuJobs del núcleo (`TutorialJobsHint`) pasa a ser el coach.

**Files:**
- Create: `FisuEvolution/UI/Tutorial/TutorialHands.swift` (`TapHereHand` mudada de `TutorialOverlay.swift`, `HoldHand`, `SwipeHand`, `TutorialHandView`)
- Create: `FisuEvolution/UI/Tutorial/TutorialSheetCoach.swift`
- Modify: `FisuEvolution/UI/Tutorial/TutorialOverlay.swift` (usa `TutorialHandView`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` (`.pickerFace`, `.menuPager`)
- Modify: `FisuEvolution/UI/Menu/MenuPagerView.swift` (E3b T3: `MenuPage` monta el coach; los dots publican `.menuPager`)
- Modify: `FisuEvolution/UI/Popups/CharacterSheetView.swift` (monta el coach; avisa `characterSheetOpened`)
- Modify: `FisuEvolution/UI/HUD/QuickHirePicker.swift` (E3b T8: avisa `pickerOpened`; la cara fijada —o la primera— publica `.pickerFace`)
- Modify: `FisuEvolution/UI/Jobs/FisuJobsView.swift` (`TutorialJobsHint` se va: el paso `core.hire` gana un paso de hoja)
- Modify: `FisuEvolution/Game/Tutorial/TutorialCurriculum.swift` (`core.hire` en dos pasos)
- Create: `FisuEvolutionTests/TutorialSheetCoachTests.swift`
- Modify: `FisuEvolutionUITests/TutorialUITests.swift` (`tutorial.jobs.hint` → `tutorial.coach`)

**Interfaces:**
- Consumes: T4–T6; `MenuPage` y `MenuPagerContext` (E3b T3), `QuickHirePicker` (E3b T8).
- Produces: `struct TapHereHand`, `struct HoldHand`, `struct SwipeHand` (`direction`),
  `struct TutorialHandView` (`hand`, `hole`, `screen`); `extension View { func tutorialSheetCoach(_ surface: TutorialStep.Surface) -> some View }`;
  `TutorialTarget.pickerFace`, `.menuPager`; id del marcador del coach `tutorial.coach` (valor = id del paso).

- [ ] **Step 0: Los anfitriones**

Run: `grep -n "struct MenuPage\b\|struct MenuPage:" -r FisuEvolution/UI/Menu` ,
`grep -rn "struct QuickHirePicker" FisuEvolution` y `grep -n "TutorialJobsHint" FisuEvolution/UI/Jobs/FisuJobsView.swift`.
Expected: `MenuPage` (una por pestaña), el selector y la banda. Si `MenuPage` no existe con ese
nombre, el coach se monta en la vista que envuelve cada página del paginador.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/TutorialSheetCoachTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los pasos que viven adentro de una hoja", .serialized)
@MainActor
struct TutorialSheetCoachTests {
    private func makeGameState() async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "coach-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        return gameState
    }

    @Test("el paso de la hoja se ve sólo con esa página abierta")
    func visibleOnlyOnItsPage() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: [
            .act("probe.open", .screenOpened(.upgrades), text: "tutorial.confirm", on: .upgrades),
            .explain("probe.inside", text: "tutorial.confirm", surface: .page(.upgrades)),
        ])
        gameState.uiCoversBoard = true
        gameState.tutorialTipHandled(opening: .upgrades)
        #expect(gameState.tutorialRun?.step?.id == "probe.inside")
        #expect(gameState.tutorialStepIsVisible)
        gameState.menuPageChanged(to: .skins)
        #expect(!gameState.tutorialStepIsVisible, "deslizó a otra página")
    }

    @Test("cerrar la hoja vuelve al paso que la abre")
    func closingRewinds() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: [
            .act("probe.open", .screenOpened(.upgrades), text: "tutorial.confirm", on: .upgrades),
            .explain("probe.inside", text: "tutorial.confirm", surface: .page(.upgrades)),
        ])
        gameState.uiCoversBoard = true
        gameState.tutorialTipHandled(opening: .upgrades)
        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "probe.open")
    }

    @Test("el núcleo contrata adentro de FisuJobs con el coach")
    func coreHireHasASheetStep() {
        let ids = TutorialCurriculum.core.map(\.id)
        #expect(ids == ["core.tap", "core.hire", "core.hire.inside", "core.merge", "core.finish"])
        #expect(TutorialCurriculum.core[2].surface == .page(.jobs))
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialSheetCoachTests` → rojo
(`coreHireHasASheetStep`: el núcleo tiene cuatro pasos).

- [ ] **Step 3: Las manos**

`FisuEvolution/UI/Tutorial/TutorialHands.swift`: `TapHereHand` **se muda tal cual** de
`TutorialOverlay.swift:347-379` (con su docstring y sus dos reglas del latido). Y:

```swift
/// El dibujo de la manito, sin latido: lo comparten las tres manos.
private struct HandGlyph: View {
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: size, weight: .black))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
            .accessibilityHidden(true)
    }
}

/// "Mantené apretado": la mano baja, se queda mientras un anillo se completa, y suelta.
struct HoldHand: View {
    var size: CGFloat = 40
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            ZStack { Circle().strokeBorder(Color("PaletteYellow"), lineWidth: 3).frame(width: size * 1.4, height: size * 1.4); HandGlyph(size: size) }
                .allowsHitTesting(false)
        } else {
            HandGlyph(size: size)
                .keyframeAnimator(initialValue: HoldPose(), repeating: true) { content, pose in
                    content
                        .scaleEffect(pose.scale)
                        .background {
                            Circle()
                                .trim(from: 0, to: pose.ring)
                                .stroke(Color("PaletteYellow"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: size * 1.4, height: size * 1.4)
                        }
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(0.9, duration: 0.25)
                        LinearKeyframe(0.9, duration: 1.0)
                        SpringKeyframe(1.0, duration: 0.35)
                    }
                    KeyframeTrack(\.ring) {
                        LinearKeyframe(0, duration: 0.25)
                        LinearKeyframe(1, duration: 1.0)
                        LinearKeyframe(0, duration: 0.35)
                    }
                }
                .allowsHitTesting(false)
        }
    }

    private struct HoldPose {
        var scale: CGFloat = 1
        var ring: CGFloat = 0
    }
}

/// "Deslizá": la mano viaja en la dirección del gesto y vuelve a empezar.
struct SwipeHand: View {
    let direction: TutorialStep.SwipeDirection
    var size: CGFloat = 40
    var distance: CGFloat = 90
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            HStack(spacing: 6) {
                Image(systemName: arrow).font(.system(size: size * 0.6, weight: .black)).foregroundStyle(.white)
                HandGlyph(size: size)
            }
            .allowsHitTesting(false)
        } else {
            HandGlyph(size: size)
                .keyframeAnimator(initialValue: 0.0, repeating: true) { content, t in
                    content
                        .offset(x: vector.dx * distance * t, y: vector.dy * distance * t)
                        .opacity(t > 0.95 ? 0 : 1)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0, duration: 0.2)
                        CubicKeyframe(1, duration: 0.9)
                        LinearKeyframe(1, duration: 0.25)
                    }
                }
                .allowsHitTesting(false)
        }
    }

    private var vector: CGVector {
        switch direction {
        case .left: CGVector(dx: -1, dy: 0)
        case .right: CGVector(dx: 1, dy: 0)
        case .up: CGVector(dx: 0, dy: -1)
        case .down: CGVector(dx: 0, dy: 1)
        }
    }

    private var arrow: String {
        switch direction {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        }
    }
}

/// La mano del paso, acomodada al recorte (o al centro de la pantalla si no hay recorte: el
/// "deslizá el tablero" no señala un control).
struct TutorialHandView: View {
    let hand: TutorialStep.Hand
    let hole: CGRect
    let screen: CGSize
    private static let size: CGFloat = 46

    var body: some View {
        Group {
            switch hand {
            case .none: EmptyView()
            case .tap: TapHereHand(size: Self.size)
            case .hold: HoldHand(size: Self.size)
            case .swipe(let direction): SwipeHand(direction: direction, size: Self.size)
            }
        }
        .position(position)
    }

    private var position: CGPoint {
        guard SpotlightShape.isDrawable(hole) else { return CGPoint(x: screen.width / 2, y: screen.height * 0.55) }
        return CGPoint(
            x: min(max(hole.maxX - 6, Self.size), screen.width - Self.size / 2),
            y: min(max(hole.maxY - 2, Self.size), screen.height - Self.size)
        )
    }
}
```

La `TutorialHand` privada del overlay se borra: `TutorialOverlay` usa `TutorialHandView`.

- [ ] **Step 4: El coach**

`FisuEvolution/UI/Tutorial/TutorialSheetCoach.swift`:

```swift
import SwiftUI

/// El tutorial adentro de una hoja (PLAN-v2 E9). Una hoja es otra presentación: sus anclas no
/// llegan al overlay de la raíz, así que cada hoja monta el suyo. Sin scrim: la hoja sigue
/// siendo usable (si el jugador la cierra sin hacer el paso, el director vuelve al paso que la
/// abre).
private struct TutorialSheetCoach: ViewModifier {
    let surface: TutorialStep.Surface
    @Environment(GameState.self) private var gameState

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let run = gameState.tutorialRun, gameState.tutorialStepIsVisible,
                   let step = run.step, step.surface == surface {
                    let hole = step.target.flatMap { anchors[$0] }.map { proxy[$0].insetBy(dx: -8, dy: -8) } ?? .null
                    ZStack {
                        if SpotlightShape.isDrawable(hole) {
                            RoundedRectangle(cornerRadius: min(24, min(hole.width, hole.height) / 2), style: .continuous)
                                .strokeBorder(Color("PaletteYellow"), lineWidth: 3)
                                .shadow(color: Color("PaletteYellow").opacity(0.75), radius: 8)
                                .frame(width: hole.width, height: hole.height)
                                .position(x: hole.midX, y: hole.midY)
                                .allowsHitTesting(false)
                        }
                        TutorialHandView(hand: step.hand, hole: hole, screen: proxy.size)
                        VStack {
                            Spacer(minLength: 0)
                            TutorialCard(step: step, index: run.index, total: run.steps.count,
                                         unlocked: run.unlocked, lockProgress: { gameState.tutorialLockProgress },
                                         confirmKey: "tutorial.confirm", onConfirm: gameState.confirmTutorialStep,
                                         onEnd: nil, compact: true)
                                .frame(maxWidth: PlayColumn.tutorialCardMaxWidth)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 18)
                        }
                    }
                    .background(
                        Color.clear.frame(width: 1, height: 1)
                            .accessibilityElement()
                            .accessibilityIdentifier("tutorial.coach")
                            .accessibilityValue(Text(verbatim: step.id))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    )
                }
            }
        }
    }
}

extension View {
    func tutorialSheetCoach(_ surface: TutorialStep.Surface) -> some View {
        modifier(TutorialSheetCoach(surface: surface))
    }
}
```

`TutorialCard` gana `var compact = false` (retrato 54×66, sin dots: la versión de coach-mark,
como el `TipBalloon` que se borró en T6).

- [ ] **Step 5: Los anfitriones y las señales**

- `MenuPage` (E3b T3): `.tutorialSheetCoach(.page(screen))` sobre el contenido de la página; los
  dots del paginador (`PagerDots`) suman `.tutorialAnchor(.menuPager)`.
- `CharacterSheetView`: `.tutorialSheetCoach(.characterSheet)` y
  `.onAppear { gameState.tutorialSignal(.characterSheetOpened) }`.
- `QuickHirePicker` (E3b T8): `.onAppear { gameState.tutorialSignal(.pickerOpened) }`; la cara
  fijada (o, si no hay, la primera) suma `.tutorialAnchor(.pickerFace)`. El selector vive en la
  raíz (no es hoja): su ancla la ve el overlay de siempre.
- `TutorialAnchor.swift`: `case pickerFace` y `case menuPager`, con su comentario.
- `FisuJobsView`: se borran `TutorialJobsHint` y sus dos usos (`:65`, `:82`). El núcleo gana el
  paso de adentro:

```swift
        .act("core.hire", .screenOpened(.jobs), text: "tutorial.step.hire", on: .hire, windows: [.coins]),
        .act("core.hire.inside", .coreHired, text: "tutorial.jobs.hint", on: .jobsRecommended,
             surface: .page(.jobs)),
```

con `TutorialTarget.jobsRecommended` publicado por la fila recomendada de FisuJobs (la que hoy
lleva la `TapHereHand` durante la fase: se le cambia la mano por el ancla; la mano la pone el
coach). ⚠️ Retomar: si `ftue.spawned` ya es `true`, los dos pasos de contratar se cumplen en el
bucle del núcleo (`coreHired` es absoluta; `screenOpened` no: el bucle del núcleo trata un
paso cuyo **siguiente** ya está cumplido como cumplido — sumá esa regla a
`progressTutorialRun` para `.core` y un test en `TutorialCoreTests.resumes`).

- [ ] **Step 6: Verde, a mano y oráculo**

Run: Receta R con `TutorialSheetCoachTests`, `TutorialCoreTests`, `TutorialDirectorTests` →
PASS. UI: `TutorialUITests` (el paso de contratar ahora espera el marcador `tutorial.coach` =
`core.hire.inside` adentro de FisuJobs en vez de `tutorial.jobs.hint`) → PASS. A mano: el núcleo
en el SE y el iPad 13"; las tres manos con Reduce Motion prendido y apagado (una lección de
prueba con `--uitest-lesson=probe_hands`, `#if DEBUG`, que muestra un paso de cada mano).
Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/UI/Tutorial/TutorialHands.swift FisuEvolution/UI/Tutorial/TutorialSheetCoach.swift
git add FisuEvolution/UI/Tutorial/TutorialOverlay.swift FisuEvolution/UI/Tutorial/TutorialCard.swift
git add FisuEvolution/UI/Tutorial/TutorialAnchor.swift FisuEvolution/UI/Menu/MenuPagerView.swift
git add FisuEvolution/UI/Popups/CharacterSheetView.swift FisuEvolution/UI/HUD/QuickHirePicker.swift
git add FisuEvolution/UI/Jobs/FisuJobsView.swift FisuEvolution/Game/Tutorial/TutorialCurriculum.swift
git add FisuEvolution/Game/State/GameState+Tutorial.swift
git add FisuEvolutionTests/TutorialSheetCoachTests.swift FisuEvolutionTests/TutorialCoreTests.swift
git add FisuEvolutionUITests/TutorialUITests.swift
git diff --cached --stat
git commit -m "feat(tutorial): el coach adentro de las hojas y las manos de mantener y deslizar"
```

---

### Task 8: Las primeras veces que son interactivas — `TutorialInlineCard`

**Objetivo:** las primeras veces que llegan en un popup —el offline (el ×2 por video), la
carrera de la UBA y el primer visitante— se explican **adentro del popup**, con el mismo
candado de 5 s: una tarjeta sobre el contenido que, hasta "Entendido", no deja tocar lo de
abajo. Se muestra una sola vez por partida.

**Files:**
- Create: `FisuEvolution/UI/Tutorial/TutorialInlineCard.swift`
- Modify: `FisuEvolution/Game/State/GameState+Tutorial.swift` (`beginInlineLesson(_:)`, `endInlineLesson(_:)`)
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift` (`TutorialInlineLesson`)
- Modify: `FisuEvolution/UI/Popups/OfflineEarningsView.swift`
- Modify: `FisuEvolution/UI/Popups/CareerChoiceView.swift`
- Modify: el popup del visitante (E4b T3; Step 0)
- Strings: `Tools/v2/claves-pendientes/e9a-t8.json` (3 claves)
- Create: `FisuEvolutionTests/TutorialInlineTests.swift`

**Interfaces:**
- Consumes: T4 (`startTutorialRun`, `isInlineRun`, `finishTutorialRun`), T5 (`TutorialCard`).
- Produces: `enum TutorialInlineLesson: String, CaseIterable` (`offline`, `career`, `visitorPopup`)
  con `steps`; `GameState.beginInlineLesson(_:)`, `endInlineLesson(_:)`;
  `struct TutorialInlineCard: View` (`lesson`); id `tutorial.inline` (valor = id de la lección).

- [ ] **Step 0: Los popups**

Run: `grep -rn "struct OfflineEarningsView\|struct CareerChoiceView\|visitorPopup" --include='*.swift' FisuEvolution/UI FisuEvolution/App | head`
Expected: los tres anfitriones (el del visitante, con el nombre que le puso E4b T3). En
`OfflineEarningsView` puede estar la tarjeta del permiso de E11 T5: la de E9 va **arriba** del
contenido y la de E11 sigue donde está (son de momentos distintos: la de E9 es la primera vuelta
con popup; la de E11 se ofrece en una vuelta con popup y se arbitra sola con
`permissionCardDue`; si caen juntas, primero se confirma la de E9).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/TutorialInlineTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Las primeras veces en su popup", .serialized)
@MainActor
struct TutorialInlineTests {
    private func makeGameState() async -> GameState {
        for lesson in TutorialInlineLesson.allCases {
            UserDefaults.standard.removeObject(forKey: TutorialFlags.lessonKey(lesson.rawValue))
        }
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "inline-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        return gameState
    }

    @Test("la tarjeta del offline espera 5 s, no pasa por la cola y queda dada")
    func offlineCard() async {
        let gameState = await makeGameState()
        gameState.beginInlineLesson(.offline)
        #expect(gameState.tutorialRun?.lessonID == "offline")
        #expect(gameState.showing != .tutorialTip, "la aloja el popup: no toma un turno propio")
        #expect(gameState.tutorialStepIsVisible)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun != nil)
        gameState.advanceTutorial(delta: 5)
        gameState.confirmTutorialStep()
        #expect(gameState.tutorialRun == nil)
        #expect(TutorialFlags.isLessonDone("offline"))
        gameState.beginInlineLesson(.offline)
        #expect(gameState.tutorialRun == nil, "una sola vez")
    }

    @Test("cerrar el popup sin confirmar no la da por vista: vuelve la próxima vez")
    func closingWithoutConfirming() async {
        let gameState = await makeGameState()
        gameState.beginInlineLesson(.career)
        gameState.endInlineLesson(.career)
        #expect(gameState.tutorialRun == nil)
        #expect(!TutorialFlags.isLessonDone("career"))
    }

    @Test("no pisa una lección que ya corre")
    func doesNotOverride() async {
        let gameState = await makeGameState()
        gameState.startTutorialRun(.lesson("probe"), steps: [.explain("probe.one", text: "tutorial.confirm")])
        gameState.beginInlineLesson(.offline)
        #expect(gameState.tutorialRun?.lessonID == "probe")
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/TutorialInlineTests`.
Expected: no compila.

- [ ] **Step 3: Las lecciones y el director**

En `GameState+TutorialTips.swift`:

```swift
/// Las primeras veces que llegan en un popup (PLAN-v2 E9): las aloja la propia celebración.
enum TutorialInlineLesson: String, CaseIterable, Sendable {
    case offline
    case career
    case visitorPopup = "visitor_popup"

    var steps: [TutorialStep] {
        switch self {
        case .offline: [.explain("offline.inline", text: "tutorial.offline.inline", surface: .embedded)]
        case .career: [.explain("career.inline", text: "tutorial.career.inline", surface: .embedded)]
        case .visitorPopup: [.explain("visitor_popup.inline", text: "tutorial.visitor_popup.inline", surface: .embedded)]
        }
    }
}
```

En `+Tutorial`:

```swift
    func beginInlineLesson(_ lesson: TutorialInlineLesson) {
        guard tutorialRun == nil, !tutorialPhaseActive || lesson == .offline,
              !TutorialFlags.isLessonDone(lesson.rawValue) else { return }
        startTutorialRun(.lesson(lesson.rawValue), steps: lesson.steps)
    }

    /// El popup se cerró: si la tarjeta no se confirmó, no queda dada.
    func endInlineLesson(_ lesson: TutorialInlineLesson) {
        guard tutorialRun?.lessonID == lesson.rawValue else { return }
        tutorialRun = nil
    }
```

(⚠️ El offline nunca cae durante el núcleo en una partida nueva —no hay producción—, pero un
veterano a medio núcleo sí puede volver con offline: la condición lo deja pasar a propósito.)

- [ ] **Step 4: La tarjeta**

`FisuEvolution/UI/Tutorial/TutorialInlineCard.swift`:

```swift
import SwiftUI

/// La primera vez, adentro de su popup (PLAN-v2 E9): un velo sobre el contenido y la tarjeta
/// del tutorial con su candado. Hasta "Entendido", lo de abajo no se toca.
struct TutorialInlineCard: View {
    let lesson: TutorialInlineLesson
    @Environment(GameState.self) private var gameState

    var body: some View {
        if let run = gameState.tutorialRun, run.lessonID == lesson.rawValue, let step = run.step {
            ZStack {
                Color("PaletteInk").opacity(0.35)
                    .contentShape(Rectangle())
                    .onTapGesture {}
                    .accessibilityHidden(true)
                TutorialCard(step: step, index: run.index, total: run.steps.count, unlocked: run.unlocked,
                             lockProgress: { gameState.tutorialLockProgress }, confirmKey: "tutorial.confirm",
                             onConfirm: gameState.confirmTutorialStep, onEnd: nil, compact: true)
                    .padding(.horizontal, 12)
            }
            .background(
                Color.clear.frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("tutorial.inline")
                    .accessibilityValue(Text(verbatim: lesson.rawValue))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
            )
            .transition(.opacity)
        }
    }
}
```

En cada anfitrión, sobre su contenido principal:

```swift
            .overlay { TutorialInlineCard(lesson: .offline) }
            .onAppear { gameState.beginInlineLesson(.offline) }
            .onDisappear { gameState.endInlineLesson(.offline) }
```

(`.career` en `CareerChoiceView`; `.visitorPopup` en el popup del visitante.) ⚠️ El
`.onAppear` del popup corre mientras su celebración tiene el turno: `tutorialStepIsVisible`
devuelve `true` para una corrida embebida sin mirar `showing` (T4, `isInlineRun`).

- [ ] **Step 5: Los textos**

`Tools/v2/claves-pendientes/e9a-t8.json`:

```json
{
  "tutorial.offline.inline": {"es": "Mientras no estabas, tus empleados siguieron laburando. Si mirás un video, lo duplicás.", "en": "Your workers kept working while you were away. Watch a video to double it."},
  "tutorial.career.inline": {"es": "¡Se recibió! Elegí una carrera: cada una te da un premio distinto. Pensalo, no hay vuelta atrás en esta vida.", "en": "They graduated! Pick a career: each one gives a different reward. Think it over, there's no going back this life."},
  "tutorial.visitor_popup.inline": {"es": "Un visitante te propone un trato. Elegí una opción, o cerrá y dejalo esperando: se va solo.", "en": "A visitor offers you a deal. Pick an option, or close it and let them wait: they'll leave on their own."}
}
```

- [ ] **Step 6: Verde, a mano y oráculo**

Run: Receta R con `TutorialInlineTests`, `LocalizationCompletenessTests` → PASS. UI:
`-only-testing:FisuEvolutionUITests/OfflineEarningsUITests` (o la suite que use
`--uitest-offline`) → PASS (lanzan con `--uitest-reset`, que borra la lección: si un test toca el
×2 sin esperar, lanza también con `--uitest-tutorial-lock=0.3` y confirma `tutorial.confirm`
antes; listarlos en el reporte). A mano: `--uitest-offline`, `--uitest-career`,
`--uitest-visitor=<guion>`. Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/UI/Tutorial/TutorialInlineCard.swift FisuEvolution/Game/State/GameState+Tutorial.swift
git add FisuEvolution/Game/State/GameState+TutorialTips.swift FisuEvolution/UI/Popups/OfflineEarningsView.swift
git add FisuEvolution/UI/Popups/CareerChoiceView.swift FisuEvolutionTests/TutorialInlineTests.swift
# + el popup del visitante, los UI tests ajustados y el catálogo o e9a-t8.json
git diff --cached --stat
git commit -m "feat(tutorial): las primeras veces se explican en su popup, con el mismo candado"
```

---

### Task 9: La regla de cobertura — toda mecánica tiene su lección

**Objetivo:** el pedido explícito del dueño, como test: un registro de **mecánicas** del juego
(`TutorialMechanic`) donde cada una dice qué la enseña (un paso del núcleo, una lección, una
tarjeta de primera vez o una pantalla que se explica sola). El `switch` es exhaustivo: una
mecánica sin cobertura **no compila**. Las que todavía no tienen lección quedan en
`knownGaps`, que E9b vacía (y su cierre exige vacío). Más la lista de claves y anclas del
currículo (`TutorialCurriculumTests`).

**Files:**
- Modify: `FisuEvolution/Game/Tutorial/TutorialCurriculum.swift` (`TutorialMechanic`, `TutorialCoverage`)
- Create: `FisuEvolutionTests/TutorialCoverageTests.swift`, `FisuEvolutionTests/TutorialCurriculumTests.swift`

**Interfaces:**
- Consumes: `TutorialLesson`, `TutorialInlineLesson`, `TutorialCurriculum.core`,
  `NotificationPermissionCard.lessonID` (E11 T5), `GameContent.oroShop` (E6a T4).
- Produces: `enum TutorialMechanic: String, CaseIterable` con `var coverage: TutorialCoverage`;
  `enum TutorialCoverage { core(String), lesson(GameState.TutorialLesson), inline(TutorialInlineLesson), selfExplained(String) }`;
  `static let knownGaps: Set<TutorialMechanic>`; `static var allCurriculumSteps: [TutorialStep]`.

- [ ] **Step 0: Los nombres del contenido de E6a**

Run: `grep -rn "oroShop\b\|struct OroShopConfig\|var items" FisuEvolution/Managers/GameContentLoader.swift Packages/EconomyKit/Sources/EconomyKit | head`
Expected: cómo se llama la lista de ítems de `oro_shop.json` en `GameContent` (E6a T4).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/TutorialCoverageTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// "Toda mecánica del juego tiene su lección" (pedido del dueño, PLAN-v2 E9). El `switch` de
/// `TutorialMechanic.coverage` la hace cumplir al compilar; esto cuida que la cobertura exista
/// de verdad y que ninguna lección quede huérfana.
@Suite("Cobertura del tutorial")
@MainActor
struct TutorialCoverageTests {
    @Test("cada mecánica está cubierta por algo que existe")
    func everyMechanicIsCovered() {
        for mechanic in TutorialMechanic.allCases where !TutorialMechanic.knownGaps.contains(mechanic) {
            switch mechanic.coverage {
            case .core(let id):
                #expect(TutorialCurriculum.core.contains { $0.id == id }, "\(mechanic): \(id)")
            case .lesson(let lesson):
                #expect(!lesson.steps.isEmpty, "\(mechanic): \(lesson)")
            case .inline(let lesson):
                #expect(!lesson.steps.isEmpty, "\(mechanic): \(lesson)")
            case .selfExplained(let id):
                #expect(TutorialMechanic.selfExplaining.contains(id), "\(mechanic): \(id)")
            }
        }
    }

    @Test("ninguna lección queda fuera del registro")
    func noOrphanLessons() {
        let covered = Set(TutorialMechanic.allCases.compactMap { mechanic -> String? in
            switch mechanic.coverage {
            case .lesson(let lesson): lesson.rawValue
            case .inline(let lesson): lesson.rawValue
            default: nil
            }
        })
        for lesson in GameState.TutorialLesson.allCases {
            #expect(covered.contains(lesson.rawValue), "\(lesson) no enseña ninguna mecánica registrada")
        }
        for lesson in TutorialInlineLesson.allCases {
            #expect(covered.contains(lesson.rawValue), "\(lesson)")
        }
    }

    @Test("cada ítem de la tienda de ORO es una mecánica con lección")
    func everyShopItemIsTaught() throws {
        let content = try GameContentLoader.load(from: .main)
        #expect(!content.oroShop.items.isEmpty)
        if case .lesson(let lesson) = TutorialMechanic.oroShopShelf.coverage {
            #expect(!lesson.steps.isEmpty)
        } else if !TutorialMechanic.knownGaps.contains(.oroShopShelf) {
            Issue.record("la tienda de ORO necesita su lección")
        }
    }

    @Test("los huecos declarados sólo se achican (E9b los vacía; su cierre exige cero)")
    func gapsAreDeclared() {
        #expect(TutorialMechanic.knownGaps.count <= TutorialMechanic.knownGapsCeiling)
    }
}
```

`FisuEvolutionTests/TutorialCurriculumTests.swift`:

```swift
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El currículo: claves y anclas")
@MainActor
struct TutorialCurriculumTests {
    @Test("cada paso tiene su texto en es y en")
    func everyStepIsTranslated() throws {
        let catalog = try LocalizationCompletenessTests.catalog("Localizable")
        let problems = TutorialMechanic.allCurriculumSteps
            .flatMap { LocalizationCompletenessTests.problems(of: $0.textKey, in: catalog) }
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }

    @Test("cada ancla que el currículo señala la publica alguna vista")
    func everyTargetIsPublished() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FisuEvolution")
        let sources = try FileManager.default.subpathsOfDirectory(atPath: root.path())
            .filter { $0.hasSuffix(".swift") }
            .map { try String(contentsOf: root.appending(path: $0), encoding: .utf8) }
            .joined(separator: "\n")
        let notViews: Set<TutorialTarget> = [.boardUnit]
        let targets = Set(TutorialMechanic.allCurriculumSteps.compactMap(\.target)).subtracting(notViews)
        for target in targets {
            let literal = ".tutorialAnchor(.\(target.rawValue))"
            #expect(sources.contains(literal) || TutorialMechanic.dynamicAnchors.contains(target),
                    "nadie publica \(literal)")
        }
        for target in TutorialMechanic.dynamicAnchors {
            #expect(sources.contains(".\(target.rawValue)"), "\(target) se declara dinámica pero no aparece")
        }
    }

    @Test("los ids de los pasos no se repiten")
    func uniqueStepIDs() {
        let ids = TutorialMechanic.allCurriculumSteps.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialCoverageTests -only-testing:FisuEvolutionTests/TutorialCurriculumTests`.
Expected: no compila (`TutorialMechanic` no existe).

- [ ] **Step 3: El registro**

En `TutorialCurriculum.swift`:

```swift
/// Qué enseña una mecánica (PLAN-v2 E9, regla de cobertura).
enum TutorialCoverage: Equatable {
    case core(String)
    case lesson(GameState.TutorialLesson)
    case inline(TutorialInlineLesson)
    /// Una pantalla que se explica sola (la pausa publicitaria tiene su pantalla previa; el
    /// permiso de avisos, su tarjeta). Va con su id para que el registro los nombre.
    case selfExplained(String)
}

/// Todas las mecánicas del juego. **Cada épica que suma una, suma su caso acá**: el `switch` de
/// `coverage` no compila sin decir qué la enseña.
enum TutorialMechanic: String, CaseIterable {
    case tap, hire, merge, welcomeChest
    case quickHire, passiveIncome, characterMultipliers, orgChart, elevatorPanel, floorSwipe, floorFull
    case offlineDoubling, boosts, dailyGifts, skins, achievements, chests, prestigeAndOro, oroUpgrades
    case career, store, menuSwipe, characterSheet, newTabs, hirePriceStep, staffedFloors, prestigeGate
    case customsPackage, mattress, wheel, visitor, visitorPopup, eventChip, album, sideRail
    case mergeAll, share, oroShopShelf, pendingTriple, autoTap, luckOdds, offers
    case cosmetics, skinEffects, extraSlots, notificationsPermission, adBreak

    var coverage: TutorialCoverage {
        switch self {
        case .tap: .core("core.tap")
        case .hire: .core("core.hire")
        case .merge: .core("core.merge")
        case .welcomeChest: .core("core.finish")
        case .quickHire: .lesson(.quickHire)
        case .characterMultipliers: .lesson(.upgrades)
        case .elevatorPanel: .lesson(.elevator)
        case .skins: .lesson(.skins)
        case .achievements: .lesson(.achievements)
        case .oroUpgrades: .lesson(.oroUpgrades)
        case .dailyGifts: .lesson(.gifts)
        case .store: .lesson(.store)
        case .prestigeAndOro: .lesson(.prestige)
        case .share: .lesson(.share)
        case .visitor: .lesson(.visitor)
        case .eventChip: .lesson(.eventChip)
        case .album: .lesson(.album)
        case .customsPackage: .lesson(.packages)
        case .mattress: .lesson(.mattress)
        case .wheel: .lesson(.wheel)
        case .sideRail: .lesson(.sideRail)
        case .mergeAll: .lesson(.mergeAllVideo)
        case .offlineDoubling: .inline(.offline)
        case .career: .inline(.career)
        case .visitorPopup: .inline(.visitorPopup)
        case .notificationsPermission: .selfExplained(NotificationPermissionCard.lessonID)
        case .adBreak: .selfExplained("ad_break.intro")
        // Hasta E9b T1–T3: sin lección propia todavía (`knownGaps`). Apuntan a la lección más
        // cercana para que el `switch` compile; el test las saltea mientras sean hueco.
        case .passiveIncome, .orgChart, .floorSwipe, .floorFull, .boosts, .chests, .menuSwipe,
             .characterSheet, .newTabs, .hirePriceStep, .staffedFloors, .prestigeGate, .oroShopShelf,
             .pendingTriple, .autoTap, .luckOdds, .offers, .cosmetics, .skinEffects, .extraSlots:
            .lesson(.upgrades)
        }
    }

    /// Lo que E9b tiene que enseñar. Su cierre exige que esté vacío.
    static let knownGaps: Set<TutorialMechanic> = [
        .passiveIncome, .orgChart, .floorSwipe, .floorFull, .boosts, .chests, .menuSwipe,
        .characterSheet, .newTabs, .hirePriceStep, .staffedFloors, .prestigeGate, .oroShopShelf,
        .pendingTriple, .autoTap, .luckOdds, .offers, .cosmetics, .skinEffects, .extraSlots,
    ]
    /// El techo de hoy: un hueco nuevo sin lección pone el test en rojo.
    static let knownGapsCeiling = 20

    static let selfExplaining: Set<String> = [NotificationPermissionCard.lessonID, "ad_break.intro"]

    /// Anclas que se publican con una variable (`.tutorialAnchor(kind.tutorialTarget)`) y no
    /// con el literal: las de la columna de E7b-b.
    static let dynamicAnchors: Set<TutorialTarget> = [.sideRail, .sideWheel, .sideMattress, .sidePackages, .sideBoost]

    static var allCurriculumSteps: [TutorialStep] {
        TutorialCurriculum.core
            + GameState.TutorialLesson.allCases.flatMap(\.steps)
            + TutorialInlineLesson.allCases.flatMap(\.steps)
    }
}
```

⚠️ Si `"ad_break.intro"` no es el id que E7b-a T3 le dio a su pantalla previa, usá el que haya
(`grep -rn "RewardedInterstitialIntroView" FisuEvolution`) y anotalo.

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con `TutorialCoverageTests`, `TutorialCurriculumTests` → PASS. Si
`everyTargetIsPublished` falla por un ancla que una épica anterior declaró pero no montó, se
monta en esta tarea (una línea en la vista) y se anota. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/Tutorial/TutorialCurriculum.swift
git add FisuEvolutionTests/TutorialCoverageTests.swift FisuEvolutionTests/TutorialCurriculumTests.swift
git diff --cached --stat
git commit -m "test(tutorial): toda mecánica tiene su lección — el registro y sus huecos declarados"
```

---

### Task 10: Cierre de E9a (controlador)

1. `Tools/v2/oraculo.sh completo --limpio` y otra vez sin tocar nada → `VERDE` las dos.
2. A mano, en el simulador propio (SE y iPad 13", Reduce Motion prendido y apagado):
   instalación nueva → núcleo entero sin "Saltar", el coach adentro de FisuJobs, el cierre que se
   llena en 5 s y el cofre; una lección con scrim que no se cierra tocando el tablero; el offline
   con su tarjeta; un veterano simulado (`defaults write` de `fisuTutorialDone` + un save) que no
   repite el núcleo y queda con `tutorial.v2.tourPending`.
3. `Docs/SESION-<fecha>-v2-e9a.md`; las cuatro ediciones de `Docs/HANDOFF.md` (§4 la entrada;
   §5: el tutorial no se saltea, el candado vive en el tick, las banderas `tutorial.v2.*` y su
   división partida/dispositivo, un solo renderer, la cobertura como test; §7 las trampas; §9);
   la tabla de fixtures de HANDOFF §6 suma `--uitest-tutorial-lock`, `--uitest-lesson`; journal,
   `LOCK` y `handoffs/HANDOFF-<fecha>-v2-e9a.md`.

---

## Lo que E9a le deja a E9b y a otras épicas

- **E9b**: el director (`startTutorialRun`, `confirmTutorialStep`, `finishTutorialRun`), el
  modelo (`TutorialStep.explain/act`, señales y superficies), el coach (`tutorialSheetCoach`), las
  manos, `TutorialFlags` (`wipeGameFlags`, `tourPending`), el registro con sus 20 huecos y
  `TutorialRun.Script.tour/.replay` (el overlay ya los dibuja como demostración: scrim sin
  agujero, sin exigir acciones). El `TutorialCard.onEnd` existe para "Terminar repaso".
- **Toda épica futura**: una mecánica nueva = un caso en `TutorialMechanic` (no compila sin su
  cobertura) + una `TutorialLesson` con `steps`, `introducedIn`, su señal y su ancla. Una vista
  nueva que aloja un paso de hoja monta `.tutorialSheetCoach(…)`.
- **E2b**: nada que calibrar; el ritmo (20 s / 1 s) y el watchdog (180 s) son números del dueño.
- **E10**: las capturas usan `--uitest-skip-tutorial` (ahora escribe `tutorial.v2.*`); las notas a
  App Review no cambian.

## Para el dueño / dudas

Ninguna frena: la ejecución sigue con el default anotado.

1. **Las lecciones ahora bloquean el tablero** (scrim con el recorte). La v1 las había hecho
   livianas a propósito ("sin scrim, nunca congelan el juego", sesión 2026-08-21), pero el §2 de
   PLAN-v2 las hace no salteables: un cartel que no se puede cerrar y no bloquea dejaría la cola
   tomada (y los reveals esperando) mientras el jugador sigue tocando. **Default:** scrim más
   liviano que el del núcleo (0,55 vs 0,68) y una lección por vez con 20 s de aire.
2. **Adentro de una hoja el coach no pone scrim**: la hoja sigue usable; si el jugador la cierra
   sin hacer el paso, el director vuelve al paso que la abre. **Default:** así (un scrim en la
   hoja taparía su "X" y la dejaría sin salida si el paso no se puede hacer).
3. **Una lección ignorada ya no existe**: se cumple haciendo lo que pide o por el watchdog de
   3 min, que la da por vista (sin premio). **Default:** así; es la válvula aprobada.
4. **El candado de las tarjetas de primera vez tapa el popup** hasta "Entendido" (5 s). El
   permiso de avisos de E11 **no** lleva candado: es una pregunta con dos salidas, y bloquear el
   "Ahora no" se leería como presión. **Default:** así.
5. **`tutorialPhaseActive` no se renombra** aunque el núcleo ya no sea "la fase": la leen cinco
   épicas. El cierre sí se renombra (`finishTutorialCore`), como pidió E11.
6. **El veterano a medio núcleo** (save de la v1 sin haber terminado la fase) sigue el núcleo y
   no recibe el Tour: va a ver cada lección nueva en su primera vez. **Default:** así.
7. **El paquete no tiene tarjeta de primera vez**: PLAN-v2 lo lista entre las "primeras veces
   interactivas", pero su apertura es un turno del tablero (E5b duda 2), no un popup; su lección
   (`.packages`, E5b T5) ya señala el chip en el tablero. **Default:** así.
