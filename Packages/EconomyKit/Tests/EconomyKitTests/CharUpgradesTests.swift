import Foundation
import Testing
@testable import EconomyKit

// MARK: - Mejoras por personaje: efecto SECUENCIAL y su tope
//
// ⚠️ **El efecto cambió el 2026-08-22 (segunda ronda de balance).** Era
// `effectFactorPerLevel ^ nivel` —×2, ×4, ×8 … ×1.048.576 al nivel 20— y ahora
// es `1 + nivel × effectStepPerLevel`: ×2, ×3, ×4 … ×20. Pedido textual del
// dueño: *"en lugar de multiplicar x2 (hasta llegar a 2^20) cada vez, hace que
// sea secuencial (ej: x2 -> x3 -> x4 -> x5 -> ... -> x20)"*.
//
// El tope pasó de 20 niveles a **19**, que es lo que clava el ×20 que él
// escribió (`1 + 19 × 1 = 20`). Con 20 niveles el tope habría sido ×21, un
// número que nadie pidió. Y el tope ya no existe para frenar un overflow —una
// recta no desborda—: existe para ser exactamente ese ×20.
//
// Las TRES puertas del tope siguen igual —el multiplicador clampea, la
// cotización devuelve `nil` y la compra rechaza— para que ningún camino lo
// esquive.

@Suite("Tope de mejoras por personaje")
struct CharUpgradesTests {
    let config = fxConfig()
    let economy = fxEconomy()
    let type = fxType("a", tier: 1)

    private func levels(_ level: Int) -> [String: Int] { ["a": level] }

    @Test("el config de producción publica el tope en 19, que es el ×20 del dueño")
    func productionCapIsNineteen() {
        // Pineado literal: 19 niveles es lo que hace que el tope sea ×20, el
        // número que el dueño escribió. Un cambio acá tiene que ser una decisión
        // nueva, no un accidente.
        #expect(EconomyConfig.CharUpgradesConfig(
            baseCostMultiplier: 50, costGrowth: 4.0, effectStepPerLevel: 1.0
        ).maxLevel == 19)
    }

    /// La secuencia del pedido, escrita a mano nivel por nivel y no calculada
    /// con la fórmula que está bajo test —eso sería tautológico—.
    @Test("el multiplicador es secuencial: ×1 sin comprar, después ×2, ×3, ×4 … ×20")
    func theMultiplierIsSequential() {
        let esperado: [Int: Double] = [
            0: 1, 1: 2, 2: 3, 3: 4, 4: 5, 5: 6,
            10: 11, 18: 19, 19: 20,
        ]
        for (nivel, multiplicador) in esperado.sorted(by: { $0.key < $1.key }) {
            #expect(
                CharUpgrades.multiplier(typeId: "a", levels: levels(nivel), config: config) == multiplicador,
                "nivel \(nivel)"
            )
        }
    }

    /// Lo que la recta cambia y la potencia no: cada nivel suma SIEMPRE lo
    /// mismo en términos absolutos, así que en términos relativos vale cada vez
    /// menos. El bot del simulador decide con este número, y con el `×2 − 1` que
    /// usaba antes creería que el nivel 19 rinde tanto como el 1.
    @Test("la ganancia del próximo nivel se achica a medida que se sube")
    func theNextLevelGainShrinks() {
        // Del nivel 0 al 1 el income del tipo se DUPLICA (×1 → ×2): +100 %.
        #expect(CharUpgrades.nextLevelGainFactor(typeId: "a", levels: levels(0), config: config) == 1.0)
        // Del 1 al 2, ×2 → ×3: +50 %.
        #expect(CharUpgrades.nextLevelGainFactor(typeId: "a", levels: levels(1), config: config) == 0.5)
        // Del 18 al 19, ×19 → ×20: +5,26 %.
        #expect(abs(CharUpgrades.nextLevelGainFactor(typeId: "a", levels: levels(18), config: config) - 1.0 / 19.0) < 1e-12)
        // En el tope no hay nivel que comprar y la ganancia es cero, no un
        // número que invite a una compra que la cotización ya rechaza.
        #expect(CharUpgrades.nextLevelGainFactor(typeId: "a", levels: levels(19), config: config) == 0)
        #expect(CharUpgrades.nextLevelGainFactor(typeId: "a", levels: levels(99), config: config) == 0)
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
        // El tope de la fixture es el de producción: 19 niveles = ×20.
        #expect(atCap == 20)
        #expect(beyond == atCap)
    }
}
