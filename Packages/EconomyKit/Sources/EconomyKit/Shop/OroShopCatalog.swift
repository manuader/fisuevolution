import Foundation

/// La tienda de ORO como dato (`oro_shop.json`, PLAN-v2 E6). Un ítem es una de dos
/// cosas: un **consumible** (precio, premios o una acción, tope por día) o un
/// **permanente** (un perk con niveles, cada uno con su precio y su valor).
/// Los cosméticos no viven acá: son skins con `oroPrice` en `skins.json` (E6b).
public struct OroShopCatalog: Codable, Sendable, Equatable {
    public enum Shelf: String, Codable, Sendable, CaseIterable {
        case boosts, shortcuts, permanents, luck
    }

    /// Lo que un permanente cambia del juego. Lo lee quien lo usa, desde los niveles.
    public enum Perk: String, Codable, Sendable, CaseIterable {
        /// Lugares extra por piso (E6b). Los valores de los niveles se SUMAN.
        case extraSlots
        /// "Mejor proveedor" del Paquete de la Aduana (E5). Manda el valor del nivel,
        /// que ES el nivel: el `r` de cada uno vive en `packages.json` (E5a T1).
        case bestSupplier
        /// Giros por video de más por día en la ruleta (E5). Manda el valor del nivel.
        case wheelDailySpins
    }

    public enum Action: String, Codable, Sendable {
        /// "Fusionar todo" sobre el piso visible, por el embudo de E1.
        case mergeAll
    }

    public struct Level: Codable, Sendable, Equatable {
        public let price: Int
        public let value: Double

        public init(price: Int, value: Double) {
            self.price = price
            self.value = value
        }
    }

    public struct Item: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let shelf: Shelf
        /// Clave del arte del ícono (E8). Sin arte, la vista dibuja `symbol`.
        public let iconKey: String
        /// SF Symbol de respaldo mientras no llega el ícono.
        public let symbol: String
        /// Consumibles: el precio de la primera compra del día.
        public let price: Int?
        public let dailyLimit: Int?
        /// Cada compra del día multiplica el precio por esto (el salto de 1 h: 1,25).
        public let priceGrowthPerPurchase: Double?
        public let rewards: [RewardSpec]
        public let action: Action?
        public let perk: Perk?
        public let levels: [Level]
        /// Azar pagado con ORO (Apple 3.1.1): probabilidades a la vista y apagado en
        /// las tiendas restringidas.
        public let isChance: Bool
        /// Desde qué piso alcanzado en la cuenta aparece.
        public let unlockFloorId: String?

        public var isPermanent: Bool { perk != nil }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            shelf = try container.decode(Shelf.self, forKey: .shelf)
            iconKey = try container.decode(String.self, forKey: .iconKey)
            symbol = try container.decode(String.self, forKey: .symbol)
            price = try container.decodeIfPresent(Int.self, forKey: .price)
            dailyLimit = try container.decodeIfPresent(Int.self, forKey: .dailyLimit)
            priceGrowthPerPurchase = try container.decodeIfPresent(Double.self, forKey: .priceGrowthPerPurchase)
            rewards = try container.decodeIfPresent([RewardSpec].self, forKey: .rewards) ?? []
            action = try container.decodeIfPresent(Action.self, forKey: .action)
            perk = try container.decodeIfPresent(Perk.self, forKey: .perk)
            levels = try container.decodeIfPresent([Level].self, forKey: .levels) ?? []
            isChance = try container.decodeIfPresent(Bool.self, forKey: .isChance) ?? false
            unlockFloorId = try container.decodeIfPresent(String.self, forKey: .unlockFloorId)
        }
    }

    public enum ValidationError: Error, Equatable {
        case duplicateID(String)
        /// Ni premios, ni acción, ni perk: no da nada.
        case emptyItem(String)
        /// Consumible y permanente a la vez, o premios y acción a la vez.
        case mixedKinds(String)
        case nonPositivePrice(String)
        case invalidLimit(String)
        case invalidGrowth(String)
        case descendingPrices(String)
        case badReward(String)
        case unknownFloor(String)
    }

    public let schemaVersion: Int
    public let items: [Item]

    public func item(id: String) -> Item? {
        items.first { $0.id == id }
    }

    public func validate(floorIDs: Set<String>) throws {
        var seen = Set<String>()
        for item in items {
            guard seen.insert(item.id).inserted else { throw ValidationError.duplicateID(item.id) }
            if let floor = item.unlockFloorId, !floorIDs.contains(floor) {
                throw ValidationError.unknownFloor(floor)
            }
            if item.isPermanent {
                guard item.price == nil, item.rewards.isEmpty, item.action == nil, item.dailyLimit == nil else {
                    throw ValidationError.mixedKinds(item.id)
                }
                guard !item.levels.isEmpty else { throw ValidationError.emptyItem(item.id) }
                guard item.levels.allSatisfy({ $0.price > 0 }) else { throw ValidationError.nonPositivePrice(item.id) }
                guard zip(item.levels, item.levels.dropFirst()).allSatisfy({ $0.price < $1.price }) else {
                    throw ValidationError.descendingPrices(item.id)
                }
                continue
            }
            guard item.levels.isEmpty else { throw ValidationError.mixedKinds(item.id) }
            guard !item.rewards.isEmpty || item.action != nil else { throw ValidationError.emptyItem(item.id) }
            guard item.rewards.isEmpty || item.action == nil else { throw ValidationError.mixedKinds(item.id) }
            guard let price = item.price, price > 0 else { throw ValidationError.nonPositivePrice(item.id) }
            if let limit = item.dailyLimit, limit < 1 { throw ValidationError.invalidLimit(item.id) }
            if let growth = item.priceGrowthPerPurchase, !(growth >= 1) { throw ValidationError.invalidGrowth(item.id) }
            do {
                try item.rewards.forEach { try $0.validate() }
            } catch {
                throw ValidationError.badReward(item.id)
            }
        }
    }
}
