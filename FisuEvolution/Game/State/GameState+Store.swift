import EconomyKit
import Foundation

/// Una tarjeta del Customization Shop (spec §7), ya resuelta: la vista la dibuja
/// sin volver a preguntarle nada al estado ni conocer `SkinsConfig`.
struct SkinCatalogRow: Identifiable, Equatable {
    /// Qué se puede hacer con esta apariencia.
    enum State: Equatable {
        /// Es la que el personaje lleva puesta ahora.
        case equipped
        /// La tenés (milestone cumplido o comprada) pero no la llevás puesta.
        case owned
        /// Skin de milestone sin cumplir. El payload es la condición **ya
        /// resuelta y traducida** ("Llegá a Ciudad"), no una clave: armarla en la
        /// vista con `LocalizedStringKey("skins.unlock.\(...)")` es la trampa 5
        /// del HANDOFF y deja la clave cruda en pantalla.
        case milestoneLocked(conditionText: String)
        /// Skin paga que todavía no compraste. El payload es el id del producto
        /// de StoreKit — la vista le pide el precio a `StoreManager`, porque el
        /// precio real depende de la tienda del jugador y no puede vivir acá.
        case purchasable(productID: String)
    }

    /// El id de la skin del catálogo, o `"base"` para la apariencia original.
    /// La base no se persiste con un id artificial (`activeSkinByType` guarda la
    /// ausencia), así que este `"base"` vive sólo en la proyección.
    let id: String
    let displayName: String
    /// Clave de textura del atlas para el preview, o `nil` en la base (que se
    /// dibuja con el arte del personaje).
    let textureKey: String?
    let state: State
}

/// Tienda (F4): entitlements de StoreKit y el equipamiento de skins. Separado de
/// `GameState.swift` para que el frente de la tienda no comparta archivo con los
/// otros cinco dominios.
extension GameState {
    /// El id de la fila de la apariencia original. No es una skin: `equipSkin`
    /// recibe `nil` para volver a ella.
    static let baseSkinRowID = "base"

    /// Las tarjetas del Customization Shop para UN personaje, listas para
    /// dibujar: la base primero y después las skins del catálogo en su orden.
    ///
    /// Es computada y no una proyección publicada por el mismo motivo que
    /// `jobRows` y `characterUpgradeRows`: la pantalla es un modal que se
    /// re-evalúa contra `skinSelectionVersion` —lo único que mueve una tarjeta—,
    /// y publicar el array obligaría a difundirlo por una hoja que casi nunca
    /// está abierta.
    ///
    /// **Los textos salen resueltos de acá.** La condición de una skin de
    /// milestone se arma con `String(localized:)` porque `LocalizedStringKey` no
    /// resuelve claves interpoladas (trampa 5): si la vista intentara armar
    /// `"skins.unlock.floor \(piso)"` como clave, en pantalla quedaría la clave
    /// cruda. El precio es la excepción y **no** vive acá: lo pone StoreKit con
    /// el `displayPrice` de la tienda del jugador.
    func skinCatalogRows(forCharacterType typeID: String) -> [SkinCatalogRow] {
        // `concreteTypes` y no `tiers.type(id:)`: el nodo de elección de carrera
        // existe en el catálogo pero no es un personaje al que vestir.
        guard let content, content.tiers.concreteTypes.contains(where: { $0.id == typeID }) else { return [] }
        let active = activeSkinID(forCharacterType: typeID)

        let base = SkinCatalogRow(
            id: Self.baseSkinRowID,
            displayName: String(localized: "skins.base"),
            textureKey: nil,
            state: active == nil ? .equipped : .owned
        )
        return [base] + skinOptions(forCharacterType: typeID).map { entry in
            SkinCatalogRow(
                id: entry.id,
                displayName: skinDisplayName(for: entry),
                textureKey: entry.textureKey,
                state: skinState(for: entry, activeSkinID: active)
            )
        }
    }

