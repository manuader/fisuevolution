import Foundation
import Testing
@testable import EconomyKit

@Suite("Efectos de modificador de los eventos v2")
struct EventModifierEffectsTests {
    let tiers: TierRepository
    let floorTable: FloorTable
    let config = fxConfig()

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    private func producing() -> PlayerState {
        var state = fxState(units: ["a": 2])
        state.run.passiveUnlocked["a"] = true
        return state
    }

    private func passive(_ state: PlayerState, now: TimeInterval) -> Double {
        IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config, now: now)
    }

    private func tap(_ state: PlayerState, now: TimeInterval) throws -> Double {
        var copy = state
        return fxEconomy().applyTap(
            type: try #require(tiers.type(id: "a")), state: &copy, tiers: tiers, floorTable: floorTable, now: now
        )
    }

    @Test("el paro frena el pasivo y deja el toque; vencido, vuelve")
    func passiveMultiplierStopsOnlyThePassive() throws {
        var state = producing()
        let before = passive(state, now: 10)
        let tapBefore = try tap(state, now: 10)
        state.run.activeModifiers = [
            ActiveModifier(effect: .passiveMultiplier, magnitude: 0, expiresAt: 40, sourceKey: "event.paro_general"),
        ]
        #expect(before > 0)
        #expect(passive(state, now: 10) == 0)
        #expect(try tap(state, now: 10) == tapBefore, "el paro es del pasivo: tocar sigue pagando")
        #expect(passive(state, now: 40) == before)
    }

    @Test("un pasivo ×3 multiplica el pasivo y no el toque")
    func passiveMultiplierBuffs() throws {
        var state = producing()
        let before = passive(state, now: 10)
        let tapBefore = try tap(state, now: 10)
        state.run.activeModifiers = [ActiveModifier(effect: .passiveMultiplier, magnitude: 3, expiresAt: 40, sourceKey: "x")]
        #expect(abs(passive(state, now: 10) - before * 3) < 1e-9)
        #expect(try tap(state, now: 10) == tapBefore)
    }

    @Test("la inmunidad se nota mientras dura y no toca los ingresos")
    func immunity() throws {
        var state = producing()
        let before = passive(state, now: 10)
        state.run.activeModifiers = [ActiveModifier(effect: .eventImmunity, magnitude: 1, expiresAt: 1800, sourceKey: "career.junior_doctor")]
        #expect(ModifierMath.isImmuneToEvents(state.run.activeModifiers, now: 10))
        #expect(!ModifierMath.isImmuneToEvents(state.run.activeModifiers, now: 1800))
        #expect(!ModifierMath.isImmuneToEvents([], now: 10))
        #expect(passive(state, now: 10) == before)
    }

    @Test("el ritmo de paquetes no toca ni el pasivo ni el toque")
    func packageRateIsOnlyForPackages() throws {
        var state = producing()
        let before = passive(state, now: 10)
        let tapBefore = try tap(state, now: 10)
        state.run.activeModifiers = [ActiveModifier(effect: .packageRateMultiplier, magnitude: 10, expiresAt: 60, sourceKey: "event.lluvia_paquetes")]
        #expect(passive(state, now: 10) == before)
        #expect(try tap(state, now: 10) == tapBefore)
        #expect(ModifierMath.factor(state.run.activeModifiers, effect: .packageRateMultiplier, now: 10) == 10)
    }

    @Test("los efectos nuevos se leen de un save que todavía no los conocía")
    func newEffectsDecode() throws {
        let json = #"{"id":"6A1D2F3E-0000-0000-0000-000000000000","effect":"passiveMultiplier","magnitude":0,"expiresAt":30,"sourceKey":"event.paro_general"}"#
        let modifier = try JSONDecoder().decode(ActiveModifier.self, from: Data(json.utf8))
        #expect(modifier.effect == .passiveMultiplier)
    }
}
