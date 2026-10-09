# E13b — El ascensor (botonera colgante y viaje en cabina) y la barra de cinco · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que lo primero que ve el dueño al abrir el juego sea la referencia
`Docs/superpowers/specs/referencias/2026-10-08-ascensor-y-barra.png`: el ícono del ascensor del
HUD que, **mantenido apretado**, despliega colgada de un resorte una placa de acero de **una
columna** con un botón redondo por piso abierto (sin nombres, sin oscurecer nada); el display LED
que **sale** del tablero; un **viaje en cabina** (puertas que cierran, los fondos de los pisos que
pasan por la ventana, "ding", puertas que abren) al elegir piso en la placa o en el mapa, **nunca al
scrollear**; y la barra de abajo con **cinco** pestañas simétricas (2 + 1 + 2), íconos más grandes y
sin rótulos, con la Tienda afuera (queda en el "+" de la moneda). PLAN-v2 E13, ítems 13 y 14.

**Architecture:** todo es app, nada baja a EconomyKit. El viaje lo maneja un director chico y
testeable (`ElevatorRide`, `@Observable`) que vive **fuera de los archivos calientes**: lo crea
`FisuEvolutionApp` y lo monta como `overlay` encima de `RootView`, así la cabina tapa HUD, barra y
tutorial sin tocar `RootView.swift` ni `GameState.swift`. La cabina es un clip HEVC con alfa
(el hueco de las puertas keyeado): **detrás del hueco se ve el juego de verdad** (la escena en el
piso de salida mientras cierran, la del destino cuando abren: la cámara ya llegó), y durante el
viaje una tira de fondos de piso pasa detrás de las ventanas. Si el clip no está, la misma vista
cae a los cuadros fijos keyeados y, si tampoco están, a una cabina vectorial: **ninguna tarea de
código espera al video**. La placa colgante se dibuja en la misma capa del director (anclada al
frame global del ícono del HUD), así queda por encima de todo y "tocar afuera" la recoge sin
importar qué hay debajo.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
AVFoundation (el `ChestCinematicPlayer` de los cofres, reusado) · XCUITest · XcodeGen (el
`.xcodeproj` no se versiona) · Python 3 (`Tools/asset-pipeline/scripts/video_assets.py`,
`Tools/audio-synth/generate_audio.py`, `Tools/v2/catalogo.py`) · ffmpeg con `hevc_videotoolbox`.

**Fuente:** `Docs/PLAN-v2.md` "E13 — Ajustes del feedback de la v1", ítems 13 y 14 (decisiones
del dueño **cerradas**: no se re-litigan) y la referencia visual, que **manda**; `tasks.md` §3
(calientes y tibios), §5 E3a/E3b/E9/E13; el código en `8eec356`. Este plan **reemplaza** E3a T8
(la botonera con display LED y persiana de dos columnas) y la barra de seis de E3a T7/T9. Lo que
la spec deja abierto o el código contradice está en "Para el dueño / dudas", con un default que
no frena.

**Rama de la épica:** `v2/e13-feedback` (la de E13), desde `version-2`. Cada tarea sale de su punta
en un worktree propio (manual, en `.claude/worktrees.nosync/v2i-e13b-tN`, mientras
`.claude/worktrees` sea un symlink: `tasks.md` §4.2) y el controlador integra de a una. Los IDs
de `tasks.md` son `E13b-T1` … `E13b-T11` (no chocan con `E13-T1…T14`).

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning rompe
  el build. Nada de `Timer` para lógica de juego (regla 2 del HANDOFF): los tiempos del viaje van
  con `Task.sleep` inyectable y la vista los dibuja con `TimelineView`.
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate`** al agregar o borrar un
  archivo Swift, un recurso (`.mov`, `.png`, `.caf`) o un test, en el mismo paso en que se crea.
  Carpeta nueva: `FisuEvolution/UI/Elevator/` (la toma XcodeGen sola: `sources: - path:
  FisuEvolution`).
- **Strings nuevos, es + en, por `Tools/v2/catalogo.py`** (formato canónico, trampa 29). Cada
  tarea escribe sus claves en `Tools/v2/claves-pendientes/e13b-tN.json` y las que **se borran** en
  `Tools/v2/claves-pendientes/e13b-tN.quitar` (una por línea). **Ninguna tarea de E13b es dueña
  del catálogo**: aplica en su worktree para correr sus tests (`catalogo.py quitar $(cat …quitar)`
  si `quitar` ya existe —lo suma E13 T6—, y `catalogo.py aplicar …json`), **commitea sólo los dos
  archivos de `claves-pendientes/`** y descarta el catálogo
  (`git checkout -- FisuEvolution/Resources/Localizable.xcstrings`). Cambiar el texto de una clave
  es `quitar` + `aplicar` de la misma clave. Si `quitar` todavía no existe, el `.quitar` espera en
  `claves-pendientes/` y el controlador lo aplica cuando llegue (una clave huérfana no rompe
  `LocalizationCompletenessTests`, que mira las claves del código).
- **Los números de un texto salen del dato** (`%@` + `String(x)`, trampa 5: un `Int` interpolado
  deja la clave cruda).
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos** (trampa
  9a-bis). La placa es un contenedor: su id (`hud.elevator.keypad`) va en un **marcador** pelado
  de fondo (`Color.clear.accessibilityElement()`, como `board.floor`), no en la placa. Los UI tests
  asertan por id, nunca por texto en castellano (trampa 6: el runner corre en inglés).
- **Materiales v3 y FisuJobs como referencia visual**: metal con remaches para la maquinaria
  (`MetalPlate`, `MetalTone`, `PanelScrew` de `PanelFrames.swift`), crema y ink de la paleta
  (`PaletteCream`, `PaletteInk`, `PaletteYellow`), `Tokens` para espacios. Todo glifo nuevo pasa por
  `GameIcon(artKey:) { vectorial }`, así el arte del atlas entra después sin tocar código.
- **Mantener apretado un `Button`**: al soltar, el botón **también dispara** (spike S3 de E3b T1).
  Se usa la bandera `longPressFired` de `QuickHireButton` (mismo patrón, mismo
  `QuickHireButton.longPressDuration` = 0,45 s).
- **El HEVC con alfa se decodifica por software en el simulador**: el arranque en frío congela el
  primer cuadro ~130 ms. `ChestCinematicPlayer` ya trae el calentado (reproducir mudo y volver a
  cero) y **nunca** se calienta en sincrónico en el main (trampa del commit `97cb618`). La cabina
  calienta sus dos clips **al desplegar la placa o al abrir el mapa**, no al elegir el piso.
- **Bajo `--uitest*` el viaje dura 0 s** (salta y listo) salvo que el test pase
  `--uitest-elevator-ride`. Lo decide `ElevatorRide.isInstantForUITests` (T1), sin tocar
  `+Debug`.
- **Reduce Motion**: placa, puertas y fondos en fundido; sin vibración, sin tira que pasa, sin
  rebote del resorte.
- Código nuevo limpio y con pocos comentarios (regla del dueño); **el comentario que miente se
  corrige** en el commit que lo vuelve mentira ("las seis pantallas", "la tienda sobrevive porque",
  "la botonera colgando", "el display reserva su alto").
- **Commits en español, estilo de la casa** (`feat(ascensor): …`, `feat(barra): …`,
  `feat(audio): …`, `feat(video): …`, `test(ascensor): …`), **SIN `Co-Authored-By`**. Staging
  selectivo por archivo y `git diff --cached --stat` antes de cada commit.
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración, ledger,
  journal y `tasks.md`. Ningún subagente toca `Docs/`, `handoffs/`, el journal, `tasks.md` ni
  `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

```bash
Tools/v2/oraculo.sh tarea <Clases de FisuEvolutionTests>   # EconomyKit entero + build + esas clases
```

- `tarea` corre EconomyKit entero y sólo las clases de `FisuEvolutionTests` que se le pasan. El
  `rapido` lo corre el controlador una vez por ola; el `completo` (UI en la matriz), al cerrar.
- Los **UI tests** que una tarea agrega o toca se corren aislados con la **receta R** de
  `Docs/superpowers/plans/2026-10-07-v2-e4a-visitantes-eventos.md` ("Receta R"), con
  `-only-testing:FisuEvolutionUITests/<Clase>` (o `/<Clase>/<test>`), simulador propio por UDID
  que se apaga y borra. Las tareas de layout corren la receta R **también en un iPhone SE (3ª
  generación)** y en un **iPad (A16)** con el mismo UDID propio.
- Las tareas de Python corren su suite con el venv del pipeline:
  `cd Tools/asset-pipeline && .venv/bin/python -m unittest tests.test_video_assets -v` (si el venv
  no está en el worktree, el del checkout principal: `…/FisuEvolution/Tools/asset-pipeline/.venv`).
  **No cuentan como "compilando"** para el tope de 3.
- ⚠️ "0 tests" con éxito no prueba nada: la salida tiene que nombrar las clases. Ante un rojo en
  masa, `uptime` y `ps aux | grep '[x]codebuild'` antes de culpar al código.
- `pacing-sim`: ninguna tarea lo mueve (cero economía).

## Las referencias de PLAN-v2 E13 (13 y 14), verificadas contra el árbol (`8eec356`)