    /// El nombre visible de una skin del catálogo.
    ///
    /// Una skin catalogada sin `displayNameKey` cae al id embellecido: sirve para
    /// una skin de prueba y evita que la falta de un nombre rompa la pantalla.
    /// Vive acá —y no en cada vista— porque lo usan la ficha de personaje y el
    /// Customization Shop, y dos copias divergen.
    func skinDisplayName(for entry: SkinsConfig.Entry) -> String {
        guard let key = entry.displayNameKey else {
            return entry.id.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return String(localized: String.LocalizationValue(key))
    }

    /// Qué se puede hacer con una skin, en orden de prioridad: tenerla gana sobre
    /// todo lo demás (una skin de milestone ya ganada no vuelve a pedir su
    /// condición, y una paga ya comprada no se vuelve a vender).
    private func skinState(for entry: SkinsConfig.Entry, activeSkinID: String?) -> SkinCatalogRow.State {
        guard !ownsSkin(entry.id) else {
            return activeSkinID == entry.id ? .equipped : .owned
        }
        if let condition = milestoneConditionText(for: entry) {
            return .milestoneLocked(conditionText: condition)
        }
        if let productID = SkinProductIndex.productIDBySkinID[entry.id] {
            return .purchasable(productID: productID)
        }
        // Ni milestone ni producto: una skin catalogada que todavía no tiene por
        // dónde conseguirse. Se muestra bloqueada en vez de desaparecer, así el
        // catálogo puede shippear una skin antes que su forma de obtenerla.
        return .milestoneLocked(conditionText: String(localized: "skins.locked.generic"))
    }

    /// La condición de una skin de milestone, ya traducida, o `nil` si no es de
    /// milestone.
    ///
    /// El piso primero y la reencarnación después, igual que `SkinMilestones`
    /// evalúa: una entrada con las dos condiciones nombra la del piso, que es la
    /// que el jugador ve venir.
    private func milestoneConditionText(for entry: SkinsConfig.Entry) -> String? {
        if let floorID = entry.floorReached {
            // El id crudo del piso ("urban") no es un nombre.
            return String(localized: "skins.unlock.floor \(TowerNaming.floorName(for: floorID))")
        }
        if entry.upgradesMaxed == true {
            // El oro no se vende: el texto genérico ("todavía no está a la
            // venta") decía justo lo contrario de su única vía.
            return String(localized: "skins.unlock.upgrades_maxed")
        }
        if let lives = entry.reincarnations {
            // `String(lives)`: interpolar un Int manda `%lld`, la clave declarada
            // con `%@` no matchea y en pantalla queda la clave cruda (trampa 5).
            return String(localized: "skins.unlock.prestige \(String(lives))")
        }
        return nil
    }

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
        // Equipar es el gesto que sigue a conseguir una pinta, y `equipSkin` es
        // el único camino de la pantalla de Personalización que pasa por el
        // estado: los logros de skins se miden acá y en `updateMaxFloorStat`
        // (que es donde las acredita `awardEligibleMilestoneSkins`).
        evaluateAchievements()
        bumpBoard()
        scheduleSave()
    }
}

/// skin → producto de StoreKit que la vende, leído UNA vez del catálogo de IAP.
///
/// ⚠️ **No es el inverso literal de `skinByProductID`.** Una skin la pueden
/// vender DOS productos: `mundialista` figura en `skin_mundialista` y también
/// dentro del `starter_pack`, que la trae de regalo. Invertir el diccionario con
/// `uniqueKeysWithValues` crashearía, y quedarse con el primero le ofrecería el
/// combo entero a quien sólo quiere la camiseta. Gana **el producto dedicado**
/// (`entitlement == .skin`); el combo queda como respaldo para una skin que sólo
/// se venda adentro de un pack.
///
/// Se lee del bundle y no de `StoreManager` a propósito: es contenido (qué
/// producto corresponde a qué skin) y no estado de la tienda. Lo que sí depende
/// de StoreKit —si el producto cargó y a qué precio— lo resuelve la vista.
@MainActor
private enum SkinProductIndex {
    static let productIDBySkinID: [String: String] = {
        guard let catalog = try? ProductCatalog.load(from: .main) else { return [:] }
        var index: [String: String] = [:]
        for entry in catalog.products {
            guard let skinID = entry.skinId else { continue }
            if entry.entitlement == .skin || index[skinID] == nil {
                index[skinID] = entry.id
            }
        }
        return index
    }()
}
