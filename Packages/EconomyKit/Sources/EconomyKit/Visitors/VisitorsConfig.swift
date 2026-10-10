import Foundation

/// `visitors.json` (PLAN-v2 E4, Anexos A y B): quiénes visitan y qué guion trae
/// cada uno. El id de un visitante ES su id de arte (`npc_<nombre>` para los 8
/// nuevos, `sp_<id>` para los 10 especiales): con él se buscan las poses en el
/// manifest y el loop de retrato en `loops_manifest.json`.
public struct VisitorsConfig: Codable, Sendable, Equatable {
    public struct Visitor: Codable, Sendable, Equatable, Identifiable {
        public enum Kind: String, Codable, Sendable {
            case npc, special
        }

        public let id: String
        public let kind: Kind
        public let nameKey: String
        /// Mientras no hay arte: un SF Symbol sobre un disco de este color de la paleta.
        public let fallbackSymbol: String
        public let fallbackTint: String

        public init(id: String, kind: Kind, nameKey: String, fallbackSymbol: String, fallbackTint: String) {
            self.id = id
            self.kind = kind
            self.nameKey = nameKey
            self.fallbackSymbol = fallbackSymbol
            self.fallbackTint = fallbackTint
        }
    }

    public enum Lane: String, Codable, Sendable {
        case main, vendor
    }

    /// A quién elige un guion que se lleva, compra o arresta gente. Siempre un
    /// DUPLICADO: nunca el último de su tipo.
    public enum UnitPick: String, Codable, Sendable {
        case lowestDuplicate, highestDuplicate
    }

    public struct VendorCard: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let nameKey: String
        public let iconKey: String
        public let reward: RewardSpec

