# Rediseño de la pantalla principal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** La pantalla principal deja de ser un tablero con islas flotantes: la barra superior se funde con el borde de arriba (panel ink opaco), la barra inferior se funde con el borde de abajo (panel crema con iconos GRANDES y label visible), y aparece un botón nuevo que contrata al personaje del tier más alto que la plata alcanza.

**Architecture:** Todo es restyling de vistas existentes (`HUDView`, `GameTabBar`/`GameTabButton`, `BottomMenuBar`, `RootView.bottomBar`) más UNA proyección nueva en `GameState` (`bestHire`, publicada por `refreshProjections` con el patrón write-only-on-change) y UNA vista nueva (`QuickHireButton`). La lógica de selección reusa la compuerta existente de FisuJobs (`jobState` + `currentQuote(player:typeId:)`): el botón nuevo no inventa reglas de autorización, elige entre lo que FisuJobs ya ofrece como `hirable`.

**Tech Stack:** SwiftUI (iOS 17+), Swift 6 strict concurrency, EconomyKit intacto (no se toca el paquete), XCTest.

## Referencia visual (decisión del dueño, 2026-08-16)

El dueño entregó un mockup (generado por otra IA) como referencia de ESTILO para la pantalla principal. Qué se toma y qué se ignora:

- **SE TOMA**: barra superior como panel OSCURO (nuestro `PaletteInk`) fundido con el borde superior; barra inferior como panel crema fundido con el borde inferior; iconos de tabs protagonistas (MÁS grandes que en el mockup, pedido explícito) con label visible debajo; pills de torre y de prestigio siguen siendo cápsulas flotantes chicas debajo del panel (así están en el mockup y así quedan).
- **SE IGNORA**: los nombres de tabs del mockup (dice "Tools"/"Quests" porque la IA que lo generó inventó; nuestros 6 tabs NO cambian de destino, orden ni identifier), el avatar con "Lv. 16" (no hay niveles en el juego), la píldora de energía (no existe esa mecánica), los botones flotantes de las esquinas (gear/trofeo — Ajustes y Logros ya viven en el Menú).
- El panel superior oscuro en la pantalla principal es decisión del dueño de HOY y **no se re-litiga** en reviews: convive con la regla "FisuJobs es la referencia visual" porque los COMPONENTES internos (IconButton, cápsulas, PricePill-patterns, tokens) siguen siendo los canónicos.

## Global Constraints

- El `.xcodeproj` NO se versiona; al **agregar o borrar** un `.swift` es obligatorio `xcodegen generate`.
- Cero warnings (`SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`).
- Strings nuevos van a `FisuEvolution/Resources/Localizable.xcstrings` (es base + en) **en el mismo commit que su vista**. El catálogo se edita a mano (herramienta Edit), NUNCA con scripts.
- `accessibilityIdentifier` en todo control interactivo; **jamás** en contenedores pelados (trampa 9a-bis: se propaga y pisa a los hijos).
- Identifiers PINEADOS por tests que no pueden cambiar: `hud.coins.plus`, `hud.coins`, `hud.income`, `hud.map`, `tower.pill`, `tower.arrow.up`, `tower.arrow.down`, `hud.prestige.multiplier`, `hud.hire`, `hud.upgrades`, `hud.skins`, `hud.bonus`, `hud.store`, `hud.settings`, `hud.prestige`, `board.units`, `tower.notice`, `ach.toast`.
- Anclas del tutorial que no pueden perderse: `.hudBar` (raíz del HUD), `.coins` (contador), `.map` (ascensor), `.hire` (icono del tab FisuJobs), `.upgrades` (icono del tab Mejoras), `.bottomBar` (franja inferior completa).
- Nada de `.disabled` en botones de compra: patrón `PricePill` (se toca igual, tiembla si no alcanza, el estado se comunica con relleno/desaturación).
- Ninguna animación `repeatForever`; todo pulido se apaga con `accessibilityReduceMotion` y apagado deja el estado FINAL.
- Commits en español, atómicos. TDD donde hay lógica (Task 3).
- Los números de tamaño de este plan son la spec; ±10% de ajuste con captura en mano está permitido, el CONTRASTE de tamaño (iconos mucho más grandes que hoy) es el requisito.
- Verificación: simulador PROPIO por UDID (`xcrun simctl create`), `-parallel-testing-enabled NO`, unit ANTES que UI, borrar el simulador al terminar.

---

