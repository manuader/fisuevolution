import Foundation

/// Una oferta de 24 h abierta (PLAN-v2 E6). El reloj es de pared: lo decidió el
/// dueño ("reloj real de 24 h que no se reinicia al volver a dispararse").
public struct ActiveOffer: Codable, Sendable, Equatable, Identifiable {
    /// El id de la oferta en `offers.json`.
    public let id: String
    public let openedAt: Double
    public let expiresAt: Double
    /// Ya se mostró sola su única vez (la hoja que aparece al abrirse).
    public var presented: Bool

    public init(id: String, openedAt: Double, expiresAt: Double, presented: Bool) {
        self.id = id
        self.openedAt = openedAt
        self.expiresAt = expiresAt
        self.presented = presented
    }
}

/// Lo que se recuerda de las ofertas: las abiertas, cuándo cerró cada una (el
/// enfriamiento cuenta desde ahí), las que ya se usaron y las líneas de base de
/// los disparadores.
public struct OffersState: Codable, Sendable, Equatable {
    public var active: [ActiveOffer]
    /// Cuándo cerró por última vez cada oferta: venció o se compró.
    public var lastClosedAt: [String: Double]
    /// Las que se abrieron alguna vez: las de una sola vez por cuenta no vuelven.
    public var everOpened: Set<String>
    public var purchases: [String: Int]
    /// La línea de base de "al reencarnar": un prestigio que ya se vio no dispara.
    public var seenPrestigeLevel: Int?
    /// La de "piso nuevo": la cantidad de pisos abiertos en la run.
    public var seenUnlockedFloors: Int?

    public static let initial = OffersState()

    public init(
        active: [ActiveOffer] = [],
        lastClosedAt: [String: Double] = [:],
        everOpened: Set<String> = [],
        purchases: [String: Int] = [:],
        seenPrestigeLevel: Int? = nil,
        seenUnlockedFloors: Int? = nil
    ) {
        self.active = active
        self.lastClosedAt = lastClosedAt
        self.everOpened = everOpened
        self.purchases = purchases
        self.seenPrestigeLevel = seenPrestigeLevel
        self.seenUnlockedFloors = seenUnlockedFloors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        active = try container.decodeIfPresent([ActiveOffer].self, forKey: .active) ?? []
        lastClosedAt = try container.decodeIfPresent([String: Double].self, forKey: .lastClosedAt) ?? [:]
        everOpened = try container.decodeIfPresent(Set<String>.self, forKey: .everOpened) ?? []
        purchases = try container.decodeIfPresent([String: Int].self, forKey: .purchases) ?? [:]
        seenPrestigeLevel = try container.decodeIfPresent(Int.self, forKey: .seenPrestigeLevel)
        seenUnlockedFloors = try container.decodeIfPresent(Int.self, forKey: .seenUnlockedFloors)
    }

    /// Las abiertas y las líneas de base viajan con el ganador (son del estado de
    /// ese dispositivo). Lo usado y lo comprado, unido: una oferta de una vez que
    /// se abrió en el otro dispositivo no vuelve, y su enfriamiento tampoco se
    /// pierde. Una abierta que el otro dispositivo ya cerró (venció o la compró)
    /// no sigue abierta: no se vende dos veces. Eso lo cubre `lastClosedAt`, así que
    /// toda compra y todo vencimiento tienen que marcarlo (`markPurchased`, T2/T10).
    public static func resolve(winner: OffersState, loser: OffersState) -> OffersState {
        var resolved = winner
        resolved.lastClosedAt = winner.lastClosedAt.merging(loser.lastClosedAt, uniquingKeysWith: max)
        resolved.everOpened = winner.everOpened.union(loser.everOpened)
        resolved.purchases = winner.purchases.merging(loser.purchases, uniquingKeysWith: max)
        resolved.active = winner.active.filter { offer in
            (resolved.lastClosedAt[offer.id] ?? -.infinity) < offer.openedAt
        }
        return resolved
    }
}
