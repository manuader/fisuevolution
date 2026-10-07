# E3a — UX núcleo, la pantalla: iPad, tablero, barra y ascensor · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que la 2.0 se juegue a pantalla completa en todo iPhone y iPad (vertical), con un
tablero que usa la pantalla —15 lugares en 3 filas, la multitud al ~70 %—, una barra de abajo
más baja que aparece de a poco, y la botonera del ascensor con su display LED.

**Architecture:** la geometría del tablero sale de un tipo puro (`PlayLayout`) que en iPhone
reproduce la v1 al punto (test golden) y en pantallas anchas topea la celda y centra el campo;
las safe areas dejan de ser una foto del arranque (`ScreenInsets`, observable); el chrome de
SwiftUI vive en una columna centrada (`PlayColumn`, 592 pt) con los fondos a sangre; las hojas
pasan por un solo modificador (`fisuSheet()`); y lo que se desbloquea (pestañas) es dato
(`tabs.json`) que evalúa una regla pura y persiste en `meta.unlockedTabs` (save v6 de E1).

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit · EconomyKit (SPM puro, `Sendable`) · Swift Testing · XCUITest · XcodeGen (el
`.xcodeproj` no se versiona) · Python 3 (la herramienta del catálogo).

**Fuente:** `Docs/PLAN-v2.md` §4, "E3 — UX núcleo: iPad, atajo, ficha, menú deslizable,
i18n" (decisiones cerradas: **no se re-litigan**), §0.1 (agentes concurrentes), §2 y §3.
Lo que el código contradice o la spec deja abierto está en la sección final "Para el dueño /
dudas", con el supuesto con el que se sigue.

### Por qué E3 va en dos planes

E3 son seis frentes casi independientes (iPad, tablero y barra, botonera, atajo, ficha, menú
deslizable, compartir) y en un solo documento serían ~25 tareas y ~6.000 líneas que ningún
subagente lee enteras. Se parte por **lo que mira el jugador**:

- **E3a (este plan) — la pantalla:** iPad universal, iOS 18, `PlayLayout`, `ScreenInsets`,
  `PlayColumn`, hojas en iPad, 15 lugares en 3 filas, la barra baja y progresiva, la botonera
  del ascensor, el layout en castellano en el SE y las capturas de iPad. Es geometría y chrome.
- **E3b (`2026-10-07-v2-e3b-ux-nucleo.md`) — las interacciones:** el atajo v2 (renombre, pin,
  selector), la ficha de personaje, el menú deslizable y compartir recableado. Son estados y
  gestos.

Los dos comparten la sección "Orden, olas y paralelismo" en espíritu (cada uno lista la suya)
y E3b depende de E3a en tres puntos que nombra con tarea y archivo (`fisuSheet`, el orden de la
barra y las pestañas desbloqueadas).

### Lo de E3 que YA está hecho (no se replanifica)

`Docs/SESION-2026-10-06-v2-e3-i18n.md` (mergeado en `version-2`, `6b5e408`): `IAPCopy` (los
IAP con nombre y descripción del catálogo), ATT en inglés, el logo del splash desde el primer
frame, los consejos del splash en el catálogo, `CFBundleName` en los dos idiomas y
`LocalizationCompletenessTests`. De i18n quedan sólo `LocalizationLayoutUITests` (Task 12) y el
checklist de App Store Connect (E10).

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning
  rompe el build. Nada de `Timer` para lógica de juego (regla 2): todo reloj va por el tick o
  el flush de 8 Hz. En vistas, el reloj es un `.task(id:)` con `Task.sleep`, como los toasts.
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate` al agregar o borrar
  un archivo Swift o un recurso**, en el mismo paso en que se crea.
- **Strings nuevos, es + en, en el mismo commit que la vista**, siempre por la herramienta de
  la Task 1 (`Tools/v2/catalogo.py`, formato canónico, trampa 29). Cada tarea escribe sus claves
  en `Tools/v2/claves-pendientes/e3a-tN.json` y las aplica con
  `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e3a-tN.json` para correr sus tests.
  **Si en su ola es dueña de `Localizable.xcstrings`** (lo dice el despacho del controlador),
  commitea el catálogo y borra el JSON; **si no**, commitea sólo el JSON y descarta el catálogo
  (`git checkout -- FisuEvolution/Resources/Localizable.xcstrings`): el controlador lo aplica al
  integrar (PLAN-v2 §0.1).
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos**
  (trampa 9a-bis). Los marcadores para tests van como `Color.clear` de fondo, como
  `board.units`.
- **FisuJobs es la referencia visual de toda pieza nueva** y los materiales v3 mandan: madera
  y pergamino para los paneles, **metal con remaches para la maquinaria** (la botonera del
  ascensor), pills caramelo (`PillBackground`), `PanelCard`/`GameCard`,
  `ActionPill`/`PricePill`/`StateBadge`, paleta y tipografía de la casa (`Tokens`). Nada de
  botones ni alertas del sistema.
- **Toda animación nueva se apaga con `accessibilityReduceMotion`** y apagada deja la pantalla
  en su estado final (fundido en vez de movimiento). Nada de `repeatForever` incondicional.
- **Nada nuevo corre bajo `--uitest*` salvo que el test lo pida** con su propio flag (patrón
  `tutorialLessonsAutorun`): las pestañas progresivas sólo con `--uitest-progressive-tabs`.
- **En iPhone (ancho ≤ 440 pt) el layout es idéntico al de hoy** salvo lo que la tarea dice
  cambiar a propósito (la barra 20 pt más baja, la multitud sobre la barra nueva). Lo pinean
  `PlayLayoutTests.iPhoneIsTheV1Layout` y los tests de UI que ya existen.
- Contenido data-driven: las reglas de desbloqueo de pestañas van a `Config/tabs.json`. Lo que
  se escribe en código es geometría (constantes con nombre y su porqué).
- EconomyKit no conoce UI. Esta épica no toca EconomyKit salvo lo que diga una tarea.
- Código nuevo limpio y con pocos comentarios (regla del dueño: prolijidad antes que
  comentarios); los comentarios heredados no se borran por deporte, pero **el que deja de ser
  verdad se reescribe en el mismo commit** (los de "sólo iPhone" y "iOS 17", sobre todo).
- **Commits en español, estilo `feat(ux): …`, SIN `Co-Authored-By`.** Staging selectivo por
  archivo y `git diff --cached --stat` antes de cada commit.
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración con
  `oraculo.sh rapido` → `Docs/SESION-<fecha>-v2-e3a.md` (tabla de estado por tarea, el porqué y
  lo medido) → las cuatro ediciones de `Docs/HANDOFF.md` (§4, §5 si algo quedó decidido, §7 si
  hubo trampa, §9) → journal AVO y latido del `LOCK` → `handoffs/HANDOFF-<fecha>-v2-e3a.md`
  (gitignored) al cortar la sesión. Ningún subagente toca `Docs/`, `handoffs/`, el journal ni
  `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

**El oráculo del run** (`Tools/v2/oraculo.sh`) es el juez de cada integración:

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5)
Tools/v2/oraculo.sh completo          # + Store (18.6) + UI en la matriz + pipeline + pacing-sim + Release
```

- Termina en 0 sólo si todo está verde salvo los rojos de `Tools/v2/rojos-declarados.txt`. Los
  tests nuevos entran solos (corre las suites enteras). La Task 10 le suma el paso `ipad-ui`
  (iPad Pro 13") y la Task 12 el paso `se-ui` (iPhone SE 3), los dos dentro de `completo`.
- `rapido` al cerrar cada tarea; `completo` al cerrar las tareas con UI (T7, T8, T9, T10, T11)
  y al cerrar la épica (T12).

**Receta R — correr UNA suite para ver el rojo y el verde:**

```bash
# App: simulador propio por UDID, DerivedData absoluto, filtro por SUITE (sin "()" no corre nada)
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e3-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e3" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e3" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/PlayLayoutTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
```

Para iPad o SE se cambia sólo el tipo de dispositivo del `simctl create`:
`"iPad Pro 13-inch (M4)"`, `"iPad mini (A17 Pro)"` o `"iPhone SE (3rd generation)"` (los tres
están instalados, medido el 2026-10-06). El mismo `build-for-testing` sirve para los tres: es
el mismo SDK y la misma arquitectura.

⚠️ **Una corrida que no nombra los tests esperados no probó nada** ("0 tests" con éxito es el
modo de falla de `-only-testing:`). Y antes de culpar al código ante un rojo en masa: `uptime`,
`ps aux | grep '[x]codebuild'` y qué árbol compiló (trampas 16, 33 y 44; la de E3 i18n: mirá
las rutas de los `SwiftCompile` en el log).

## Las referencias de PLAN-v2 E3, verificadas contra el árbol (`4fd77c8`)

| Lo que cita el plan | Dónde está hoy | Estado |
|---|---|---|
| `project.yml:42,101` (`TARGETED_DEVICE_FAMILY "1"`) | `project.yml:39` (base) y `:101` (target) | ✅ con el comentario del error 90474 en `:89-100` |
| `deploymentTarget` 17 | `project.yml:6` y `IPHONEOS_DEPLOYMENT_TARGET` en `:38` | ✅ |
| camino iOS 17 de `clearNavigationBackdrop` | `PanelFrames.swift:269-305` (`LegacyClearNavigationBackdrop`) | ✅ |
| `BoardScene.swift:1226-1234` (escala por ancho) | `layoutBoard()` `:1205-1238`: `boardRows = 2`, `cellSize = (W − 32) / columnas` | ✅ |
| `crowdTopRatio` 0,44 y `crowdBand`/`depthZ` parametrizados por filas | `BoardScene.swift:171`, `:1733-1745`, `:1707-1709` | ✅ |
| lecturas estáticas de la safe area | `HUDView.swift:87-93` y `GameArtComponents.swift:1080-1086` | ✅ |
| `hud.map` | `HUDView.elevatorButton` `:247-266` | ✅ abre `FloorMapView` |
| `GameTabBar` "374 de 375 pt en el SE" | `GameArtComponents.swift:1162-1175` | ✅ platos 62/56, barra 84 |
| `GameTabBar.barHeight` lo consumen `BoardScene.bottomInset` y los dos toasts | `BoardScene.swift:151`, `RootView.swift:691,789` | ✅ y el espejo de `AscentRenderingUITests.swift:73` (118) |
| el sfx "ding" | `Resources/Audio/sfx_elevator_ding.caf` existe (E8 audio) | ⚠️ sin caso en `AudioManager.SFX`: lo cablea la Task 8 |
| `InfoPlistContractTests` | no existe | lo crea la Task 5 |
| "Launch screen con color crema" | `INFOPLIST_KEY_UILaunchScreen_Generation: YES` (`project.yml:76`) genera el diccionario vacío | la Task 5 lo pasa a `Info.plist` |
| `fisuSheet()`, `PlayLayout`, `PlayColumn`, `ScreenInsets`, `ElevatorPanel` | no existen | Tasks 3, 4, 6, 8 |

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Tools/v2/catalogo.py` | **nuevo** — escribir el catálogo en formato canónico; aplicar snapshots | 1 |
| `Tools/v2/test_catalogo.py` | **nuevo** — sus tests (unittest) | 1 |
| `Tools/v2/claves-pendientes/` | **nuevo** — snapshots de claves que el controlador aplica al integrar | 1 |
| `FisuEvolution/Scenes/PlayLayout.swift` | **nuevo** — geometría pura del tablero | 3, 10 |
| `FisuEvolution/UI/ScreenInsets.swift` | **nuevo** — safe areas observables + la sonda | 4 |
| `FisuEvolution/UI/PlayColumn.swift` | **nuevo** — la columna de 592 pt del chrome | 4 |
| `FisuEvolution/UI/HUD/HUDView.swift` | insets, columna, la botonera colgando, la hoja del mapa | 4, 6, 8 |
| `FisuEvolution/UI/Art/GameArtComponents.swift` | `GameTabBar` (insets, columna, Contratar al centro, "¡Nuevo!"), `GameScreen.barOrder` | 4, 7, 9 |
| `FisuEvolution/UI/Tutorial/TutorialOverlay.swift`, `TutorialTipView.swift` | tarjetas de 520 pt | 4 |
| `project.yml` | universal, iOS 18, iPad vertical, pantalla completa | 5 |
| `FisuEvolution/Info.plist` | `UILaunchScreen` crema | 5 |
| `FisuEvolution/UI/Art/PanelFrames.swift` | sin camino iOS 17; `fisuSheet()` y la columna de 640; `MetalPlate` | 5, 6, 8 |
| popups (`OfflineEarnings`, `Prestige`, `CareerChoice`, `DailyReward`, `SpecialDrop`, `SkinAward`, `CharacterSheet`, `ShareCard`) | `fisuSheet()` | 6 |
| `FisuEvolution/UI/HUD/BottomMenuBar.swift` | orden de la barra; pestañas desbloqueadas y "¡Nuevo!" | 7, 9 |
| `FisuEvolution/UI/HUD/ElevatorPanel.swift` | **nuevo** — modelo puro + la botonera | 8, 10 |
| `FisuEvolution/Audio/AudioManager.swift` | `case elevatorDing` | 8 |
| `FisuEvolution/Resources/Config/tabs.json` | **nuevo** — reglas de desbloqueo | 9 |
| `FisuEvolution/Managers/TabUnlocks.swift` | **nuevo** — config, señales y regla pura | 9 |
| `FisuEvolution/Managers/GameContentLoader.swift` | carga y valida `tabs.json` | 9 |
| `FisuEvolution/Game/State/GameState+Tabs.swift` | **nuevo** — proyección, persistencia y "¡Nuevo!" | 9 |
| `FisuEvolution/Game/State/GameState.swift` | `unlockedTabs`, `newTabs`, `cameraFloor`, `boardLayoutMarker` | 9, 10 |
| `FisuEvolution/Game/State/GameState+Debug.swift` | `--uitest-progressive-tabs` | 9 |
| `FisuEvolution/Scenes/BoardScene.swift` | `PlayLayout`, filas por capacidad, `textScale`, tope del reveal, cámara continua | 10 |
| `FisuEvolution/App/RootView.swift` | marcador `board.layout`; columna y `fisuSheet` de las seis | 10, 11 |
| `Tools/v2/oraculo.sh` | pasos `ipad-ui` y `se-ui` | 10, 12 |
| tests | `PlayLayoutTests`, `ScreenInsetsTests`, `InfoPlistContractTests`, `SheetPresentationGuardTests`, `ElevatorPanelModelTests`, `TabUnlockRulesTests`, `TabUnlockWiringTests` (unit); `ElevatorPanelUITests`, `ProgressiveTabsUITests`, `IPadLayoutUITests`, `LocalizationLayoutUITests` (UI) | 3–12 |

## Orden, olas y paralelismo

**Archivos calientes** (un solo dueño por ola, PLAN-v2 §0.1): `GameState.swift`,
`RootView.swift`, `BoardScene.swift`, `ContentSystems.swift`, `GameState+Bonus.swift`,
`PlayerState.swift`, `TowerActions.swift`, `SettingsView.swift`, `Localizable.xcstrings`,
`project.yml`. **E1 corre en paralelo** (rama `v2/e1-correcciones`) y es dueña de casi todos
ellos en sus tareas 3 a 16; además toca, sin ser calientes, `Info.plist` (E1 T6),
`GameState+Debug.swift` (E1 T2, T3, T8–T10, T12, T13), `GameState+Hiring.swift` (E1 T3, T13),
`FisuEvolutionApp.swift` (E1 T5, T8) y `GameState+Celebrations.swift` (E1 T9, T10). Esos se
marcan "tibios": no se tocan en una ola en la que E1 los toca.

| T | Archivos | 🔥 calientes | Tibios | Depende de |
|---|---|---|---|---|
| 1 | `Tools/v2/catalogo.py`, `test_catalogo.py`, `claves-pendientes/` | — | — | — |
| 2 | ninguno (spikes, sin commit de producto) | — | — | — |
| 3 | `PlayLayout.swift`, `PlayLayoutTests.swift` | — | — | — |
| 4 | `ScreenInsets.swift`, `PlayColumn.swift`, `HUDView.swift`, `GameArtComponents.swift`, `TutorialOverlay.swift`, `TutorialTipView.swift`, `ScreenInsetsTests.swift` | — | — | T3 (su test compara con `PlayLayout.phoneMaxWidth`) |
| 5 | `project.yml`, `Info.plist`, `PanelFrames.swift`, `InfoPlistContractTests.swift` | `project.yml` | `Info.plist` (E1 T6) | — |
| 6 | `PanelFrames.swift`, 8 popups, `HUDView.swift`, `SheetPresentationGuardTests.swift` | — | — | T4, T5 |
| 7 | `GameArtComponents.swift`, `BottomMenuBar.swift`, `GameArtComponentsTests.swift`, `BottomMenuUITests.swift` | — | — | T4 |
| 8 | `ElevatorPanel.swift`, `PanelFrames.swift`, `HUDView.swift`, `AudioManager.swift`, catálogo, tests | catálogo (o snapshot) | — | T6 |
| 9 | `tabs.json`, `TabUnlocks.swift`, `GameContentLoader.swift`, `GameState+Tabs.swift`, `GameState.swift`, `GameState+Debug.swift`, `BottomMenuBar.swift`, `GameArtComponents.swift`, catálogo, tests | `GameState.swift`, catálogo | `GameState+Debug.swift` | T7, **E1 T4** (`meta.unlockedTabs`) |
| 10 | `BoardScene.swift`, `PlayLayout.swift`, `GameState.swift`, `RootView.swift`, `ElevatorPanel.swift`, `CrowdDepthTests.swift`, `RevealLayoutTests.swift`, `AscentRenderingUITests.swift`, `IPadLayoutUITests.swift`, `oraculo.sh` | `BoardScene.swift`, `GameState.swift`, `RootView.swift` | — | T3, T7, T8, **E1 T10** (última de E1 en `BoardScene`) |
| 11 | `RootView.swift`, `SheetPresentationGuardTests.swift`, `IPadLayoutUITests.swift` | `RootView.swift` | — | T6, T10 |
| 12 | `LocalizationLayoutUITests.swift`, `AppStoreScreenshotTests.swift`, `oraculo.sh` | — | — | todas |

```
Ola 1 (fría, en paralelo con E1 T5–T8)   T1 catálogo ║ T2 spikes S1/S4/S5/S6 ║ T3 PlayLayout
Ola 2 (fría)                             T4 insets + columna ║ T5 universal (no en la ola de E1 T6)
Ola 3 (fría)                             T6 hojas en iPad ║ T7 la barra baja
Ola 4 (fría salvo el catálogo)           T8 la botonera del ascensor
── calientes: en las ventanas que deja E1, o después de E1 T16 ──
Ola 5                                    T9 pestañas progresivas         (GameState.swift; después de E1 T4)
Ola 6                                    T10 la escena                    (BoardScene; después de E1 T10, no con E1 T12–T14)
Ola 7                                    T11 la raíz                      (RootView; no con E1 T13–T14)
Ola 8                                    T12 SE en castellano + capturas  (cierre)
```

**Reglas del paralelismo:**

1. Cada tarea corre en su worktree aislado (`Agent(isolation: "worktree")`, PLAN-v2 §0.1),
   desde la punta de la rama de la épica (`v2/e3-ux`), con su DerivedData y su simulador por
   UDID, y los apaga al terminar.
2. El controlador integra de a una (`git rebase` sobre la punta + `git merge --ff-only`), corre
   `oraculo.sh rapido` sobre la integración, aplica los snapshots pendientes de
   `Tools/v2/claves-pendientes/` con la Task 1 y recién ahí hace los docs.
3. Hasta 3 agentes compilando a la vez (los spikes compilan y cuentan). La Task 1 no compila.
4. Un agente que necesita un archivo caliente que no es suyo en la ola para y reporta
   `NEEDS_CONTEXT`.
5. E3b (`2026-10-07-v2-e3b-ux-nucleo.md`) usa `fisuSheet()` (T6), `GameScreen.barOrder` (T7) y
   `unlockedTabsInBarOrder` (T9) de este plan: sus tareas que los consumen van después.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` | `FisuEvolutionTests/Support/GameStateFixture.swift:11` |
| Flag de observación `Sendable` | `PublishFlag` (privado: copiarlo) | `BestHireTests.swift:445-447` |
| Leer un `.xcstrings` o una fuente desde un test | `#filePath` + `URL(fileURLWithPath:)` | `LocalizationCompletenessTests.swift` |
| Contenido real | `try GameContentLoader.load(from: .main)` | idem |
| Plata, pisos, tipos vistos, frontera | `debugGrantCoins()`, `debugUnlockFloors(throughTier:)`, `debugMarkTypesSeen(throughTier:)`, `debugSetMaxTier(_:)` | `GameState+Debug.swift` |
| Skins para tests | `grantMilestoneSkinsForTests(_:)` | `GameState+Debug.swift:62` |
| Fixtures de UI | `--uitest-reset`, `--uitest-skip-tutorial`, `--uitest-coins`, `--uitest-unlock-tower` (pisos hasta el tier 5, piso visible 0), `--uitest-seen-types`, `--uitest-open-sheet`, `--uitest-chest`, `--screenshot-mode` | `GameState.bootstrap` / `+Debug` |
| Esperas de UI | `waitUntilHittable`, `waitForAny`, `waitUntilGone`, `attach` (privados por archivo: copiarlos) | `BottomMenuUITests.swift:167-205` |
| Marcadores de la escena | `app.otherElements["board.units"]`, `["board.floor"]` | `RootView.swift:350-365` |