### Task 1: Panel superior fundido con el borde de arriba

**Files:**
- Modify: `FisuEvolution/UI/HUD/HUDView.swift`
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (sólo `IconButton`: parámetro nuevo `glyphScale`)
- Modify: `FisuEvolution/Scenes/BoardScene.swift:125` (`topInset`, sólo si la medición lo pide)

**Interfaces:**
- Consumes: `GameState.coinsText`, `towerIncomePerSecondText`, `towerNavigation`, `prestigePreview` (sin cambios).
- Produces: nada nuevo para otras tareas; el HUD conserva TODOS sus identifiers y anclas.

Qué se construye: el `VStack` del HUD deja el scrim degradado y la `GameCard` isla. La fila principal (moneda+ · contador · ascensor) pasa a vivir sobre un panel `PaletteInk` opaco que se extiende hasta el borde físico superior (detrás de la barra de estado), con las dos esquinas de ABAJO redondeadas (24, continuous) y sombra hacia abajo. Las cápsulas de torre y prestigio quedan como están: flotantes, crema, debajo del panel.

- [ ] **Step 1: Restyle del `body` y `mainBar` de `HUDView`**

```swift
var body: some View {
    VStack(spacing: Tokens.s4) {
        mainBar
            .padding(.horizontal, Tokens.s12)
            .padding(.top, 2)
            .padding(.bottom, Tokens.s12)
            .frame(maxWidth: .infinity)
            .background { topPanel }
        towerNavigator
        prestigeIndicator
    }
    .sheet(isPresented: $showFloorMap) { FloorMapView() }
    .tutorialAnchor(.hudBar)
}

/// El panel ink que reemplaza a la isla: opaco, fundido con el borde superior
/// (cubre la barra de estado vía `ignoresSafeArea`), esquinas redondeadas
/// SÓLO abajo y sombra hacia el tablero.
private var topPanel: some View {
    UnevenRoundedRectangle(
        bottomLeadingRadius: 24, bottomTrailingRadius: 24, style: .continuous
    )
    .fill(Color("PaletteInk"))
    .overlay(
        UnevenRoundedRectangle(
            bottomLeadingRadius: 24, bottomTrailingRadius: 24, style: .continuous
        )
        .strokeBorder(Color("PaletteCream").opacity(0.18), lineWidth: 2)
        .padding(.top, -4)   // el contorno de arriba muere fuera de pantalla
    )
    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    .ignoresSafeArea(edges: .top)
}
```

Notas obligatorias:
- `mainBar` deja de usar `GameCard`: es el mismo `HStack` (coinsPlusButton · coinsColumn · elevatorButton) directo sobre el panel.
- El texto del contador (`coinsAmount`) pasa de `PaletteInk` a `Color("PaletteCream")`; `incomeRate` a `PaletteCream` con opacity 0.75. La sombra `shadow(color: .black.opacity(0.35), radius: 1, y: 1)` en el monto lo despega del panel.
- `CoinIcon` del contador: 26 → **34**.
- Los dos `IconButton` (`hud.coins.plus`, `hud.map`): `size: 52` → **60** y `glyphScale: 0.62` (Step 2). Sus fondos crema circulares ya contrastan con el panel oscuro; no se tocan sus ids, labels ni anclas.
- El viejo `.padding(.horizontal, 10)/.padding(.top, 8)/.padding(.bottom, 6)` del VStack y el `LinearGradient` scrim se borran (el panel opaco los reemplaza). Las cápsulas `towerNavigator`/`prestigeIndicator` no cambian de estructura; sólo suben apenas de tamaño: chevrons `size: 13→16`, frame `26→30` en `towerArrow`.

- [ ] **Step 2: `IconButton.glyphScale`**

En `GameArtComponents.swift`, `IconButton` gana un parámetro con default que preserva a todos los llamadores existentes:

```swift
struct IconButton: View {
    let artKey: String?
    let fallback: () -> AnyView
    var size: CGFloat = 52
    /// Fracción del plato que ocupa el glifo. El default es el histórico; el
    /// HUD rediseñado pide 0.62 para que el dibujo domine el botón.
    var glyphScale: CGFloat = 0.52
    ...
    // en body: .frame(width: size * glyphScale, height: size * glyphScale)
}
```

- [ ] **Step 3: Build + captura de verificación**

