import Foundation

/// El vocabulario único de premios de la 2.0 (PLAN-v2, "Cimientos compartidos"):
/// visitantes, eventos, ruleta, colchón, tienda, ofertas y escapes dicen QUÉ dan
/// con esto, y la app lo entrega en un solo punto (`GameState.grant`).
///
/// En los JSON es un objeto con `kind` y los campos de ese tipo:
/// `{"kind": "coinsSeconds", "seconds": 900}`,
/// `{"kind": "modifier", "effect": "incomeMultiplier", "magnitude": 1.5, "seconds": 600}`.
public enum RewardSpec: Sendable, Equatable, Hashable {
    /// Segundos de producción real (el `S(n)` del Anexo A). Se cotizan al cobrar,
    /// o al llegar el visitante (`VisitPlanner`).
    case coinsSeconds(Double)
    case oro(Int)
    /// Paquetes de la Aduana. Los entrega E5.
    case package(Int)
    case skinChest(Int)
    case modifier(effect: ActiveModifier.Effect, magnitude: Double, seconds: Double)
    case clearBoostCooldowns
    /// Toques automáticos. Los entrega E6.
    case autoTap(perSecond: Double, seconds: Double)
    case nextOfflineMultiplier(Double)
    case nextDailyMultiplier(Double)
    /// Giros de la ruleta. Los entrega E5.
    case wheelSpin(Int)
    /// Lugares extra por piso. Los entrega E6.
    case extraSlots(Int)
    case eventImmunity(seconds: Double)

    public enum Kind: String, CaseIterable, Sendable, Codable {
        case coinsSeconds, oro, package, skinChest, modifier, clearBoostCooldowns, autoTap
        case nextOfflineMultiplier, nextDailyMultiplier, wheelSpin, extraSlots, eventImmunity
    }

    public var kind: Kind {
        switch self {
        case .coinsSeconds: .coinsSeconds
        case .oro: .oro
        case .package: .package
        case .skinChest: .skinChest
        case .modifier: .modifier
        case .clearBoostCooldowns: .clearBoostCooldowns
        case .autoTap: .autoTap
        case .nextOfflineMultiplier: .nextOfflineMultiplier
        case .nextDailyMultiplier: .nextDailyMultiplier
        case .wheelSpin: .wheelSpin
        case .extraSlots: .extraSlots
        case .eventImmunity: .eventImmunity
        }
    }

    /// El "×2 con video" (`multiplier` 2). Lo contable se multiplica; un efecto con
    /// duración dura N veces más, no pega más fuerte (un −30 % al doble sería un
    /// −60 % que nadie diseñó); lo que no es una cantidad queda igual.
    public func scaled(by multiplier: Int) -> RewardSpec {
        let factor = Double(multiplier)
        switch self {
        case .coinsSeconds(let seconds): return .coinsSeconds(seconds * factor)
        case .oro(let amount): return .oro(amount * multiplier)
        case .package(let count): return .package(count * multiplier)
        case .skinChest(let count): return .skinChest(count * multiplier)
        case let .modifier(effect, magnitude, seconds):
            return .modifier(effect: effect, magnitude: magnitude, seconds: seconds * factor)
        case let .autoTap(perSecond, seconds): return .autoTap(perSecond: perSecond, seconds: seconds * factor)
        case .wheelSpin(let count): return .wheelSpin(count * multiplier)
        case .eventImmunity(let seconds): return .eventImmunity(seconds: seconds * factor)
        case .clearBoostCooldowns, .nextOfflineMultiplier, .nextDailyMultiplier, .extraSlots: return self
        }
    }

    public enum ValidationError: Error, Equatable {
        case notPositive(Kind)
        /// Un premio de ×1 no da nada: es un error de dato, no un premio.
        case neutralModifier
    }

    public func validate() throws {
        switch self {
        case .coinsSeconds(let seconds), .eventImmunity(seconds: let seconds):
            guard seconds > 0 else { throw ValidationError.notPositive(kind) }
        case .oro(let count), .package(let count), .skinChest(let count), .wheelSpin(let count), .extraSlots(let count):
            guard count > 0 else { throw ValidationError.notPositive(kind) }
        case let .modifier(_, magnitude, seconds):
            guard seconds > 0, magnitude > 0 else { throw ValidationError.notPositive(kind) }
            guard magnitude != 1 else { throw ValidationError.neutralModifier }
        case let .autoTap(perSecond, seconds):
            guard perSecond > 0, seconds > 0 else { throw ValidationError.notPositive(kind) }
        case .nextOfflineMultiplier(let multiplier), .nextDailyMultiplier(let multiplier):
            guard multiplier > 1 else { throw ValidationError.notPositive(kind) }
        case .clearBoostCooldowns:
            break
        }
    }
}

extension RewardSpec: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, seconds, amount, count, effect, magnitude, perSecond, multiplier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .coinsSeconds: self = .coinsSeconds(try container.decode(Double.self, forKey: .seconds))
        case .oro: self = .oro(try container.decode(Int.self, forKey: .amount))
        case .package: self = .package(try container.decode(Int.self, forKey: .count))
        case .skinChest: self = .skinChest(try container.decode(Int.self, forKey: .count))
        case .modifier:
            self = .modifier(
                effect: try container.decode(ActiveModifier.Effect.self, forKey: .effect),
                magnitude: try container.decode(Double.self, forKey: .magnitude),
                seconds: try container.decode(Double.self, forKey: .seconds)
            )
        case .clearBoostCooldowns: self = .clearBoostCooldowns
        case .autoTap:
            self = .autoTap(
                perSecond: try container.decode(Double.self, forKey: .perSecond),
                seconds: try container.decode(Double.self, forKey: .seconds)
            )
        case .nextOfflineMultiplier: self = .nextOfflineMultiplier(try container.decode(Double.self, forKey: .multiplier))
        case .nextDailyMultiplier: self = .nextDailyMultiplier(try container.decode(Double.self, forKey: .multiplier))
        case .wheelSpin: self = .wheelSpin(try container.decode(Int.self, forKey: .count))
        case .extraSlots: self = .extraSlots(try container.decode(Int.self, forKey: .count))
        case .eventImmunity: self = .eventImmunity(seconds: try container.decode(Double.self, forKey: .seconds))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .coinsSeconds(let seconds), .eventImmunity(seconds: let seconds):
            try container.encode(seconds, forKey: .seconds)
        case .oro(let amount):
            try container.encode(amount, forKey: .amount)
        case .package(let count), .skinChest(let count), .wheelSpin(let count), .extraSlots(let count):
            try container.encode(count, forKey: .count)
        case let .modifier(effect, magnitude, seconds):
            try container.encode(effect, forKey: .effect)
            try container.encode(magnitude, forKey: .magnitude)
            try container.encode(seconds, forKey: .seconds)
        case .clearBoostCooldowns:
            break
        case let .autoTap(perSecond, seconds):
            try container.encode(perSecond, forKey: .perSecond)
            try container.encode(seconds, forKey: .seconds)
        case .nextOfflineMultiplier(let multiplier), .nextDailyMultiplier(let multiplier):
            try container.encode(multiplier, forKey: .multiplier)
        }
    }
}
