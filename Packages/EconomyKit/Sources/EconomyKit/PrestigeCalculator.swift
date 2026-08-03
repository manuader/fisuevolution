import Foundation

/// Reencarnación (F7 §3.7): el gate es GANAR ORO (≥1), no tener a Dios en el
/// tablero — con el pacing aprobado la 1ª reencarnación llega en el piso 5-6.
/// `oroEarnedLifetime` converge a `formula(lifetimeEarnings)` — lo ganado es el
/// delta, así el ORO nunca se cobra dos veces.
public enum PrestigeCalculator {
    public static func oroGained(state: PlayerState, economy: StandardEconomy) -> Int {
        max(0, economy.oroTotal(lifetimeEarnings: state.meta.lifetimeEarnings) - state.meta.oroEarnedLifetime)
    }

    public static func canReincarnate(state: PlayerState, economy: StandardEconomy) -> Bool {
        oroGained(state: state, economy: economy) >= 1
    }

    /// Reencarnar: `run = .fresh(...)` (muere TODO lo de la run — imposible
    /// olvidarse un campo) y la meta acredita el ORO ganado.
    public static func applyReincarnation(
        state: inout PlayerState,
        economy: StandardEconomy,
        tiers: TierRepository,
        floorTable: FloorTable,
        now: TimeInterval
    ) {
        let gained = oroGained(state: state, economy: economy)
        state.meta.oro += gained
        state.meta.oroEarnedLifetime += gained
        state.meta.prestigeLevel += 1
        state.meta.globalMultiplier = economy.globalMultiplier(
            oroEarnedLifetime: state.meta.oroEarnedLifetime,
            prestigeBonus: state.meta.derivedEffects.prestigeBonus
        )
        state.meta.lastSeenTimestamp = now
        state.run = .fresh(startTypeId: tiers.baseType.id, startFloorId: floorTable[0].id)
    }
}

/// Data-driven prestige rewards (`prestige_unlocks.json`): per-level hire cost
/// discount.
public struct PrestigeUnlocks: Codable, Sendable, Equatable {
    public struct Level: Codable, Sendable, Equatable {
        public let level: Int
        public let spawnCostDiscount: Double
        public let unlockBackgrounds: [String]
        public let unlockSkins: [String]
        public let unlockSpecials: [String]

        public init(level: Int, spawnCostDiscount: Double, unlockBackgrounds: [String], unlockSkins: [String], unlockSpecials: [String]) {
            self.level = level
            self.spawnCostDiscount = spawnCostDiscount
            self.unlockBackgrounds = unlockBackgrounds
            self.unlockSkins = unlockSkins
            self.unlockSpecials = unlockSpecials
        }
    }

    public let schemaVersion: Int
    /// Hard cap so stacked discounts never zero out the hire cost. [TUNEABLE]
    public let spawnDiscountCap: Double
    public let levels: [Level]

    public init(schemaVersion: Int, spawnDiscountCap: Double, levels: [Level]) {
        self.schemaVersion = schemaVersion
        self.spawnDiscountCap = spawnDiscountCap
        self.levels = levels
    }

    /// Sum of discounts for every reached level, capped.
    public func cumulativeSpawnDiscount(atPrestigeLevel prestigeLevel: Int) -> Double {
        let sum = levels.filter { $0.level <= prestigeLevel }.map(\.spawnCostDiscount).reduce(0, +)
        return min(sum, spawnDiscountCap)
    }
}
