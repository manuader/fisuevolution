# E3b — UX núcleo, las interacciones: atajo, ficha, menú deslizable y compartir · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que el atajo de contratar no desaparezca nunca y se pueda fijar a un personaje, que
la ficha muestre la pinta en grande y se cierre como toda hoja, que el menú se recorra
deslizando sin re-abrir la hoja, y que compartir vuelva a existir en los momentos virales.

**Architecture:** el atajo publica una oferta con motivo (`QuickHireOffer`: `fits`,
`affordable`, `isPinned`, `blocker`) resuelta en un orden fijo —el pin, el mejor que alcanza y
entra, la meta de ahorro, el mejor con piso lleno— y el pin vive en el save
(`meta.quickHirePinnedTypeId`, save v6 de E1). El selector es un overlay, no una hoja. El menú
deslizable es UNA hoja con una sesión de identidad estable y un `ScrollView` paginado de
páginas que conservan su `NavigationStack`; las flechas y los puntos los dibuja `panelSheet`
leyendo un contexto del entorno. Compartir encola un `ShareMoment` y lo ofrece como botón cuando
no hay nada celebrándose; el premio se cobra una vez por momento (`engagement.sharedMoments`).

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit · EconomyKit (SPM puro) · StoreKit 2 · Swift Testing · XCUITest · XcodeGen.

**Fuente:** `Docs/PLAN-v2.md` §4, "E3 — UX núcleo…" (bloques "Atajo v2", "Ficha de
personaje", "Menú deslizable" y "Compartir"), §2 (filas "Atajo (ítem 7)" y "Compartir") y §0.1.
Las decisiones **no se re-litigan**; lo que el código contradice está en "Para el dueño / dudas".

**Hermano:** `2026-10-07-v2-e3a-ux-nucleo.md` (la pantalla). El porqué de la partición está
ahí. Este plan **usa de E3a**: `fisuSheet()` (E3a T6), `GameScreen.barOrder` (E3a T7),
`GameState.unlockedTabsInBarOrder` y `markTabOpened(_:)` (E3a T9), y `Tools/v2/catalogo.py`
(E3a T1). **Usa de E1**: `meta.quickHirePinnedTypeId` y `EngagementState` (E1 T4),
`hire(…, countsAsPurchase:)` y el `+Hiring` de E1 T3/T13, `markRevealed(tier:)` (E1 T9),
`coinReward(seconds:player:content:economy:)` ya `static` (E1 T14) y el parámetro `boosts:` de
`recomputeDerivedEffects` (E1 T2).

## Global Constraints

Las mismas de E3a (`2026-10-07-v2-e3a-ux-nucleo.md`, "Global Constraints"), que valen enteras
acá. En corto:

- Cero warnings, concurrencia estricta, nada de `Timer`; `xcodegen generate` al agregar o
  borrar archivos.
- **Strings es + en en el mismo commit que la vista, por `Tools/v2/catalogo.py`**: cada tarea
  escribe `Tools/v2/claves-pendientes/e3b-tN.json`, lo aplica para correr sus tests y, según la
  ola, commitea el catálogo (y borra el JSON) o sólo el JSON.
- `accessibilityIdentifier` en cada control nuevo, nunca en un contenedor con hijos.
- FisuJobs es la referencia visual: `PanelCard`, `ActionPill`/`PricePill`/`StateBadge`,
  `PillBackground`, `ArtCloseButton` (`sheet.close`). **Nada de alertas ni botones del sistema.**
- Toda animación nueva se apaga con Reduce Motion (fundido en vez de movimiento).
- **Nada nuevo corre bajo `--uitest*` salvo que el test lo pida**: compartir sólo con
  `--uitest-share`.
- Commits en español, `feat(ux): …` / `refactor(ux): …`, **sin `Co-Authored-By`**; staging
  selectivo y `git diff --cached --stat`.
- Al cerrar cada tarea, el controlador integra, corre `oraculo.sh rapido` y documenta
  (`Docs/SESION-<fecha>-v2-e3b.md`, las cuatro ediciones del HANDOFF, journal, handoff).

## Verificación (vale para toda tarea)

La de E3a: `Tools/v2/oraculo.sh rapido` al cerrar cada tarea y `completo` al cerrar las que
tocan UI (todas salvo T5 y T6) y la épica; la **Receta R** (simulador propio por UDID,
DerivedData `$WT/build/DD-e3`, filtro por suite) para el ciclo rojo → verde. ⚠️ Una corrida que
no nombra los tests esperados no probó nada.

## Las referencias de PLAN-v2 E3, verificadas contra el árbol (`4fd77c8`)

| Lo que cita el plan | Dónde está hoy | Estado |
|---|---|---|
| `BestHire` | `GameState+Hiring.swift:79` (tipo), `GameState.swift:195,1011-1012` (proyección), `QuickHireButton.swift`, `GameState+TutorialTips.swift:151`, comentarios de `RootView.swift:498,784`, `BestHireTests.swift` | ✅ (el `bestHire(state:)` de `PacingSimulator` es otra cosa y no se toca) |
| `noHirableMeansNoOffer` | `BestHireTests.swift:336-356` | ✅ pinea "sin contratable no hay botón": pasa a `fullFloorKeepsAnOfferWithFloorFullBlocker` |
| el `if let` del atajo | `QuickHireButton.swift:77` | ✅ |
| mantener presionado 0,45 s "el mismo reloj que el tablero" | `BoardScene.swift:636,653` (`.wait(forDuration: 0.45)`) | ✅ |
| la ficha: retrato ~84 pt, alerta de sistema para despedir | `CharacterSheetView.swift:89-115` (96 pt con plato), `:77-85` (`.alert`) | ✅ |
| `testCadaTabAbreSuPantallaYSeCierra` | `BottomMenuUITests.swift:42-81` | ✅ tiene que seguir verde sin cambios |
| el intersticial al cerrar una hoja | `RootView.swift:248-258` (`onChange(of: activeScreen)`) | ✅ hoy: uno por hoja cerrada |
| "nada llama a `offerShareCard` desde julio" | `GameState+Bonus.swift:324-331`, sin llamadores | ✅ y `registerShareCompleted` (`:594-609`) sólo lo llama la hoja |
| `ach_share_1`, `viral.json` (+0,5 %, tope 20) | `achievements.json:535`, `Config/viral.json` | ✅ |
| `PagerChevronLabel` | privado en `CharacterSheetView.swift:309-331` | se muda a `GameArtComponents` (T2) |

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `FisuEvolution/UI/Popups/CharacterSheetView.swift` | la ficha, reescrita | 2 |
| `FisuEvolution/UI/Art/GameConfirmCard.swift` | **nuevo** — la confirmación de la casa | 2 |
| `FisuEvolution/UI/Art/GameArtComponents.swift` | `PagerChevronButton` (mudado de la ficha) | 2 |
| `FisuEvolution/UI/Art/GameArt.swift` | `PanelTitleBanner(verbatim:)` | 2 |
| `FisuEvolution/UI/DebugPanelView.swift` | puertas de test: ficha, atajo, compartir | 2, 8, 9 |
| `FisuEvolution/UI/Menu/MenuPagerView.swift` | **nuevo** — el paginador, `MenuPage`, `MenuPagerContext`, `PagerDots` | 3 |
| `FisuEvolution/Game/State/GameState+Menu.swift` | **nuevo** — `menuDidOpen` / `menuPageChanged` / `menuDidClose` | 3, 4 |
| `FisuEvolution/UI/Art/PanelFrames.swift` | flechas y puntos del paginador en `panelSheet` | 3 |
| `FisuEvolution/UI/Menu/MenuView.swift` | bloquea el paginador con un destino empujado | 3 |
| `FisuEvolution/App/RootView.swift` | la sesión de menú; el selector; el botón de compartir | 4, 5, 8, 9 |
| `FisuEvolution/Game/State/GameState+Hiring.swift` | `QuickHireOffer` v2, pin, entradas del selector | 5, 6 |
| `FisuEvolution/Game/State/GameState.swift` | `quickHireOffer`; `shareOffer`, `shareCardMoment` | 5, 9 |
| `FisuEvolution/UI/HUD/QuickHireButton.swift` | nunca desaparece; mantener presionado | 5, 7 |
| `FisuEvolution/UI/HUD/QuickHirePicker.swift` | **nuevo** — el selector | 8 |
| `FisuEvolution/Game/State/ShareMoment.swift` | **nuevo** — los momentos virales | 9 |
| `FisuEvolution/Game/State/GameState+Share.swift` | **nuevo** — encolar, ofrecer, cobrar | 9 |
| `FisuEvolution/UI/Share/ShareMomentChip.swift` | **nuevo** — el botón de compartir | 9 |
| `FisuEvolution/UI/Share/ShareCardView.swift` | la tarjeta por momento | 9 |
| `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift` | `sharedMoments` | 9 |
| tests | `CharacterSheetUITests`, `MenuSessionTests`, `MenuPagerUITests`, `QuickHireOfferTests` (ex `BestHireTests`), `QuickHireButtonUITests`, `QuickHireUITests`, `ShareMomentTests`, `EngagementStateTests`, `ShareMomentUITests` | 2–9 |

## Orden, olas y paralelismo

**Archivos calientes** (un solo dueño por ola): `GameState.swift`, `RootView.swift`,
`BoardScene.swift`, `ContentSystems.swift`, `GameState+Bonus.swift`, `PlayerState.swift`,
`TowerActions.swift`, `SettingsView.swift`, `Localizable.xcstrings`, `project.yml`. **Tibios**
(E1 los toca en alguna tarea): `GameState+Hiring.swift` (E1 T3, T13), `GameState+Debug.swift`,
`GameState+Celebrations.swift`, `GameState+BoardChanges.swift` (E1 T9, T14),
`ContentConfigs.swift` (E1 T8, T11, T13, T15).

| T | Archivos | 🔥 calientes | Tibios | Depende de |
|---|---|---|---|---|
| 1 | ninguno (spikes S2, S3) | — | — | — |
| 2 | `CharacterSheetView.swift`, `GameConfirmCard.swift`, `GameArtComponents.swift`, `GameArt.swift`, `DebugPanelView.swift`, `CharacterSheetUITests.swift`, `UpgradesMenuUITests.swift`, catálogo | catálogo | — | E3a T6 (`fisuSheet`, y es dueña de `CharacterSheetView` antes), E3a T7 (`GameArtComponents`) |
| 3 | `MenuPagerView.swift`, `GameState+Menu.swift`, `PanelFrames.swift`, `MenuView.swift`, `MenuSessionTests.swift`, catálogo | catálogo | — | T2 (`PagerChevronButton`), E3a T8 (`PanelFrames`) |
| 4 | `RootView.swift`, `GameState+Menu.swift`, `MenuPagerUITests.swift` | `RootView.swift` | — | T3, E3a T9, E3a T11 |
| 5 | `GameState.swift`, `RootView.swift` (comentarios), `GameState+Hiring.swift`, `QuickHireButton.swift`, `GameState+TutorialTips.swift`, `QuickHireOfferTests.swift` | `GameState.swift`, `RootView.swift` | `+Hiring` | ventana sin E1 en `GameState.swift`/`+Hiring` |
| 6 | `GameState+Hiring.swift`, `QuickHireOfferTests.swift` | — | `+Hiring` | T5, **E1 T4** (el pin), **E1 T13** (último en `+Hiring`) |
| 7 | `QuickHireButton.swift`, `QuickHireButtonUITests.swift`, catálogo | catálogo | — | T6 |
| 8 | `QuickHirePicker.swift`, `RootView.swift`, `DebugPanelView.swift`, `QuickHireUITests.swift`, catálogo | `RootView.swift`, catálogo | — | T7, T4 (las dos tocan `RootView`) |
| 9 | ver la tarea (14 archivos) | `GameState.swift`, `GameState+Bonus.swift`, `RootView.swift`, catálogo | `+BoardChanges`, `+Debug`, `ContentConfigs` | **E1 cerrada (T16)**, T8 |

```
Ola 1 (fría, con E3a T2)        T1 spikes S2/S3
Ola 3–4 (fría, tras E3a T6/T7)   T2 la ficha
Ola 4–5 (fría, tras E3a T8)      T3 el menú deslizable, las piezas
── calientes ──
ventana de GameState.swift      T5 renombre → T6 oferta v2 (tras E1 T13) → T7 botón (fría)
tras E3a T11                    T4 el menú montado → T8 el selector   (RootView, de a uno)
tras E1 T16                     T9 compartir
```

Mismas reglas de paralelismo que E3a (worktree aislado por tarea, integración de a una,
≤ 3 compilando, `NEEDS_CONTEXT` ante un caliente ajeno).

## Helpers de test que EXISTEN (usar éstos, no inventar)

Los de E3a, más:

| Necesidad | Qué usar | Dónde |
|---|---|---|
| Reloj de anuncios controlable | `TestClock` (`read`, `advance(by:)`) | `FisuEvolutionTests/AdFormatsTests.swift:158` (interno) |
| Proveedor de anuncios que anota lo que muestra | `ScriptedAdsProvider` (`shown`) | `AdFormatsTests.swift:174` (interno) |
| Saldo a mano | `giveCoins(_:to:)` (privado: copiarlo) | `BestHireTests.swift:43-47` |
| Escenario "Senior pagable" | `debugUnlockFloors(throughTier: 13)` + `debugMarkTypesSeen(throughTier: 12)` + `debugSetMaxTier(18)` + 400.000.000.000 de saldo | `BestHireTests.theOfferIsTheHighestPayableTier` |
| Abrir el panel de debug en un test de UI | `app.buttons["hud.debug"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()` | `TutorialUITests.swift:578-580` |

---

### Task 1: Ola 0 — los spikes de las interacciones (S2, S3)

**Objetivo:** medir, antes de construir, las dos cosas de las que depende el diseño del menú
deslizable y del atajo. Sin commit de producto: se mide, se descarta y se reporta al
controlador. Corre junto con E3a T2.

**Files:** ninguno commiteado. Capturas y logs en `build/spikes-e3b/`.

- [ ] **Step 1: S2 — el paginador contra el carrusel de Pintas**

Pregunta: dentro de un `ScrollView(.horizontal)` con `.scrollTargetBehavior(.paging)`, una
página con su propio `ScrollView(.horizontal)` (el carrusel de caras de `CustomizationView`,
`:125-185`), ¿el carrusel gana el gesto dentro de su cuadro y el paginador lo gana afuera? Con
la hoja abierta, ¿el arrastre vertical para cerrar sigue andando?

Cómo: el `MenuPagerView` de la Task 3 (o un prototipo con las seis vistas en un
`LazyHStack` + `.containerRelativeFrame(.horizontal)` + `.scrollPosition(id:)`) montado en
lugar de la hoja de `activeScreen` en `RootView`. En el 16 Pro y el SE: deslizar sobre el
carrusel de Pintas, sobre las tarjetas de abajo, y hacia abajo desde la cabecera.

Criterio: el carrusel se mueve sin cambiar de página; afuera de él se cambia de página; el
arrastre vertical cierra. **Si el carrusel pierde el gesto**, la página de Pintas lleva
`.scrollDisabled(…)` del paginador mientras el dedo está en el carrusel
(`simultaneousGesture(DragGesture(minimumDistance: 0))` sobre el carrusel que avisa por el
contexto) — el reporte trae cuál de los dos hizo falta.

- [ ] **Step 2: S3 — mantener presionado un `Button`**

Pregunta: un `Button` con `.simultaneousGesture(LongPressGesture(minimumDuration: 0.45))`,
¿dispara su acción al soltar después de un mantener? ¿Y `XCUIElement.press(forDuration: 0.9)`
reproduce lo mismo en el runner?

Cómo: en `QuickHireButton`, un `print("tap")` en la acción y `print("long")` en el
`onEnded` del gesto; probar a mano en el simulador y con un test de UI descartable.

Criterio y consecuencia: **si dispara al soltar** (lo esperado), la bandera de la Task 7 que
anula ese toque es necesaria tal cual está escrita; si NO dispara, la bandera sobra y la Task 7
la omite (el reporte lo dice). En los dos casos, el `press(forDuration:)` tiene que abrir el
selector en el runner.

- [ ] **Step 3: El reporte al controlador**

Respuesta, números, capturas y qué cambia en T3 o T7. Sin commit.

---

### Task 2: La ficha de personaje — la pinta en grande, con el andamio de FisuJobs

**Objetivo:** la ficha se rehace como una pantalla de la casa: `NavigationStack` +
`panelSheet` + la X (`sheet.close`), el nombre en la cabecera, la pinta en grande (216–248 pt,
~2,6× la de la v1, sin arte nuevo) que se cambia deslizando, con flechas a los costados y una
tira de miniaturas. Ponérsela es un `ActionPill` —o el estado "Puesta", nunca un botón
deshabilitado—; comprarla es un `PricePill`; despedir pide confirmación con una
`GameConfirmCard` propia, no con la alerta del sistema.

**Files:**
- Modify: `FisuEvolution/UI/Popups/CharacterSheetView.swift` (entero)
- Create: `FisuEvolution/UI/Art/GameConfirmCard.swift`
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (`PagerChevronButton`, `PagerChevronLabel`)
- Modify: `FisuEvolution/UI/Art/GameArt.swift` (`PanelTitleBanner`)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (sección "Ficha")
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (snapshot `e3b-t2.json`)
- Create: `FisuEvolutionUITests/CharacterSheetUITests.swift`
- Modify: `FisuEvolutionUITests/UpgradesMenuUITests.swift` (`testCharacterSheetNoLongerSellsPassiveIncome`)

**Interfaces:**
- Consumes: `fisuSheet()` (E3a T6); `GameState.skinOptions(forCharacterType:)`, `ownsSkin(_:)`,
  `activeSkinID(forCharacterType:)`, `equipSkin(id:forCharacterType:)`,
  `skinDisplayName(for:)`, `dismissCharacter(atCell:)`, `presentCharacterSheet(cellIndex:)`.
- Produces: `struct GameConfirmCard: View` (`titleKey`, `message: Text`, `confirmTitleKey`,
  `confirmSystemImage`, `confirmTint`, `cancelTitleKey`, `onConfirm`, `onCancel`; ids
  `confirm.accept` y `confirm.cancel`). E9 la reusa en el reset.
- Produces: `struct PagerChevronButton: View` (`direction: .previous | .next`, `identifier`,
  `action`). La Task 3 la usa en el paginador.
- Produces: `PanelTitleBanner(verbatim:icon:)`.
- Produces: ids `character.portrait` (marcador, valor = id de la pinta), `character.skin.thumb.<id>`,
  `character.skin.wearing`; se conservan `character.skin.previous`, `.next`, `.equip`,
  `character.dismiss`, `character.skin.buy`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionUITests/CharacterSheetUITests.swift`:

```swift
import XCTest

/// La ficha de personaje (PLAN-v2 E3): la pinta en grande, la X de la casa, y
/// despedir con la confirmación propia del juego — nunca una alerta del sistema.
final class CharacterSheetUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaPintaVaEnGrandeYLaFichaSeCierraConLaX() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-open-sheet"]
        app.launch()

        let portrait = app.otherElements["character.portrait"]
        XCTAssertTrue(portrait.waitForExistence(timeout: 15), "la ficha no mostró su retrato")
        XCTAssertGreaterThanOrEqual(portrait.frame.height, 200, "la pinta tiene que verse en grande")
        XCTAssertGreaterThanOrEqual(portrait.frame.width, 200)
        attach(app, named: "E3 ficha grande")

        let base = portrait.value as? String
        app.buttons["character.skin.next"].tap()
        let changed = NSPredicate(format: "value != %@", base ?? "")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: changed, evaluatedWith: portrait)], timeout: 3),
                       .completed, "la flecha no cambió de pinta")

        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.exists, "la ficha se cierra con la X de la casa")
        close.tap()
        XCTAssertTrue(portrait.waitForNonExistence(timeout: 8))
    }

    @MainActor
    func testDespedirPideLaTarjetaDeLaCasaYNoUnaAlerta() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"]
        app.launch()
        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 20))

        // La puerta de debug contrata un segundo Fisura y abre la ficha del
        // primero: con uno solo, despedir no existe.
        let debugKey = app.buttons["hud.debug"]
        XCTAssertTrue(debugKey.waitForExistence(timeout: 6))
        debugKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let open = app.buttons["debug.sheet.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 6))
        open.tap()

        let dismissButton = app.buttons["character.dismiss"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 10), "la ficha no ofreció despedir")
        XCTAssertEqual(units.value as? String, "2")

        dismissButton.tap()
        let accept = app.buttons["confirm.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 3), "despedir tiene que pedir confirmación")
        XCTAssertEqual(app.alerts.count, 0, "nunca la alerta del sistema")
        attach(app, named: "E3 confirmación de la casa")

        app.buttons["confirm.cancel"].tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 3))
        XCTAssertTrue(dismissButton.exists, "cancelar deja la ficha como estaba")

        dismissButton.tap()
        XCTAssertTrue(accept.waitForExistence(timeout: 3))
        accept.tap()
        XCTAssertTrue(dismissButton.waitForNonExistence(timeout: 8), "despedir cierra la ficha")
        let one = NSPredicate(format: "value == %@", "1")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: one, evaluatedWith: units)], timeout: 5), .completed)
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

