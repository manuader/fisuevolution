import Foundation
import Testing
@testable import EconomyKit

@Suite("Offline: los modificadores se integran sobre la ausencia")
struct OfflineModifierTests {
    let config = fxConfig()
    let economy = fxEconomy()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    /// Dos `a` con pasivo: 0,6/s de base, eficiencia 1 para que las cuentas sean limpias.
    private func producing(_ modifiers: [ActiveModifier]) throws -> PlayerState {
        var state = fxState(units: ["a": 2])
        state.run.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        state.run.activeModifiers = modifiers
        state.meta.lastSeenTimestamp = 1000
        state.meta.derivedEffects.offlineEfficiency = 1
        return state
    }

    private func income(_ magnitude: Double, until expiresAt: TimeInterval) -> ActiveModifier {
        ActiveModifier(effect: .incomeMultiplier, magnitude: magnitude, expiresAt: expiresAt, sourceKey: "test")
    }

    private func earned(_ state: PlayerState, now: TimeInterval) -> Double {
        OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: config, now: now)
    }

    @Test("un buff que venció mientras no estabas paga su tramo")
    func expiredBuffPaysItsShare() throws {
        let state = try producing([income(3, until: 1000 + 600)])
        #expect(abs(earned(state, now: 1000 + 3600) - 0.6 * (600 * 3 + 3000)) < 1e-6)
    }

    @Test("un debuff vivo al volver no cuenta afuera")
    func debuffsAreIgnored() throws {
        let state = try producing([income(0.5, until: 1000 + 7200)])
        #expect(abs(earned(state, now: 1000 + 3600) - 0.6 * 3600) < 1e-6)
    }

    @Test("dos buffs se multiplican mientras viven los dos")
    func stackedBuffs() throws {
        let state = try producing([income(2, until: 1100), income(3, until: 1300)])
        #expect(abs(earned(state, now: 2000) - 0.6 * (100 * 6 + 200 * 3 + 700)) < 1e-6)
    }

    @Test("la ventana es la del tope y arranca cuando te fuiste")
    func windowIsCapped() throws {
        let state = try producing([income(2, until: 1000 + 9 * 3600)])
        #expect(abs(earned(state, now: 1000 + 20 * 3600) - 0.6 * 8 * 3600 * 2) < 1e-6)
    }

    @Test("sin modificadores el factor es 1")
    func neutralFactor() {
        #expect(ModifierMath.offlineFactor([], effect: .incomeMultiplier, from: 0, to: 100) == 1)
    }
}
