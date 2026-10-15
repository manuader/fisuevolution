import Foundation

/// Lo que comparten los dos pedidos de la telemetría: la sesión efímera y los headers de
/// Supabase con la clave anónima del ranking (`RankingConfig`, E12).
enum TelemetryNetwork {
    typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let timeout: TimeInterval = 10

    private static let session = URLSession(configuration: .ephemeral)

    static let urlSessionFetch: Fetch = { request in
        try await TelemetryNetwork.session.data(for: request)
    }

    /// Un `POST` JSON a `{baseURL}/rest/v1/<path>`, sólo si la config es usable y HTTPS.
    static func post(_ path: String, body: Data, config: RankingConfig?) -> URLRequest? {
        guard let config, config.isUsable, let baseURL = config.baseURL, let anonKey = config.anonKey else { return nil }
        let url = baseURL.appending(path: "rest/v1/\(path)")
        guard url.scheme?.lowercased() == "https" else { return nil }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    /// La respuesta HTTP, si llegó por HTTPS; `nil` si no hubo red o se degradó a `http://`.
    static func send(_ request: URLRequest, with fetch: Fetch) async -> (Data, HTTPURLResponse)? {
        guard let reply = try? await fetch(request),
              let http = reply.1 as? HTTPURLResponse,
              http.url?.scheme?.lowercased() == "https" else { return nil }
        return (reply.0, http)
    }
}

/// El interruptor remoto (C5.2): pregunta `rpc/telemetry_enabled` al mismo Supabase del ranking.
///
/// Todo lo que no sea un `true` explícito es **apagado**: un error, sin red, un timeout, un cuerpo
/// raro o una `RankingConfig` que no se puede usar. La respuesta se guarda en memoria y se vuelve a
/// preguntar al volver del background, como mucho cada 6 h. Una pregunta sin respuesta no cuenta:
/// la próxima vuelta pregunta de nuevo.
actor TelemetrySwitch {
    static let maxAge: TimeInterval = 6 * 60 * 60

    private let config: RankingConfig?
    private let fetch: TelemetryNetwork.Fetch
    private let now: @Sendable () -> Date
    private(set) var isEnabled = false
    /// `true` sólo si el servidor contestó un `false` explícito (no un error ni la falta de red):
    /// es lo único del interruptor que autoriza a vaciar la cola.
    private(set) var saidNo = false
    private var answeredAt: Date?

    init(
        config: RankingConfig?,
        fetch: @escaping TelemetryNetwork.Fetch = TelemetryNetwork.urlSessionFetch,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.config = config
        self.fetch = fetch
        self.now = now
    }

    /// `force` pregunta siempre (el arranque); si no, sólo si la última respuesta tiene 6 h o más.
    @discardableResult
    func refresh(force: Bool) async -> Bool {
        if !force, let answeredAt, now().timeIntervalSince(answeredAt) < Self.maxAge { return isEnabled }
        let answer = await ask()
        if let answer {
            answeredAt = now()
            saidNo = !answer
        }
        isEnabled = answer == true
        return isEnabled
    }

    /// `true`/`false` si el servidor contestó un booleano; `nil` si no hubo una respuesta clara.
    private func ask() async -> Bool? {
        guard let request = TelemetryNetwork.post("rpc/telemetry_enabled", body: Data("{}".utf8), config: config),
              let reply = await TelemetryNetwork.send(request, with: fetch),
              reply.1.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(Bool.self, from: reply.0)
    }
}
