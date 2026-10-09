import EconomyKit
import Foundation

enum RankingError: Error, Equatable, Sendable {
    /// Sin red o timeout: se reintenta en la próxima vuelta a `.active`.
    case offline
    /// 5xx del servidor: se reintenta más tarde.
    case retryLater
    /// 400: el cuerpo o el nombre no pasan las reglas. Definitivo.
    case invalidName
    case notOwner
    case notActive
    case rateLimited
    /// 503: el interruptor del servidor está apagado.
    case disabled
    case badResponse
}

struct StartRunRequest: Codable, Sendable, Equatable {
    let appVersion: String
    let clientRunId: String
}

struct StartRunResponse: Codable, Sendable, Equatable {
    let runId: String
    /// Epoch en segundos, del reloj del servidor.
    let startedAt: TimeInterval
}

struct FinishRunRequest: Codable, Sendable, Equatable {
    let runId: String
    let playedSeconds: Int
    let name: String?
}

struct FinishRunResponse: Codable, Sendable, Equatable {
    enum Status: String, Codable, Sendable { case finished, review }

    let status: Status
    let nameStatus: RankingState.NameStatus
    let realSeconds: Int
    let rank: Int?
}

struct LeaderboardRequest: Codable, Sendable, Equatable {
    let mine: Bool
}

struct LeaderboardRow: Codable, Sendable, Equatable {
    let runId: String
    let rank: Int
    /// `nil` se muestra como "Anónimo".
    let name: String?
    let realSeconds: Int
    let playedSeconds: Int
    let isMe: Bool
}

struct MyRun: Codable, Sendable, Equatable {
    let runId: String
    let startedAt: TimeInterval
    let finishedAt: TimeInterval?
    let realSeconds: Int?
    let playedSeconds: Int?
    let name: String?
    let nameStatus: RankingState.NameStatus
    let status: FinishRunResponse.Status
}

struct LeaderboardResponse: Codable, Sendable, Equatable {
    let top: [LeaderboardRow]
    let me: LeaderboardRow?
    let myRank: Int?
    let mine: [MyRun]?
    let fetchedAt: TimeInterval
}

struct ReportRequest: Codable, Sendable, Equatable {
    let runId: String
}

protocol RankingClient: Sendable {
    func startRun(_ request: StartRunRequest) async throws(RankingError) -> StartRunResponse
    func finishRun(_ request: FinishRunRequest) async throws(RankingError) -> FinishRunResponse
    func leaderboard(_ request: LeaderboardRequest) async throws(RankingError) -> LeaderboardResponse
    func report(_ request: ReportRequest) async throws(RankingError)
}
