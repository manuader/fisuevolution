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
        oroGained(state: state, economy: economy) >= 1 && lastRunWallGoal(state: state, economy: economy) == nil
    }

    /// El tier al que todavía hay que llegar para reencarnar (piso móvil), o
    /// `nil` si no se pide nada: la perilla apagada, la primera reencarnación
    /// (`lastRunMaxTier` en 0) o la pared ya alcanzada.
    public static func lastRunWallGoal(state: PlayerState, economy: StandardEconomy) -> Int? {
        guard economy.config.oro.requiresWall, state.run.maxTierReached < state.meta.lastRunMaxTier else { return nil }
        return state.meta.lastRunMaxTier
    }

    /// Los pasivos que la run nueva conserva: los desbloqueados de ésta, que ya
    /// traen los de las anteriores. Vacío con la herencia apagada. La pantalla
    /// de reencarnar muestra esto mismo.
    public static func inheritedPassiveUnlocks(state: PlayerState, economy: StandardEconomy) -> [String: Bool] {
        guard economy.config.oro.inheritsPassives else { return [:] }
        return state.run.passiveUnlocked.filter(\.value)
    }

    /// Reencarnar: `run = .fresh(...)` (muere TODO lo de la run — imposible
    /// olvidarse un campo, salvo los pasivos si la herencia está prendida) y la
    /// meta acredita el ORO ganado.
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
        state.meta.lastRunMaxTier = state.run.maxTierReached
        let inherited = inheritedPassiveUnlocks(state: state, economy: economy)
        state.run = .fresh(startTypeId: tiers.baseType.id, startFloorId: floorTable[0].id)
        state.run.passiveUnlocked.merge(inherited) { _, kept in kept }
    }
}

/// Data-driven prestige rewards (`prestige_unlocks.json`): per-level hire cost
/// discount.
public struct PrestigeUnlocks: Codable, Sendable, Equatable {
    public struct Level: Codable, Sendable, Equatable {
        public let level: Int
        public let spawnCostDiscount: Double

        public init(level: Int, spawnCostDiscount: Double) {
            self.level = level
            self.spawnCostDiscount = spawnCostDiscount
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