`xcodebuild build` (sin regenerar proyecto: no hay archivos nuevos). Levantar el simulador propio, capturar la pantalla principal y verificar: panel llega al borde físico superior sin banda de color detrás de la barra de estado; el reloj/batería del sistema se leen sobre el panel oscuro; las cápsulas de torre/prestigio flotan debajo; nada del contenido quedó detrás del notch.

- [ ] **Step 4: `BoardScene.topInset` sólo si hace falta**

Con la captura en mano: si la multitud o el arte del piso asoman DETRÁS del panel opaco (antes el scrim era translúcido y no molestaba), subir `topInset` (`BoardScene.swift:125`) con la aritmética documentada en el propio comentario, mismo estilo que `bottomInset`. Si no hay solape, no tocar.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/UI/HUD/HUDView.swift FisuEvolution/UI/Art/GameArtComponents.swift FisuEvolution/Scenes/BoardScene.swift
git commit -m "feat(hud): el panel superior se funde con el borde — ink opaco, sin isla"
```

---

### Task 2: Barra inferior fundida con el borde de abajo, iconos gigantes y label visible

**Files:**
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (`GameTabBar`, `GameTabButton`)
- Modify: `FisuEvolution/UI/HUD/BottomMenuBar.swift` (`iconSide`/`prominentIconSide`)
- Modify: `FisuEvolution/App/RootView.swift` (`bottomBar`: sin paddings laterales/inferior)
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (2 valores retocados, claves existentes)
- Modify: `FisuEvolution/Scenes/BoardScene.swift:139` (`bottomInset`, recálculo documentado)

**Interfaces:**
- Consumes: `GameTabItem` (sin cambios de firma), `GameScreen` (intacto: orden, casos, identifiers).
- Produces: la barra mide más alto — Task 4 coloca el botón nuevo INMEDIATAMENTE encima de su borde; los paddings de `TowerNoticeView`/`AchievementToastView` quedan recalculados acá y Task 4 los vuelve a revisar.

Qué se construye: `GameTabBar` deja la isla redondeada y pasa a panel crema de ancho completo, fundido con el borde inferior (cubre la zona del home indicator), esquinas redondeadas SÓLO arriba y contorno ink de 3 pt cuyo trazo lateral muere fuera de pantalla. Cada tab: plato más grande, icono MUCHO más grande y el nombre visible debajo.

- [ ] **Step 1: Restyle de `GameTabBar`**

```swift
struct GameTabBar: View {
    let items: [GameTabItem]
    let selection: (GameScreen) -> Void

    var body: some View {
        HStack(spacing: Tokens.s4) {
            ForEach(items) { item in
                GameTabButton(item: item) { selection(item.screen) }
            }
        }
        .padding(.horizontal, Tokens.s8)
        .padding(.top, Tokens.s8)
        .frame(maxWidth: .infinity)
        .background { bottomPanel }
    }

    /// Panel crema fundido con el borde inferior: esquinas redondeadas sólo
    /// arriba, contorno ink que sólo se ve en el borde superior (los laterales
    /// mueren fuera de pantalla vía padding negativo) y relleno que se extiende
    /// bajo el home indicator.
    private var bottomPanel: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous
        )
        .fill(Color("PaletteCream"))
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous
            )
            .strokeBorder(Color("PaletteInk"), lineWidth: 3)
            .padding(.horizontal, -3)
            .padding(.bottom, -3)
        )
        .shadow(color: .black.opacity(0.2), radius: 6, y: -2)
        .ignoresSafeArea(edges: .bottom)
    }
}
```

- [ ] **Step 2: `GameTabButton` — plato 54/60, icono 44/50, label debajo**

```swift
private struct GameTabButton: View {
    let item: GameTabItem
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = 0

    /// Platos 54/60 e iconos 44/50: el icono ocupa ~82% del plato, que es lo
    /// que el mockup pide ("los iconos deben ser más grandes aún que la foto").
    /// 2×60 + 4×54 + 5×4 de spacing + 16 de padding = 372 ≤ 375 (SE): la barra
    /// entra en el teléfono más angosto sin comprimir.
    private var side: CGFloat { item.prominent ? 60 : 54 }
    private var iconSide: CGFloat { item.prominent ? 50 : 44 }

