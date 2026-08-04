import Foundation

/// Tunable economy parameters, mirrored 1:1 from `economy.json` (schemaVersion 2, F7).
///
/// Every number the game uses derives from this file — nothing is hardcoded.
/// v2 (F7 "La Torre"): floors[] reemplaza al board único y a la tabla de stages
/// hardcodeada; `hire` (contratación contextual al piso, precio punitivo) reemplaza
/// al spawn progresivo por tierOffset; `oro` reemplaza a `prestige` (soul points).
public struct EconomyConfig: Codable, Sendable, Equatable {
    /// Contratación contextual al piso (spec F7 §3.3, decisión cerrada con el dueño):
    /// el botón contrata el TIER BASE del piso visible.
    /// `cost(k, n) = mult(k) × tapYield(firstTier(k)) × growth(k)^n`, con
    /// `n = run.hireCounts[floorId]`. Los pisos > 1 usan estos defaults PUNITIVOS
    /// (backfill recién rentable con la frontera 2-3 pisos arriba); el piso 1
    /// overridea a barato en su FloorDef. [TUNEABLE]
    public struct HireConfig: Codable, Sendable, Equatable {
        public let defaultCostMultiplier: Double
        public let defaultCostGrowth: Double

        public init(defaultCostMultiplier: Double, defaultCostGrowth: Double) {
            self.defaultCostMultiplier = defaultCostMultiplier
            self.defaultCostGrowth = defaultCostGrowth
        }
    }

    /// Mejoras POR PERSONAJE compradas con plata (se pierden al reencarnar).
    /// Efecto: `effectFactorPerLevel^nivel` sobre el income del tipo (×2/nivel,
    /// default ⚠️4). Costo: `baseCostMultiplier × tapYield(tier) × costGrowth^nivel`.
    public struct CharUpgradesConfig: Codable, Sendable, Equatable {
        public let baseCostMultiplier: Double
        public let costGrowth: Double
        public let effectFactorPerLevel: Double

        public init(baseCostMultiplier: Double, costGrowth: Double, effectFactorPerLevel: Double) {
            self.baseCostMultiplier = baseCostMultiplier
            self.costGrowth = costGrowth
            self.effectFactorPerLevel = effectFactorPerLevel
        }
    }

    /// ORO: moneda de prestigio (F7 §3.7). Ganancia al reencarnar:
    /// `floor((lifetimeEarnings / divisor) ^ exponent) − oroEarnedLifetime`.
    /// El multiplicador global se calcula sobre `oroEarnedLifetime` (monótono:
    /// gastar ORO nunca nerfea).
    public struct OroConfig: Codable, Sendable, Equatable {
        public let divisor: Double
        public let exponent: Double
        public let globalMultiplierPerOro: Double

        public init(divisor: Double, exponent: Double, globalMultiplierPerOro: Double) {
            self.divisor = divisor
            self.exponent = exponent
            self.globalMultiplierPerOro = globalMultiplierPerOro
        }
    }

    public let schemaVersion: Int
    public let baseTapYieldTier1: Double
    public let yieldGrowthPerTier: Double
    public let passiveRatio: Double
    public let passiveUnlockCostMultiplier: Double
    public let hire: HireConfig
    public let charUpgrades: CharUpgradesConfig
    public let oro: OroConfig
    public let critChanceBase: Double
    public let critMultiplier: Double
    public let offlineEfficiencyBase: Double
    public let offlineCapHours: Double
    /// La Torre: pisos en orden ascendente de tiers. Validados por `FloorTable`.
    public let floors: [FloorDef]

    public init(
        schemaVersion: Int,
        baseTapYieldTier1: Double,
        yieldGrowthPerTier: Double,
        passiveRatio: Double,
        passiveUnlockCostMultiplier: Double,
        hire: HireConfig,
        charUpgrades: CharUpgradesConfig,
        oro: OroConfig,
        critChanceBase: Double,
        critMultiplier: Double,
        offlineEfficiencyBase: Double,
        offlineCapHours: Double,
        floors: [FloorDef]
    ) {
        self.schemaVersion = schemaVersion
        self.baseTapYieldTier1 = baseTapYieldTier1
        self.yieldGrowthPerTier = yieldGrowthPerTier
        self.passiveRatio = passiveRatio
        self.passiveUnlockCostMultiplier = passiveUnlockCostMultiplier
        self.hire = hire
        self.charUpgrades = charUpgrades
        self.oro = oro
        self.critChanceBase = critChanceBase
        self.critMultiplier = critMultiplier
        self.offlineEfficiencyBase = offlineEfficiencyBase
        self.offlineCapHours = offlineCapHours
        self.floors = floors
    }

    /// Multiplicador de hire efectivo del piso (override o default punitivo).
    public func hireCostMultiplier(for floor: FloorDef) -> Double {
        floor.hireCostMultiplierOverride ?? hire.defaultCostMultiplier
    }

    /// Growth de hire efectivo del piso (override o default).
    public func hireCostGrowth(for floor: FloorDef) -> Double {
        floor.hireCostGrowthOverride ?? hire.defaultCostGrowth
    }

    /// Costo de contratar el tier base de un piso, ANTES de descuentos
    /// permanentes y modificadores temporales.
    ///
    /// Regla del dueño (2026-08-04): el precio es `multiplicador ×` **lo que
    /// realmente rinde un click de ese personaje en ese piso** — o sea el
    /// tapYield del tier POR el `incomeMultiplier` del piso, no el tapYield
    /// pelado. Con el default en 100, contratar cuesta 100 taps de ese mismo
    /// personaje; el piso 1 overridea a 50 para que el primer Fisura sea 50.
    /// Cada compra sube la curva un `hireCostGrowth` (20% por defecto).
    ///
    /// Vive acá y no en `TowerActions` porque el `PacingSimulator` necesita el
    /// mismo número: duplicar la fórmula fue lo que llevó a que el simulador
    /// cotizara distinto que el juego.
    public func hireCost(floor: FloorDef, tapYield: Double, purchases: Int) -> Double {
        hireCostMultiplier(for: floor)
            * tapYield
            * floor.incomeMultiplier
            * pow(hireCostGrowth(for: floor), Double(purchases))
    }
}