Los ids de piso reales: `alley` (tiers 1–4), `urban` (5–8), `corporate`, … (`economy.json`).
El tipo base es `homeless`. Los diez pisos tienen capacidad 10 hasta que E2a la pase a 15.

---

### Task 1: El catálogo en formato canónico, con snapshots que se aplican al integrar

**Objetivo:** una herramienta que escribe `Localizable.xcstrings` exactamente como Xcode
(trampa 29) y suma claves desde un snapshot `{"clave": {"es", "en"}}`. Con ella cualquier tarea
puede entregar strings sin ser dueña del catálogo, y el controlador las aplica al integrar sin
un diff de 2.400 líneas. No compila: corre en paralelo con todo.

**Files:**
- Create: `Tools/v2/catalogo.py`
- Create: `Tools/v2/test_catalogo.py`
- Create: `Tools/v2/claves-pendientes/.gitkeep`

**Interfaces:**
- Produces: `Tools/v2/catalogo.py verificar` (exit 0 si los dos catálogos son canónicos) y
  `Tools/v2/catalogo.py aplicar <snapshot.json>…` (suma claves al `Localizable.xcstrings`).
- Produces: en Python, `catalogo.es_canonico(ruta) -> bool`, `catalogo.aplicar(snapshots, ruta)`,
  `catalogo.CATALOGOS`, `catalogo.LOCALIZABLE`.

- [ ] **Step 1: Los tests, en rojo**

`Tools/v2/test_catalogo.py`:

```python
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import catalogo  # noqa: E402


class CatalogoTests(unittest.TestCase):
    def test_los_dos_catalogos_del_repo_son_canonicos(self):
        for ruta in catalogo.CATALOGOS:
            self.assertTrue(catalogo.es_canonico(ruta), f"{ruta.name} no sale igual al reescribirlo")

    def test_aplicar_inserta_en_orden_natural_y_queda_canonico(self):
        with tempfile.TemporaryDirectory() as tmp:
            destino = Path(tmp) / "Localizable.xcstrings"
            destino.write_text(catalogo.LOCALIZABLE.read_text(encoding="utf-8"), encoding="utf-8")
            snapshot = Path(tmp) / "claves.json"
            snapshot.write_text(json.dumps({
                "zz.prueba_10": {"es": "diez", "en": "ten"},
                "zz.prueba_9": {"es": "nueve", "en": "nine"},
            }), encoding="utf-8")

            catalogo.aplicar([snapshot], destino)

            self.assertTrue(catalogo.es_canonico(destino))
            claves = list(json.loads(destino.read_text(encoding="utf-8"))["strings"])
            self.assertLess(claves.index("zz.prueba_9"), claves.index("zz.prueba_10"),
                            "Xcode compara los números como números")
            entrada = json.loads(destino.read_text(encoding="utf-8"))["strings"]["zz.prueba_9"]
            self.assertEqual(entrada["extractionState"], "manual")
            self.assertEqual(entrada["localizations"]["en"]["stringUnit"]["state"], "translated")

    def test_una_clave_igual_se_saltea_y_una_distinta_frena_todo(self):
        with tempfile.TemporaryDirectory() as tmp:
            destino = Path(tmp) / "Localizable.xcstrings"
            original = catalogo.LOCALIZABLE.read_text(encoding="utf-8")
            destino.write_text(original, encoding="utf-8")
            existente = json.loads(original)["strings"]["splash.tip.merge"]["localizations"]
            igual = Path(tmp) / "igual.json"
            igual.write_text(json.dumps({"splash.tip.merge": {
                "es": existente["es"]["stringUnit"]["value"],
                "en": existente["en"]["stringUnit"]["value"],
            }}), encoding="utf-8")
            catalogo.aplicar([igual], destino)
            self.assertEqual(destino.read_text(encoding="utf-8"), original)

            distinta = Path(tmp) / "distinta.json"
            distinta.write_text(json.dumps({"splash.tip.merge": {"es": "otra", "en": "other"}}), encoding="utf-8")
            with self.assertRaises(SystemExit):
                catalogo.aplicar([distinta], destino)
            self.assertEqual(destino.read_text(encoding="utf-8"), original, "no escribe nada si frena")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Verlos fallar**

Run: `python3 -m unittest discover -s Tools/v2 -p 'test_*.py' -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'catalogo'`.

- [ ] **Step 3: La herramienta**

`Tools/v2/catalogo.py` (y `chmod +x`):

```python
#!/usr/bin/env python3
"""El catálogo de strings en el formato canónico de Xcode (HANDOFF §7, trampa 29).

    Tools/v2/catalogo.py verificar
    Tools/v2/catalogo.py aplicar <claves.json> [<claves.json> …]

`verificar` reescribe en memoria los dos catálogos sin cambiarles nada y exige
que salgan byte a byte iguales: es la prueba de que este script escribe el
formato de Xcode (dos espacios, `" : "`, las claves de `strings` en orden
natural, sin salto de línea final). `aplicar` suma las claves de los snapshots
al `Localizable.xcstrings`, y sólo si esa verificación pasa antes.

Un snapshot es {"clave": {"es": "…", "en": "…"}}. Una clave que ya existe con
los mismos textos se saltea; con otros, es un error y no se escribe nada: este
script no pisa traducciones. Los snapshots que esperan integración viven en
`Tools/v2/claves-pendientes/` (PLAN-v2 §0.1).
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LOCALIZABLE = REPO / "FisuEvolution/Resources/Localizable.xcstrings"
CATALOGOS = [LOCALIZABLE, REPO / "FisuEvolution/Resources/InfoPlist.xcstrings"]


def orden_natural(clave):
    # Xcode compara los números como números: `skins_5` va antes que `skins_20`.
    return [int(parte) if parte.isdigit() else parte.lower() for parte in re.split(r"(\d+)", clave)]


def serializar(valor, nivel=0):
    margen = "  " * nivel
    adentro = "  " * (nivel + 1)
    if isinstance(valor, dict):
        if not valor:
            return "{\n\n" + margen + "}"
        # Sólo el diccionario de `strings` (nivel 1) va ordenado; adentro de cada
        # entrada se respeta el orden en que la escribió Xcode.
        claves = sorted(valor, key=orden_natural) if nivel == 1 else list(valor)
        filas = [adentro + json.dumps(c, ensure_ascii=False) + " : " + serializar(valor[c], nivel + 1)
                 for c in claves]
        return "{\n" + ",\n".join(filas) + "\n" + margen + "}"
    if isinstance(valor, list):
        if not valor:
            return "[\n\n" + margen + "]"
        return "[\n" + ",\n".join(adentro + serializar(v, nivel + 1) for v in valor) + "\n" + margen + "]"
    return json.dumps(valor, ensure_ascii=False)


def es_canonico(ruta):
    texto = Path(ruta).read_text(encoding="utf-8")
    return serializar(json.loads(texto)) == texto


def entrada(es, en):
    return {
        "extractionState": "manual",
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "es": {"stringUnit": {"state": "translated", "value": es}},
        },
    }


def textos(existente):
    locs = existente.get("localizations", {})
    return {idioma: locs.get(idioma, {}).get("stringUnit", {}).get("value") for idioma in ("es", "en")}


def aplicar(snapshots, ruta=LOCALIZABLE):
    ruta = Path(ruta)
    if not es_canonico(ruta):
        sys.exit(f"✋ {ruta.name} no está en el formato canónico: no se escribe nada (trampa 29)")
    catalogo = json.loads(ruta.read_text(encoding="utf-8"))
    nuevas = 0
    for snapshot in snapshots:
        for clave, par in json.loads(Path(snapshot).read_text(encoding="utf-8")).items():
            if set(par) != {"es", "en"} or not all(par.values()):
                sys.exit(f"✋ {snapshot}: la clave {clave!r} necesita 'es' y 'en', no vacíos")
            existente = catalogo["strings"].get(clave)
            if existente is None:
                catalogo["strings"][clave] = entrada(par["es"], par["en"])
                nuevas += 1
            elif textos(existente) != par:
                sys.exit(f"✋ {clave!r} ya existe con otro texto: {textos(existente)} contra {par}")
    ruta.write_text(serializar(catalogo), encoding="utf-8")
    print(f"{ruta.name}: {nuevas} claves nuevas")


def main(argumentos):
    if argumentos[:1] == ["verificar"]:
        malos = [r.name for r in CATALOGOS if not es_canonico(r)]
        for r in CATALOGOS:
            print(f"{r.name}: {'NO canónico' if r.name in malos else 'canónico'}")
        return 1 if malos else 0
    if argumentos[:1] == ["aplicar"] and len(argumentos) > 1:
        aplicar(argumentos[1:])
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

Y `Tools/v2/claves-pendientes/.gitkeep` vacío (la carpeta existe aunque no haya pendientes).

- [ ] **Step 4: Verde**

Run: `python3 -m unittest discover -s Tools/v2 -p 'test_*.py' -v`
Expected: `Ran 3 tests … OK`.
Run: `Tools/v2/catalogo.py verificar`
Expected: `Localizable.xcstrings: canónico` y `InfoPlist.xcstrings: canónico`, exit 0.
Run: `git status --short` → sólo los tres archivos nuevos (los tests escriben en un temporal).

- [ ] **Step 5: Commit**

```bash
git add Tools/v2/catalogo.py Tools/v2/test_catalogo.py Tools/v2/claves-pendientes/.gitkeep
git diff --cached --stat
git commit -m "chore(v2): el catálogo de strings en formato canónico, con snapshots para integrar"
```

---

### Task 2: Ola 0 — los spikes de la pantalla (S1, S4, S5, S6)

**Objetivo:** contestar con medición, antes de construir, las cuatro preguntas de las que
dependen las constantes de este plan. **No se commitea código de producto**: cada spike se
hace en el worktree de la tarea, se mide, se descarta (`git checkout -- .` + `git clean -fd`
de lo agregado) y se **reporta al controlador**, que lo asienta en la sesión. Si un spike
cambia una constante, la tarea que la usa la toma del reporte (el controlador la pasa en el
despacho). Corre en paralelo con E3b T1 (S2, S3).

**Files:** ninguno commiteado. Capturas y logs en `build/spikes-e3a/` (fuera de git).

- [ ] **Step 1: S1 — las hojas en iPad (mini y 13", runtimes 18.6 y 26.5)**

Pregunta: con `TARGETED_DEVICE_FAMILY "1,2"` + `UIRequiresFullScreen`, ¿una hoja con
`.presentationSizing(.page)` + `.presentationBackground(.clear)` mide al menos 640 pt de ancho y
deja ver el juego atenuado detrás, en los cuatro casos? ¿Y en iPhone queda igual que hoy (los
detents `.fraction` de los popups siguen mandando)?

Cómo:
1. Aplicar localmente los cambios de `project.yml` de la Task 5 (sin commit).
2. En `RootView.swift:324` cambiar `.presentationBackground(.clear)` por
   `.presentationSizing(.page).presentationBackground(.clear)`; lo mismo en
   `OfflineEarningsView.swift:153`.
3. Correr en `iPad mini (A17 Pro)` y `iPad Pro 13-inch (M4)` con 18.6 y 26.5, y en
   `iPhone 16 Pro` 26.5: `--uitest-reset --uitest-skip-tutorial --uitest-coins`, tocar
   `hud.upgrades`, capturar; `--uitest-offline`, capturar.
4. Medir con un test de UI descartable el `frame` de `sheet.close` y de `upgrades.tab.permanent`
   (el ancho de la hoja ≈ distancia entre el borde izquierdo del contenido y la X).

Criterio de salida: ancho de la hoja ≥ 640 pt y fondo transparente en los cuatro iPad;
iPhone idéntico a las capturas actuales. **Si falla** (hoja angosta u opaca): plan B de la spec,
`fullScreenCover` con `.presentationBackground(.clear)` y un velo propio
(`Color.black.opacity(0.35)`) — el controlador ajusta la Task 6 antes de despacharla.

- [ ] **Step 2: S4 — safe areas reactivas**

Pregunta: una `UIView` sonda (`didMoveToWindow`, `layoutSubviews`, `safeAreaInsetsDidChange`)
que lee `window.safeAreaInsets`, ¿da los valores de la pantalla desde el primer frame y no
dispara avisos de "Modifying state during view update"?

Cómo: el `ScreenInsetsReader` de la Task 4 pegado como `.background` de `HUDView`, con un
`print` del par (top, bottom) en cada publicación. Medir en iPhone SE 3 (esperado 0/0),
16 Pro (62/34), iPad mini y iPad Pro 13" (≈24/20), runtime 26.5. Mirar la consola de Xcode o
`xcrun simctl spawn <udid> log stream --predicate 'process == "FisuEvolution"'`.

Criterio: los cuatro pares correctos, a lo sumo dos publicaciones por arranque y ningún aviso.
**Si aparece el aviso:** la publicación pasa a `Task { @MainActor in … }` (un runloop de demora;
el valor inicial 44/34 cubre ese frame). La Task 4 lo trae escrito así como alternativa.

- [ ] **Step 3: S5 — el tablero con 15 lugares, medido en el iPhone SE**

Pregunta: con 3 filas y el techo de la multitud al 70 % del alto, ¿la multitud entra en el SE
sin taparse con el HUD, la botonera (display arriba a la derecha) ni la columna izquierda que
traerá E7b (Ruleta/Colchón/Paquetes/Boost, ~56 pt de ancho)? ¿Hace falta que los personajes
dejen de deambular por debajo de las columnas?

Cómo:
1. Localmente, `economy.json` → `"capacity": 15` en los diez pisos, `BoardScene.layoutBoard()`
   con `boardRows = 3` y `crowdTopRatio = 0.70`.
2. Dibujar en `RootView` dos rectángulos de referencia semitransparentes: 56 × 260 pt pegado al
   borde izquierdo desde `y = 160` (la columna de E7b) y 156 × 44 pt arriba a la derecha bajo el
   HUD (el display).
3. Capturas con `--uitest-reset --uitest-skip-tutorial --uitest-unlock-tower` y diez
   contrataciones (`hud.quickhire` × 10 con `--uitest-coins`) en SE 3, 16 Pro, 16 Pro Max y
   iPad Pro 13".

Criterio y reporte: (a) el `crowdTopRatio` para 3 filas que deja la fila de atrás debajo del
display (esperado 0,70; el reporte trae el número medido); (b) si las columnas caen sobre la
franja de la multitud. **Supuesto del plan:** las columnas van por encima de la franja (la de
E7b en el tercio superior), así que `PlayLayout` no reserva márgenes laterales y el golden de
iPhone se mantiene; si S5 mide solape, se anota para E7b (que agrega el margen a `PlayLayout`)
y se lleva al dueño (ver "Para el dueño", punto 2).

- [ ] **Step 4: S6 — la botonera sobre el tablero, sin robarle el gesto**

Pregunta: una vista SwiftUI encima del `SpriteView` (el display de 156 × 44 y, desplegada, una
grilla de 2 × 5 botones de 34 pt), ¿deja pasar el deslizamiento vertical del tablero cuando el
dedo arranca fuera de sus botones? ¿Y la grilla desplegada entra en el SE entre el HUD y la
franja de la multitud?

Cómo: el `ElevatorPanel` de la Task 8 (o un prototipo con la misma jerarquía) montado como
overlay del HUD; en el SE y el 16 Pro, deslizar sobre el tablero a 10 pt del panel, arrancar un
deslizamiento sobre el display, tocar el display, tocar un botón. Contar en `board.floor` los
cambios de piso.

Criterio: el deslizamiento que arranca fuera de los controles cambia de piso igual que hoy;
el que arranca sobre el display no cambia de piso ni tapea el tablero; la grilla desplegada no
pasa del 50 % del alto del SE. **Si la grilla no entra**, se achica a botones de 30 pt.

- [ ] **Step 5: El reporte al controlador**

Un mensaje con, por spike: la respuesta (sí/no), los números medidos, las rutas de las
capturas en `build/spikes-e3a/` y qué constante del plan cambia (si alguna). Sin commit.

---

### Task 3: `PlayLayout` — la geometría del tablero, pura y con el golden de iPhone

**Objetivo:** un tipo puro que, dada la pantalla y la capacidad del piso, dice filas, columnas,
celda, origen del campo, escala de texto y alto de la multitud. En iPhone con 10 lugares da
**exactamente** la geometría de hoy; en pantallas anchas topea la celda en 112 pt y centra el
campo; con 15 lugares arma 3 filas. Todavía no lo usa nadie (la escena lo adopta en la Task 10),
así que no toca ningún archivo caliente.

**Files:**
- Create: `FisuEvolution/Scenes/PlayLayout.swift`
- Create: `FisuEvolutionTests/PlayLayoutTests.swift`

**Interfaces:**
- Produces: `struct PlayLayout: Equatable` con `init(size: CGSize, capacity: Int)`, propiedades
  `rows: Int`, `columns: Int`, `cellSize: CGFloat`, `fieldX: CGFloat`, `fieldWidth: CGFloat`,
  `textScale: CGFloat`, `crowdTopRatio: CGFloat`, `marker: String`; estáticos `phoneMaxWidth`
  (440), `maxCellSize` (112), `horizontalInset` (16), `slotsPerRow` (5), `wideTextScale`
  (1,25), `revealMaxSide` (380), `rows(forCapacity:) -> Int`, `crowdTopRatio(rows:) -> CGFloat`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/PlayLayoutTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import FisuEvolution

/// La geometría del tablero en cualquier pantalla (PLAN-v2 E3).
///
/// ⚠️ `iPhoneIsTheV1Layout` es el golden: escribe a mano los números de la v1
/// (dos filas, cinco columnas, la celda al ancho y el campo a 16 pt del borde).
/// Si se pone rojo, cambió el juego en todos los iPhone.
@Suite("PlayLayout: el tablero en cualquier pantalla")
struct PlayLayoutTests {
    /// Los seis iPhone que soporta la app, del más chico al más grande.
    static let phones: [CGSize] = [
        CGSize(width: 320, height: 568),
        CGSize(width: 375, height: 667),
        CGSize(width: 390, height: 844),
        CGSize(width: 402, height: 874),
        CGSize(width: 430, height: 932),
        CGSize(width: 440, height: 956),
    ]

    /// Los dos iPad y dos ventanas que no son de ningún dispositivo: con el SDK
    /// de iOS 27 `UIRequiresFullScreen` se ignora y la app puede vivir en una.
    static let wide: [CGSize] = [
        CGSize(width: 744, height: 1133),
        CGSize(width: 1032, height: 1376),
        CGSize(width: 500, height: 800),
        CGSize(width: 700, height: 1000),
    ]

    @Test("en iPhone, con 10 lugares, es exactamente el layout de la v1", arguments: phones)
    func iPhoneIsTheV1Layout(size: CGSize) {
        let layout = PlayLayout(size: size, capacity: 10)
        #expect(layout.rows == 2)
        #expect(layout.columns == 5)
        #expect(abs(layout.cellSize - (size.width - 32) / 5) < 0.001)
        #expect(abs(layout.fieldX - 16) < 0.001)
        #expect(layout.textScale == 1)
        #expect(layout.crowdTopRatio == 0.44)
    }

    @Test("en pantallas anchas la celda tiene tope y el campo va centrado", arguments: wide)
    func wideScreensCapTheCellAndCenterTheField(size: CGSize) {
        let layout = PlayLayout(size: size, capacity: 10)
        #expect(layout.cellSize <= PlayLayout.maxCellSize)
        #expect(layout.fieldX >= PlayLayout.horizontalInset - 0.001)
        #expect(abs(layout.fieldX * 2 + layout.fieldWidth - size.width) < 0.001, "centrado")
        #expect(layout.textScale == PlayLayout.wideTextScale)
    }

    /// El sprite mide ~2 celdas (`CharacterNode`): con el tope, en el iPad 13"
    /// ocupa la misma fracción del alto que en el 16 Pro.
    @Test("en el iPad 13\" el personaje ocupa el 16,5 % del alto, como en el 16 Pro")
    func iPadCharacterMatchesTheSixteenPro() {
        let ipad = PlayLayout(size: CGSize(width: 1032, height: 1376), capacity: 10)
        let phone = PlayLayout(size: CGSize(width: 402, height: 874), capacity: 10)
        let ipadShare = ipad.cellSize * 2 / 1376
        let phoneShare = phone.cellSize * 2 / 874
        #expect(abs(ipadShare - 0.165) < 0.005)
        #expect(abs(ipadShare - phoneShare) < 0.01)
    }

    @Test("la capacidad decide las filas: 10 son dos, 15 son tres y 20 son cuatro",
          arguments: [(10, 2, 5), (15, 3, 5), (20, 4, 5), (8, 2, 4), (5, 2, 3), (1, 2, 1)])
    func capacityDrivesTheRows(capacity: Int, rows: Int, columns: Int) {
        let layout = PlayLayout(size: CGSize(width: 402, height: 874), capacity: capacity)
        #expect(layout.rows == rows)
        #expect(layout.columns == columns)
    }

    @Test("la multitud: 0,44 del alto con dos filas (la v1) y 0,70 con tres o más")
    func crowdHeightFollowsTheRows() {
        #expect(PlayLayout.crowdTopRatio(rows: 2) == 0.44)
        #expect(PlayLayout.crowdTopRatio(rows: 3) == 0.70)
        #expect(PlayLayout.crowdTopRatio(rows: 4) == 0.70)
    }

    @Test("el tope de la foto del reveal nunca se alcanza en iPhone")
    func revealCapIsInvisibleOnPhones() {
        // `BoardScene.revealLayout` usa `min(ancho × 0,82, alto × 0,52)`: en el
        // iPhone más ancho eso da 360,8, por debajo del tope.
        #expect(440 * 0.82 < PlayLayout.revealMaxSide)
    }

    @Test("el marcador del test de UI dice columnas, filas, celda y escala")
    func markerFormat() {
        #expect(PlayLayout(size: CGSize(width: 1032, height: 1376), capacity: 15).marker == "5x3@112·1.25")
        #expect(PlayLayout(size: CGSize(width: 402, height: 874), capacity: 10).marker == "5x2@74·1.0")
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/PlayLayoutTests`.
Expected: no compila — `cannot find 'PlayLayout' in scope`.

- [ ] **Step 3: La implementación**

`FisuEvolution/Scenes/PlayLayout.swift`:

```swift
import CoreGraphics

/// La geometría del tablero para una pantalla y un piso (PLAN-v2 E3).
///
/// Pura y sin SpriteKit: la escena la pide en `layoutBoard()` y los tests la
/// pinean sin levantar una escena. Junta lo que vivía suelto en `BoardScene`
/// —filas, columnas, celda, origen del campo— y suma lo del iPad: la celda con
/// tope y el campo centrado.
///
/// ⚠️ **En iPhone (ancho ≤ 440) y con 10 lugares da exactamente la v1**: dos
/// filas, cinco columnas, la celda al ancho y el campo a 16 pt del borde. Lo
/// pinea `PlayLayoutTests.iPhoneIsTheV1Layout`.
struct PlayLayout: Equatable {
    /// Hasta este ancho la pantalla es un teléfono (el 16/17 Pro Max mide 440).
    static let phoneMaxWidth: CGFloat = 440
    /// Tope de la celda. El sprite mide ~2 celdas: en el iPad 13" queda en
    /// ~224 pt, el 16,5 % del alto, como en el 16 Pro.
    static let maxCellSize: CGFloat = 112
    /// Margen lateral mínimo del campo.
    static let horizontalInset: CGFloat = 16
    /// Lugares por fila: 10 son dos filas, 15 son tres y 20 son cuatro.
    static let slotsPerRow = 5
    /// Los textos de SpriteKit en pantallas anchas.
    static let wideTextScale: CGFloat = 1.25
    /// Tope del lado de la foto del reveal. En iPhone no se alcanza nunca.
    static let revealMaxSide: CGFloat = 380

    let rows: Int
    let columns: Int
    let cellSize: CGFloat
    /// Borde izquierdo del campo, en coordenadas de escena.
    let fieldX: CGFloat
    let textScale: CGFloat
    /// Techo de la franja de la multitud, en fracción del alto de pantalla.
    let crowdTopRatio: CGFloat

    var fieldWidth: CGFloat { CGFloat(columns) * cellSize }

    init(size: CGSize, capacity: Int) {
        let rows = Self.rows(forCapacity: capacity)
        let columns = max(1, (capacity + rows - 1) / rows)
        let available = max(1, size.width - Self.horizontalInset * 2)
        let cell = min(available / CGFloat(columns), Self.maxCellSize)
        self.rows = rows
        self.columns = columns
        self.cellSize = cell
        self.fieldX = (size.width - CGFloat(columns) * cell) / 2
        self.textScale = size.width > Self.phoneMaxWidth ? Self.wideTextScale : 1
        self.crowdTopRatio = Self.crowdTopRatio(rows: rows)
    }

    /// Dos filas hasta 10 lugares (la v1) y una fila más cada cinco.
    static func rows(forCapacity capacity: Int) -> Int {
        max(2, (capacity + slotsPerRow - 1) / slotsPerRow)
    }

    /// El knob del alto de la multitud. Con dos filas sigue en el 0,44 de la v1;
    /// con tres o más sube al ~70 % que pidió la crítica de Marco (PLAN-v2 §2).
    static func crowdTopRatio(rows: Int) -> CGFloat {
        rows <= 2 ? 0.44 : 0.70
    }

    /// Lo que publica el marcador `board.layout`: "5x3@112·1.25".
    var marker: String {
        "\(columns)x\(rows)@\(Int(cellSize.rounded()))·\(textScale)"
    }
}
```

Si el reporte de S5 (Task 2) trajo otro techo para 3 filas, se usa ése en
`crowdTopRatio(rows:)` y en su test.

- [ ] **Step 4: Verde**

Run: Receta R con `-only-testing:FisuEvolutionTests/PlayLayoutTests`.
Expected: PASS, nombrando los 7 tests (y los 10 + 6 casos parametrizados). Después
`Tools/v2/oraculo.sh rapido` → `VERDE` con la cuenta de unit +7.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Scenes/PlayLayout.swift FisuEvolutionTests/PlayLayoutTests.swift
git diff --cached --stat
git commit -m "feat(ux): PlayLayout, la geometría del tablero pura y con el golden de iPhone"
```

---

### Task 4: `ScreenInsets` y `PlayColumn` — el chrome deja de leer la safe area una vez

**Objetivo:** las dos lecturas estáticas de la safe area (`HUDView` y `GameTabBar`, en su
`onAppear`) pasan a un objeto observable que una sonda mantiene al día, y el chrome (la fila
del HUD, la barra de abajo y las tarjetas del tutorial) se mete en una columna centrada: 592 pt
para el HUD y la barra, 520 para las tarjetas. En iPhone no cambia nada (la columna es más
ancha que la pantalla y los insets son los mismos).

**Files:**
- Create: `FisuEvolution/UI/ScreenInsets.swift`
- Create: `FisuEvolution/UI/PlayColumn.swift`
- Modify: `FisuEvolution/UI/HUD/HUDView.swift` (`windowTopInset`, `minimumTopGap`, `mainBarTopPadding`, `screenTopSafeArea`, `body`)
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (`GameTabBar`: `windowBottomInset`, `bottomGap`, `bottomFloor`, `screenBottomSafeArea`, `body`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialOverlay.swift` (`card(_:hole:screen:)`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialTipView.swift` (`balloon(_:anchor:screen:)`)
- Create: `FisuEvolutionTests/ScreenInsetsTests.swift`

**Interfaces:**
- Produces: `@MainActor @Observable final class ScreenInsets` con `static let shared`,
  `private(set) var top: CGFloat` (44 de arranque), `private(set) var bottom: CGFloat` (34),
  `init(top:bottom:)`, `func update(top:bottom:)` (escribe sólo si cambió) y
  `static func floorGap(minimum: CGFloat, inset: CGFloat) -> CGFloat`.
- Produces: `struct ScreenInsetsReader: UIViewRepresentable` (la sonda).
- Produces: `enum PlayColumn { static let maxWidth: CGFloat = 592; static let tutorialCardMaxWidth: CGFloat = 520 }`
  y `extension View { func playColumn() -> some View }`.
- Consumes: nada nuevo.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/ScreenInsetsTests.swift`:

```swift
import CoreGraphics
import Observation
import Testing
@testable import FisuEvolution

/// Las safe areas de la pantalla, observables (PLAN-v2 E3). La sonda que las
/// lee de la ventana se mide en el spike S4 y en `IPadLayoutUITests`; acá se
/// pinea el contrato del objeto.
@Suite("ScreenInsets")
@MainActor
struct ScreenInsetsTests {
    /// `withObservationTracking` pide un `@Sendable` y bajo concurrencia
    /// estricta un `var` capturado no compila (patrón de `BestHireTests`).
    private final class PublishFlag: @unchecked Sendable {
        var published = false
    }

    @Test("arranca con los insets de un teléfono con notch, para no saltar en el primer frame")
    func startsWithNotchDefaults() {
        let insets = ScreenInsets()
        #expect(insets.top == 44)
        #expect(insets.bottom == 34)
    }

    @Test("publica sólo cuando el valor cambia")
    func publishesOnlyOnChange() {
        let insets = ScreenInsets()
        insets.update(top: 62, bottom: 34)

        let quiet = PublishFlag()
        withObservationTracking { _ = insets.top; _ = insets.bottom } onChange: { quiet.published = true }
        insets.update(top: 62, bottom: 34)
        #expect(!quiet.published, "la sonda corre en cada layout: repetir el valor no puede invalidar")

        let moved = PublishFlag()
        withObservationTracking { _ = insets.top; _ = insets.bottom } onChange: { moved.published = true }
        insets.update(top: 0, bottom: 0)
        #expect(moved.published)
    }

    @Test("el aire contra el bezel sólo entra cuando el inset es chico",
          arguments: [(0, 12), (34, 0), (12, 0), (5, 7)] as [(CGFloat, CGFloat)])
    func floorGap(inset: CGFloat, expected: CGFloat) {
        #expect(ScreenInsets.floorGap(minimum: 12, inset: inset) == expected)
    }

    @Test("la columna del chrome es más ancha que cualquier iPhone")
    func playColumnNeverTouchesAPhone() {
        #expect(PlayColumn.maxWidth > PlayLayout.phoneMaxWidth)
        #expect(PlayColumn.tutorialCardMaxWidth > PlayLayout.phoneMaxWidth)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/ScreenInsetsTests`.
Expected: no compila — `cannot find 'ScreenInsets' in scope`.

- [ ] **Step 3: `ScreenInsets` y la sonda**

`FisuEvolution/UI/ScreenInsets.swift`:

```swift
import SwiftUI
import UIKit

/// Las safe areas de la PANTALLA, observables (PLAN-v2 E3).
///
/// Reemplaza las dos lecturas que `HUDView` y `GameTabBar` hacían en su
/// `onAppear`: eran una foto del arranque, y en iPad —o con el SDK de iOS 27,
/// cuando la app deje de ser de pantalla completa— el inset puede cambiar en
/// pleno juego.
///
/// ⚠️ Se sigue leyendo de la ventana y no con un `GeometryReader`: adentro del
/// juego la safe area ya la consumió `RootView`, y un proxy reporta 0 en todos
/// los teléfonos.
@MainActor
@Observable
final class ScreenInsets {
    static let shared = ScreenInsets()

    /// Arrancan en los de un teléfono con notch: el valor real llega con el
    /// primer layout de la sonda, y arrancar en 0 haría saltar el HUD 12 pt en
    /// el caso común.
    private(set) var top: CGFloat
    private(set) var bottom: CGFloat

    init(top: CGFloat = 44, bottom: CGFloat = 34) {
        self.top = top
        self.bottom = bottom
    }

    func update(top: CGFloat, bottom: CGFloat) {
        if self.top != top { self.top = top }
        if self.bottom != bottom { self.bottom = bottom }
    }

    /// Cuánto aire agregar para que algo pegado a un borde físico no quede a
    /// menos de `minimum` del bezel cuando el inset de ese borde es chico (en el
    /// SE, con la barra de estado oculta, los dos son 0).
    nonisolated static func floorGap(minimum: CGFloat, inset: CGFloat) -> CGFloat {
        max(0, minimum - inset)
    }
}

/// La sonda que mantiene al día `ScreenInsets.shared`: una `UIView` invisible
/// que copia los insets de su ventana en cada pasada de layout. Va UNA vez, de
/// fondo del HUD, que está montado siempre que hay tablero.
struct ScreenInsetsReader: UIViewRepresentable {
    func makeUIView(context: Context) -> Probe {
        let probe = Probe()
        probe.isUserInteractionEnabled = false
        probe.isAccessibilityElement = false
        return probe
    }

    func updateUIView(_ uiView: Probe, context: Context) {}

    final class Probe: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            publish()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            publish()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            publish()
        }

        private func publish() {
            guard let window else { return }
            ScreenInsets.shared.update(top: window.safeAreaInsets.top, bottom: window.safeAreaInsets.bottom)
        }
    }
}
```

Si el spike S4 midió el aviso "Modifying state during view update", `publish()` queda:

```swift
        private func publish() {
            guard let window else { return }
            let insets = window.safeAreaInsets
            Task { @MainActor in ScreenInsets.shared.update(top: insets.top, bottom: insets.bottom) }
        }
```

`FisuEvolution/UI/PlayColumn.swift`:

```swift
import SwiftUI

/// La columna del chrome en pantallas anchas (PLAN-v2 E3): el HUD, la barra de
/// pestañas, la fila del atajo y la barra de bonus no pasan de 592 pt y van
/// centrados; los fondos de los paneles siguen a sangre, así que en iPad no
/// queda ninguna barra. En iPhone la columna es más ancha que la pantalla y no
/// cambia nada.
enum PlayColumn {
    static let maxWidth: CGFloat = 592
    /// Las tarjetas del tutorial, que flotan solas y se leen mejor angostas.
    static let tutorialCardMaxWidth: CGFloat = 520
}

extension View {
    /// El contenido en la columna, centrado. El fondo que se le ponga DESPUÉS
    /// ocupa el ancho entero.
    func playColumn() -> some View {
        frame(maxWidth: PlayColumn.maxWidth)
            .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 4: El HUD y la barra leen `ScreenInsets`, en la columna**

En `HUDView.swift`:
1. Borrar `@State private var windowTopInset: CGFloat = 44` (`:24-31`) y
   `screenTopSafeArea` (`:73-93`) con sus docstrings.
2. Reemplazar el docstring de `minimumTopGap` (`:33-39`) y `mainBarTopPadding` (`:42-50`) por:

```swift
    /// Aire mínimo entre el borde FÍSICO de arriba y la fila principal. Sólo
    /// entra cuando la safe area de arriba se desploma: en el SE, con la barra de
    /// estado oculta, es 0 y la fila se iría contra el bezel.
    private static let minimumTopGap: CGFloat = 14

    /// Cuánto baja la fila principal desde el borde de la safe area: el 2 del
    /// diseño, o lo que haga falta para respetar `minimumTopGap`.
    private var mainBarTopPadding: CGFloat {
        max(2, ScreenInsets.floorGap(minimum: Self.minimumTopGap, inset: ScreenInsets.shared.top))
    }
```

3. En `body`, el `mainBar` pasa por la columna y la sonda queda de fondo:

```swift
    var body: some View {
        VStack(spacing: Tokens.s4) {
            mainBar
                .padding(.horizontal, Tokens.s12)
                .padding(.top, mainBarTopPadding)
                .padding(.bottom, Tokens.s12)
                .playColumn()
                .background { topPanel }
            prestigeIndicator
        }
        .background(ScreenInsetsReader().accessibilityHidden(true))
        .sheet(isPresented: $showFloorMap) {
            FloorMapView()
                .presentationBackground(.clear)
        }
        .tutorialAnchor(.hudBar)
    }
```

(el `.onAppear { windowTopInset = … }` se va con la propiedad; el comentario de la hoja del mapa
se conserva).

En `GameArtComponents.swift`, `GameTabBar`:
1. Borrar `@State private var windowBottomInset` (`:995-1002`) y `screenBottomSafeArea`
   (`:1073-1086`) con sus docstrings, y el `.onAppear { windowBottomInset = … }` del `body`.
2. Reemplazar `bottomGap` y `bottomFloor`:

```swift
    /// Aire mínimo entre los nombres de los tabs y el borde FÍSICO de abajo. Sólo
    /// entra sin home indicator (SE): con él, el inset ya pone 34.
    private static let minimumBottomGap: CGFloat = 12
    private var bottomGap: CGFloat {
        ScreenInsets.floorGap(minimum: Self.minimumBottomGap, inset: ScreenInsets.shared.bottom)
    }

    /// Cuánto SUBE la barra por el piso de arriba, para lo que se apoye sobre
    /// ella (los dos toasts de `RootView`, que cuentan desde la safe area).
    @MainActor static var bottomFloor: CGFloat {
        ScreenInsets.floorGap(minimum: minimumBottomGap, inset: ScreenInsets.shared.bottom)
    }
```

3. En `body`, `.frame(maxWidth: .infinity)` (`:1109`) pasa a `.playColumn()`.

- [ ] **Step 5: Las tarjetas del tutorial, a 520**

En `TutorialOverlay.card(_:hole:screen:)`, entre el `TutorialCard(…)` y su
`.padding(.horizontal, 14)`:

```swift
            .frame(maxWidth: PlayColumn.tutorialCardMaxWidth)
```

En `TutorialTipView.balloon(_:anchor:screen:)`, entre el `TipBalloon(…)` y su
`.padding(.horizontal, 16)`, la misma línea.

- [ ] **Step 6: Verde y oráculo**

Run: Receta R con `-only-testing:FisuEvolutionTests/ScreenInsetsTests` → PASS (4 tests, 4
casos). Después `-only-testing:FisuEvolutionUITests/HUDRedesignUITests` y
`-only-testing:FisuEvolutionUITests/TutorialUITests` → PASS sin cambios (el HUD y el tutorial
miden igual en iPhone). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/UI/ScreenInsets.swift FisuEvolution/UI/PlayColumn.swift \
  FisuEvolution/UI/HUD/HUDView.swift FisuEvolution/UI/Art/GameArtComponents.swift \
  FisuEvolution/UI/Tutorial/TutorialOverlay.swift FisuEvolution/UI/Tutorial/TutorialTipView.swift \
  FisuEvolutionTests/ScreenInsetsTests.swift
git diff --cached --stat
git commit -m "feat(ux): las safe areas observables y el chrome en una columna centrada"
```

---

### Task 5: Universal — iPhone y iPad vertical, iOS 18 y el contrato del Info.plist

**Objetivo:** la app pasa a universal (iPad sólo vertical, de pantalla completa), el mínimo sube
a iOS 18, se retira el camino iOS 17 de `clearNavigationBackdrop`, la pantalla de lanzamiento
es crema, y un test pinea el contrato del Info.plist compilado — incluido uno que se pone rojo
**a propósito** el día que se compile con el SDK de iOS 27, que ignora `UIRequiresFullScreen`.

**Files:**
- Modify: `project.yml` (`options.deploymentTarget`, `settings.base`, target `FisuEvolution`)
- Modify: `FisuEvolution/Info.plist` (`UILaunchScreen`)
- Modify: `FisuEvolution/UI/Art/PanelFrames.swift` (`clearNavigationBackdrop`, borrar `LegacyClearNavigationBackdrop`)
- Create: `FisuEvolutionTests/InfoPlistContractTests.swift`

**Interfaces:**
- Produces: `MinimumOSVersion` 18.0, `UIDeviceFamily` [1, 2], `UIRequiresFullScreen`,
  `UISupportedInterfaceOrientations~ipad` = Portrait. Habilita las APIs de iOS 18 sin
  `#available` (`presentationSizing`, `containerBackground(for: .navigation)`), que usan T6 y E3b.

- [ ] **Step 1: El test, en rojo**

`FisuEvolutionTests/InfoPlistContractTests.swift`:

```swift
import Foundation
import Testing
@testable import FisuEvolution

/// El contrato del Info.plist COMPILADO (PLAN-v2 E3, iPad): universal, vertical,
/// de pantalla completa, iOS 18 y la pantalla de lanzamiento crema.
///
/// Lee `Bundle.main` —el host de los unit tests es la app— y no `project.yml`:
/// la trampa de siempre de este repo es una clave puesta como build setting que
/// no llega al Info.plist (ver `UIStatusBarHidden` en `project.yml`).
@Suite("El contrato del Info.plist")
struct InfoPlistContractTests {
    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    @Test("la app es universal: iPhone y iPad")
    func universal() {
        #expect(info["UIDeviceFamily"] as? [Int] == [1, 2])
    }

    @Test("sólo vertical, en iPhone y en iPad")
    func portraitOnly() {
        #expect(info["UISupportedInterfaceOrientations"] as? [String] == ["UIInterfaceOrientationPortrait"])
        #expect(info["UISupportedInterfaceOrientations~ipad"] as? [String] == ["UIInterfaceOrientationPortrait"])
    }

    /// Sin esta clave, Apple pide las cuatro orientaciones a toda app con iPad
    /// (error 90474 en Validate) y el tablero sólo funciona vertical.
    @Test("de pantalla completa: no participa del multitasking del iPad")
    func requiresFullScreen() {
        #expect(info["UIRequiresFullScreen"] as? Bool == true)
    }

    @Test("iOS 18 como mínimo")
    func minimumOS() {
        #expect(info["MinimumOSVersion"] as? String == "18.0")
    }

    @Test("la pantalla de lanzamiento es crema, no blanca")
    func creamLaunchScreen() {
        let launch = info["UILaunchScreen"] as? [String: Any]
        #expect(launch?["UIColorName"] as? String == "PaletteCream")
    }

    /// ⚠️ **Rojo a propósito el día que se compile con el SDK de iOS 27.** Ese SDK
    /// ignora `UIRequiresFullScreen`: vuelve el error 90474 y la app pasa a poder
    /// vivir en ventanas de cualquier tamaño. Antes de subir de SDK hay que
    /// decidir (landscape, "sólo iPhone" o ventanas) y recién ahí tocar este test.
    @Test("el SDK con el que se compila todavía respeta UIRequiresFullScreen")
    func theSDKStillHonorsFullScreen() throws {
        let sdk = try #require(info["DTSDKName"] as? String, "el Info.plist compilado no trae DTSDKName")
        let digits = sdk.drop { !$0.isNumber }.prefix { $0.isNumber }
        let major = try #require(Int(digits), "no entiendo el SDK \(sdk)")
        #expect(major < 27, "SDK \(sdk): UIRequiresFullScreen ya no rige — ver PLAN-v2 §2, iPad")
    }
}
```

- [ ] **Step 2: Verlo fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/InfoPlistContractTests`.
Expected: FAIL en `universal` (`[1]`), `portraitOnly` (la clave de iPad no existe),
`requiresFullScreen` (`nil`), `minimumOS` (`"17.0"`) y `creamLaunchScreen` (`nil`); PASS en
`theSDKStillHonorsFullScreen` (`iphonesimulator26.5`). Si ése también falla por `DTSDKName`
ausente, anotarlo en el reporte: el test pasa a leer `DTPlatformVersion`.

- [ ] **Step 3: `project.yml`**

1. `options.deploymentTarget.iOS: "18.0"` (`:6`).
2. En `settings.base`: `IPHONEOS_DEPLOYMENT_TARGET: "18.0"` y `TARGETED_DEVICE_FAMILY: "1,2"`.
3. En el target `FisuEvolution`, borrar `INFOPLIST_KEY_UILaunchScreen_Generation: YES` (`:76`)
   y reemplazar el bloque de `TARGETED_DEVICE_FAMILY: "1"` con su comentario (`:79-101`; la
   línea de `INFOPLIST_KEY_UISupportedInterfaceOrientations` de `:77` queda como está) por:

```yaml
        # Universal desde la 2.0 (PLAN-v2 E3, decisión del dueño): iPhone y iPad,
        # SÓLO VERTICAL. Va acá en el target además de en `settings.base`:
        # medido con `xcodebuild -showBuildSettings`, el target no hereda el de
        # base (así fue como la 1.0 salió `1,2` sin quererlo).
        #
        # Lo que permite un iPad vertical es `UIRequiresFullScreen`: la app no
        # participa del multitasking y Apple deja de pedir las cuatro
        # orientaciones (el error 90474 que rechazó la 1.0 en Validate).
        # ⚠️ La clave está DEPRECADA y el SDK de iOS 27 la ignora al compilar:
        # ese día vuelve el 90474. Lo vigila
        # `InfoPlistContractTests.theSDKStillHonorsFullScreen`, rojo a propósito.
        TARGETED_DEVICE_FAMILY: "1,2"
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: UIInterfaceOrientationPortrait
        INFOPLIST_KEY_UIRequiresFullScreen: YES
```

- [ ] **Step 4: La pantalla de lanzamiento crema en `Info.plist`**

Antes de `<key>GADApplicationIdentifier</key>`:

```xml
	<!-- La pantalla de lanzamiento: crema, el fondo del splash, para que el
	     primer cuadro no sea blanco (PLAN-v2 E3). Va acá y no como
	     `INFOPLIST_KEY_UILaunchScreen_Generation`, que genera el diccionario
	     VACÍO: la whitelist de Xcode no tiene clave para el color. -->
	<key>UILaunchScreen</key>
	<dict>
		<key>UIColorName</key>
		<string>PaletteCream</string>
	</dict>
```

- [ ] **Step 5: Fuera el camino iOS 17 de `clearNavigationBackdrop`**

En `PanelFrames.swift`, el bloque "Telón de las vistas empujadas" (`:255-305`) queda:

```swift
// MARK: - Telón de las vistas empujadas

/// El telón transparente de una vista EMPUJADA en el `NavigationStack` del
/// menú. Las hojas flotan sobre el juego atenuado porque se presentan
/// transparentes, pero al empujar UIKit le pinta `systemBackground` al destino
/// y la franja que el panel deja a la vista se veía blanca.
extension View {
    /// Aplicar sobre el CONTENIDO de un `navigationDestination`.
    func clearNavigationBackdrop() -> some View {
        containerBackground(.clear, for: .navigation)
    }
}
```

(se borra `LegacyClearNavigationBackdrop` entero).

- [ ] **Step 6: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`, Receta R con
`-only-testing:FisuEvolutionTests/InfoPlistContractTests` → PASS (6). Verificar a mano el
compilado: `plutil -p "$WT/build/DD-e3/Build/Products/Debug-iphonesimulator/FisuEvolution.app/Info.plist" | grep -E 'UIDeviceFamily|UIRequiresFullScreen|UILaunchScreen|MinimumOSVersion' -A2`.
Correr `-only-testing:FisuEvolutionUITests/MenuUITests` (las vistas empujadas siguen
transparentes) y `-only-testing:FisuEvolutionUITests/LaunchSmokeTests` → PASS.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add project.yml FisuEvolution/Info.plist FisuEvolution/UI/Art/PanelFrames.swift \
  FisuEvolutionTests/InfoPlistContractTests.swift
git diff --cached --stat
git commit -m "feat(ipad): la app universal, vertical y de pantalla completa, con iOS 18 de mínimo"
```

**Para el controlador (docs, no lo hace el subagente):** `Docs/HANDOFF-v2.md:90-91` ("Sólo
iPhone", "iOS mínimo 17.0") y la ficha (`Distribution/store-metadata.md`, el frente de E10)
pasan a "Universal, iPad vertical" e "iOS 18".

---

### Task 6: Las hojas y los popups en iPad — `fisuSheet()` y la columna de 640

**Objetivo:** toda hoja del juego se presenta con un solo modificador —transparente y, en iPad,
del tamaño de una página— y el panel de las hojas no pasa de 640 pt. Un test de fuente impide
que una hoja nueva vuelva a presentarse a mano. Las seis de la barra (en `RootView`, caliente)
las pasa la Task 11; acá quedan anotadas como pendientes del guardia.

**Files:**
- Modify: `FisuEvolution/UI/Art/PanelFrames.swift` (`fisuSheet()`, `SheetColumn`, `PanelSheetLayout.body`)
- Modify: `FisuEvolution/UI/Popups/OfflineEarningsView.swift:153`, `PrestigeView.swift:105`, `CareerChoiceView.swift:49`, `DailyRewardView.swift:104`, `SpecialDropView.swift:86`, `SkinAwardView.swift:95`, `CharacterSheetView.swift:76`
- Modify: `FisuEvolution/UI/Share/ShareCardView.swift` (`presentationSizing`)
- Modify: `FisuEvolution/UI/HUD/HUDView.swift` (la hoja del mapa)
- Create: `FisuEvolutionTests/SheetPresentationGuardTests.swift`

**Interfaces:**
- Consumes: iOS 18 de la Task 5 (`presentationSizing`).
- Produces: `extension View { func fisuSheet() -> some View }` y `enum SheetColumn { static let maxWidth: CGFloat = 640 }`.
  E3b T2 (la ficha) y E3b T4 (el paginador) presentan con `fisuSheet()`.

- [ ] **Step 1: El guardia, en rojo**

`FisuEvolutionTests/SheetPresentationGuardTests.swift`:

```swift
import Foundation
import Testing

/// Toda hoja del juego pasa por `fisuSheet()` (PLAN-v2 E3, iPad): una que se
/// presente a mano con `.presentationBackground(.clear)` sale en iPad como un
/// formulario angosto. Lee las FUENTES con `#filePath`, como
/// `LocalizationCompletenessTests`.
@Suite("Toda hoja se presenta con fisuSheet")
struct SheetPresentationGuardTests {
    private static let appSources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "FisuEvolution")

    /// El único archivo autorizado: el que define `fisuSheet()`.
    private static let definition = "PanelFrames.swift"

    /// Los que todavía presentan a mano, con su motivo. La hoja de las seis
    /// pestañas vive en `RootView`, que es caliente: la pasa la Task 11 de
    /// E3a, que deja esta lista vacía.
    private static let pending: Set<String> = ["RootView.swift"]

    @Test("ninguna hoja usa .presentationBackground(.clear) a mano")
    func noSheetBypassesFisuSheet() throws {
        var offenders: [String] = []
        let files = FileManager.default.enumerator(at: Self.appSources, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            let name = url.lastPathComponent
            guard url.pathExtension == "swift", name != Self.definition, !Self.pending.contains(name) else { continue }
            let code = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            if code.contains(where: { $0.contains(".presentationBackground(.clear)") }) {
                offenders.append(name)
            }
        }
        #expect(offenders.isEmpty, "presentan a mano: \(offenders.sorted())")
    }
}
```

- [ ] **Step 2: Verlo fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/SheetPresentationGuardTests`.
Expected: FAIL — `presentan a mano: ["CareerChoiceView.swift", "CharacterSheetView.swift", "DailyRewardView.swift", "HUDView.swift", "OfflineEarningsView.swift", "PrestigeView.swift", "SkinAwardView.swift", "SpecialDropView.swift"]`.

- [ ] **Step 3: `fisuSheet()` y la columna de 640**

En `PanelFrames.swift`, al final del bloque "Hoja contenida" (después de las dos
`panelSheet`):

```swift
// MARK: - La presentación de las hojas

/// El ancho máximo del panel de una hoja: en iPhone no se alcanza nunca; en
/// iPad la hoja `.page` es más ancha y el panel queda centrado en esta columna.
enum SheetColumn {
    static let maxWidth: CGFloat = 640
}

extension View {
    /// Cómo se presenta TODA hoja del juego (PLAN-v2 E3): transparente —el panel
    /// o la tarjeta flotan sobre el juego atenuado— y, en iPad, del tamaño de
    /// una página en vez del formulario angosto de fábrica. En iPhone `.page`
    /// es la hoja de siempre y los `presentationDetents` siguen mandando.
    func fisuSheet() -> some View {
        presentationSizing(.page)
            .presentationBackground(.clear)
    }
}
```

En `PanelSheetLayout.body`, después de `.ignoresSafeArea(edges: .top)`:

```swift
        .frame(maxWidth: SheetColumn.maxWidth)
```

(si el reporte de S1 trajo el plan B, el controlador despacha esta tarea con
`fullScreenCover` en vez de `.page`; el resto no cambia).

- [ ] **Step 4: Los popups, el mapa y compartir**

En cada uno de los siete popups, la línea `.presentationBackground(.clear)` pasa a
`.fisuSheet()` (los `presentationDetents` de arriba se quedan). En `HUDView.body`, la hoja del
mapa: `FloorMapView().fisuSheet()`. En `ShareCardView.swift`, antes de
`.presentationBackground { … }` (que es de pergamino y se queda):

```swift
        .presentationSizing(.page)
```

- [ ] **Step 5: Verde, iPhone igual y oráculo**

Run: Receta R con `-only-testing:FisuEvolutionTests/SheetPresentationGuardTests` → PASS.
Después, en iPhone 16 Pro: `-only-testing:FisuEvolutionUITests/BottomMenuUITests`,
`-only-testing:FisuEvolutionUITests/FloorMapUITests`, `-only-testing:FisuEvolutionUITests/CareerChoiceUITests`
→ PASS sin cambios. Capturar `--uitest-offline` en iPhone y en `iPad Pro 13-inch (M4)` y
adjuntar las dos al reporte (el popup offline tiene que verse igual en iPhone y como página
centrada en iPad). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/UI/Art/PanelFrames.swift FisuEvolution/UI/Popups/OfflineEarningsView.swift \
  FisuEvolution/UI/Popups/PrestigeView.swift FisuEvolution/UI/Popups/CareerChoiceView.swift \
  FisuEvolution/UI/Popups/DailyRewardView.swift FisuEvolution/UI/Popups/SpecialDropView.swift \
  FisuEvolution/UI/Popups/SkinAwardView.swift FisuEvolution/UI/Popups/CharacterSheetView.swift \
  FisuEvolution/UI/Share/ShareCardView.swift FisuEvolution/UI/HUD/HUDView.swift \
  FisuEvolutionTests/SheetPresentationGuardTests.swift
git diff --cached --stat
git commit -m "feat(ipad): toda hoja se presenta con fisuSheet y el panel no pasa de 640 pt"
```

---

### Task 7: La barra de abajo más baja, con Contratar al centro

**Objetivo:** la barra baja 20 pt (el panel pasa de 84 a 64) y Contratar va al centro, más
grande, sobresaliendo por encima del panel como el botón central de Cow Evolution; dos
pestañas a la izquierda (Mejoras, Vestimenta) y tres a la derecha (Bonus, Tienda, Menú). La
pila de arriba (el atajo, el prestigio y los dos toasts) **no se mueve**: se apoya sobre el
cuadro entero de la barra, que sigue midiendo 84. La multitud baja recién en la Task 10, cuando
`BoardScene.bottomInset` pase a contar el panel (caliente).

**Files:**
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (`GameScreen.barOrder`, `GameScreen.centerTab`, `GameTabBar`, `GameTabButton`)
- Modify: `FisuEvolution/UI/HUD/BottomMenuBar.swift` (`items`, `isProminent`, `iconSide`, `prominentIconSide`)
- Modify: `FisuEvolutionTests/GameArtComponentsTests.swift`
- Modify: `FisuEvolutionUITests/BottomMenuUITests.swift` (`testLosExtremosSonMasGrandesQueElResto` → `testContratarVaAlCentroYEsElMasGrande`)

**Interfaces:**
- Produces: `GameScreen.barOrder: [GameScreen]` = `[.upgrades, .skins, .jobs, .gifts, .store, .menu]`
  y `GameScreen.centerTab` = `.jobs`. **`allCases` no cambia** (lo pinean los tests y es la
  identidad de la hoja). El paginador de E3b usa `barOrder`.
- Produces: `GameTabBar.panelHeight` (64), `GameTabBar.centerRise` (20),
  `GameTabBar.barHeight` (= 84, el cuadro entero), `GameTabBar.plateSide` (44),
  `GameTabBar.centerPlateSide` (64), `GameTabBar.centerColumnWidth` (72),
  `GameTabBar.spacing` (2), `GameTabBar.minimumWidth(tabsPerSide:) -> CGFloat`.

- [ ] **Step 1: Los tests, en rojo**

En `GameArtComponentsTests.swift`, reemplazar `screenOrderIsTheTabOrder` y
`tabItemsAreDistinct` y sumar la geometría:

```swift
    @Test("allCases conserva el orden histórico: es la identidad de la hoja")
    func allCasesKeepsTheHistoricOrder() {
        #expect(GameScreen.allCases.map(\.rawValue) == ["jobs", "upgrades", "skins", "gifts", "store", "menu"])
    }

    @Test("la barra va con Contratar al centro: dos a la izquierda y tres a la derecha")
    func barOrderPutsHiringInTheCenter() {
        #expect(GameScreen.barOrder == [.upgrades, .skins, .jobs, .gifts, .store, .menu])
        #expect(Set(GameScreen.barOrder) == Set(GameScreen.allCases))
        #expect(GameScreen.centerTab == .jobs)
    }

    @Test("una barra con las 6 pantallas no repite ni ids ni identifiers, y sólo Contratar se destaca")
    func tabItemsAreDistinct() {
        let items = GameScreen.barOrder.map { screen in
            GameTabItem(
                screen: screen,
                icon: AnyView(EmptyView()),
                labelKey: "hud.\(screen.rawValue).label",
                identifier: screen.identifier,
                prominent: screen == GameScreen.centerTab
            )
        }
        #expect(items.count == 6)
        #expect(Set(items.map(\.id)).count == 6)
        #expect(Set(items.map(\.identifier)).count == 6)
        #expect(items.filter(\.prominent).map(\.screen) == [.jobs])
    }

    @Test("la barra baja 20 pt: el panel mide 64 y Contratar sobresale 20")
    func barGeometry() {
        #expect(GameTabBar.panelHeight == 64)
        #expect(GameTabBar.centerRise == GameTabBar.centerPlateSide - GameTabBar.plateSide)
        #expect(GameTabBar.barHeight == GameTabBar.panelHeight + GameTabBar.centerRise)
        #expect(GameTabBar.barHeight == 84, "la pila de arriba (atajo, prestigio, toasts) no se mueve")
    }

    /// Las dos zonas miden lo mismo, así que manda la más poblada: tres pestañas
    /// a la derecha. 16 + 72 + 2 × 136 + 4 = 364 de los 375 del SE.
    @Test("las seis pestañas entran en el SE")
    func sixTabsFitTheSE() {
        #expect(GameTabBar.minimumWidth(tabsPerSide: 3) <= 375)
    }
```

En `BottomMenuUITests.swift`, reemplazar `testLosExtremosSonMasGrandesQueElResto` entero por:

```swift
    /// Contratar va al centro y es el más grande (PLAN-v2 E3, la crítica de la
    /// barra): el verbo principal se encuentra sin buscarlo. Y la barra es más
    /// baja: los platos comunes arrancan a menos de 100 pt del borde de abajo.
    @MainActor
    func testContratarVaAlCentroYEsElMasGrande() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()

        let jobs = app.buttons["hud.hire"]
        XCTAssertTrue(jobs.waitForExistence(timeout: 20))
        let screen = app.windows.element(boundBy: 0).frame
        attach(app, named: "E3 Contratar al centro")

        XCTAssertEqual(jobs.frame.midX, screen.midX, accuracy: 2, "Contratar tiene que ir al centro")
        for identifier in ["hud.upgrades", "hud.skins", "hud.bonus", "hud.store", "hud.settings"] {
            let tab = app.buttons[identifier]
            XCTAssertTrue(tab.exists, "falta \(identifier)")
            XCTAssertGreaterThan(jobs.frame.height, tab.frame.height,
                                 "Contratar tiene que ser más alto que \(identifier)")
            XCTAssertGreaterThan(tab.frame.minY, screen.height - 100,
                                 "\(identifier) arrancó en \(tab.frame.minY): la barra no bajó")
        }
        XCTAssertGreaterThan(jobs.frame.minY, screen.height * 0.75,
                             "la barra tiene que estar pegada abajo, arrancó en \(jobs.frame.minY)")
    }
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/GameArtComponentsTests` → no compila
(`barOrder`, `panelHeight` no existen). La UI, con
`-only-testing:FisuEvolutionUITests/BottomMenuUITests/testContratarVaAlCentroYEsElMasGrande`
→ FAIL (Contratar está en la punta izquierda).

- [ ] **Step 3: `GameScreen` y la geometría de la barra**

En `GameArtComponents.swift`, dentro de `enum GameScreen`, después de `identifier`:

```swift
    /// El orden de la barra de abajo y del paginador del menú (PLAN-v2 E3):
    /// Contratar al centro, con dos pestañas a la izquierda y tres a la derecha.
    /// NO es `allCases`, que conserva el orden histórico.
    static let barOrder: [GameScreen] = [.upgrades, .skins, .jobs, .gifts, .store, .menu]

    /// La pestaña del centro, la más grande.
    static let centerTab: GameScreen = .jobs
```

En `GameTabBar`, reemplazar `barHeight` (con su docstring de `:1028-1071`) y `body` por:

```swift
    /// Aire arriba de los platos comunes, adentro del panel.
    static let topPadding: CGFloat = 6
    /// Plato de una pestaña común y el de Contratar.
    static let plateSide: CGFloat = 44
    static let centerPlateSide: CGFloat = 64
    /// El espacio entre pestañas: el literal 2 de la v1.
    static let spacing: CGFloat = 2

    /// Alto del panel visible, sin la safe area ni el piso de abajo: 6 de aire +
    /// 44 de plato + 2 + 12 del nombre. Es lo que le tapa el tablero a la
    /// multitud (`BoardScene.bottomInset`): 20 pt menos que la v1 (84), que es lo
    /// que pidió la crítica de la barra (PLAN-v2 §2).
    static let panelHeight: CGFloat = 64
    /// Cuánto sobresale Contratar por encima del panel.
    static let centerRise: CGFloat = centerPlateSide - plateSide

    /// Alto del cuadro entero, con Contratar sobresaliendo. Sobre esto se apoya
    /// la pila de arriba —el atajo, el prestigio y los dos toasts de `RootView`—,
    /// así que conserva el nombre y el valor de la v1 (84) y esa pila no se
    /// mueve. ⚠️ Aislado al main actor como todo el tipo (es un `View`).
    static let barHeight: CGFloat = panelHeight + centerRise

    /// El ancho fijo de la columna de Contratar: su plato y un poco de aire para
    /// el nombre. Fijo, para que las dos zonas se repartan el resto por igual.
    static let centerColumnWidth: CGFloat = centerPlateSide + Tokens.s8

    /// El ancho mínimo de la barra. Las dos zonas miden lo mismo, así que manda
    /// la que tiene más pestañas.
    static func minimumWidth(tabsPerSide: Int) -> CGFloat {
        let zone = CGFloat(tabsPerSide) * plateSide + CGFloat(max(0, tabsPerSide - 1)) * spacing
        return Tokens.s8 * 2 + centerColumnWidth + zone * 2 + spacing * 2
    }

    var body: some View {
        let center = items.first { $0.screen == GameScreen.centerTab }
        let leading = Array(items.prefix { $0.screen != GameScreen.centerTab })
        let trailing = center == nil ? [] : Array(items.drop { $0.screen != GameScreen.centerTab }.dropFirst())
        // Alineados abajo: los nombres de las seis comparten renglón y la
        // diferencia de alto se va toda para arriba, que es donde sobresale
        // Contratar. Las dos zonas miden lo mismo, así que Contratar queda al
        // centro exacto tenga cuantas pestañas tenga cada lado.
        HStack(alignment: .bottom, spacing: Self.spacing) {
            zone(leading)
            if let center {
                GameTabButton(item: center) { selection(center.screen) }
                    // Ancho fijo: el botón se estira (`maxWidth: .infinity`) y,
                    // sin esto, se llevaría un tercio de la barra y la zona de
                    // tres pestañas no entraría en el SE.
                    .frame(width: Self.centerColumnWidth)
            }
            zone(trailing)
        }
        .padding(.horizontal, Tokens.s8)
        .padding(.top, Self.topPadding)
        .padding(.bottom, bottomGap)
        .playColumn()
        .background(alignment: .bottom) {
            bottomPanel.padding(.top, Self.centerRise)
        }
    }

    private func zone(_ zoneItems: [GameTabItem]) -> some View {
        HStack(alignment: .bottom, spacing: Self.spacing) {
            ForEach(zoneItems) { item in
                GameTabButton(item: item) { selection(item.screen) }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
    }
```

En `GameTabButton`, el docstring de `side` (`:1162-1173`) y las dos propiedades quedan:

```swift
    /// Platos de 44 y 64 (Contratar) con iconos de 38 y 56: la barra baja 20 pt
    /// y el centro sobresale, como en Cow Evolution. Las seis entran en el SE con
    /// aire (`GameTabBar.minimumWidth`).
    private var side: CGFloat { item.prominent ? GameTabBar.centerPlateSide : GameTabBar.plateSide }
    private var iconSide: CGFloat { item.prominent ? 56 : 38 }
```

- [ ] **Step 4: `BottomMenuBar` en el orden nuevo**

En `BottomMenuBar.swift`:

```swift
    private var items: [GameTabItem] {
        GameScreen.barOrder.map { screen in
            GameTabItem(
                screen: screen,
                icon: icon(for: screen),
                labelKey: Self.labelKey(for: screen),
                identifier: screen.identifier,
                prominent: Self.isProminent(screen),
                showsBadge: showsBadge(for: screen)
            )
        }
    }
```

```swift
    /// Contratar va al centro y destacado: es el verbo principal del juego.
    private static func isProminent(_ screen: GameScreen) -> Bool {
        screen == GameScreen.centerTab
    }
```

```swift
    private static let iconSide: CGFloat = 38
    private static let prominentIconSide: CGFloat = 56
```

y en el docstring de `icon(for:)`, la cuenta del recorte pasa a "56+20 = 76 sobre los 64 de
Contratar, 38+20 = 58 sobre los 44 de una común". El docstring del tipo deja de decir "FisuJobs
a la izquierda y el Menú a la derecha, los dos destacados": "Contratar al centro y destacado,
con dos pestañas a la izquierda y tres a la derecha (PLAN-v2 E3)".

- [ ] **Step 5: Verde, el resto de la barra igual y oráculo**

Run: Receta R con `-only-testing:FisuEvolutionTests/GameArtComponentsTests` → PASS.
`-only-testing:FisuEvolutionUITests/BottomMenuUITests` → PASS, con
`testCadaTabAbreSuPantallaYSeCierra` **sin cambios**. `-only-testing:FisuEvolutionUITests/TutorialUITests`
→ PASS (el ancla `.hire` está en el icono de Contratar, ahora al centro). Captura en SE 3 y
16 Pro al reporte. `Tools/v2/oraculo.sh completo` → `VERDE` (toca UI).

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/UI/Art/GameArtComponents.swift FisuEvolution/UI/HUD/BottomMenuBar.swift \
  FisuEvolutionTests/GameArtComponentsTests.swift FisuEvolutionUITests/BottomMenuUITests.swift
git diff --cached --stat
git commit -m "feat(ux): la barra de abajo 20 pt más baja, con Contratar al centro"
```

---

### Task 8: La botonera del ascensor — display LED, persiana y un botón por piso

**Objetivo:** debajo del HUD, contra el borde derecho, una placa de metal con remaches y un
display LED ("3 · Corporativo") que hace de cartel del piso. En reposo sólo se ve el display;
al tocarlo o al cambiar de piso se despliega como persiana una grilla de 2 columnas con un
botón redondo por piso (candado si está cerrado, luz verde si está "en marcha" —todos sus
lugares ocupados—), y a los 2 s sin uso se recoge. Tocar un botón hace "ding" y vuela al piso.
El ícono del ascensor del HUD (`hud.map`) sigue abriendo el mapa.

**Files:**
- Create: `FisuEvolution/UI/HUD/ElevatorPanel.swift`
- Modify: `FisuEvolution/UI/Art/PanelFrames.swift` (`MetalPlate`)
- Modify: `FisuEvolution/UI/HUD/HUDView.swift` (`body`: la fila del prestigio)
- Modify: `FisuEvolution/Audio/AudioManager.swift` (`SFX.elevatorDing`)
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (por snapshot: `Tools/v2/claves-pendientes/e3a-t8.json`)
- Create: `FisuEvolutionTests/ElevatorPanelModelTests.swift`
- Create: `FisuEvolutionUITests/ElevatorPanelUITests.swift`

**Interfaces:**
- Consumes: `GameState.floorMap: [FloorMapEntry]`, `GameState.towerNavigation`,
  `GameState.jumpToFloor(ordinal:)`, `GameState.playHaptic(_:)`, `TowerNaming.floorName(for:)`.
- Produces: `struct ElevatorPanelModel: Equatable` con `struct Floor { id, number, isUnlocked, isStaffed }`,
  `init(map: [FloorMapEntry])`, `floors` (de arriba abajo) y
  `static func glow(forOrdinal: Int, cameraFloor: Double) -> Double`.
- Produces: `struct ElevatorPanel: View` con `static let displayHeight: CGFloat` (44) y
  `static let collapseDelay: Duration` (2 s). La Task 10 cambia la fuente de la luz a
  `GameState.cameraFloor`.
- Produces: `AudioManager.SFX.elevatorDing` (`sfx_elevator_ding`).
- Produces: `struct MetalPlate: View` (`cornerRadius`).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/ElevatorPanelModelTests.swift`:

```swift
import Testing
@testable import FisuEvolution

/// La botonera del ascensor (PLAN-v2 E3): qué botón va dónde, cuál está "en
/// marcha" y cuánto brilla cada uno con la cámara en camino.
@Suite("La botonera del ascensor")
struct ElevatorPanelModelTests {
    /// El mapa viene de Dios para abajo, como lo arma `GameState.floorMap`.
    private func map(_ floors: [(id: String, occupied: Int, capacity: Int, unlocked: Bool)]) -> [FloorMapEntry] {
        floors.enumerated().map { index, floor in
            FloorMapEntry(
                id: floor.id,
                ordinal: floors.count - 1 - index,
                backgroundKey: "bg_\(floor.id)",
                occupied: floor.occupied,
                capacity: floor.capacity,
                isUnlocked: floor.unlocked,
                isVisible: false
            )
        }
    }

    @Test("los botones van de arriba abajo y numerados desde el callejón")
    func floorsGoTopDownNumberedFromTheAlley() {
        let model = ElevatorPanelModel(map: map([
            ("corporate", 0, 10, false),
            ("urban", 4, 10, true),
            ("alley", 10, 10, true),
        ]))
        #expect(model.floors.map(\.id) == ["corporate", "urban", "alley"])
        #expect(model.floors.map(\.number) == [3, 2, 1])
    }

    @Test("un piso está en marcha con todos sus lugares ocupados, y nunca si está cerrado")
    func staffedMeansFullAndOpen() {
        let model = ElevatorPanelModel(map: map([
            ("corporate", 10, 10, false),
            ("urban", 9, 10, true),
            ("alley", 10, 10, true),
        ]))
        #expect(model.floors.map(\.isStaffed) == [false, false, true])
        #expect(model.floors.map(\.isUnlocked) == [false, true, true])
    }

    @Test("la luz viaja suave: 1 en el piso, la mitad a medio camino, 0 a un piso")
    func glowFollowsTheCamera() {
        #expect(ElevatorPanelModel.glow(forOrdinal: 2, cameraFloor: 2) == 1)
        #expect(abs(ElevatorPanelModel.glow(forOrdinal: 2, cameraFloor: 2.5) - 0.5) < 0.0001)
        #expect(abs(ElevatorPanelModel.glow(forOrdinal: 3, cameraFloor: 2.5) - 0.5) < 0.0001)
        #expect(ElevatorPanelModel.glow(forOrdinal: 2, cameraFloor: 3.2) == 0)
    }
}
```

`FisuEvolutionUITests/ElevatorPanelUITests.swift`:

```swift
import XCTest

/// La botonera del ascensor (PLAN-v2 E3): el display muestra el piso, tocarlo
/// despliega la persiana, un botón lleva al piso y la persiana se recoge sola.
final class ElevatorPanelUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaBotoneraLlevaAlPisoYSeRecogeSola() throws {
        let app = XCUIApplication()
        // La torre abierta hasta el urbano; el piso visible arranca en el callejón.
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower"]
        app.launch()

        let display = app.buttons["hud.elevator.display"]
        XCTAssertTrue(display.waitForExistence(timeout: 20), "el display del ascensor no apareció")
        XCTAssertEqual(display.value as? String, "alley")
        XCTAssertTrue(app.buttons["hud.map"].exists, "el ícono del ascensor se conserva")
        XCTAssertFalse(app.buttons["hud.elevator.floor.urban"].exists, "en reposo sólo se ve el display")

        display.tap()
        let urban = app.buttons["hud.elevator.floor.urban"]
        XCTAssertTrue(urban.waitForExistence(timeout: 3), "la persiana no se desplegó")
        attach(app, named: "E3 botonera desplegada")
        urban.tap()

        let floor = app.otherElements["board.floor"]
        let arrived = NSPredicate(format: "value == %@", "urban")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: arrived, evaluatedWith: floor)], timeout: 5), .completed,
                       "el botón no llevó al urbano")
        XCTAssertEqual(display.value as? String, "urban")
        XCTAssertTrue(urban.waitForNonExistence(timeout: 6), "la persiana no se recogió a los 2 s")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/ElevatorPanelModelTests` → no compila
(`ElevatorPanelModel` no existe). Con el modelo creado vacío, la UI con
`-only-testing:FisuEvolutionUITests/ElevatorPanelUITests` → FAIL "el display del ascensor no apareció".

- [ ] **Step 3: El ding y la placa de metal**

`AudioManager.swift`, en `enum SFX`, después de `chestShakeB`:

```swift
        /// La campana de la botonera del ascensor (E8 audio, cableada en E3).
        case elevatorDing = "sfx_elevator_ding"
```

(`AudioManagerTests.preloadLeavesEverySFXReady` lo cubre: el `.caf` existe.)

`PanelFrames.swift`, después de `PanelScrew`:

```swift
// MARK: - MetalPlate

/// Una placa chica de metal con remaches, para la maquinaria del HUD (la
/// botonera del ascensor). Tonos y remaches del marco `.metal`.
struct MetalPlate: View {
    var cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(LinearGradient(colors: [MetalTone.light, MetalTone.base], startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(MetalTone.bevel.opacity(0.9), lineWidth: 1.5).padding(2))
            .overlay(shape.strokeBorder(Color("PaletteInk").opacity(0.9), lineWidth: 2.5))
            .overlay {
                GeometryReader { geo in
                    ForEach(0..<4, id: \.self) { corner in
                        PanelScrew(fill: MetalTone.screw, line: MetalTone.dark, diameter: 6)
                            .position(
                                x: corner.isMultiple(of: 2) ? 7 : geo.size.width - 7,
                                y: corner < 2 ? 7 : geo.size.height - 7
                            )
                    }
                }
            }
            .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
            .accessibilityHidden(true)
    }
}
```

- [ ] **Step 4: El modelo y la botonera**

`FisuEvolution/UI/HUD/ElevatorPanel.swift`:

```swift
import SwiftUI

/// Lo que dibuja la botonera, resuelto y puro (lo pinea `ElevatorPanelModelTests`).
struct ElevatorPanelModel: Equatable {
    struct Floor: Identifiable, Equatable {
        let id: String
        /// 1 en el callejón: el número que se lee en el botón y en el display.
        let number: Int
        let isUnlocked: Bool
        /// Todos sus lugares ocupados: el piso "en marcha" (PLAN-v2 §2). La luz
        /// verde; E2a le cuelga el bonus de ingresos.
        let isStaffed: Bool
    }

    /// De arriba abajo, como se lee una botonera.
    let floors: [Floor]

    /// `map` viene de Dios para abajo (`GameState.floorMap`).
    init(map: [FloorMapEntry]) {
        floors = map.map { entry in
            Floor(
                id: entry.id,
                number: entry.ordinal + 1,
                isUnlocked: entry.isUnlocked,
                isStaffed: entry.isUnlocked && entry.capacity > 0 && entry.occupied >= entry.capacity
            )
        }
    }

    /// Cuánto brilla el botón de un piso con la cámara en `cameraFloor` (ordinal
    /// continuo): 1 en el piso, 0 a un piso o más. Así la luz viaja entre los
    /// botones siguiendo la cámara en vez de saltar.
    static func glow(forOrdinal ordinal: Int, cameraFloor: Double) -> Double {
        max(0, 1 - abs(cameraFloor - Double(ordinal)))
    }
}

/// La botonera del ascensor (PLAN-v2 §2 y E3): el cartel del piso en un display
/// LED sobre una placa de metal, y una persiana con un botón por piso.
///
/// En reposo sólo se ve el display. Se despliega al tocarlo o al cambiar de piso
/// y se recoge sola a los 2 s sin uso. ⚠️ Fuera de sus controles no toca nada:
/// el deslizamiento del tablero que arranca al lado de la botonera sigue siendo
/// del tablero (spike S6).
struct ElevatorPanel: View {
    @Environment(GameState.self) private var gameState
    @Environment(AudioManager.self) private var audio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    /// Cada toque o cambio de piso reinicia la cuenta de los 2 s.
    @State private var activity = 0

    /// Alto del display con su placa: la fila del HUD lo reserva para que el
    /// display nunca se encime con lo que va debajo.
    static let displayHeight: CGFloat = 44
    static let collapseDelay: Duration = .seconds(2)

    private static let ledScreen = Color(red: 0.11, green: 0.10, blue: 0.09)
    private static let ledLit = Color(red: 1.0, green: 0.64, blue: 0.18)

    /// Dónde está la luz: el piso visible. La Task 10 la ata a la cámara.
    private var lightPosition: Double { Double(gameState.towerNavigation.ordinal) }

    var body: some View {
        let navigation = gameState.towerNavigation
        VStack(alignment: .trailing, spacing: Tokens.s4) {
            display(navigation)
            if expanded {
                shutter
                    .transition(reduceMotion
                        ? .opacity
                        : .scale(scale: 0.2, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35), value: expanded)
        .onChange(of: navigation.ordinal) { _, _ in unfold() }
        .task(id: activity) {
            guard expanded else { return }
            try? await Task.sleep(for: Self.collapseDelay)
            guard !Task.isCancelled else { return }
            expanded = false
        }
    }

    // MARK: El display

    private func display(_ navigation: GameState.TowerNavigation) -> some View {
        Button {
            if expanded { expanded = false } else { unfold() }
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: "\(navigation.ordinal + 1)")
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(navigation.ordinal)))
                Text(verbatim: "·")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                Text(verbatim: TowerNaming.floorName(for: navigation.floorID))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(Self.ledLit)
            .shadow(color: Self.ledLit.opacity(0.8), radius: 3)
            .padding(.horizontal, Tokens.s8)
            .frame(maxWidth: 146, minHeight: Self.displayHeight - 10)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Self.ledScreen))
            .padding(5)
            .background(MetalPlate(cornerRadius: 12))
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: navigation.ordinal)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hud.elevator.display")
        .accessibilityLabel(Text("elevator.display.label"))
        // El id crudo del piso, como `board.floor`: el runner corre en inglés.
        .accessibilityValue(Text(verbatim: navigation.floorID))
    }

    // MARK: La persiana

    private var shutter: some View {
        // Se re-evalúa con el tablero: una contratación o un merge cambian la
        // ocupación, y con ella la luz verde.
        let _ = gameState.boardVersion
        let model = ElevatorPanelModel(map: gameState.floorMap)
        let rows = stride(from: 0, to: model.floors.count, by: 2).map {
            Array(model.floors[$0 ..< min($0 + 2, model.floors.count)])
        }
        // `Grid` y no `LazyVGrid`: la perezosa se lleva puestos los identifiers
        // cuando el árbol de AX se arma antes de la celda (medido en la T11 del
        // rediseño, ver `MenuView`).
        return Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { floor in
                        ElevatorFloorButton(
                            floor: floor,
                            glow: ElevatorPanelModel.glow(forOrdinal: floor.number - 1, cameraFloor: lightPosition)
                        ) {
                            select(floor)
                        }
                    }
                }
            }
        }
        .padding(Tokens.s8)
        .background(MetalPlate(cornerRadius: 14))
        .animation(.linear(duration: 0.125), value: lightPosition)
    }

    private func unfold() {
        expanded = true
        activity &+= 1
    }

    private func select(_ floor: ElevatorPanelModel.Floor) {
        unfold()
        guard floor.isUnlocked else {
            gameState.playHaptic(.error)
            return
        }
        audio.play(.elevatorDing)
        gameState.jumpToFloor(ordinal: floor.number - 1)
    }
}

/// Un botón de la botonera: redondo, de metal, con el número (o el candado) y la
/// luz del piso donde está la cámara. El punto verde es "en marcha".
private struct ElevatorFloorButton: View {
    let floor: ElevatorPanelModel.Floor
    let glow: Double
    let action: () -> Void

    private static let side: CGFloat = 34

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.85), Color("PaletteCream")],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(Color("PaletteInk").opacity(0.85), lineWidth: 2))
                Circle()
                    .fill(Color(red: 1.0, green: 0.64, blue: 0.18))
                    .opacity(glow * 0.85)
                    .padding(3)
                if floor.isUnlocked {
                    Text(verbatim: "\(floor.number)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color("PaletteInk"))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color("PaletteInk").opacity(0.55))
                }
            }
            .overlay(alignment: .topTrailing) {
                if floor.isStaffed {
                    Circle()
                        .fill(Color("PaletteGreen"))
                        .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 1.5))
                        .frame(width: 10, height: 10)
                        .offset(x: 2, y: -2)
                }
            }
            .frame(width: Self.side, height: Self.side)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hud.elevator.floor.\(floor.id)")
        .accessibilityLabel(Text("elevator.floor.ax \(String(floor.number)) \(TowerNaming.floorName(for: floor.id))"))
        .accessibilityValue(floor.isUnlocked
            ? (floor.isStaffed ? Text("elevator.floor.staffed") : Text(verbatim: ""))
            : Text("elevator.floor.locked"))
    }
}
```

- [ ] **Step 5: Colgarla del HUD**

En `HUDView.body`, `prestigeIndicator` pasa a:

```swift
            prestigeIndicator
                .frame(maxWidth: .infinity, minHeight: ElevatorPanel.displayHeight, alignment: .top)
                .overlay(alignment: .topTrailing) {
                    // Contra el borde derecho, debajo del ícono del ascensor
                    // (`hud.map`, que sigue abriendo el mapa). La fila reserva el
                    // alto del display; la persiana desplegada flota por encima
                    // del tablero mientras dura.
                    ElevatorPanel()
                        .padding(.trailing, Tokens.s12)
                }
```

- [ ] **Step 6: Las strings**

`Tools/v2/claves-pendientes/e3a-t8.json`:

```json
{
  "elevator.display.label": {"es": "Ascensor", "en": "Elevator"},
  "elevator.floor.ax %@ %@": {"es": "Piso %1$@: %2$@", "en": "Floor %1$@: %2$@"},
  "elevator.floor.locked": {"es": "bloqueado", "en": "locked"},
  "elevator.floor.staffed": {"es": "en marcha", "en": "fully staffed"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e3a-t8.json` (ver Global
Constraints para commitearlo o descartarlo).

- [ ] **Step 7: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/ElevatorPanelModelTests` → PASS (3);
`-only-testing:FisuEvolutionTests/AudioManagerTests` y `LocalizationCompletenessTests` → PASS;
`-only-testing:FisuEvolutionUITests/ElevatorPanelUITests`, `FloorMapUITests`,
`HUDRedesignUITests` → PASS. Capturas en SE 3 (persiana desplegada) al reporte.
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/UI/HUD/ElevatorPanel.swift FisuEvolution/UI/Art/PanelFrames.swift \
  FisuEvolution/UI/HUD/HUDView.swift FisuEvolution/Audio/AudioManager.swift \
  FisuEvolutionTests/ElevatorPanelModelTests.swift FisuEvolutionUITests/ElevatorPanelUITests.swift
# Dueño del catálogo en la ola: FisuEvolution/Resources/Localizable.xcstrings (y git rm del JSON)
# Si no: Tools/v2/claves-pendientes/e3a-t8.json
git diff --cached --stat
git commit -m "feat(ux): la botonera del ascensor, con display LED, persiana y un botón por piso"
```

---

### Task 9: Las pestañas aparecen de a poco, con "¡Nuevo!"

**Objetivo:** un jugador nuevo ve sólo Contratar y Mejoras; las demás pestañas aparecen cuando
se desbloquean (Vestimenta con la primera pinta, Bonus al terminar el núcleo del tutorial o con
el primer cofre, Tienda en la 2ª sesión, Menú al terminar el núcleo), entran con animación y un
"¡Nuevo!" que se va al abrirlas. Las reglas son dato (`tabs.json`), las evalúa una función pura,
y lo desbloqueado se guarda en `meta.unlockedTabs` (save v6 de E1): nunca se vuelve a cerrar, y
los veteranos de la v1 lo tienen todo (lo pone `SaveMigrator.migrateV5toV6`).

**Files:**
- Create: `FisuEvolution/Resources/Config/tabs.json`
- Create: `FisuEvolution/Managers/TabUnlocks.swift`
- Modify: `FisuEvolution/Managers/GameContentLoader.swift` (`GameContent.tabs`, `load`)
- Create: `FisuEvolution/Game/State/GameState+Tabs.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` (`unlockedTabs`, `newTabs`, `progressiveTabsEnabled`; `refreshProjections`)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`applyLaunchArgumentDefaults`)
- Modify: `FisuEvolution/UI/HUD/BottomMenuBar.swift` (`items`, `body`)
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (`GameTabItem.isNew`, `GameTabButton`, `NewTabBadge`)
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (snapshot `e3a-t9.json`)
- Create: `FisuEvolutionTests/TabUnlockRulesTests.swift`, `FisuEvolutionTests/TabUnlockWiringTests.swift`, `FisuEvolutionUITests/ProgressiveTabsUITests.swift`

**Interfaces:**
- Consumes: `MetaState.unlockedTabs: Set<String>` y `SaveMigrator.v1Tabs` (**E1 T4**);
  `GameScreen.barOrder` (T7); `GameState.sessionsAfterPhaseKey` (`+TutorialTips`).
- Produces: `enum TabUnlockCondition: String, Codable` (`always`, `tutorialCore`, `firstSkin`,
  `firstChest`, `secondSession`), `struct TabUnlockSignals`, `struct TabsConfig` (con
  `validate()`), `enum TabUnlockRules { static func unlocked(config:signals:) -> Set<GameScreen> }`.
- Produces: `GameState.unlockedTabs: Set<GameScreen>` y `GameState.newTabs: Set<GameScreen>`
  (observados), `GameState.unlockedTabsInBarOrder: [GameScreen]`,
  `GameState.markTabOpened(_:)`, `GameState.refreshUnlockedTabs()`,
  `GameState.progressiveTabsEnabled` (`@ObservationIgnored`). E3b T4 usa
  `unlockedTabsInBarOrder` y `markTabOpened`.
- Produces: `GameTabItem.isNew: Bool` (default `false`).

- [ ] **Step 1: La regla pura, en rojo**

`FisuEvolutionTests/TabUnlockRulesTests.swift`:

```swift
import Testing
@testable import FisuEvolution

/// Qué pestañas tiene un jugador según lo que hizo (PLAN-v2 E3, la barra
/// progresiva). Pura: las señales llegan resueltas.
@Suite("Las reglas de desbloqueo de las pestañas")
@MainActor
struct TabUnlockRulesTests {
    private let config = TabsConfig(schemaVersion: 1, tabs: [
        .init(id: "upgrades", unlockWhen: [.always]),
        .init(id: "skins", unlockWhen: [.firstSkin]),
        .init(id: "jobs", unlockWhen: [.always]),
        .init(id: "gifts", unlockWhen: [.tutorialCore, .firstChest]),
        .init(id: "store", unlockWhen: [.secondSession]),
        .init(id: "menu", unlockWhen: [.tutorialCore]),
    ])

    private func signals(core: Bool = false, skin: Bool = false, chest: Bool = false, sessions: Int = 0) -> TabUnlockSignals {
        TabUnlockSignals(tutorialCoreDone: core, ownsAnySkin: skin, hasReceivedChest: chest, sessionsAfterCore: sessions)
    }

    @Test("un jugador nuevo ve sólo Contratar y Mejoras")
    func newPlayerSeesHiringAndUpgrades() {
        #expect(TabUnlockRules.unlocked(config: config, signals: signals()) == [.jobs, .upgrades])
    }

    @Test("el núcleo del tutorial abre Bonus y Menú")
    func coreOpensGiftsAndMenu() {
        #expect(TabUnlockRules.unlocked(config: config, signals: signals(core: true)) == [.jobs, .upgrades, .gifts, .menu])
    }

    @Test("el primer cofre abre Bonus aunque el tutorial siga")
    func firstChestOpensGifts() {
        #expect(TabUnlockRules.unlocked(config: config, signals: signals(chest: true)).contains(.gifts))
    }

    @Test("la primera pinta abre Vestimenta")
    func firstSkinOpensSkins() {
        #expect(TabUnlockRules.unlocked(config: config, signals: signals(skin: true)).contains(.skins))
    }

    @Test("la segunda sesión abre la Tienda")
    func secondSessionOpensTheStore() {
        #expect(!TabUnlockRules.unlocked(config: config, signals: signals(core: true, sessions: 0)).contains(.store))
        #expect(TabUnlockRules.unlocked(config: config, signals: signals(core: true, sessions: 1)).contains(.store))
    }

    @Test("el tabs.json embarcado es válido y cubre las seis pestañas")
    func bundledConfigIsValid() throws {
        let content = try GameContentLoader.load(from: .main)
        try content.tabs.validate()
        #expect(Set(content.tabs.tabs.compactMap(\.screen)) == Set(GameScreen.allCases))
    }

    @Test("una config sin Contratar siempre abierto no valida")
    func hiringMustAlwaysBeOpen() {
        let broken = TabsConfig(schemaVersion: 1, tabs: GameScreen.allCases.map {
            .init(id: $0.rawValue, unlockWhen: [.tutorialCore])
        })
        #expect(throws: GameError.self) { try broken.validate() }
    }
}
```

- [ ] **Step 2: Verla fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/TabUnlockRulesTests`.
Expected: no compila — `cannot find 'TabsConfig' in scope`.

- [ ] **Step 3: El dato y la regla**

`FisuEvolution/Resources/Config/tabs.json`:

```json
{
  "schemaVersion": 1,
  "tabs": [
    { "id": "upgrades", "unlockWhen": ["always"] },
    { "id": "skins", "unlockWhen": ["firstSkin"] },
    { "id": "jobs", "unlockWhen": ["always"] },
    { "id": "gifts", "unlockWhen": ["tutorialCore", "firstChest"] },
    { "id": "store", "unlockWhen": ["secondSession"] },
    { "id": "menu", "unlockWhen": ["tutorialCore"] }
  ]
}
```

`FisuEvolution/Managers/TabUnlocks.swift`:

```swift
import Foundation

/// Cuándo aparece una pestaña de la barra (PLAN-v2 E3). Basta con una de sus
/// condiciones.
enum TabUnlockCondition: String, Codable, Sendable {
    case always
    /// Terminó la fase obligatoria del tutorial.
    case tutorialCore
    /// Tiene al menos una pinta.
    case firstSkin
    /// Recibió al menos un cofre.
    case firstChest
    /// Volvió a abrir el juego después de la sesión del tutorial.
    case secondSession
}

/// Lo que el jugador hizo, resuelto por `GameState+Tabs` desde el save y las
/// banderas del tutorial.
struct TabUnlockSignals: Equatable, Sendable {
    var tutorialCoreDone: Bool
    var ownsAnySkin: Bool
    var hasReceivedChest: Bool
    /// Arranques con la fase obligatoria ya hecha (`tutorial.sessionsAfterPhase`).
    var sessionsAfterCore: Int
}

/// `tabs.json`: qué abre cada pestaña.
struct TabsConfig: Codable, Sendable, Equatable {
    struct Tab: Codable, Sendable, Equatable {
        let id: String
        let unlockWhen: [TabUnlockCondition]

        var screen: GameScreen? { GameScreen(rawValue: id) }
    }

    let schemaVersion: Int
    let tabs: [Tab]

    /// Cada pestaña exactamente una vez, cada una con al menos una condición, y
    /// Contratar siempre abierta: sin ella no hay juego.
    func validate() throws {
        let screens = tabs.compactMap(\.screen)
        guard screens.count == tabs.count, Set(screens) == Set(GameScreen.allCases),
              screens.count == GameScreen.allCases.count else {
            throw GameError.contentInvalid(file: "tabs.json", reason: "tiene que nombrar las seis pestañas una vez")
        }
        if let empty = tabs.first(where: { $0.unlockWhen.isEmpty }) {
            throw GameError.contentInvalid(file: "tabs.json", reason: "\(empty.id) no tiene condición")
        }
        guard tabs.first(where: { $0.screen == GameScreen.centerTab })?.unlockWhen.contains(.always) == true else {
            throw GameError.contentInvalid(file: "tabs.json", reason: "Contratar tiene que estar siempre abierta")
        }
    }

    /// Las que abren desde el arranque: esas nunca llevan "¡Nuevo!".
    var alwaysOpen: Set<GameScreen> {
        Set(tabs.filter { $0.unlockWhen.contains(.always) }.compactMap(\.screen))
    }
}

enum TabUnlockRules {
    static func unlocked(config: TabsConfig, signals: TabUnlockSignals) -> Set<GameScreen> {
        Set(config.tabs.filter { $0.unlockWhen.contains { isMet($0, signals) } }.compactMap(\.screen))
    }

    static func isMet(_ condition: TabUnlockCondition, _ signals: TabUnlockSignals) -> Bool {
        switch condition {
        case .always: true
        case .tutorialCore: signals.tutorialCoreDone
        case .firstSkin: signals.ownsAnySkin
        case .firstChest: signals.hasReceivedChest
        case .secondSession: signals.sessionsAfterCore >= 1
        }
    }
}
```

`GameContentLoader.swift`: en `GameContent`, después de `achievements`, `let tabs: TabsConfig`;
en `load(from:)`, junto a los otros `decode`: `let tabs: TabsConfig = try decode("tabs", from: bundle)`,
antes del `return`: `try tabs.validate()`, y `tabs: tabs` al final del `GameContent(…)`.

- [ ] **Step 4: Verde la regla**

Run: `/opt/homebrew/bin/xcodegen generate` (archivo Swift y recurso nuevos) y Receta R con
`-only-testing:FisuEvolutionTests/TabUnlockRulesTests` → PASS (7).

- [ ] **Step 5: El cableado, en rojo**

`FisuEvolutionTests/TabUnlockWiringTests.swift`:

```swift
import Foundation
import Testing
@testable import FisuEvolution

/// La barra progresiva contra el `GameState` real: qué se publica, qué se
/// guarda y que nunca se vuelve a cerrar.
///
/// ⚠️ Las banderas del tutorial viven en `UserDefaults` y el host de los tests
/// las comparte: cada test las pone y las restaura.
@Suite("Las pestañas progresivas en el GameState", .serialized)
@MainActor
struct TabUnlockWiringTests {
    private func withDefaults(core: Bool, sessions: Int, _ body: @MainActor () async throws -> Void) async rethrows {
        let defaults = UserDefaults.standard
        let savedCore = defaults.object(forKey: "fisuTutorialDone")
        let savedSessions = defaults.object(forKey: GameState.sessionsAfterPhaseKey)
        let savedNew = defaults.object(forKey: GameState.newTabsKey)
        defaults.set(core, forKey: "fisuTutorialDone")
        defaults.set(sessions, forKey: GameState.sessionsAfterPhaseKey)
        defaults.removeObject(forKey: GameState.newTabsKey)
        defer {
            defaults.set(savedCore, forKey: "fisuTutorialDone")
            defaults.set(savedSessions, forKey: GameState.sessionsAfterPhaseKey)
            defaults.set(savedNew, forKey: GameState.newTabsKey)
        }
        try await body()
    }

    @Test("partida nueva: Contratar y Mejoras, sin ¡Nuevo!")
    func freshGame() async {
        await withDefaults(core: false, sessions: 0) {
            let gameState = await makeGameState()
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs == [.jobs, .upgrades])
            #expect(gameState.newTabs.isEmpty, "las que abren desde el arranque no son novedad")
            #expect(gameState.unlockedTabsInBarOrder == [.upgrades, .jobs])
        }
    }

    @Test("terminar el núcleo abre Bonus y Menú, con ¡Nuevo!, y se guarda")
    func coreUnlocksAndPersists() async throws {
        try await withDefaults(core: false, sessions: 0) {
            let gameState = await makeGameState()
            gameState.refreshProjections()
            UserDefaults.standard.set(true, forKey: "fisuTutorialDone")
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs == [.jobs, .upgrades, .gifts, .menu])
            #expect(gameState.newTabs == [.gifts, .menu])
            let saved = try #require(gameState.player?.meta.unlockedTabs)
            #expect(saved.isSuperset(of: ["gifts", "menu"]))

            gameState.markTabOpened(.gifts)
            #expect(gameState.newTabs == [.menu])
        }
    }

    @Test("una pestaña abierta no se vuelve a cerrar")
    func neverCloses() async {
        await withDefaults(core: true, sessions: 0) {
            let gameState = await makeGameState()
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs.contains(.menu))
            UserDefaults.standard.set(false, forKey: "fisuTutorialDone")
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs.contains(.menu))
        }
    }

    @Test("la primera pinta abre Vestimenta")
    func firstSkinOpensSkins() async {
        await withDefaults(core: true, sessions: 0) {
            let gameState = await makeGameState()
            let skin = gameState.content?.skins.skins.first { $0.isMilestone }
            #expect(skin != nil, "el catálogo real tiene skins de milestone")
            gameState.grantMilestoneSkinsForTests([skin?.id].compactMap { $0 })
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs.contains(.skins))
        }
    }

    @Test("apagada (corridas de UI sin el flag), la barra está entera y sin ¡Nuevo!")
    func disabledShowsTheWholeBar() async {
        await withDefaults(core: false, sessions: 0) {
            let gameState = await makeGameState()
            gameState.progressiveTabsEnabled = false
            gameState.refreshProjections()
            #expect(gameState.unlockedTabs == Set(GameScreen.allCases))
            #expect(gameState.newTabs.isEmpty)
        }
    }
}
```

`FisuEvolutionUITests/ProgressiveTabsUITests.swift`:

```swift
import XCTest

/// La barra progresiva (PLAN-v2 E3). Sólo corre con `--uitest-progressive-tabs`:
/// sin el flag, toda corrida de UI ve las seis pestañas (los tests viejos las
/// necesitan).
final class ProgressiveTabsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testUnJugadorNuevoVeSoloContratarYMejoras() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-progressive-tabs"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["hud.upgrades"].exists)
        for hidden in ["hud.skins", "hud.bonus", "hud.store", "hud.settings"] {
            XCTAssertFalse(app.buttons[hidden].exists, "\(hidden) no tendría que estar todavía")
        }
    }

    @MainActor
    func testAlTerminarElNucleoAparecenBonusYMenuConNuevo() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-progressive-tabs"]
        app.launch()
        let gifts = app.buttons["hud.bonus"]
        XCTAssertTrue(gifts.waitForExistence(timeout: 20), "Bonus tendría que estar con el núcleo hecho")
        XCTAssertTrue(app.buttons["hud.settings"].exists)
        XCTAssertFalse(app.buttons["hud.skins"].exists, "Vestimenta espera la primera pinta")
        XCTAssertFalse(app.buttons["hud.store"].exists, "la Tienda espera la segunda sesión")
        // El runner corre en inglés (trampa 6): "new" es el valor de AX del badge.
        XCTAssertTrue((gifts.value as? String)?.contains("new") == true, "Bonus tendría que decir ¡Nuevo!")

        gifts.tap()
        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10))
        XCTAssertFalse((app.buttons["hud.bonus"].value as? String)?.contains("new") == true,
                       "abrirla le saca el ¡Nuevo!")
    }
}
```

- [ ] **Step 6: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/TabUnlockWiringTests` → no compila (`unlockedTabs`,
`newTabsKey`, `markTabOpened` no existen).

- [ ] **Step 7: La proyección y la persistencia**

En `GameState.swift`, junto a `hasPendingChests` (`:233`):

```swift
    /// Las pestañas de la barra que el jugador ya tiene (PLAN-v2 E3). Las escribe
    /// `+Tabs` desde `refreshProjections`, sólo si cambiaron.
    var unlockedTabs: Set<GameScreen> = [.jobs, .upgrades]
    /// Las que se abrieron en esta instalación y todavía no se miraron: llevan
    /// "¡Nuevo!". Las escribe `+Tabs`.
    var newTabs: Set<GameScreen> = []
    /// Con `false` la barra está entera (corridas de UI sin
    /// `--uitest-progressive-tabs`). Lo apaga `+Debug`.
    @ObservationIgnored var progressiveTabsEnabled = true
```

y en `refreshProjections()`, antes de `refreshTutorialTip()`:

```swift
        refreshUnlockedTabs()
```

`FisuEvolution/Game/State/GameState+Tabs.swift`:

```swift
import EconomyKit
import Foundation

/// La barra de abajo progresiva (PLAN-v2 E3): qué pestañas tiene el jugador, el
/// "¡Nuevo!" y la persistencia en `meta.unlockedTabs` (save v6).
extension GameState {
    /// Las abiertas en esta instalación que todavía no se miraron. Vive en
    /// `UserDefaults` y no en el save: es una pista de UI, como las lecciones.
    static let newTabsKey = "tabs.new"

    /// Las pestañas abiertas, en el orden de la barra (y del paginador del menú).
    var unlockedTabsInBarOrder: [GameScreen] {
        GameScreen.barOrder.filter(unlockedTabs.contains)
    }

    /// Lo llama `refreshProjections` a 8 Hz: son cuatro lecturas y unas
    /// operaciones de conjuntos, y escribe sólo si algo cambió.
    func refreshUnlockedTabs() {
        guard let content, var player else { return }
        let earned = progressiveTabsEnabled
            ? TabUnlockRules.unlocked(config: content.tabs, signals: tabSignals(player: player))
            : Set(GameScreen.allCases)
        let saved = Set(player.meta.unlockedTabs.compactMap(GameScreen.init(rawValue:)))
        let fresh = earned.subtracting(saved)
        if !fresh.isEmpty {
            player.meta.unlockedTabs.formUnion(fresh.map(\.rawValue))
            self.player = player
            scheduleSave()
            if progressiveTabsEnabled {
                rememberNew(fresh.subtracting(content.tabs.alwaysOpen))
            }
        }
        let all = saved.union(earned)
        if unlockedTabs != all { unlockedTabs = all }
        let new = storedNewTabs.intersection(all)
        if newTabs != new { newTabs = new }
    }

    /// El jugador abrió la pestaña: se le va el "¡Nuevo!".
    func markTabOpened(_ screen: GameScreen) {
        var stored = storedNewTabs
        guard stored.remove(screen) != nil else { return }
        UserDefaults.standard.set(stored.map(\.rawValue).sorted(), forKey: Self.newTabsKey)
        newTabs.remove(screen)
    }

    func tabSignals(player: PlayerState) -> TabUnlockSignals {
        let defaults = UserDefaults.standard
        return TabUnlockSignals(
            tutorialCoreDone: defaults.bool(forKey: "fisuTutorialDone"),
            ownsAnySkin: !player.meta.allOwnedSkins.isEmpty,
            hasReceivedChest: player.meta.welcomeChestGiven
                || player.meta.chestsPending > 0
                || player.meta.prestigeChestsPending > 0,
            sessionsAfterCore: defaults.integer(forKey: Self.sessionsAfterPhaseKey)
        )
    }

    private var storedNewTabs: Set<GameScreen> {
        Set((UserDefaults.standard.stringArray(forKey: Self.newTabsKey) ?? []).compactMap(GameScreen.init(rawValue:)))
    }

    private func rememberNew(_ screens: Set<GameScreen>) {
        guard !screens.isEmpty else { return }
        let all = storedNewTabs.union(screens)
        UserDefaults.standard.set(all.map(\.rawValue).sorted(), forKey: Self.newTabsKey)
    }
}
```

En `GameState+Debug.swift`, `applyLaunchArgumentDefaults(forceNewGame:)`: en el bloque
`if forceNewGame { … }`, junto a `wipeTutorialLessonProgress()`:

```swift
            defaults.removeObject(forKey: Self.newTabsKey)
```

y al final de la función, después del bloque de `tutorialLessonsAutorun`:

```swift
        // La barra progresiva es nueva de la 2.0: bajo `--uitest*` arranca
        // entera salvo que el test la pida, porque los tests de la v1 tocan las
        // seis pestañas (`testCadaTabAbreSuPantallaYSeCierra`, sin cambios).
        if arguments.contains(where: { $0.hasPrefix("--uitest") }),
           !arguments.contains("--uitest-progressive-tabs") {
            progressiveTabsEnabled = false
        }
```

- [ ] **Step 8: La barra sólo con las abiertas, y el "¡Nuevo!"**

En `GameArtComponents.swift`, `GameTabItem`: sumar `let isNew: Bool` y el parámetro
`isNew: Bool = false` al `init` (con `self.isNew = isNew`). En `GameTabButton.body`, después del
`.overlay(alignment: .topTrailing) { … NotificationBadge … }` y antes del `keyframeAnimator`:

```swift
                .overlay(alignment: .top) {
                    if item.isNew {
                        NewTabBadge()
                            .offset(y: -12)
                    }
                }
```

y el valor de AX pasa a:

```swift
        .accessibilityValue(accessibilityValue)
```

con

```swift
    /// El puntito de cobrar y el "¡Nuevo!", dichos por el botón (trampa 9a:
    /// jamás un elemento de AX adentro del label).
    private var accessibilityValue: Text {
        switch (item.showsBadge, item.isNew) {
        case (true, true): Text("tab.new.ax") + Text(verbatim: ", ") + Text("badge.claimable.ax")
        case (false, true): Text("tab.new.ax")
        case (true, false): Text("badge.claimable.ax")
        case (false, false): Text(verbatim: "")
        }
    }
```

Y, después de `GameTabButton`:

```swift
/// El cartelito de una pestaña recién abierta: cápsula caramelo naranja con
/// "¡Nuevo!". Decoración: lo dice el valor de AX del botón.
private struct NewTabBadge: View {
    var body: some View {
        Text("tab.new.badge")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(PillBackground(fill: Color("PaletteOrange")))
            .fixedSize()
            .accessibilityHidden(true)
    }
}
```

En `BottomMenuBar.swift`:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GameTabBar(items: items) { screen in
            gameState.markTabOpened(screen)
            select(screen)
        }
        // Una pestaña nueva ENTRA (la transición vive en `GameTabBar.zone`);
        // con Reduce Motion, se funde.
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.3),
                   value: gameState.unlockedTabs)
    }

    private var items: [GameTabItem] {
        gameState.unlockedTabsInBarOrder.map { screen in
            GameTabItem(
                screen: screen,
                icon: icon(for: screen),
                labelKey: Self.labelKey(for: screen),
                identifier: screen.identifier,
                prominent: Self.isProminent(screen),
                showsBadge: showsBadge(for: screen),
                isNew: gameState.newTabs.contains(screen)
            )
        }
    }
```

- [ ] **Step 9: Las strings**

`Tools/v2/claves-pendientes/e3a-t9.json`:

```json
{
  "tab.new.badge": {"es": "¡Nuevo!", "en": "New!"},
  "tab.new.ax": {"es": "nuevo", "en": "new"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e3a-t9.json`.

- [ ] **Step 10: Verde y oráculo**

Run: Receta R con `-only-testing:FisuEvolutionTests/TabUnlockRulesTests`,
`TabUnlockWiringTests`, `GameContentValidationTests`, `LocalizationCompletenessTests` → PASS;
UI con `ProgressiveTabsUITests`, `BottomMenuUITests` (**sin cambios**) y `TutorialUITests` →
PASS. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 11: Commit**

```bash
git add FisuEvolution/Resources/Config/tabs.json FisuEvolution/Managers/TabUnlocks.swift \
  FisuEvolution/Managers/GameContentLoader.swift FisuEvolution/Game/State/GameState+Tabs.swift \
  FisuEvolution/Game/State/GameState.swift FisuEvolution/Game/State/GameState+Debug.swift \
  FisuEvolution/UI/HUD/BottomMenuBar.swift FisuEvolution/UI/Art/GameArtComponents.swift \
  FisuEvolutionTests/TabUnlockRulesTests.swift FisuEvolutionTests/TabUnlockWiringTests.swift \
  FisuEvolutionUITests/ProgressiveTabsUITests.swift
# + el catálogo o el snapshot e3a-t9.json, según la ola
git diff --cached --stat
git commit -m "feat(ux): las pestañas de la barra aparecen de a poco, con ¡Nuevo!"
```

---

### Task 10: La escena — `PlayLayout` en el tablero, 3 filas, la cámara continua y el iPad

**Objetivo:** `BoardScene` adopta `PlayLayout`: la celda topeada y el campo centrado en iPad,
las filas según la capacidad (15 lugares = 3 filas, al ~70 % del alto), los textos de SpriteKit
escalados y la foto del reveal con tope de 380 pt; la multitud baja 20 pt porque la barra es
más baja; la escena publica el piso continuo de la cámara (la luz de la botonera lo sigue) y el
marcador `board.layout`. Con 10 lugares en iPhone, el tablero es el de siempre salvo esos 20 pt.

**Files:**
- Modify: `FisuEvolution/Scenes/BoardScene.swift` (`bottomInset`, `horizontalInset`, `crowdTopRatio`, `layoutBoard`, `renderAnchoredSpecials`, `crowdBand`, `revealLayout`, `update`, los `fontSize`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (`cameraFloor`, `boardLayoutMarker`, `publishCameraFloor(_:)`, `publishBoardLayout(_:)`)
- Modify: `FisuEvolution/App/RootView.swift` (marcador `board.layout`)
- Modify: `FisuEvolution/UI/HUD/ElevatorPanel.swift` (`lightPosition`)
- Modify: `FisuEvolutionTests/CrowdDepthTests.swift`, `FisuEvolutionTests/RevealLayoutTests.swift`
- Modify: `FisuEvolutionUITests/AscentRenderingUITests.swift` (el espejo: 118 → 98)
- Create: `FisuEvolutionUITests/IPadLayoutUITests.swift`
- Modify: `Tools/v2/oraculo.sh` (`new_sim` con dispositivo; paso `ipad-ui`)

**Interfaces:**
- Consumes: `PlayLayout` (T3), `GameTabBar.panelHeight` (T7), `ElevatorPanel` (T8). El
  `BoardScene` de E1 T10 (`presentResolution`, `markRevealed`): esta tarea va después.
- Produces: `GameState.cameraFloor: Double`, `GameState.boardLayoutMarker: String` (observados),
  `publishCameraFloor(_:)`, `publishBoardLayout(_:)`; `BoardScene.bottomInset` = 98.
- Borra: `BoardScene.crowdTopRatio` (vive en `PlayLayout.crowdTopRatio(rows:)`) y
  `BoardScene.horizontalInset` (vive en `PlayLayout`).

- [ ] **Step 1: Los tests, en rojo**

`CrowdDepthTests.swift`: las pantallas suman los dos iPad, la profundidad se prueba con 10, 15
y 20 lugares (no sólo con los pisos de hoy, que son todos de 10) y la franja con 2, 3 y 4
filas. El docstring de la cabecera del archivo se conserva; las dos suites quedan:

```swift
@Suite("Profundidad: la multitud nunca cae detrás del fondo")
@MainActor
struct CrowdDepthTests {
    /// De la más chica que soporta la app a la más grande, iPad incluido.
    private let screens: [CGSize] = [
        CGSize(width: 320, height: 568),
        CGSize(width: 375, height: 667),
        CGSize(width: 390, height: 844),
        CGSize(width: 402, height: 874),
        CGSize(width: 430, height: 932),
        CGSize(width: 440, height: 956),
        CGSize(width: 744, height: 1133),
        CGSize(width: 1032, height: 1376),
    ]
    /// Los de hoy (10), los de la crítica de Marco (15) y el permanente de ORO (20).
    private let capacities = [10, 15, 20]

    /// El z más bajo que puede alcanzar un personaje en esa pantalla y capacidad.
    private func lowestCrowdZ(screen: CGSize, capacity: Int) -> CGFloat {
        let layout = PlayLayout(size: screen, capacity: capacity)
        let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: layout.cellSize, rows: layout.rows)
        return BoardScene.fieldBaseZ + BoardScene.depthZ(y: band.topY, rows: layout.rows, cellSize: layout.cellSize)
    }

    private func highestFloorZ() throws -> CGFloat {
        let content = try GameContentLoader.load(from: .main)
        return FloorNode.backgroundZ(ordinal: content.floorTable.floors.count - 1)
    }

    @Test("ningún personaje puede quedar detrás del fondo de su piso")
    func crowdNeverSinksBehindItsFloor() throws {
        let floorZ = try highestFloorZ()
        for capacity in capacities {
            for screen in screens {
                let lowestZ = lowestCrowdZ(screen: screen, capacity: capacity)
                #expect(
                    lowestZ > floorZ,
                    """
                    capacidad \(capacity) en \(screen.width)×\(screen.height): el personaje \
                    más atrás queda en z=\(lowestZ) y el fondo más alto en z=\(floorZ). \
                    Por debajo del fondo se vuelve invisible pero clickeable.
                    """
                )
            }
        }
    }

    @Test("la base del campo entero queda por encima de los fondos")
    func theWholeFieldSitsAboveTheBackgrounds() throws {
        #expect(BoardScene.fieldBaseZ > (try highestFloorZ()))
    }

    @Test("los specials quedan detrás de la multitud y delante del fondo")
    func specialsSitBetweenTheFloorAndTheCrowd() throws {
        let floorZ = try highestFloorZ()
        for capacity in capacities {
            for screen in screens {
                let layout = PlayLayout(size: screen, capacity: capacity)
                let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: layout.cellSize, rows: layout.rows)
                let specialZ = BoardScene.fieldBaseZ
                    + BoardScene.specialZ(band: band, rows: layout.rows, cellSize: layout.cellSize)
                #expect(specialZ < lowestCrowdZ(screen: screen, capacity: capacity))
                #expect(specialZ > floorZ, "un special tampoco puede irse detrás del fondo")
            }
        }
    }

    @Test("el de adelante sigue tapando al de atrás", arguments: [2, 3])
    func nearerCharactersStayInFront(rows: Int) {
        let cell: CGFloat = 74
        let band = BoardScene.crowdBand(sceneHeight: 874, cellSize: cell, rows: rows)
        let front = BoardScene.depthZ(y: band.frontY, rows: rows, cellSize: cell)
        let back = BoardScene.depthZ(y: band.frontY + band.rowDepth, rows: rows, cellSize: cell)
        #expect(front > back, "la fila delantera tiene que dibujarse sobre la trasera")
    }
}

/// La franja por la que camina la multitud llega hasta donde diga
/// `PlayLayout.crowdTopRatio(rows:)`, y el deambular sale derivado de ella.
@Suite("La franja de la multitud")
@MainActor
struct CrowdBandTests {
    private let screens: [CGSize] = [
        CGSize(width: 320, height: 568),
        CGSize(width: 402, height: 874),
        CGSize(width: 440, height: 956),
        CGSize(width: 1032, height: 1376),
    ]

    private func cellSize(screen: CGSize) -> CGFloat {
        PlayLayout(size: screen, capacity: 10).cellSize
    }

    @Test("el techo de la franja cae donde dice el knob", arguments: [2, 3, 4])
    func bandTopFollowsTheRatio(rows: Int) {
        for screen in screens {
            let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: cellSize(screen: screen), rows: rows)
            let onScreen = band.topY + BoardScene.bottomInset
            let expected = screen.height * PlayLayout.crowdTopRatio(rows: rows)
            #expect(
                abs(onScreen - expected) < 0.5,
                "\(rows) filas en \(screen.height) de alto: el techo quedó en \(onScreen) y se esperaba \(expected)"
            )
        }
    }

    @Test("ningún personaje se pasa del techo de la franja", arguments: [2, 3, 4])
    func nobodyWandersPastTheTop(rows: Int) {
        for screen in screens {
            let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: cellSize(screen: screen), rows: rows)
            let backRowTop = band.frontY + band.rowDepth * CGFloat(rows - 1) + band.wanderRange / 2
            #expect(backRowTop <= band.topY + 0.001, "la fila trasera llega a \(backRowTop) y el techo es \(band.topY)")
        }
    }

    @Test("las filas cubren la franja sin dejar un hueco entre ellas", arguments: [2, 3, 4])
    func rowsCoverTheBandWithoutGaps(rows: Int) {
        for screen in screens {
            let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: cellSize(screen: screen), rows: rows)
            let frontRowTop = band.frontY + band.wanderRange / 2
            let backRowBottom = band.frontY + band.rowDepth - band.wanderRange / 2
            #expect(frontRowTop >= backRowBottom - 0.001, "queda un hueco entre \(frontRowTop) y \(backRowBottom)")
        }
    }
}
```

`RevealLayoutTests.swift`, sumar:

```swift
    /// En iPad la foto no crece sin tope: a 380 pt ya es un retrato de cuerpo
    /// entero, y más grande se ve el estirado del arte.
    @Test("en iPad la foto del reveal tiene tope")
    func revealPhotoIsCappedOnIPad() {
        let layout = BoardScene.revealLayout(size: CGSize(width: 1032, height: 1376))
        #expect(layout.photoSide == PlayLayout.revealMaxSide)
    }
```

`FisuEvolutionUITests/IPadLayoutUITests.swift`:

```swift
import XCTest

/// La app universal en el iPad (PLAN-v2 E3): a pantalla completa, sin barras,
/// con el tablero en su celda tope y los textos de la escena escalados.
///
/// Corre sólo en iPad: en el paso `ui` del oráculo (iPhone 16 Pro) se saltea, y
/// el paso `ipad-ui` la corre en un iPad Pro 13" propio.
final class IPadLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "sólo en iPad (paso ipad-ui del oráculo)")
        continueAfterFailure = false
    }

    @MainActor
    func testElJuegoOcupaLaPantallaSinBarras() throws {
        let app = launch()
        let window = app.windows.element(boundBy: 0).frame
        let screen = XCUIScreen.main.screenshot().image.size
        XCTAssertEqual(window.width, screen.width, accuracy: 1,
                       "la ventana mide \(window.width) en una pantalla de \(screen.width): modo compatibilidad")
        XCTAssertEqual(window.height, screen.height, accuracy: 1)
        attach(app, named: "E3 iPad tablero")
    }

    @MainActor
    func testElTableroTopeaLaCeldaYEscalaLosTextos() throws {
        let app = launch()
        let marker = app.otherElements["board.layout"]
        XCTAssertTrue(marker.waitForExistence(timeout: 20))
        let value = try XCTUnwrap(marker.value as? String, "board.layout sin valor")
        // "5x2@112·1.25": columnas x filas @ celda · escala de texto.
        let cell = try XCTUnwrap(Double(value.split(separator: "@")[1].split(separator: "·")[0]), value)
        XCTAssertLessThanOrEqual(cell, 112, value)
        XCTAssertTrue(value.hasSuffix("·1.25"), "los textos de la escena escalan en iPad: \(value)")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-unlock-tower"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 30), "la barra nunca apareció")
        return app
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/CrowdDepthTests -only-testing:FisuEvolutionTests/CrowdBandTests -only-testing:FisuEvolutionTests/RevealLayoutTests`.
Expected: FAIL en `bandTopFollowsTheRatio` con `rows: 3` (la escena todavía usa 0,44) y en
`revealPhotoIsCappedOnIPad` (`photoSide` 846,24). En un iPad Pro 13" con
`-only-testing:FisuEvolutionUITests/IPadLayoutUITests` → FAIL: `board.layout` no existe.

- [ ] **Step 3: La escena adopta `PlayLayout`**

En `BoardScene.swift`:

1. `bottomInset` (`:132-151`) queda, con su docstring reescrito:

```swift
    /// Origen vertical del campo: el borde de arriba del PANEL de la barra
    /// inferior más los 34 pt de safe area de un teléfono con notch, para que la
    /// multitud no camine detrás de la barra. Es `GameTabBar.panelHeight` (64) y
    /// no `barHeight` (84): Contratar sobresale en el centro, pero a los costados
    /// el tablero gana los 20 pt que la barra bajó (PLAN-v2 E3).
    ///
    /// ⚠️ Una constante para todos los tamaños: sin home indicator la barra mide
    /// 12 más (`GameTabBar.minimumBottomGap`) y el error va hacia el lado seguro.
    /// El espejo de `AscentRenderingUITests` es copia a mano y va en el MISMO
    /// commit que este número.
    static let bottomInset: CGFloat = GameTabBar.panelHeight + 34
```

2. Borrar `horizontalInset` (`:152`) y `crowdTopRatio` (`:161-171`, con su docstring).
3. Sumar, junto a `cellSize` (`:51`):

```swift
    /// La geometría vigente; la recalcula `layoutBoard`.
    private var layout = PlayLayout(size: CGSize(width: 390, height: 844), capacity: 10)
```

4. En `layoutBoard()`, el bloque de `boardRows = 2` hasta `fieldNode.position` (`:1214-1224`):

```swift
        layout = PlayLayout(size: size, capacity: floorDef.capacity)
        boardRows = layout.rows
        boardColumns = layout.columns
        cellSize = layout.cellSize
        fieldNode.position = CGPoint(x: layout.fieldX, y: Self.bottomInset + floorOffset)
        gameState.publishBoardLayout(layout.marker)
```

5. En `renderAnchoredSpecials`, la `x` del special de la derecha:

```swift
                x: isLeft ? side * 0.55 : layout.fieldWidth - side * 0.55,
```

6. En `crowdBand(sceneHeight:cellSize:rows:)`:

```swift
        let topY = max(floorY, sceneHeight * PlayLayout.crowdTopRatio(rows: rows) - bottomInset)
```

7. En `revealLayout(size:)`:

```swift
        let side = min(min(size.width * 0.82, size.height * 0.52), available, PlayLayout.revealMaxSide)
```

8. Los siete `fontSize` fijos se multiplican por `layout.textScale`: el número del tap
   (`label.fontSize = (result.isCrit || result.isGolden ? 24 : 17) * layout.textScale`), la
   etiqueta del reveal (`tag.fontSize = 24 * layout.textScale`), el banner
   (`banner.fontSize = 38 * layout.textScale`), el título y la pista del piso nuevo
   (`29 * layout.textScale`, `18 * layout.textScale`) y los dos textos del piso cerrado
   (`25 * layout.textScale`, `17 * layout.textScale`). Buscarlos con
   `grep -n "fontSize = " FisuEvolution/Scenes/BoardScene.swift`: tienen que quedar siete, todos
   con `* layout.textScale`.
9. En `update(_:)`, el bloque del flush:

```swift
        if frameCounter >= Self.hudFlushEveryNFrames {
            frameCounter = 0
            gameState.flushHUD()
            gameState.publishCameraFloor(cameraFloorPosition)
        }
```

y, junto a `depthZ(for:)`:

```swift
    /// El piso donde está la cámara, continuo: 0 en el callejón, 2,5 a mitad de
    /// camino entre el tercero y el cuarto. La luz de la botonera lo sigue.
    private var cameraFloorPosition: Double {
        guard size.height > 0 else { return 0 }
        return Double((cameraNode.position.y - size.height / 2) / size.height)
    }
```

- [ ] **Step 4: `GameState` publica la cámara y el layout; `RootView` el marcador**

`GameState.swift`, junto a `towerNavigation`:

```swift
    /// El piso donde está la cámara, continuo. Lo publica la escena en el flush
    /// de 8 Hz y lo lee la luz de la botonera; se escribe sólo si se movió más de
    /// una centésima, así que con la cámara quieta no invalida nada.
    private(set) var cameraFloor: Double = 0
    /// La geometría del tablero para el marcador `board.layout` de los tests.
    private(set) var boardLayoutMarker = ""

    func publishCameraFloor(_ value: Double) {
        let clamped = max(0, value)
        if abs(cameraFloor - clamped) > 0.01 { cameraFloor = clamped }
    }

    func publishBoardLayout(_ marker: String) {
        if boardLayoutMarker != marker { boardLayoutMarker = marker }
    }
```

`RootView.swift`, después del marcador `board.floor`:

```swift
        // La geometría del tablero ("5x2@112·1.25"), para `IPadLayoutUITests`.
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("board.layout")
                .accessibilityValue(Text(verbatim: gameState.boardLayoutMarker))
        )
```

`ElevatorPanel.swift`:

```swift
    /// Dónde está la luz: la cámara, que viaja entre pisos.
    private var lightPosition: Double { gameState.cameraFloor }
```

- [ ] **Step 5: El espejo de `AscentRenderingUITests`**

En `slot(_:in:)`: `let bottomInset: CGFloat = 98` y el comentario de arriba suma "y de 118 a
98 en E3a (Task 10), cuando la barra bajó 20 pt y el campo pasó a contar el panel
(`GameTabBar.panelHeight`)". El resto
del espejo (5 columnas, 2 filas, 0,44, el campo a 16 pt) sigue valiendo: los pisos tienen 10
lugares.

- [ ] **Step 6: El paso `ipad-ui` del oráculo**

En `Tools/v2/oraculo.sh`, `new_sim` toma el dispositivo como tercer argumento:

```bash
# Deja el UDID en la variable $2. No se usa `$(…)`: en un subshell el simulador
# no llegaría a SIMS y quedaría huérfano al salir. El dispositivo es el tercer
# argumento (por defecto, el iPhone 16 Pro).
new_sim() {
  local udid device="${3:-iPhone 16 Pro}"
  udid=$(xcrun simctl create "oraculo-$1-$$" "$device" "com.apple.CoreSimulator.SimRuntime.iOS-$1") || return 1
  SIMS+=("$udid")
  printf -v "$2" '%s' "$udid"
}
```

y en el bloque `completo`, después de `step store-ui …`:

```bash
  new_sim 26-5 SIMIPAD "iPad Pro 13-inch (M4)" || { note "❌ no se pudo crear el iPad"; exit 1; }
  step ipad-ui run_tests ipad-ui "$SIMIPAD" -only-testing:FisuEvolutionUITests/IPadLayoutUITests
```

⚠️ No editar `oraculo.sh` mientras corre (bash lee el archivo a medida que ejecuta).

- [ ] **Step 7: Verde y oráculo**

Run: Receta R (iPhone) con `CrowdDepthTests`, `CrowdBandTests`, `RevealLayoutTests`,
`BoardGestureTests`, `MergeTargetingTests` → PASS; UI con `AscentRenderingUITests`,
`EconomyLoopUITests`, `BoardGestureUITests`, `ElevatorPanelUITests` → PASS. En un iPad Pro 13"
con el mismo build: `-only-testing:FisuEvolutionUITests/IPadLayoutUITests` → PASS (2).
Capturas de iPhone SE, 16 Pro y iPad al reporte, con el estirado del personaje en el iPad 13"
medido sobre la captura (alto del sprite en px ÷ alto de su textura en el atlas; PLAN-v2 espera
≤ 1,18×; si se pasa, va a "Para el dueño" y no se toca el tope de la celda sin él).
`Tools/v2/oraculo.sh completo` → `VERDE`, con el paso `ipad-ui` nombrando los 2 tests.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/Scenes/BoardScene.swift FisuEvolution/Game/State/GameState.swift \
  FisuEvolution/App/RootView.swift FisuEvolution/UI/HUD/ElevatorPanel.swift \
  FisuEvolutionTests/CrowdDepthTests.swift FisuEvolutionTests/RevealLayoutTests.swift \
  FisuEvolutionUITests/AscentRenderingUITests.swift FisuEvolutionUITests/IPadLayoutUITests.swift \
  Tools/v2/oraculo.sh
git diff --cached --stat
git commit -m "feat(ipad): el tablero con PlayLayout, filas por capacidad y la cámara que sigue la botonera"
```

---

### Task 11: La raíz — el chrome en la columna y las seis hojas con `fisuSheet`

**Objetivo:** lo que queda del chrome en `RootView` entra en la columna de 592 pt (la fila del
atajo y el prestigio, la barra de bonus y el banner del evento) y la hoja de las seis pestañas
pasa por `fisuSheet()`. El guardia de la Task 6 queda total. En iPad, nada de la UI se estira a
los bordes salvo los fondos.

**Files:**
- Modify: `FisuEvolution/App/RootView.swift` (`hudColumn`, `bottomBar`, la hoja de `activeScreen`)
- Modify: `FisuEvolutionTests/SheetPresentationGuardTests.swift` (`pending` vacío)
- Modify: `FisuEvolutionUITests/IPadLayoutUITests.swift` (dos tests más)

**Interfaces:**
- Consumes: `playColumn()` (T4), `fisuSheet()` (T6).
- Produces: nada nuevo. E3b T4 reemplaza la hoja de `activeScreen` por el paginador y conserva
  el `.fisuSheet()`.

- [ ] **Step 1: Los tests, en rojo**

`SheetPresentationGuardTests.swift`: `private static let pending: Set<String> = []` y su
docstring pasa a "Vacío: toda hoja pasa por `fisuSheet()`. Un archivo nuevo acá es una deuda
con nombre, no una excepción."

`IPadLayoutUITests.swift`, sumar:

```swift
    /// El chrome vive en una columna de 592 pt centrada (`PlayColumn`): ningún
    /// control se estira hacia los bordes del iPad.
    @MainActor
    func testElChromeVaEnUnaColumnaCentrada() throws {
        let app = launch()
        let window = app.windows.element(boundBy: 0).frame
        let left = window.midX - 296 - 1
        let right = window.midX + 296 + 1
        for identifier in ["hud.coins.plus", "hud.map", "hud.upgrades", "hud.hire", "hud.settings", "hud.quickhire"] {
            let element = app.buttons[identifier]
            XCTAssertTrue(element.waitForExistence(timeout: 10), "falta \(identifier)")
            XCTAssertGreaterThanOrEqual(element.frame.minX, left, "\(identifier) se sale de la columna por la izquierda")
            XCTAssertLessThanOrEqual(element.frame.maxX, right, "\(identifier) se sale de la columna por la derecha")
        }
    }

    /// Una hoja de la barra se abre como página, se cierra con su X, y el cofre
    /// es un telón a pantalla completa con el video a su tamaño.
    @MainActor
    func testUnaHojaYElCofreEnIPad() throws {
        let app = launch()
        app.buttons["hud.upgrades"].tap()
        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 10))
        attach(app, named: "E3 iPad hoja de Mejoras")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10))

        let chest = XCUIApplication()
        chest.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-chest"]
        chest.launch()
        XCTAssertTrue(chest.otherElements["chest.stage"].waitForExistence(timeout: 30))
        attach(chest, named: "E3 iPad cofre")
    }
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/SheetPresentationGuardTests` → FAIL
(`presentan a mano: ["RootView.swift"]`). En iPad, `IPadLayoutUITests/testElChromeVaEnUnaColumnaCentrada`
→ FAIL en `hud.quickhire` (la fila del atajo va de borde a borde).

- [ ] **Step 3: `RootView`**

En `hudColumn`, la barra de bonus y el banner:

```swift
            if !gameState.activeBonuses.isEmpty {
                ActiveBonusBar(bonuses: gameState.activeBonuses)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .playColumn()
            }
            if let event = gameState.activeEvent, gameState.eventBannerIsVisible {
                EventBannerView(event: event)
                    .playColumn()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
```

En `bottomBar`, la fila del atajo y el prestigio:

```swift
            .padding(.horizontal, Tokens.s8)
            .playColumn()
```

En la hoja de las seis (`.sheet(item: $activeScreen)`), `.presentationBackground(.clear)` pasa
a `.fisuSheet()` y el comentario de arriba dice "El panel del `panelSheet` ES la hoja:
`fisuSheet()` la deja transparente y, en iPad, del tamaño de una página".

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con `SheetPresentationGuardTests` → PASS; UI en iPhone con `BottomMenuUITests`,
`BonusHUDUITests`, `HUDRedesignUITests` → PASS sin cambios; en iPad `IPadLayoutUITests` → PASS
(4). `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/App/RootView.swift FisuEvolutionTests/SheetPresentationGuardTests.swift \
  FisuEvolutionUITests/IPadLayoutUITests.swift
git diff --cached --stat
git commit -m "feat(ipad): el chrome de la raíz en la columna y las seis hojas con fisuSheet"
```

---

### Task 12: Cierre — el juego en castellano en el SE, las capturas de iPad y el oráculo

**Objetivo:** el último pendiente de i18n de E3 (`LocalizationLayoutUITests`: en el iPhone SE y
en castellano, nada se encima ni se sale de la pantalla), el generador de capturas preparado
para el iPad Pro 13" (2064 × 2752) en los dos idiomas, el paso `se-ui` del oráculo y la
verificación de punta a punta de E3a.

**Files:**
- Create: `FisuEvolutionUITests/LocalizationLayoutUITests.swift`
- Modify: `FisuEvolutionUITests/AppStoreScreenshotTests.swift` (doc y nombres por dispositivo)
- Modify: `Tools/v2/oraculo.sh` (paso `se-ui`)

**Interfaces:** ninguna nueva.

- [ ] **Step 1: El test, en rojo contra lo que haya que arreglar**

`FisuEvolutionUITests/LocalizationLayoutUITests.swift`:

```swift
import XCTest

/// El juego en castellano en la pantalla más chica que soportamos (PLAN-v2 E3,
/// i18n). El castellano es más largo que el inglés y el SE es la pantalla más
/// angosta: si algo se encima, es acá.
///
/// No hay forma de ver un texto truncado desde XCUITest; sí de ver dos
/// controles encimados o uno afuera de la pantalla, que es lo que rompe.
/// Corre en todo dispositivo; el paso `se-ui` del oráculo la corre en un SE 3.
final class LocalizationLayoutUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testLaPantallaPrincipalNoSeEnciman() throws {
        let app = launch()
        let screen = app.windows.element(boundBy: 0).frame
        let controls = ["hud.coins.plus", "hud.map", "hud.elevator.display", "hud.quickhire",
                        "hud.upgrades", "hud.skins", "hud.hire", "hud.bonus", "hud.store", "hud.settings"]
            .map { app.buttons[$0] }
        for control in controls {
            XCTAssertTrue(control.waitForExistence(timeout: 10), "falta \(control.identifier)")
            XCTAssertTrue(screen.contains(control.frame.insetBy(dx: 1, dy: 1)),
                          "\(control.identifier) se sale de la pantalla: \(control.frame)")
        }
        for (index, lhs) in controls.enumerated() {
            for rhs in controls.dropFirst(index + 1) {
                XCTAssertFalse(lhs.frame.insetBy(dx: 1, dy: 1).intersects(rhs.frame.insetBy(dx: 1, dy: 1)),
                               "\(lhs.identifier) y \(rhs.identifier) se enciman")
            }
        }
        attach(app, named: "E3 SE en castellano")
    }

    @MainActor
    func testCadaHojaSeAbreYSeCierraEnCastellano() throws {
        let app = launch()
        for tab in ["hud.upgrades", "hud.skins", "hud.hire", "hud.bonus", "hud.store", "hud.settings"] {
            let button = app.buttons[tab]
            XCTAssertTrue(waitUntilHittable(button), "\(tab) nunca quedó tocable")
            button.tap()
            let close = app.buttons["sheet.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 10), "\(tab) no abrió una hoja cerrable")
            XCTAssertTrue(close.isHittable, "la X de \(tab) quedó tapada")
            attach(app, named: "E3 SE castellano \(tab)")
            close.tap()
            XCTAssertTrue(close.waitForNonExistence(timeout: 10))
        }
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(es)", "-AppleLocale", "es_AR",
                               "--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 30))
        return app
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable { return true }
            usleep(200_000)
        }
        return false
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- [ ] **Step 2: Correrlo en el SE**

Run: `simctl create … "iPhone SE (3rd generation)" …` y `-only-testing:FisuEvolutionUITests/LocalizationLayoutUITests`.
Expected: PASS si las tareas anteriores dejaron todo en su lugar. Un rojo acá es un hallazgo:
se arregla en la vista que se encima (con su `minimumScaleFactor` o su `lineLimit`) **en esta
misma tarea**, con el antes y el después en el reporte, y se vuelve a correr.

- [ ] **Step 3: El paso `se-ui` del oráculo**

En `Tools/v2/oraculo.sh`, después del paso `ipad-ui`:

```bash
  new_sim 26-5 SIMSE "iPhone SE (3rd generation)" || { note "❌ no se pudo crear el SE"; exit 1; }
  step se-ui run_tests se-ui "$SIMSE" -only-testing:FisuEvolutionUITests/LocalizationLayoutUITests
```

- [ ] **Step 4: Las capturas de iPad**

En `AppStoreScreenshotTests.swift`:

1. En la doc de "Cómo se corre", sumar después del bloque de iPhone:

```swift
/// Para el iPad (2064 × 2752, el slot de 13" de App Store Connect), el mismo
/// comando con `-destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'`.
/// Los archivos salen con el prefijo del dispositivo (`ipad13-`/`iphone69-`).
```

2. Sumar:

```swift
    /// El slot de App Store Connect de este dispositivo.
    private static var deviceSlot: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "ipad13" : "iphone69"
    }
```

3. En `shoot(_:_:)`: `attachment.name = "\(Self.deviceSlot)-\(name)"`.

- [ ] **Step 5: El oráculo completo, dos veces, y las capturas**

Run: `Tools/v2/oraculo.sh completo --limpio` y, sin tocar nada, `Tools/v2/oraculo.sh completo`.
Expected: `VERDE` las dos, con `ipad-ui` (4 tests) y `se-ui` (2 tests) nombrados. Correr
`AppStoreScreenshotTests` en el iPad Pro 13" y exportar los PNG
(`xcrun xcresulttool export attachments`): tienen que medir 2064 × 2752. Van al reporte; subirlos
a App Store Connect es de E10.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolutionUITests/LocalizationLayoutUITests.swift \
  FisuEvolutionUITests/AppStoreScreenshotTests.swift Tools/v2/oraculo.sh
git diff --cached --stat
git commit -m "test(i18n): el juego en castellano en el SE y las capturas de iPad"
```

- [ ] **Step 7: Documentación (controlador)**

1. `Docs/SESION-<fecha>-v2-e3a.md`: la tabla final por tarea con su commit, lo que midieron los
   spikes y el porqué de cada decisión que no está en el plan.
2. `Docs/HANDOFF.md`: §4 (entrada "E3a — la pantalla"), §5 (universal + iOS 18 ya rige; las
   pestañas progresivas son dato; la barra mide 64 + 20), §7 (las trampas que aparezcan; la de
   `barHeight` que conserva su valor y `panelHeight` que es lo que mide la escena), §9.
3. `Docs/HANDOFF-v2.md:90-91` (dispositivos e iOS mínimo).
4. Journal AVO y `LOCK`; `handoffs/HANDOFF-<fecha>-v2-e3a.md`.

---

## Para el dueño / dudas

Cosas del código que contradicen o no cierran con PLAN-v2 E3. **Ninguna frena**: la ejecución
sigue con el supuesto anotado hasta que el dueño diga otra cosa.

1. **¿Quién pasa los pisos a 15 lugares?** PLAN-v2 pone el dato (`economy.json`
   `floors[].capacity` de 10 a 15) en E2a, detrás de knob y calibrado en E2b, y pone en E3 "15
   lugares en 3 filas". **Supuesto:** E3 deja el tablero listo para cualquier capacidad
   (`PlayLayout`, filas por capacidad, techo por filas, tests con 10/15/20) y **no toca el
   dato**: hasta E2a el juego sigue con 10 lugares y 2 filas al 0,44. Cambiar el dato es un
   cambio de balance y el contrato de pacing lo mide E2b.
2. **"Idéntico en iPhone" contra "los personajes no deambulan debajo de las columnas".** Si la
   columna izquierda de E7b baja hasta la franja de la multitud, el campo tiene que angostarse y
   el golden de iPhone deja de valer. **Supuesto:** las columnas van por encima de la franja (el
   spike S5 lo mide) y `PlayLayout` no reserva márgenes; si E7b necesita uno, lo agrega ahí
   con su test.
3. **Contratar "al centro" con seis pestañas.** Seis no tienen centro: el plan pone Contratar al
   centro exacto con dos a la izquierda (Mejoras, Vestimenta) y tres a la derecha (Bonus,
   Tienda, Menú), cada lado repartido en su mitad. Alternativa: mover el Menú a otro lugar y
   dejar 2 | Contratar | 2.
4. **"Tienda: 2ª sesión".** Se usa el contador que ya existe (`tutorial.sessionsAfterPhase`,
   arranques con el tutorial hecho): la Tienda aparece en el primer arranque después del de
   tutorial (`≥ 1`). La **lección** de Tienda de hoy espera `≥ 2` (una sesión más): E9 las
   alinea cuando reescriba las lecciones de las pestañas.
5. **El "¡Nuevo!" vive en `UserDefaults`, no en el save.** Es una pista de UI (como las
   lecciones) y agregar un campo a `meta` después de E1 obliga a v7. Reinstalar pierde los
   "¡Nuevo!" pendientes; lo desbloqueado sí está en el save.
6. **La botonera: el "punto si hay algo pendiente".** La spec lo ejemplifica con "lleno" y
   "paquete". La luz verde ya es "en marcha" (todos los lugares ocupados, que es lo mismo que
   "lleno"), así que E3 no dibuja un punto aparte: **el punto del paquete lo agrega E5** cuando
   exista el buzón.
7. **Dónde vive la botonera.** El ícono del ascensor (`hud.map`) se queda en la fila del HUD y
   sigue abriendo el mapa; la placa con el display cuelga debajo, contra el borde derecho, y la
   fila del prestigio reserva su alto (el HUD crece ~24 pt en iPhone; el tablero no se mueve).
   Hasta que E4 retire el banner de eventos, el banner pasa por debajo de esa fila.
8. **La pantalla de lanzamiento crema va en `Info.plist`.** La cabecera de ese archivo dice
   "acá sólo lo que la whitelist no puede expresar": el color de `UILaunchScreen` es justamente
   eso (`INFOPLIST_KEY_UILaunchScreen_Generation` genera el diccionario vacío).
9. **El SDK de iOS 27.** `UIRequiresFullScreen` deja de regir y vuelve el error 90474.
   `InfoPlistContractTests.theSDKStillHonorsFullScreen` se pone rojo a propósito ese día; la
   decisión (landscape, sólo iPhone o ventanas) es del dueño.
10. **Los fondos a 2048 px** (PLAN-v2 E3, "Arte") los regenera E8 con el gate humano de
    ChatGPT; este plan no los toca. `PlayLayout` topea la celda, así que los personajes no
    necesitan arte nuevo.
11. **Cuatro filas (20 lugares, el permanente de ORO) usan el mismo 0,70** que tres. Si S5 o
    E6 miden que la fila de atrás queda muy chica, `crowdTopRatio(rows:)` suma un escalón.