En `UpgradesMenuUITests.testCharacterSheetNoLongerSellsPassiveIncome`: la espera inicial pasa a
`app.buttons["character.skin.next"]` (con la pinta base puesta, "Puesta" es un estado y no un
botón) y la verificación final a:

```swift
        let known: Set<String> = [
            "character.skin.previous",
            "character.skin.next",
            "character.skin.equip",
            "character.skin.buy",
            "character.dismiss",
        ]
        let sheetButtons = app.scrollViews.firstMatch.buttons
        let identifiers = Set((0 ..< sheetButtons.count).map { sheetButtons.element(boundBy: $0).identifier })
        XCTAssertFalse(identifiers.isEmpty, "la ficha no expuso ningún control: el query no encontró la hoja")
        // Las miniaturas de la tira son controles de pintas: se aceptan por prefijo.
        let unknown = identifiers.filter { !known.contains($0) && !$0.hasPrefix("character.skin.thumb.") }
        XCTAssertTrue(unknown.isEmpty,
                      "la ficha tiene controles que no son de skins (\(unknown)); el pasivo se compra en el menú")
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionUITests/CharacterSheetUITests`.
Expected: FAIL — `character.portrait` no existe (y el segundo, `debug.sheet.open` no existe).

- [ ] **Step 3: `PagerChevronButton` y `PanelTitleBanner(verbatim:)`**

En `GameArtComponents.swift`, después de `ActionPill`:

```swift
// MARK: - PagerChevronButton

/// Las flechas ‹ › de un paginador de la casa (la ficha, el menú deslizable):
/// plato crema con borde marrón. Sin vuelta en los extremos: el llamador pone
/// `.disabled` y la cara lo dibuja leyendo `isEnabled`, sin el atenuado del
/// sistema (que deja el glifo ilegible).
struct PagerChevronButton: View {
    enum Direction {
        case previous
        case next
    }

    let direction: Direction
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PagerChevronLabel(systemName: direction == .previous ? "chevron.left" : "chevron.right")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(labelKey))
    }

    /// Escritas enteras: armar la clave por interpolación no la resuelve (trampa 5).
    private var labelKey: LocalizedStringKey {
        switch direction {
        case .previous: "pager.previous.ax"
        case .next: "pager.next.ax"
        }
    }
}

private struct PagerChevronLabel: View {
    let systemName: String
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(Color("PaletteInk").opacity(isEnabled ? 1 : 0.3))
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(Color("PaletteCream"))
                    .overlay(
                        Circle().strokeBorder(
                            Color("PaletteBrown").opacity(isEnabled ? 0.7 : 0.3),
                            lineWidth: 2
                        )
                    )
            )
            .contentShape(Circle())
    }
}
```

En `GameArt.swift`, `PanelTitleBanner`: `let titleKey: LocalizedStringKey` pasa a
`private let title: Text`, con dos `init`, y el `Text(titleKey)` del `body` pasa a `title`:

```swift
struct PanelTitleBanner: View {
    private let title: Text
    var icon: AnyView?

    init(titleKey: LocalizedStringKey, icon: AnyView? = nil) {
        self.title = Text(titleKey)
        self.icon = icon
    }

    /// Para un título ya resuelto (el nombre de un personaje): pasarlo como
    /// clave buscaría una traducción que no existe (trampa 5).
    init(verbatim title: String, icon: AnyView? = nil) {
        self.title = Text(verbatim: title)
        self.icon = icon
    }
```

- [ ] **Step 4: `GameConfirmCard`**

`FisuEvolution/UI/Art/GameConfirmCard.swift`:

```swift
import SwiftUI

/// La confirmación de la casa (PLAN-v2 E3): una `PanelCard` sobre un velo, con
/// el título, el detalle y dos salidas. Reemplaza a la alerta del sistema, que
/// era lo único del juego que se veía de otra app. La reusa el reset de E9.
///
/// Va como `.overlay` de la pantalla que pregunta y no como otra hoja: una hoja
/// sobre otra apila dos marcos, y el arrastre podría cerrarla a medias.
struct GameConfirmCard: View {
    let titleKey: LocalizedStringKey
    let message: Text
    let confirmTitleKey: LocalizedStringKey
    let confirmSystemImage: String
    /// Rosa para lo destructivo (despedir, resetear), como la firma de la casa.
    var confirmTint: Color = Color("PalettePink")
    let cancelTitleKey: LocalizedStringKey
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)
            PanelCard {
                VStack(spacing: Tokens.s12) {
                    Text(titleKey)
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                        .multilineTextAlignment(.center)
                    message
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk").opacity(0.75))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    ActionPill(
                        titleKey: confirmTitleKey,
                        systemImage: confirmSystemImage,
                        tint: confirmTint,
                        identifier: "confirm.accept",
                        action: onConfirm
                    )
                    // La salida silenciosa no compite con la acción: texto
                    // tinta pelado, como "Ahora no" en la tarjeta de compartir.
                    Button(action: onCancel) {
                        Text(cancelTitleKey)
                            .font(Tokens.body)
                            .foregroundStyle(Color("PaletteInk").opacity(0.75))
                            .padding(.vertical, Tokens.s8)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("confirm.cancel")
                }
            }
            .frame(maxWidth: 360)
            .padding(Tokens.s24)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }
}
```

- [ ] **Step 5: La ficha**

`FisuEvolution/UI/Popups/CharacterSheetView.swift`, entero (el `CharacterPortrait` privado del
final del archivo actual se conserva tal cual; `PagerChevronLabel` y `EquipButtonLabel` se
borran). El estado "Puesta" usa la clave de Pintas (`skins.equipped`), así las dos pantallas
dicen lo mismo; `character.skin.equipped` queda sin uso y no se borra acá (sería editar el
catálogo a mano):

```swift
import EconomyKit
import StoreKit
import SwiftUI

/// La ficha de un personaje: su pinta en grande, cambiarla y despedirlo
/// (PLAN-v2 E3). Es una pantalla con el andamio de FisuJobs —`NavigationStack`
/// + `panelSheet` + la X de la casa— y no una tarjeta suelta.
///
/// El pasivo **no se compra acá** (RF-04): lo vende cada fila de Mejoras.
struct CharacterSheetView: View {
    @Environment(GameState.self) private var gameState
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let sheet: GameState.CharacterSheet
    @State private var selectedID = SkinOption.baseID
    @State private var confirmingDismissal = false

    /// La pinta en grande: hasta 248 pt (216 en el SE), ~2,6× la de la v1.
    static let portraitMaxSide: CGFloat = 248

    private struct SkinOption: Identifiable {
        static let baseID = "base"
        let skin: SkinsConfig.Entry?
        var id: String { skin?.id ?? Self.baseID }
    }

    private var options: [SkinOption] {
        [SkinOption(skin: nil)] + gameState.skinOptions(forCharacterType: sheet.type.id).map(SkinOption.init)
    }

    private var selectedIndex: Int { options.firstIndex { $0.id == selectedID } ?? 0 }
    private var selected: SkinOption { options[selectedIndex] }

    var body: some View {
        // Proyección observada: entitlements, milestones y equipar refrescan la
        // ficha sin observar `PlayerState`.
        let _ = gameState.skinSelectionVersion
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.s16) {
                    pager
                    names
                    thumbnails
                    action
                    dismissal
                }
                .padding(.horizontal, WoodPanelBackground.columnInset)
                .padding(.top, Tokens.s8)
                .padding(.bottom, Tokens.s24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .panelSheet { header }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
        .overlay {
            if confirmingDismissal {
                GameConfirmCard(
                    titleKey: "character.dismiss.title",
                    message: Text("character.dismiss.message"),
                    confirmTitleKey: "character.dismiss.confirm",
                    confirmSystemImage: "person.fill.xmark",
                    cancelTitleKey: "character.dismiss.cancel",
                    onConfirm: {
                        gameState.dismissCharacter(atCell: sheet.cellIndex)
                        dismiss()
                    },
                    onCancel: { confirmingDismissal = false }
                )
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: confirmingDismissal)
        .fisuSheet()
        .onAppear { selectActiveSkin() }
    }

    // MARK: Cabecera

    private var header: some View {
        VStack(spacing: Tokens.s4) {
            PanelTitleBanner(verbatim: sheet.type.localizedName)
            // Los Int se interpolan como %lld y no matchean la clave declarada
            // con %@: van como String.
            Text("character.count \(String(sheet.instanceCount))")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
        }
    }

    // MARK: La pinta en grande

    private var pager: some View {
        HStack(spacing: Tokens.s8) {
            PagerChevronButton(direction: .previous, identifier: "character.skin.previous") { move(by: -1) }
                .disabled(selectedIndex == 0)
            TabView(selection: $selectedID) {
                ForEach(options) { option in
                    CharacterPortrait(type: sheet.type, treatment: treatment(for: option), asSilhouette: !owns(option))
                        .padding(Tokens.s16)
                        .tag(option.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: Self.portraitMaxSide)
            .aspectRatio(1, contentMode: .fit)
            .background(portraitPlate)
            // El marcador del test de UI: el tamaño real del retrato y qué pinta
            // muestra (de FONDO, como `board.units`).
            .background(
                Color.clear
                    .accessibilityElement()
                    .accessibilityIdentifier("character.portrait")
                    .accessibilityValue(Text(verbatim: selectedID))
            )
            PagerChevronButton(direction: .next, identifier: "character.skin.next") { move(by: 1) }
                .disabled(selectedIndex == options.count - 1)
        }
    }

    private var portraitPlate: some View {
        RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
            .fill(Color("PaletteYellow").opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                    .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
            )
    }

    private var names: some View {
        VStack(spacing: 3) {
            Text(verbatim: skinName(selected))
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteInk"))
            Text("character.skin.index \(String(selectedIndex + 1)) \(String(options.count))")
                .font(Tokens.caption)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk").opacity(0.65))
        }
    }

    // MARK: La tira de miniaturas

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.s8) {
                ForEach(options) { option in
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) { selectedID = option.id }
                    } label: {
                        thumbnail(option)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("character.skin.thumb.\(option.id)")
                    .accessibilityLabel(Text(verbatim: skinName(option)))
                    .accessibilityAddTraits(option.id == selectedID ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, Tokens.s4)
        }
    }

    private func thumbnail(_ option: SkinOption) -> some View {
        let isSelected = option.id == selectedID
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return CharacterPortrait(type: sheet.type, treatment: treatment(for: option), asSilhouette: !owns(option))
            .padding(4)
            .frame(width: 52, height: 52)
            .background(shape.fill(Color("PaletteYellow").opacity(isSelected ? 0.55 : 0.2)))
            .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(isSelected ? 0.9 : 0.4), lineWidth: isSelected ? 2.5 : 1.5))
    }

    // MARK: Ponérsela o comprarla

    @ViewBuilder private var action: some View {
        if owns(selected) {
            if isActive(selected) {
                StateBadge(
                    text: String(localized: "skins.equipped"),
                    systemImage: "checkmark.circle.fill",
                    textAlignment: .center,
                    muted: true
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("character.skin.wearing")
            } else {
                ActionPill(
                    titleKey: "character.skin.equip",
                    systemImage: "tshirt.fill",
                    tint: Color("PaletteBlue"),
                    identifier: "character.skin.equip",
                    accessibilityLabel: Text("character.skin.equip.ax \(skinName(selected))")
                ) {
                    gameState.equipSkin(id: selected.skin?.id, forCharacterType: sheet.type.id)
                }
            }
        } else {
            lockedDetails
        }
    }

    @ViewBuilder private var lockedDetails: some View {
        Label("character.skin.locked", systemImage: "lock.fill")
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Color("PaletteInk"))
        Text(unlockDescription)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color("PaletteInk").opacity(0.75))
            .multilineTextAlignment(.center)
        if let product = selected.skin.flatMap(product(for:)) {
            PricePill(
                text: product.displayPrice,
                currency: .money,
                affordable: true,
                identifier: "character.skin.buy",
                accessibilityPurpose: Text("skins.buy.ax \(skinName(selected))")
            ) {
                Task { await store.purchase(product) }
            }
        }
    }

    // MARK: Despedir

    @ViewBuilder private var dismissal: some View {
        if sheet.canDismiss {
            // Destructivo pero subordinado: cápsula crema con la firma rosa, no
            // la pill llena — despedir no compite con ponérsela.
            Button { confirmingDismissal = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill.xmark")
                        .font(.system(size: 14, weight: .black))
                    Text("character.dismiss")
                        .font(Tokens.body)
                }
                .foregroundStyle(Color("PalettePink").deepened(0.25))
                .padding(.horizontal, Tokens.s12)
                .padding(.vertical, Tokens.s8)
                .frame(maxWidth: .infinity)
                .background(
                    PillBackground(
                        fill: Color("PaletteCream"),
                        border: Color("PalettePink").deepened(0.15).opacity(0.75)
                    )
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("character.dismiss")
        }
    }

    // MARK: Datos

    private func owns(_ option: SkinOption) -> Bool {
        option.skin.map { gameState.ownsSkin($0.id) } ?? true
    }

    private func isActive(_ option: SkinOption) -> Bool {
        gameState.activeSkinID(forCharacterType: sheet.type.id) == option.skin?.id
    }

    private func treatment(for option: SkinOption) -> SkinResolver.Treatment {
        SkinResolver.treatment(
            for: option.skin?.id,
            characterType: sheet.type.id,
            config: gameState.content?.skins ?? SkinsConfig(schemaVersion: 1, skins: [])
        )
    }

    private func skinName(_ option: SkinOption) -> String {
        guard let skin = option.skin else { return String(localized: "character.skin.base") }
        return gameState.skinDisplayName(for: skin)
    }

    private var unlockDescription: String {
        guard let skin = selected.skin else { return "" }
        if let floor = skin.floorReached {
            return String(localized: "character.skin.reach-floor \(TowerNaming.floorName(for: floor))")
        }
        if let lives = skin.reincarnations { return String(localized: "character.skin.reincarnations \(String(lives))") }
        return String(localized: "character.skin.store")
    }

    private func product(for skin: SkinsConfig.Entry) -> Product? {
        store.products.first { store.skinId(for: $0.id) == skin.id }
    }

    private func selectActiveSkin() {
        let active = gameState.activeSkinID(forCharacterType: sheet.type.id)
        selectedID = options.first { $0.skin?.id == active }?.id ?? SkinOption.baseID
    }

    private func move(by delta: Int) {
        let target = min(max(selectedIndex + delta, 0), options.count - 1)
        withAnimation(reduceMotion ? nil : .snappy) { selectedID = options[target].id }
    }
}
```

