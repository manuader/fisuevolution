import Foundation
import Testing
@testable import FisuEvolution

@Suite("Cliente simulado del ranking")
struct SimulatedRankingClientTests {
    private let start = StartRunRequest(appVersion: "2.0", clientRunId: "c")

    private func make(_ scenario: SimulatedRankingClient.Scenario) -> SimulatedRankingClient {
        SimulatedRankingClient(scenario: scenario, now: { 1_000 })
    }

    @Test("el escenario sale de --uitest-ranking-<nombre>")
    func scenarioFromArguments() {
        #expect(SimulatedRankingClient.scenario(from: ["app", "--uitest-ranking-outside-top"]) == .outsideTop)
        #expect(SimulatedRankingClient.scenario(from: ["--uitest-ranking-reject-first-name"]) == .rejectFirstName)
        #expect(SimulatedRankingClient.scenario(from: ["--uitest-ranking-haiku-down"]) == .haikuDown)
        #expect(SimulatedRankingClient.scenario(from: ["--uitest-ranking-happy"]) == .happy)
        #expect(SimulatedRankingClient.scenario(from: ["--uitest-ranking-nada", "--uitest"]) == nil)
    }

    @Test("happy: registra, sella sin nombre, entra al ranking y lista")
    func happyPath() async throws {
        let client = make(.happy)
        let run = try await client.startRun(start)
        let sealed = try await client.finishRun(FinishRunRequest(runId: run.runId, playedSeconds: 10, name: nil))
        #expect(sealed.nameStatus == .missing)
        let named = try await client.finishRun(FinishRunRequest(runId: run.runId, playedSeconds: 10, name: "Fisu"))
        #expect(named.nameStatus == .ok && named.rank == 7)
        let board = try await client.leaderboard(LeaderboardRequest(mine: true))
        #expect(board.top.count == 10 && board.me?.isMe == true && board.mine == [])
        try await client.report(ReportRequest(runId: run.runId))
        #expect(await client.calls.count == 5)
    }

    @Test("offline y disabled fallan en todo")
    func failingScenarios() async {
        for (scenario, error) in [(SimulatedRankingClient.Scenario.offline, RankingError.offline), (.disabled, .disabled)] {
            let client = make(scenario)
            await #expect(throws: error) { try await client.startRun(start) }
            await #expect(throws: error) { try await client.leaderboard(LeaderboardRequest(mine: false)) }
        }
    }

    @Test("rejectFirstName rechaza sólo el primer nombre")
    func rejectsOnlyTheFirstName() async throws {
        let client = make(.rejectFirstName)
        let first = try await client.finishRun(FinishRunRequest(runId: "r", playedSeconds: 1, name: "Uno"))
        let second = try await client.finishRun(FinishRunRequest(runId: "r", playedSeconds: 1, name: "Dos"))
        #expect(first.nameStatus == .rejected)
        #expect(second.nameStatus == .ok)
    }

    @Test("haikuDown deja el nombre pendiente")
    func haikuDownLeavesPending() async throws {
        let response = try await make(.haikuDown).finishRun(FinishRunRequest(runId: "r", playedSeconds: 1, name: "Fisu"))
        #expect(response.nameStatus == .pending && response.rank == nil)
    }

    @Test("outsideTop: 100 filas y la propia en el puesto 103")
    func outsideTop() async throws {
        let board = try await make(.outsideTop).leaderboard(LeaderboardRequest(mine: false))
        #expect(board.top.count == 100)
        #expect(board.top.allSatisfy { !$0.isMe })
        #expect(board.me?.rank == 103 && board.myRank == 103)
        #expect(board.mine == nil)
    }

    @Test("el reloj inyectado fija el tiempo real")
    func injectedClock() async throws {
        let clock = Clock()
        let client = SimulatedRankingClient(scenario: .happy, now: { clock.value })
        let run = try await client.startRun(start)
        clock.value = run.startedAt + 3_600
        let sealed = try await client.finishRun(FinishRunRequest(runId: run.runId, playedSeconds: 1, name: nil))
        #expect(sealed.realSeconds == 3_600)
    }
}

private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: TimeInterval = 1_000
    var value: TimeInterval {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}
