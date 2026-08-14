import Foundation
import SwiftUI
import Testing
@testable import FisuEvolution

/// Lo testeable del design system v2. Las vistas no se pueden assertar sin
/// renderizarlas, pero sí su **contrato**: el orden de las pantallas (que ES el
/// orden de los tabs), los identifiers que los tests de UI tienen pineados, y
/// los cálculos que las vistas hacen sobre datos de afuera —el clamp de la barra
/// de progreso y el texto formateado del pill—, que es donde un `NaN` o un monto
/// de 10³⁰⁰ hacen daño de verdad.
@Suite("Design system v2")
@MainActor
struct GameArtComponentsTests {

    // MARK: - GameScreen

    @Test("las 6 pantallas vienen en el orden de la barra inferior")
    func screenOrderIsTheTabOrder() {
        #expect(GameScreen.allCases.map(\.rawValue) == ["jobs", "upgrades", "skins", "gifts", "store", "menu"])
    }

    @Test("el id es el rawValue: lo consume .sheet(item:)")
    func identifiableUsesRawValue() {
        for screen in GameScreen.allCases {
            #expect(screen.id == screen.rawValue)
            #expect(GameScreen(rawValue: screen.rawValue) == screen)
        }
    }

    @Test("los identifiers de los tabs son únicos y conservan los pineados")
    func tabIdentifiersAreUniqueAndPinned() {
        let identifiers = GameScreen.allCases.map(\.identifier)
        #expect(Set(identifiers).count == GameScreen.allCases.count)
        // Estos tres los usan tests de UI que ya existen: cambiarlos los rompe.
        #expect(GameScreen.upgrades.identifier == "hud.upgrades")
        #expect(GameScreen.gifts.identifier == "hud.bonus")
        #expect(GameScreen.store.identifier == "hud.store")
        // Los nuevos, según spec §4.
        #expect(GameScreen.jobs.identifier == "hud.hire")
        #expect(GameScreen.skins.identifier == "hud.skins")
        #expect(GameScreen.menu.identifier == "hud.settings")
    }

    // MARK: - GameTabItem

    @Test("una barra con las 6 pantallas no repite ni ids ni identifiers")
    func tabItemsAreDistinct() {
        let items = GameScreen.allCases.map { screen in
            GameTabItem(
                screen: screen,
                icon: AnyView(EmptyView()),
                labelKey: "hud.\(screen.rawValue).label",
                identifier: screen.identifier,
                prominent: screen == .jobs || screen == .menu
            )
        }
        #expect(items.count == 6)
        #expect(Set(items.map(\.id)).count == 6)
        #expect(Set(items.map(\.identifier)).count == 6)
        // Los extremos van destacados (56 pt contra 48 pt).
        #expect(items.filter(\.prominent).map(\.screen) == [.jobs, .menu])
    }

    @Test("el tab no es prominente si no se lo pide")
    func prominentDefaultsToFalse() {
        let item = GameTabItem(
            screen: .store,
            icon: AnyView(EmptyView()),
            labelKey: "hud.store.label",
            identifier: GameScreen.store.identifier
        )
        #expect(item.prominent == false)
    }

    // MARK: - PricePill

    @Test("el precio sobrevive a los montos astronómicos del idle")
    func priceSurvivesAstronomicalAmounts() {
        // El juego llega a 10¹⁶ de tapYield y los costos suben desde ahí: el
        // pill recibe SIEMPRE texto ya abreviado por CoinFormatter.
        let values: [Double] = [0, 50, 999, 1_000, 1e6, 1e15, 1e30, 1e100, 1e300,
                                .greatestFiniteMagnitude]
        for value in values {
            let text = CoinFormatter.string(from: value)
            let pill = PricePill(text: text, currency: .coins, affordable: false,
                                 identifier: "jobs.hire.test", action: {})
            #expect(pill.text == text)
            #expect(!pill.text.isEmpty)
            // El texto abreviado queda corto SIEMPRE: 4 dígitos + sufijo. El
            // tope es 8 y no 6 porque en el salto exacto de sufijo el redondeo
            // puede dar "1.000dq" (mil con separador de miles) en vez de "1dr" —
            // pasa recién a partir de 10³⁰⁰, muy arriba del techo del juego
            // (~10¹⁶), y el pill igual lo encoge con minimumScaleFactor.
            #expect(pill.text.count <= 8)
        }
    }

    @Test("un monto no finito no llega roto al pill")
    func priceHandlesNonFiniteAmounts() {
        for value in [Double.infinity, .nan, -1] {
            let pill = PricePill(text: CoinFormatter.string(from: value), currency: .oro,
                                 affordable: true, identifier: "store.buy.test", action: {})
            #expect(pill.text == "∞")
        }
    }

    // MARK: - ProgressBar

    @Test("el progreso se clampea a 0…1 y sobrevive a NaN")
    func progressIsClamped() {
        #expect(ProgressBar(progress: 0.5, tint: .green).clampedProgress == 0.5)
        #expect(ProgressBar(progress: 0, tint: .green).clampedProgress == 0)
        #expect(ProgressBar(progress: 1, tint: .green).clampedProgress == 1)
        // 0/0 (un logro con objetivo 0) y contadores pasados de rosca.
        #expect(ProgressBar(progress: .nan, tint: .green).clampedProgress == 0)
        #expect(ProgressBar(progress: .infinity, tint: .green).clampedProgress == 0)
        #expect(ProgressBar(progress: 4.2, tint: .green).clampedProgress == 1)
        #expect(ProgressBar(progress: -3, tint: .green).clampedProgress == 0)
    }

    @Test("la barra acepta una etiqueta opcional sin cambiar el cálculo")
    func progressLabelIsIndependent() {
        let bar = ProgressBar(progress: 0.25, tint: .blue, labelText: "3/12")
        #expect(bar.labelText == "3/12")
        #expect(bar.clampedProgress == 0.25)
    }

    // MARK: - CountBadge

    @Test("el badge dice ×N con el signo de multiplicación")
    func badgeText() {
        #expect(CountBadge(count: 0, dimmed: true).text == "×0")
        #expect(CountBadge(count: 7, dimmed: false).text == "×7")
        #expect(CountBadge(count: 1_234, dimmed: false).text == "×1234")
    }

    // MARK: - Tokens

    @Test("la escala de espaciado es 4/8/12/16/24")
    func spacingScale() {
        #expect([Tokens.s4, Tokens.s8, Tokens.s12, Tokens.s16, Tokens.s24] == [4, 8, 12, 16, 24])
    }

    // MARK: - Iconos

    @Test("los tres trofeos son el mismo icono en tres metales distintos")
    func trophyTiers() {
        #expect(VectorTrophyIcon.Tier.allCases.map(\.rawValue) == ["bronze", "silver", "gold"])
        let metals = VectorTrophyIcon.Tier.allCases.map(\.metal)
        #expect(Set(metals.map(\.description)).count == 3)
    }
}