- [ ] **Step 6: La puerta de debug**

En `DebugPanelView.swift`, después de la sección "Cofres":

```swift
                // La ficha con un segundo Fisura en la torre: el fixture
                // `--uitest-open-sheet` la abre sobre el único de una partida
                // nueva, que no se puede despedir.
                Section("Ficha") {
                    Button("Abrir la ficha (con otro para despedir)") {
                        gameState.debugGrantCoins()
                        if let base = gameState.content?.tiers.baseType.id {
                            gameState.hireCharacter(typeId: base)
                        }
                        if let slot = gameState.visiblePlacements.first?.slot {
                            gameState.presentCharacterSheet(cellIndex: slot)
                        }
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.sheet.open")
                }
```

- [ ] **Step 7: Las strings**

`Tools/v2/claves-pendientes/e3b-t2.json`:

```json
{
  "character.skin.equip.ax %@": {"es": "Ponerle %@", "en": "Wear %@"},
  "pager.previous.ax": {"es": "Anterior", "en": "Previous"},
  "pager.next.ax": {"es": "Siguiente", "en": "Next"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e3b-t2.json`.

- [ ] **Step 8: Verde y oráculo**

Run: Receta R con UI `CharacterSheetUITests`, `UpgradesMenuUITests`, `LaunchSmokeTests` (su
`testCharacterSheetExposesSkinPager` pasa sin cambios: las flechas conservan su `.disabled` en
el extremo), `CustomizationUITests` → PASS; unit `LocalizationCompletenessTests`,
`SheetPresentationGuardTests` → PASS. Capturas de la ficha en SE 3 y 16 Pro al reporte.
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 9: Commit**

```bash
git add FisuEvolution/UI/Popups/CharacterSheetView.swift FisuEvolution/UI/Art/GameConfirmCard.swift \
  FisuEvolution/UI/Art/GameArtComponents.swift FisuEvolution/UI/Art/GameArt.swift \
  FisuEvolution/UI/DebugPanelView.swift FisuEvolutionUITests/CharacterSheetUITests.swift \
  FisuEvolutionUITests/UpgradesMenuUITests.swift
# + el catálogo o el snapshot e3b-t2.json, según la ola
git diff --cached --stat
git commit -m "feat(ux): la ficha de personaje con la pinta en grande y la confirmación de la casa"
```

---

### Task 3: El menú deslizable, las piezas — paginador, flechas, puntos y la sesión

**Objetivo:** todo lo del menú deslizable que no toca `RootView`: el paginador
(`MenuPagerView`), cada página con su `NavigationStack`, su marco y su X; las flechas ‹ › en el
renglón del título y los puntos sobre la banda de madera, dibujados por `panelSheet` cuando hay
un paginador en el entorno; el bloqueo del paginador cuando el Menú tiene un destino empujado; y
la sesión (`GameState+Menu`) que pide el intersticial **una vez al cerrar**, no por página.

**Files:**
- Create: `FisuEvolution/UI/Menu/MenuPagerView.swift`
- Create: `FisuEvolution/Game/State/GameState+Menu.swift`
- Modify: `FisuEvolution/UI/Art/PanelFrames.swift` (`PanelSheetLayout`)
- Modify: `FisuEvolution/UI/Menu/MenuView.swift` (`NavigationStack(path:)`, el bloqueo, sin contexto en los empujados)
- Create: `FisuEvolutionTests/MenuSessionTests.swift`

**Interfaces:**
- Consumes: `PagerChevronButton` (T2), `GameScreen.barOrder` (E3a T7),
  `GameState.tutorialTipHandled(opening:)`, `showInterstitialIfAppropriate()`.
- Produces: `struct MenuPagerView: View` con
  `init(pages: [GameScreen], start: GameScreen, adsProvider: AdsCoordinator, onPageChange: @escaping (GameScreen) -> Void)`;
  `struct MenuPage: View` (`screen`, `adsProvider`); `struct MenuPagerContext`
  (`index`, `count`, `go: @MainActor (Int) -> Void`, `lock: @MainActor (Bool) -> Void`);
  `EnvironmentValues.menuPager: MenuPagerContext?`; `struct PagerDots: View`.
- Produces: `GameState.menuDidOpen(at:)`, `menuPageChanged(to:)`, `menuDidClose() async`.
- Produces: ids `menu.pager.previous`, `menu.pager.next` y el marcador `menu.pager.dots`
  (valor "2/6").

- [ ] **Step 1: El test de la sesión, en rojo**

`FisuEvolutionTests/MenuSessionTests.swift`:

```swift
import Testing
@testable import FisuEvolution

/// La sesión del menú deslizable (PLAN-v2 E3): recorrer páginas no es una pausa;
/// cerrar el menú sí, y ahí se pide el intersticial UNA vez.
@Suite("La sesión de menú", .serialized)
@MainActor
struct MenuSessionTests {
    @Test("el intersticial se pide una vez al cerrar el menú, nunca al cambiar de página")
    func interstitialOnlyOnClose() async {
        let gameState = await makeGameState()
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        gameState.attachAds(ads)
        clock.advance(by: 10_000)
        ads.armIfDue()
        #expect(ads.isInterstitialArmed, "el escenario es un intersticial que ya toca")

        gameState.menuDidOpen(at: .upgrades)
        gameState.menuPageChanged(to: .skins)
        gameState.menuPageChanged(to: .jobs)
        #expect(provider.shown.isEmpty, "cambiar de página no es una pausa natural")

        await gameState.menuDidClose()
        #expect(provider.shown == ["interstitial"])
    }
}
```

- [ ] **Step 2: Verlo fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/MenuSessionTests`.
Expected: no compila — `value of type 'GameState' has no member 'menuDidOpen'`.

- [ ] **Step 3: La sesión**

`FisuEvolution/Game/State/GameState+Menu.swift`:

```swift
import Foundation

/// La sesión del menú deslizable (PLAN-v2 E3): una hoja con las pestañas como
/// páginas. Abrir o deslizar a una pestaña cuenta como abrirla; la pausa natural
/// es cerrar la sesión entera, y sólo ahí se pide el intersticial.
extension GameState {
    func menuDidOpen(at screen: GameScreen) {
        tutorialTipHandled(opening: screen)
    }

    func menuPageChanged(to screen: GameScreen) {
        tutorialTipHandled(opening: screen)
    }

    func menuDidClose() async {
        await showInterstitialIfAppropriate()
    }
}
```

Run: Receta R con `MenuSessionTests` → PASS.

- [ ] **Step 4: El paginador**

`FisuEvolution/UI/Menu/MenuPagerView.swift`:

```swift
import SwiftUI

/// Dónde está una página del paginador y cómo moverse (PLAN-v2 E3). `nil` fuera
/// del paginador y en las vistas empujadas del Menú: ahí no hay flechas ni puntos.
struct MenuPagerContext {
    let index: Int
    let count: Int
    let go: @MainActor (Int) -> Void
    /// El Menú avisa que tiene un destino empujado (Ajustes, Legales): con eso el
    /// paginador se bloquea y el gesto de "volver" es del `NavigationStack`.
    let lock: @MainActor (Bool) -> Void
}

extension EnvironmentValues {
    // Si `@Entry` no compilara con la concurrencia estricta (el contexto lleva
    // closures), la clave va a mano con `static var defaultValue: MenuPagerContext? { nil }`:
    // computada, no exige `Sendable`.
    @Entry var menuPager: MenuPagerContext? = nil
}

/// El menú deslizable (PLAN-v2 E3): UNA hoja con las pestañas desbloqueadas como
/// páginas, en el orden de la barra. Cada página conserva su `NavigationStack`, su
/// marco y su X: lo que el "telón" rechazó era cambiar contenido dentro de un
/// panel fijo, no deslizar entre pantallas enteras.
///
/// Se montan la página actual y sus vecinas; las ocultas no tienen AX ni toques,
/// así que `sheet.close` es uno solo en el árbol.
struct MenuPagerView: View {
    let pages: [GameScreen]
    let adsProvider: AdsCoordinator
    let onPageChange: (GameScreen) -> Void
    @State private var current: GameScreen?
    @State private var locked = false

    init(pages: [GameScreen], start: GameScreen, adsProvider: AdsCoordinator,
         onPageChange: @escaping (GameScreen) -> Void) {
        self.pages = pages
        self.adsProvider = adsProvider
        self.onPageChange = onPageChange
        _current = State(initialValue: pages.contains(start) ? start : pages.first)
    }

    private var currentIndex: Int {
        current.flatMap { pages.firstIndex(of: $0) } ?? 0
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.element) { index, page in
                    slot(page, index: index)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $current)
        .scrollIndicators(.hidden)
        .scrollDisabled(locked)
        .onChange(of: current) { _, page in
            if let page { onPageChange(page) }
        }
    }

    @ViewBuilder private func slot(_ page: GameScreen, index: Int) -> some View {
        let isCurrent = index == currentIndex
        Group {
            if abs(index - currentIndex) <= 1 {
                MenuPage(screen: page, adsProvider: adsProvider)
                    .environment(\.menuPager, MenuPagerContext(
                        index: index,
                        count: pages.count,
                        go: { go(to: $0) },
                        lock: { locked = $0 }
                    ))
            } else {
                Color.clear
            }
        }
        .accessibilityHidden(!isCurrent)
        .allowsHitTesting(isCurrent)
    }

    private func go(to index: Int) {
        guard pages.indices.contains(index) else { return }
        withAnimation(.snappy) { current = pages[index] }
    }
}

/// Una pestaña como página: la misma vista de siempre.
struct MenuPage: View {
    let screen: GameScreen
    let adsProvider: AdsCoordinator

    var body: some View {
        switch screen {
        case .jobs: FisuJobsView()
        case .upgrades: UpgradesView()
        case .skins: CustomizationView()
        case .gifts: GiftsView(adsProvider: adsProvider)
        case .store: StoreView()
        case .menu: MenuView()
        }
    }
}

/// Los puntos del paginador, sobre la banda de madera: la página actual es una
/// cápsula caramelo. Es un marcador para los tests ("2/6"), no un control.
struct PagerDots: View {
    /// Dónde van, contados desde el borde de abajo del panel: centrados en la banda.
    static let bandInset: CGFloat = 7

    let index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { dot in
                if dot == index {
                    PillBackground(fill: Color("PaletteOrange"))
                        .frame(width: 18, height: 8)
                } else {
                    Capsule()
                        .fill(Color("PaletteCream").opacity(0.75))
                        .overlay(Capsule().strokeBorder(Color("PaletteInk").opacity(0.45), lineWidth: 1))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("menu.pager.dots")
        .accessibilityValue(Text(verbatim: "\(index + 1)/\(count)"))
    }
}
```

- [ ] **Step 5: Las flechas y los puntos en `panelSheet`**

En `PanelFrames.swift`, `PanelSheetLayout`:

```swift
    @Environment(\.menuPager) private var pager
```

el `header` del `VStack` de `body(content:)` pasa a `pagedHeader`, el fondo suma los puntos:

```swift
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            pagedHeader
                .frame(maxWidth: .infinity)
                .padding(.horizontal, WoodPanelBackground.columnInset)
                .padding(.top, WoodPanelBackground.headerTopInset(awning: awning))
                .padding(.bottom, Tokens.s8)
            content
                .mask { edgeFade }
        }
        .padding(.bottom, WoodPanelBackground.contentInset)
        .background {
            ZStack(alignment: .top) {
                WoodPanelBackground(material: material, awning: awning)
                ornament
            }
            .overlay(alignment: .bottom) {
                if let pager {
                    PagerDots(index: pager.index, count: pager.count)
                        .padding(.bottom, PagerDots.bandInset)
                }
            }
            .shadow(color: .black.opacity(0.30), radius: 16, y: 6)
        }
        .ignoresSafeArea(edges: .top)
        .frame(maxWidth: SheetColumn.maxWidth)
    }

    /// Con un paginador en el entorno, las flechas ‹ › van en el renglón del
    /// título; sin él, la cabecera de siempre.
    @ViewBuilder private var pagedHeader: some View {
        if let pager {
            HStack(spacing: Tokens.s8) {
                PagerChevronButton(direction: .previous, identifier: "menu.pager.previous") {
                    pager.go(pager.index - 1)
                }
                .disabled(pager.index == 0)
                header
                    .frame(maxWidth: .infinity)
                PagerChevronButton(direction: .next, identifier: "menu.pager.next") {
                    pager.go(pager.index + 1)
                }
                .disabled(pager.index >= pager.count - 1)
            }
        } else {
            header
        }
    }
