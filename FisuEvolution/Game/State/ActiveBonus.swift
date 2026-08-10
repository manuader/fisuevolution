import EconomyKit
import Foundation

/// Un bonus temporal corriendo, listo para dibujar en el HUD.
///
/// Boosts, videos y el premio del Abogado son la misma cosa para el jugador
/// —"tengo un ×3 corriendo, le quedan 42 s"— y también para el código: los tres
/// son `ActiveModifier` con vencimiento. Los eventos quedan afuera porque ya
/// tienen `EventBannerView`, que además lleva el chiste del evento y funciona
/// como anuncio; un chip chico no lo reemplaza.
///
/// ⚠️ **No lleva el tiempo restante, y es a propósito.** Lleva `expiresAt` y
/// `totalDuration`, que son constantes mientras el bonus vive. Con el restante
/// adentro, esta proyección cambiaría una vez por segundo —y el aro, ocho—
/// invalidando SwiftUI sin parar mientras hubiera un boost activo. Así el array
/// sólo cambia cuando un bonus arranca o se muere. El tiempo lo cuenta la vista
/// con un timer propio (ver `ActiveBonusBar`).
struct ActiveBonus: Identifiable, Equatable {
    /// Con qué se dibuja. Los boosts tienen arte en el atlas UI; el video y el
    /// premio de carrera no, y van con un glifo del sistema.
    enum Icon: Equatable {
        case art(String)
        case symbol(String)
    }

    let id: UUID
    let effect: ActiveModifier.Effect
    let icon: Icon
    /// "×3", "−30%". Sale del mismo formateador que el menú de Bonus.
    let effectText: String
    let expiresAt: TimeInterval
    /// Cuánto duraba en total, para poder dibujar el aro que se vacía. Nil
    /// cuando el `sourceKey` no está en el catálogo: ahí el aro va lleno y el
    /// chip se muestra igual. Un bonus que corre y no se ve es peor que un aro
    /// sin vaciarse.
    let totalDuration: TimeInterval?
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
    /// Los modificadores que no se muestran: el evento tiene su propio banner.
    private static let excludedPrefix = "event."

    /// Glifo para un origen sin arte propio.
    private static let fallbackSymbol = "bolt.fill"

    static func bonuses(
        from modifiers: [ActiveModifier],
        catalog: [String: BonusSource],
        now: TimeInterval
    ) -> [ActiveBonus] {
        modifiers
            .filter { modifier in
                modifier.isActive(at: now)
                    // Los permanentes no son un contador: la Milanesa sube la
                    // eficiencia offline para siempre y no tiene nada que contar.
                    && modifier.expiresAt.isFinite
                    && !modifier.sourceKey.hasPrefix(excludedPrefix)
            }
            // Primero el que vence, que es el que urge.
            .sorted { $0.expiresAt < $1.expiresAt }
            .map { modifier in
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
    }

    /// El MISMO número que muestra el menú de Bonus, por el mismo camino: la
    /// magnitud 0,7 del mate es un factor de costo y se lee **−30%**, no ×0,7.
    /// Los tres efectos temporales mapean 1:1 contra `BoostsConfig.EffectType`.
    private static func effectText(for modifier: ActiveModifier) -> String {
        let boostEffect: BoostsConfig.EffectType = switch modifier.effect {
        case .incomeMultiplier: .incomeMultiplier
        case .tapMultiplier: .tapMultiplier
        case .spawnCostMultiplier: .spawnCostMultiplier
        }
        return EffectFormatter.text(
            EffectDescriptor.amount(forBoost: boostEffect, magnitude: modifier.magnitude)
        )
    }
}
