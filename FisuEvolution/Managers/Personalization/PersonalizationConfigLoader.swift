import Foundation

/// Trae la config de personalización (2.1 E15 F1, contrato C3) de `rpc/personalization_config`, en
/// el mismo Supabase del ranking (`RankingConfig`, sesión efímera, como `TelemetrySwitch`).
///
/// - **El interruptor manda.** `isEnabled` es `true` sólo después de que el servidor contestó un
///   envoltorio válido en esta sesión; arranca en `false` y un `null` lo apaga **y borra la caché**.
///   Sin red al arrancar, la personalización queda cerrada hasta la primera respuesta: ante la duda,
///   `base`.
/// - **Lo demás no toca nada.** Un error, sin red, un timeout, una respuesta por `http://`, un cuerpo
///   de más de 64 KB o uno que no es un objeto con `sections`: quedan el estado y la caché de antes.
/// - `current()` es sólo disco: la caché si se puede leer; si no, el respaldo del bundle armado como
///   envoltorio (`player_value.json`, `segments.json`, `moments.json`, los que existan).
/// - Refresca al arrancar (`force`) y al volver del background, como mucho cada 6 h. Una pregunta
///   sin respuesta no cuenta: la próxima vuelta pregunta de nuevo.
actor PersonalizationConfigLoader {
    static let path = "rpc/personalization_config"
    static let maxBytes = 64 * 1024
    static let maxAge: TimeInterval = 6 * 60 * 60

    enum RefreshOutcome: Equatable, Sendable {
        /// El servidor mandó una config: prendido y guardada.
        case enabled
        /// El servidor dijo `null`: apagado y sin caché.
        case disabled
        /// Sin una respuesta usable: quedan el estado y la caché de antes.
        case kept
        /// La última respuesta tiene menos de 6 h: no se preguntó.
        case notDue
    }

    private let config: RankingConfig?
    private let cacheURL: URL
    private let bundledSections: [String: URL]
    private let fetch: TelemetryNetwork.Fetch
    private let now: @Sendable () -> Date
    private(set) var isEnabled = false
    private var answeredAt: Date?

    init(
        config: RankingConfig?,
        cacheURL: URL = PersonalizationConfigLoader.defaultCacheURL,
        bundledSections: [String: URL] = PersonalizationConfigLoader.bundledSections(),
        fetch: @escaping TelemetryNetwork.Fetch = TelemetryNetwork.urlSessionFetch,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.config = config
        self.cacheURL = cacheURL
        self.bundledSections = bundledSections
        self.fetch = fetch
        self.now = now
    }

    /// El de la app: la `RankingConfig` del ranking. Bajo XCTest o `--uitest*` no recibe config, así
    /// que nunca pregunta y queda apagado.
    static func live(config: RankingConfig?) -> PersonalizationConfigLoader {
        PersonalizationConfigLoader(config: RankingStore.isLive ? config : nil)
    }

    static var defaultCacheURL: URL {
        URL.cachesDirectory.appending(path: "personalization-config.json")
    }

    /// Los respaldos del bundle, por clave de sección. Un archivo que no está, no entra.
    static func bundledSections(in bundle: Bundle = .main) -> [String: URL] {
        let files = ["player_value": "player_value", "segments": "segments", "moments": "moments"]
        return files.reduce(into: [:]) { result, entry in
            if let url = bundle.url(forResource: entry.value, withExtension: "json") { result[entry.key] = url }
        }
    }

    /// La caché si se puede leer; si no, el envoltorio del bundle (versión 0).
    func current() -> PersonalizationConfig {
        if let data = try? Data(contentsOf: cacheURL), let cached = PersonalizationConfig.decode(data) {
            return cached
        }
        return bundled()
    }

    /// `force` pregunta siempre (el arranque); si no, sólo si la última respuesta tiene 6 h o más.
    @discardableResult
    func refresh(force: Bool) async -> RefreshOutcome {
        if !force, let answeredAt, now().timeIntervalSince(answeredAt) < Self.maxAge { return .notDue }
        guard let data = await ask() else { return .kept }

        if isNull(data) {
            answeredAt = now()
            isEnabled = false
            try? FileManager.default.removeItem(at: cacheURL)
            return .disabled
        }
        guard PersonalizationConfig.decode(data) != nil else { return .kept }
        guard (try? data.write(to: cacheURL, options: .atomic)) != nil else { return .kept }
        answeredAt = now()
        isEnabled = true
        return .enabled
    }

    /// El cuerpo de un 200 por HTTPS de hasta 64 KB; `nil` si no hubo una respuesta así.
    private func ask() async -> Data? {
        guard let request = TelemetryNetwork.post(Self.path, body: Data("{}".utf8), config: config),
              let reply = await TelemetryNetwork.send(request, with: fetch),
              reply.1.statusCode == 200,
              reply.0.count <= Self.maxBytes else { return nil }
        return reply.0
    }

    private func isNull(_ data: Data) -> Bool {
        (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) is NSNull
    }

    private func bundled() -> PersonalizationConfig {
        var sections: [String: Data] = [:]
        for (key, url) in bundledSections {
            guard let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { continue }
            sections[key] = encoded
        }
        return PersonalizationConfig(version: 0, sections: sections)
    }
}
