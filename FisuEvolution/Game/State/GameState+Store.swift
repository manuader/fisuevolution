import EconomyKit
import Foundation

/// Tienda (F4): entitlements de StoreKit y el equipamiento de skins. Separado de
/// `GameState.swift` para que el frente de la tienda no comparta archivo con los
/// otros cinco dominios.
extension GameState {
    /// StoreKit es la fuente de verdad; acá solo se cachea en el save.
    /// Las skins de milestone viven aparte (`meta.milestoneSkins`) y NO se pisan.
    func applyStoreEntitlements(removedAds: Bool, ownedSkins: [String]) {
        guard var player else { return }
        guard player.meta.removedAds != removedAds || player.meta.ownedSkins != ownedSkins else { return }
        player.meta.removedAds = removedAds
        player.meta.ownedSkins = ownedSkins
        let owned = player.meta.allOwnedSkins
        player.meta.activeSkinByType = player.meta.activeSkinByType.filter { owned.contains($0.value) }
        self.player = player
        skinSelectionVersion &+= 1
        bumpBoard()
        scheduleSave()
    }

    /// Skin actualmente equipada en la ficha de un tipo. La ausencia es la
    /// apariencia base: no se persiste un ID artificial para poder sumar skins
    /// data-driven sin migrar saves.
    func activeSkinID(forCharacterType typeID: String) -> String? {
        guard let player else { return nil }
        return player.meta.activeSkinByType[typeID]
    }

    func skinOptions(forCharacterType typeID: String) -> [SkinsConfig.Entry] {
        content?.skins.entries(forCharacterType: typeID) ?? []
    }

    func ownsSkin(_ skinID: String) -> Bool {
        player?.meta.allOwnedSkins.contains(skinID) == true
    }

    /// Equipa una skin en UN personaje. Valida tanto la pertenencia de la skin
    /// al catálogo como la propiedad del jugador; StoreKit nunca puede inyectar
    /// una apariencia que `skins.json` no declare para esa ficha.
    func equipSkin(id skinID: String?, forCharacterType typeID: String) {
        guard let content, var player,
              content.tiers.type(id: typeID) != nil
        else { return }
        if let skinID {
            guard player.meta.allOwnedSkins.contains(skinID),
                  content.skins.entries(forCharacterType: typeID).contains(where: { $0.id == skinID })
            else { return }
            player.meta.activeSkinByType[typeID] = skinID
        } else {
            player.meta.activeSkinByType.removeValue(forKey: typeID)
        }
        self.player = player
        skinSelectionVersion &+= 1
        bumpBoard()
        scheduleSave()
    }
}
