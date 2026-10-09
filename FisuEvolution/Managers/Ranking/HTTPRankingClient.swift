import Foundation

/// El cliente real: `POST` JSON a las Edge Functions de Supabase, sólo por HTTPS.
/// El `installId` viaja en el cuerpo, nunca en la URL.
struct HTTPRankingClient: RankingClient {
    typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let timeout: TimeInterval = 10

    let config: RankingConfig
    let identity: InstallIdentity
    let fetch: Fetch

    init(config: RankingConfig, identity: InstallIdentity, fetch: @escaping Fetch = HTTPRankingClient.urlSessionFetch) {
        self.config = config
        self.identity = identity
        self.fetch = fetch
    }

    private static let session = URLSession(configuration: .ephemeral)

    static let urlSessionFetch: Fetch = { request in
        try await HTTPRankingClient.session.data(for: request)
    }

    func startRun(_ request: StartRunRequest) async throws(RankingError) -> StartRunResponse {
        try await call("start-run", request)
    }

    func finishRun(_ request: FinishRunRequest) async throws(RankingError) -> FinishRunResponse {
        try await call("finish-run", request)
    }

    func leaderboard(_ request: LeaderboardRequest) async throws(RankingError) -> LeaderboardResponse {
        try await call("leaderboard", request)
    }

    func report(_ request: ReportRequest) async throws(RankingError) {
        let _: Acknowledgement = try await call("report", request)
    }

    private struct Acknowledgement: Decodable { let ok: Bool }

    private func call<Body: Encodable, Reply: Decodable>(
        _ function: String, _ body: Body
    ) async throws(RankingError) -> Reply {
        guard config.isUsable, let baseURL = config.baseURL, let anonKey = config.anonKey else { throw .disabled }
        let url = baseURL.appending(path: "functions/v1/\(function)")
        guard url.scheme?.lowercased() == "https" else { throw .disabled }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoded(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await fetch(request)
        } catch {
            throw .offline
        }
        guard let http = response as? HTTPURLResponse, response.url?.scheme?.lowercased() == "https" else {
            throw .badResponse
        }
        switch http.statusCode {
        case 200:
            guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { throw .badResponse }
            return reply
        case 400: throw .invalidName
        case 403: throw .notOwner
        case 409: throw .notActive
        case 429: throw .rateLimited
        case 503: throw .disabled
        case 500...599: throw .retryLater
        default: throw .badResponse
        }
    }

    private func encoded(_ body: some Encodable) throws(RankingError) -> Data {
        guard let data = try? JSONEncoder().encode(body),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw .badResponse
        }
        object["installId"] = identity.installId()
        guard let payload = try? JSONSerialization.data(withJSONObject: object) else { throw .badResponse }
        return payload
    }
}
