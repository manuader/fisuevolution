import EconomyKit
import Foundation

/// Lo que la personalización recuerda entre arranques (2.1 E15 F1): el último cálculo, el último
/// segmento que salió a la telemetría y las últimas sesiones. Vive en `Application Support`, **no
/// en el save**: un reinstalado arranca en `base` hasta su primer cálculo (Dudas 2 del plan).
struct PersonalizationRecord: Codable, Sendable, Equatable {
    /// Una sesión de juego (de `.active` a `.background`), con los contadores de la partida al
    /// empezarla: la diferencia con los de ahora es lo que pasó en la ventana.
    struct Session: Codable, Sendable, Equatable {
        var startedAt: Date
        /// `nil` mientras está abierta, o si la app murió sin pasar por `.background`.
        var seconds: Double?
        /// `meta.prestigeLevel` al empezar.
        var prestige: Int
        /// Las ofertas mostradas desde siempre (`meta.offerFunnel`) al empezar.
        var offersShown: Int
    }

    /// El último cálculo de `PlayerValue`, con la variante que lo hizo.
    struct Computation: Codable, Sendable, Equatable {
        var segment: PlayerSegment
        var expectedMicrosPerVideo: Int64
        var score: Double
        var tablesVersion: String
        /// `PlayerValueEstimate.Source.rawValue`.
        var source: String
        /// El `src` del evento `segment`: `rules` o `tree-<v>`.
        var src: String
        /// Con qué se pidió el cálculo (`rules`, o `model:<versión>` en el brazo modelo del A/B): si
        /// cambia, se recalcula aunque sea el mismo día.
        var variant: String
        var computedAt: Date

        init(_ estimate: PlayerValueEstimate, src: String, variant: String, computedAt: Date) {
            segment = estimate.segment
            expectedMicrosPerVideo = estimate.expectedMicrosPerVideo
            score = estimate.score
            tablesVersion = estimate.tablesVersion
            source = estimate.source.rawValue
            self.src = src
            self.variant = variant
            self.computedAt = computedAt
        }

        var estimate: PlayerValueEstimate {
            PlayerValueEstimate(
                segment: segment, expectedMicrosPerVideo: expectedMicrosPerVideo, score: score,
                tablesVersion: tablesVersion, source: PlayerValueEstimate.Source(rawValue: source) ?? .rules)
        }
    }

    static let maxSessions = 30
    static let empty = PersonalizationRecord(computation: nil, reportedSegment: nil, sessions: [])

    var computation: Computation?
    /// El último segmento que salió en un evento `segment`; `nil` si nunca salió ninguno.
    var reportedSegment: PlayerSegment?
    /// Las últimas `maxSessions`, de la más vieja a la más nueva.
    var sessions: [Session]

    mutating func beginSession(at date: Date, prestige: Int, offersShown: Int) {
        sessions.append(Session(startedAt: date, seconds: nil, prestige: prestige, offersShown: offersShown))
        if sessions.count > Self.maxSessions { sessions.removeFirst(sessions.count - Self.maxSessions) }
    }

    /// Cierra la última sesión si sigue abierta. Una sesión vieja que quedó sin cierre no se toca.
    mutating func endSession(at date: Date) {
        guard let last = sessions.indices.last, sessions[last].seconds == nil else { return }
        sessions[last].seconds = max(0, date.timeIntervalSince(sessions[last].startedAt))
    }
}

/// `Application Support/personalization.json`, con escritura atómica. Un archivo que no se puede
/// leer es un registro vacío: la personalización vuelve a calcular, nunca se traba.
struct PersonalizationStore: Sendable {
    let url: URL

    init(url: URL = PersonalizationStore.defaultURL) {
        self.url = url
    }

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "personalization.json")
    }

    func load() -> PersonalizationRecord {
        guard let data = try? Data(contentsOf: url),
              let record = try? JSONDecoder().decode(PersonalizationRecord.self, from: data) else { return .empty }
        return record
    }

    func save(_ record: PersonalizationRecord) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(record) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
