import Foundation

/// Tunable economy parameters, mirrored 1:1 from `economy.json` (build bible §3).
///
/// Every number the game uses derives from this file — nothing is hardcoded.
/// The soul-points formula from the bible, `floor((lifetimeEarnings / 1e6) ^ 0.5)`,
/// is expressed here as `prestige.soulPointsDivisor` + `prestige.soulPointsExponent`.
public struct EconomyConfig: Codable, Sendable, Equatable {
    public struct SpawnConfig: Codable, Sendable, Equatable {
        /// What the cost-growth exponent counts. `perType` (bible literal): purchases
        /// of the currently offered type — pacing colapsa en una sola pared cuando la
        /// ventana de spawn avanza. `total`: todas las compras de la vida — inflación
        /// global suave, pacing parejo (validado con balance-sim). [TUNEABLE]
        public enum CostBasis: String, Codable, Sendable {
            case perType
            case total
        }

        /// Base cost of the very first spawn purchase (bible: 15).
        public let baseCost: Double
        /// Multiplicative growth per purchase counted according to `costBasis`.
        public let costGrowth: Double
        /// Progressive-spawn mechanic: the shop offers tier `max(1, maxTierReached - tierOffset)`.
        /// Approved extension to bible §2.3 rule 4 — reaching god with tier-1-only spawns
        /// would need 2^29 units.
        public let tierOffset: Int
        public let costBasis: CostBasis

        public init(baseCost: Double, costGrowth: Double, tierOffset: Int, costBasis: CostBasis = .perType) {
            self.baseCost = baseCost
            self.costGrowth = costGrowth
            self.tierOffset = tierOffset
            self.costBasis = costBasis
        }

        enum CodingKeys: String, CodingKey {
            case baseCost, costGrowth, tierOffset, costBasis
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            baseCost = try container.decode(Double.self, forKey: .baseCost)
            costGrowth = try container.decode(Double.self, forKey: .costGrowth)
            tierOffset = try container.decode(Int.self, forKey: .tierOffset)
            costBasis = try container.decodeIfPresent(CostBasis.self, forKey: .costBasis) ?? .perType
        }
    }

    public struct PrestigeConfig: Codable, Sendable, Equatable {
        public let soulPointsDivisor: Double
        public let soulPointsExponent: Double
        public let globalMultiplierPerSoulPoint: Double

        public init(soulPointsDivisor: Double, soulPointsExponent: Double, globalMultiplierPerSoulPoint: Double) {
            self.soulPointsDivisor = soulPointsDivisor
            self.soulPointsExponent = soulPointsExponent
            self.globalMultiplierPerSoulPoint = globalMultiplierPerSoulPoint
        }
    }

    public struct BoardConfig: Codable, Sendable, Equatable {
        public let columns: Int
        public let rows: Int

        public var cellCount: Int { columns * rows }

        public init(columns: Int, rows: Int) {
            self.columns = columns
            self.rows = rows
        }
    }

    public let schemaVersion: Int
    public let baseTapYieldTier1: Double
    public let yieldGrowthPerTier: Double
    public let passiveRatio: Double
    public let passiveUnlockCostMultiplier: Double
    public let spawn: SpawnConfig
    public let critChanceBase: Double
    public let critMultiplier: Double
    public let offlineEfficiencyBase: Double
    public let offlineCapHours: Double
    public let prestige: PrestigeConfig
    public let board: BoardConfig

    public init(
        schemaVersion: Int,
        baseTapYieldTier1: Double,
        yieldGrowthPerTier: Double,
        passiveRatio: Double,
        passiveUnlockCostMultiplier: Double,
        spawn: SpawnConfig,
        critChanceBase: Double,
        critMultiplier: Double,
        offlineEfficiencyBase: Double,
        offlineCapHours: Double,
        prestige: PrestigeConfig,
        board: BoardConfig
    ) {
        self.schemaVersion = schemaVersion
        self.baseTapYieldTier1 = baseTapYieldTier1
        self.yieldGrowthPerTier = yieldGrowthPerTier
        self.passiveRatio = passiveRatio
        self.passiveUnlockCostMultiplier = passiveUnlockCostMultiplier
        self.spawn = spawn
        self.critChanceBase = critChanceBase
        self.critMultiplier = critMultiplier
        self.offlineEfficiencyBase = offlineEfficiencyBase
        self.offlineCapHours = offlineCapHours
        self.prestige = prestige
        self.board = board
    }
}