    var body: some View {
        Button {
            if !reduceMotion { bounce += 1 }
            action()
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    plate
                    item.icon
                        .frame(width: iconSide, height: iconSide)
                }
                .frame(width: side, height: side)
                .keyframeAnimator(initialValue: 1.0, trigger: bounce) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(0.9, duration: 0.08)
                        SpringKeyframe(1.14, duration: 0.14, spring: .bouncy)
                        SpringKeyframe(1.0, duration: 0.22, spring: .bouncy)
                    }
                }
                Text(LocalizedStringKey(item.labelKey))
                    .font(.system(size: 10, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.identifier)
        .accessibilityLabel(Text(LocalizedStringKey(item.labelKey)))
    }
    // `plate` queda igual (arte 1.45×, fallback rects) — sólo escala con `side`.
}
```

Notas obligatorias:
- El label visible usa la MISMA clave que ya es el label de AX (`item.labelKey`): lo que se ve y lo que VoiceOver dice quedan idénticos por construcción. El `Text` vive DENTRO del label del `Button`, así que no crea parada de AX propia.
- `BottomMenuBar.iconSide/prominentIconSide` (los espejos privados, `BottomMenuBar.swift:70-71`) pasan a 44/50 con el mismo comentario de espejo.
- El ancla `.tutorialAnchor(.hire)`/`.tutorialAnchor(.upgrades)` sigue en el ICONO (el recorte del tutorial crece con el icono: 44+20 = 64 sobre plato de 54 — sigue centrado sobre el plato, verificar en captura que el spotlight no quede ridículo; si desborda feo, el ancla se mueve al `ZStack` del plato, que no tiene identifier y no rompe la trampa 9a-bis).

- [ ] **Step 3: Copy de dos labels (catálogo, a mano)**

En `Localizable.xcstrings`, retocar SÓLO valores (las claves y el resto de idiomas quedan):
- `hud.skins.label`: es `Personalización` → `Vestimenta` (la palabra del dueño para ese tab); en `Customization` → `Outfits`.
- `hud.settings.label`: es `Ajustes` → `Menú`; en `Settings` → `Menu` (el tab abre el hub Menú, no Ajustes directo).

Verificar con grep que ningún test asserte los textos viejos (`Personalización`/`Ajustes` como LABEL de tab; los ids no cambian).

- [ ] **Step 4: `RootView.bottomBar` sin isla**

```swift
private var bottomBar: some View {
    VStack(spacing: Tokens.s8) {
        prestigeButton
            .padding(.horizontal, Tokens.s8)
        BottomMenuBar(select: open)
    }
    .tutorialAnchor(.bottomBar)
}
```

(El `.padding(.horizontal/.bottom, Tokens.s8)` del VStack se borra: la barra toca los tres bordes. El botón de prestigio conserva su aire propio.)

- [ ] **Step 5: `BoardScene.bottomInset` recalculado y documentado**

La aritmética del comentario existente (`BoardScene.swift:128-139`) se rehace con las medidas nuevas: safe area (34) + padding top de la barra (8) + columna del tab destacado (60 de plato + 2 + ~12 de label) ≈ **116**, y se ajusta contra la captura como hizo la versión anterior ("el borde ink arranca a N pt del borde inferior"). `CrowdBandTests`/`CrowdDepthTests` asertan contra el knob, no contra el número: no hay tests que tocar, pero correr `FisuEvolutionTests` para confirmarlo.

- [ ] **Step 6: Paddings de los toasts**

`TowerNoticeView` (`RootView.swift`, `.padding(.bottom, 132)`) y `AchievementToastView` (`.padding(.bottom, 196)`): recalcular contra la barra nueva para que el aviso flote ENCIMA del borde ink con el mismo aire visual que hoy (medir en captura; Task 4 los vuelve a subir si el botón nuevo los pisa). El botón DEBUG (`debugButton`, `.padding(.top, 68)`) se re-mide contra el panel de Task 1.

- [ ] **Step 7: Build + suites + captura**

`xcodebuild build`, correr `FisuEvolutionTests` (unit) y `BottomMenuUITests` en el simulador propio. Captura de verificación: barra tocando los tres bordes, 6 labels legibles (¡"Vestimenta" entra en una línea!), iconos protagonistas, home indicator sobre crema.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/UI/Art/GameArtComponents.swift FisuEvolution/UI/HUD/BottomMenuBar.swift FisuEvolution/App/RootView.swift FisuEvolution/Resources/Localizable.xcstrings FisuEvolution/Scenes/BoardScene.swift
git commit -m "feat(barra): la barra inferior se funde con el borde — iconos gigantes con nombre"
```

---