        public init(id: String, nameKey: String, iconKey: String, reward: RewardSpec) {
            self.id = id
            self.nameKey = nameKey
            self.iconKey = iconKey
            self.reward = reward
        }
    }

    public enum Mechanic: Sendable, Equatable {
        /// Da algo. Con `videoDoubles`, un video lo duplica (`RewardSpec.scaled`).
        case gift(rewards: [RewardSpec], videoDoubles: Bool)
        /// Se lleva un duplicado: pagás la fianza (× lo que cuesta reponerlo) o lo
        /// dejás ir y te indemnizan (× reponerlo, siempre > 1).
        case arrest(pick: UnitPick, bailMultiplier: Double, releaseMultiplier: Double)
        /// Multa de `seconds` de producción con tope en una fracción de la caja.
        /// Pagarla da `stamp`; un video la perdona; ignorarla no cobra nada.
        case fine(seconds: Double, capFraction: Double, stamp: RewardSpec)
        /// ORO por plata. `dailyOroCap` nil = sin tope (el blue del Cepo).
        case exchange(costSeconds: Double, oro: Int, dailyOroCap: Int?)
        /// Compra un duplicado hasta `tiersBelowFrontier` abajo de tu frontera.
        case sale(pick: UnitPick, priceMultiplier: Double, tiersBelowFrontier: Int)
        /// Se lleva `count` y deja `rewards`, con la plata llevada a por lo menos
        /// `minValueMultiplier` × lo que cuesta reponerlos.
        case take(pick: UnitPick, count: Int, rewards: [RewardSpec], minValueMultiplier: Double)
        /// `taps` toques en `windowSeconds`. Si no llegás, no pasa nada.
        case challenge(taps: Int, windowSeconds: Double, rewards: [RewardSpec], videoDoubles: Bool)
        /// Una carta por video (el Vendedor Ambulante).
        case vendor(cards: [VendorCard])
        /// Te adelanta el próximo evento y deja `rewards` (la Vecina).
        case gossip(rewards: [RewardSpec])

        /// Todo lo que el guion puede dar: si uno no se puede entregar todavía,
        /// el guion no se ofrece.
        public var rewards: [RewardSpec] {
            switch self {
            case .gift(let rewards, _), .take(_, _, let rewards, _), .challenge(_, _, let rewards, _), .gossip(let rewards):
                rewards
            case .fine(_, _, let stamp):
                [stamp]
            case .exchange(_, let oro, _):
                [.oro(oro)]
            case .vendor(let cards):
                cards.map(\.reward)
            case .arrest, .sale:
                []
            }
        }
    }

    public struct Script: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let visitor: String
        public let lane: Lane
        public let weight: Int
        public let minTier: Int
        public let dailyCap: Int
        /// Sólo entra si lo llama un evento (el blue del Arbolito, en el Cepo).
        public let eventOnly: Bool
        public let mechanic: Mechanic

        public init(
            id: String, visitor: String, lane: Lane, weight: Int, minTier: Int,
            dailyCap: Int, eventOnly: Bool, mechanic: Mechanic
        ) {
            self.id = id
            self.visitor = visitor
            self.lane = lane
            self.weight = weight
            self.minTier = minTier
            self.dailyCap = dailyCap
            self.eventOnly = eventOnly
            self.mechanic = mechanic
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            visitor = try container.decode(String.self, forKey: .visitor)
            lane = try container.decodeIfPresent(Lane.self, forKey: .lane) ?? .main
            weight = try container.decode(Int.self, forKey: .weight)
            minTier = try container.decode(Int.self, forKey: .minTier)
            dailyCap = try container.decode(Int.self, forKey: .dailyCap)
            eventOnly = try container.decodeIfPresent(Bool.self, forKey: .eventOnly) ?? false
            mechanic = try container.decode(Mechanic.self, forKey: .mechanic)
        }

        /// Las claves van por convención (Anexo A): una sola fuente para el globo y el popup.
        public var bubbleKey: String { "visit.\(id).bubble" }
        public var askKey: String { "visit.\(id).ask" }
    }

    public let schemaVersion: Int
    public let firstVisitAfterSeconds: Double
    public let intervalMinSeconds: Double
    public let intervalMaxSeconds: Double
    public let vendorIntervalSeconds: Double
    public let vendorJitterSeconds: Double
    public let retryWhenNoneSeconds: Double
    /// Lo que espera alguien en escena, contado sólo en un momento calmo.
    public let patienceSeconds: Double
    /// Lo que se queda el presentador de un evento hablando antes de irse.
    public let presenterTalkSeconds: Double
    /// Cuántos guiones recientes no vuelven si hay otro para mandar.
    public let antiRepeat: Int
    /// Escala de todos los `coinsSeconds` de los guiones: la palanca de E2b.
    public let coinsSecondsScale: Double
    public let visitors: [Visitor]
    public let scripts: [Script]

    public init(
        schemaVersion: Int, firstVisitAfterSeconds: Double, intervalMinSeconds: Double,
        intervalMaxSeconds: Double, vendorIntervalSeconds: Double, vendorJitterSeconds: Double,
        retryWhenNoneSeconds: Double, patienceSeconds: Double, presenterTalkSeconds: Double,
        antiRepeat: Int, coinsSecondsScale: Double, visitors: [Visitor], scripts: [Script]
    ) {
        self.schemaVersion = schemaVersion
        self.firstVisitAfterSeconds = firstVisitAfterSeconds
        self.intervalMinSeconds = intervalMinSeconds
        self.intervalMaxSeconds = intervalMaxSeconds
        self.vendorIntervalSeconds = vendorIntervalSeconds
        self.vendorJitterSeconds = vendorJitterSeconds
        self.retryWhenNoneSeconds = retryWhenNoneSeconds
        self.patienceSeconds = patienceSeconds
        self.presenterTalkSeconds = presenterTalkSeconds
        self.antiRepeat = antiRepeat
        self.coinsSecondsScale = coinsSecondsScale
        self.visitors = visitors
        self.scripts = scripts
    }

    public func visitor(id: String) -> Visitor? {
        visitors.first { $0.id == id }
    }

    public func script(id: String) -> Script? {
        scripts.first { $0.id == id }
    }

    public enum ValidationError: Error, Equatable {
        case unsupportedSchema(Int)
        case duplicateId(String)
        case invalid(id: String, reason: String)
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw ValidationError.unsupportedSchema(schemaVersion) }
        guard firstVisitAfterSeconds >= 0, intervalMinSeconds > 0, intervalMaxSeconds >= intervalMinSeconds,
              vendorJitterSeconds >= 0, vendorIntervalSeconds > vendorJitterSeconds, retryWhenNoneSeconds > 0,
              patienceSeconds > 0, presenterTalkSeconds > 0, antiRepeat >= 0, coinsSecondsScale > 0
        else { throw ValidationError.invalid(id: "config", reason: "relojes y escalas tienen que ser positivos") }

        var visitorIDs: Set<String> = []
        for visitor in visitors {
            guard visitorIDs.insert(visitor.id).inserted else { throw ValidationError.duplicateId(visitor.id) }
            let prefix = visitor.kind == .npc ? "npc_" : "sp_"
            guard visitor.id.hasPrefix(prefix) else {
                throw ValidationError.invalid(id: visitor.id, reason: "el id de arte es npc_<nombre> o sp_<id>")
            }
            guard !visitor.nameKey.isEmpty, !visitor.fallbackSymbol.isEmpty, !visitor.fallbackTint.isEmpty else {
                throw ValidationError.invalid(id: visitor.id, reason: "sin nombre o sin respaldo de arte")
            }
        }

        var scriptIDs: Set<String> = []
        for script in scripts {
            func fail(_ reason: String) -> ValidationError { .invalid(id: script.id, reason: reason) }
            guard scriptIDs.insert(script.id).inserted else { throw ValidationError.duplicateId(script.id) }
            guard visitorIDs.contains(script.visitor) else { throw fail("visitante desconocido") }
            guard script.weight > 0, script.minTier >= 1, script.dailyCap > 0 else { throw fail("peso, tier o tope") }
            let isVendor: Bool = if case .vendor = script.mechanic { true } else { false }
            guard isVendor == (script.lane == .vendor) else { throw fail("el vendedor, y sólo él, va por su carril") }
            for reward in script.mechanic.rewards {
                do { try reward.validate() } catch { throw fail("premio inválido: \(error)") }
            }
            switch script.mechanic {
            case .gift(let rewards, _), .gossip(let rewards):
                guard !rewards.isEmpty else { throw fail("sin premios") }
            case let .arrest(_, bail, release):
                guard bail > 0, release > 1 else { throw fail("el arresto indemniza más de lo que cuesta reponer") }
            case let .fine(seconds, capFraction, _):
                guard seconds > 0, capFraction > 0, capFraction <= 1 else { throw fail("multa") }
            case let .exchange(costSeconds, oro, dailyOroCap):
                guard costSeconds > 0, oro > 0, (dailyOroCap ?? 1) > 0 else { throw fail("cambio") }
            case let .sale(_, priceMultiplier, tiersBelowFrontier):
                guard priceMultiplier > 1, tiersBelowFrontier >= 0 else { throw fail("la compra paga más de lo que vale") }
            case let .take(_, count, rewards, minValueMultiplier):
                guard count >= 1, minValueMultiplier >= 1, !rewards.isEmpty else {
                    throw fail("se lleva gente y paga por lo menos lo que vale")
                }
            case let .challenge(taps, windowSeconds, rewards, _):
                guard taps > 0, windowSeconds > 0, !rewards.isEmpty else { throw fail("reto") }
            case .vendor(let cards):
                guard (1...3).contains(cards.count), Set(cards.map(\.id)).count == cards.count else {
                    throw fail("de una a tres cartas")
                }
            }
        }
    }
}

