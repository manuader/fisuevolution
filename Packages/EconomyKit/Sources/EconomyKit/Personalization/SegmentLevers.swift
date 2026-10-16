import Foundation

/// `segments.json` (sección `segments` de la config remota): las palancas de ayuda opcional de cada
/// segmento (2.1 E15 F2, contrato C1). Cada palanca sólo puede dar **más** ayuda que la base: premio por
/// video más grande, colchón gratis, visitantes y pausas del costado más seguidos, y menos forzados.
///
/// `base` no está en el archivo: es la identidad, siempre, la diga o no el archivo. Los topes viven en el
/// código (`Caps`): lo remoto puede ser menos generoso, nunca más, y un valor fuera de tope invalida el
/// archivo entero (no se recorta).
public struct SegmentLevers: Codable, Sendable, Equatable {
    /// La fuente de un premio con «×2 con video»: el `site` de `RewardDouble` sin el prefijo `double.` ni
    /// el sufijo (`double.visit.ministro_subsidio` → `visit`).
    public enum Source: String, Codable, Sendable, CaseIterable {
        case offline, daily, career, wheel, mattress, visit, achievement, event

        /// La fuente de un `site` de `RewardDouble`; `nil` si no es uno.
        public init?(site: String) {
            let parts = site.split(separator: ".")
            guard parts.count >= 2, parts[0] == "double" else { return nil }
            self.init(rawValue: String(parts[1]))
        }
    }

    /// Las palancas de un segmento. Una palanca que el archivo no trae queda como en la base.
    public struct Levers: Codable, Sendable, Equatable {
        /// El multiplicador del premio con video por fuente (`Source.rawValue`). Una fuente que falta = ×2.
        public var videoRewardMultiplier: [String: Double]
        /// Escala del intervalo del colchón gratis del tablero (< 1 = más seguido).
        public var freeMattressIntervalScale: Double
        /// Escala del intervalo entre visitantes (< 1 = más seguidos).
        public var visitorIntervalScale: Double
        /// Escala de las pausas de las ayudas del costado (< 1 = más cortas).
        public var sideRailCooldownScale: Double
        /// Escala del espaciado entre forzados (> 1 = menos forzados).
        public var forcedSpacingScale: Double

        /// El ×N de una fuente sin palanca: el de la 2.0.
        public static let baseVideoRewardMultiplier = 2.0

        /// La base: el juego de la 2.0, sin ninguna palanca.
        public static let identity = Levers()

        public init(
            videoRewardMultiplier: [String: Double] = [:],
            freeMattressIntervalScale: Double = 1,
            visitorIntervalScale: Double = 1,
            sideRailCooldownScale: Double = 1,
            forcedSpacingScale: Double = 1
        ) {
            self.videoRewardMultiplier = videoRewardMultiplier
            self.freeMattressIntervalScale = freeMattressIntervalScale
            self.visitorIntervalScale = visitorIntervalScale
            self.sideRailCooldownScale = sideRailCooldownScale
            self.forcedSpacingScale = forcedSpacingScale
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            videoRewardMultiplier = try container.decodeIfPresent([String: Double].self, forKey: .videoRewardMultiplier) ?? [:]
            freeMattressIntervalScale = try container.decodeIfPresent(Double.self, forKey: .freeMattressIntervalScale) ?? 1
            visitorIntervalScale = try container.decodeIfPresent(Double.self, forKey: .visitorIntervalScale) ?? 1
            sideRailCooldownScale = try container.decodeIfPresent(Double.self, forKey: .sideRailCooldownScale) ?? 1
            forcedSpacingScale = try container.decodeIfPresent(Double.self, forKey: .forcedSpacingScale) ?? 1
        }

        /// El ×N del premio con video de una fuente.
        public func rewardMultiplier(for source: Source) -> Double {
            videoRewardMultiplier[source.rawValue] ?? Self.baseVideoRewardMultiplier
        }
    }

    /// Los topes: constantes del código. **Los `videoRewardMultiplier` por fuente y `minScale` son
    /// provisorios hasta la calibración (F2-T5)**, que los fija para que el peor caso remoto (todo en el
    /// tope) siga llegando a Dios en ≥ 30 h con `.ads` (V3, V7).
    public enum Caps {
        /// El ×N máximo por fuente; nunca más de ×2,5 (V3).
        public static let videoRewardMultiplier: [Source: Double] = Dictionary(
            uniqueKeysWithValues: Source.allCases.map { ($0, 2.5) }
        )
        /// La escala más chica del intervalo del colchón gratis.
        public static let minScale = 0.75