```

(se conserva el `.frame(maxWidth: SheetColumn.maxWidth)` que puso E3a T6.)

- [ ] **Step 6: El Menú bloquea el paginador con un destino empujado**

En `MenuView.swift`:

```swift
    @Environment(\.menuPager) private var pager
    @State private var path: [Destination] = []
```

`NavigationStack {` pasa a `NavigationStack(path: $path) {`; al contenido de
`navigationDestination` se le suma, después de `.clearNavigationBackdrop()`:

```swift
                // Las empujadas no son páginas: sin flechas ni puntos.
                .environment(\.menuPager, nil)
```

y al `NavigationStack`, junto al `.tint`:

```swift
        // Con Ajustes o Legales empujados, deslizar es "volver" y no "otra
        // pestaña": el paginador se bloquea hasta que la pila se vacía.
        .onChange(of: path.isEmpty) { _, isEmpty in pager?.lock(!isEmpty) }
```

- [ ] **Step 7: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `MenuSessionTests` → PASS; UI con
`MenuUITests` y `BottomMenuUITests` → PASS sin cambios (todavía nadie monta el paginador: sin
contexto, `panelSheet` dibuja lo de siempre). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/UI/Menu/MenuPagerView.swift FisuEvolution/Game/State/GameState+Menu.swift \
  FisuEvolution/UI/Art/PanelFrames.swift FisuEvolution/UI/Menu/MenuView.swift \
  FisuEvolutionTests/MenuSessionTests.swift
git diff --cached --stat
git commit -m "feat(ux): el paginador del menú, con flechas, puntos y la sesión que pide un solo anuncio"
```

---

### Task 4: El menú deslizable, montado — una hoja, una sesión

**Objetivo:** `RootView` deja de presentar una hoja por pestaña y presenta el paginador en una
sesión de identidad estable: cambiar de página no re-presenta la hoja, la barra y el `+` de la
plata abren la sesión en su página, y el intersticial sale una sola vez, al cerrar.
`testCadaTabAbreSuPantallaYSeCierra` sigue verde **sin cambios**.

**Files:**
- Modify: `FisuEvolution/App/RootView.swift` (`activeScreen` → `menuSession`; `open(_:)`; la hoja; los tres `onChange`)
- Modify: `FisuEvolution/Game/State/GameState+Menu.swift` (`markTabOpened` al deslizar)
- Create: `FisuEvolutionUITests/MenuPagerUITests.swift`

**Interfaces:**
- Consumes: T3; `GameState.unlockedTabsInBarOrder`, `markTabOpened(_:)` (E3a T9); `fisuSheet()`.
- Produces: la sesión de menú; nada nuevo para otras tareas.

- [ ] **Step 1: El test de UI, en rojo**

`FisuEvolutionUITests/MenuPagerUITests.swift`:

```swift
import XCTest

/// El menú deslizable (PLAN-v2 E3): una hoja, las pestañas como páginas, flechas
/// y puntos, sin vuelta en los extremos, y el Menú con un destino empujado no se
/// desliza.
final class MenuPagerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testDeslizarYLasFlechasCambianDePestanaEnLaMismaHoja() throws {
        let app = launch()
        tapTab("hud.upgrades", in: app)
        XCTAssertTrue(app.buttons["upgrades.tab.permanent"].waitForExistence(timeout: 10))
        XCTAssertEqual(dots(app), "1/6")
        XCTAssertEqual(app.buttons.matching(identifier: "sheet.close").count, 1,
                       "las páginas ocultas no exponen su X")
        XCTAssertFalse(app.buttons["menu.pager.previous"].isEnabled, "en el extremo no hay vuelta")

        app.windows.firstMatch.swipeLeft()
        XCTAssertTrue(app.buttons["skins.row.base"].waitForExistence(timeout: 5), "deslizar no llevó a Vestimenta")
        XCTAssertEqual(dots(app), "2/6")

        app.buttons["menu.pager.next"].tap()
        XCTAssertTrue(app.buttons["jobs.hire.homeless"].waitForExistence(timeout: 5), "la flecha no llevó a Contratar")
        XCTAssertEqual(dots(app), "3/6")
        attach(app, named: "E3 paginador en Contratar")

        app.buttons["menu.pager.previous"].tap()
        XCTAssertTrue(app.buttons["skins.row.base"].waitForExistence(timeout: 5))

        let close = app.buttons["sheet.close"]
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10), "la X cierra la sesión entera")
    }

    @MainActor
    func testConAjustesAbiertoElMenuNoSeDesliza() throws {
        let app = launch()
        tapTab("hud.settings", in: app)
        XCTAssertEqual(dots(app), "6/6")
        let settingsCard = app.buttons["menu.card.settings"]
        XCTAssertTrue(settingsCard.waitForExistence(timeout: 10))
        settingsCard.tap()
        let version = app.descendants(matching: .any)["settings.about.version"]
        XCTAssertTrue(version.waitForExistence(timeout: 10), "Ajustes no se empujó")

        app.windows.firstMatch.swipeLeft()
        app.windows.firstMatch.swipeRight()
        XCTAssertTrue(version.exists, "con un destino empujado, deslizar no cambia de pestaña")
    }

    // MARK: - Utilidades

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func tapTab(_ identifier: String, in app: XCUIApplication) {
        let tab = app.buttons[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.buttons["sheet.close"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func dots(_ app: XCUIApplication) -> String? {
        let dots = app.otherElements["menu.pager.dots"]
        _ = dots.waitForExistence(timeout: 5)
        return dots.value as? String
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

- [ ] **Step 2: Verlo fallar**

Run: Receta R con `-only-testing:FisuEvolutionUITests/MenuPagerUITests`.
Expected: FAIL — `menu.pager.dots` no existe (la hoja todavía es la de una pestaña).

- [ ] **Step 3: `RootView`**

En `GameBoardView`:

1. `@State private var activeScreen: GameScreen?` (con su docstring) pasa a:

```swift
    /// La sesión del menú deslizable, o `nil`. Su `id` es estable mientras la
    /// hoja está arriba: deslizar entre pestañas cambia la página adentro, no
    /// la sesión, así que la hoja no se vuelve a presentar (PLAN-v2 E3).
    @State private var menuSession: MenuSession?

    private struct MenuSession: Identifiable {
        let id = UUID()
        let start: GameScreen
    }
```

2. Los tres `onChange` que leen `activeScreen`:

```swift
        .onChange(of: menuSession?.id) { _, id in
            gameState.uiCoversBoard = id != nil || showPrestige
            // **La pausa natural**: cerrar el menú entero, no cada página.
            if id == nil {
                Task { await gameState.menuDidClose() }
            }
        }
        .onChange(of: showPrestige) { _, prestige in
            gameState.uiCoversBoard = prestige || menuSession != nil
        }
        .onChange(of: gameState.specialInfo) { _, info in
            gameState.uiCoversBoard = info != nil || menuSession != nil || showPrestige
        }
```

3. La hoja de las seis (`.sheet(item: $activeScreen) { … }` entera) pasa a:

```swift
        // El menú deslizable: las pestañas desbloqueadas como páginas de UNA
        // hoja. Cada página conserva su `NavigationStack`, su marco y su X.
        .sheet(item: $menuSession) { session in
            MenuPagerView(
                pages: gameState.unlockedTabsInBarOrder,
                start: session.start,
                adsProvider: adsProvider
            ) { page in
                gameState.menuPageChanged(to: page)
            }
            .fisuSheet()
        }
```

4. `open(_:)`:

```swift
    /// Abre el menú deslizable en una pestaña (la barra o el `+` de la plata).
    private func open(_ screen: GameScreen) {
        gameState.menuDidOpen(at: screen)
        menuSession = MenuSession(start: screen)
    }
```

En `GameState+Menu.swift`, `menuPageChanged(to:)` suma `markTabOpened(screen)` (la barra ya lo
hace al tocar la pestaña; deslizar hasta una nueva también le saca el "¡Nuevo!"):

```swift
    func menuPageChanged(to screen: GameScreen) {
        tutorialTipHandled(opening: screen)
        markTabOpened(screen)
    }
```

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con UI `MenuPagerUITests`, `BottomMenuUITests` (**sin cambios**), `MenuUITests`,
`CustomizationUITests` (el carrusel de Pintas sigue andando: lo midió S2), `StoreUITests`,
`BonusHUDUITests`, `TutorialUITests`, `ProgressiveTabsUITests` → PASS; unit `MenuSessionTests`
→ PASS. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/App/RootView.swift FisuEvolution/Game/State/GameState+Menu.swift \
  FisuEvolutionUITests/MenuPagerUITests.swift
git diff --cached --stat
git commit -m "feat(ux): el menú deslizable, una sola hoja que se recorre sin volver a abrirse"
```

---

### Task 5: Renombre puro — `BestHire` pasa a llamarse `QuickHireOffer`

**Objetivo:** el commit propio que pide la spec antes de cambiar el comportamiento: el tipo, la
proyección y la acción del atajo pasan a llamarse por lo que van a ser (una oferta con pin y
motivo, no "el mejor"). **Cero cambios de comportamiento**: los mismos tests, renombrados, en
verde.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Hiring.swift`, `FisuEvolution/Game/State/GameState.swift`,
  `FisuEvolution/UI/HUD/QuickHireButton.swift`, `FisuEvolution/Game/State/GameState+TutorialTips.swift`,
  `FisuEvolution/App/RootView.swift` (sólo comentarios)
- Rename: `FisuEvolutionTests/BestHireTests.swift` → `FisuEvolutionTests/QuickHireOfferTests.swift`

**Interfaces:**
- Produces: `struct QuickHireOffer` (los mismos campos que `BestHire`), `GameState.quickHireOffer`,
  `computeQuickHireOffer()`, `hireQuickOffer()`. Las Tasks 6 a 9 usan estos nombres.

- [ ] **Step 1: El rename**

```bash
git mv FisuEvolutionTests/BestHireTests.swift FisuEvolutionTests/QuickHireOfferTests.swift
sed -i '' -e 's/hireBestCharacter/hireQuickOffer/g' -e 's/BestHire/QuickHireOffer/g' -e 's/bestHire/quickHireOffer/g' \
  FisuEvolution/Game/State/GameState+Hiring.swift FisuEvolution/Game/State/GameState.swift \
  FisuEvolution/UI/HUD/QuickHireButton.swift FisuEvolution/Game/State/GameState+TutorialTips.swift \
  FisuEvolution/App/RootView.swift FisuEvolutionTests/QuickHireOfferTests.swift
/opt/homebrew/bin/xcodegen generate
```

(`computeBestHire` queda `computeQuickHireOffer` y `BestHireTests` queda `QuickHireOfferTests`
por la segunda regla.) En `QuickHireOfferTests.swift`, el título de la suite pasa a
`@Suite("quickHireOffer: la oferta del atajo de contratar", .serialized)`.

- [ ] **Step 2: Nada quedó con el nombre viejo**

Run: `grep -rn "BestHire\|bestHire\|hireBestCharacter" FisuEvolution FisuEvolutionTests FisuEvolutionUITests`
Expected: sin resultados (el `bestHire(state:)` de `Packages/EconomyKit` es del simulador y no
se toca).

- [ ] **Step 3: Verde**

Run: Receta R con `-only-testing:FisuEvolutionTests/QuickHireOfferTests -only-testing:FisuEvolutionTests/TutorialTipsTests`
→ PASS, con la misma cuenta de tests que tenía `BestHireTests`. `Tools/v2/oraculo.sh rapido` →
`VERDE` con la cuenta de unit igual a la de antes del rename.

- [ ] **Step 4: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Hiring.swift FisuEvolution/Game/State/GameState.swift \
  FisuEvolution/UI/HUD/QuickHireButton.swift FisuEvolution/Game/State/GameState+TutorialTips.swift \
  FisuEvolution/App/RootView.swift FisuEvolutionTests/QuickHireOfferTests.swift
git diff --cached --stat
git commit -m "refactor(ux): BestHire pasa a llamarse QuickHireOffer"
```

---

### Task 6: La oferta del atajo v2 — el pin, el motivo y nunca `nil`

**Objetivo:** la oferta del atajo se resuelve en un orden fijo: (1) el pin, si está
desbloqueado —con su motivo, sin caer a otro en silencio—; (2) el mejor que alcanza y entra;
(3) el más barato que entra, como meta de ahorro; (4) el mejor que pagarías si hubiera lugar
("Piso lleno"). Lleva `fits`, `isPinned` y un `blocker` (piso lleno gana a "no te alcanza").
Con la partida cargada **nunca es `nil`**. El pin se guarda en el save
(`meta.quickHirePinnedTypeId`) y, si el tipo deja de estar desbloqueado, se ignora sin
borrarse. El selector (Task 8) lee las entradas de acá.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Hiring.swift` (`QuickHireOffer`, `computeQuickHireOffer`, `hireQuickOffer`; nuevos `QuickHirePickerEntry`, `pinQuickHire(typeId:)`, `quickHirePickerEntries`)
- Modify: `FisuEvolutionTests/QuickHireOfferTests.swift`

**Interfaces:**
- Consumes: `MetaState.quickHirePinnedTypeId: String?` (**E1 T4**); `jobState`, `currentQuote`,
  `hireCharacter(typeId:)` (`+Hiring`).
- Produces: `QuickHireOffer` con `fits: Bool`, `isPinned: Bool`, `blocker: Blocker?`
  (`.floorFull` | `.cantAfford`), `accessibilityState: String` (`"ready:homeless"`,
  `"floorFull:homeless;pinned"`).
- Produces: `struct QuickHirePickerEntry: Identifiable, Equatable` (`id`, `displayName`,
  `faceKey`, `costText`, `affordable`, `fits`, `isPinned`);
  `GameState.quickHirePickerEntries: [QuickHirePickerEntry]`; `GameState.pinQuickHire(typeId: String?)`.

- [ ] **Step 1: Los tests, en rojo**

En `QuickHireOfferTests.swift`, reemplazar `noHirableMeansNoOffer` (`:336-356`) por el primero
y sumar los demás al final de "La regla":

```swift
    @Test("con el piso lleno la oferta sigue ahí con su motivo, y tocar no compra pero avisa")
    func fullFloorKeepsAnOfferWithFloorFullBlocker() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        let capacity = gameState.floorOccupancy(ordinal: 0).capacity
        for _ in gameState.floorOccupancy(ordinal: 0).occupied..<capacity {
            gameState.hireCharacter(typeId: "homeless")
        }
        gameState.refreshProjections()

        let offer = try #require(gameState.quickHireOffer, "el atajo nunca desaparece")
        #expect(offer.typeId == "homeless")
        #expect(!offer.fits)
        #expect(offer.blocker == .floorFull, "piso lleno gana a no te alcanza")
        #expect(offer.accessibilityState == "floorFull:homeless")

        let unitsBefore = try #require(gameState.player?.run.units)
        gameState.towerNotice = nil
        gameState.hireQuickOffer()
        #expect(gameState.player?.run.units == unitsBefore, "con el piso lleno no hay compra")
        #expect(gameState.towerNotice?.kind == .floorFull, "y el aviso de piso lleno aparece")
    }

    @Test("el pin manda: la oferta es el fijado aunque haya uno mejor, y sin plata no cae a otro")
    func thePinWins() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        gameState.debugSetMaxTier(18)
        try giveCoins(400_000_000_000, to: gameState)
        gameState.refreshProjections()
        #expect(gameState.quickHireOffer?.typeId == "senior_architect", "sin pin, el más alto pagable")

        gameState.pinQuickHire(typeId: "oficinista")
        var offer = try #require(gameState.quickHireOffer)
        #expect(offer.typeId == "oficinista")
        #expect(offer.isPinned)
        #expect(offer.blocker == nil)
        #expect(offer.accessibilityState == "ready:oficinista;pinned")
        #expect(gameState.player?.meta.quickHirePinnedTypeId == "oficinista", "el pin va al save")

        try giveCoins(0, to: gameState)
        gameState.refreshProjections()
        offer = try #require(gameState.quickHireOffer)
        #expect(offer.typeId == "oficinista", "el pin muestra su motivo, no cae a otro en silencio")
        #expect(offer.blocker == .cantAfford)

        gameState.pinQuickHire(typeId: nil)
        try giveCoins(400_000_000_000, to: gameState)
        gameState.refreshProjections()
        #expect(gameState.quickHireOffer?.typeId == "senior_architect", "soltar el pin vuelve a la regla")
        #expect(gameState.quickHireOffer?.isPinned == false)
    }

    @Test("un pin que dejó de estar desbloqueado se ignora sin borrarse")
    func aStalePinIsIgnoredNotErased() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.pinQuickHire(typeId: "senior_architect")
        gameState.refreshProjections()
        let offer = try #require(gameState.quickHireOffer)
        #expect(offer.typeId == "homeless", "un tipo nunca visto no se ofrece (RF-03)")
        #expect(!offer.isPinned)
        #expect(gameState.player?.meta.quickHirePinnedTypeId == "senior_architect",
                "vuelve a mandar cuando se desbloquee")
    }

    @Test("el selector lista sólo lo desbloqueado, el más alto primero, con lleno y fijado")
    func pickerListsOnlyUnlockedTypes() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        gameState.debugSetMaxTier(18)
        try giveCoins(400_000_000_000, to: gameState)
        gameState.pinQuickHire(typeId: "oficinista")
        gameState.refreshProjections()

        let entries = gameState.quickHirePickerEntries
        #expect(!entries.isEmpty)
        let rows = Dictionary(uniqueKeysWithValues: gameState.jobRows.map { ($0.id, $0) })
        for entry in entries {
            let state = try #require(rows[entry.id]?.state)
            #expect(state == .hirable || state == .floorFull, "\(entry.id) no está desbloqueado (\(state))")
            #expect(entry.fits == (state == .hirable))
        }
        let tiers = entries.compactMap { rows[$0.id]?.tier }
        #expect(tiers == tiers.sorted(by: >), "el más alto primero")
        #expect(entries.filter(\.isPinned).map(\.id) == ["oficinista"])
    }
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/QuickHireOfferTests`.
Expected: no compila — `value of type 'QuickHireOffer' has no member 'fits'`, `pinQuickHire` no existe.

- [ ] **Step 3: La implementación**

En `GameState+Hiring.swift`, el `struct QuickHireOffer` (ex `BestHire`, con su docstring)
pasa a:

```swift
/// La oferta del atajo de contratar de la pantalla principal (PLAN-v2 E3).
///
/// Se resuelve en un orden fijo (ver `computeQuickHireOffer()`): el personaje
/// fijado, el mejor que alcanza y entra, la meta de ahorro, y el mejor con piso
/// lleno. **Con la partida cargada nunca es `nil`**: el botón no desaparece,
/// dice por qué no compra.
///
/// Es una fila de FisuJobs recortada a lo que el botón dibuja: publicar los
/// quince campos de `JobRow` invitaría a la vista a decidir con ellos.
struct QuickHireOffer: Equatable {
    /// Por qué el atajo no compra ahora. Piso lleno gana a "no te alcanza":
    /// juntar plata no destraba un piso lleno; fusionar, sí.
    enum Blocker: String, Equatable {
        case floorFull
        case cantAfford
    }