extension VisitorsConfig.Mechanic: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, rewards, videoDoubles, pick, bailMultiplier, releaseMultiplier, seconds, capFraction, stamp
        case costSeconds, oro, dailyOroCap, priceMultiplier, tiersBelowFrontier, count, minValueMultiplier
        case taps, windowSeconds, cards
    }

    private enum Kind: String, Codable {
        case gift, arrest, fine, exchange, sale, take, challenge, vendor, gossip
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .gift:
            self = .gift(rewards: try c.decode([RewardSpec].self, forKey: .rewards),
                         videoDoubles: try c.decodeIfPresent(Bool.self, forKey: .videoDoubles) ?? false)
        case .arrest:
            self = .arrest(pick: try c.decode(VisitorsConfig.UnitPick.self, forKey: .pick),
                           bailMultiplier: try c.decode(Double.self, forKey: .bailMultiplier),
                           releaseMultiplier: try c.decode(Double.self, forKey: .releaseMultiplier))
        case .fine:
            self = .fine(seconds: try c.decode(Double.self, forKey: .seconds),
                         capFraction: try c.decode(Double.self, forKey: .capFraction),
                         stamp: try c.decode(RewardSpec.self, forKey: .stamp))
        case .exchange:
            self = .exchange(costSeconds: try c.decode(Double.self, forKey: .costSeconds),
                             oro: try c.decode(Int.self, forKey: .oro),
                             dailyOroCap: try c.decodeIfPresent(Int.self, forKey: .dailyOroCap))
        case .sale:
            self = .sale(pick: try c.decode(VisitorsConfig.UnitPick.self, forKey: .pick),
                         priceMultiplier: try c.decode(Double.self, forKey: .priceMultiplier),
                         tiersBelowFrontier: try c.decode(Int.self, forKey: .tiersBelowFrontier))
        case .take:
            self = .take(pick: try c.decode(VisitorsConfig.UnitPick.self, forKey: .pick),
                         count: try c.decode(Int.self, forKey: .count),
                         rewards: try c.decode([RewardSpec].self, forKey: .rewards),
                         minValueMultiplier: try c.decode(Double.self, forKey: .minValueMultiplier))
        case .challenge:
            self = .challenge(taps: try c.decode(Int.self, forKey: .taps),
                              windowSeconds: try c.decode(Double.self, forKey: .windowSeconds),
                              rewards: try c.decode([RewardSpec].self, forKey: .rewards),
                              videoDoubles: try c.decodeIfPresent(Bool.self, forKey: .videoDoubles) ?? false)
        case .vendor:
            self = .vendor(cards: try c.decode([VisitorsConfig.VendorCard].self, forKey: .cards))
        case .gossip:
            self = .gossip(rewards: try c.decode([RewardSpec].self, forKey: .rewards))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .gift(rewards, videoDoubles):
            try c.encode(Kind.gift, forKey: .kind)
            try c.encode(rewards, forKey: .rewards)
            try c.encode(videoDoubles, forKey: .videoDoubles)
        case let .arrest(pick, bail, release):
            try c.encode(Kind.arrest, forKey: .kind)
            try c.encode(pick, forKey: .pick)
            try c.encode(bail, forKey: .bailMultiplier)
            try c.encode(release, forKey: .releaseMultiplier)
        case let .fine(seconds, capFraction, stamp):
            try c.encode(Kind.fine, forKey: .kind)
            try c.encode(seconds, forKey: .seconds)
            try c.encode(capFraction, forKey: .capFraction)
            try c.encode(stamp, forKey: .stamp)
        case let .exchange(costSeconds, oro, dailyOroCap):
            try c.encode(Kind.exchange, forKey: .kind)
            try c.encode(costSeconds, forKey: .costSeconds)
            try c.encode(oro, forKey: .oro)
            try c.encodeIfPresent(dailyOroCap, forKey: .dailyOroCap)
        case let .sale(pick, priceMultiplier, tiersBelowFrontier):
            try c.encode(Kind.sale, forKey: .kind)
            try c.encode(pick, forKey: .pick)
            try c.encode(priceMultiplier, forKey: .priceMultiplier)
            try c.encode(tiersBelowFrontier, forKey: .tiersBelowFrontier)
        case let .take(pick, count, rewards, minValueMultiplier):
            try c.encode(Kind.take, forKey: .kind)
            try c.encode(pick, forKey: .pick)
            try c.encode(count, forKey: .count)
            try c.encode(rewards, forKey: .rewards)
            try c.encode(minValueMultiplier, forKey: .minValueMultiplier)
        case let .challenge(taps, windowSeconds, rewards, videoDoubles):
            try c.encode(Kind.challenge, forKey: .kind)
            try c.encode(taps, forKey: .taps)
            try c.encode(windowSeconds, forKey: .windowSeconds)
            try c.encode(rewards, forKey: .rewards)
            try c.encode(videoDoubles, forKey: .videoDoubles)
        case .vendor(let cards):
            try c.encode(Kind.vendor, forKey: .kind)
            try c.encode(cards, forKey: .cards)
        case .gossip(let rewards):
            try c.encode(Kind.gossip, forKey: .kind)
            try c.encode(rewards, forKey: .rewards)
        }
    }
}
