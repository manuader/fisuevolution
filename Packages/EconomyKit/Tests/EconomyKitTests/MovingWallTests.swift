import Foundation
import Testing
@testable import EconomyKit

@Suite("Piso móvil para reencarnar")
struct MovingWallTests {
    /// Con mucho ORO por cobrar: lo único que puede frenar es la pared.
    private func ready(lastWall: Int, frontier: Int) -> PlayerState {
        var state = fxState()
        state.meta.lifetimeEarnings = 1e12
        state.meta.lastRunMaxTier = lastWall
        state.run.raiseFrontier(to: frontier)
        return state
    }

    private func walled() throws -> StandardEconomy {
        StandardEconomy(config: try fxConfig().tuned(EconomyKnobs(requiresLastRunWall: true)))
    }

    @Test("sin la perilla, reencarnar sigue pidiendo sólo ORO: la v1")
    func offIsV1() {
        let state = ready(lastWall: 4, frontier: 2)
        #expect(PrestigeCalculator.canReincarnate(state: state, economy: fxEconomy()))
        #expect(PrestigeCalculator.lastRunWallGoal(state: state, economy: fxEconomy()) == nil)
    }

    @Test("con la perilla, hace falta llegar a la pared de la run anterior")
    func onNeedsTheWall() throws {
        let economy = try walled()
        let blocked = ready(lastWall: 4, frontier: 2)
        #expect(!PrestigeCalculator.canReincarnate(state: blocked, economy: economy))
        #expect(PrestigeCalculator.lastRunWallGoal(state: blocked, economy: economy) == 4)
        #expect(PrestigeCalculator.canReincarnate(state: ready(lastWall: 4, frontier: 4), economy: economy))
    }

    @Test("la primera reencarnación no pide pared")
    func theFirstHasNoWall() throws {
        #expect(PrestigeCalculator.canReincarnate(state: ready(lastWall: 0, frontier: 1), economy: try walled()))
    }

    @Test("llegar a la pared no alcanza sin ORO")
    func theWallAloneIsNotEnough() throws {
        var state = ready(lastWall: 2, frontier: 2)
        state.meta.lifetimeEarnings = 0
        #expect(!PrestigeCalculator.canReincarnate(state: state, economy: try walled()))
    }
}
