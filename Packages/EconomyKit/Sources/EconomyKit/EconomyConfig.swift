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
        /// Tope de niveles por personaje. Sin él, `effectFactorPerLevel^nivel`
        /// crece sin techo y el número termina en overflow (decisión del dueño,
        /// 2026-08-19: máximo = valor inicial × 2^20).
        public let maxLevel: Int

        public init(
            baseCostMultiplier: Double,
            costGrowth: Double,
            effectFactorPerLevel: Double,
            maxLevel: Int = 20
        ) {
            self.baseCostMultiplier = baseCostMultiplier
            self.costGrowth = costGrowth
            self.effectFactorPerLevel = effectFactorPerLevel
            self.maxLevel = maxLevel
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
    /// Con qué exponente el TAP recibe el `incomeMultiplier` del piso (el pasivo
    /// lo recibe siempre entero). Default `1` = la conducta histórica.
    ///
    /// Es lo que separa la curva del tap de la del pasivo, que hasta el rebalance
    /// eran la misma con un factor (`passiveYield = tapYield × passiveRatio`): un
    /// solo knob para dos curvas que el diseño necesita distintas. El
    /// multiplicador de piso es el único factor que crece con la ALTURA de la
    /// torre (1 → 620), así que bajarle el exponente le saca plata al click del
    /// tier alto —la queja del dueño— **sin tocar el early game**: en el callejón
    /// el multiplicador es 1, y 1^x = 1 para cualquier exponente.
    ///
    /// Opcional para que un `economy.json` viejo o una fixture sin la clave sigan
    /// decodificando: el Codable sintetizado usa `decodeIfPresent` sólo en las
    /// propiedades opcionales, y escribir un `init(from:)` entero por esta sola
    /// clave obligaría a mantener a mano las trece que ya funcionan. El valor
    /// efectivo sale de `tapFloorMultiplier(for:)`, el único lugar donde vive el
    /// default. [TUNEABLE]
    public let tapFloorMultiplierExponent: Double?
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
        tapFloorMultiplierExponent: Double? = nil,
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
        self.tapFloorMultiplierExponent = tapFloorMultiplierExponent
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

    /// El multiplicador de piso que recibe **el tap** (el pasivo y el precio de
    /// contratación reciben `floor.incomeMultiplier` entero, siempre).
    ///
    /// Único lugar donde vive el default del exponente: repetir el `?? 1` en cada
    /// llamador es exactamente cómo se desincronizaron los dos literales `1.8` de
    /// `tierPremium` antes de que ese default se mudara a una constante.
    public func tapFloorMultiplier(for floor: FloorDef) -> Double {
        let exponent = tapFloorMultiplierExponent ?? 1.0
        guard exponent != 1.0 else { return floor.incomeMultiplier }
        return pow(floor.incomeMultiplier, exponent)
    }

    /// Costo de contratar UN TIER CONCRETO en su piso, ANTES de descuentos
    /// permanentes y modificadores temporales. **Ésta es LA fórmula de precio de
    /// contratación, y la única**: no hay otra copia ni otra firma.
    ///
    /// Regla del dueño (2026-08-04): el precio es `multiplicador ×` **lo que
    /// realmente rinde un click de ese personaje en ese piso**. Con el default
    /// en 600, contratar cuesta 600 taps de ese mismo personaje; el callejón
    /// overridea a 25 para que el primer Fisura sea 25. Cada compra sube la
    /// curva un `hireCostGrowth` (6% por defecto desde el rebalance de pacing;
    /// era 20%).
    ///
    /// El factor de piso es `tapFloorMultiplier(for:)` —el MISMO que cobra
    /// `GameActions.applyTap`— y no `floor.incomeMultiplier` crudo. Es lo que
    /// mantiene la regla literal: cuando el rebalance le sacó al tap el
    /// multiplicador de piso, con el `incomeMultiplier` crudo acá contratar el
    /// tier base del reino divino pasaba de 600 clicks a 600 × 620 = 372.000, y
    /// la regla dejaba de ser cierta sin que nada hiciera ruido. Atado al mismo
    /// factor, vale 600 clicks en los diez pisos para cualquier exponente.
    /// (Decisión del dueño, fix round 2 — ver Docs/balance-log.md.)
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
            * tapFloorMultiplier(for: floor)
            * pow(hire.tierPremium, Double(tier - floor.firstTier))
            * pow(hireCostGrowth(for: floor), Double(purchases))
    }
}
