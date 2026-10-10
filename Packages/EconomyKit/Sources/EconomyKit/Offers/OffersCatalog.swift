import Foundation

/// Las ofertas de 24 h (`offers.json`, PLAN-v2 E6). Cada una es un consumible de
/// StoreKit que entrega un paquete de `RewardSpec`.
public struct OffersCatalog: Codable, Sendable, Equatable {
    public enum Trigger: String, Codable, Sendable, CaseIterable {
        /// El 2º día de juego (con `oncePerAccount`, una sola vez).
        case secondDay
        /// Al reencarnar.
        case reincarnation
        /// Al abrir un piso nuevo en la run.
        case newFloor
    }

    public struct Offer: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let productId: String
        public let trigger: Trigger
        public let oncePerAccount: Bool
        /// Trae azar (un cofre): probabilidades a la vista y apagada en las
        /// tiendas restringidas (Apple 3.1.1, decisión "loot boxes").
        public let isChance: Bool
        public let iconKey: String
        public let symbol: String
        public let rewards: [RewardSpec]

        /// El ORO que trae: es ORO **comprado** (`oroPurchasedLifetime`).
        public var oroAmount: Int {
            rewards.reduce(0) { total, reward in
                guard case .oro(let amount) = reward else { return total }
                return total + amount
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            productId = try container.decode(String.self, forKey: .productId)
            trigger = try container.decode(Trigger.self, forKey: .trigger)
            oncePerAccount = try container.decodeIfPresent(Bool.self, forKey: .oncePerAccount) ?? false
            isChance = try container.decodeIfPresent(Bool.self, forKey: .isChance) ?? false
            iconKey = try container.decode(String.self, forKey: .iconKey)
            symbol = try container.decode(String.self, forKey: .symbol)
            rewards = try container.decode([RewardSpec].self, forKey: .rewards)
        }
    }

    public enum ValidationError: Error, Equatable {
        case duplicateID(String)
        case duplicateProduct(String)
        case emptyRewards(String)
        case badReward(String)
        /// Trae un cofre y no lo declara: se vendería azar sin probabilidades.
        case chanceNotDeclared(String)
        case nonPositiveWindow
        case negativeCooldown
    }

    public let schemaVersion: Int
    public let windowHours: Double
    public let cooldownDays: Double
    public let offers: [Offer]

    public var windowSeconds: Double { windowHours * 3600 }
    public var cooldownSeconds: Double { cooldownDays * 86_400 }

    public func offer(id: String) -> Offer? { offers.first { $0.id == id } }
    public func offer(productId: String) -> Offer? { offers.first { $0.productId == productId } }

    public func validate() throws {
        guard windowHours > 0 else { throw ValidationError.nonPositiveWindow }
        guard cooldownDays >= 0 else { throw ValidationError.negativeCooldown }
        var ids = Set<String>()
        var products = Set<String>()
        for offer in offers {
            guard ids.insert(offer.id).inserted else { throw ValidationError.duplicateID(offer.id) }
            guard products.insert(offer.productId).inserted else { throw ValidationError.duplicateProduct(offer.productId) }
            guard !offer.rewards.isEmpty else { throw ValidationError.emptyRewards(offer.id) }
            do {
                try offer.rewards.forEach { try $0.validate() }
            } catch {
                throw ValidationError.badReward(offer.id)
            }
            if offer.rewards.contains(where: { $0.kind == .skinChest }), !offer.isChance {
                throw ValidationError.chanceNotDeclared(offer.id)
            }
        }
    }
}
