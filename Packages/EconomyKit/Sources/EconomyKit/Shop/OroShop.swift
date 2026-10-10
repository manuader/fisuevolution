import Foundation

/// Las cuentas de la tienda de ORO (PLAN-v2 E6). Pura: la app le pasa lo que
/// sólo ella sabe (lo que puede entregar, si el azar está permitido en esta
/// tienda, cuántos pares fundiría "Fusionar todo") y entrega los premios ella.
public enum OroShop {
    public struct Context: Sendable, Equatable {
        /// "yyyy-MM-dd", el mismo día del premio diario.
        public let today: String
        /// Lo que la app ya sabe entregar (`GameState.grantableRewardKinds`).
        public let grantableKinds: Set<RewardSpec.Kind>
        /// `false` en las tiendas de `restrictedStorefronts` (Bélgica y Australia).
        public let chanceAllowed: Bool
        /// Los pisos que la cuenta alcanzó alguna vez.
        public let reachedFloorIds: Set<String>
        /// Cuántos pares fundiría "Fusionar todo" ahora en el piso visible.
        public let mergeAllPairs: Int
        /// Hay algún boost esperando su cooldown.
        public let anyBoostCoolingDown: Bool
        /// El cofre de pintas tiene algo para dar hoy (`ChestRoller.hasSomethingToGive`).
        public let chestHasSomethingToGive: Bool
        /// Los perks que alguien lee hoy (el de paquetes necesita E5; el de lugares, E6b).
        public let supportedPerks: Set<OroShopCatalog.Perk>

        public init(
            today: String,
            grantableKinds: Set<RewardSpec.Kind>,
            chanceAllowed: Bool,
            reachedFloorIds: Set<String>,
            mergeAllPairs: Int,
            anyBoostCoolingDown: Bool,
            chestHasSomethingToGive: Bool,
            supportedPerks: Set<OroShopCatalog.Perk>
        ) {
            self.today = today
            self.grantableKinds = grantableKinds
            self.chanceAllowed = chanceAllowed
            self.reachedFloorIds = reachedFloorIds
            self.mergeAllPairs = mergeAllPairs
            self.anyBoostCoolingDown = anyBoostCoolingDown
            self.chestHasSomethingToGive = chestHasSomethingToGive
            self.supportedPerks = supportedPerks
        }
    }

    /// Por qué no se puede comprar AHORA algo que sí se ve. El orden de los casos
    /// es el de prioridad: "al máximo" gana a todo, "no te alcanza" a nada.
    public enum Blocker: Sendable, Equatable {
        case maxed
        case dailyLimitReached
        case alreadyPending
        case nothingToDo
        case cantAfford
    }

    public struct Quote: Sendable, Equatable {
        public let itemId: String
        /// `nil` = al máximo (no hay próximo nivel).
        public let price: Int?
        /// Permanentes: el nivel comprado. Consumibles: 0.
        public let level: Int
        public let boughtToday: Int
        public let blocker: Blocker?
    }

    public enum PurchaseError: Error, Equatable {
        case unknownItem
        case notOffered
        case blocked(Blocker)
    }

    public struct Purchase: Sendable, Equatable {
        public let item: OroShopCatalog.Item
        public let price: Int
        /// Permanentes: el nivel que quedó. Consumibles: `nil`.
        public let newLevel: Int?
    }

    /// Lo que se ofrece hoy, en el orden del catálogo.
    public static func visibleItems(catalog: OroShopCatalog, context: Context) -> [OroShopCatalog.Item] {
        catalog.items.filter { isOffered($0, context: context) }
    }

    public static func quote(_ item: OroShopCatalog.Item, state: PlayerState, context: Context) -> Quote {
        let shop = state.meta.engagement.shop.on(day: context.today)
        let bought = shop.purchasesToday[item.id] ?? 0
        if item.isPermanent {
            let level = shop.levels[item.id] ?? 0
            guard item.levels.indices.contains(level) else {
                return Quote(itemId: item.id, price: nil, level: level, boughtToday: 0, blocker: .maxed)
            }
            let price = item.levels[level].price
            let blocker: Blocker? = state.meta.oro >= price ? nil : .cantAfford
            return Quote(itemId: item.id, price: price, level: level, boughtToday: 0, blocker: blocker)
        }
        let base = Double(item.price ?? 0)
        let price = Int((base * pow(item.priceGrowthPerPurchase ?? 1, Double(bought))).rounded())
        return Quote(itemId: item.id, price: price, level: 0, boughtToday: bought,
                     blocker: consumableBlocker(item, shop: shop, bought: bought, price: price, oro: state.meta.oro, context: context))
    }

