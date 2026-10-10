import Foundation

/// `events.json` schema 2 (PLAN-v2 E4): cada evento tiene efectos compuestos, una
/// polaridad, quiénes lo presentan y por dónde se sale.
public struct EventCatalog: Codable, Sendable, Equatable {
    public enum Polarity: String, Codable, Sendable {
        case positive, negative, mixed
    }

    /// Lo que el evento le hace a la escena, además de sus números (E4b).
    public enum Scene: String, Codable, Sendable, CaseIterable {
        case blackout, champions, sale
    }

    public enum Effect: Sendable, Equatable {
        /// Dura lo que dura el evento.
        case modifier(effect: ActiveModifier.Effect, magnitude: Double)
        /// Segundos de producción real, al arrancar.
        case coinsSeconds(Double)
        /// La mejor unidad que puede crecer sola sube un tier (Startup).
        case evolveBestUnit
        /// Una unidad `tiersBelowFrontier` abajo de tu frontera (Blanqueo).
        case grantUnit(tiersBelowFrontier: Int)
        /// Un guion que entra por el evento (Cepo → el blue del Arbolito).
        case callVisitor(script: String)
    }

    public struct Escape: Codable, Sendable, Equatable {
        public enum Kind: String, Codable, Sendable {
            case video, fee, free
        }

        public let kind: Kind
        /// La cuota, en segundos de producción (`fee`).
        public let feeSeconds: Double?
        /// Qué efectos saca. `nil` = todos (la Hiperinflación saca sólo el ×2 de contratar).
        public let removes: [ActiveModifier.Effect]?

        public init(kind: Kind, feeSeconds: Double?, removes: [ActiveModifier.Effect]?) {
            self.kind = kind
            self.feeSeconds = feeSeconds
            self.removes = removes
        }
    }

    public struct Event: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let polarity: Polarity
        public let durationSeconds: Double
        public let weight: Int
        public let minTier: Int
        public let cooldownSeconds: Double
        public let titleKey: String
        public let phraseKey: String
        /// Quiénes lo pueden anunciar (ids de `visitors.json`). El primero es su cara en el chip.
        public let presenters: [String]
        public let effects: [Effect]
        public let escapes: [Escape]
        public let scene: Scene?
        /// Cuánto sube el multiplicador cada velita del Apagón (hasta ×1).
        public let candleStep: Double?

        public init(
            id: String, polarity: Polarity, durationSeconds: Double, weight: Int, minTier: Int,
            cooldownSeconds: Double, titleKey: String, phraseKey: String, presenters: [String],
            effects: [Effect], escapes: [Escape], scene: Scene?, candleStep: Double?
        ) {
            self.id = id
            self.polarity = polarity
            self.durationSeconds = durationSeconds
            self.weight = weight
            self.minTier = minTier
            self.cooldownSeconds = cooldownSeconds
            self.titleKey = titleKey
            self.phraseKey = phraseKey
            self.presenters = presenters
            self.effects = effects
            self.escapes = escapes
            self.scene = scene
            self.candleStep = candleStep
        }

        /// El origen de sus modificadores: así los encuentran el chip y las salidas.
        public var sourceKey: String { "event.\(id)" }