| Lo que cita el plan | Dónde está hoy | Qué significa para E13b |
|---|---|---|
| la botonera de E3a T8 (display LED + persiana) | `UI/HUD/ElevatorPanel.swift` (218 líneas): `ElevatorPanelModel` (todos los pisos, `isStaffed`, `glow`), display `hud.elevator.display`, persiana en `Grid` de 2 columnas, botones de 30 pt `hud.elevator.floor.<id>`, se recoge a los 2 s | **se borra entero** (T8); la placa nueva es `UI/Elevator/ElevatorKeypad.swift` (T2). `ElevatorPanelModelTests` se borra; `ElevatorPanelUITests` se reescribe |
| dónde cuelga hoy | `HUDView.body`: `prestigeIndicator` con `minHeight: ElevatorPanel.displayHeight` y `.overlay(alignment: .topTrailing) { ElevatorPanel() }` (`HUDView.swift:60-70`) | T8 saca el overlay y la reserva de alto; la placa se dibuja en la capa del director |
| el ícono del ascensor `hud.map` | `HUDView.elevatorButton` (`:253-272`): `IconButton(artKey: "ui_elevator", size: 61, glyphAspect: 0.86)`, abre `FloorMapView` con `fisuSheet`, ancla `.map` | se conserva el toque corto; T8 le suma el mantener apretado, la acción de AX y el frame global |
| `IconButton` | `GameArtComponents.swift:922-985`: un `Button` sin gesto largo | el gesto va **afuera**, con `.simultaneousGesture` desde `HUDView` (no se toca `IconButton`) |
| "el vuelo de siempre" | `GameState.jumpToFloor(ordinal:)` → `setVisibleFloor` (`GameState+Tower.swift:85-147`); `BoardScene.moveCameraIfNeeded`: salto de 0,35 s a un piso, vuelo de `flightDuration` (0,6–0,9 s) a más | el director llama `jumpToFloor` **al empezar el tramo de viaje**; el viaje dura **≥ el vuelo** (lo pinea T1 contra `BoardScene.flightDuration`), así al abrir la cámara ya llegó |
| scrollear entre pisos | `GameState.moveVisibleFloor(by:)` (gesto de la escena) | **no se toca**: nunca dispara un viaje |
| el mapa | `FloorMapView.floorButton` (`:171-195`): `jumpToFloor` + `dismiss()`, ids `map.floor.<id>` | T6: pide el viaje al director y cierra; el viaje arranca en el `onDisappear` del mapa |
| `cameraFloor` | `GameState.cameraFloor` publicado por la escena | la placa no lo usa (la luz es del piso actual, fija): queda para E9 y quien lo lea |
| los fondos de piso | `FloorMapEntry.backgroundKey` → `content.manifest.backgrounds[key]` → `UIImage(named:)`; `FloorMapView` ya los achica con `preparingThumbnail` (`FloorThumbnail`, privado) | T5 hace su propio caché async (`byPreparingThumbnail`) al tamaño de la pantalla, sólo de los pisos del viaje |
| el pipeline de video | `video_assets.py cinematica <id>`: ids fijos `reencarnacion/arresto/dios`, 720×1280, mide el verde **en las 4 esquinas** y se niega si no son verde liso, HEVC-alfa premultiplicado, registra en `Resources/Data/loops_manifest.json` (`cinematics`, hoy vacío) | **en los clips del ascensor las esquinas son la cabina**: T4 suma la pieza `ascensor` (mide el verde en el hueco y en las ventanas, recorta y acelera) |
| los clips | `~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2/video/ascensor/`: `puertas_cierran.mp4` / `puertas_abren.mp4` (1080×1912, 24 fps, 73 cuadros, **sin audio**), `cabina_cerrada.png` / `cabina_abierta.png` (1520×2688) | medido: el movimiento de puertas ocupa los cuadros ~8–59 (cierran) y ~11–72 (abren), ≈ 2,1–2,5 s; el verde del hueco ≈ `#04F523` y el de las ventanas ≈ `#03FA0E` (dos verdes, 21 de diferencia en B) |
| el reproductor de clips con alfa | `UI/Popups/ChestCinematicPlayer.swift`: `ChestCinematicPlayer(url:)` (calentado, `play(rate:volume:)`, `awaitEnd(timeout:)`, `actionAtItemEnd = .pause`) + `ChestCinematicView` (`AVPlayerLayer`) | se **reusa tal cual** (sin renombrar: tocaría `ChestOpeningView`, duda 9) |
| los sonidos `sfx_elevator_*` | `AudioManager.SFX` tiene `elevatorDing`; los `.caf` los sintetiza `Tools/audio-synth/generate_audio.py` (dict `SFX`, `sfx_elevator_ding` en `:515`); `play` sin `stop` | T3: resorte, clic, puertas, motor (con el roce de cables) y `stop(_:)` |
| la barra de seis | `GameScreen.barOrder` (`GameArtComponents.swift:1040`) `[.upgrades, .skins, .jobs, .gifts, .store, .menu]`; `GameTabBar` (platos 44/64, íconos 38/56, rótulo de 10 pt, `panelHeight` 64, `barHeight` 84); `BottomMenuBar` (íconos espejados 38/56, `.tutorialAnchor(.store)` en el ícono de la tienda) | T9 saca la Tienda del orden; T10 rehace la geometría **conservando** `panelHeight` 64 y `barHeight` 84 (los leen `BoardScene.bottomInset`, los toasts y `AscentRenderingUITests`) |
| la barra progresiva | `tabs.json` (la tienda con `secondSession`), `TabsConfig.validate` exige las **seis** pantallas, `refreshUnlockedTabs` usa `Set(GameScreen.allCases)` con la barra apagada | T9: `tabs.json` y `validate` pasan a las cinco de `barOrder`; la tienda deja de ser una pestaña |
| el "+" de la moneda | `HUDView.coinsPlusButton` `hud.coins.plus` → `onStoreTap` → `RootView.open(.store)` (que ya llama `tutorialTipHandled(opening:)`) | ya abre la tienda: T9 sólo le mueve el ancla `.store` y le cambia el rótulo a "Tienda" |
| el paginador del menú (E3b T3) | `MenuPagerView(pages:)` + `MenuPage` (tiene `.store`); **no está montado** (E3b T4 ⛔) | si las páginas salen de `unlockedTabsInBarOrder`, quedan cinco solas: carry a E3b T4 |
| los UI tests que tocan la tienda por la barra | `BottomMenuUITests.destinations` (`hud.store`, `:31`) y `testContratarVaAlCentroYEsElMasGrande` (`:93`); `StoreUITests.openStore` (`:24`); `ProgressiveTabsUITests` (`:18`, lista de ocultas) | T9 los pasa por `hud.coins.plus` |
| los UI tests que tocan el ascensor | `ElevatorPanelUITests` (display, persiana, se recoge); `FloorMapUITests`, `AscentRenderingUITests:345`, `HUDRedesignUITests:139`, `CareerChoiceUITests:62` (sólo `hud.map` y `map.floor.*`) | T8 reescribe el primero; los otros siguen verdes porque bajo `--uitest*` el viaje es instantáneo (T6 lo verifica) |
| la lección del ascensor | `TutorialLesson.elevator` (`GameState+TutorialTips.swift`): `unlockedFloorsCount >= 2`, ancla `.map`, "Tocá el ascensor…" | sigue (el toque corto abre el mapa); T7 suma `.elevatorKeypad` al piso 3 |
| `TutorialCoverageTests` (E9) | **no existe** (lo crea E9a T9) | carry a E9a T9 / E9b T1 |
| los pisos | 10 (`economy.json`: `alley` … `god_realm`) | el tope de 10 botones es la torre entera |
| `--uitest-unlock-tower` | `debugUnlockFloors(throughTier: 5)` → callejón y urbano | la placa del UI test tiene **2** botones |

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `FisuEvolution/UI/Elevator/ElevatorRide.swift` (nuevo) | `ElevatorRidePlan` (tiempos puros, ≤ 3 s), `ElevatorRide` (director `@Observable`: placa abierta, fases, saltear, pedido del mapa, `Cue`, `Hooks`) | 1 |
| `FisuEvolution/UI/Elevator/ElevatorKeypad.swift` (nuevo) | `ElevatorKeypadModel`, `ElevatorKeypadLayout`, `ElevatorLED`, `ElevatorKeypad` (la placa con su resorte), `SpringCoil` | 2 |
| `FisuEvolution/Audio/AudioManager.swift` (tibio) | cuatro `SFX` nuevos y `stop(_:)` | 3 |
| `Tools/audio-synth/generate_audio.py`, `FisuEvolution/Resources/Audio/sfx_elevator_{spring,click,doors,motor}.caf` | los cuatro sonidos sintetizados | 3 |
| `Tools/asset-pipeline/scripts/video_assets.py`, `Tools/asset-pipeline/tests/test_video_assets.py` | la pieza `ascensor`: key medido en el hueco, recorte, retime, cuadros fijos | 4 |
| `FisuEvolution/Resources/Cinematics/cine_ascensor_{cierra,abre}.mov`, `cine_ascensor_{cerrada,abierta}.png`, `FisuEvolution/Resources/Data/loops_manifest.json` | los clips y los cuadros procesados | 4 |
| `FisuEvolution/UI/Elevator/ElevatorCabin.swift` (nuevo) | `ElevatorCabinArt` (video → cuadros → vectorial), `CabinFrame` (dónde va la cabina en la pantalla), `VectorCabin` | 5 |
| `FisuEvolution/UI/Elevator/ElevatorRideView.swift` (nuevo) | la vista del viaje: la tira de fondos, la cabina por fase, el indicador LED, la vibración, `elevator.ride.skip`; `FloorBackdrops` (caché async) | 5 |
| `FisuEvolution/UI/Elevator/ElevatorRideOverlay.swift` (nuevo) | la capa de arriba: el viaje (T6) y la placa colgante con su "tocar afuera" (T8); `AudioManager.play(_ cue:)` | 6, 8 |
| `FisuEvolution/App/FisuEvolutionApp.swift` (tibio) | crea el director, lo inyecta y monta el overlay encima de `RootView` | 6 |
| `FisuEvolution/UI/Popups/FloorMapView.swift` (tibio: E13 T8) | elegir un piso pide el viaje | 6 |
| `FisuEvolution/Game/State/GameState+TutorialTips.swift` (tibio) | `TutorialLesson.elevatorKeypad`, `elevatorKeypadOpened()` | 7 |
| `FisuEvolution/UI/HUD/HUDView.swift` (🔥 de la épica) | el ancla `.store` en el "+" (T9); el mantener apretado del ascensor, su frame y la salida de la botonera vieja (T8) | 9, 8 |
| `FisuEvolution/UI/HUD/ElevatorPanel.swift`, `FisuEvolutionTests/ElevatorPanelModelTests.swift` | **se borran** | 8 |
| `FisuEvolution/UI/Art/GameArtComponents.swift` (tibio) | `GameScreen.barOrder` sin la tienda (T9); `GameTabBar`/`GameTabButton`: sin rótulo, platos 52/72, 2 + 1 + 2 empacadas al centro (T10) | 9, 10 |
| `FisuEvolution/UI/HUD/BottomMenuBar.swift` | sin el ancla `.store` (T9); íconos 46/64 (T10) | 9, 10 |
| `FisuEvolution/Managers/TabUnlocks.swift`, `FisuEvolution/Resources/Config/tabs.json`, `FisuEvolution/Game/State/GameState+Tabs.swift` | las cinco pestañas de la barra | 9 |
| tests unit | `ElevatorRideTests`, `ElevatorKeypadModelTests`, `ElevatorCabinTests` (nuevos); `AudioManagerTests`, `TutorialTipsTests`, `GameArtComponentsTests`, `TabUnlockRulesTests`, `TabUnlockWiringTests`, `MenuSessionTests` | 1–10 |
| tests UI | `ElevatorRideUITests` (nuevo), `ElevatorPanelUITests` (reescrito), `FloorMapUITests`, `BottomMenuUITests`, `StoreUITests`, `ProgressiveTabsUITests`, `HUDRedesignUITests` | 6, 8, 9, 10 |

## Orden, olas y paralelismo

**Archivos calientes.** E13b **no toca** `RootView.swift`, `GameState.swift`, `BoardScene.swift`,
`ContentSystems.swift`, `+Bonus`, `PlayerState.swift`, `TowerActions.swift`, `SettingsView.swift` ni
`project.yml` (el viaje vive en `FisuEvolutionApp` a propósito: la fila `P-E13b` de `tasks.md`
daba por hecho `RootView`, y se evitó). Dentro de la épica, **`HUDView.swift` tiene un dueño a la
vez**: T9 (una línea, el ancla del "+") y T8 (el ascensor), en ese orden de integración. El
catálogo va siempre por snapshot.

| T | Qué | Archivos (🔥 / tibios) | Depende de | Revisión · modelo |
|---|---|---|---|---|
| 1 | el director del viaje y sus tiempos | nuevos (`ElevatorRide.swift`, `ElevatorRideTests`) | — | sonnet · sonnet |
| 2 | la placa colgante (modelo, medidas y vista, sin cablear) | nuevos (`ElevatorKeypad.swift`, `ElevatorKeypadModelTests`); catálogo (snapshot) | — | sonnet · sonnet |
| 3 | los sonidos del ascensor | `AudioManager` (tibio), `generate_audio.py`, 4 `.caf`, `AudioManagerTests` | — | ninguna · sonnet |
| 4 | los clips y los cuadros de la cabina | `video_assets.py`, `test_video_assets.py`, `Resources/Cinematics/`, `loops_manifest.json` | — (Python; no compila) | sonnet · sonnet |
| 5 | la cabina y la vista del viaje | nuevos (`ElevatorCabin.swift`, `ElevatorRideView.swift`, `ElevatorCabinTests`); catálogo (snapshot) | T1 | **opus** (AVFoundation, memoria de los fondos) · sonnet |
| 6 | el viaje montado, desde el mapa | `FisuEvolutionApp` (tibio), `FloorMapView` (tibio), nuevo `ElevatorRideOverlay.swift`, nuevo `ElevatorRideUITests` | T1, T3, T5 | **opus** (capa por encima de todo, AX, toques) · sonnet |
| 7 | la lección "Mantené apretado el ascensor" | `+TutorialTips` (tibio), `TutorialTipsTests`; catálogo (snapshot) | — | ninguna · sonnet |
| 8 | el ícono que se mantiene apretado y la placa en pantalla | 🔥 `HUDView`; `ElevatorRideOverlay`; borra `ElevatorPanel.swift` y `ElevatorPanelModelTests`; reescribe `ElevatorPanelUITests`; catálogo (snapshot) | T2, T6, T7; T9 integrada | **opus** (gesto vs botón, SE, iPad) · sonnet |
| 9 | la Tienda sale de la barra | 🔥 `HUDView` (una línea); `GameArtComponents` (`barOrder`), `TabUnlocks`, `tabs.json`, `+Tabs`, `BottomMenuBar`; tests unit y UI de la tienda; catálogo (snapshot) | — | sonnet · sonnet |
| 10 | la barra simétrica, sin rótulos y con íconos grandes | `GameArtComponents` (`GameTabBar`), `BottomMenuBar`, `GameArtComponentsTests`, `BottomMenuUITests` | T9 | sonnet · sonnet |
| 11 | cierre | `Docs/` (controlador) | T1–T10 | — |

```
Ola 1 (ya)        T1 ║ T2 ║ T9            + T4 (Python, no cuenta en el tope)
Ola 2             T5 ║ T3 ║ T7 ║ T10      (≤ 3 compilando: T10 entra cuando se libere un cupo)
Ola 3             T6
Ola 4             T8
Cierre            T11
```

**Reglas del paralelismo:**

1. **Prioridad del dueño**: el camino a "lo que se ve" es T1 → T5 → T6 → T8 (el ascensor) y T9 →
   T10 (la barra). T2, T3, T4 y T7 corren al costado.
2. **De a una sobre el mismo archivo**: T9 y T8 (`HUDView`); T9 y T10 (`GameArtComponents`,
   `BottomMenuBar`); T6 y T8 (`ElevatorRideOverlay`, que T6 crea y T8 completa).
3. **Fuera de la épica**: `FloorMapView` es tibio de **E13 T8** ("Piso ???"): se integran en serie
   (funciones distintas). E13 T8 **ya no necesita** su parte de `ElevatorPanel.swift` (el display
   desaparece y la placa sólo muestra pisos abiertos): se despacha sin ese paso, o si ya entró, T8
   de acá lo borra junto con el archivo. `AudioManager` es tibio de E5b (la ruleta y el apagón
   suman sus `SFX`): en serie. `FisuEvolutionApp` es tibio de E11 T6 y E7b-a T1/T2: en serie.
   `GameArtComponents` es tibio de E4b T3/T7: en serie. `video_assets.py` lo toca también el
   pedido sin plan "lado Swift de las cinemáticas" (ajustes de `retrato`): en serie, T4 primero si
   salen juntos.
4. Tope de **3 compilando** en todo el run (`tasks.md` §3). T4 no compila.
5. **La barra no espera a E3b T4** (duda 1): PLAN-v2 la ponía "después de E3b T4" porque toca el
   orden que el paginador usa; con el carry de abajo, E3b T4 arranca ya con cinco páginas y la
   tienda aparte. Si el dueño prefiere el orden del PLAN, T9 y T10 pasan a ⛔ tras E3b T4 y nada más
   cambia.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` | `FisuEvolutionTests/Support/GameStateFixture.swift` |
| el mapa de la torre | `gameState.floorMap` (de Dios para abajo), `visibleFloorOrdinal`, `debugUnlockFloors(throughTier:)` | `GameState+Tower.swift`, `+Debug` |
| un `FloorMapEntry` a mano | el `map(_:)` privado de `ElevatorPanelModelTests` (copiarlo a la suite nueva antes de borrar la vieja) | `ElevatorPanelModelTests.swift:8-20` |
| el vuelo de la cámara | `BoardScene.flightDuration(floors:totalFloors:)` (estático, interno) | `BoardScene.swift:1541` |
| el contenido real | `try GameContentLoader.load(from: .main)` | `GameContentLoader.swift` |
| el catálogo de strings | `LocalizationCompletenessTests.catalog("Localizable")` | `LocalizationCompletenessTests.swift` |
| UI: esperar a que algo sea tocable / desaparezca | `waitUntilHittable`, `waitUntilGone`, `waitForAny` | `FisuEvolutionUITests/` (helpers de `BottomMenuUITests`) |
| UI: mantener apretado | `element.press(forDuration: 0.9)` | XCUITest |
| UI: el piso a la vista | `app.otherElements["board.floor"].value` (id crudo del piso) | `RootView` |
| Python: un master sintético | `self.master(w, h)` y `self.cuadro(mov)` de `test_video_assets.VideoAssetsTests` | `tests/test_video_assets.py:160-200` |

---

### Task 1: El director del viaje y sus tiempos

**Objetivo:** un tipo puro con los tiempos del viaje (≤ 3 s del 1 al 10, los pisos del medio más
rápido, el viaje nunca más corto que el vuelo de la cámara) y un director `@Observable` que sabe
si la placa está abierta, en qué fase va el viaje, cuándo saltar de piso, cómo se saltea y qué
sonido toca en cada borde. Sin vista y sin `AudioManager`: todo lo de afuera entra por `Hooks`.

**Files:**
- Create: `FisuEvolution/UI/Elevator/ElevatorRide.swift`
- Create: `FisuEvolutionTests/ElevatorRideTests.swift`
- `xcodegen generate` (dos archivos nuevos)

**Interfaces:**
- Produces: `ElevatorRidePlan` (`init?(origin:destination:reduceMotion:instant:)`, `close`,
  `travel`, `open`, `total`, `fades`, `direction`, `passingOrdinals`, `position(atTravelProgress:)`);
  `ElevatorRide` (`phase`, `plan`, `phaseStartedAt`, `isKeypadOpen`, `keypadAnchor`,
  `attach(_ hooks:)`, `openKeypad()`, `closeKeypad()`, `select(ordinal:)`, `requestFromMap(ordinal:)`,
  `startPendingRide()`, `skip()`, `waitUntilIdle()`); `ElevatorRide.Cue`, `ElevatorRide.Hooks`,
  `ElevatorRide.isInstantForUITests`.

**Oráculo:** `Tools/v2/oraculo.sh tarea ElevatorRideTests`
**Revisión:** sonnet · **Modelo:** sonnet. **Tutorial:** no.

- [ ] **Step 0: Pararse en la base**

```bash
grep -n "static func flightDuration" FisuEvolution/Scenes/BoardScene.swift
grep -n "func jumpToFloor" FisuEvolution/Game/State/GameState+Tower.swift
ls FisuEvolution/UI/Elevator 2>/dev/null   # no existe todavía
```

- [ ] **Step 1: Los tests, en rojo** (`FisuEvolutionTests/ElevatorRideTests.swift`)

```swift
import Testing
@testable import FisuEvolution

