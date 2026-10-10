import Foundation

/// Lo que se recuerda de la tienda de ORO (PLAN-v2 E6): los topes del día, los
/// niveles de los permanentes, los multiplicadores comprados que esperan su
/// próximo offline o diario, y las pintas compradas con ORO.
public struct ShopState: Codable, Sendable, Equatable {
    /// El día calendario ("yyyy-MM-dd") de `purchasesToday`.
    public var day: String?
    /// Compras de hoy por ítem: los topes diarios y el ×1,25 del salto de 1 h.
    public var purchasesToday: [String: Int]
    /// Nivel comprado de cada permanente (sin clave = no comprado).
    public var levels: [String: Int]
    /// El próximo offline con popup se multiplica por esto (Offline ×3).
    public var pendingOfflineMultiplier: Double?
    /// El próximo diario que paga plata se multiplica por esto (Diario ×3).
    public var pendingDailyMultiplier: Double?
    /// Pintas compradas con ORO. Viven acá y no en `meta.ownedSkins`, que es la
    /// caché de StoreKit y se reescribe entera en cada sincronización.
    public var skins: Set<String>

    public static let initial = ShopState()

    public init(
        day: String? = nil,
        purchasesToday: [String: Int] = [:],
        levels: [String: Int] = [:],
        pendingOfflineMultiplier: Double? = nil,
        pendingDailyMultiplier: Double? = nil,
        skins: Set<String> = []
    ) {
        self.day = day
        self.purchasesToday = purchasesToday
        self.levels = levels
        self.pendingOfflineMultiplier = pendingOfflineMultiplier
        self.pendingDailyMultiplier = pendingDailyMultiplier
        self.skins = skins
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decodeIfPresent(String.self, forKey: .day)
        purchasesToday = try container.decodeIfPresent([String: Int].self, forKey: .purchasesToday) ?? [:]
        levels = try container.decodeIfPresent([String: Int].self, forKey: .levels) ?? [:]
        pendingOfflineMultiplier = try container.decodeIfPresent(Double.self, forKey: .pendingOfflineMultiplier)
        pendingDailyMultiplier = try container.decodeIfPresent(Double.self, forKey: .pendingDailyMultiplier)
        skins = try container.decodeIfPresent(Set<String>.self, forKey: .skins) ?? []
    }

    /// El estado visto desde `today`: en otro día los topes vuelven a cero. Lo
    /// comprado (niveles, pintas, ×3 pendientes) no vence con el día.
    public func on(day today: String) -> ShopState {
        guard day != today else { return self }
        var fresh = self
        fresh.day = today
        fresh.purchasesToday = [:]
        return fresh
    }

    /// Lo comprado no retrocede: niveles al más alto, pintas unidas y el ×3
    /// pendiente de cualquiera de los dos (el mayor si hay ambos). Los topes, si
    /// los dos saves hablan del mismo día, se quedan con lo más alto: dos
    /// dispositivos no duplican el cupo; si hablan de días distintos, vale el del
    /// día mayor. El ×3 pendiente puede reaparecer si se compró en A, se sincronizó,
    /// se usó en A y se cruzó con B: igual que `chestsPending`, aceptado a la vista.
    public static func resolve(winner: ShopState, loser: ShopState) -> ShopState {
        var resolved = winner
        resolved.levels = winner.levels.merging(loser.levels, uniquingKeysWith: max)
        resolved.skins = winner.skins.union(loser.skins)
        resolved.pendingOfflineMultiplier = larger(winner.pendingOfflineMultiplier, loser.pendingOfflineMultiplier)
        resolved.pendingDailyMultiplier = larger(winner.pendingDailyMultiplier, loser.pendingDailyMultiplier)
        if let winnerDay = winner.day, let loserDay = loser.day {
            if winnerDay == loserDay {
                resolved.purchasesToday = winner.purchasesToday.merging(loser.purchasesToday, uniquingKeysWith: max)
            } else if loserDay > winnerDay {
                resolved.day = loserDay
                resolved.purchasesToday = loser.purchasesToday
            }
        } else if winner.day == nil, let loserDay = loser.day {
            resolved.day = loserDay
            resolved.purchasesToday = loser.purchasesToday
        }
        return resolved
    }

    private static func larger(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): max(lhs, rhs)
        default: lhs ?? rhs
        }
    }
}
