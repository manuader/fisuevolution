import EconomyKit
import Foundation

/// Un bonus temporal corriendo, listo para dibujar en el HUD.
///
/// Boosts, videos y el premio del Abogado son la misma cosa para el jugador
/// —"tengo un ×3 corriendo, le quedan 42 s"— y también para el código: los tres
/// son `ActiveModifier` con vencimiento. Los de un evento se juntan en UN chip con
/// la cara de quien lo anunció, y ése sí se toca: abre el popup del evento.
///
/// ⚠️ **No lleva el tiempo restante, y es a propósito.** Lleva `expiresAt` y
/// `totalDuration`, que son constantes mientras el bonus vive. Con el restante
/// adentro, esta proyección cambiaría una vez por segundo —y el aro, ocho—
/// invalidando SwiftUI sin parar mientras hubiera un boost activo. Así el array
/// sólo cambia cuando un bonus arranca o se muere. El tiempo lo cuenta la vista
/// con un timer propio (ver `ActiveBonusBar`).
struct ActiveBonus: Identifiable, Equatable {
    /// Con qué se dibuja. Los boosts tienen arte en el atlas UI; el video y el
    /// premio de carrera, un glifo del sistema; los eventos y las visitas, la cara
    /// de quien los trajo.
    enum Icon: Equatable {
        case art(String)
        case symbol(String)
        case face(String)
    }

    let id: UUID
    let effect: ActiveModifier.Effect
    let icon: Icon
    /// "×3", "−30%". Sale del mismo formateador que el menú de Bonus. Un evento
    /// con dos efectos los junta: "+100% · ×3".
    let effectText: String
    let expiresAt: TimeInterval
    /// Cuánto duraba en total, para poder dibujar el aro que se vacía. Nil
    /// cuando el `sourceKey` no está en el catálogo: ahí el aro va lleno y el
    /// chip se muestra igual. Un bonus que corre y no se ve es peor que un aro
    /// sin vaciarse.
    let totalDuration: TimeInterval?
    /// El evento de este chip: lo vuelve un botón que abre su popup.
    var eventId: String?
    var polarity: EventCatalog.Polarity?
}

/// Lo que un chip de evento necesita y el modificador no sabe: la cara de quien
/// lo anunció, su polaridad y cuánto dura.
struct EventChipSource: Equatable {
    let presenterId: String
    let polarity: EventCatalog.Polarity
    let duration: TimeInterval
}

/// Lo que el `sourceKey` de un `ActiveModifier` no dice: con qué arte se dibuja
/// y cuánto duraba en total. Lo arma `GameState` desde los configs.
struct BonusSource: Equatable {
    let icon: ActiveBonus.Icon
    let duration: TimeInterval
}

/// Traduce los modificadores vivos a chips. Puro y sin SwiftUI, así el test
/// prueba la regla y no una copia de la regla.
enum ActiveBonusBuilder {
    /// Los modificadores de un evento.
    private static let eventPrefix = "event."

    /// Glifo para un origen sin arte propio.
    private static let fallbackSymbol = "bolt.fill"

    static func bonuses(
        from modifiers: [ActiveModifier],
        catalog: [String: BonusSource],
        events: [String: EventChipSource] = [:],
        now: TimeInterval
    ) -> [ActiveBonus] {
        let live = modifiers.filter { modifier in
            modifier.isActive(at: now)
                // Los permanentes no son un contador: la Milanesa sube la
                // eficiencia offline para siempre y no tiene nada que contar.
                && modifier.expiresAt.isFinite
        }
        let plain = live.filter { !$0.sourceKey.hasPrefix(eventPrefix) }.map { modifier in
            let source = catalog[modifier.sourceKey]
            return ActiveBonus(
                id: modifier.id,
                effect: modifier.effect,
                icon: source?.icon ?? .symbol(fallbackSymbol),
                effectText: effectText(for: modifier),
                expiresAt: modifier.expiresAt,
                totalDuration: source?.duration
            )
        }
        // Un evento es UN chip aunque traiga dos efectos (la Hiperinflación). Sin
        // su fuente no hay cara que mostrar y no entra.
        let byEvent = Dictionary(grouping: live.filter { $0.sourceKey.hasPrefix(eventPrefix) }, by: \.sourceKey)
        let eventChips = byEvent.compactMap { sourceKey, group -> ActiveBonus? in
            guard let source = events[sourceKey], let first = group.first else { return nil }
            return ActiveBonus(
                id: first.id,
                effect: first.effect,
                icon: .face(source.presenterId),
                effectText: group.map(effectText(for:)).joined(separator: " · "),
                expiresAt: group.map(\.expiresAt).max() ?? first.expiresAt,
                totalDuration: source.duration,
                eventId: String(sourceKey.dropFirst(eventPrefix.count)),
                polarity: source.polarity
            )
        }
        // Primero el que vence, que es el que urge; el id desempata para que el
        // orden no baile entre dos lecturas.
        return (plain + eventChips).sorted {
            $0.expiresAt != $1.expiresAt ? $0.expiresAt < $1.expiresAt : $0.id.uuidString < $1.id.uuidString
        }
    }

    /// El MISMO número que muestra el menú de Bonus, por el mismo camino: la
    /// magnitud 0,7 del mate es un factor de costo y se lee **−30%**, no ×0,7.
    /// Los efectos de multiplicador mapean 1:1 contra `BoostsConfig.EffectType`.
    private static func effectText(for modifier: ActiveModifier) -> String {
        let boostEffect: BoostsConfig.EffectType
        switch modifier.effect {
        case .incomeMultiplier, .passiveMultiplier: boostEffect = .incomeMultiplier
        case .tapMultiplier: boostEffect = .tapMultiplier
        case .spawnCostMultiplier: boostEffect = .spawnCostMultiplier
        case .spendingFrozen: return String(localized: "bonus.chip.spending_frozen")
        case .eventImmunity: return String(localized: "bonus.chip.immunity")
        case .freeHire: return String(localized: "bonus.chip.free_hire")
        case .packageRateMultiplier:
            let value = EffectFormatter.text(
                EffectDescriptor.amount(forBoost: .incomeMultiplier, magnitude: modifier.magnitude)
            )
            return String(localized: "bonus.chip.packages \(value)")
        case .autoTapPerSecond:
            return String(localized: "bonus.chip.autotap \(Self.autoTapRateText(modifier.magnitude))")
        }
        return EffectFormatter.text(
            EffectDescriptor.amount(forBoost: boostEffect, magnitude: modifier.magnitude)
        )
    }

    /// "5" toques por segundo: sin decimales salvo que el dato los traiga. Lo usa
    /// también `EffectContractTests` para leer el chip con la misma vara.
    static func autoTapRateText(_ perSecond: Double) -> String {
        perSecond.formatted(.number.precision(.fractionLength(0...1)))
    }
}