@Suite("El viaje en cabina")
@MainActor
struct ElevatorRideTests {
    private func seconds(_ d: Duration) -> Double {
        Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }

    @Test("del 1 al 10 entra en 3 s, y un piso solo es más corto")
    func theWholeTowerFitsTheBudget() throws {
        let long = try #require(ElevatorRidePlan(origin: 0, destination: 9, reduceMotion: false, instant: false))
        let short = try #require(ElevatorRidePlan(origin: 0, destination: 1, reduceMotion: false, instant: false))
        #expect(seconds(long.total) <= 3.0)
        #expect(seconds(short.total) < seconds(long.total))
        #expect(long.direction == .up)
        #expect(ElevatorRidePlan(origin: 9, destination: 2, reduceMotion: false, instant: false)?.direction == .down)
    }

    @Test("el viaje nunca dura menos que el vuelo de la cámara: al abrir, ya llegó")
    func travelOutlastsTheCameraFlight() throws {
        for distance in 2...9 {
            let plan = try #require(ElevatorRidePlan(origin: 0, destination: distance, reduceMotion: false, instant: false))
            #expect(seconds(plan.travel) >= BoardScene.flightDuration(floors: distance, totalFloors: 10))
        }
        let hop = try #require(ElevatorRidePlan(origin: 3, destination: 4, reduceMotion: false, instant: false))
        #expect(seconds(hop.travel) >= 0.35, "el salto corto de BoardScene (floorHopDuration)")
    }

    @Test("los pisos del medio pasan más rápido que los de las puntas")
    func middleFloorsPassFaster() throws {
        let plan = try #require(ElevatorRidePlan(origin: 0, destination: 8, reduceMotion: false, instant: false))
        #expect(plan.position(atTravelProgress: 0) == 0)
        #expect(plan.position(atTravelProgress: 1) == 8)
        let start = plan.position(atTravelProgress: 0.1) - plan.position(atTravelProgress: 0)
        let middle = plan.position(atTravelProgress: 0.55) - plan.position(atTravelProgress: 0.45)
        #expect(middle > start)
        #expect(plan.passingOrdinals == Array(0...8))
        #expect(ElevatorRidePlan(origin: 4, destination: 1, reduceMotion: false, instant: false)?.passingOrdinals == [4, 3, 2, 1])
    }

    @Test("al mismo piso no hay viaje; con Reduce Motion son fundidos; bajo los UI tests, cero")
    func degenerateAndAccessibleRides() throws {
        #expect(ElevatorRidePlan(origin: 3, destination: 3, reduceMotion: false, instant: false) == nil)
        let faded = try #require(ElevatorRidePlan(origin: 0, destination: 9, reduceMotion: true, instant: false))
        #expect(faded.fades)
        #expect(seconds(faded.total) < 1.5)
        let instant = try #require(ElevatorRidePlan(origin: 0, destination: 9, reduceMotion: false, instant: true))
        #expect(instant.total == .zero)
    }

    /// Hooks que anotan todo y no duermen de verdad.
    private final class Recorder {
        var jumps: [Int] = []
        var cues: [ElevatorRide.Cue] = []
        var phasesAtJump: [ElevatorRide.Phase] = []
    }

    private func director(_ recorder: Recorder, instant: Bool = false,
                          unlocked: Set<Int> = Set(0...9), visible: Int = 0) -> ElevatorRide {
        let ride = ElevatorRide()
        ride.attach(ElevatorRide.Hooks(
            visibleOrdinal: { visible },
            isUnlocked: { unlocked.contains($0) },
            jump: { [unowned ride] in recorder.jumps.append($0); recorder.phasesAtJump.append(ride.phase) },
            cue: { recorder.cues.append($0) },
            sleep: { _ in await Task.yield() },
            reduceMotion: { false },
            instant: instant
        ))
        return ride
    }

    @Test("elegir un piso de la placa la recoge, cierra, salta al empezar el viaje y abre")
    func selectingRunsTheWholeRide() async {
        let recorder = Recorder()
        let ride = director(recorder)
        ride.openKeypad()
        #expect(ride.isKeypadOpen)
        ride.select(ordinal: 4)
        #expect(!ride.isKeypadOpen)
        await ride.waitUntilIdle()
        #expect(recorder.jumps == [4])
        #expect(recorder.phasesAtJump == [.traveling])
        #expect(recorder.cues == [.keypadOpen, .button, .doorsClose, .motorStart, .motorStop, .ding, .doorsOpen])
        #expect(ride.phase == .idle)
    }

    @Test("un piso cerrado, el mismo piso o un viaje en curso no arrancan otro")
    func ignoredRequests() async {
        let recorder = Recorder()
        let ride = director(recorder, unlocked: [0, 1], visible: 1)
        ride.select(ordinal: 5)
        ride.select(ordinal: 1)
        await ride.waitUntilIdle()
        #expect(recorder.jumps.isEmpty)
        ride.select(ordinal: 0)
        ride.select(ordinal: 0)
        await ride.waitUntilIdle()
        #expect(recorder.jumps == [0])
    }

    @Test("saltear lleva directo a la llegada, con el piso ya cambiado")
    func skipJumpsToTheArrival() async {
        let recorder = Recorder()
        let ride = ElevatorRide()
        ride.attach(ElevatorRide.Hooks(
            visibleOrdinal: { 0 }, isUnlocked: { _ in true },
            jump: { recorder.jumps.append($0) }, cue: { recorder.cues.append($0) },
            sleep: { try? await Task.sleep(for: $0) }, reduceMotion: { false }, instant: false
        ))
        ride.select(ordinal: 6)
        #expect(ride.phase == .closing)
        ride.skip()
        #expect(ride.phase == .idle)
        #expect(recorder.jumps == [6])
        #expect(recorder.cues.suffix(2) == [.motorStop, .ding])
    }

    @Test("el pedido del mapa espera a que el mapa se cierre")
    func mapRequestWaitsForTheSheet() async {
        let recorder = Recorder()
        let ride = director(recorder)
        ride.requestFromMap(ordinal: 3)
        #expect(ride.phase == .idle)
        ride.startPendingRide()
        await ride.waitUntilIdle()
        #expect(recorder.jumps == [3])
        ride.startPendingRide()
        await ride.waitUntilIdle()
        #expect(recorder.jumps == [3], "el pedido se consume una vez")
    }

    @Test("instantáneo: salta en el acto, sin fases ni sonidos de viaje")
    func instantRideJumpsRightAway() async {
        let recorder = Recorder()
        let ride = director(recorder, instant: true)
        ride.select(ordinal: 2)
        #expect(recorder.jumps == [2])
        #expect(ride.phase == .idle)
        #expect(!recorder.cues.contains(.doorsClose))
    }
}
```

- [ ] **Step 2: `ElevatorRide.swift`**

```swift
import Foundation
import Observation
import UIKit

/// Los tiempos de un viaje en cabina (PLAN-v2 E13, ítem 13). Puro: lo pinea `ElevatorRideTests`.
struct ElevatorRidePlan: Equatable {
    enum Direction: Equatable { case up, down }

    static let budget: Duration = .seconds(3)
    static let closeDuration: Duration = .milliseconds(750)
    static let openDuration: Duration = .milliseconds(650)
    static let travelBase: Duration = .milliseconds(500)
    static let travelPerFloor: Duration = .milliseconds(150)
    static let fadeDuration: Duration = .milliseconds(300)

    let origin: Int
    let destination: Int
    let close: Duration
    let travel: Duration
    let open: Duration
    /// Reduce Motion: puertas y fondos se funden, nada se desliza ni vibra.
    let fades: Bool

    init?(origin: Int, destination: Int, reduceMotion: Bool, instant: Bool) {
        guard origin != destination else { return nil }
        self.origin = origin
        self.destination = destination
        fades = reduceMotion
        if instant {
            (close, travel, open) = (.zero, .zero, .zero)
        } else if reduceMotion {
            (close, travel, open) = (Self.fadeDuration, Self.fadeDuration, Self.fadeDuration)
        } else {
            close = Self.closeDuration
            open = Self.openDuration
            let wanted = Self.travelBase + Self.travelPerFloor * abs(destination - origin)
            travel = min(wanted, Self.budget - Self.closeDuration - Self.openDuration)
        }
    }

    var total: Duration { close + travel + open }
    var direction: Direction { destination > origin ? .up : .down }

    /// Los pisos que pasan por la ventana, en el orden en que pasan, puntas incluidas.
    var passingOrdinals: [Int] {
        origin < destination ? Array(origin...destination) : Array((destination...origin).reversed())
    }

    /// Dónde va la tira (ordinal continuo) a una fracción del tramo de viaje. Arranca y frena suave:
    /// los pisos del medio pasan más rápido.
    func position(atTravelProgress progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        let eased = t * t * (3 - 2 * t)
        return Double(origin) + Double(destination - origin) * eased
    }
}

/// El director del ascensor: la placa colgante y el viaje en cabina. Lo crea `FisuEvolutionApp`
/// y lo leen el HUD, el mapa y `ElevatorRideOverlay`.
@Observable @MainActor
final class ElevatorRide {
    enum Phase: Equatable { case idle, closing, traveling, opening }

    /// Los bordes que suenan. `ElevatorRideOverlay` los traduce a `AudioManager.SFX`.
    enum Cue: Equatable { case keypadOpen, keypadClose, button, doorsClose, motorStart, motorStop, ding, doorsOpen }

    struct Hooks {
        var visibleOrdinal: @MainActor () -> Int
        var isUnlocked: @MainActor (Int) -> Bool
        var jump: @MainActor (Int) -> Void
        var cue: @MainActor (Cue) -> Void
        var sleep: @MainActor (Duration) async -> Void
        var reduceMotion: @MainActor () -> Bool
        var instant: Bool
    }

    /// Bajo `--uitest*` el viaje dura 0 s, salvo que el test lo pida con `--uitest-elevator-ride`.
    static var isInstantForUITests: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains { $0.hasPrefix("--uitest") } && !arguments.contains("--uitest-elevator-ride")
        #else
        return false
        #endif
    }

    private(set) var phase: Phase = .idle
    private(set) var plan: ElevatorRidePlan?
    private(set) var phaseStartedAt: ContinuousClock.Instant = .now
    private(set) var isKeypadOpen = false
    /// El frame global del ícono del ascensor del HUD: de ahí cuelga la placa.
    var keypadAnchor: CGRect = .zero

    @ObservationIgnored private var hooks: Hooks?
    @ObservationIgnored private var pendingFromMap: Int?
    @ObservationIgnored private var rideTask: Task<Void, Never>?
    @ObservationIgnored private var jumped = false

    func attach(_ hooks: Hooks) { self.hooks = hooks }

    func openKeypad() {
        guard phase == .idle, !isKeypadOpen else { return }
        isKeypadOpen = true
        hooks?.cue(.keypadOpen)
    }

    func closeKeypad() {
        guard isKeypadOpen else { return }
        isKeypadOpen = false
        hooks?.cue(.keypadClose)
    }

    /// Un botón de la placa.
    func select(ordinal: Int) {
        if isKeypadOpen {
            isKeypadOpen = false
            hooks?.cue(.button)
        }
        start(to: ordinal)
    }

    /// Una fila del mapa: el viaje arranca cuando el mapa termina de irse (`startPendingRide`).
    func requestFromMap(ordinal: Int) { pendingFromMap = ordinal }

    func startPendingRide() {
        guard let ordinal = pendingFromMap else { return }
        pendingFromMap = nil
        start(to: ordinal)
    }

    /// Tocar la pantalla durante el viaje: directo a la llegada.
    func skip() {
        guard phase != .idle, let plan else { return }
        rideTask?.cancel()
        rideTask = nil
        if !jumped { hooks?.jump(plan.destination) }
        hooks?.cue(.motorStop)
        hooks?.cue(.ding)
        finish()
    }

    func waitUntilIdle() async { await rideTask?.value }

    private func start(to destination: Int) {
        guard phase == .idle, let hooks, hooks.isUnlocked(destination),
              let plan = ElevatorRidePlan(origin: hooks.visibleOrdinal(), destination: destination,
                                          reduceMotion: hooks.reduceMotion(), instant: hooks.instant)
        else { return }
        guard plan.total > .zero else {
            hooks.jump(destination)
            return
        }
        self.plan = plan
        jumped = false
        // La fase entra en el acto (no adentro del Task): un segundo pedido en el mismo cuadro
        // ya encuentra el viaje en curso, y la vista arranca a cerrar sin esperar un tick.
        enter(.closing)
        hooks.cue(.doorsClose)
        rideTask = Task { [weak self] in await self?.run(plan, hooks) }
    }

    private func run(_ plan: ElevatorRidePlan, _ hooks: Hooks) async {
        await hooks.sleep(plan.close)
        guard !Task.isCancelled else { return }
        enter(.traveling)
        hooks.jump(plan.destination)
        jumped = true
        hooks.cue(.motorStart)
        await hooks.sleep(plan.travel)
        guard !Task.isCancelled else { return }
        hooks.cue(.motorStop)
        hooks.cue(.ding)
        enter(.opening)
        hooks.cue(.doorsOpen)
        await hooks.sleep(plan.open)
        guard !Task.isCancelled else { return }
        finish()
    }

    private func enter(_ next: Phase) {
        phase = next
        phaseStartedAt = .now
    }

    private func finish() {
        phase = .idle
        plan = nil
        rideTask = nil
    }
}
```

(Si `Duration * Int` no compila tal cual, `Self.travelPerFloor * abs(…)` funciona porque
`Duration` conforma `*` con `Int`; si no, `.milliseconds(150 * abs(…))`.)

- [ ] **Step 3:** `xcodegen generate`, oráculo, commit:
  `feat(ascensor): el director del viaje en cabina, con sus tiempos medidos contra el vuelo`.

---

### Task 2: La placa colgante (modelo, medidas y vista)

**Objetivo:** la placa de la referencia, sin cablear todavía: un resorte de metal arriba, una
placa de acero cepillado con remaches en las esquinas y **una columna** de botones redondos (cara
crema, borde de acero, número negro grueso), uno por piso **abierto**, del más alto arriba al 1
abajo, como máximo 10. El piso actual brilla en amarillo con un destello. Sin nombres, sin
candados, sin luz de "en marcha". La placa mide lo que midan sus botones, que se achican para que
diez entren en el SE entre el HUD y la barra.

**Files:**
- Create: `FisuEvolution/UI/Elevator/ElevatorKeypad.swift`
- Create: `FisuEvolutionTests/ElevatorKeypadModelTests.swift`
- Strings: `Tools/v2/claves-pendientes/e13b-t2.json` (2)
- `xcodegen generate`

**Interfaces:**
- Produces: `ElevatorKeypadModel(map:visibleOrdinal:)` con `floors: [Floor]` (`id`, `ordinal`,
  `number`, `isCurrent`) y `maxButtons = 10`; `ElevatorKeypadLayout.buttonSide(count:availableHeight:)`,
  `.plateSize(count:buttonSide:)`, `.springHeight`; `ElevatorLED.screen` / `.lit` (los tonos del LED,
  públicos: los usan la cabina de T5 y la columna de E7b-b T3); `ElevatorKeypad(model:buttonSide:onSelect:)`.
- Consumes: `FloorMapEntry`, `TowerNaming.floorName(for:)`, `MetalPlate`, `MetalTone`, `PanelScrew`.

**Oráculo:** `Tools/v2/oraculo.sh tarea ElevatorKeypadModelTests LocalizationCompletenessTests`
**Revisión:** sonnet · **Modelo:** sonnet. **Tutorial:** no (la lección es T7).

- [ ] **Step 1: Los tests, en rojo** (copiar el `map(_:)` de `ElevatorPanelModelTests`)

```swift
@Suite("La placa colgante del ascensor")
struct ElevatorKeypadModelTests {
    // private func map(...) -> [FloorMapEntry]  (el mismo de ElevatorPanelModelTests)