    let typeId: String
    let displayName: String
    let faceKey: String
    let costText: String
    /// La plata alcanza. `false` no deshabilita: el botón tiembla (patrón `PricePill`).
    let affordable: Bool
    /// Hay lugar en el piso donde cae la contratación.
    let fits: Bool
    /// Es el personaje que el jugador fijó manteniendo apretado el atajo.
    let isPinned: Bool
    let tier: Int

    var blocker: Blocker? {
        if !fits { return .floorFull }
        if !affordable { return .cantAfford }
        return nil
    }

    /// El estado como lo leen los tests de UI: `ready:homeless`,
    /// `cantAfford:oficinista;pinned`, `floorFull:homeless`.
    var accessibilityState: String {
        "\(blocker?.rawValue ?? "ready"):\(typeId)" + (isPinned ? ";pinned" : "")
    }
}

/// Una cara del selector del atajo: un tipo desbloqueado, con su precio y si
/// entra. Nunca un tipo que el jugador no puede contratar.
struct QuickHirePickerEntry: Identifiable, Equatable {
    let id: String
    let displayName: String
    let faceKey: String
    let costText: String
    let affordable: Bool
    let fits: Bool
    let isPinned: Bool
}
```

`computeQuickHireOffer()` (con su docstring: se conserva el bloque "⚠️ Esto revierte el recorte a
tier base…" con sus tres datos, porque sigue siendo la regla del paso 2) pasa a:

```swift
    func computeQuickHireOffer() -> QuickHireOffer? {
        guard let content, let player else { return nil }
        let candidates = quickHireCandidates(player: player, content: content)
        let pinnedID = player.meta.quickHirePinnedTypeId
        let pick = candidates.first { $0.type.id == pinnedID }              // 1. el pin
            ?? Self.best(candidates.filter { $0.fits && $0.affordable })    // 2. el mejor que alcanza y entra
            ?? Self.cheapest(candidates.filter(\.fits))                     // 3. la meta de ahorro
            ?? Self.best(candidates.filter(\.affordable))                   // 4. el mejor, con "Piso lleno"
            ?? Self.cheapest(candidates)
        guard let pick else { return nil }
        return QuickHireOffer(
            typeId: pick.type.id,
            displayName: pick.type.localizedName,
            faceKey: "\(pick.type.id)_face",
            costText: CoinFormatter.cost(from: pick.cost),
            affordable: pick.affordable,
            fits: pick.fits,
            isPinned: pick.type.id == pinnedID,
            tier: pick.type.tier
        )
    }

    /// Lo que el atajo puede ofrecer: lo que FisuJobs vende (piso abierto,
    /// compuerta abierta, tipo visto), con lugar o sin él. Que la compuerta sea
    /// `jobState` y no una regla propia es lo que impide espoilear la cadena.
    private func quickHireCandidates(player: PlayerState, content: GameContent) -> [QuickHireCandidate] {
        content.tiers.concreteTypes.compactMap { type in
            guard let quote = currentQuote(player: player, typeId: type.id) else { return nil }
            let state = jobState(for: type, ordinal: quote.floorOrdinal, player: player, content: content)
            guard state == .hirable || state == .floorFull else { return nil }
            return QuickHireCandidate(
                type: type,
                cost: quote.cost,
                fits: state == .hirable,
                affordable: player.run.coins >= quote.cost
            )
        }
    }

    /// El tier más alto; empate de tier (las cuatro ramas de carrera), el más
    /// barato; empate de precio, el id ascendente. Pineado por
    /// `tiesOnTierPreferTheCheapest` y `tiesFallBackToTheAscendingID`.
    private static func best(_ candidates: [QuickHireCandidate]) -> QuickHireCandidate? {
        candidates.max { lhs, rhs in
            if lhs.type.tier != rhs.type.tier { return lhs.type.tier < rhs.type.tier }
            if lhs.cost != rhs.cost { return lhs.cost > rhs.cost }
            return lhs.type.id > rhs.type.id
        }
    }

    /// El más barato; empate, el id ascendente.
    private static func cheapest(_ candidates: [QuickHireCandidate]) -> QuickHireCandidate? {
        candidates.min { lhs, rhs in
            if lhs.cost != rhs.cost { return lhs.cost < rhs.cost }
            return lhs.type.id < rhs.type.id
        }
    }

    /// Las caras del selector, el más alto primero.
    var quickHirePickerEntries: [QuickHirePickerEntry] {
        guard let content, let player else { return [] }
        let pinned = player.meta.quickHirePinnedTypeId
        return quickHireCandidates(player: player, content: content)
            .sorted { lhs, rhs in
                lhs.type.tier != rhs.type.tier ? lhs.type.tier > rhs.type.tier : lhs.type.id < rhs.type.id
            }
            .map { candidate in
                QuickHirePickerEntry(
                    id: candidate.type.id,
                    displayName: candidate.type.localizedName,
                    faceKey: "\(candidate.type.id)_face",
                    costText: CoinFormatter.cost(from: candidate.cost),
                    affordable: candidate.affordable,
                    fits: candidate.fits,
                    isPinned: candidate.type.id == pinned
                )
            }
    }

    /// Fija (o con `nil` suelta) el personaje del atajo. Va al save
    /// (`meta.quickHirePinnedTypeId`) y sobrevive a reencarnar.
    func pinQuickHire(typeId: String?) {
        guard var player, player.meta.quickHirePinnedTypeId != typeId else { return }
        player.meta.quickHirePinnedTypeId = typeId
        self.player = player
        scheduleSave()
        refreshProjections()
    }
```

y, junto a `jobGroup`:

```swift
    private struct QuickHireCandidate {
        let type: CharacterType
        let cost: Double
        let fits: Bool
        let affordable: Bool
    }
```

`hireQuickOffer()` queda como estaba (contrata `quickHireOffer?.typeId` por `hireCharacter`, que
ya avisa "piso lleno" y hace el háptico de error); su docstring suma: "con piso lleno o sin plata,
`hireCharacter` rechaza y avisa: el botón no decide nada".

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con `QuickHireOfferTests` → PASS (los de la regla vieja siguen verdes: el paso 2
es la regla de siempre), `TutorialTipsTests`, `JobRowsTests` → PASS.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Hiring.swift FisuEvolutionTests/QuickHireOfferTests.swift
git diff --cached --stat
git commit -m "feat(ux): la oferta del atajo con pin, motivo y siempre presente"
```

---

### Task 7: El botón del atajo nunca desaparece, y se mantiene presionado

**Objetivo:** el botón dibuja los tres estados —listo (verde), no te alcanza y piso lleno (gris
de la casa, con "Piso lleno" en la segunda línea)— con el mismo alto y ancho mínimo; tiembla al
tocarlo bloqueado; muestra un alfiler cuando hay pin y un chevron que dice "hay más". Mantener
presionado 0,45 s (el reloj del tablero) llama a `onChoose` (el selector de la Task 8), con una
bandera que anula el toque de soltar. AX: un solo elemento con el estado en el valor
(`ready:<id>`, `…;pinned`) y la acción "Elegir a quién contratar".

**Files:**
- Modify: `FisuEvolution/UI/HUD/QuickHireButton.swift` (entero)
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (snapshot `e3b-t7.json`)
- Create: `FisuEvolutionUITests/QuickHireButtonUITests.swift`

**Interfaces:**
- Consumes: `QuickHireOffer` v2 (T6), `GameState.hireQuickOffer()`, `playHaptic(_:)`.
- Produces: `QuickHireButton(onChoose: @escaping () -> Void = {})`,
  `QuickHireButton.capsuleHeight` (56, sin cambios), `QuickHireButton.longPressDuration` (0,45).
  La Task 8 pasa `onChoose` desde `RootView`.

- [ ] **Step 1: El test de UI, en rojo**

`FisuEvolutionUITests/QuickHireButtonUITests.swift`:

```swift
import XCTest

/// El atajo de contratar (PLAN-v2 E3): dice su estado y mantenerlo presionado no
/// compra. El selector que abre lo prueba `QuickHireUITests`.
final class QuickHireButtonUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElAtajoDiceSiCompraONoYPorQue() throws {
        let broke = launch(["--uitest-reset", "--uitest-skip-tutorial"])
        let quickHire = broke.buttons["hud.quickhire"]
        XCTAssertTrue(quickHire.waitForExistence(timeout: 20))
        XCTAssertEqual(quickHire.value as? String, "cantAfford:homeless", "sin plata: meta de ahorro")

        let rich = launch(["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"])
        let ready = rich.buttons["hud.quickhire"]
        XCTAssertTrue(ready.waitForExistence(timeout: 20))
        XCTAssertEqual(ready.value as? String, "ready:homeless")
    }

    @MainActor
    func testMantenerPresionadoNoCompra() throws {
        let app = launch(["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"])
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(quickHire.waitForExistence(timeout: 20))
        let units = app.otherElements["board.units"]
        let before = units.value as? String

        quickHire.press(forDuration: 0.9)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(units.value as? String, before, "el toque de soltar después de mantener no compra")

        quickHire.tap()
        let bought = NSPredicate(format: "value != %@", before ?? "")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: bought, evaluatedWith: units)], timeout: 5),
                       .completed, "un toque común sí compra")
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }
}
```

- [ ] **Step 2: Verlo fallar**

Run: Receta R con `-only-testing:FisuEvolutionUITests/QuickHireButtonUITests`.
Expected: FAIL — el valor de `hud.quickhire` es `nil` (hoy no publica estado) y mantener
presionado compra.

- [ ] **Step 3: El botón**

`FisuEvolution/UI/HUD/QuickHireButton.swift`, entero:

```swift
import SwiftUI

/// El atajo de contratar de la pantalla principal (PLAN-v2 E3): compra la oferta
/// `quickHireOffer` sin abrir FisuJobs, y mantenerlo presionado abre el selector
/// para fijar a quién.
///
/// **Nunca desaparece** con la partida cargada: cuando no compra, dice por qué
/// —"no te alcanza" (el precio en gris es la meta de ahorro) o "Piso lleno"—, y
/// tiembla al tocarlo (patrón `PricePill`: nunca `.disabled`).
///
/// ⚠️ La oferta NO se recalcula al tocar: el botón le pide a `hireQuickOffer()`
/// que compre la proyección publicada, y `TowerActions.hire` revalida todo.
struct QuickHireButton: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Abre el selector (mantener presionado, o la acción de VoiceOver).
    var onChoose: () -> Void = {}
    @State private var shake = 0
    /// El mantener presionado ya abrió el selector: el toque de soltar que le
    /// sigue no compra (spike S3).
    @State private var longPressFired = false

    /// Cuánto mide de alto la cápsula: 40 de la carita + 8 + 8 de padding. Lo
    /// consumen los dos toasts de `RootView`, por símbolo. ⚠️ Dynamic Type lo
    /// puede pasar en runtime (los text styles son dinámicos); vale al tamaño por
    /// defecto. Aislado al main actor como todo el tipo (es un `View`).
    static let capsuleHeight: CGFloat = 56

    /// El mismo reloj que el mantener presionado del tablero (`BoardScene`).
    static let longPressDuration: Double = 0.45

    var body: some View {
        // `nil` sólo antes de cargar, y antes de cargar la pantalla es el splash.
        if let offer = gameState.quickHireOffer {
            button(for: offer)
        }
    }

    private func button(for offer: QuickHireOffer) -> some View {
        Button {
            if longPressFired {
                longPressFired = false
                return
            }
            gameState.tutorialTipCompleted(.quickHire)
            if offer.blocker != nil, !reduceMotion { shake += 1 }
            gameState.hireQuickOffer()
        } label: {
            label(for: offer)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: Self.longPressDuration)
                .onEnded { _ in
                    longPressFired = true
                    gameState.playHaptic(.merge)
                    onChoose()
                }
        )
        // UNA sola parada, sin el nombre suelto como hijo: la única forma que da
        // a la vez "sin hijos", "sigue siendo botón" y "sigue siendo tocable" es
        // `accessibilityRepresentation` (medido con dumps del árbol de AX; el
        // porqué entero está en la historia de este archivo, 2026-08-28).
        .accessibilityRepresentation {
            Color.clear
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(spokenLabel(for: offer))
                .accessibilityValue(Text(verbatim: offer.accessibilityState))
                .accessibilityAction(named: Text("quickhire.ax.choose"), onChoose)
        }
        // ⚠️ DESPUÉS de la representación: puesto arriba, se iría con lo que
        // ella reemplaza.
        .accessibilityIdentifier("hud.quickhire")
        // Las keyframes de `PricePill`; va último para que el identifier quede
        // pegado al botón (trampa 9a-bis).
        .keyframeAnimator(initialValue: 0.0, trigger: shake) { view, dx in
            view.offset(x: dx)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-4, duration: 0.07)
                CubicKeyframe(4, duration: 0.08)
                CubicKeyframe(-3, duration: 0.08)
                CubicKeyframe(0, duration: 0.07)
            }
        }
    }

    private func label(for offer: QuickHireOffer) -> some View {
        let ready = offer.blocker == nil
        return HStack(spacing: Tokens.s8) {
            GameIcon(artKey: offer.faceKey, size: 40) { EmptyView() }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(verbatim: offer.displayName)
                        .font(Tokens.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if offer.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .black))
                            .rotationEffect(.degrees(30))
                    }
                }
                secondLine(for: offer)
            }
            // "Hay más": mantener presionado abre el selector.
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .black))
                .opacity(0.6)
        }
        .foregroundStyle(ready ? .white : Color("PaletteInk"))
        .shadow(color: .black.opacity(ready ? 0.45 : 0), radius: 1, y: 1)
        .padding(.horizontal, Tokens.s16)
        .padding(.vertical, Tokens.s8)
        .frame(minWidth: 170)
        .background(
            // Verde caramelo cuando compra; el gris de la casa (el de
            // `GameCard.locked` y `StateBadge` apagado) cuando no.
            PillBackground(
                fill: ready ? Color("PaletteGreen") : CardMaterials.lockedFill,
                border: ready ? nil : CardMaterials.lockedBorder
            )
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        )
        .contentShape(Capsule())
    }

    /// La segunda línea mide lo mismo en los tres estados (20 pt, el alto de la
    /// moneda): el atajo no cambia de tamaño, y el SE está al límite.
    @ViewBuilder private func secondLine(for offer: QuickHireOffer) -> some View {
        if offer.blocker == .floorFull {
            HStack(spacing: 5) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 12, weight: .black))
                Text("quickhire.blocker.floor_full")
                    .font(Tokens.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(height: 20)
        } else {
            HStack(spacing: 5) {
                CoinIcon(size: 20)
                Text(verbatim: offer.costText)
                    .font(Tokens.body)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    /// "Contratar a {nombre}, {monto} monedas", más el motivo y el pin.
    private func spokenLabel(for offer: QuickHireOffer) -> Text {
        var label = Text(verbatim: String(localized: "quickhire.ax.purpose \(offer.displayName)"))
        switch offer.blocker {
        case .floorFull:
            label = label + Text(verbatim: ", ") + Text("quickhire.blocker.floor_full")
        case .cantAfford:
            label = label + Text(verbatim: ", \(String(localized: "price.ax.coins \(offer.costText)")), ")
                + Text("quickhire.ax.cant_afford")
        case nil:
            label = label + Text(verbatim: ", \(String(localized: "price.ax.coins \(offer.costText)"))")
        }
        if offer.isPinned {
            label = label + Text(verbatim: ", ") + Text("quickhire.ax.pinned")
        }
        return label
    }
}
```

