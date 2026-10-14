import Foundation
import Testing
@testable import EconomyKit

/// "Pegarla" + "Toque dorado" = "Toque premiado" (PLAN-v2 E13): los niveles se
/// suman sin tocar el blue, y al tope el efecto es el de las dos al tope.
@Suite("Toque premiado")
struct LuckyTouchTests {
    private let lucky = PermanentUpgradeLine(
        id: "lucky", effect: .luckyTouch, magnitudePerLevel: 0.0125, goldenPerLevel: 0.0025,
        maxLevel: 20, baseCost: 1, costGrowth: 1.09
    )

    @Test("los niveles de las dos viejas se suman en la nueva y las viejas se van")
    func foldSums() {
        let folded = PermanentUpgrades.foldingMergedLines(["income": 4, "crit": 3, "golden": 5])
        #expect(folded == ["income": 4, "lucky": 8])
    }

    @Test("plegar dos veces da lo mismo, y lo comprado después no se pisa")
    func foldIsIdempotent() {
        let once = PermanentUpgrades.foldingMergedLines(["crit": 10, "golden": 10])
        #expect(PermanentUpgrades.foldingMergedLines(once) == once)
        #expect(PermanentUpgrades.foldingMergedLines(["lucky": 12, "crit": 3]) == ["lucky": 12])
    }

    @Test("un save viejo se lee ya plegado")
    func decodingFolds() throws {
        var state = fxState()
        state.meta.blueUpgradeLevels = ["crit": 2, "golden": 1]
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(state))
        #expect(decoded.meta.blueUpgradeLevels == ["lucky": 3])
    }

    @Test("la migración no toca el blue ni el contador de cofres")
    func decodingKeepsTheRestOfMeta() throws {
        var state = fxState()
        state.meta.blue = 37
        state.meta.blueEarnedLifetime = 120
        state.meta.floorChestsAwarded = 2
        state.meta.blueUpgradeLevels = ["crit": 10, "golden": 10, "income": 3]
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(state))
        #expect(decoded.meta.blue == 37)
        #expect(decoded.meta.blueEarnedLifetime == 120)
        #expect(decoded.meta.floorChestsAwarded == 2)
        #expect(decoded.meta.blueUpgradeLevels == ["lucky": 20, "income": 3])
    }

    @Test("al tope, crítico y dorado son los de las dos líneas viejas al tope")
    func maxedMatchesTheOldPair() {
        var state = fxState()
        state.meta.blueUpgradeLevels = ["lucky": 20]
        PermanentUpgrades.recomputeDerivedEffects(state: &state, lines: [lucky], economy: fxEconomy())
        #expect(abs(state.meta.derivedEffects.critChance - (fxConfig().critChanceBase + 0.25)) < 1e-12)
        #expect(abs(state.meta.derivedEffects.goldenChance - 0.05) < 1e-12)
        #expect(PermanentUpgrades.allMaxed(levels: state.meta.blueUpgradeLevels, lines: [lucky]))
    }
}