        public var modifierEffects: Set<ActiveModifier.Effect> {
            Set(effects.compactMap { effect in
                if case .modifier(let modifierEffect, _) = effect { return modifierEffect }
                return nil
            })
        }
    }

    public let schemaVersion: Int
    /// Segundos de juego antes del primero de una partida (o de un save anterior a E4).
    public let firstEventAfterSeconds: Double
    public let intervalSeconds: Double
    public let intervalJitterSeconds: Double
    /// Al volver a la app, un evento vencido espera esto (E1 T8).
    public let resumeGraceSeconds: Double
    /// Un sorteo sin candidatos reintenta a este plazo (E1 T11).
    public let retryWhenNoneApplicableSeconds: Double
    public let events: [Event]

    public init(
        schemaVersion: Int, firstEventAfterSeconds: Double, intervalSeconds: Double,
        intervalJitterSeconds: Double, resumeGraceSeconds: Double,
        retryWhenNoneApplicableSeconds: Double, events: [Event]
    ) {
        self.schemaVersion = schemaVersion
        self.firstEventAfterSeconds = firstEventAfterSeconds
        self.intervalSeconds = intervalSeconds
        self.intervalJitterSeconds = intervalJitterSeconds
        self.resumeGraceSeconds = resumeGraceSeconds
        self.retryWhenNoneApplicableSeconds = retryWhenNoneApplicableSeconds
        self.events = events
    }

    public func event(id: String) -> Event? {
        events.first { $0.id == id }
    }

    public enum ValidationError: Error, Equatable {
        case unsupportedSchema(Int)
        case duplicateId(String)
        case invalid(id: String, reason: String)
    }

    /// Un evento mal declarado no rompe nada visible: no sale nunca, o sale sin
    /// salida, y nadie se entera hasta que un jugador lo reporta.
    public func validate(visitorIDs: Set<String>, scriptIDs: Set<String>) throws {
        guard schemaVersion == 2 else { throw ValidationError.unsupportedSchema(schemaVersion) }
        guard intervalSeconds > 0, intervalJitterSeconds >= 0, firstEventAfterSeconds >= 0,
              resumeGraceSeconds >= 0, retryWhenNoneApplicableSeconds > 0
        else { throw ValidationError.invalid(id: "catalog", reason: "los relojes tienen que ser positivos") }
        var seen: Set<String> = []
        for event in events {
            func fail(_ reason: String) -> ValidationError { .invalid(id: event.id, reason: reason) }
            guard seen.insert(event.id).inserted else { throw ValidationError.duplicateId(event.id) }
            guard event.weight > 0, event.minTier >= 1, event.cooldownSeconds >= 0 else { throw fail("peso, tier o cooldown") }
            guard !event.titleKey.isEmpty, !event.phraseKey.isEmpty else { throw fail("sin textos") }
            guard !event.presenters.isEmpty, event.presenters.allSatisfy(visitorIDs.contains) else {
                throw fail("presentador desconocido")
            }
            guard !event.effects.isEmpty else { throw fail("sin efectos") }
            if !event.modifierEffects.isEmpty, event.durationSeconds <= 0 { throw fail("un modificador necesita duración") }
            if event.polarity != .positive, !event.escapes.contains(where: { $0.kind == .video }) {
                throw fail("un negativo siempre tiene salida por video")
            }
            for escape in event.escapes {
                if escape.kind == .fee, (escape.feeSeconds ?? 0) <= 0 { throw fail("cuota sin monto") }
                if let removes = escape.removes, !Set(removes).isSubset(of: event.modifierEffects) {
                    throw fail("la salida saca un efecto que el evento no tiene")
                }
            }
            for case .callVisitor(let script) in event.effects where !scriptIDs.contains(script) {
                throw fail("llama a un guion que no existe: \(script)")
            }
            if event.scene == .blackout, (event.candleStep ?? 0) <= 0 { throw fail("el apagón necesita candleStep") }
        }
    }
}

extension EventCatalog.Effect: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, effect, magnitude, seconds, tiersBelowFrontier, script
    }

    private enum Kind: String, Codable {
        case modifier, coinsSeconds, evolveBestUnit, grantUnit, callVisitor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .modifier:
            self = .modifier(
                effect: try container.decode(ActiveModifier.Effect.self, forKey: .effect),
                magnitude: try container.decode(Double.self, forKey: .magnitude)
            )
        case .coinsSeconds: self = .coinsSeconds(try container.decode(Double.self, forKey: .seconds))
        case .evolveBestUnit: self = .evolveBestUnit
        case .grantUnit: self = .grantUnit(tiersBelowFrontier: try container.decode(Int.self, forKey: .tiersBelowFrontier))
        case .callVisitor: self = .callVisitor(script: try container.decode(String.self, forKey: .script))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .modifier(effect, magnitude):
            try container.encode(Kind.modifier, forKey: .kind)
            try container.encode(effect, forKey: .effect)
            try container.encode(magnitude, forKey: .magnitude)
        case .coinsSeconds(let seconds):
            try container.encode(Kind.coinsSeconds, forKey: .kind)
            try container.encode(seconds, forKey: .seconds)
        case .evolveBestUnit:
            try container.encode(Kind.evolveBestUnit, forKey: .kind)
        case .grantUnit(let below):
            try container.encode(Kind.grantUnit, forKey: .kind)
            try container.encode(below, forKey: .tiersBelowFrontier)
        case .callVisitor(let script):
            try container.encode(Kind.callVisitor, forKey: .kind)
            try container.encode(script, forKey: .script)
        }
    }
}