### Task 3: `bestHire` — el mejor contratable que la plata alcanza (TDD)

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Hiring.swift` (struct `BestHire`, computación, `hireBestCharacter()`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (propiedad publicada `bestHire` + refresh en `refreshProjections`)
- Test: `FisuEvolutionTests/BestHireTests.swift` (archivo NUEVO → `xcodegen generate`)

**Interfaces:**
- Consumes: `jobState(for:ordinal:player:content:)` (private del MISMO archivo `GameState+Hiring.swift` — por eso la computación vive ahí), `currentQuote(player:typeId:)`, `hireCharacter(typeId:)`, `CoinFormatter`.
- Produces (Task 4 los consume tal cual):
  - `struct BestHire: Equatable { let typeId: String; let displayName: String; let faceKey: String; let costText: String; let affordable: Bool; let tier: Int }`
  - `GameState.bestHire: BestHire?` (proyección publicada, 8 Hz write-only-on-change)
  - `GameState.hireBestCharacter()` (contrata el `bestHire` vigente; no-op si es `nil`)

Regla de selección (la spec del botón): entre los tipos concretos cuyo `jobState == .hirable` (piso abierto, gate abierto, lugar libre — `unseen` NUNCA califica, no espoilear RF-03):
1. Si alguno es pagable (`coins >= cost`): el de **tier más alto**; empate por tier (ramas de carrera) → el más barato; empate exacto → id ascendente (orden estable).
2. Si ninguno es pagable: el más **barato** de los hirable (empate → id ascendente), con `affordable: false` — el botón muestra la meta de ahorro y tiembla al tocarlo.
3. Sin ningún hirable (todo lleno/cerrado): `nil` — el botón no se dibuja.

- [ ] **Step 1: Tests que pinean la selección (escribir primero, verlos fallar)**

Archivo nuevo `FisuEvolutionTests/BestHireTests.swift`, patrón `GameLoopWiringTests`: `GameState` real con el `economy.json` bundleado, `@MainActor`, y los helpers de `GameState+Debug` para armar el escenario.

```swift
import XCTest
@testable import FisuEvolution

/// Pinea la regla de selección del botón "contratar al mejor" contra la
/// config REAL bundleada: tier más alto pagable entre los `hirable`; sin
/// plata, el más barato como meta; sin hirable, nil.
@MainActor
final class BestHireTests: XCTestCase {
    private func makeReadyState() async throws -> GameState { /* mismo boot que GameLoopWiringTests */ }

    func testFreshRunOffersBaseTypeEvenWithFortune() async throws {
        // Run fresca: sólo el piso 0 abierto ⇒ aunque la plata sobre, el mejor
        // hirable ES el tier base (la compuerta por piso manda, no el saldo).
        let state = try await makeReadyState()
        state.debugGrantCoins()
        state.refreshProjections()
        let best = try XCTUnwrap(state.bestHire)
        XCTAssertTrue(best.affordable)
        XCTAssertEqual(best.tier, /* firstTier del piso 0 según floorTable */ 1)
    }

    func testBrokePlayerSeesCheapestGoal() async throws {
        // Sin plata: la oferta es el hirable más barato, con affordable=false.
        let state = try await makeReadyState()  // coins iniciales ~0
        state.refreshProjections()
        let best = try XCTUnwrap(state.bestHire)
        XCTAssertFalse(best.affordable)
    }

    func testUnlockedFloorsRaiseTheOffer() async throws {
        // Pisos abiertos + tipos vistos + plata ⇒ la oferta salta al tier más
        // alto cuyo piso tiene el gate abierto (no al más alto absoluto).
        let state = try await makeReadyState()
        state.debugUnlockFloors(throughTier: 8)
        state.debugMarkTypesSeen(throughTier: 8)
        state.debugGrantCoins()   // repetir hasta cubrir el más caro si hace falta
        state.refreshProjections()
        let best = try XCTUnwrap(state.bestHire)
        XCTAssertTrue(best.affordable)
        // El tier exacto sale de la regla del gate (canHire) sobre la config
        // real: pinearlo con el número que devuelva la PRIMERA corrida VERDE
        // tras verificar a mano contra floorTable que es el correcto.
        XCTAssertGreaterThan(best.tier, 1)
    }

    func testUnseenNeverOffered() async throws {
        // Piso abierto pero tipo jamás visto ⇒ no es oferta (RF-03).
        // debugUnlockFloors SIN debugMarkTypesSeen: el mejor sigue siendo un
        // tipo ya visto.
        let state = try await makeReadyState()
        state.debugUnlockFloors(throughTier: 8)
        state.debugGrantCoins()
        state.refreshProjections()
        let best = try XCTUnwrap(state.bestHire)
        XCTAssertTrue(state.player!.run.seenTypes.contains(best.typeId))
    }

