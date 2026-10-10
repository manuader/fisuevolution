import EconomyKit
import Foundation

/// Una figurita del Álbum de especiales (PLAN-v2 E4).
struct AlbumEntry: Identifiable, Equatable {
    let id: String
    let owned: Bool
    let nameKey: String
    let flavorKey: String
    /// "+3 % de ingresos": lo que da mientras lo tenés. Vacío si falta.
    let effectText: String
    /// Desde qué tier puede caer: la pista de los que faltan.
    let minTier: Int
}

extension GameState {
    /// Los diez, en el orden del catálogo. Computada: el Álbum es una pantalla
    /// del menú y casi nunca está abierta.
    var albumEntries: [AlbumEntry] {
        guard let content, let player else { return [] }
        let owned = Set(player.meta.ownedSpecials)
        return content.specials.specials.map { special in
            let has = owned.contains(special.id)
            return AlbumEntry(
                id: special.id, owned: has, nameKey: special.displayNameKey,
                flavorKey: special.flavorTextKey,
                effectText: has ? Self.albumEffectText(special.passiveEffect) : "",
                minTier: special.minTier
            )
        }
    }

    var albumOwnedCount: Int {
        albumEntries.filter(\.owned).count
    }

    static func albumEffectText(_ effect: SpecialsConfig.PassiveEffect) -> String {
        let amount = EffectFormatter.text(EffectDescriptor.amount(forSpecial: effect.type, magnitude: effect.magnitude))
        switch effect.type {
        case .incomeMultiplier: return String(localized: "album.effect.income \(amount)")
        case .offlineEfficiencyBonus: return String(localized: "album.effect.offline \(amount)")
        case .critChanceBonus: return String(localized: "album.effect.crit \(amount)")
        case .spawnDiscount: return String(localized: "album.effect.discount \(amount)")
        }
    }
}
