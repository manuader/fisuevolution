import Foundation
import Testing
@testable import EconomyKit

@Suite("El reset abre un intento nuevo del ranking")
struct RankingResetTests {
    private func running() -> RankingState {
        var s = RankingState.newGame
        s.registered(runId: "r1", serverStartedAt: 1_000)
        s.lastName = "Fisu"
        s.playedSeconds = 120
        return s
    }

    private func god(sealed: Bool = false) -> RankingState {
        var s = running()
        s.reachedGod(at: 5_000)
        if sealed { s.sealed(realSeconds: 4_000, underReview: false, nameStatus: .missing) }
        return s
    }

    private func plan(from ranking: RankingState) -> ResetPlan {
        var current = fxState()
        current.meta.ranking = ranking
        return ResetPlan.make(current: current, fresh: fxState())
    }

    @Test("desde cada fase la partida nueva queda en awaitingStart y conserva lastName",
          arguments: [RankingState.legacy, .newGame, RankingState.newGame.withRunning, RankingState.newGame.withGod])
    func everyPhaseRestartsAwaitingStart(source: RankingState) {
        let ranking = plan(from: source).result.meta.ranking
        #expect(ranking.phase == .awaitingStart)
        #expect(ranking.playedSeconds == 0)
        #expect(ranking.activeSince == nil)
        #expect(ranking.lastName == source.lastName)
    }

    @Test("lo que el plan escribe es el forNewGame de la partida de hoy")
    func planWritesForNewGame() {
        for source in [running(), god(), god(sealed: true)] {
            #expect(plan(from: source).result.meta.ranking == source.forNewGame())
        }
    }

    @Test("una llegada a Dios sin enviar viaja en carriedSubmission; sin llegada no viaja nada")
    func carriesOnlyTheUnsentArrival() {
        #expect(plan(from: god()).result.meta.ranking.carriedSubmission == .init(runId: "r1", playedSeconds: 120))
        #expect(plan(from: god(sealed: true)).result.meta.ranking.carriedSubmission
                == .init(runId: "r1", sealed: true, playedSeconds: 120))
        #expect(plan(from: running()).result.meta.ranking.carriedSubmission == nil)
        #expect(plan(from: .newGame).result.meta.ranking.carriedSubmission == nil)
    }

    @Test("el resumen no cambia por el ranking")
    func summaryIgnoresRanking() {
        #expect(plan(from: god()).summary == plan(from: .newGame).summary)
    }
}

private extension RankingState {
    var withRunning: RankingState {
        var s = RankingState.newGame
        s.registered(runId: "r1", serverStartedAt: 1_000)
        s.lastName = "Fisu"
        s.playedSeconds = 120
        return s
    }

    var withGod: RankingState {
        var s = withRunning
        s.reachedGod(at: 5_000)
        return s
    }
}