    func testHireBestActuallyHires() async throws {
        let state = try await makeReadyState()
        state.debugGrantCoins()
        state.refreshProjections()
        let before = state.player!.run.totalUnits
        state.hireBestCharacter()
        XCTAssertEqual(state.player!.run.totalUnits, before + 1)
    }
}
```

(Los asserts con comentario "pinear con la primera corrida verde" se cierran con el número REAL verificado a mano contra `economy.json`/`floorTable` — no se deja el assert blando.)

- [ ] **Step 2: `xcodegen generate` + correr los tests → FAIL**

Deben fallar por `bestHire`/`hireBestCharacter` inexistentes (error de compilación cuenta como rojo de TDD acá).

- [ ] **Step 3: Implementación en `GameState+Hiring.swift`**

```swift
/// La oferta del botón "contratar al mejor" (pantalla principal): el tipo de
/// tier más alto que la plata alcanza ENTRE los que FisuJobs ofrece como
/// contratables. Sin nada pagable, el más barato como meta de ahorro.
struct BestHire: Equatable {
    let typeId: String
    let displayName: String
    let faceKey: String
    let costText: String
    let affordable: Bool
    let tier: Int
}

extension GameState {
    /// Calcula la oferta. La llama SOLO `refreshProjections` (8 Hz): la vista
    /// lee la proyección publicada `bestHire`, nunca esto.
    func computeBestHire() -> BestHire? {
        guard let content, let player else { return nil }
        let coins = player.run.coins

        struct Candidate { let type: CharacterType; let cost: Double }
        let candidates: [Candidate] = content.tiers.concreteTypes.compactMap { type in
            guard let quote = currentQuote(player: player, typeId: type.id),
                  jobState(for: type, ordinal: quote.floorOrdinal, player: player, content: content) == .hirable
            else { return nil }
            return Candidate(type: type, cost: quote.cost)
        }
        guard !candidates.isEmpty else { return nil }

        let affordable = candidates.filter { coins >= $0.cost }
        let pick: Candidate
        if let best = affordable.max(by: { lhs, rhs in
            if lhs.type.tier != rhs.type.tier { return lhs.type.tier < rhs.type.tier }
            if lhs.cost != rhs.cost { return lhs.cost > rhs.cost }   // empate de tier: gana el más barato
            return lhs.type.id > rhs.type.id                          // orden estable
        }) {
            pick = best
        } else {
            pick = candidates.min(by: { lhs, rhs in
                if lhs.cost != rhs.cost { return lhs.cost < rhs.cost }
                return lhs.type.id < rhs.type.id
            })!
        }
        return BestHire(
            typeId: pick.type.id,
            displayName: pick.type.displayName,
            faceKey: "\(pick.type.id)_face",
            costText: CoinFormatter.string(from: pick.cost),
            affordable: coins >= pick.cost,
            tier: pick.type.tier
        )
    }

    /// Contrata la oferta vigente. Reusa `hireCharacter` entero: FTUE,
    /// hápticos, logros, aviso de piso lleno — un solo camino de compra.
    func hireBestCharacter() {
        guard let best = bestHire else { return }
        hireCharacter(typeId: best.typeId)
    }
}
```

⚠️ Cuidado con los comparadores: `max(by:)` con desempates invertidos es fácil de escribir al revés. Los tests de empate de Step 1 son los que lo pinean; si la config real no tiene empates alcanzables, agregar un assert de comparador puro (instanciar dos `Candidate` a mano no se puede desde el test — en ese caso documentar en el propio comparador POR QUÉ el orden de los `return` es ese).

En `GameState.swift`: propiedad `var bestHire: BestHire?` junto a las otras proyecciones, y en `refreshProjections()`:

```swift
let newBestHire = computeBestHire()
if bestHire != newBestHire { bestHire = newBestHire }
```

- [ ] **Step 4: Correr `BestHireTests` → PASS; correr `FisuEvolutionTests` entero → verde**

43 cotizaciones a 8 Hz es aritmética pura (lookups + pow); si `GameLoopWiringTests` o los tests de performance existentes se resienten, mover el recálculo a un contador (cada 2do refresh) — pero medir primero, no optimizar por las dudas.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Hiring.swift FisuEvolution/Game/State/GameState.swift FisuEvolutionTests/BestHireTests.swift project.yml
git commit -m "feat(hire): bestHire — el mejor contratable que la plata alcanza, pineado por tests"
```

