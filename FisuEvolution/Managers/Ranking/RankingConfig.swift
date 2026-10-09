import Foundation

/// La config del ranking: viene en el bundle y se puede apagar o mover de URL desde el sitio.
/// `baseURL` y `anonKey` nulos (hasta el despliegue real) dejan la config sin usar y la app,
/// con el cliente simulado.
struct RankingConfig: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let enabled: Bool
    let baseURL: URL?
    let anonKey: String?

    static let supportedSchemaVersion = 1

    var isUsable: Bool {
        enabled && baseURL?.scheme == "https" && anonKey?.isEmpty == false
    }

    enum Rejection: Error, Equatable, Sendable {
        case undecodable
        case unsupportedSchema
        case notHTTPS
        case badResponse
        case tooLarge
        /// El remoto sólo puede apagar o cambiar la URL, no la clave.
        case foreignAnonKey
    }

    /// Decodifica y valida un archivo (del bundle, de la caché o del remoto).
    static func decodeValidated(_ data: Data) throws(Rejection) -> RankingConfig {
        guard let config = try? JSONDecoder().decode(RankingConfig.self, from: data) else { throw .undecodable }
        guard config.schemaVersion == supportedSchemaVersion else { throw .unsupportedSchema }
        if let baseURL = config.baseURL, baseURL.scheme?.lowercased() != "https" { throw .notHTTPS }
        return config
    }
}

/// Baja, valida y guarda `ranking.json` (mismo patrón que `AdsRemoteConfigLoader`): `current()`
/// lee sólo disco y nunca bloquea; `refresh()` es la red, y una respuesta mala deja la caché intacta.
struct RankingConfigLoader: Sendable {
    typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let productionURL = URL(string: "https://adergames-site.vercel.app/config/ranking.json")!
    static let maxBytes = 16 * 1024

    enum Source: Equatable, Sendable {
        case cache
        case bundle
    }

    struct Loaded: Equatable, Sendable {
        let config: RankingConfig
        let source: Source
    }

    enum RefreshOutcome: Equatable, Sendable {
        case updated(RankingConfig)
        case rejected(RankingConfig.Rejection)
        case unreachable
    }

    let remoteURL: URL
    let cacheURL: URL
    let bundledURL: URL?
    let fetch: Fetch

    init(
        remoteURL: URL = RankingConfigLoader.productionURL,
        cacheURL: URL = RankingConfigLoader.defaultCacheURL,
        bundledURL: URL? = Bundle.main.url(forResource: "ranking", withExtension: "json"),
        fetch: @escaping Fetch = RankingConfigLoader.urlSessionFetch
    ) {
        self.remoteURL = remoteURL
        self.cacheURL = cacheURL
        self.bundledURL = bundledURL
        self.fetch = fetch
    }

    static var defaultCacheURL: URL {
        URL.cachesDirectory.appending(path: "ranking-remote-config.json")
    }

    private static let session = URLSession(configuration: .ephemeral)

    static let urlSessionFetch: Fetch = { request in
        try await RankingConfigLoader.session.data(for: request)
    }

    private var bundled: RankingConfig? {
        guard let bundledURL, let data = try? Data(contentsOf: bundledURL) else { return nil }
        return try? RankingConfig.decodeValidated(data)
    }

    /// La caché si sigue siendo válida (y no cambia la clave del bundle); si no, el bundle.
    func current() -> Loaded? {
        let fallback = bundled
        if let data = try? Data(contentsOf: cacheURL),
           let config = try? RankingConfig.decodeValidated(data),
           fallback.map({ $0.anonKey == config.anonKey }) ?? true {
            return Loaded(config: config, source: .cache)
        }
        return fallback.map { Loaded(config: $0, source: .bundle) }
    }

    func refresh() async -> RefreshOutcome {
        guard remoteURL.scheme?.lowercased() == "https" else { return .rejected(.notHTTPS) }

        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false

        let fetched: (Data, URLResponse)
        do {
            fetched = try await fetch(request)
        } catch {
            return .unreachable
        }
        let (data, response) = fetched
        guard let finalURL = response.url, finalURL.scheme?.lowercased() == "https" else {
            return .rejected(.notHTTPS)
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return .rejected(.badResponse) }
        guard data.count <= Self.maxBytes else { return .rejected(.tooLarge) }

        let config: RankingConfig
        do {
            config = try RankingConfig.decodeValidated(data)
        } catch {
            return .rejected(error)
        }
        if let bundled, bundled.anonKey != config.anonKey { return .rejected(.foreignAnonKey) }

        try? data.write(to: cacheURL, options: .atomic)
        return .updated(config)
    }
}