    @Test("un botón por piso abierto, del más alto arriba, numerados desde el callejón")
    func onlyUnlockedFloorsTopDown() {
        let model = ElevatorKeypadModel(map: map([
            ("corporate", 0, 10, false), ("urban", 4, 10, true), ("alley", 10, 10, true),
        ]), visibleOrdinal: 1)
        #expect(model.floors.map(\.id) == ["urban", "alley"])
        #expect(model.floors.map(\.number) == [2, 1])
        #expect(model.floors.map(\.isCurrent) == [true, false])
    }

    @Test("la placa crece con los pisos abiertos, de 1 a 10")
    func growsWithTheTower() {
        let ids = ["god_realm", "galaxy", "solar", "mars", "moon", "island", "luxury", "corporate", "urban", "alley"]
        for open in 1...10 {
            let floors = ids.enumerated().map { index, id in (id, 0, 10, index >= ids.count - open) }
            let model = ElevatorKeypadModel(map: map(floors), visibleOrdinal: 0)
            #expect(model.floors.count == open)
        }
        #expect(ElevatorKeypadModel.maxButtons == 10)
    }

    @Test("diez botones entran en el SE entre el HUD y la barra, y nunca bajan de 34 ni pasan de 46")
    func tenButtonsFitTheSE() {
        let available: CGFloat = 667 - 80 - 84 - 12 - 8
        let side = ElevatorKeypadLayout.buttonSide(count: 10, availableHeight: available)
        #expect(side >= 34)
        #expect(ElevatorKeypadLayout.plateSize(count: 10, buttonSide: side).height
                + ElevatorKeypadLayout.springHeight <= available)
        #expect(ElevatorKeypadLayout.buttonSide(count: 2, availableHeight: 2000) == 46)
        #expect(ElevatorKeypadLayout.buttonSide(count: 10, availableHeight: 100) == 34)
    }
}
```

- [ ] **Step 2: El modelo y las medidas**

```swift
/// Lo que dibuja la placa colgante, resuelto y puro (PLAN-v2 E13, ítem 13).
struct ElevatorKeypadModel: Equatable {
    struct Floor: Identifiable, Equatable {
        let id: String
        let ordinal: Int
        let isCurrent: Bool
        var number: Int { ordinal + 1 }
    }

    static let maxButtons = 10

    /// De arriba abajo, sólo los abiertos.
    let floors: [Floor]

    /// `map` viene de Dios para abajo (`GameState.floorMap`).
    init(map: [FloorMapEntry], visibleOrdinal: Int) {
        floors = map.filter(\.isUnlocked).prefix(Self.maxButtons).map {
            Floor(id: $0.id, ordinal: $0.ordinal, isCurrent: $0.ordinal == visibleOrdinal)
        }
    }
}

enum ElevatorKeypadLayout {
    static let maxButtonSide: CGFloat = 46
    static let minButtonSide: CGFloat = 34
    static let spacing: CGFloat = 8
    static let platePadding: CGFloat = 12
    static let springHeight: CGFloat = 24

    static func buttonSide(count: Int, availableHeight: CGFloat) -> CGFloat {
        guard count > 0 else { return maxButtonSide }
        let room = availableHeight - springHeight - platePadding * 2 - spacing * CGFloat(count - 1)
        return min(maxButtonSide, max(minButtonSide, (room / CGFloat(count)).rounded(.down)))
    }

    static func plateSize(count: Int, buttonSide: CGFloat) -> CGSize {
        CGSize(width: buttonSide + platePadding * 2,
               height: CGFloat(count) * buttonSide + CGFloat(max(0, count - 1)) * spacing + platePadding * 2)
    }
}

/// Los tonos del LED del ascensor: la cabina (T5) y la columna de premios (E7b-b T3) los comparten.
enum ElevatorLED {
    static let screen = Color(red: 0.11, green: 0.10, blue: 0.09)
    static let lit = Color(red: 1.0, green: 0.64, blue: 0.18)
}
```

- [ ] **Step 3: La vista**

`ElevatorKeypad` es un `VStack(spacing: 0)` con el resorte arriba y la placa abajo:

- `SpringCoil` (vectorial, envuelto en `GameIcon(artKey: "ui_elevator_spring", size:)`): cinco
  elipses aplastadas apiladas de `MetalTone.light` a `MetalTone.dark` con contorno ink de 1,5 pt,
  de `springHeight` de alto y ~22 pt de ancho.
- La placa: `MetalPlate(cornerRadius: 16)` de fondo (ya trae los cuatro remaches) y adentro un
  `VStack(spacing: ElevatorKeypadLayout.spacing)` con un `ElevatorKeypadButton` por piso, con
  `padding(ElevatorKeypadLayout.platePadding)`. `Grid`/`LazyVStack` no: `VStack` llano (diez
  hijos, sin pereza: los ids tienen que estar en el árbol de AX desde el primer cuadro).
- El marcador de AX (la placa es un contenedor): `.background { Color.clear.accessibilityElement()
  .accessibilityIdentifier("hud.elevator.keypad").accessibilityLabel(Text("elevator.keypad.ax"))
  .accessibilityValue(Text(verbatim: String(model.floors.count))) }`.

`ElevatorKeypadButton(floor:side:action:)`:

```swift
Button(action: action) {
    ZStack {
        Circle().fill(floor.isCurrent
            ? LinearGradient(colors: [Color("PaletteYellow"), Color("PaletteOrange")], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [.white, Color("PaletteCream")], startPoint: .top, endPoint: .bottom))
        Circle().strokeBorder(MetalTone.dark, lineWidth: 3)
        Circle().strokeBorder(MetalTone.bevel.opacity(0.9), lineWidth: 1).padding(3)
        Text(verbatim: String(floor.number))
            .font(.system(size: side * 0.48, weight: .black, design: .rounded))
            .foregroundStyle(Color("PaletteInk"))
    }
    .frame(width: side, height: side)
    .shadow(color: floor.isCurrent ? Color("PaletteYellow").opacity(0.9) : .black.opacity(0.2),
            radius: floor.isCurrent ? 8 : 2, y: floor.isCurrent ? 0 : 1)
    .overlay(alignment: .leading) { if floor.isCurrent { Sparkle(side: side).offset(x: -side * 0.42) } }
    .contentShape(Circle())
}
.buttonStyle(.plain)
.accessibilityIdentifier("hud.elevator.keypad.floor.\(floor.id)")
.accessibilityLabel(Text("elevator.floor.ax \(String(floor.number)) \(TowerNaming.floorName(for: floor.id))"))
.accessibilityValue(floor.isCurrent ? Text("elevator.floor.current") : Text(verbatim: ""))
```

`Sparkle`: tres trazos cortos amarillos con contorno ink en abanico a la izquierda del botón (como
la referencia), `accessibilityHidden(true)`, con un pulso de `keyframeAnimator` **una vez** al
aparecer (`trigger` en `onAppear`, sin `repeatForever`); con Reduce Motion, quieto.

El label de AX usa el nombre del piso (VoiceOver no ve el número como "3", y el nombre ayuda);
**a la vista no hay nombres**. Si E13 T8 ya entró, se usa `TowerNaming.displayName(for:isUnlocked: true)`
si existe (es lo mismo para un piso abierto).

- [ ] **Step 4: Strings** `e13b-t2.json`:

```json
{
  "elevator.keypad.ax": {"es": "Botonera del ascensor", "en": "Elevator keypad"},
  "elevator.floor.current": {"es": "estás acá", "en": "you are here"}
}
```

(`elevator.floor.ax %@ %@` ya existe.) Una vista previa `#Preview` con 2 y con 10 pisos sobre un
fondo cualquiera, para la captura del despacho. Oráculo y commit:
`feat(ascensor): la placa colgante, una columna con un botón por piso abierto`.

---

### Task 3: Los sonidos del ascensor

**Objetivo:** el resorte al desplegar y recoger la placa, el clic de un botón, el golpe de las
puertas y el zumbido del motor con el roce de los cables (`sfx_elevator_*`); el "ding" ya existe.
Y `AudioManager.stop(_:)`, para que saltear el viaje corte el motor.

**Files:**
- Modify: `Tools/audio-synth/generate_audio.py` (cuatro funciones y su registro en `SFX`)
- Create: `FisuEvolution/Resources/Audio/sfx_elevator_spring.caf`, `sfx_elevator_click.caf`,
  `sfx_elevator_doors.caf`, `sfx_elevator_motor.caf` (salen del script)
- Modify: `FisuEvolution/Audio/AudioManager.swift` (tibio: cuatro casos y `stop`)
- Modify tests: `FisuEvolutionTests/AudioManagerTests.swift`
- `xcodegen generate` (recursos nuevos)

**Interfaces:**
- Produces: `AudioManager.SFX.elevatorSpring`, `.elevatorClick`, `.elevatorDoors`, `.elevatorMotor`;
  `AudioManager.stop(_ sfx: SFX)`.

**Oráculo:** `Tools/v2/oraculo.sh tarea AudioManagerTests AudioWiringTests`
**Revisión:** ninguna · **Modelo:** sonnet. **Tutorial:** no.

- [ ] **Step 1: Los cuatro sonidos** (al lado de `sfx_elevator_ding`, con los helpers que ya
  existen: `render_tone`, `render_noise`, `render_noise_lp`, `glide`, `env_perc`, `env_sustain`,
  `env_swell`):

| Clave | Duración | Receta |
|---|---|---|
| `sfx_elevator_spring` | ~0,45 s | "boing" metálico: triángulo con `glide(420, 260)` y vibrato rápido (8 Hz) que decae (`env_perc`, curva 4), más un roce de ruido filtrado al principio |
| `sfx_elevator_click` | ~0,08 s | clic de botón de metal: ruido de 6 ms con decaimiento 1,5 ms + un seno de 2,2 kHz de 30 ms |
| `sfx_elevator_doors` | ~0,6 s | puertas que corren y golpean: ruido filtrado `render_noise_lp` con `env_swell` de 0,45 s y un golpe grave (seno 90 Hz + ruido corto) en 0,48 s |
| `sfx_elevator_motor` | ~1,8 s | zumbido del motor: senos de 55 y 110 Hz con `env_sustain`, más el roce de cables (ruido filtrado muy bajo, con trémolo de 3 Hz) |

Registrarlos en `SFX = {…}` y correr
`python3 Tools/audio-synth/generate_audio.py sfx_elevator_spring sfx_elevator_click sfx_elevator_doors sfx_elevator_motor`
(sólo esos cuatro: no regenera los demás). La tabla impresa no puede tener clipping ni "casi
mudo" (los `assert` del script). Escuchar cada uno con `afplay` antes del commit.

