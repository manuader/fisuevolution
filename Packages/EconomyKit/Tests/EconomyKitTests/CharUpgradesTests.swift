import Foundation
import Testing
@testable import EconomyKit

// MARK: - Tope de las mejoras por personaje (decisión del dueño, 2026-08-19)
//
// El efecto es `effectFactorPerLevel ^ nivel` y el costo crece `costGrowth ^
// nivel`: sin techo, los dos exponenciales terminan en números que la UI no
// puede formatear y el juego se cae. El tope vive en el config (`maxLevel`,
// 20 en producción: máximo = base × 2^20) y lo aplican las TRES puertas —el
// multiplicador clampea, la cotización devuelve `nil` y la compra rechaza—
// para que ningún camino lo esquive.

@Suite("Tope de mejoras por personaje")
struct CharUpgradesTests {
    let config = fxConfig()
    let economy = fxEconomy()
    let type = fxType("a", tier: 1)

    private func levels(_ level: Int) -> [String: Int] { ["a": level] }

    @Test("el config de producción publica el tope en 20")
    func productionCapIsTwenty() {
        // Pineado literal: es el número de la decisión (base × 2^20 máximo) y
        // un cambio acá tiene que ser una decisión nueva, no un accidente.
        #expect(EconomyConfig.CharUpgradesConfig(
            baseCostMultiplier: 50, costGrowth: 4.0, effectFactorPerLevel: 2.0
        ).maxLevel == 20)
    }

    @Test("bajo el tope hay precio; en el tope, nil")
    func costStopsAtCap() {
        let cap = config.charUpgrades.maxLevel
        #expect(CharUpgrades.nextLevelCost(
            type: type, levels: levels(cap - 1), config: config, economy: economy
        ) != nil)
        #expect(CharUpgrades.nextLevelCost(
            type: type, levels: levels(cap), config: config, economy: economy
        ) == nil)
        #expect(CharUpgrades.isMaxed(typeId: "a", levels: levels(cap), config: config))
    }

    @Test("la compra en el tope rechaza con maxLevelReached y no toca el estado")
    func purchaseRejectsAtCap() throws {
        var state = fxState()
        state.run.coins = .greatestFiniteMagnitude
        state.run.charUpgradeLevels["a"] = config.charUpgrades.maxLevel

        #expect(throws: CharUpgrades.PurchaseError.maxLevelReached) {
            try CharUpgrades.purchase(type: type, state: &state, config: config, economy: economy)
        }
        #expect(state.run.charUpgradeLevels["a"] == config.charUpgrades.maxLevel)
        #expect(state.run.coins == .greatestFiniteMagnitude)
    }

    @Test("comprando desde cero, la vida entera termina exactamente en el tope")
    func fullLifeEndsAtCap() throws {
        var state = fxState()
        state.run.coins = .greatestFiniteMagnitude

        var purchases = 0
        while true {
            do {
                try CharUpgrades.purchase(type: type, state: &state, config: config, economy: economy)
                purchases += 1
            } catch CharUpgrades.PurchaseError.maxLevelReached {
                break
            }
            // Red de seguridad: si el tope no corta, que corte el test.
            try #require(purchases <= config.charUpgrades.maxLevel)
        }
        #expect(purchases == config.charUpgrades.maxLevel)
        #expect(state.run.charUpgradeLevels["a"] == config.charUpgrades.maxLevel)
    }

    @Test("el multiplicador clampea un save que trae niveles por encima del tope")
    func multiplierClampsDoctoredSaves() {
        let cap = config.charUpgrades.maxLevel
        let atCap = CharUpgrades.multiplier(typeId: "a", levels: levels(cap), config: config)
        let beyond = CharUpgrades.multiplier(typeId: "a", levels: levels(cap + 13), config: config)
        #expect(atCap == pow(config.charUpgrades.effectFactorPerLevel, Double(cap)))
        #expect(beyond == atCap)
    }
}