- [ ] **Step 4: Las strings**

`Tools/v2/claves-pendientes/e3b-t7.json`:

```json
{
  "quickhire.blocker.floor_full": {"es": "Piso lleno", "en": "Floor full"},
  "quickhire.ax.cant_afford": {"es": "no te alcanza", "en": "not enough coins"},
  "quickhire.ax.pinned": {"es": "fijado", "en": "pinned"},
  "quickhire.ax.choose": {"es": "Elegir a quién contratar", "en": "Choose who to hire"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e3b-t7.json`.

- [ ] **Step 5: Verde y oráculo**

Run: Receta R con UI `QuickHireButtonUITests`, `BottomMenuUITests`, `FisuJobsUITests`,
`TutorialUITests`, `HUDRedesignUITests` → PASS; unit `LocalizationCompletenessTests` → PASS.
Capturas de los tres estados en el SE al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/UI/HUD/QuickHireButton.swift FisuEvolutionUITests/QuickHireButtonUITests.swift
# + el catálogo o el snapshot e3b-t7.json, según la ola
git diff --cached --stat
git commit -m "feat(ux): el atajo no desaparece nunca, dice por qué no compra y se mantiene presionado"
```

---

### Task 8: El selector del atajo — fijar a quién con las caras

**Objetivo:** mantener presionado el atajo abre un overlay —**no una hoja**: el juego sigue— con
una tarjeta de la casa colgada del botón (con su cola): arriba "Mejor disponible" y debajo una
grilla de 4 columnas con las caras desbloqueadas y su precio; las de piso lleno, atenuadas con
"Lleno". Tocar una cara la fija; tocar la fijada o "Mejor disponible" la suelta; tocar afuera
cierra. Nunca muestra tipos sin desbloquear.

**Files:**
- Create: `FisuEvolution/UI/HUD/QuickHirePicker.swift`
- Modify: `FisuEvolution/App/RootView.swift` (`showQuickHirePicker`, `QuickHireButton(onChoose:)`, el overlay, los comentarios del atajo)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (sección "Atajo")
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (snapshot `e3b-t8.json`)
- Create: `FisuEvolutionUITests/QuickHireUITests.swift`

**Interfaces:**
- Consumes: `GameState.quickHirePickerEntries`, `pinQuickHire(typeId:)` (T6),
  `QuickHireButton(onChoose:)` (T7), `TutorialAnchorKey` y el ancla `.quickHire`.
- Produces: `struct QuickHirePicker: View` (`anchor: CGRect?`, `close: () -> Void`); ids
  `quickhire.picker.best`, `quickhire.picker.option.<id>`, `quickhire.picker.close`;
  puertas de debug `debug.floor.fill` y `debug.quickhire.many`.

- [ ] **Step 1: El test de UI, en rojo**

`FisuEvolutionUITests/QuickHireUITests.swift`:

```swift
import XCTest

/// El selector del atajo (PLAN-v2 E3): mantener presionado abre las caras,
/// tocar una la fija, "Mejor disponible" la suelta y tocar afuera cierra. Con el
/// piso lleno el atajo sigue y avisa.
final class QuickHireUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testMantenerPresionadoAbreElSelectorYFija() throws {
        let app = launch()
        openDebug("debug.quickhire.many", in: app)
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(waitUntilHittable(quickHire))
        let before = try XCTUnwrap(quickHire.value as? String)
        let currentID = String(before.split(separator: ":")[1].split(separator: ";")[0])

        quickHire.press(forDuration: 0.9)
        let best = app.buttons["quickhire.picker.best"]
        XCTAssertTrue(best.waitForExistence(timeout: 3), "mantener presionado no abrió el selector")
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'quickhire.picker.option.'"))
        XCTAssertGreaterThanOrEqual(options.count, 2, "el escenario tiene varios contratables")
        attach(app, named: "E3 selector del atajo")

        let other = try XCTUnwrap((0..<options.count).map { options.element(boundBy: $0) }
            .first { !$0.identifier.hasSuffix(".\(currentID)") })
        let pinnedID = String(other.identifier.dropFirst("quickhire.picker.option.".count))
        other.tap()
        XCTAssertTrue(best.waitForNonExistence(timeout: 3), "elegir cierra el selector")
        XCTAssertTrue(waitForValue(of: quickHire) { $0.contains(":\(pinnedID);pinned") },
                      "el atajo no quedó fijado en \(pinnedID)")

        quickHire.press(forDuration: 0.9)
        XCTAssertTrue(best.waitForExistence(timeout: 3))
        best.tap()
        XCTAssertTrue(waitForValue(of: quickHire) { !$0.contains(";pinned") }, "Mejor disponible suelta el pin")
    }

    @MainActor
    func testTocarAfueraCierraElSelector() throws {
        let app = launch()
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(waitUntilHittable(quickHire))
        quickHire.press(forDuration: 0.9)
        let best = app.buttons["quickhire.picker.best"]
        XCTAssertTrue(best.waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
        XCTAssertTrue(best.waitForNonExistence(timeout: 3), "tocar afuera cierra")
    }

    @MainActor
    func testConElPisoLlenoElAtajoSigueYAvisa() throws {
        let app = launch()
        openDebug("debug.floor.fill", in: app)
        let quickHire = app.buttons["hud.quickhire"]
        XCTAssertTrue(waitForValue(of: quickHire) { $0.hasPrefix("floorFull:") }, "el atajo no dice piso lleno")
        XCTAssertTrue(waitUntilHittable(quickHire))
        quickHire.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tower.notice"].waitForExistence(timeout: 3),
                      "tocar con el piso lleno avisa")
    }

    // MARK: - Utilidades

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func openDebug(_ identifier: String, in app: XCUIApplication) {
        let debugKey = app.buttons["hud.debug"]
        XCTAssertTrue(debugKey.waitForExistence(timeout: 6))
        debugKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 6), "el panel de debug no ofrece \(identifier)")
        button.tap()
        XCTAssertTrue(button.waitForNonExistence(timeout: 6))
    }

    @MainActor
    private func waitForValue(of element: XCUIElement, timeout: TimeInterval = 5,
                              _ matches: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = element.value as? String, matches(value) { return true }
            usleep(200_000)
        }
        return false
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

- [ ] **Step 2: Verlo fallar**

Run: Receta R con `-only-testing:FisuEvolutionUITests/QuickHireUITests`.
Expected: FAIL — `el panel de debug no ofrece debug.quickhire.many` (y el selector no existe).

- [ ] **Step 3: El selector**

`FisuEvolution/UI/HUD/QuickHirePicker.swift`:

```swift
import SwiftUI

/// El selector del atajo (PLAN-v2 E3): una tarjeta colgada del atajo con las
/// caras de los personajes que el jugador puede contratar, para fijar uno.
///
/// **No es una hoja**: el juego sigue corriendo detrás. Tocar una cara la fija;
/// tocar la fijada o "Mejor disponible" la suelta; tocar afuera cierra. Nunca
/// muestra un tipo sin desbloquear (`quickHirePickerEntries` sale de la misma
/// compuerta que FisuJobs).
struct QuickHirePicker: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// El marco del atajo en la pantalla (el ancla `.quickHire` del tutorial).
    let anchor: CGRect?
    let close: () -> Void

    private static let columns = 4
    private static let cellWidth: CGFloat = 64
    private static let gridMaxHeight: CGFloat = 300
    private static var cardWidth: CGFloat {
        CGFloat(columns) * cellWidth + CGFloat(columns - 1) * Tokens.s8 + PanelCard<EmptyView>.contentInset * 2
    }

    var body: some View {
        // Los precios y los llenos se mueven con el tablero.
        let _ = gameState.boardVersion
        let entries = gameState.quickHirePickerEntries
        GeometryReader { proxy in
            let leading = cardLeading(in: proxy.size)
            ZStack(alignment: .bottomLeading) {
                Color.black.opacity(0.18)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(Text("store.close"))
                    .accessibilityIdentifier("quickhire.picker.close")
                card(entries, tailX: (anchor?.midX ?? leading + 40) - leading)
                    .padding(.leading, leading)
                    .padding(.bottom, proxy.size.height - (anchor?.minY ?? proxy.size.height * 0.8) + 14)
            }
        }
        .ignoresSafeArea()
        .transition(reduceMotion ? .opacity : .scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
    }

    private func cardLeading(in size: CGSize) -> CGFloat {
        let wanted = anchor?.minX ?? Tokens.s12
        return min(max(Tokens.s12, wanted), size.width - Self.cardWidth - Tokens.s12)
    }

    private func card(_ entries: [QuickHirePickerEntry], tailX: CGFloat) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: Tokens.s12) {
                Text("quickhire.picker.title")
                    .font(Tokens.title)
                    .foregroundStyle(Color("PaletteInk"))
                bestButton(isActive: !entries.contains(where: \.isPinned))
                ScrollView {
                    // `Grid` y no `LazyVGrid`: la perezosa pierde identifiers.
                    Grid(horizontalSpacing: Tokens.s8, verticalSpacing: Tokens.s8) {
                        ForEach(Array(rows(entries).enumerated()), id: \.offset) { _, row in
                            GridRow {
                                ForEach(row) { entry in option(entry) }
                            }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: Self.gridMaxHeight)
            }
        }
        .frame(width: Self.cardWidth)
        .overlay(alignment: .bottomLeading) {
            PickerTail()
                .fill(Color("PaletteInk").opacity(0.9))
                .frame(width: 20, height: 12)
                .offset(x: max(16, min(tailX - 10, Self.cardWidth - 36)), y: 11)
                .accessibilityHidden(true)
        }
    }

    private func rows(_ entries: [QuickHirePickerEntry]) -> [[QuickHirePickerEntry]] {
        stride(from: 0, to: entries.count, by: Self.columns).map {
            Array(entries[$0 ..< min($0 + Self.columns, entries.count)])
        }
    }

    private func bestButton(isActive: Bool) -> some View {
        Button {
            gameState.pinQuickHire(typeId: nil)
            close()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "sparkles")
                    .font(.system(size: 14, weight: .black))
                Text("quickhire.picker.best")
                    .font(Tokens.body)
            }
            .foregroundStyle(isActive ? .white : Color("PaletteInk"))
            .shadow(color: .black.opacity(isActive ? 0.45 : 0), radius: 1, y: 1)
            .padding(.horizontal, Tokens.s12)
            .padding(.vertical, Tokens.s8)
            .frame(maxWidth: .infinity)
            .background(
                PillBackground(
                    fill: isActive ? Color("PaletteGreen") : Color("PaletteCream"),
                    border: isActive ? nil : Color("PaletteBrown").opacity(0.6)
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quickhire.picker.best")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func option(_ entry: QuickHirePickerEntry) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button {
            gameState.pinQuickHire(typeId: entry.isPinned ? nil : entry.id)
            close()
        } label: {
            VStack(spacing: 2) {
                GameIcon(artKey: entry.faceKey, size: 44) { EmptyView() }
                    .overlay(alignment: .topTrailing) {
                        if entry.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 11, weight: .black))
                                .rotationEffect(.degrees(30))
                                .offset(x: 4, y: -4)
                        }
                    }
                if entry.fits {
                    HStack(spacing: 2) {
                        CoinIcon(size: 12)
                        Text(verbatim: entry.costText)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                } else {
                    Text("quickhire.picker.full")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(Color("PaletteInk"))
            .frame(width: Self.cellWidth, height: 68)
            .background(shape.fill(entry.isPinned ? Color("PaletteYellow").opacity(0.55) : Color("PaletteCream")))
            .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(entry.isPinned ? 0.9 : 0.45),
                                        lineWidth: entry.isPinned ? 2.5 : 1.5))
            .opacity(entry.fits ? 1 : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quickhire.picker.option.\(entry.id)")
        .accessibilityLabel(Text(verbatim: String(localized: "quickhire.ax.purpose \(entry.displayName)")))
        .accessibilityValue(entry.isPinned
            ? Text("quickhire.ax.pinned")
            : (entry.fits ? Text(verbatim: String(localized: "price.ax.coins \(entry.costText)")) : Text("quickhire.picker.full")))
    }
}

/// La cola de la tarjeta, apuntando al atajo.
private struct PickerTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
```

- [ ] **Step 4: Montarlo en `RootView`**

En `GameBoardView`:

```swift
    /// El selector del atajo: un overlay sobre el juego, no una hoja.
    @State private var showQuickHirePicker = false
```

En `bottomBar`, `QuickHireButton()` pasa a:

```swift
                QuickHireButton(onChoose: {
                    withAnimation(.spring(duration: 0.3)) { showQuickHirePicker = true }
                })
                .tutorialAnchor(.quickHire)
```

En el `overlayPreferenceValue(TutorialAnchorKey.self)`, el `ZStack` suma el selector (lo cuelga
del marco real del atajo, que es justo lo que ese overlay ya resuelve):

```swift
                ZStack {
                    TutorialOverlay(anchors: resolved)
                    TutorialTipView(anchors: resolved)
                    if showQuickHirePicker {
                        QuickHirePicker(anchor: resolved[.quickHire]) {
                            withAnimation(.easeOut(duration: 0.2)) { showQuickHirePicker = false }
                        }
                    }
                }
```

Los comentarios que dejaron de ser verdad: en el docstring de `bottomBar`, el párrafo "La
aparición/desaparición del atajo (`quickHireOffer` pasa a `nil` …)" pasa a "El atajo no
desaparece nunca (PLAN-v2 E3): el único que se dibuja o se va es el prestigio, y va arriba para
no moverle el piso al atajo"; en `TowerNoticeView`, el bloque "⚠️ Cuando `quickHireOffer` es
`nil` el atajo no se dibuja…" se borra entero.