- [ ] **Step 2:** `AudioManager.SFX` suma los cuatro casos (comentario de una línea: "El
  ascensor de E13: placa, botón, puertas y motor") y:

```swift
    /// Corta un SFX que todavía suena (el motor del ascensor al saltear el viaje).
    func stop(_ sfx: SFX) {
        sfxPlayers[sfx]?.stop()
    }
```

- [ ] **Step 3:** `AudioManagerTests`: el test de precarga ya recorre `allCases` (cambiar "los diez
  SFX" del título por "todos los SFX"); sumar "cada SFX tiene su archivo en el bundle"
  (`Bundle.main.url(forResource: sfx.rawValue, withExtension: "caf") != nil` para todos) si no
  existe ya. Oráculo y commit: `feat(audio): el resorte, el clic, las puertas y el motor del ascensor`.

---

### Task 4: Los clips y los cuadros de la cabina

**Objetivo:** `video_assets.py ascensor <cierra|abre>` convierte los dos masters de Higgsfield en
clips HEVC con alfa de 720×1280 (el hueco y las ventanas transparentes), **recortados al
movimiento de las puertas y acelerados a 0,75 s / 0,65 s** (los tiempos de T1), y
`video_assets.py ascensor-cuadros` keyea los dos cuadros fijos a PNG con alfa del mismo tamaño
(los usa la cabina de T5 si no hay clip). El verde se **mide** en cada master, pero en el hueco y
en las ventanas, no en las esquinas (que son la cabina).

**Files:**
- Modify: `Tools/asset-pipeline/scripts/video_assets.py`
- Modify tests: `Tools/asset-pipeline/tests/test_video_assets.py`
- Create: `FisuEvolution/Resources/Cinematics/cine_ascensor_cierra.mov`, `cine_ascensor_abre.mov`,
  `cine_ascensor_cerrada.png`, `cine_ascensor_abierta.png`
- Modify: `FisuEvolution/Resources/Data/loops_manifest.json`

**Interfaces:**
- Produces: las piezas `cinematics.ascensor_cierra` / `cinematics.ascensor_abre` y la sección nueva
  `stills` (`ascensor_cerrada`, `ascensor_abierta`) del manifest; los nombres de archivo que T5
  busca en el bundle.

**Oráculo:** `cd Tools/asset-pipeline && .venv/bin/python -m unittest tests.test_video_assets -v`
(VERDE con los tests nuevos en la salida) + los cuatro archivos en `Resources/Cinematics/`.
**Revisión:** sonnet (mirar los cuadros keyeados) · **Modelo:** sonnet. **Tutorial:** no.

- [ ] **Step 1: Los tests, en rojo** (en `test_video_assets.py`)

- `test_el_ascensor_mide_el_verde_en_el_hueco`: un master sintético con **las esquinas grises** y
  un rectángulo verde en el centro (`self.master` con un `drawbox`; si el helper no lo permite,
  uno propio con `ffmpeg -f lavfi color=gray … ,drawbox=…:color=0x04F523@1:t=fill`). Con la
  medición de esquinas (`measure_key_color`) se niega (`MasterError`); con `measure_key_in_regions`
  devuelve un verde a ≤ 4 del pintado.
- `test_los_dos_verdes_del_ascensor_se_keyean`: un cuadro con el hueco en `#04F523` y dos ventanas
  en `#03FA0E`; tras `process_ascensor`, el alfa del centro del hueco y del centro de cada ventana
  es 0 (con `alfa_decodificable()`, como `assert_keyeado`), y la cabina (gris) queda opaca.
- `test_el_ascensor_se_recorta_y_acelera`: master de 3 s a 24 fps → la pieza dura 0,75 s (cierra)
  / 0,65 s (abre) ± 1 cuadro, sale a 30 fps y 720×1280, sin audio, registrada en
  `manifest["cinematics"]` con `alpha: true`.
- `test_los_cuadros_del_ascensor_salen_keyeados_y_registrados`: un PNG sintético 1520×2688 →
  `cine_ascensor_cerrada.png` RGBA 720×1280 con el hueco transparente, en `manifest["stills"]`.
- `test_la_forma_del_contrato` y `test_no_hay_piezas_huerfanas`: suman `stills` (los `.png` de
  `Cinematics/` también tienen que estar en el manifest).

- [ ] **Step 2: El script**

```python
# El ascensor (PLAN-v2 E13 ítem 13): una sola cabina para todos los viajes. Las
# esquinas del master son la cabina, asi que el verde se mide en el hueco de las
# puertas (cuadro con las puertas abiertas) y en las ventanas (cuadro cerradas).
ELEVATOR_CLIPS = {
    # id: (cuadro de puertas abiertas, recorte en cuadros del master, duracion final)
    "ascensor_cierra": ("first", (6, 62), 0.75),
    "ascensor_abre": ("last", (9, 73), 0.65),
}
ELEVATOR_STILLS = {"ascensor_cerrada": "cabina_cerrada.png", "ascensor_abierta": "cabina_abierta.png"}
ELEVATOR_FPS = 30
# Fracciones del cuadro: el hueco abierto y las dos ventanas de las puertas
# cerradas (medidas en los masters del 2026-10-08).
HOLE_POINTS = [(fx, fy) for fy in (0.35, 0.5, 0.65) for fx in (0.4, 0.5, 0.6)]
WINDOW_POINTS = [(fx, 0.45) for fx in (0.33, 0.36, 0.64, 0.67)]
# Hueco y ventanas son dos verdes (B 35 vs 14): se aceptan juntos si cada uno es
# un verde liso y entre ellos no se apartan mas que esto.
ELEVATOR_MAX_SPREAD = 28
```

- `measure_key_in_regions(video, open_frame, points_open, points_closed) -> str`: decodifica el
  primer y el último cuadro (como `measure_key_color`, con la matriz por defecto), toma parches de
  `CORNER_PATCH` en los puntos del cuadro abierto y en los del cerrado, y llama a
  `key_color_from_patches(patches, max_spread=ELEVATOR_MAX_SPREAD)` (la función gana un parámetro
  con default `MAX_CORNER_SPREAD`; el mensaje de error deja de decir "esquinas" a secas).
- `process_ascensor(clip_id, master, similarity, blend) -> dict`: mide, arma el filtro
  `trim=start_frame=A:end_frame=B,setpts=(PTS-STARTPTS)*{dur}/{(B-A)/24},fps=30,` + el mismo
  keyeo premultiplicado de `encode` + `framing_filter("cinematica", …)`, codifica a
  `Resources/Cinematics/cine_<id>.mov` con `-an`, y registra con `register("cinematica", id, entry)`.
  `validate_id` acepta `ELEVATOR_CLIPS` además de `CINEMATIC_IDS`.
- `process_ascensor_stills(source_dir) -> dict`: por cada cuadro fijo, `ffmpeg -i <png> -vf
  "<key_filter(color)>,format=rgba,premultiply=inplace=1,<framing 720x1280>"` → PNG RGBA en
  `Resources/Cinematics/cine_<id>.png`, con el verde medido igual que en el clip (hueco en el
  abierto, ventanas en el cerrado), y una entrada `{"file", "width", "height", "keyColor"}` en la
  sección `stills` (sección nueva: `load_manifest` la crea vacía).
- El CLI: `ascensor <cierra|abre> [--video …]` y `ascensor-cuadros [--dir …]`.

- [ ] **Step 3: Correrlo sobre los masters del dueño** (no se copian al repo: duda 8)

```bash
cd Tools/asset-pipeline
SRC=~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2/video/ascensor
.venv/bin/python scripts/video_assets.py ascensor cierra --video "$SRC/puertas_cierran.mp4"
.venv/bin/python scripts/video_assets.py ascensor abre --video "$SRC/puertas_abren.mp4"
.venv/bin/python scripts/video_assets.py ascensor-cuadros --dir "$SRC"
```

Verificar a ojo: extraer el primer, el del medio y el último cuadro de cada `.mov` sobre un fondo
magenta (`ffmpeg -i cine_ascensor_cierra.mov -filter_complex "color=magenta:s=720x1280[b];[b][0]overlay"
…`) y mirarlos con Read: el hueco y las ventanas tienen que ser magenta limpio, sin halo verde
(si queda halo, subir `--similarity` de a 0,02 y anotarlo en el commit). Los tamaños de los
`.mov` (esperado < 1 MB cada uno) van en el commit.

- [ ] **Step 4:** tests verdes y commit:
  `feat(video): la cabina del ascensor, keyeada en el hueco y recortada al movimiento de las puertas`
  (staging: el script, el test, los cuatro archivos y el manifest).

---

### Task 5: La cabina y la vista del viaje

**Objetivo:** la vista que se ve **desde adentro** de la cabina: cierran las puertas (con el juego
de verdad detrás del hueco), por las ventanas pasan de abajo hacia arriba (o al revés) los fondos
reales de cada piso mientras la cabina vibra apenas y un indicador LED chico cuenta los pisos,
y se abren las puertas con el destino detrás. Tres arte posibles, en orden: el clip, los cuadros
fijos con fundido, y una cabina vectorial. Tocar la pantalla saltea. Sin montar todavía (T6).

**Files:**
- Create: `FisuEvolution/UI/Elevator/ElevatorCabin.swift`
- Create: `FisuEvolution/UI/Elevator/ElevatorRideView.swift`
- Create: `FisuEvolutionTests/ElevatorCabinTests.swift`
- Strings: `Tools/v2/claves-pendientes/e13b-t5.json` (1)
- `xcodegen generate`

**Interfaces:**
- Consumes: `ElevatorRide`, `ElevatorRidePlan` (T1); `ElevatorLED` (T2, si ya entró; si no, los dos
  colores se declaran acá y T2 los mueve: el que llegue segundo deja uno solo);
  `ChestCinematicPlayer`, `ChestCinematicView`; `gameState.floorMap`,
  `gameState.content?.manifest.backgrounds`.
- Produces: `ElevatorCabinArt` (`.video(close: URL, open: URL)`, `.stills(closed: UIImage, open: UIImage)`,
  `.vector`; `static func resolve(url:image:) -> ElevatorCabinArt`; `static let shared`);
  `CabinFrame.rect(in:)`; `ElevatorRideView(ride:plan:art:)`; `FloorBackdrops`;
  `ElevatorCabinWarmup.shared` (los dos players calentados, para que T6/T8 los preparen al abrir
  el mapa o la placa).

**Oráculo:** `Tools/v2/oraculo.sh tarea ElevatorCabinTests ElevatorRideTests LocalizationCompletenessTests`
**Revisión:** **opus** (AVFoundation y memoria) · **Modelo:** sonnet. **Tutorial:** no.

- [ ] **Step 1: Los tests, en rojo**

```swift
@Suite("La cabina del ascensor")
@MainActor
struct ElevatorCabinTests {
    @Test("con los dos clips es video; con los cuadros, cuadros; sin nada, vectorial")
    func artFallsBackInOrder() {
        let url = URL(fileURLWithPath: "/tmp/x.mov")
        let image = UIImage(systemName: "square")!
        let video = ElevatorCabinArt.resolve(url: { _ in url }, image: { _ in image })
        #expect(video.isVideo)
        let stills = ElevatorCabinArt.resolve(url: { _ in nil }, image: { _ in image })
        #expect(stills.isStills)
        let vector = ElevatorCabinArt.resolve(url: { _ in nil }, image: { _ in nil })
        #expect(vector == .vector)
        let halfVideo = ElevatorCabinArt.resolve(url: { $0 == "cine_ascensor_cierra" ? url : nil }, image: { _ in nil })
        #expect(halfVideo == .vector, "un clip solo no alcanza: cierra y abre van juntos")
    }

    @Test("el bundle de hoy resuelve el arte que dice el manifest")
    func bundleMatchesTheManifest() throws {
        let art = ElevatorCabinArt.resolve()
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: #require(
            Bundle.main.url(forResource: "loops_manifest", withExtension: "json")))) as? [String: Any]
        let cinematics = manifest?["cinematics"] as? [String: Any] ?? [:]
        #expect(art.isVideo == (cinematics["ascensor_cierra"] != nil && cinematics["ascensor_abre"] != nil))
    }

    @Test("en el teléfono la cabina cubre la pantalla; en el iPad va al alto, centrada")
    func cabinFrame() {
        let phone = CabinFrame.rect(in: CGSize(width: 393, height: 852))
        #expect(phone.width >= 393 && phone.height >= 852)
        let pad = CabinFrame.rect(in: CGSize(width: 820, height: 1180))
        #expect(pad.height == 1180)
        #expect(abs(pad.midX - 410) < 0.5)
        #expect(abs(pad.width / pad.height - 720.0 / 1280.0) < 0.001)
    }
}
```

(`isVideo`/`isStills` son dos `var` de conveniencia del enum; `ElevatorCabinArt: Equatable`
compara por caso.)

- [ ] **Step 2: `ElevatorCabin.swift`**

- `ElevatorCabinArt.resolve(url:image:)` con defaults que leen el bundle:
  `url: { Bundle.main.url(forResource: $0, withExtension: "mov") }`,
  `image: { Bundle.main.url(forResource: $0, withExtension: "png").flatMap { UIImage(contentsOfFile: $0.path) } }`;
  pide `cine_ascensor_cierra`/`cine_ascensor_abre` y `cine_ascensor_cerrada`/`cine_ascensor_abierta`
  (los nombres de T4). Se resuelve **una vez** (`static let shared`), no por cuadro.
- `CabinFrame.rect(in size:)`: aspecto 720/1280. Si `size.width / size.height <= 0.6` (teléfono),
  `aspectFill` centrado; si no (iPad), alto completo, centrado en X; los costados los pinta
  `VectorCabin.wall` (crema de pared con una franja de `MetalTone.base` en el borde de la cabina).
- `VectorCabin(doors: Double)` (0 = abiertas, 1 = cerradas): pared crema con contorno ink,
  marco amarillo (`PaletteYellow`) del hueco en (0,18; 0,18)–(0,82; 0,91) del cuadro (las medidas
  del clip), dos hojas de acero (`MetalTone`, con tornillos `PanelScrew`) que corren desde los
  costados del hueco al centro según `doors`, cada una con una ventana redondeada (contorno
  amarillo) **recortada** (`.mask` con `eoFill`), y el tablero del indicador arriba
  (0,5; 0,105). Hueco y ventanas quedan transparentes: detrás se ve lo que haya.
- `ElevatorCabinWarmup` (`static let shared`): `@MainActor final class` que, para `.video`, crea los dos
  `ChestCinematicPlayer(url:)` (el init ya calienta en su `Task`) y los guarda; `prepare()` es
  idempotente y **nunca** bloquea. `close`/`open` devuelven el player listo.

- [ ] **Step 3: `ElevatorRideView.swift`**

Capas de abajo arriba, todo en un `GeometryReader` con `ignoresSafeArea()`:

1. **La tira de fondos** (sólo en `.traveling` y sin `plan.fades`): un `ZStack` de los fondos de
   `plan.passingOrdinals` (cada uno a pantalla completa, `scaledToFill`), apilados en vertical, con
   el offset que sale de `plan.position(atTravelProgress:)` dentro de un
   `TimelineView(.animation)`; progreso = `(now − ride.phaseStartedAt) / plan.travel`. Subir
   (`.up`) es que los fondos **bajan** por la ventana. Con `fades`: el fondo de salida se funde en
   el de destino. En `.closing` y `.opening` no hay tira: detrás del hueco se ve el juego.
2. **La cabina** en `CabinFrame.rect`:
   - `.video`: `.closing` → `ChestCinematicView(player: warmup.close)` y `play(rate: 1, volume: 0)`
     al entrar a la fase; en `.traveling` se queda **pausado en su último cuadro** (puertas
     cerradas, ventanas transparentes: `actionAtItemEnd = .pause`); `.opening` → el de `abre`.
     El `rate` sale de la duración del clip y la de la fase (`clipSeconds / phaseSeconds`), así un
     clip que no coincide con el plan igual termina a tiempo.
   - `.stills`: `.closing` funde `open` → `closed` en `plan.close`; `.opening` al revés.
   - `.vector`: `VectorCabin(doors:)` con `doors` animado de 0 a 1 en `.closing` y de 1 a 0 en
     `.opening` (`easeInOut`); con `fades`, en vez de deslizar, la cabina entera se funde.
   - Vibración en `.traveling`, salvo `fades`: `offset(y: sin(t · 2π · 16) · 1.2)` con el mismo
     `TimelineView`.
3. **El indicador**: un `ElevatorLED.screen` redondeado de ~56 × 26 pt sobre el tablero del clip
   (0,5; 0,105 del rect de la cabina), con el número `Int(position.rounded()) + 1` en
   `ElevatorLED.lit` monospaced pesado y una flecha `arrowtriangle.up.fill`/`.down.fill` según
   `plan.direction`. `contentTransition(.numericText())` salvo Reduce Motion.
4. **Saltear**: un `Button { ride.skip() }` a pantalla completa con `Color.clear` +
   `contentShape(Rectangle())`, `accessibilityIdentifier("elevator.ride.skip")`,
   `accessibilityLabel(Text("elevator.ride.skip.ax"))`.

Al entrar (`.task(id: plan.destination)`): `FloorBackdrops.load(ordinals: plan.passingOrdinals,
entries: gameState.floorMap, manifest: content.manifest, pixelSize: size × displayScale)` — por
piso, `UIImage(named:)` y `await image.byPreparingThumbnail(ofSize:)` **fuera del main** (con un
`TaskGroup`), guardando en un caché de la vista (`[Int: Image]`) que muere con el viaje. Un fondo
que no llegó a tiempo se dibuja como `Color("PaletteInk").opacity(0.25)`: nunca se espera. Diez
fondos a ~1.170 × 2.532 px son ~120 MB: **el tamaño del thumbnail es el ancho de la pantalla en px
y la mitad del alto** (`scaledToFill` lo estira; por la ventana no se nota), ≈ 30 MB en el peor
caso; la revisión opus lo mide con Instruments o `os_proc_available_memory` en el iPhone SE.

- [ ] **Step 4:** `e13b-t5.json`:
  `{"elevator.ride.skip.ax": {"es": "Saltear el viaje", "en": "Skip the ride"}}`.
  `#Preview` de cada arte (con un `ElevatorRide` armado a mano en `.closing`/`.traveling`).
  Oráculo y commit: `feat(ascensor): el viaje visto desde la cabina, con el clip o sin él`.

---

### Task 6: El viaje montado, desde el mapa

**Objetivo:** el director vive en la app y la cabina se dibuja encima de todo; elegir un piso en
el mapa (`FloorMapView`) cierra el mapa y arranca el viaje. Scrollear entre pisos sigue igual, sin
viaje. Bajo `--uitest*` el viaje es instantáneo, así los UI tests de siempre no cambian.

**Files:**
- Create: `FisuEvolution/UI/Elevator/ElevatorRideOverlay.swift`
- Modify: `FisuEvolution/App/FisuEvolutionApp.swift` (tibio)
- Modify: `FisuEvolution/UI/Popups/FloorMapView.swift` (tibio: E13 T8)
- Create: `FisuEvolutionUITests/ElevatorRideUITests.swift`
- `xcodegen generate`

**Interfaces:**
- Consumes: T1 (`ElevatorRide`, `Hooks`, `isInstantForUITests`), T3 (`SFX.elevator*`, `stop`), T5
  (`ElevatorRideView`, `ElevatorCabinArt`, `ElevatorCabinWarmup`).
- Produces: `ElevatorRideOverlay` (la capa, donde T8 suma la placa); `AudioManager.play(_ cue:)`;
  `@Environment(ElevatorRide.self)` disponible en todo el árbol (y en las hojas).

**Oráculo:** `Tools/v2/oraculo.sh tarea ElevatorRideTests ElevatorCabinTests TutorialTipsTests` +
receta R `ElevatorRideUITests`, `FloorMapUITests`, `AscentRenderingUITests/testCharactersStayVisibleAfterTheFirstAscent`,
`CareerChoiceUITests`.
**Revisión:** **opus** (una capa encima de todo: toques, AX, hojas) · **Modelo:** sonnet.
**Tutorial:** la lección `.elevator` se sigue cumpliendo al abrir el mapa (`onMapOpen`, sin cambio).

- [ ] **Step 1: Los UI tests, en rojo** (`ElevatorRideUITests`)

```swift
final class ElevatorRideUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testElegirUnPisoEnElMapaViajaEnCabinaYSeSaltea() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower",
                               "--uitest-elevator-ride"]
        app.launch()
        let map = app.buttons["hud.map"]
        XCTAssertTrue(map.waitForExistence(timeout: 20))
        map.tap()
        let urban = app.buttons["map.floor.urban"]
        XCTAssertTrue(urban.waitForExistence(timeout: 5))
        urban.tap()
        let skip = app.buttons["elevator.ride.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3), "elegir en el mapa no abrió la cabina")
        attach(app, named: "E13b cabina desde el mapa")
        skip.tap()
        XCTAssertTrue(skip.waitForNonExistence(timeout: 2), "saltear no cerró la cabina")
        XCTAssertEqual(app.otherElements["board.floor"].value as? String, "urban",
                       "al saltear, el destino queda a la vista")
    }

    @MainActor
    func testElViajeTerminaSoloEnElDestino() throws {
        // igual hasta `urban.tap()`; sin tocar nada:
        // skip.waitForExistence(3) → skip.waitForNonExistence(timeout: 5) → board.floor == "urban"
    }

    @MainActor
    func testScrollearEntrePisosNuncaViaja() throws {
        // --uitest-unlock-tower --uitest-elevator-ride; deslizar el tablero hacia arriba con el
        // mismo gesto de AscentRenderingUITests (press(forDuration: 0.05, thenDragTo:)); esperar a
        // que board.floor sea "urban"; en ningún momento existe elevator.ride.skip
        // (XCTAssertFalse(app.buttons["elevator.ride.skip"].exists) justo después del gesto y al
        // terminar).
    }
}
```

- [ ] **Step 2: `ElevatorRideOverlay.swift`**

```swift
import SwiftUI

/// La capa del ascensor, por encima de `RootView` (la monta `FisuEvolutionApp`): el viaje en
/// cabina y, desde E13b T8, la placa colgante. Fuera del viaje y con la placa cerrada no
/// existe en el árbol: no come toques ni AX.
struct ElevatorRideOverlay: View {
    @Environment(ElevatorRide.self) private var ride

    var body: some View {
        ZStack {
            if ride.phase != .idle, let plan = ride.plan {
                ElevatorRideView(ride: ride, plan: plan, art: ElevatorCabinArt.shared)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: ride.phase == .idle)
    }
}

extension AudioManager {
    func play(_ cue: ElevatorRide.Cue) {
        switch cue {
        case .keypadOpen, .keypadClose: play(.elevatorSpring)
        case .button: play(.elevatorClick)
        case .doorsClose, .doorsOpen: play(.elevatorDoors)
        case .motorStart: play(.elevatorMotor)
        case .motorStop: stop(.elevatorMotor)
        case .ding: play(.elevatorDing)
        }
    }
}
```

- [ ] **Step 3: `FisuEvolutionApp`**

```swift
    /// El ascensor de E13b: la placa colgante y el viaje en cabina, encima de todo.
    @State private var elevatorRide = ElevatorRide()
    …
            RootView()
                .overlay { ElevatorRideOverlay() }
                .environment(elevatorRide)
                .environment(gameState)
                …
                .task {
                    …
                    elevatorRide.attach(ElevatorRide.Hooks(
                        visibleOrdinal: { [gameState] in gameState.visibleFloorOrdinal },
                        isUnlocked: { [gameState] ordinal in
                            gameState.floorMap.contains { $0.ordinal == ordinal && $0.isUnlocked }
                        },
                        jump: { [gameState] in gameState.jumpToFloor(ordinal: $0) },
                        cue: { [audio] in audio.play($0) },
                        sleep: { try? await Task.sleep(for: $0) },
                        reduceMotion: { UIAccessibility.isReduceMotionEnabled },
                        instant: ElevatorRide.isInstantForUITests
                    ))
```

(`attach` va **antes** de `await gameState.bootstrap()`: es barato y así ningún toque temprano
encuentra el director sin hooks. `floorMap` es computada y recorre diez pisos: está bien para un
toque, no para un cuadro.) ⚠️ `.overlay` antes de los `.environment`: así la capa ve todos los
servicios. Verificar en el simulador que la cabina tapa también la barra de estado y el home
indicator (`ignoresSafeArea` en `ElevatorRideView`).

- [ ] **Step 4: `FloorMapView`**

```swift
    @Environment(ElevatorRide.self) private var ride
    …
        return Button {
            ride.requestFromMap(ordinal: entry.ordinal)
            dismiss()
        } label: { … }
    …
    // en el body, sobre el NavigationStack:
        .onAppear { ElevatorCabinWarmup.shared.prepare() }
        .onDisappear { ride.startPendingRide() }
```

Un piso cerrado no llega acá (la fila sigue `disabled`), y el director igual lo rechaza. El
comentario del encabezado ("el mismo `jumpToFloor(ordinal:)`") pasa a decir que la fila pide el
viaje. Verificar en el iPad que el `onDisappear` del cover transparente de `fisuSheet` también
dispara. Si no dispara, el pedido se arranca desde el `onDismiss` del `fisuSheet` del mapa en
`HUDView`; esa línea la hace **T8** (dueña de `HUDView`): anotarlo en el reporte como carry.

- [ ] **Step 5:** receta R de los cuatro UI tests (los de siempre sin `--uitest-elevator-ride`
  tienen que seguir verdes sin cambiar una línea: el viaje es instantáneo), una grabación corta
  del viaje en el simulador (`xcrun simctl io <UDID> recordVideo`) con `--uitest-elevator-ride`
  para el reporte, y commit:
  `feat(ascensor): elegir un piso en el mapa viaja en cabina; scrollear sigue igual`.

---

### Task 7: La lección "Mantené apretado el ascensor"

**Objetivo:** una lección corta al desbloquear el piso 3 que señala el ícono del ascensor y dice
"Mantené apretado el ascensor para elegir piso"; se da por cumplida (y no vuelve) en cuanto el
jugador despliega la placa, la haya visto o no.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift` (tibio)
- Modify tests: `FisuEvolutionTests/TutorialTipsTests.swift`
- Strings: `Tools/v2/claves-pendientes/e13b-t7.json` (1)

**Interfaces:**
- Produces: `GameState.TutorialLesson.elevatorKeypad`; `GameState.elevatorKeypadOpened()` (la llama
  T8).

**Oráculo:** `Tools/v2/oraculo.sh tarea TutorialTipsTests LocalizationCompletenessTests`
**Revisión:** ninguna · **Modelo:** sonnet. **Tutorial:** es la tarea.

- [ ] **Step 1: Los tests, en rojo** (`TutorialTipsTests`)

- "la lección de la placa nace con el tercer piso, no antes": `makeGameState()`, lecciones
  activadas como en los tests vecinos, `debugUnlockFloors(throughTier:)` hasta dos pisos → la
  lección que nace no es `.elevatorKeypad`; con tres pisos (y `.elevator` ya dada con
  `markLessonDone(.elevator)`), nace `.elevatorKeypad`.
- "desplegar la placa la cumple aunque no se haya visto": sin lección en pantalla,
  `elevatorKeypadOpened()` → `UserDefaults.standard.bool(forKey: TutorialLesson.elevatorKeypad.defaultsKey)`.
- el test que recorre `allCases` (`:19`) sigue verde con el caso nuevo.

- [ ] **Step 2:** en `TutorialLesson`, **después de `elevator`**:

```swift
        /// El tercer piso: la placa colgante (PLAN-v2 E13, ítem 13).
        case elevatorKeypad
```

con `anchorTarget` `.map`, `destinationScreen` `nil`, `textKey` `"tutorial.tip.elevator.hold"` y
elegibilidad `unlockedFloorsCount >= 3`. Y:

```swift
    /// El jugador desplegó la placa del ascensor: la lección se cumple y no vuelve.
    func elevatorKeypadOpened() {
        tutorialTipCompleted(.elevatorKeypad)
        markLessonDone(.elevatorKeypad)
    }
```

- [ ] **Step 3:** `e13b-t7.json`:

```json
{"tutorial.tip.elevator.hold": {"es": "Mantené apretado el ascensor para elegir piso.", "en": "Press and hold the elevator to pick a floor."}}
```

Oráculo y commit: `feat(tutorial): la lección de mantener apretado el ascensor, al tercer piso`.

---

### Task 8: El ícono que se mantiene apretado y la placa en pantalla

**Objetivo:** mantener apretado el ícono del ascensor del HUD despliega la placa colgada de su
resorte, justo debajo del ícono; tocar un botón viaja; tocar afuera, o que entre una celebración,
la recoge. El toque corto sigue abriendo el mapa. La botonera vieja (display LED y persiana) se va
del todo, con sus tests.

**Files:**
- Modify: `FisuEvolution/UI/HUD/HUDView.swift` 🔥
- Modify: `FisuEvolution/UI/Elevator/ElevatorRideOverlay.swift` (la placa)
- Delete: `FisuEvolution/UI/HUD/ElevatorPanel.swift`, `FisuEvolutionTests/ElevatorPanelModelTests.swift`
- Rewrite: `FisuEvolutionUITests/ElevatorPanelUITests.swift`
- Strings: `Tools/v2/claves-pendientes/e13b-t8.json` (1) y `e13b-t8.quitar` (3)
- `xcodegen generate` (dos archivos menos)

**Interfaces:**
- Consumes: T2 (`ElevatorKeypad`, `ElevatorKeypadModel`, `ElevatorKeypadLayout`), T6
  (`ElevatorRideOverlay`, el director en el entorno), T7 (`elevatorKeypadOpened()`), T5
  (`ElevatorCabinWarmup`), `QuickHireButton.longPressDuration`, `GameTabBar.barHeight`/`bottomFloor`.

**Oráculo:** `Tools/v2/oraculo.sh tarea ElevatorKeypadModelTests ElevatorRideTests TutorialTipsTests LocalizationCompletenessTests`
+ receta R `ElevatorPanelUITests`, `ElevatorRideUITests`, `HUDRedesignUITests`, `FloorMapUITests`,
`BottomMenuUITests` en el 16 Pro, **y `ElevatorPanelUITests` en el SE y en el iPad**.
**Revisión:** **opus** (gesto contra botón; la placa en el SE con diez pisos) · **Modelo:** sonnet.
**Tutorial:** llama a `elevatorKeypadOpened()` (T7).

- [ ] **Step 0:** `grep -rn "ElevatorPanel\b\|ElevatorPanel(\|displayHeight\|hud.elevator.display" FisuEvolution FisuEvolutionTests FisuEvolutionUITests`
  → sólo `HUDView` y los dos archivos que se borran. Si aparece otro llamador (E7b-b T3 o E13 T8
  que llegaron antes), `NEEDS_CONTEXT`.

- [ ] **Step 1: `ElevatorPanelUITests`, reescrito, en rojo**

```swift
/// La placa colgante del ascensor (PLAN-v2 E13, ítem 13): mantener apretado el ícono la
/// despliega con un botón por piso abierto; un botón viaja; tocar afuera la recoge; el toque
/// corto sigue siendo el mapa.
final class ElevatorPanelUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["hud.map"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    func testMantenerApretadoDespliegaUnBotonPorPisoYLlevaAlPiso() throws {
        let app = launch()
        XCTAssertFalse(app.otherElements["hud.elevator.keypad"].exists, "en reposo no hay placa")
        XCTAssertFalse(app.buttons["hud.elevator.display"].exists, "el display LED se fue del tablero")
        app.buttons["hud.map"].press(forDuration: 0.9)
        let keypad = app.otherElements["hud.elevator.keypad"]
        XCTAssertTrue(keypad.waitForExistence(timeout: 3), "mantener apretado no desplegó la placa")
        XCTAssertEqual(keypad.value as? String, "2", "un botón por piso abierto")
        XCTAssertFalse(app.buttons["map.floor.urban"].exists, "soltar no abrió el mapa (spike S3)")
        attach(app, named: "E13b placa desplegada")
        app.buttons["hud.elevator.keypad.floor.urban"].tap()
        XCTAssertTrue(keypad.waitForNonExistence(timeout: 2), "elegir no recogió la placa")
        let arrived = NSPredicate(format: "value == %@", "urban")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: arrived, evaluatedWith: app.otherElements["board.floor"])],
                                        timeout: 5), .completed)
    }

    @MainActor
    func testTocarAfueraLaRecogeYElToqueCortoSigueSiendoElMapa() throws {
        let app = launch()
        app.buttons["hud.map"].press(forDuration: 0.9)
        let keypad = app.otherElements["hud.elevator.keypad"]
        XCTAssertTrue(keypad.waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        XCTAssertTrue(keypad.waitForNonExistence(timeout: 2), "tocar afuera no la recogió")
        XCTAssertEqual(app.otherElements["board.units"].value as? String, "0", "el toque de afuera no llegó al tablero")
        app.buttons["hud.map"].tap()
        XCTAssertTrue(app.buttons["map.floor.urban"].waitForExistence(timeout: 5), "el toque corto es el mapa")
    }

    @MainActor
    func testElBotonDeLaPlacaViajaEnCabina() throws {
        let app = launch(["--uitest-elevator-ride"])
        app.buttons["hud.map"].press(forDuration: 0.9)
        app.buttons["hud.elevator.keypad.floor.urban"].tap()
        XCTAssertTrue(app.buttons["elevator.ride.skip"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["elevator.ride.skip"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.otherElements["board.floor"].value as? String, "urban")
    }
}
```

(Si `board.units` arranca distinto de "0" con estos fixtures, se lee antes de tocar y se compara
con el mismo valor.)

- [ ] **Step 2: `HUDView`**

- Fuera: el `.overlay { ElevatorPanel() … }` y el `minHeight: ElevatorPanel.displayHeight` de la
  fila del prestigio (queda `.frame(maxWidth: .infinity, alignment: .top)`), y el
  `elevatorTrailingInset` (lo usaba sólo la botonera; la llave de DEBUG ya no tiene con quién
  chocar). Los comentarios que hablaban de la botonera colgando se corrigen.
- `elevatorButton`:

```swift
    @Environment(ElevatorRide.self) private var ride
    @Environment(\.accessibilityReduceMotion) private var reduceMotion   // ya está
    /// El mantener apretado ya desplegó la placa: el toque de soltar no abre el mapa (spike S3).
    @State private var keypadLongPressFired = false

    private var elevatorButton: some View {
        IconButton(…mismos parámetros…, identifier: "hud.map") {
            if keypadLongPressFired {
                keypadLongPressFired = false
                return
            }
            showFloorMap = true
            onMapOpen()
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: QuickHireButton.longPressDuration)
                .onEnded { _ in
                    keypadLongPressFired = true
                    openKeypad()
                }
        )
        .accessibilityAction(named: Text("elevator.keypad.open")) { openKeypad() }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { ride.keypadAnchor = $0 }
        .tutorialAnchor(.map)
    }

    private func openKeypad() {
        ElevatorCabinWarmup.shared.prepare()
        gameState.playHaptic(.merge)
        gameState.elevatorKeypadOpened()
        ride.openKeypad()
    }
```

- [ ] **Step 3: La placa en `ElevatorRideOverlay`**

```swift
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    …
        ZStack(alignment: .topLeading) {
            if ride.isKeypadOpen {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { ride.closeKeypad() }
                    .accessibilityHidden(true)
                keypad
                    .transition(reduceMotion ? .opacity
                        : .scale(scale: 0.05, anchor: .top).combined(with: .opacity))
            }
            // … el viaje de T6
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.35),
                   value: ride.isKeypadOpen)
        .onChange(of: gameState.showing) { _, _ in ride.closeKeypad() }
        .accessibilityAction(.escape) { ride.closeKeypad() }
