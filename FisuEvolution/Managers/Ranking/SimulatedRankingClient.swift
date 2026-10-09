import EconomyKit
import Foundation

/// El servidor de mentira: para los tests y para `--uitest-ranking-<escenario>`. Nunca toca la red.
actor SimulatedRankingClient: RankingClient {
    enum Scenario: String, Sendable, CaseIterable {
        case happy
        case offline
        case rejectFirstName
        case haikuDown
        case outsideTop
        case disabled
    }

    enum Call: Equatable, Sendable {
        case startRun(StartRunRequest)
        case finishRun(FinishRunRequest)
        case leaderboard(LeaderboardRequest)
        case report(ReportRequest)
    }

    static let argumentPrefix = "--uitest-ranking-"

    /// El escenario que pide un UI test; `nil` si no pidió ninguno.
    static func scenario(from arguments: [String]) -> Scenario? {
        arguments.lazy
            .compactMap { argument in
                argument.hasPrefix(argumentPrefix)
                    ? Scenario.allCases.first { $0.argumentName == String(argument.dropFirst(argumentPrefix.count)) }
                    : nil
            }
            .first
    }

    let scenario: Scenario
    private let now: @Sendable () -> TimeInterval
    private(set) var calls: [Call] = []
    private var startedAt: TimeInterval?
    private var rejectedAlready = false

    init(scenario: Scenario = .happy, now: @escaping @Sendable () -> TimeInterval = { Date().timeIntervalSince1970 }) {
        self.scenario = scenario
        self.now = now
    }

    private static let runId = "00000000-0000-4000-8000-000000000001"

    func startRun(_ request: StartRunRequest) async throws(RankingError) -> StartRunResponse {
        calls.append(.startRun(request))
        try gate()
        let started = startedAt ?? now()
        startedAt = started
        return StartRunResponse(runId: Self.runId, startedAt: started)
    }

    func finishRun(_ request: FinishRunRequest) async throws(RankingError) -> FinishRunResponse {
        calls.append(.finishRun(request))
        try gate()
        let real = Int(max(0, now() - (startedAt ?? now())))
        guard request.name != nil else {
            return FinishRunResponse(status: .finished, nameStatus: .missing, realSeconds: real, rank: nil)
        }
        let status: RankingState.NameStatus
        switch scenario {
        case .rejectFirstName where !rejectedAlready:
            rejectedAlready = true
            status = .rejected
        case .haikuDown:
            status = .pending
        default:
            status = .ok
        }
        return FinishRunResponse(status: .finished, nameStatus: status, realSeconds: real, rank: status == .ok ? 7 : nil)
    }

    func leaderboard(_ request: LeaderboardRequest) async throws(RankingError) -> LeaderboardResponse {
        calls.append(.leaderboard(request))
        try gate()
        let fetchedAt = now()
        let mine = request.mine ? [] as [MyRun] : nil
        if scenario == .outsideTop {
            let top = (1...100).map { row($0, isMe: false) }
            let me = row(103, isMe: true)
            return LeaderboardResponse(top: top, me: me, myRank: 103, mine: mine, fetchedAt: fetchedAt)
        }
        let top = (1...10).map { row($0, isMe: $0 == 7) }
        return LeaderboardResponse(top: top, me: top[6], myRank: 7, mine: mine, fetchedAt: fetchedAt)
    }

    func report(_ request: ReportRequest) async throws(RankingError) {
        calls.append(.report(request))
        try gate()
    }

    private func gate() throws(RankingError) {
        switch scenario {
        case .offline: throw .offline
        case .disabled: throw .disabled
        default: break
        }
    }

    private func row(_ rank: Int, isMe: Bool) -> LeaderboardRow {
        LeaderboardRow(
            runId: isMe ? Self.runId : String(format: "00000000-0000-4000-8000-%012d", 1_000 + rank),
            rank: rank,
            name: isMe ? "Fisu" : "Jugador \(rank)",
            realSeconds: 100_000 + rank * 600,
            playedSeconds: 60_000 + rank * 300,
            isMe: isMe
        )
    }
}

private extension SimulatedRankingClient.Scenario {
    var argumentName: String {
        switch self {
        case .happy: "happy"
        case .offline: "offline"
        case .rejectFirstName: "reject-first-name"
        case .haikuDown: "haiku-down"
        case .outsideTop: "outside-top"
        case .disabled: "disabled"
        }
    }
}