- [ ] **Step 5: Las puertas de debug**

En `DebugPanelView.swift`, después de "Ficha":

```swift
                Section("Atajo") {
                    // El piso visible lleno con Fisuras: el atajo tiene que
                    // quedarse y decir "Piso lleno".
                    Button("Llenar el piso visible") {
                        gameState.debugGrantCoins()
                        if let base = gameState.content?.tiers.baseType.id {
                            var guardrail = 0
                            while gameState.visibleFloorOccupancy.occupied < gameState.visibleFloorOccupancy.capacity,
                                  guardrail < 30 {
                                gameState.hireCharacter(typeId: base)
                                guardrail += 1
                            }
                        }
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.floor.fill")
                    // Varios contratables a la vez, para que el selector tenga
                    // a quién fijar (el escenario de `QuickHireOfferTests`).
                    Button("Varios contratables (frontera 18)") {
                        gameState.debugUnlockFloors(throughTier: 13)
                        gameState.debugMarkTypesSeen(throughTier: 12)
                        gameState.debugSetMaxTier(18)
                        gameState.debugGrantCoins()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.quickhire.many")
                }
```

- [ ] **Step 6: Las strings**

`Tools/v2/claves-pendientes/e3b-t8.json`:

```json
{
  "quickhire.picker.title": {"es": "¿A quién contratamos?", "en": "Who are we hiring?"},
  "quickhire.picker.best": {"es": "Mejor disponible", "en": "Best available"},
  "quickhire.picker.full": {"es": "Lleno", "en": "Full"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e3b-t8.json`.

- [ ] **Step 7: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con UI `QuickHireUITests`,
`QuickHireButtonUITests`, `TutorialUITests`, `BottomMenuUITests` → PASS; unit
`LocalizationCompletenessTests` → PASS. Captura del selector en el SE (tiene que entrar entero)
al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/UI/HUD/QuickHirePicker.swift FisuEvolution/App/RootView.swift \
  FisuEvolution/UI/DebugPanelView.swift FisuEvolutionUITests/QuickHireUITests.swift
# + el catálogo o el snapshot e3b-t8.json, según la ola
git diff --cached --stat
git commit -m "feat(ux): el selector del atajo para fijar a quién contratar"
```

---

### Task 9: Compartir recableado — los momentos virales, con premio una vez

**Objetivo:** compartir vuelve a existir. Un personaje nuevo, un piso nuevo, una reencarnación
y la llegada a Dios **encolan un momento viral**; cuando no hay nada celebrándose (sin
celebración, sin hoja, sin tutorial obligatorio) se ofrece como un **botón** —nunca un popup—
que abre la tarjeta vertical de siempre (`ShareCardView`), ahora por momento, en es y en.
Compartir de verdad paga un premio chico en minutos de producción **una vez por momento**
(`engagement.sharedMoments`) y vuelven el bonus viral (+0,5 % por compartida, tope 20) y el
logro `ach_share_1`. El tutorial presenta el botón la primera vez (lección `.share`).

**Files:**
- Create: `FisuEvolution/Game/State/ShareMoment.swift`
- Create: `FisuEvolution/Game/State/GameState+Share.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` (`shareCardSubject` → `shareCardMoment`; `shareOffer`, `pendingShareMoment`, `shareOffersEnabled`; `refreshProjections`; `updateMaxFloorStat`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (se van `offerShareCard`, `dismissShareCard`, `registerShareCompleted`)
- Modify: `FisuEvolution/Game/State/GameState+BoardChanges.swift` (`markRevealed(tier:)`)
- Modify: `FisuEvolution/Game/State/GameState+Prestige.swift` (`confirmPrestige`)
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift` (lección `.share`; el guardia de `refreshTutorialTip`)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`--uitest-share`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` (`TutorialTarget.share`)
- Modify: `FisuEvolution/UI/Share/ShareCardView.swift` (por momento; id de "Ahora no")
- Create: `FisuEvolution/UI/Share/ShareMomentChip.swift`
- Modify: `FisuEvolution/App/RootView.swift` (el botón; la hoja de la tarjeta)
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (`debug.share.offer`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift` (`sharedMoments`)
- Modify: `FisuEvolution/Managers/ContentConfigs.swift` (`ViralConfig.momentRewardMinutes`) y `FisuEvolution/Resources/Config/viral.json`
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (snapshot `e3b-t9.json`)
- Create: `FisuEvolutionTests/ShareMomentTests.swift`, `Packages/EconomyKit/Tests/EconomyKitTests/EngagementStateTests.swift`, `FisuEvolutionUITests/ShareMomentUITests.swift`

**Interfaces:**
- Consumes: `EngagementState` y `MetaState.engagement` (E1 T4); `markRevealed(tier:)` (E1 T9);
  `GameState.coinReward(seconds:player:content:economy:)` `static` (E1 T14);
  `UpgradeManager.recomputeDerivedEffects(state:config:specials:viral:boosts:economy:)` (E1 T2).
- Produces: `enum ShareMoment` (`.newCharacter`, `.newFloor(floorID:)`, `.reincarnation(level:)`,
  `.god`; `key`, `weight`); `GameState.shareOffer`, `shareCardMoment`, `queueShareMoment(_:)`,
  `presentShareMomentIfCalm()`, `noteRevealedTier(_:)`, `openShareCard()`,
  `dismissShareOffer()`, `dismissShareCard()`, `registerShareCompleted(_:)`,
  `shareRewardMinutesText`; `EngagementState.sharedMoments: Set<String>`;
  `TutorialLesson.share`, `TutorialTarget.share`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/EngagementStateTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

/// Los momentos compartidos viven en `meta.engagement` (sin subir el schema).
@Suite("EngagementState: los momentos compartidos")
struct EngagementStateTests {
    @Test("un engagement escrito antes de E3 decodifica sin momentos")
    func decodesWithoutTheKey() throws {
        let state = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(state.sharedMoments.isEmpty)
    }

    @Test("ida y vuelta")
    func roundTrip() throws {
        var state = EngagementState.initial
        state.sharedMoments = ["floor.urban", "god"]
        let decoded = try JSONDecoder().decode(EngagementState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
    }

    @Test("al resolver un conflicto de saves, lo compartido se une: nunca se cobra dos veces")
    func resolveUnions() {
        var winner = EngagementState.initial
        winner.sharedMoments = ["floor.urban"]
        var loser = EngagementState.initial
        loser.sharedMoments = ["god"]
        #expect(EngagementState.resolve(winner: winner, loser: loser).sharedMoments == ["floor.urban", "god"])
    }
}
```

`FisuEvolutionTests/ShareMomentTests.swift`:

```swift
import EconomyKit
import Testing
@testable import FisuEvolution

/// Compartir los momentos virales (PLAN-v2 E3): qué se ofrece, cuándo, y que el
/// premio se cobra una vez por momento.
@Suite("Compartir los momentos virales", .serialized)
@MainActor
struct ShareMomentTests {
    @Test("las claves con las que se recuerda lo compartido")
    func keys() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType)
        #expect(ShareMoment.newCharacter(base).key == "character.homeless")
        #expect(ShareMoment.newFloor(floorID: "urban").key == "floor.urban")
        #expect(ShareMoment.reincarnation(level: 3).key == "reincarnation.3")
        #expect(ShareMoment.god(base).key == "god")
    }

    @Test("el premio del dato: cinco minutos de producción")
    func rewardComesFromTheData() async throws {
        let gameState = await makeGameState()
        #expect(gameState.content?.viral.momentRewardMinutes == 5)
    }

    @Test("el momento se ofrece en una pausa, nunca con una hoja arriba")
    func offeredOnlyWhenCalm() async {
        let gameState = await makeGameState()
        gameState.queueShareMoment(.newFloor(floorID: "urban"))
        gameState.uiCoversBoard = true
        gameState.refreshProjections()
        #expect(gameState.shareOffer == nil, "con una hoja abierta no se ofrece")
        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.shareOffer == .newFloor(floorID: "urban"))
    }

    @Test("si caen dos en la misma celebración, se ofrece el más grande")
    func theBiggerMomentWins() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType)
        gameState.uiCoversBoard = true
        gameState.queueShareMoment(.newCharacter(base))
        gameState.queueShareMoment(.newFloor(floorID: "urban"))
        gameState.queueShareMoment(.newCharacter(base))
        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.shareOffer == .newFloor(floorID: "urban"))
    }

    @Test("compartir paga una vez por momento y siempre suma al bonus viral")
    func paysOncePerMoment() async throws {
        let gameState = await makeGameState()
        let coins0 = try #require(gameState.player?.run.coins)

        gameState.registerShareCompleted(.newFloor(floorID: "urban"))
        let coins1 = try #require(gameState.player?.run.coins)
        #expect(coins1 > coins0, "el primer share del momento paga")
        #expect(gameState.player?.meta.sharesCompleted == 1)
        #expect(gameState.player?.meta.engagement.sharedMoments.contains("floor.urban") == true)
        #expect(gameState.player?.meta.unlockedAchievements.contains("ach_share_1") == true,
                "el logro de compartir vuelve a ser posible")

        gameState.registerShareCompleted(.newFloor(floorID: "urban"))
        #expect(gameState.player?.run.coins == coins1, "el mismo momento no paga dos veces")
        #expect(gameState.player?.meta.sharesCompleted == 2, "pero el bonus viral sí cuenta")
    }

    @Test("un momento ya compartido no se vuelve a ofrecer")
    func aSharedMomentIsNotOfferedAgain() async {
        let gameState = await makeGameState()
        gameState.registerShareCompleted(.newFloor(floorID: "urban"))
        gameState.queueShareMoment(.newFloor(floorID: "urban"))
        gameState.refreshProjections()
        #expect(gameState.shareOffer == nil)
    }

    @Test("apagado (corridas de UI sin --uitest-share), no se ofrece nada")
    func disabledOffersNothing() async {
        let gameState = await makeGameState()
        gameState.shareOffersEnabled = false
        gameState.queueShareMoment(.newFloor(floorID: "urban"))
        gameState.refreshProjections()
        #expect(gameState.shareOffer == nil)
    }
}
```

`FisuEvolutionUITests/ShareMomentUITests.swift`:

```swift
import XCTest