    /// Compra: cobra por `MetaState.spendOro` (la única salida de ORO) y anota el
    /// cupo del día o el nivel. NO entrega los premios: eso es de la app.
    @discardableResult
    public static func purchase(
        _ itemId: String,
        state: inout PlayerState,
        catalog: OroShopCatalog,
        context: Context
    ) throws -> Purchase {
        guard let item = catalog.item(id: itemId) else { throw PurchaseError.unknownItem }
        guard isOffered(item, context: context) else { throw PurchaseError.notOffered }
        let quote = quote(item, state: state, context: context)
        if let blocker = quote.blocker { throw PurchaseError.blocked(blocker) }
        guard let price = quote.price, state.meta.spendOro(price) else { throw PurchaseError.blocked(.cantAfford) }

        var shop = state.meta.engagement.shop.on(day: context.today)
        var newLevel: Int?
        if item.isPermanent {
            newLevel = quote.level + 1
            shop.levels[item.id] = newLevel
        } else {
            shop.purchasesToday[item.id, default: 0] += 1
        }
        state.meta.engagement.shop = shop
        return Purchase(item: item, price: price, newLevel: newLevel)
    }

    public enum SkinPurchaseError: Error, Equatable {
        case alreadyOwned
        case cantAfford
        case invalidPrice
    }

    /// Una pinta con ORO: `spendOro` y a `shop.skins`, en un solo paso. El precio
    /// lo trae quien llama, desde `skins.json` (`SkinsConfig.oroPrice(of:)`).
    /// Lo que ya es tuyo no se cobra: una segunda llamada ve la primera.
    public static func purchaseSkin(_ skinID: String, price: Int, state: inout PlayerState) throws {
        guard price > 0 else { throw SkinPurchaseError.invalidPrice }
        guard !state.meta.allOwnedSkins.contains(skinID) else { throw SkinPurchaseError.alreadyOwned }
        guard state.meta.spendOro(price) else { throw SkinPurchaseError.cantAfford }
        state.meta.engagement.shop.skins.insert(skinID)
    }

    // MARK: Perks

    /// Lugares extra por piso: la suma de los valores de los niveles comprados.
    public static func extraSlots(levels: [String: Int], catalog: OroShopCatalog) -> Int {
        catalog.items.filter { $0.perk == .extraSlots }.reduce(0) { total, item in
            let level = min(levels[item.id] ?? 0, item.levels.count)
            return total + item.levels.prefix(level).reduce(0) { $0 + Int($1.value) }
        }
    }

    /// El nivel de "mejor proveedor" (0 sin comprar). Lo lee el Paquete de E5a
    /// con `PackagesConfig.tierRatio(bestSupplierLevel:)`: el `r` es dato de E5.
    public static func bestSupplierLevel(levels: [String: Int], catalog: OroShopCatalog) -> Int {
        Int(levelValue(of: .bestSupplier, levels: levels, catalog: catalog) ?? 0)
    }

    /// Giros por video de más por día en la ruleta.
    public static func bonusDailyWheelSpins(levels: [String: Int], catalog: OroShopCatalog) -> Int {
        Int(levelValue(of: .wheelDailySpins, levels: levels, catalog: catalog) ?? 0)
    }

    // MARK: Internals

    private static func levelValue(of perk: OroShopCatalog.Perk, levels: [String: Int], catalog: OroShopCatalog) -> Double? {
        guard let item = catalog.items.first(where: { $0.perk == perk }) else { return nil }
        let level = min(levels[item.id] ?? 0, item.levels.count)
        return level > 0 ? item.levels[level - 1].value : nil
    }

    private static func isOffered(_ item: OroShopCatalog.Item, context: Context) -> Bool {
        if let floor = item.unlockFloorId, !context.reachedFloorIds.contains(floor) { return false }
        if item.isChance, !context.chanceAllowed { return false }
        if let perk = item.perk, !context.supportedPerks.contains(perk) { return false }
        return item.rewards.allSatisfy { isDeliverable($0, grantable: context.grantableKinds) }
    }

    /// Un ritmo de paquetes sin paquetes no es un premio: pide `.package` (el
    /// mismo criterio que los eventos de E4a).
    private static func isDeliverable(_ reward: RewardSpec, grantable: Set<RewardSpec.Kind>) -> Bool {
        guard grantable.contains(reward.kind) else { return false }
        if case .modifier(.packageRateMultiplier, _, _) = reward { return grantable.contains(.package) }
        return true
    }

    private static func consumableBlocker(
        _ item: OroShopCatalog.Item,
        shop: ShopState,
        bought: Int,
        price: Int,
        oro: Int,
        context: Context
    ) -> Blocker? {
        if let limit = item.dailyLimit, bought >= limit { return .dailyLimitReached }
        for reward in item.rewards {
            switch reward {
            case .nextOfflineMultiplier where shop.pendingOfflineMultiplier != nil: return .alreadyPending
            case .nextDailyMultiplier where shop.pendingDailyMultiplier != nil: return .alreadyPending
            case .clearBoostCooldowns where !context.anyBoostCoolingDown: return .nothingToDo
            case .skinChest where !context.chestHasSomethingToGive: return .nothingToDo
            default: continue
            }
        }
        if item.action == .mergeAll, context.mergeAllPairs == 0 { return .nothingToDo }
        return oro >= price ? nil : .cantAfford
    }
}
