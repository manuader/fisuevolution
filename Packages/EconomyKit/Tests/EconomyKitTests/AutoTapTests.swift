import Foundation
import Testing
@testable import EconomyKit

@Suite("El auto-tap: toques automáticos al mejor que tenés")
struct AutoTapTests {
    let tiers: TierRepository
    let floorTable: FloorTable
    let economy = fxEconomy()

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    private func autoTap(_ perSecond: Double, until expiresAt: TimeInterval = 100) -> ActiveModifier {
        ActiveModifier(effect: .autoTapPerSecond, magnitude: perSecond, expiresAt: expiresAt, sourceKey: "shop.auto_tap")
    }

    @Test("toca al de tier más alto que tenés")
    func targetsTheBest() {
        #expect(AutoTapper.target(state: fxState(units: ["a": 3, "b": 1]), tiers: tiers)?.id == "b")
        #expect(AutoTapper.target(state: fxState(units: [:]), tiers: tiers) == nil)
    }

    @Test("cobra toques por segundo × segundos × lo que paga un toque al mejor")
    func paysTapsTimesSeconds() throws {
        var state = fxState(units: ["a": 1, "b": 1])
        state.run.activeModifiers = [autoTap(5)]
        var probe = state
        let oneTap = economy.applyTap(type: try #require(tiers.type(id: "b")), state: &probe, tiers: tiers,
                                      floorTable: floorTable, now: 10)
        let coins = state.run.coins
        let earned = state.meta.lifetimeEarnings
        let paid = AutoTapper.advance(state: &state, delta: 2, now: 10, tiers: tiers, floorTable: floorTable, economy: economy)
        #expect(paid > 0)
        #expect(abs(paid - oneTap * 5 * 2) < 1e-9 * max(1, paid))
        #expect(abs(state.run.coins - coins - paid) < 1e-9 * max(1, paid))
        #expect(abs(state.meta.lifetimeEarnings - earned - paid) < 1e-9 * max(1, paid))
        #expect(state.meta.stats.totalTapsEver == 0, "los toques automáticos no son del jugador")
    }

    @Test("dos auto-taps se suman; vencido, no paga")
    func ratesAddAndExpire() {
        let modifiers = [autoTap(5, until: 100), autoTap(3, until: 50)]
        #expect(ModifierMath.autoTapsPerSecond(modifiers, now: 10) == 8)
        #expect(ModifierMath.autoTapsPerSecond(modifiers, now: 60) == 5)
        #expect(ModifierMath.autoTapsPerSecond([], now: 0) == 0)
        var state = fxState(units: ["a": 1])
        state.run.activeModifiers = modifiers
        #expect(AutoTapper.advance(state: &state, delta: 1, now: 200, tiers: tiers, floorTable: floorTable, economy: economy) == 0)
    }

    @Test("no toca el pasivo ni los multiplicadores de ingresos")
    func doesNotTouchIncome() {
        var state = fxState(units: ["a": 2])
        state.run.passiveUnlocked["a"] = true
        let passive = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig(), now: 10)
        state.run.activeModifiers = [autoTap(5)]
        #expect(IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: fxConfig(), now: 10) == passive)
        #expect(ModifierMath.factor(state.run.activeModifiers, effect: .incomeMultiplier, now: 10) == 1)
        #expect(ModifierMath.factor(state.run.activeModifiers, effect: .tapMultiplier, now: 10) == 1)
    }

    @Test("sin nadie en el tablero no paga")
    func nobodyToTap() {
        var state = fxState(units: [:])
        state.run.activeModifiers = [autoTap(5)]
        #expect(AutoTapper.advance(state: &state, delta: 1, now: 10, tiers: tiers, floorTable: floorTable, economy: economy) == 0)
    }

    @Test("el efecto se lee de un save que todavía no lo conocía")
    func decodes() throws {
        let json = #"{"id":"6A1D2F3E-0000-0000-0000-000000000001","effect":"autoTapPerSecond","magnitude":5,"expiresAt":600,"sourceKey":"shop.auto_tap"}"#
        #expect(try JSONDecoder().decode(ActiveModifier.self, from: Data(json.utf8)).effect == .autoTapPerSecond)
    }
}