/// Compartir (PLAN-v2 E3): el momento viral se ofrece como botón, abre la
/// tarjeta vertical y se descarta sin interrumpir. La hoja del sistema para
/// compartir no se puede completar desde el runner: eso lo cubre `ShareMomentTests`.
final class ShareMomentUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testElMomentoViralSeOfreceComoBotonYAbreLaTarjeta() throws {
        let app = launch()
        offer(in: app)
        let button = app.buttons["share.offer"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "el momento no se ofreció")
        button.tap()
        XCTAssertTrue(app.buttons["share.button"].waitForExistence(timeout: 5), "no abrió la tarjeta")
        let skip = app.buttons["share.skip"]
        skip.tap()
        XCTAssertTrue(skip.waitForNonExistence(timeout: 8))
        XCTAssertFalse(app.buttons["share.offer"].exists, "abrirla consume la oferta")
    }

    @MainActor
    func testLaOfertaSeDescartaConLaX() throws {
        let app = launch()
        offer(in: app)
        let dismiss = app.buttons["share.offer.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        dismiss.tap()
        XCTAssertTrue(app.buttons["share.offer"].waitForNonExistence(timeout: 3))
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-share"]
        app.launch()
        XCTAssertTrue(app.buttons["hud.hire"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func offer(in app: XCUIApplication) {
        let debugKey = app.buttons["hud.debug"]
        XCTAssertTrue(debugKey.waitForExistence(timeout: 6))
        debugKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let button = app.buttons["debug.share.offer"]
        XCTAssertTrue(button.waitForExistence(timeout: 6))
        button.tap()
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter EngagementStateTests` → no compila
(`sharedMoments`). `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/ShareMomentTests` → no compila (`ShareMoment`).

- [ ] **Step 3: `EngagementState` y el dato**

En `EngagementState.swift` (E1 T4 lo creó vacío; si otra épica ya le sumó campos y su propio
`init(from:)`, se agrega este campo a ese mismo `init` y a ese mismo `resolve`):

```swift
public struct EngagementState: Codable, Sendable, Equatable {
    public static let initial = EngagementState()

    /// Las claves de los momentos virales ya compartidos (`ShareMoment.key` en la
    /// app): cada uno paga su premio una sola vez (PLAN-v2 E3).
    public var sharedMoments: Set<String>

    public init(sharedMoments: Set<String> = []) {
        self.sharedMoments = sharedMoments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sharedMoments = try container.decodeIfPresent(Set<String>.self, forKey: .sharedMoments) ?? []
    }

    /// Lo compartido se une: con dos dispositivos, un momento cobrado en
    /// cualquiera de los dos no se vuelve a cobrar.
    public static func resolve(winner: EngagementState, loser: EngagementState) -> EngagementState {
        var resolved = winner
        resolved.sharedMoments.formUnion(loser.sharedMoments)
        return resolved
    }
}
```

`ContentConfigs.swift`, `ViralConfig`: `let momentRewardMinutes: Int` (con un docstring: "El
premio de compartir un momento viral, en minutos de producción real, una vez por momento").
`Config/viral.json`: `"momentRewardMinutes": 5` después de `maxShares`.

- [ ] **Step 4: Los momentos y la lógica**

`FisuEvolution/Game/State/ShareMoment.swift`:

```swift
import EconomyKit

/// Un momento viral (PLAN-v2 E3): lo que se ofrece compartir cuando termina su
/// celebración, con la tarjeta vertical y un premio chico la primera vez.
enum ShareMoment: Equatable, Identifiable {
    case newCharacter(CharacterType)
    case newFloor(floorID: String)
    case reincarnation(level: Int)
    /// El último tier: la llegada a Dios.
    case god(CharacterType)

    /// Con esto se recuerda que ya se compartió (`engagement.sharedMoments`).
    var key: String {
        switch self {
        case .newCharacter(let type): "character.\(type.id)"
        case .newFloor(let floorID): "floor.\(floorID)"
        case .reincarnation(let level): "reincarnation.\(level)"
        case .god: "god"
        }
    }

    var id: String { key }

    /// Si dos caen en la misma celebración (un tier nuevo que abre un piso), se
    /// ofrece el más grande.
    var weight: Int {
        switch self {
        case .newCharacter: 1
        case .newFloor: 2
        case .reincarnation: 3
        case .god: 4
        }
    }
}
```

En `GameState.swift`, `var shareCardSubject: CharacterType?` (`:243-244`, con su comentario)
pasa a:

```swift
    /// La tarjeta de compartir abierta. Lo escribe `+Share`.
    var shareCardMoment: ShareMoment?
    /// El momento viral ofrecido como botón. Lo escribe `+Share`.
    var shareOffer: ShareMoment?
    /// El momento que espera una pausa para ofrecerse. Lo escribe `+Share`.
    @ObservationIgnored var pendingShareMoment: ShareMoment?
    /// Con `false` no se ofrece nada (corridas de UI sin `--uitest-share`).
    @ObservationIgnored var shareOffersEnabled = true
```

en `refreshProjections()`, antes de `refreshTutorialTip()`:

```swift
        presentShareMomentIfCalm()
```

y en `updateMaxFloorStat()`, adentro del `if maxUnlocked > player.meta.stats.maxFloorOrdinalEver`:

```swift
            queueShareMoment(.newFloor(floorID: content.floorTable[maxUnlocked].id))
```

`FisuEvolution/Game/State/GameState+Share.swift`:

```swift
import EconomyKit
import Foundation

/// Compartir los momentos virales (PLAN-v2 E3): se encolan donde pasan, se
/// ofrecen en una pausa como botón (nunca un popup) y pagan una vez por momento.
extension GameState {
    /// Un momento nuevo. Uno ya compartido no se ofrece más; si ya hay uno
    /// esperando, queda el más grande.
    func queueShareMoment(_ moment: ShareMoment) {
        guard shareOffersEnabled, let player,
              !player.meta.engagement.sharedMoments.contains(moment.key)
        else { return }
        if let pending = pendingShareMoment, pending.weight > moment.weight { return }
        pendingShareMoment = moment
    }

    /// Lo llama `refreshProjections`: el momento pendiente pasa a oferta en una
    /// pausa natural —sin celebración, sin hoja, sin la fase del tutorial—.
    func presentShareMomentIfCalm() {
        guard let moment = pendingShareMoment, shareOffer == nil, shareCardMoment == nil,
              phase == .ready, !uiCoversBoard, characterSheet == nil,
              celebrations.current == nil, !tutorialPhaseActive
        else { return }
        pendingShareMoment = nil
        shareOffer = moment
    }

    /// El reveal de un tier (lo llama `markRevealed`): personaje nuevo, o Dios.
    func noteRevealedTier(_ tier: Int) {
        guard let content, let player else { return }
        let candidates = content.tiers.concreteTypes.filter { $0.tier == tier }
        guard let type = candidates.first(where: { player.run.seenTypes.contains($0.id) }) ?? candidates.first
        else { return }
        queueShareMoment(tier == content.tiers.maxTier ? .god(type) : .newCharacter(type))
    }

    func openShareCard() {
        guard let moment = shareOffer else { return }
        tutorialTipCompleted(.share)
        shareOffer = nil
        shareCardMoment = moment
    }

    func dismissShareOffer() {
        shareOffer = nil
    }

    func dismissShareCard() {
        shareCardMoment = nil
    }

    /// Los minutos del premio, para el botón ("+5 min").
    var shareRewardMinutesText: String {
        String(content?.viral.momentRewardMinutes ?? 0)
    }

    /// La hoja del sistema confirmó que se compartió. El premio en minutos de
    /// producción, una vez por momento; el bonus viral (+0,5 %, tope 20) y el
    /// logro, siempre.
    func registerShareCompleted(_ moment: ShareMoment) {
        guard let content, let economy, var player else { return }
        if player.meta.engagement.sharedMoments.insert(moment.key).inserted {
            let seconds = Double(content.viral.momentRewardMinutes) * 60
            player.run.coins += Self.coinReward(seconds: seconds, player: player, content: content, economy: economy)
            audio?.play(.coin)
        }
        if player.meta.sharesCompleted < content.viral.maxShares {
            player.meta.sharesCompleted += 1
            UpgradeManager.recomputeDerivedEffects(
                state: &player,
                config: content.upgradesConfig,
                specials: content.specials,
                viral: content.viral,
                boosts: content.boosts,
                economy: economy
            )
            effectsVersion += 1
        }
        self.player = player
        evaluateAchievements()
        refreshProjections()
        scheduleSave()
    }

    #if DEBUG
    /// La puerta de los tests de UI: un piso nuevo para compartir, ya mismo.
    func debugOfferShareMoment() {
        guard let content, content.floorTable.floors.count > 1 else { return }
        queueShareMoment(.newFloor(floorID: content.floorTable[1].id))
        refreshProjections()
    }
    #endif
}
```

En `GameState+Bonus.swift` se borran `offerShareCard(for:)`, `dismissShareCard()` y
`registerShareCompleted()` (con sus docstrings): los reemplaza `+Share`.

En `GameState+BoardChanges.swift`, `markRevealed(tier:)`, después de `scheduleSave()`:

```swift
        noteRevealedTier(tier)
```

En `GameState+Prestige.swift`, `confirmPrestige()`, después de `reconcileTower()`:

```swift
        // Reencarnar es un momento viral: se ofrece cuando el cofre épico y el
        // resto de la celebración terminan (`presentShareMomentIfCalm`).
        queueShareMoment(.reincarnation(level: player.meta.prestigeLevel))
```

En `GameState+Debug.swift`, `applyLaunchArgumentDefaults`, al final:

```swift
        // Compartir es nuevo de la 2.0: bajo `--uitest*` no se ofrece nada salvo
        // que el test lo pida, o el botón aparecería encima de cualquier test
        // que fusione.
        if arguments.contains(where: { $0.hasPrefix("--uitest") }),
           !arguments.contains("--uitest-share") {
            shareOffersEnabled = false
        }
```

- [ ] **Step 5: La lección del tutorial**

`TutorialAnchor.swift`, en `TutorialTarget`, después de `prestige`:

```swift
    /// El botón de compartir un momento viral.
    case share
```

`GameState+TutorialTips.swift`: `case share` al final de `TutorialLesson` (con su docstring:
"El primer momento viral ofrecido: el botón de compartir y su premio"), y en sus `switch`:
`anchorTarget` → `case .share: .share`; `destinationScreen` → `.share` en la lista de los que
devuelven `nil`; `textKey` → `case .share: "tutorial.tip.share"`; `isEligible` →
`case .share: shareOffer != nil`. En `refreshTutorialTip()`, el guardia
`characterSheet == nil, shareCardSubject == nil` pasa a `characterSheet == nil, shareCardMoment == nil`.

- [ ] **Step 6: La tarjeta por momento y el botón**

`ShareCardView.swift`: `ShareCardSheet` recibe `let moment: ShareMoment` (en vez de
`subject: CharacterType`), `ShareCardContent(subject:)` pasa a `ShareCardContent(moment:)`, la
completion de `ActivityShareView` llama `gameState.registerShareCompleted(moment)`, y el botón
"Ahora no" suma `.accessibilityIdentifier("share.skip")`. En `ShareCardContent`, el nombre, el
remate y el glifo salen del momento:

```swift
private struct ShareCardContent: View {
    let moment: ShareMoment

    private var headline: String {
        switch moment {
        case .newCharacter(let type), .god(let type): type.localizedName.uppercased()
        case .newFloor(let floorID): TowerNaming.floorName(for: floorID).uppercased()
        case .reincarnation(let level): String(localized: "share.card.reincarnation.title \(String(level))").uppercased()
        }
    }

    private var caption: Text {
        switch moment {
        case .newCharacter(let type): Text("share.card.caption \(type.localizedName)")
        case .newFloor(let floorID): Text("share.card.floor \(TowerNaming.floorName(for: floorID))")
        case .reincarnation: Text("share.card.reincarnation")
        case .god: Text("share.card.god")
        }
    }

    private var symbolName: String {
        switch moment {
        case .newCharacter(let type), .god(let type):
            type.spritePlaceholder.hasPrefix("sf:") ? String(type.spritePlaceholder.dropFirst(3)) : "person.fill"
        case .newFloor: "building.2.fill"
        case .reincarnation: "arrow.triangle.2.circlepath"
        }
    }
```

y en su `body`, `Text(verbatim: subject.localizedName.uppercased())` pasa a
`Text(verbatim: headline)` y `Text("share.card.caption \(subject.localizedName)")` a `caption`
(con los mismos modificadores). `renderCard()` usa `ShareCardContent(moment: moment)`.

`FisuEvolution/UI/Share/ShareMomentChip.swift`:

```swift
import SwiftUI

/// El botón de compartir un momento viral (PLAN-v2 E3): aparece cuando terminó
/// la celebración, encima de la franja de abajo, y se va solo. **Nunca es un
/// popup**: no tapa nada ni pide nada.
struct ShareMomentChip: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let moment: ShareMoment

    static let lifetime: Duration = .seconds(10)

    /// Arriba de los dos toasts de `RootView` (el de logros llega a 264 pt de
    /// la safe area con su aire), para que los tres se lean apilados.
    @MainActor static var bottomPadding: CGFloat {
        GameTabBar.barHeight + 8 + QuickHireButton.capsuleHeight + 8 + 45 + 63 + 63 + GameTabBar.bottomFloor
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: Tokens.s8) {
                ActionPill(
                    titleKey: "share.offer \(gameState.shareRewardMinutesText)",
                    systemImage: "square.and.arrow.up",
                    tint: Color("PaletteBlue"),
                    identifier: "share.offer"
                ) {
                    gameState.openShareCard()
                }
                .tutorialAnchor(.share)
                Button { gameState.dismissShareOffer() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color("PaletteInk"))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(Color("PaletteCream"))
                                .overlay(Circle().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("share.offer.dismiss")
                .accessibilityLabel(Text("share.skip"))
            }
            .padding(.bottom, Self.bottomPadding)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .task(id: moment.id) {
            try? await Task.sleep(for: Self.lifetime)
            // Si el tutorial lo está señalando, se queda hasta que el jugador
            // decida.
            guard !Task.isCancelled, gameState.tutorialTip?.lesson != .share else { return }
            gameState.dismissShareOffer()
        }
    }
}
```

En `RootView.swift`, después del `ZStack` del toast de logros:

```swift
            // El botón de compartir un momento viral: mismo patrón de los toasts
            // (la transición necesita que el PADRE abra la transacción).
            ZStack {
                if let offer = gameState.shareOffer {
                    ShareMomentChip(moment: offer)
                }
            }
            .animation(.spring(duration: 0.32), value: gameState.shareOffer?.id)
```

y la hoja de la tarjeta:

```swift
        .sheet(item: Binding(
            get: { gameState.shareCardMoment },
            set: { if $0 == nil { gameState.dismissShareCard() } }
        )) { moment in
            ShareCardSheet(moment: moment)
        }
```

`DebugPanelView.swift`, después de "Atajo":

```swift
                Section("Compartir") {
                    Button("Ofrecer compartir (piso nuevo)") {
                        gameState.debugOfferShareMoment()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.share.offer")
                }
```

- [ ] **Step 7: Las strings**

`Tools/v2/claves-pendientes/e3b-t9.json`:

```json
{
  "share.offer %@": {"es": "¡Compartilo! +%@ min", "en": "Share it! +%@ min"},
  "share.card.floor %@": {"es": "Abrí %@ y vos seguís en el callejón 💀", "en": "I opened %@ and you're still in the alley 💀"},
  "share.card.reincarnation.title %@": {"es": "Reencarnación %@", "en": "Reincarnation %@"},
  "share.card.reincarnation": {"es": "Volví a empezar, pero con plata 😎", "en": "Started over, but loaded 😎"},
  "share.card.god": {"es": "Llegué a Dios. Literal. 🙏", "en": "I made it to God. Literally. 🙏"},
  "tutorial.tip.share": {"es": "¡Compartilo y te llevás un premio! Una vez por cada logro.", "en": "Share it and grab a bonus! Once per milestone."}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e3b-t9.json`.

- [ ] **Step 8: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (con `EngagementStateTests` y los de
E1 de `SaveCompatibilityTests`/`SaveConflictResolverTests`); `/opt/homebrew/bin/xcodegen generate`;
Receta R con unit `ShareMomentTests`, `TutorialTipsTests`, `AchievementEngineTests`,
`StatsSnapshotTests`, `LocalizationCompletenessTests` (la familia de las lecciones exige
`tutorial.tip.share`; si `TutorialTipsTests` pinea la lista de lecciones, `.share` va al final),
`GameContentValidationTests` → PASS (los usos de `shareCardSubject` que queden, el compilador
los lista: pasan a `shareCardMoment`); UI `ShareMomentUITests`,
`TutorialUITests`, `AscentRenderingUITests` (sin `--uitest-share` no aparece ningún botón) →
PASS. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 9: Commit**

```bash
git add FisuEvolution/Game/State/ShareMoment.swift FisuEvolution/Game/State/GameState+Share.swift \
  FisuEvolution/Game/State/GameState.swift FisuEvolution/Game/State/GameState+Bonus.swift \
  FisuEvolution/Game/State/GameState+BoardChanges.swift FisuEvolution/Game/State/GameState+Prestige.swift \
  FisuEvolution/Game/State/GameState+TutorialTips.swift FisuEvolution/Game/State/GameState+Debug.swift \
  FisuEvolution/UI/Tutorial/TutorialAnchor.swift FisuEvolution/UI/Share/ShareCardView.swift \
  FisuEvolution/UI/Share/ShareMomentChip.swift FisuEvolution/App/RootView.swift \
  FisuEvolution/UI/DebugPanelView.swift Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift \
  FisuEvolution/Managers/ContentConfigs.swift FisuEvolution/Resources/Config/viral.json \
  FisuEvolutionTests/ShareMomentTests.swift Packages/EconomyKit/Tests/EconomyKitTests/EngagementStateTests.swift \
  FisuEvolutionUITests/ShareMomentUITests.swift
# + el catálogo o el snapshot e3b-t9.json, según la ola
git diff --cached --stat
git commit -m "feat(ux): compartir vuelve en los momentos virales, con premio una vez por momento"
```

- [ ] **Step 10: Cierre de E3 (controlador)**

1. `Tools/v2/oraculo.sh completo --limpio` y otra vez sin tocar nada → `VERDE` las dos.
2. A mano, en el simulador propio: mantener el atajo y fijar; piso lleno; la ficha grande y
   despedir; deslizar el menú y Ajustes bloqueando; un reveal → botón de compartir → tarjeta.
3. `Docs/SESION-<fecha>-v2-e3b.md`, las cuatro ediciones de `Docs/HANDOFF.md` (§4 la entrada
   de E3b; §5: el atajo nunca desaparece y el pin vive en el save, la confirmación de la casa
   reemplaza a las alertas, el menú es una hoja con sesión, compartir es botón y nunca popup;
   §7 las trampas; §9), journal, `LOCK` y `handoffs/HANDOFF-<fecha>-v2-e3b.md`.

---

## Para el dueño / dudas

Ninguna frena: la ejecución sigue con el supuesto anotado.

1. **El motivo en la 2ª línea del atajo.** La spec pide "gris de la casa con el motivo en la
   2ª línea". Con "Piso lleno" la segunda línea lo dice. Con "no te alcanza" **la segunda línea
   sigue siendo el precio, en gris**: la oferta en ese estado es la meta de ahorro (paso 3 de la
   resolución) y sacar el número la vaciaría. El motivo lo dicen el gris, el temblor y VoiceOver.
2. **El pin sobrevive a reencarnar.** Vive en `meta` (save v6 de E1): después de reencarnar
   vuelve a mandar en cuanto el tipo se desbloquee de nuevo. Mientras tanto se ignora sin
   borrarse, como pide la spec.
3. **La ficha ya no tiene un "Equipar" deshabilitado.** Con la pinta puesta se ve el estado
   "Puesta" (`character.skin.wearing`, la misma clave `skins.equipped` que Pintas); por eso cambian dos tests de UI que esperaban el
   botón. Las flechas de la ficha y del menú **sí** se deshabilitan en el extremo (sin vuelta):
   son flechas de navegación y `LaunchSmokeTests` pinea esa semántica.
4. **Despedir se prueba con una puerta del panel de debug** (`debug.sheet.open`, contrata un
   segundo Fisura y abre la ficha) y no con un launch argument nuevo: los fixtures viven en
   `GameState.bootstrap`, que es caliente durante todo E1.
5. **El orden de las páginas del menú es el de la barra** (Mejoras, Vestimenta, Contratar,
   Bonus, Tienda, Menú; E3a T7), no `GameScreen.allCases`. Deslizar recorre lo mismo que se ve
   abajo.
6. **Un intersticial por sesión de menú, al cerrarla.** Hoy sale uno por hoja cerrada; con el
   menú deslizable el jugador recorre cinco pestañas y come uno. Es lo que pide la spec y baja
   la frecuencia: E7 lo tiene en cuenta al calibrar.
7. **"Personaje nuevo" es por run.** El reveal ocurre la primera vez que el tier aparece en la
   run (`markRevealed`), así que después de reencarnar el mismo personaje vuelve a ser "nuevo":
   el botón se ofrece de nuevo sólo si ese momento todavía no se compartió (y nunca paga dos
   veces). Si el dueño lo quiere por cuenta, el cambio es un filtro en `noteRevealedTier`.
8. **El premio de compartir son 5 minutos** de producción (`viral.json`
   `momentRewardMinutes`), con `coinReward` como los logros. Cuando E2a mueva los premios a
   `RewardScale`, éste se muda con ellos.
9. **El botón de compartir dura 10 s** si nadie lo toca (salvo que el tutorial lo esté
   señalando). Ajustable en `ShareMomentChip.lifetime`.
10. **La lección del atajo** (mantener presionado para fijar) es de E9, como dice la spec; este
    plan no la escribe. La de compartir sí, porque la spec la pone en E3 ("el tutorial lo
    presenta la primera vez").
