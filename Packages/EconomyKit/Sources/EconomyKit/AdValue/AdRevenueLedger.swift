import Foundation

/// Cuánto pagaron los anuncios de esta cuenta, por formato (E15 C2). Vive en el save como
/// `meta.adRevenue`; es medición pura: ningún cálculo de economía ni de ritmo lo lee.
///
/// Los agregados se llevan en UNA moneda, la de la primera impresión: AdMob informa en la de la
/// cuenta, que no cambia. Una impresión en otra moneda entra al anillo (queda a la vista) pero no
/// a los agregados, y suma `foreignCurrencyCount`.
public struct AdRevenueLedger: Codable, Sendable, Equatable {
    /// Cuántas impresiones recientes guarda cada formato.
    public static let recentCapacity = 20

    public struct FormatStats: Codable, Sendable, Equatable {
        /// Las últimas `recentCapacity`, de la más vieja a la más nueva.
        public internal(set) var recent: [AdImpression]
        /// Impresiones en la moneda del ledger, desde siempre.
        public internal(set) var count: Int
        public internal(set) var totalMicros: Int64
        public internal(set) var maxMicros: Int64

        public static let empty = FormatStats(recent: [], count: 0, totalMicros: 0, maxMicros: 0)

        public init(recent: [AdImpression], count: Int, totalMicros: Int64, maxMicros: Int64) {
            self.recent = recent
            self.count = count
            self.totalMicros = totalMicros
            self.maxMicros = maxMicros
        }

        /// `totalMicros / count`; 0 sin impresiones.
        public var meanMicros: Int64 {
            count == 0 ? 0 : totalMicros / Int64(count)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            recent = try container.decodeIfPresent([AdImpression].self, forKey: .recent) ?? []
            count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
            totalMicros = try container.decodeIfPresent(Int64.self, forKey: .totalMicros) ?? 0
            maxMicros = try container.decodeIfPresent(Int64.self, forKey: .maxMicros) ?? 0
        }
    }

    /// La moneda de los agregados: la de la primera impresión. nil hasta que llega una.
    public internal(set) var currency: String?
    /// Por `AdFormat.rawValue`: un mapa de `String` y no de `AdFormat` para que el JSON sea un
    /// objeto legible y un formato que este build no conoce no rompa la lectura.
    public internal(set) var formats: [String: FormatStats]
    /// Impresiones que llegaron en otra moneda que `currency`.
    public internal(set) var foreignCurrencyCount: Int

    public static let empty = AdRevenueLedger(currency: nil, formats: [:], foreignCurrencyCount: 0)

    public init(currency: String?, formats: [String: FormatStats], foreignCurrencyCount: Int) {
        self.currency = currency
        self.formats = formats
        self.foreignCurrencyCount = foreignCurrencyCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        formats = try container.decodeIfPresent([String: FormatStats].self, forKey: .formats) ?? [:]
        foreignCurrencyCount = try container.decodeIfPresent(Int.self, forKey: .foreignCurrencyCount) ?? 0
    }

    public func stats(_ format: AdFormat) -> FormatStats {
        formats[format.rawValue] ?? .empty
    }

    /// Anota una impresión: siempre al anillo de su formato; a los agregados sólo si viene en la
    /// moneda del ledger.
    public mutating func record(_ impression: AdImpression) {
        let ledgerCurrency = currency ?? impression.currency
        currency = ledgerCurrency
        var stats = stats(impression.format)
        stats.recent.append(impression)
        if stats.recent.count > Self.recentCapacity {
            stats.recent.removeFirst(stats.recent.count - Self.recentCapacity)
        }
        if impression.currency == ledgerCurrency {
            let micros = max(0, impression.valueMicros)
            stats.count += 1
            stats.totalMicros = Self.saturatingAdd(stats.totalMicros, micros)
            stats.maxMicros = max(stats.maxMicros, micros)
        } else {
            foreignCurrencyCount += 1
        }
        formats[impression.format.rawValue] = stats
    }

    // MARK: - Los atajos con los nombres del reel

    /// El promedio del anillo de `format`, sólo las impresiones en la moneda del ledger; 0 si no hay.
    public func recentMicros(format: AdFormat) -> Int64 {
        let values = stats(format).recent.filter { $0.currency == currency }.map { max(0, $0.valueMicros) }
        guard !values.isEmpty else { return 0 }
        return values.reduce(Int64(0), Self.saturatingAdd) / Int64(values.count)
    }

    /// La impresión que más pagó, de cualquier formato.
    public var maxMicros: Int64 {
        formats.values.map(\.maxMicros).max() ?? 0
    }

    /// Lo que paga en promedio un video con premio.
    public var averageRewardedMicros: Int64 {
        stats(.rewarded).meanMicros
    }

    // MARK: - Sincronización

    /// Dos devices: por formato gana entero (con su anillo) el lado con más impresiones contadas,
    /// el mismo criterio de «máximo de contadores monótonos» que `stats`. En empate, el ganador del
    /// save. Si los dos ya fijaron monedas distintas, sus agregados no se mezclan: queda entero
    /// el lado con más impresiones.
    public static func resolve(winner: AdRevenueLedger, loser: AdRevenueLedger) -> AdRevenueLedger {
        if let mine = winner.currency, let theirs = loser.currency, mine != theirs {
            return loser.totalCount > winner.totalCount ? loser : winner
        }
        var merged = winner
        merged.currency = winner.currency ?? loser.currency
        for key in Set(winner.formats.keys).union(loser.formats.keys) {
            let mine = winner.formats[key] ?? .empty
            let theirs = loser.formats[key] ?? .empty
            merged.formats[key] = theirs.count > mine.count ? theirs : mine
        }
        merged.foreignCurrencyCount = max(winner.foreignCurrencyCount, loser.foreignCurrencyCount)
        return merged
    }

    private var totalCount: Int {
        formats.values.reduce(0) { $0 + $1.count }
    }

    /// Un total que no entra en `Int64` se queda en el tope: medir nunca puede tirar abajo la app.
    private static func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : sum
    }
}