(Si `project.yml` no cambió —los tests entran por glob—, commitear sin él; `xcodegen generate` corre igual por el archivo nuevo.)

---

### Task 4: `QuickHireButton` en la pantalla principal

**Files:**
- Create: `FisuEvolution/UI/HUD/QuickHireButton.swift` (→ `xcodegen generate`)
- Modify: `FisuEvolution/App/RootView.swift` (colocación en `bottomBar` + re-chequeo de paddings de toasts)
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (1 clave nueva es+en, mismo commit)
- Test: `FisuEvolutionUITests/BottomMenuUITests.swift` (un smoke test nuevo)

**Interfaces:**
- Consumes: `GameState.bestHire: BestHire?`, `GameState.hireBestCharacter()` (Task 3), `GameIcon`, `CoinIcon`, `Tokens`, patrón de temblor de `PricePill`.
- Produces: control `hud.quickhire` (identifier NUEVO — no pisa ninguno pineado).

Qué se construye: cápsula prominente centrada justo encima de la barra inferior: la cara del personaje ofrecido + su nombre + el precio. Verde cuando alcanza, crema desaturada cuando no (nunca `.disabled`; tiembla al tocar sin saldo). Se dibuja sólo con `bestHire != nil`.

- [ ] **Step 1: La vista**

```swift
import SwiftUI

/// El atajo de contratación de la pantalla principal: compra al personaje del
/// TIER MÁS ALTO que la plata alcanza (proyección `bestHire`), sin abrir
/// FisuJobs. Mismo contrato visual que `PricePill`: nunca `.disabled`, verde
/// cuando alcanza, temblor cuando no.
///
/// La cara viene del atlas por `faceKey` (las 43 existen — auditoría RF-05);
/// no lleva fallback vectorial porque `UIArt` ya cae a su placeholder.
struct QuickHireButton: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake = 0

    var body: some View {
        if let best = gameState.bestHire {
            button(for: best)
        }
    }

    private func button(for best: BestHire) -> some View {
        Button {
            if !best.affordable, !reduceMotion { shake += 1 }
            gameState.hireBestCharacter()
        } label: {
            HStack(spacing: Tokens.s8) {
                GameIcon(artKey: best.faceKey, size: 40) { EmptyView() }
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: best.displayName)
                        .font(Tokens.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 5) {
                        CoinIcon(size: 20)
                        Text(verbatim: best.costText)
                            .font(Tokens.body)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
            .foregroundStyle(best.affordable ? .white : Color("PaletteInk"))
            .shadow(color: .black.opacity(best.affordable ? 0.45 : 0), radius: 1, y: 1)
            .padding(.horizontal, Tokens.s16)
            .padding(.vertical, Tokens.s8)
            .frame(minWidth: 170)
            .background(
                Capsule()
                    .fill(best.affordable ? Color("PaletteGreen") : Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
            )
            .saturation(best.affordable ? 1 : 0.7)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hud.quickhire")
        .accessibilityLabel(spokenLabel(for: best))
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

    /// "Contratar a {nombre}, {monto} monedas": propósito + monto CON su
    /// moneda, mismo reparto que arma `PricePill` (el glifo de la moneda es un
    /// dibujo y VoiceOver no lo ve).
    private func spokenLabel(for best: BestHire) -> Text {
        Text(verbatim: String(localized: "quickhire.ax.purpose \(best.displayName)"))
            + Text(verbatim: ", \(String(localized: "price.ax.coins \(best.costText)"))")
    }
}
```

Clave nueva en el catálogo (a mano, mismo commit): `quickhire.ax.purpose %@` — es: `Contratar a %@` / en: `Hire %@`. (`price.ax.coins %@` ya existe — verificar el nombre exacto de la clave en el catálogo antes de usarla y ajustar si difiere.)

- [ ] **Step 2: Colocación en `RootView.bottomBar` + toasts**

```swift
private var bottomBar: some View {
    VStack(spacing: Tokens.s8) {
        prestigeButton
            .padding(.horizontal, Tokens.s8)
        QuickHireButton()
        BottomMenuBar(select: open)
    }
    .tutorialAnchor(.bottomBar)
}
```