```

`keypad`: un `GeometryReader { geo in … }` con `ignoresSafeArea()` que arma
`ElevatorKeypadModel(map: gameState.floorMap, visibleOrdinal: gameState.visibleFloorOrdinal)`
(leyendo `gameState.boardVersion` antes, como la botonera vieja, para que un piso nuevo aparezca
con la placa abierta), calcula el alto disponible
`geo.size.height − ride.keypadAnchor.maxY − GameTabBar.barHeight − GameTabBar.bottomFloor − 8`,
`ElevatorKeypadLayout.buttonSide(count:availableHeight:)`, y posiciona `ElevatorKeypad` con su
borde de arriba en `keypadAnchor.maxY − 6` (el resorte se mete apenas bajo el ícono, como en la
referencia) y centrado en `keypadAnchor.midX`; si la placa se saldría por la derecha, se corre
hacia adentro hasta `Tokens.s8` del borde. `onSelect: { ride.select(ordinal: $0.ordinal) }`.
El marco global del ancla y el de la capa coinciden porque las dos ignoran la safe area: verificarlo
con la captura (el resorte tiene que nacer del ícono, no 20 pt más abajo ni más arriba).

- [ ] **Step 4: Borrar** `ElevatorPanel.swift` y `ElevatorPanelModelTests.swift` (`git rm`),
  `xcodegen generate`. Strings:
  `e13b-t8.json` → `{"elevator.keypad.open": {"es": "Elegir piso", "en": "Choose floor"}}`;
  `e13b-t8.quitar` → `elevator.display.label`, `elevator.floor.staffed`, `elevator.floor.locked`
  (verificar con `grep -rn` que nadie más las usa; si E13 T8 sumó `tower.floor.unknown` y sólo lo
  usaba `ElevatorPanel`, queda: lo usa `FloorMapView`).

- [ ] **Step 5:** capturas con la placa abierta en el SE con diez pisos (`--uitest-unlock-tower`
  no llega: con el panel de debug o `debugUnlockFloors(throughTier: 99)` a mano en el simulador) y
  en el iPad; la placa no toca la barra ni se sale de la pantalla. Oráculo, receta R y commit:
  `feat(ascensor): mantener apretado el ascensor despliega la placa; el display se va del tablero`.

---

### Task 9: La Tienda sale de la barra

**Objetivo:** la barra queda con cinco pestañas (Mejoras, Vestimenta, Contratar, Bonus, Menú); la
Tienda se abre sólo con el "+" de la moneda, que pasa a decir "Tienda" en accesibilidad y lleva el
ancla de su lección. La barra progresiva y su persistencia hablan de esas cinco. Los UI tests que
entraban a la tienda por la barra entran por el "+".

**Files:**
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (sólo `GameScreen.barOrder` y su comentario)
- Modify: `FisuEvolution/Managers/TabUnlocks.swift` (`validate`), `FisuEvolution/Resources/Config/tabs.json`
- Modify: `FisuEvolution/Game/State/GameState+Tabs.swift` (`refreshUnlockedTabs`)
- Modify: `FisuEvolution/UI/HUD/BottomMenuBar.swift` (sin el ancla `.store`; comentarios "seis")
- Modify: `FisuEvolution/UI/HUD/HUDView.swift` 🔥 (una línea: `.tutorialAnchor(.store)` en `coinsPlusButton`; comentario del encabezado)
- Modify tests: `GameArtComponentsTests`, `TabUnlockRulesTests`, `TabUnlockWiringTests`, `MenuSessionTests`
- Modify UI tests: `BottomMenuUITests`, `StoreUITests`, `ProgressiveTabsUITests`, `HUDRedesignUITests`
- Strings: `Tools/v2/claves-pendientes/e13b-t9.json` (1) y `e13b-t9.quitar` (1)

**Interfaces:**
- Produces: `GameScreen.barOrder == [.upgrades, .skins, .jobs, .gifts, .menu]`; `GameScreen.store`
  **se queda** (es la hoja que abre el "+", y la hoja de `RootView` la sigue presentando).

**Oráculo:** `Tools/v2/oraculo.sh tarea GameArtComponentsTests TabUnlockRulesTests TabUnlockWiringTests MenuSessionTests TutorialTipsTests GameContentValidationTests LocalizationCompletenessTests`
+ receta R `BottomMenuUITests`, `StoreUITests` (⚠️ en iOS 18.6: es suite de Store, ver
`oraculo.sh` `STORE_UI`), `ProgressiveTabsUITests`, `HUDRedesignUITests`.
**Revisión:** sonnet · **Modelo:** sonnet. **Tutorial:** la lección `.store` señala el "+".

- [ ] **Step 0:** `grep -rn "secondSession" FisuEvolution FisuEvolutionTests Docs/superpowers/plans | grep -v e13b`
  (si sólo lo usa la tienda, el caso `TabUnlockCondition.secondSession` se borra con su test; si
  otro plan pendiente lo nombra, queda y se anota en el reporte).

- [ ] **Step 1: Los tests, en rojo**

```swift
    @Test("la barra va con Contratar al centro: dos y dos, y la Tienda afuera")
    func barOrderPutsHiringInTheCenter() {
        #expect(GameScreen.barOrder == [.upgrades, .skins, .jobs, .gifts, .menu])
        #expect(Set(GameScreen.barOrder) == Set(GameScreen.allCases).subtracting([.store]))
        #expect(GameScreen.centerTab == .jobs)
    }
