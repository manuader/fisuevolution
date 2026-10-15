import Foundation

/// Las etapas de una oferta con video (E15 C3). El abandono a mitad del video no se cuenta
/// aparte: es `accepted − completed − unfilled`.
public enum OfferStage: String, Codable, Sendable, CaseIterable {
    /// El botón quedó ofreciendo, con video listo.
    case shown
    /// Primer toque.
    case accepted
    /// Premio ganado.
    case completed
    /// Tocó y no hubo video.
    case unfilled
    /// La oferta se fue de la pantalla mostrada y sin aceptar («No, gracias», cerrar, irse).
    case dismissed
}

/// Cómo convierte cada oferta con video, por lugar (E15 C3). Vive en el save como
/// `meta.offerFunnel`; es medición pura: ningún cálculo de economía ni de ritmo lo lee.
///
/// La clave es el `site`: el identificador de accesibilidad del botón de video (estable y único
/// por fila del mapa de ubicaciones), p. ej. `ads.watch.double_earnings`, `offline.x2` o los
/// `double.*` del paso 2. Cualquier `String` vale; lo único que se limita es cuántas hay.
public struct OfferFunnel: Codable, Sendable, Equatable {
    /// Cuántos lugares distintos se cuentan por nombre. Del 65.º en adelante van a `overflowSite`:
    /// un id dinámico mal elegido no infla el save.
    public static let maxSites = 64
    public static let overflowSite = "_other"

    public struct Counts: Codable, Sendable, Equatable {
        public internal(set) var shown: Int
        public internal(set) var accepted: Int
        public internal(set) var completed: Int
        public internal(set) var unfilled: Int
        public internal(set) var dismissed: Int

        public static let zero = Counts(shown: 0, accepted: 0, completed: 0, unfilled: 0, dismissed: 0)

        public init(shown: Int, accepted: Int, completed: Int, unfilled: Int, dismissed: Int) {
            self.shown = shown
            self.accepted = accepted
            self.completed = completed
            self.unfilled = unfilled
            self.dismissed = dismissed
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            shown = try container.decodeIfPresent(Int.self, forKey: .shown) ?? 0
            accepted = try container.decodeIfPresent(Int.self, forKey: .accepted) ?? 0
            completed = try container.decodeIfPresent(Int.self, forKey: .completed) ?? 0
            unfilled = try container.decodeIfPresent(Int.self, forKey: .unfilled) ?? 0
            dismissed = try container.decodeIfPresent(Int.self, forKey: .dismissed) ?? 0
        }

        public subscript(stage: OfferStage) -> Int {
            get {
                switch stage {
                case .shown: shown
                case .accepted: accepted
                case .completed: completed
                case .unfilled: unfilled
                case .dismissed: dismissed
                }
            }
            set {
                switch stage {
                case .shown: shown = newValue
                case .accepted: accepted = newValue
                case .completed: completed = newValue
                case .unfilled: unfilled = newValue
                case .dismissed: dismissed = newValue
                }
            }
        }

        /// Aceptó y no terminó ni se quedó sin video: se fue a mitad del video.
        public var abandoned: Int {
            max(0, accepted - completed - unfilled)
        }

        static func maxEach(_ lhs: Counts, _ rhs: Counts) -> Counts {
            var merged = lhs
            for stage in OfferStage.allCases {
                merged[stage] = Swift.max(lhs[stage], rhs[stage])
            }
            return merged
        }
    }

    public internal(set) var sites: [String: Counts]

    public static let empty = OfferFunnel(sites: [:])

    public init(sites: [String: Counts]) {
        self.sites = sites
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sites = try container.decodeIfPresent([String: Counts].self, forKey: .sites) ?? [:]
    }

    public func counts(site: String) -> Counts {
        sites[site] ?? .zero
    }

    public mutating func record(_ stage: OfferStage, site: String) {
        let key = sites[site] != nil || namedSiteCount < Self.maxSites ? site : Self.overflowSite
        var counts = sites[key] ?? .zero
        counts[stage] += 1
        sites[key] = counts
    }

    private var namedSiteCount: Int {
        sites.keys.filter { $0 != Self.overflowSite }.count
    }

    /// Dos devices: el máximo de cada contador, lugar por lugar (son monótonos, como `stats`).
    /// Si la unión pasa el tope, los lugares que sobran —en orden alfabético, para que dé lo mismo
    /// de qué lado se resuelva— se suman a `overflowSite`.
    public static func resolve(_ lhs: OfferFunnel, _ rhs: OfferFunnel) -> OfferFunnel {
        var merged: [String: Counts] = [:]
        for key in Set(lhs.sites.keys).union(rhs.sites.keys) {
            merged[key] = Counts.maxEach(lhs.counts(site: key), rhs.counts(site: key))
        }
        let named = merged.keys.filter { $0 != overflowSite }.sorted()
        if named.count > maxSites {
            var overflow = merged[overflowSite] ?? .zero
            for key in named.dropFirst(maxSites) {
                let counts = merged.removeValue(forKey: key) ?? .zero
                for stage in OfferStage.allCases { overflow[stage] += counts[stage] }
            }
            merged[overflowSite] = overflow
        }
        return OfferFunnel(sites: merged)
    }
}
