import Foundation
import Testing
@testable import EconomyKit

@Suite("La herencia de pasivos al reencarnar")
struct PassiveInheritanceTests {
    private func reincarnate(_ state: inout PlayerState, inherits: Bool) throws {
        let config = try fxConfig().tuned(EconomyKnobs(inheritsPassiveUnlocks: inherits))
        let economy = StandardEconomy(config: config)
        state.meta.lifetimeEarnings = 1e30
        PrestigeCalculator.applyReincarnation(
            state: &state, economy: economy, tiers: try fxTiers(), floorTable: try fxFloorTable(), now: 0
        )
    }

    @Test("apagada, la run nueva arranca sin pasivos: la v1")
    func offIsV1() throws {
        var state = fxState()
        state.run.passiveUnlocked = ["a": true, "b": true]
        try reincarnate(&state, inherits: false)
        #expect(state.run.passiveUnlocked.values.allSatisfy { !$0 })
    }

    @Test("prendida, la run nueva conserva los pasivos y nada más de la run")
    func onKeepsOnlyPassives() throws {
        var state = fxState()
        state.run.passiveUnlocked = ["a": true, "b": true, "d": false]
        state.run.units = ["a": 3, "b": 2]
        state.run.charUpgradeLevels = ["a": 4]
        try reincarnate(&state, inherits: true)
        #expect(state.run.passiveUnlocked.filter(\.value).keys.sorted() == ["a", "b"])
        #expect(state.run.charUpgradeLevels.isEmpty)
        #expect(state.run.units["b"] == nil)
    }

    @Test("se acumulan: un pasivo de la run 1 sigue en la 3 aunque la 2 nunca llegó a ese tipo")
    func theyAccumulate() throws {
        var state = fxState()
        state.run.passiveUnlocked = ["d": true]
        try reincarnate(&state, inherits: true)
        state.run.passiveUnlocked["a"] = true
        try reincarnate(&state, inherits: true)
        #expect(state.run.passiveUnlocked["d"] == true)
        #expect(state.run.passiveUnlocked["a"] == true)
    }

    @Test("lo que muestra la pantalla es lo que aplica la reencarnación")
    func previewIsWhatApplies() throws {
        var state = fxState()
        state.run.passiveUnlocked = ["a": true, "c_prog": true, "b": false]
        let economy = StandardEconomy(config: try fxConfig().tuned(EconomyKnobs(inheritsPassiveUnlocks: true)))
        let preview = PrestigeCalculator.inheritedPassiveUnlocks(state: state, economy: economy)
        try reincarnate(&state, inherits: true)
        #expect(state.run.passiveUnlocked.filter(\.value) == preview)
    }
}
