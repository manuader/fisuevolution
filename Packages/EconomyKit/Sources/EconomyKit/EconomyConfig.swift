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
    /// `cost(k, t, n) = mult(k) × tapYield(t) × income(k) × tierPremium^(t − firstTier(k)) × growth(k)^n`,
    /// con `n` = compras previas. Los pisos > 1 usan estos defaults PUNITIVOS
    /// (backfill recién rentable con la frontera 2-3 pisos arriba); el piso 1
    /// overridea a barato en su FloorDef. [TUNEABLE]
    public struct HireConfig: Codable, Sendable, Equatable {
        /// Premium por defecto cuando el JSON no lo declara. Vive acá y no
        /// repetido en el init y el decoder: dos literales 1.8 se desincronizan.
        public static let defaultTierPremium = 1.8

        public let defaultCostMultiplier: Double
        public let defaultCostGrowth: Double
        /// Recargo por cada tier POR ENCIMA del tier base de su piso.
        ///
        /// La pantalla de laburos vende cualquier tipo desbloqueado, no sólo el
        /// tier base del piso: sin recargo, comprar el tier alto directo sería un
        /// atajo que saltea la mecánica central del juego. Con `tapYield`
        /// creciendo 2,8×/tier y premium 1,8, subir un tier cuesta ~5×, o sea
        /// bastante más que las DOS unidades del tier de abajo que hacen falta
        /// para mergearlo: fusionar siempre gana. [TUNEABLE]
        public let tierPremium: Double

        public init(
            defaultCostMultiplier: Double,
            defaultCostGrowth: Double,
            tierPremium: Double = HireConfig.defaultTierPremium
        ) {
            self.defaultCostMultiplier = defaultCostMultiplier
            self.defaultCostGrowth = defaultCostGrowth
            self.tierPremium = tierPremium
        }

        /// Decoder a mano por `tierPremium`, que se agregó después: el Codable
        /// SINTETIZADO exige toda clave no-opcional y se saltea los valores por
        /// defecto de las propiedades, así que un `economy.json` (o una fixture)
        /// sin la clave tiraría `keyNotFound` y la config no cargaría. Es el
        /// mismo motivo por el que `RunState` y `FloorDef` decodifican a mano.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            defaultCostMultiplier = try container.decode(Double.self, forKey: .defaultCostMultiplier)
            defaultCostGrowth = try container.decode(Double.self, forKey: .defaultCostGrowth)
            tierPremium = try container.decodeIfPresent(Double.self, forKey: .tierPremium)
                ?? HireConfig.defaultTierPremium
        }

        enum CodingKeys: String, CodingKey {
            case defaultCostMultiplier, defaultCostGrowth, tierPremium
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

    /// Costo de contratar UN TIER CONCRETO en su piso, ANTES de descuentos
    /// permanentes y modificadores temporales. **Ésta es LA fórmula de precio de
    /// contratación**: no hay otra copia, y la firma vieja de abajo delega acá.
    ///
    /// Regla del dueño (2026-08-04): el precio es `multiplicador ×` **lo que
    /// realmente rinde un click de ese personaje en ese piso** — o sea el
    /// tapYield del tier POR el `incomeMultiplier` del piso, no el tapYield
    /// pelado. Con el default en 100, contratar cuesta 100 taps de ese mismo
    /// personaje; el piso 1 overridea a 50 para que el primer Fisura sea 50.
    /// Cada compra sube la curva un `hireCostGrowth` (20% por defecto).
    ///
    /// El factor nuevo es `tierPremium^(tier − firstTier)`: para el tier BASE de
    /// un piso vale 1, así que los precios de siempre —y sus pins— no se mueven;
    /// sólo pone precio a los tiers que antes no se podían comprar (§5.2).
    ///
    /// Vive acá y no en `TowerActions` porque el `PacingSimulator` necesita el
    /// mismo número: duplicar la fórmula fue lo que llevó a que el simulador
    /// cotizara distinto que el juego.
    public func hireCost(floor: FloorDef, tier: Int, purchases: Int) -> Double {
        hireCostMultiplier(for: floor)
            * StandardEconomy(config: self).tapYield(forTier: tier)
            * floor.incomeMultiplier
            * pow(hire.tierPremium, Double(tier - floor.firstTier))
            * pow(hireCostGrowth(for: floor), Double(purchases))
    }

    /// Firma vieja, conservada por los pins que la leen (`GameContentValidationTests`):
    /// cotiza el TIER BASE del piso.
    ///
    /// ⚠️ `tapYield` es redundante y **no se usa**: todos sus llamadores le pasan
    /// `tapYield(forTier: floor.firstTier)`, que es exactamente lo que la fórmula
    /// recalcula. Se ignora a propósito —tener dos fuentes para el mismo número
    /// es justo el bug que este archivo documenta— así que si necesitás cotizar
    /// OTRO tier, usá `hireCost(floor:tier:purchases:)`.
    public func hireCost(floor: FloorDef, tapYield: Double, purchases: Int) -> Double {
        hireCost(floor: floor, tier: floor.firstTier, purchases: purchases)
    }
}