```

`tabItemsAreDistinct`: 5 en vez de 6. `sixTabsFitTheSE` lo rehace T10 (acá sigue con
`tabsPerSide: 3`, que sigue siendo cierto). `TabUnlockRulesTests`: fuera
`secondSessionOpensTheStore`; `bundledConfigIsValid` dice "cubre las cinco pestañas de la barra";
uno nuevo: "un `tabs.json` con la tienda no es válido" (`validate()` tira). `MenuSessionTests.pagerStartsOnTheRequestedPage`:
`startIndex(of: .jobs, in: barOrder) == 2` sigue; `isMounted(index: 4, …)` sigue. `TabUnlockWiringTests`:
un save con `meta.unlockedTabs` que trae `"store"` (veterano de la v1) da
`unlockedTabsInBarOrder` sin la tienda.

UI: en `BottomMenuUITests.destinations` la fila de la tienda pasa a `("hud.coins.plus", […mismos ids…])`
(el test recorre "lo que se toca y lo que abre": el "+" es el camino a la tienda) y el comentario
lo dice; `testContratarVaAlCentroYEsElMasGrande` saca `hud.store` de la lista y suma
`XCTAssertFalse(app.buttons["hud.store"].exists, "la Tienda salió de la barra")`.
`StoreUITests.openStore`: `app.buttons["hud.coins.plus"]` ("el + de la moneda nunca apareció").
`ProgressiveTabsUITests`: `hud.store` queda en la lista de ocultas y, en el test de fin de núcleo,
sigue sin aparecer. `HUDRedesignUITests.testElAtajoDeMonedasAbreLaTienda` (`:99`) ya pasa por el
"+": sólo verificar.

- [ ] **Step 2: El código**

- `GameScreen.barOrder = [.upgrades, .skins, .jobs, .gifts, .menu]`, comentario: "Contratar al
  centro, dos y dos. La Tienda no está: la abre el + de la moneda (PLAN-v2 E13, ítem 14)."
- `tabs.json`: sale la línea de `store`. `TabsConfig.validate`: `Set(screens) == Set(GameScreen.barOrder)`
  y `screens.count == GameScreen.barOrder.count`, mensaje "tiene que nombrar las cinco pestañas de
  la barra una vez".
- `refreshUnlockedTabs`: `Set(GameScreen.allCases)` → `Set(GameScreen.barOrder)`, y `saved` se
  filtra a `barOrder` (`.intersection(GameScreen.barOrder)`), así un save viejo con `"store"` no
  la cuela; `meta.unlockedTabs` **no se reescribe** (no se pierde nada si el dueño la quiere de
  vuelta).
- `BottomMenuBar`: `.store` sigue en los `switch` (el enum es exhaustivo) pero el ícono pierde
  `.tutorialAnchor(.store)`; una línea dice que no llega a la barra.
- `HUDView.coinsPlusButton`: `.tutorialAnchor(.store)` después del `IconButton`; el encabezado deja
  de decir que la tienda "sobrevive" en el HUD como atajo de un tab: es **la** entrada a la tienda.
- `e13b-t9.quitar` → `hud.coins.plus.label`; `e13b-t9.json` →
  `{"hud.coins.plus.label": {"es": "Tienda", "en": "Store"}}` (cambiar el texto es quitar + aplicar).

- [ ] **Step 3:** oráculo, receta R y commit:
  `feat(barra): la Tienda sale de la barra; se abre con el + de la moneda`.

---

### Task 10: La barra simétrica, sin rótulos y con íconos más grandes

**Objetivo:** como en la referencia: cinco pestañas 2 + 1 + 2, simétricas alrededor de Contratar,
con íconos más grandes y **sin rótulos de texto** (quedan en accesibilidad). Mientras haya
pestañas sin desbloquear, las que se ven quedan **pegadas a Contratar** (cada lado se llena del
centro hacia afuera). La barra no cambia de alto: `panelHeight` 64 y `barHeight` 84 se conservan,
así el tablero, el atajo, los toasts y `AscentRenderingUITests` no se mueven.

**Files:**
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (`GameTabBar`, `GameTabButton`)
- Modify: `FisuEvolution/UI/HUD/BottomMenuBar.swift` (`iconSide` 46, `prominentIconSide` 64; el
  comentario del recorte del tutorial con las medidas nuevas)
- Modify tests: `FisuEvolutionTests/GameArtComponentsTests.swift`;
  `FisuEvolutionUITests/BottomMenuUITests.swift`

**Interfaces:**
- Produces: `GameTabBar.slots(_:towardCenterFrom:) -> [GameTabItem?]`; `GameTabBar.slotsPerSide = 2`;
  platos 52/72, íconos 46/64.

**Oráculo:** `Tools/v2/oraculo.sh tarea GameArtComponentsTests` + receta R `BottomMenuUITests`,
`ProgressiveTabsUITests`, `AscentRenderingUITests` en el 16 Pro, **y `BottomMenuUITests` en el SE y
en el iPad**.
**Revisión:** sonnet (capturas) · **Modelo:** sonnet. **Tutorial:** las anclas siguen en los íconos
(el recorte crece con ellos).

- [ ] **Step 1: Los tests, en rojo**

```swift
    @Test("la barra no cambia de alto: el panel mide 64 y Contratar sobresale 20")
    func barGeometry() {
        #expect(GameTabBar.plateSide == 52)
        #expect(GameTabBar.centerPlateSide == 72)
        #expect(GameTabBar.panelHeight == 64)
        #expect(GameTabBar.centerRise == GameTabBar.centerPlateSide - GameTabBar.plateSide)
        #expect(GameTabBar.barHeight == 84, "la pila de arriba (atajo, prestigio, toasts) no se mueve")
    }

    @Test("las cinco pestañas entran en el SE con aire")
    func fiveTabsFitTheSE() {
        #expect(GameTabBar.minimumWidth(tabsPerSide: 2) <= 320)
    }

    @Test("cada lado se llena desde Contratar hacia afuera")
    func sidesFillTowardTheCenter() {
        let up = item(.upgrades), sk = item(.skins), gi = item(.gifts), me = item(.menu)
        #expect(GameTabBar.slots([up], towardCenterFrom: .leading).map { $0?.screen } == [nil, .upgrades])
        #expect(GameTabBar.slots([up, sk], towardCenterFrom: .leading).map { $0?.screen } == [.upgrades, .skins])
        #expect(GameTabBar.slots([gi], towardCenterFrom: .trailing).map { $0?.screen } == [.gifts, nil])
        #expect(GameTabBar.slots([gi, me], towardCenterFrom: .trailing).map { $0?.screen } == [.gifts, .menu])
        #expect(GameTabBar.slots([], towardCenterFrom: .trailing).map { $0?.screen } == [nil, nil])
    }
