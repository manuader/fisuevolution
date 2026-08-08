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

    /// Acredita lo que trae un producto CONSUMIBLE. Los entitlements
    /// permanentes (remove ads, skins) no pasan por acá: los reescribe entero
    /// `applyStoreEntitlements` en cada sync de StoreKit, que es lo correcto
    /// para algo que se puede restaurar. La plata gastada no se restaura.
    func creditStorePurchase(_ entry: ProductCatalog.Entry, transactionID: String) {
        guard let economy, var player else { return }
        // Por transacción y no por producto: comprar dos veces el mismo pack
        // tiene que acreditar las dos.
        guard player.meta.creditedPurchases.insert(transactionID).inserted else { return }

        switch entry.entitlement {
        case .coins, .starterPack:
            guard let factor = entry.coinFactor else { return }
            let amount = economy.passiveUnlockCost(forTier: player.run.maxTierReached) * factor
            player.run.coins += amount
            player.meta.lifetimeEarnings += amount
        case .oro:
            guard let amount = entry.oroAmount else { return }
            // Sólo el balance. `oroEarnedLifetime` es lo que alimenta el
            // multiplicador global y sube únicamente al reencarnar.
            player.meta.oro += amount
        case .removeAds, .skin:
            return
        }

        self.player = player
        refreshProjections()
        scheduleSave()
    }

    /// Qué te da este pack, con el número concreto y ya formateado. La plata
    /// depende de dónde estás parado, así que no se puede escribir en el
    /// `.storekit`: sale calculada acá y la fila la muestra tal cual.
    ///
    /// Devuelve `nil` para lo que no es pack: la descripción de esos la pone
    /// StoreKit y repetirla sería una segunda fuente de verdad.
    func packRewardText(for entry: ProductCatalog.Entry) -> String? {
        guard let economy, let player else { return nil }
        switch entry.entitlement {
        case .coins:
            guard let factor = entry.coinFactor else { return nil }
            let amount = economy.passiveUnlockCost(forTier: player.run.maxTierReached) * factor
            return String(localized: "store.pack.coins \(CoinFormatter.string(from: amount))")
        case .oro:
            guard let amount = entry.oroAmount else { return nil }
            // `String(amount)`: interpolar un Int en un `%@` manda `%lld` y el
            // lookup falla, y en pantalla queda la clave cruda (trampa 5).
            return String(localized: "store.pack.oro \(String(amount))")
        case .starterPack:
            guard let factor = entry.coinFactor else { return nil }
            let amount = economy.passiveUnlockCost(forTier: player.run.maxTierReached) * factor
            return String(localized: "store.pack.starter \(CoinFormatter.string(from: amount))")
        case .removeAds, .skin:
            return nil
        }
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