        public static func videoRewardMultiplierRange(for source: Source) -> ClosedRange<Double> {
            Levers.baseVideoRewardMultiplier...(videoRewardMultiplier[source] ?? Levers.baseVideoRewardMultiplier)
        }
        public static let freeMattressIntervalScale: ClosedRange<Double> = minScale...1
        public static let visitorIntervalScale: ClosedRange<Double> = 0.75...1
        public static let sideRailCooldownScale: ClosedRange<Double> = 0.75...1
        public static let forcedSpacingScale: ClosedRange<Double> = 1...3

        /// Todo en el tope: el peor caso que podría mandar lo remoto (`pacing-sim --caps`).
        public static var worstCase: Levers {
            Levers(
                videoRewardMultiplier: Dictionary(
                    uniqueKeysWithValues: Source.allCases.map { ($0.rawValue, videoRewardMultiplierRange(for: $0).upperBound) }
                ),
                freeMattressIntervalScale: freeMattressIntervalScale.lowerBound,
                visitorIntervalScale: visitorIntervalScale.lowerBound,
                sideRailCooldownScale: sideRailCooldownScale.lowerBound,
                forcedSpacingScale: forcedSpacingScale.upperBound
            )
        }
    }

    public var version: String
    /// Las palancas por segmento (`PlayerSegment.rawValue`). Un segmento que falta queda en la base.
    public var segments: [String: Levers]

    public init(version: String, segments: [PlayerSegment: Levers]) {
        self.version = version
        self.segments = Dictionary(uniqueKeysWithValues: segments.map { ($0.key.rawValue, $0.value) })
    }

    /// Las palancas de un segmento. `base` es la identidad siempre, sin mirar el archivo.
    public func levers(for segment: PlayerSegment) -> Levers {
        guard segment != .base else { return .identity }
        return segments[segment.rawValue] ?? .identity
    }

    public enum ValidationError: Error, Equatable {
        case emptyVersion
        case unknownSegment(String)
        case unknownSource(segment: String, source: String)
        case outOfRange(segment: String, lever: String)
        case notMonotonic(lever: String)
    }

    /// Todo o nada: un valor fuera de tope, una clave desconocida o un segmento más generoso que el de
    /// arriba invalida el archivo entero.
    public func validate() throws {
        guard !version.trimmingCharacters(in: .whitespaces).isEmpty else { throw ValidationError.emptyVersion }
        for (key, levers) in segments {
            guard PlayerSegment(rawValue: key) != nil else { throw ValidationError.unknownSegment(key) }
            try Self.validate(levers, segment: key)
        }
        try validateMonotonic()
    }

    private static func validate(_ levers: Levers, segment: String) throws {
        for (key, multiplier) in levers.videoRewardMultiplier {
            guard let source = Source(rawValue: key) else {
                throw ValidationError.unknownSource(segment: segment, source: key)
            }
            guard Caps.videoRewardMultiplierRange(for: source).contains(multiplier) else {
                throw ValidationError.outOfRange(segment: segment, lever: "videoRewardMultiplier.\(key)")
            }
        }
        let scales: [(String, Double, ClosedRange<Double>)] = [
            ("freeMattressIntervalScale", levers.freeMattressIntervalScale, Caps.freeMattressIntervalScale),
            ("visitorIntervalScale", levers.visitorIntervalScale, Caps.visitorIntervalScale),
            ("sideRailCooldownScale", levers.sideRailCooldownScale, Caps.sideRailCooldownScale),
            ("forcedSpacingScale", levers.forcedSpacingScale, Caps.forcedSpacingScale),
        ]
        for (lever, value, range) in scales where !range.contains(value) {
            throw ValidationError.outOfRange(segment: segment, lever: lever)
        }
    }

    /// La generosidad sube `low ≤ mid ≤ high` en cada palanca (el `base` del archivo no cuenta).
    private func validateMonotonic() throws {
        let ladder = [PlayerSegment.low, .mid, .high].map(levers(for:))
        var generosity: [(lever: String, value: (Levers) -> Double)] = [
            ("freeMattressIntervalScale", { levers in -levers.freeMattressIntervalScale }),
            ("visitorIntervalScale", { levers in -levers.visitorIntervalScale }),
            ("sideRailCooldownScale", { levers in -levers.sideRailCooldownScale }),
            ("forcedSpacingScale", { levers in levers.forcedSpacingScale }),
        ]
        for source in Source.allCases {
            generosity.append(("videoRewardMultiplier.\(source.rawValue)", { levers in levers.rewardMultiplier(for: source) }))
        }
        for (lever, value) in generosity {
            let values: [Double] = ladder.map(value)
            guard zip(values, values.dropFirst()).allSatisfy({ $0 <= $1 }) else {
                throw ValidationError.notMonotonic(lever: lever)
            }
        }
    }
}