- La aparición/desaparición (bestHire pasa a `nil` y vuelve) debe ser suave: envolver en el mismo patrón `ZStack + .animation(value:)` que usan los toasts de `RootView` SI la aparición de golpe se nota en la captura; con Reduce Motion, sin animación.
- Re-chequear `TowerNoticeView`/`AchievementToastView`: ahora flotan sobre botón + barra; subir sus `.padding(.bottom, …)` para que no pisen la cápsula nueva (medir en captura).
- Durante el tutorial el scrim cubre la franja inferior salvo los agujeros de cada paso; verificar en el simulador (tutorial fresco) que ningún paso deja al botón nuevo tocable dentro de una ventana que no le corresponde — si lo deja, no es bloqueante: `hireCharacter` marca `ftue.spawned` igual y el paso "hire" se completa por `.hired`, pero anotarlo en el reporte.

- [ ] **Step 3: Smoke test de UI**

En `BottomMenuUITests` (usa su mismo bootstrapping de launch args/estado):

```swift
func testQuickHireButtonExistsAndSurvivesBrokeTap() {
    // Arranque fresco: sin plata, la oferta es la meta de ahorro — el botón
    // existe igual (nunca .disabled) y tocarlo sin saldo no compra ni rompe.
    let quickHire = app.buttons["hud.quickhire"]
    XCTAssertTrue(quickHire.waitForExistence(timeout: 10))
    let unitsBefore = app.otherElements["board.units"].value as? String
    quickHire.tap()
    XCTAssertEqual(app.otherElements["board.units"].value as? String, unitsBefore)
}
```

(Si el arranque del suite regala monedas y el tap SÍ compra, invertir el assert a `units + 1` — el test pinea el comportamiento REAL del estado de arranque del suite, documentado en su comentario.)

- [ ] **Step 4: `xcodegen generate`, build, unit + `BottomMenuUITests` en el simulador propio → verde**

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/UI/HUD/QuickHireButton.swift FisuEvolution/App/RootView.swift FisuEvolution/Resources/Localizable.xcstrings FisuEvolutionUITests/BottomMenuUITests.swift project.yml
git commit -m "feat(hire): botón de contratar al mejor tier pagable en la pantalla principal"
```

---

### Task 5: Verificación integral + captura + documentación de cierre

**Files:**
- Modify: `Docs/HANDOFF.md` (banner: línea del rediseño de pantalla principal)
- Create: `Docs/SESION-2026-08-16-rediseno-pantalla-principal.md`

**Interfaces:**
- Consumes: todo lo anterior mergeado en la rama.
- Produces: la rama lista para el review final de SDD y el merge.

- [ ] **Step 1: Suite completa en simulador propio** — `xcodegen generate`; EconomyKit (`swift test` en el paquete); `FisuEvolutionTests` (unit ANTES que UI); suite de UI COMPLETA en UNA corrida sin skips; borrar el simulador al terminar. Cero warnings.

- [ ] **Step 2: Capturas finales** — pantalla principal completa (panel arriba, botón nuevo, barra abajo) en estado pobre (botón crema) y en estado pagable (botón verde, vía debug panel o jugando). Guardarlas para el mensaje de cierre al dueño.

- [ ] **Step 3: Chequeo visual contra el pedido** — barra superior SIN isla (fundida al borde), barra inferior SIN isla, iconos que se entienden de un vistazo a un brazo de distancia, botón nuevo presente y honesto (tier y precio del mejor pagable real).

- [ ] **Step 4: Docs** — doc de sesión (tabla de tareas, decisiones, números de tests) + banner del HANDOFF actualizado. Commit de docs en español.

---

## Self-review (hecho al escribir)

1. **Cobertura del pedido**: barra superior fundida → Task 1; barra inferior fundida + iconos mucho más grandes → Task 2; botón del mejor tier pagable → Tasks 3+4; "menú no cambia" → constraint global (ids/orden/destinos intactos); "estilo de la imagen con nuestros assets" → sección Referencia visual.
2. **Placeholders**: ninguno — todos los pasos llevan código o comando concreto; los dos asserts que dependen de la config real llevan la instrucción exacta de cómo cerrarlos (número verificado a mano, no assert blando).
3. **Consistencia de tipos**: `BestHire` (Task 3) es exactamente lo que consume `QuickHireButton` (Task 4: `typeId/displayName/faceKey/costText/affordable/tier`); `hireBestCharacter()` idem; `glyphScale` sólo lo usa Task 1.