```

(`item(_:)` arma un `GameTabItem` con `AnyView(EmptyView())`, como `tabItemsAreDistinct`.)

`BottomMenuUITests.testLaBarraEsSimetrica` (nuevo, sin `--uitest-progressive-tabs`: las cinco a
la vista): `upgrades.midX + menu.midX` y `skins.midX + gifts.midX` dan `2 · hire.midX` ± 2 pt; los
cuatro platos comunes miden lo mismo (`frame.width` ± 1) y menos que Contratar; ningún botón se
sale de la ventana. Correrlo en el 16 Pro, el SE y el iPad (en el iPad la barra vive en la
`playColumn` de 592: la simetría es alrededor del centro de la pantalla igual).

- [ ] **Step 2: El código**

- `plateSide = 52`, `centerPlateSide = 72` (con eso `centerRise` = 20 y `barHeight` = 84 salen
  solos); el comentario de `panelHeight` pasa a "6 de aire + 52 de plato + 6 hasta el piso" y
  **`panelHeight` sigue siendo 64**.
- `GameTabButton`: fuera el `Text(LocalizedStringKey(item.labelKey))` del label (el
  `accessibilityLabel` con la misma clave **queda**) y el `VStack` que lo contenía; `iconSide`
  46/64. Sin el rótulo, el `minimumBottomGap` de 12 sigue siendo el aire contra el bezel del SE.
- Las zonas: `enum Side { case leading, trailing }`,

```swift
    static let slotsPerSide = 2

    /// Los lugares de un lado de la barra, del borde al centro (`leading`) o del centro al borde
    /// (`trailing`). Las pestañas se pegan a Contratar: con una sola abierta, ocupa el lugar de al
    /// lado del centro (PLAN-v2 E13, ítem 14).
    static func slots(_ items: [GameTabItem], towardCenterFrom side: Side) -> [GameTabItem?] {
        let padding = Array<GameTabItem?>(repeating: nil, count: max(0, slotsPerSide - items.count))
        let filled = items.prefix(slotsPerSide).map { Optional($0) }
        return side == .leading ? padding + filled : filled + padding
    }
```

  y `zone(_:side:)` dibuja `slots(…)` en un `HStack` donde cada lugar es
  `frame(maxWidth: .infinity)` (vacío = `Color.clear` del alto del plato), así las dos zonas
  miden lo mismo y la barra llena se reparte pareja como en la referencia.
- `BottomMenuBar`: `iconSide = 46`, `prominentIconSide = 64`, y el comentario del recorte: 64 + 20
  = 84 sobre los 72 de Contratar, 46 + 20 = 66 sobre los 52 de una común.

- [ ] **Step 3:** capturas del 16 Pro, el SE y el iPad con la barra entera y con la progresiva a
  medio abrir (`--uitest-progressive-tabs`: Mejoras + Contratar pegadas al centro), y commit:
  `feat(barra): cinco pestañas simétricas, íconos grandes y sin rótulos`.

---

### Task 11: Cierre de E13b (controlador)

- [ ] **Step 1:** `Tools/v2/oraculo.sh completo` sobre la punta de `v2/e13-feedback` con
  `version-2` mergeada → VERDE, con `ElevatorRideTests`, `ElevatorKeypadModelTests`,
  `ElevatorCabinTests`, `ElevatorRideUITests` y `ElevatorPanelUITests` en la salida.
- [ ] **Step 2: A mano**, en el simulador del 16 Pro y del SE, con Reduce Motion apagado y
  prendido: mantener apretado el ascensor (resorte, la placa, el piso actual en amarillo con su
  destello, tocar afuera); un viaje del 1 al 10 y uno del 10 al 3 por la placa (puertas, fondos
  pasando por la ventana en el sentido correcto, indicador, vibración, "ding", puertas que abren al
  piso con la gente adentro); uno desde el mapa; saltear a mitad de viaje; scrollear sin viaje; la
  barra de cinco y el "+" abriendo la tienda; la lección del tercer piso. Una grabación de cada uno
  para el dueño.
- [ ] **Step 3: Docs.** `Docs/SESION-<fecha>-v2-e13b.md` (tabla por tarea con su commit y el
  porqué de cada default de "Para el dueño"); `Docs/HANDOFF.md` §4 (E13b), §5 (el ascensor: la
  placa es la única botonera, el viaje es sólo al elegir, la barra es de cinco y la tienda vive en
  el "+"; los defaults que el dueño no cambió), §7 (las trampas nuevas que hayan salido: p. ej.
  "el verde de un clip se mide donde está el verde, no en las esquinas"), §9 (este plan y la
  sesión). `tasks.md`: las filas y los carries de abajo a sus épicas. Journal y `LOCK`.

---

## Lo que E13b le deja a otras épicas

- **E3a T12** (cierre de E3a): el carry "en DEBUG el display tapa el chip ×1,0; medir SE" ya no
  aplica (el display se fue); las capturas del SE incluyen la placa abierta con diez pisos y la
  barra de cinco.
- **E3b T4** (el menú deslizable, montado): las páginas son `unlockedTabsInBarOrder` → **cinco**,
  sin la Tienda. El "+" de la moneda sigue abriendo `StoreView` **sola** (`activeScreen = .store`
  no es una página del paginador: esa rama de `RootView` se conserva). `MenuPagerUITests` cuenta
  cinco puntos. `MenuPage` puede conservar su caso `.store` o no (es exhaustivo).
- **E7b-b T3** (la columna plegable, hermana de la botonera): `ElevatorPanel.swift` **ya no existe**.
  Los tonos del LED son `ElevatorLED.screen` / `.lit` (`UI/Elevator/ElevatorKeypad.swift`, ya
  públicos); el alto del botón en reposo, que era `ElevatorPanel.displayHeight` (44), lo declara
  la columna (44); el resorte de 0,35 s y el "se recoge sola" eran de la persiana vieja: la placa
  nueva no se recoge sola (se recoge tocando afuera). La columna copia la mecánica de "tocar afuera"
  de `ElevatorRideOverlay` si la quiere.
- **E9a T9** (`TutorialCoverageTests`): la mecánica nueva `elevatorKeypad` (mantener apretado el
  ascensor) con su lección `.elevatorKeypad` (E13b T7). **E9b T1**: las lecciones de la botonera de
  E3a (`.explain("elevator.display")`, `.act("elevator.expand", .elevatorExpanded)`,
  `staffed_floors.light` sobre `.elevatorDisplay`) **se reescriben**: el ancla es `.map` (el ícono),
  la señal es "placa desplegada" (`elevatorKeypadOpened()`), el paso de elegir piso es un botón de
  la placa, y la luz de "en marcha" ya no está en la placa: esa lección pasa al mapa
  (`map.staffed`). Las anclas `.elevatorDisplay` y `.elevatorButtons` no se crean. **E9b T2**: la
  lección de la tienda señala el "+" (`.store` ya está ahí desde E13b T9).
- **E13 T8** ("Piso ???"): sin el paso de `ElevatorPanel.swift` (la placa sólo muestra pisos
  abiertos, y el display LED se fue). `FloorMapView` es tibio con E13b T6: en serie.
- **E4b T3 / E7b-b T7**: nada (no tocan el ascensor).
- **El pedido sin plan "lado Swift de las cinemáticas"**: `loops_manifest.json` ya tiene
  `cinematics.ascensor_cierra/abre` y una sección `stills`; el reproductor de esos clips es el de
  los cofres (`ChestCinematicPlayer`). Si ese plan crea un `CinematicPlayer` general, la cabina se
  muda a él (y `ChestCinematicPlayer` se renombra: duda 9).
- **E10** (release): el viaje suma ~1–2 MB de `.mov` y dos `.png` al bundle.

## Para el dueño / dudas

Ninguna frena: la ejecución sigue con el default anotado hasta que el dueño diga otra cosa.

1. **La barra no espera a E3b T4.** PLAN-v2 ponía el ítem 14 después de E3b T4 porque los dos tocan
   las pestañas que ve el paginador; T9 y T10 no tocan `RootView` y le dejan a E3b T4 un carry
   exacto (cinco páginas, la tienda aparte). **Default:** la barra sale en la ola 1–2, que es lo que
   el dueño ve primero. Alternativa: T9/T10 ⛔ tras E3b T4.
2. **El viaje se monta encima de `RootView`, desde `FisuEvolutionApp`**, y no adentro de `RootView`
   (🔥 con E3a T11, E3b T4 y medio plan en cola). La cabina tapa todo lo de `RootView`; las hojas
   del sistema (que el viaje no abre) quedarían por encima. **Default:** así.
3. **La placa se despliega al mantener y queda abierta al soltar**; se elige tocando un botón (no
   arrastrando el dedo hasta el piso y soltando). **Default:** así, que es lo que pide el texto
   ("se recoge tocando afuera o al elegir"). Alternativa: además, deslizar y soltar sobre un botón
   elige (se suma después sin cambiar nada de esto).
4. **Con un solo piso abierto, mantener apretado igual despliega la placa** (un botón, el 1, en
   amarillo); elegir el piso donde estás la recoge sin viaje. **Default:** así (enseña el gesto
   antes de que haga falta). Alternativa: no desplegar con un piso.
5. **Los botones de la placa miden entre 34 y 46 pt** según cuánto lugar haya: diez en el SE dan
   ~36 pt; dos en un 16 Pro, 46. La placa nunca toca la barra.
6. **El viaje dura de 2 s (un piso) a 3 s (del 1 al 10)**: puertas 0,75 s, viaje 0,65–1,6 s,
   puertas 0,65 s. Con Reduce Motion, 0,9 s de fundidos. Bajo los UI tests, 0 s salvo que el test
   lo pida. Los números están en `ElevatorRidePlan` y sólo piden tocar ahí.
7. **Detrás del hueco de las puertas se ve el juego de verdad**, no una foto del fondo: al cerrar,
   la escena del piso de salida (con su gente); al abrir, la del destino (la cámara ya llegó: el
   viaje dura más que el vuelo, y un test lo pinea). Sólo durante el viaje, por las ventanas, pasan
   fondos quietos. **Default:** así; se ve más vivo y no hay que componer nada.
8. **Los masters del dueño no se copian al repo** (viven en el generador, regla "el generador vive
   en su propio repo"); el script se corre con `--video`/`--dir` y lo que entra al repo son los
   `.mov` y `.png` procesados. Alternativa: copiarlos a `Tools/asset-pipeline/video/cinematicas/`
   como el del cofre (~11 MB).
9. **`ChestCinematicPlayer` se reusa con su nombre** (renombrarlo toca `ChestOpeningView`, fuera de
   la épica). Queda para el plan de "lado Swift de las cinemáticas".
10. **Un solo sonido para motor y cables** (`sfx_elevator_motor`, con el roce adentro): son
    simultáneos y así se cortan juntos al saltear. El resorte suena igual al desplegar y al
    recoger. Si el dueño los quiere separados, son dos funciones más en `generate_audio.py`.
11. **El "+" de la moneda pasa a llamarse "Tienda" en VoiceOver** ("Comprar monedas" quedaba corto:
    la tienda vende ORO, packs y quitar anuncios). El dibujo no cambia.
12. **La barra no lleva las rayitas separadoras** que se adivinan en la referencia entre pestaña y
    pestaña; si el dueño las quiere, es una línea en `GameTabBar.zone`.
13. **En el iPad la cabina va al alto de la pantalla, centrada**, con la pared crema a los costados
    (cubrirla entera le cortaba arriba y abajo justo el hueco de las puertas).
14. **La lección del tercer piso no reemplaza a la del segundo** ("Tocá el ascensor…", que sigue
    siendo cierta: el toque abre el mapa). Son dos lecciones chicas, una por gesto.

## Filas para `tasks.md`

Para reemplazar la fila `P-E13b` y sumar debajo en §5 "E13". La rama es la de E13
(`v2/e13-feedback`). En §3.1, E13b **no suma** calientes del run (`HUDView` es caliente sólo dentro
de la épica: T9 → T8). En §3.2 suma: `FisuEvolutionApp.swift` (E13b T6), `AudioManager.swift`
(E13b T3), `FloorMapView.swift` (E13 T8, E13b T6), `GameArtComponents.swift` (E13b T9, T10),
`GameState+TutorialTips.swift` (E13b T7), `video_assets.py` (E13b T4, el pedido de las
cinemáticas). En §5 E3a, la fila T8 suma en su nota "reemplazada por E13b (placa colgante)"; en
E3b T4, E7b-b T3, E9a T9, E9b T1/T2 y E13 T8, los carries de arriba.

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E13b | Plan de E13 ítems 13–14 (ascensor y barra) | ✅ | — | — | (el commit de este plan) | 11 tareas (T1–T11); `2026-10-08-v2-e13b-ascensor-barra.md`; 14 dudas con default; **no toca RootView ni GameState** |
| E13b-T1 | El director del viaje en cabina y sus tiempos (≤ 3 s, nunca menos que el vuelo) | ⏳ | — | nuevos (`UI/Elevator/ElevatorRide.swift`) | | sonnet; ola 1 |
| E13b-T2 | La placa colgante: modelo, medidas (34–46 pt) y vista, sin cablear | ⏳ | — | nuevos (`ElevatorKeypad.swift`); catálogo (snapshot) | | sonnet; ola 1; `ElevatorLED` público (carry E7b-b T3) |
| E13b-T3 | Los sonidos del ascensor (resorte, clic, puertas, motor) y `AudioManager.stop` | ⏳ | — | AudioManager (tibio, E5b); generate_audio.py, 4 `.caf` | | revisión ninguna |
| E13b-T4 | Los clips y los cuadros de la cabina (`video_assets.py ascensor`) | ⏳ | — | video_assets.py (tibio: pedido de cinemáticas); Resources/Cinematics, loops_manifest.json | | Python, no compila; key medido en el hueco y las ventanas; masters por `--video` |
| E13b-T5 | La cabina y la vista del viaje (clip → cuadros → vectorial) | ⛔ | T1 | nuevos (`ElevatorCabin.swift`, `ElevatorRideView.swift`); catálogo (snapshot) | | **revisión opus** (AVFoundation, memoria de fondos en el SE); no espera a T4 |
| E13b-T6 | El viaje montado encima de RootView; el mapa viaja | ⛔ | T1, T3, T5 | FisuEvolutionApp (tibio), FloorMapView (tibio, E13 T8); nuevo ElevatorRideOverlay | | **revisión opus**; bajo `--uitest*` el viaje es 0 s (los UI tests de siempre no cambian) |
| E13b-T7 | La lección "Mantené apretado el ascensor" al tercer piso | ⏳ | — | +TutorialTips (tibio); catálogo (snapshot) | | revisión ninguna; carry E9a T9 / E9b T1 |
| E13b-T8 | Mantener apretado el ascensor despliega la placa; el display LED se va | ⛔ | T2, T6, T7; T9 integrada | 🔥 HUDView (épica); ElevatorRideOverlay; borra ElevatorPanel.swift; catálogo (snapshot) | | **revisión opus**; reescribe ElevatorPanelUITests; capturas SE (10 pisos) e iPad |
| E13b-T9 | La Tienda sale de la barra (se abre con el + de la moneda) | ⏳ | — | 🔥 HUDView (una línea); GameArtComponents (barOrder), TabUnlocks, tabs.json, +Tabs, BottomMenuBar; catálogo (snapshot) | | ola 1; migra BottomMenu/Store/ProgressiveTabs UITests al `hud.coins.plus`; carry E3b T4 (5 páginas) — duda 1 |
| E13b-T10 | La barra simétrica 2 + 1 + 2, sin rótulos y con íconos grandes | ⛔ | T9 | GameArtComponents (GameTabBar), BottomMenuBar | | `panelHeight` 64 y `barHeight` 84 se conservan; capturas SE e iPad |
| E13b-T11 | Cierre de E13b (controlador) | ⛔ | T1–T10 | `Docs/` | | `completo`; grabaciones para el dueño |
