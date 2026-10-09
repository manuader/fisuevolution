import Foundation
import Testing
@testable import EconomyKit

@Suite("El ranking en el save")
struct RankingSaveTests {
    private func fxSave(lifetime: Double, lastSeen: TimeInterval = 1000) -> PlayerState {
        var state = fxState()
        state.meta.lifetimeEarnings = lifetime
        state.meta.lastSeenTimestamp = lastSeen
        return state
    }

    private func decoded(editingMeta edit: (inout [String: Any]) -> Void) throws -> PlayerState {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fxState())) as? [String: Any])
        var meta = try #require(object["meta"] as? [String: Any])
        edit(&meta)
        object["meta"] = meta
        return try JSONDecoder().decode(PlayerState.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func god(_ runId: String, sealed: Bool = false, played: Double = 100) -> RankingState {
        RankingState(phase: .reachedGod(runId: runId, serverStartedAt: 10, sealed: sealed), playedSeconds: played)
    }

    // MARK: - Decodificación

    @Test("un MetaState sin el argumento nace elegible; un save sin la clave, no")
    func newGameIsEligibleAndMissingKeyIsLegacy() throws {
        #expect(fxState().meta.ranking == .newGame)
        let old = try decoded { $0.removeValue(forKey: "ranking") }
        #expect(old.meta.ranking == .legacy)
    }

    @Test("ida y vuelta con una partida en curso y con una llegada a Dios")
    func roundTrip() throws {
        for ranking in [
            RankingState(phase: .running(runId: "r1", serverStartedAt: 5), playedSeconds: 42, activeSince: 7, clientRunId: nil),
            RankingState(
                phase: .reachedGod(runId: "r1", serverStartedAt: 5, sealed: true), playedSeconds: 90,
                submission: .init(name: "Ana", nameStatus: .ok, realSeconds: 3600, rank: 3), lastName: "Ana", cardOffered: true,
                carriedSubmission: .init(runId: "r0", name: "Beto", sealed: true, playedSeconds: 8)
            ),
            RankingState(phase: .unregisteredGod), .legacy, .newGame,
        ] {
            var state = fxState()
            state.meta.ranking = ranking
            let back = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(state))
            #expect(back.meta.ranking == ranking)
        }
    }

    @Test("un ranking vacío, ilegible o con una fase de una versión futura no cuesta la partida")
    func unreadableRankingDegrades() throws {
        let empty = try decoded { $0["ranking"] = [String: Any]() }
        #expect(empty.meta.ranking.phase == .ineligible)
        let garbage = try decoded { $0["ranking"] = "no soy un ranking" }
        #expect(garbage.meta.ranking == .legacy)
        let future = try decoded { $0["ranking"] = ["phase": ["viaLactea": [String: Any]()], "lastName": "Ana"] as [String: Any] }
        #expect(future.meta.ranking.phase == .ineligible)
        #expect(future.meta.ranking.lastName == "Ana")
        #expect(future.meta.oro == fxState().meta.oro, "el resto del save sigue intacto")
    }

    // MARK: - Conflicto

    @Test("el resolver funde el ranking con el mismo ganador que el resto del meta")
    func resolverMergesRanking() {
        var local = fxSave(lifetime: 1000)
        local.meta.ranking = god("r1")
        var remote = fxSave(lifetime: 10)
        remote.meta.ranking = RankingState(phase: .running(runId: "r1", serverStartedAt: 10), playedSeconds: 500)
        for resolved in [
            SaveConflictResolver.resolve(local: local, remote: remote),
            SaveConflictResolver.resolve(local: remote, remote: local),
        ] {
            #expect(resolved.meta.ranking.phase == .reachedGod(runId: "r1", serverStartedAt: 10, sealed: false))
            #expect(resolved.meta.ranking.playedSeconds == 500)
        }
    }

    @Test("con partidas distintas manda el ganador entero y la llegada sin enviar del otro se conserva")
    func differentGamesKeepTheWinnerAndCarryTheArrival() {
        var winner = fxSave(lifetime: 1000)
        winner.meta.ranking = RankingState(phase: .running(runId: "r2", serverStartedAt: 20))
        var loser = fxSave(lifetime: 10)
        loser.meta.ranking = god("r1", played: 77)
        let resolved = SaveConflictResolver.resolve(local: loser, remote: winner)
        #expect(resolved.meta.ranking.phase == .running(runId: "r2", serverStartedAt: 20))
        #expect(resolved.meta.ranking.carriedSubmission?.runId == "r1")
    }

    @Test("un save legacy que gana no vuelve elegible al perdedor")
    func legacyWinnerStaysLegacy() {
        var winner = fxSave(lifetime: 1000)
        winner.meta.ranking = .legacy
        var loser = fxSave(lifetime: 10)
        loser.meta.ranking = .newGame
        let resolved = SaveConflictResolver.resolve(local: winner, remote: loser)
        #expect(resolved.meta.ranking.phase == .ineligible)
    }

    // MARK: - A través de un reset

    @Test("a través de un reset gana el ranking de la época nueva entero")
    func acrossResetTheNewerEpochWins() {
        var newer = fxSave(lifetime: 0)
        newer.meta.resetEpoch = 1
        newer.meta.ranking = RankingState(phase: .awaitingStart, playedSeconds: 3)
        var older = fxSave(lifetime: 1_000_000)
        older.meta.resetEpoch = 0
        older.meta.ranking = RankingState(phase: .running(runId: "vieja", serverStartedAt: 1), playedSeconds: 9999, cardOffered: true)
        for resolved in [
            SaveConflictResolver.resolve(local: newer, remote: older),
            SaveConflictResolver.resolve(local: older, remote: newer),
        ] {
            #expect(resolved.meta.ranking == newer.meta.ranking, "la partida a medias de la época vieja se descarta")
        }
    }

    @Test("a través de un reset cruzan el último nombre y la llegada a Dios sin enviar")
    func acrossResetCarriesNameAndUnsentArrival() {
        var newer = fxSave(lifetime: 0)
        newer.meta.resetEpoch = 2
        newer.meta.ranking = .newGame
        var older = fxSave(lifetime: 5000)
        older.meta.resetEpoch = 1
        var arrived = god("r1", sealed: true, played: 321)
        arrived.lastName = "Ana"
        older.meta.ranking = arrived
        let resolved = SaveConflictResolver.resolve(local: older, remote: newer)
        #expect(resolved.meta.ranking.phase == .awaitingStart)
        #expect(resolved.meta.ranking.lastName == "Ana")
        #expect(resolved.meta.ranking.carriedSubmission == .init(runId: "r1", name: nil, sealed: true, playedSeconds: 321))
    }

    @Test("a través de un reset no pisa el carry que el reset ya traía ni cruza una llegada ya enviada")
    func acrossResetKeepsExistingCarryAndSkipsSent() {
        var newer = fxSave(lifetime: 0)
        newer.meta.resetEpoch = 2
        newer.meta.ranking = RankingState(
            phase: .awaitingStart, lastName: "Nueva", carriedSubmission: .init(runId: "propia", playedSeconds: 1)
        )
        var older = fxSave(lifetime: 5000)
        older.meta.resetEpoch = 1
        older.meta.ranking = god("ajena")
        let kept = SaveConflictResolver.resolve(local: older, remote: newer).meta.ranking
        #expect(kept.carriedSubmission?.runId == "propia")
        #expect(kept.lastName == "Nueva")

        var sent = god("enviada")
        sent.submission = .init(name: "Ana", nameStatus: .ok, realSeconds: 10)
        older.meta.ranking = sent
        newer.meta.ranking = .newGame
        #expect(SaveConflictResolver.resolve(local: older, remote: newer).meta.ranking.carriedSubmission == nil)
    }
}
