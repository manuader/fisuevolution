import Foundation

/// Lo que el evento le pide al tablero. NO se aplica acá: la app lo planea por el
/// embudo `BoardChange` (E1) y la escena lo reproduce a la vista.
public enum EventBoardIntent: Sendable, Equatable {
    case evolveBestUnit
    case grantUnit(typeId: String)
}

public struct EventApplication: Sendable, Equatable {
    public let modifiers: [ActiveModifier]
    public let coinsSeconds: Double
    public let boardIntent: EventBoardIntent?
    public let calledScript: String?
    public let scene: EventCatalog.Scene?
}

/// Un evento con algo corriendo: lo que dibuja su chip.
public struct RunningEvent: Sendable, Equatable, Identifiable {
    public let id: String
    public let polarity: EventCatalog.Polarity
    public let expiresAt: TimeInterval
    public let presenterId: String
    public let scene: EventCatalog.Scene?
}

public enum EventPlanner {
    public static func apply(
        _ event: EventCatalog.Event,
        state: PlayerState,
        tiers: TierRepository,
        now: TimeInterval
    ) -> EventApplication {
        var modifiers: [ActiveModifier] = []
        var coinsSeconds = 0.0
        var intent: EventBoardIntent?
        var called: String?
        for effect in event.effects {
            switch effect {
            case let .modifier(modifierEffect, magnitude):
                modifiers.append(ActiveModifier(
                    effect: modifierEffect, magnitude: magnitude,
                    expiresAt: now + event.durationSeconds, sourceKey: event.sourceKey
                ))
            case .coinsSeconds(let seconds):
                coinsSeconds += seconds
            case .evolveBestUnit:
                intent = .evolveBestUnit
            case .grantUnit(let below):
                intent = grantedUnitType(tiersBelowFrontier: below, state: state, tiers: tiers).map { .grantUnit(typeId: $0.id) }
            case .callVisitor(let script):
                called = script
            }
        }
        return EventApplication(modifiers: modifiers, coinsSeconds: coinsSeconds, boardIntent: intent,
                                calledScript: called, scene: event.scene)
    }

    /// El que regala el Blanqueo: tantos tiers abajo de tu frontera, respetando la
    /// carrera elegida (la misma regla que la v1 y que E1 T11).
    public static func grantedUnitType(tiersBelowFrontier: Int, state: PlayerState, tiers: TierRepository) -> CharacterType? {
        let tier = max(1, state.run.maxTierReached - tiersBelowFrontier)
        return tiers.concreteTypes.first { candidate in
            candidate.tier == tier && (state.run.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        } ?? tiers.concreteTypes.first { $0.tier == tier }
    }

    /// Los modificadores que quedan después de salir por `escape`.
    public static func escape(
        _ escape: EventCatalog.Escape,
        of event: EventCatalog.Event,
        from modifiers: [ActiveModifier]
    ) -> [ActiveModifier] {
        modifiers.filter { modifier in
            guard modifier.sourceKey == event.sourceKey else { return true }
            guard let removes = escape.removes else { return false }
            return !removes.contains(modifier.effect)
        }
    }

    /// La Obra social corta los negativos en curso. Los mixtos se quedan: tienen
    /// su parte buena.
    public static func cutNegatives(_ modifiers: [ActiveModifier], catalog: EventCatalog) -> [ActiveModifier] {
        let negative = Set(catalog.events.filter { $0.polarity == .negative }.map(\.sourceKey))
        return modifiers.filter { !negative.contains($0.sourceKey) }
    }

    /// Uno por evento con algún modificador vivo, el que vence primero adelante.
    public static func running(_ modifiers: [ActiveModifier], catalog: EventCatalog, now: TimeInterval) -> [RunningEvent] {
        catalog.events.compactMap { event -> RunningEvent? in
            let live = modifiers.filter { $0.sourceKey == event.sourceKey && $0.isActive(at: now) }
            guard let expiresAt = live.map(\.expiresAt).max() else { return nil }
            return RunningEvent(id: event.id, polarity: event.polarity, expiresAt: expiresAt,
                                presenterId: event.presenters.first ?? "", scene: event.scene)
        }
        .sorted { $0.expiresAt < $1.expiresAt }
    }

    /// Una velita más en el Apagón: el multiplicador de ingresos del evento sube
    /// `candleStep`, hasta ×1. `nil` si no hay apagón vivo o ya no hay qué prender.
    public static func lightCandle(_ modifiers: [ActiveModifier], event: EventCatalog.Event, now: TimeInterval) -> [ActiveModifier]? {
        guard let step = event.candleStep,
              let index = modifiers.firstIndex(where: {
                  $0.sourceKey == event.sourceKey && $0.effect == .incomeMultiplier && $0.isActive(at: now)
              }),
              modifiers[index].magnitude < 1
        else { return nil }
        let old = modifiers[index]
        var result = modifiers
        result[index] = ActiveModifier(id: old.id, effect: old.effect, magnitude: min(1, old.magnitude + step),
                                       expiresAt: old.expiresAt, sourceKey: old.sourceKey)
        return result
    }
}
