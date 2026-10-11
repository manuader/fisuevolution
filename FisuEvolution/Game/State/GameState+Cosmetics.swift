import EconomyKit
import Foundation

/// Una fila del estante de Cosméticos: una pinta de ORO de `skins.json`.
struct CosmeticRow: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Una familia dibujada para los 43.
        case family(name: String)
        /// Una pinta de un solo personaje.
        case outfit(characterType: String)
    }

    let id: String
    let kind: Kind
    let price: Int
    let owned: Bool

    static func rows(skins: SkinsConfig, owned: Set<String>) -> [CosmeticRow] {
        skins.oroSkinIDs.compactMap { id in
            guard let entry = skins.entry(id: id), let price = entry.oroPrice else { return nil }
            let kind: Kind = entry.family.map(Kind.family(name:)) ?? .outfit(characterType: entry.characterType)
            return CosmeticRow(id: id, kind: kind, price: price, owned: owned.contains(id))
        }
    }
}

extension GameState {
    var cosmeticRows: [CosmeticRow] {
        guard let content, let player else { return [] }
        return CosmeticRow.rows(skins: content.skins, owned: player.meta.allOwnedSkins)
    }

    /// A quién se le muestra una familia en la tienda: al de tier más alto que
    /// tenés (el mismo criterio que el auto-tap).
    var cosmeticPreviewType: CharacterType? {
        guard let content, let player else { return nil }
        return AutoTapper.target(state: player, tiers: content.tiers) ?? content.tiers.baseType
    }
}
