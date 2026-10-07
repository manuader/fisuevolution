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
    /// `cost(k, t, f, n) = mult(k) × tapYield(f) × income(k) × priceGrowthPerTier^(t − f) × growth(k)^n`,
    /// con `f` = tu frontera de merge y `n` = compras previas. Los pisos > 1 usan
    /// estos defaults PUNITIVOS (backfill recién rentable con la frontera 2-3
    /// pisos arriba); el piso 1 overridea a barato en su FloorDef. [TUNEABLE]
    public struct HireConfig: Codable, Sendable, Equatable {
        public let defaultCostMultiplier: Double
        public let defaultCostGrowth: Double
        /// Cuánto sube el precio por cada tier, alrededor del ancla de la
        /// frontera. **1,5**, y lo que importa del número es que sea MENOR QUE 2.
        ///
        /// Es el knob que reemplazó al `tierPremium` en la cuarta ronda de
        /// balance, y el que cierra el agujero estructural que midió la tercera:
        /// el rendimiento crece `yieldGrowthPerTier` (2,8) por tier y fusionar
        /// sólo multiplica por 2, así que un precio atado al rendimiento hacía
        /// que una unidad de tu frontera saliera `(2/2,8)^d` comprando `d` tiers
        /// más abajo — **comprar hondo siempre salía más barato**, y una
        /// compuerta más profunda ABARATABA el juego (medido: N=4 → 6,67 h,
        /// N=6 → 5,34 h; `Docs/balance-log.md`, tercera ronda).
        ///
        /// Con el precio subiendo `P` por tier, una unidad de tu frontera
        /// comprada a profundidad `d` sale `(2/P)^d`, así que el knob parte las
        /// aguas EXACTAMENTE en 2, que es el factor de merge:
        /// - `P > 2` → comprar hondo sale más barato (el agujero de siempre).
        /// - `P = 2` → da exactamente igual: la indiferencia.
        /// - `P < 2` → bajar un tier sale `2/P` más caro. Con 1,5, **1,33× por
        ///   tier**, y la compuerta pasa a ser un dial de dificultad de verdad.
        ///
        /// Lo que hace segura a la mitad `P < 2` es la compuerta: `canHire` no
        /// deja comprar por encima de `frontera − gateTierDistance`, así que el
        /// atajo simétrico —comprar arriba en vez de mergear— no existe. Ése era
        /// el trabajo del `tierPremium` (1,8), que además tenía que irse por
        /// otro motivo: se reiniciaba en cada piso y dejaba la pendiente real
        /// dentro del piso en 2,8 × 1,8 = 5,04, o sea el agujero otra vez.
        /// [TUNEABLE]
        public let priceGrowthPerTier: Double

        /// Cuánto se encarece **tu propia frontera** por cada tier que subís,
        /// POR ENCIMA de lo que ya sube por rendir más. Es la desaceleración
        /// dentro de la run (decisión del dueño, 2026-08-23).
        ///
        /// **El problema que arregla.** Con el precio anclado a la frontera y
        /// nada más, el precio de avanzar crece `yieldGrowthPerTier` por tier y
        /// tu ingreso también: cada tier cuesta el MISMO tiempo que el anterior.
        /// 37 tiers × constante da una duración fija y —lo que importa— **una run
        /// que nunca se traba**. Por eso se podía ir de Fisura a Dios de una
        /// sentada y por eso reencarnar no pagaba: se reencarna para correr una
        /// pared, y no había pared.
        ///
        /// Con `D` puesto, el precio de avanzar crece `yieldGrowthPerTier × D` y
        /// el ingreso sigue creciendo `yieldGrowthPerTier`: **el tiempo por tier
        /// se multiplica por `D` cada vez**. Los primeros pisos quedan ágiles y
        /// los últimos se ponen densos hasta que la run se traba de verdad. Ahí
        /// el prestigio pasa a ser la forma de correr esa pared, que es el rol
        /// que el diseño siempre le dio y que nunca había tenido.
        ///
        /// ⚠️ **El exponente es `frontera − 1`, así que con la frontera en el
        /// tier 1 vale exactamente 1**: el primer Fisura sigue costando 25 sin
        /// ningún caso especial, y el tutorial no se entera. Decisión cerrada del
        /// dueño, respetada por construcción.
        ///
        /// ⚠️ **No toca el invariante de profundidad.** Depende SÓLO de la
        /// frontera, así que a frontera fija no cambia nada entre dos tiers
        /// comprados: comprar hondo sigue costando `(2/priceGrowthPerTier)^d` más
        /// caro. Lo pinea `laEscaladaNoTocaElInvarianteDeProfundidad`.
        /// [TUNEABLE]
        public let frontierEscalationPerTier: Double

        /// **Desde qué tier de frontera empieza a cobrarse la desaceleración.**
        /// Por debajo de este tier la escalada vale 1 y el juego corre como antes.
        ///
        /// Sin esto la escalada es una exponencial desde el tier 1, y una
        /// exponencial no tiene cómo ser suave abajo y densa arriba: o muerde
        /// temprano (medido con `D` 1,6 desde el tier 1: las primeras CINCO runs
        /// se trababan en el tier 7, o sea en el callejón, que es la frustración
        /// que el diseño quiere evitar) o no muerde nunca. El umbral es lo que
        /// compra las dos mitades de la forma que pidió el dueño: **los primeros
        /// pisos ágiles —el tutorial no se toca— y los últimos densos**.
        ///
        /// Con `1` la escalada corre desde el principio, que es la conducta sin
        /// umbral. [TUNEABLE]
        public let frontierEscalationFromTier: Int
        /// Cuántos tiers por ENCIMA de un personaje tiene que estar tu frontera
        /// de merge (`run.maxTierReached`) para poder contratarlo.
        ///
        /// Es la compuerta de contratación, y desde el 2026-08-22 se mide en
        /// TIERS y no en pisos (decisión del dueño; el diagnóstico completo está
        /// en `Docs/superpowers/specs/2026-08-22-compuerta-por-distancia-design.md`).
        /// La regla vieja pedía el PISO de arriba desbloqueado, pero un piso son
        /// cuatro tiers y la pantalla de laburos los vende todos: lo que ataba
        /// era el caso más barato —el TOPE del piso habilitado, a UN tier de la
        /// frontera, o sea DOS unidades de merge—, así que todo pasaba entre dos
        /// pisos contiguos y el ascensor no hacía falta. Medida en tiers, la
        /// distancia es la misma compres lo que compres: `2^distancia` unidades.
        ///
        /// El tier base de la torre queda EXENTO —es el motor del early game y
        /// el tutorial lo enseña—: la regla corre del segundo tier para arriba.
        /// Es la única excepción, y por eso los dos parches por piso que había
        /// (el callejón entero y `hireGateExempt` del urbano) ya no existen.
        /// [TUNEABLE]
        public let gateTierDistance: Int

        /// El default de `priceGrowthPerTier` para las FIXTURES: **2,0**, el
        /// factor de merge, o sea la indiferencia exacta —bajar un tier no
        /// abarata ni encarece—. No es el valor del juego (1,5): es el neutro,
        /// el único que un test que no habla de precios puede omitir sin quedar
        /// apoyado en una política. El `economy.json` real declara la clave o no
        /// carga (ver `init(from:)`).
        public static let neutralPriceGrowthPerTier = 2.0

        /// La desaceleración APAGADA: con 1,0 la fórmula queda idéntica a la de
        /// antes del 2026-08-23 (cada tier cuesta lo mismo que el anterior y la
        /// run no se traba nunca). Es el default del init para las FIXTURES —un
        /// test que no habla de desaceleración no tiene que elegir una política—
        /// y es justo por eso que en el JSON la clave es obligatoria.
        public static let noFrontierEscalation = 1.0

        /// El umbral que no recorta nada: la escalada corre desde el primer tier.
        public static let escalationFromFirstTier = 1

        /// La compuerta APAGADA: cualquier tier se contrata con sólo tener el
        /// piso abierto.
        ///
        /// Es un sentinel, no una distancia de cero tiers —que sería "podés
        /// contratar lo que ya alcanzaste" y es otra regla—: `canHire` trata
        /// cualquier valor ≤ 0 como apagada. Existe para las FIXTURES, no para
        /// el juego: el `economy.json` real declara la clave o no carga (ver
        /// `init(from:)`), así que un test que no habla de la compuerta no tiene
        /// que declararla y ninguna config de producción puede caer acá por
        /// olvido.
        public static let noTierGate = 0

        public init(
            defaultCostMultiplier: Double,
            defaultCostGrowth: Double,
            priceGrowthPerTier: Double = HireConfig.neutralPriceGrowthPerTier,
            gateTierDistance: Int = HireConfig.noTierGate,
            frontierEscalationPerTier: Double = HireConfig.noFrontierEscalation,
            frontierEscalationFromTier: Int = HireConfig.escalationFromFirstTier
        ) {
            self.defaultCostMultiplier = defaultCostMultiplier
            self.defaultCostGrowth = defaultCostGrowth
            self.priceGrowthPerTier = priceGrowthPerTier
            self.gateTierDistance = gateTierDistance
            self.frontierEscalationPerTier = frontierEscalationPerTier
            self.frontierEscalationFromTier = frontierEscalationFromTier
        }

        /// Decoder a mano porque los dos knobs de abajo se agregaron después: el
        /// Codable SINTETIZADO exige toda clave no-opcional y se saltea los
        /// valores por defecto de las propiedades, así que declararlos y ya
        /// dejaría a las fixtures tirando `keyNotFound`. Es el mismo motivo por
        /// el que `RunState` y `FloorDef` decodifican a mano.
        ///
        /// Los tres van con `decode` y no con `decodeIfPresent`: **ninguno tiene
        /// un default histórico inocente**. El de la compuerta sería CERO, que la
        /// apaga entera; el del precio sería 2,0, que es justo el filo del
        /// cuchillo (`P = 2` = comprar hondo cuesta exactamente lo mismo); y el
        /// de la escalada sería 1,0, que es "la run no se traba nunca" — la forma
        /// de curva que la ronda del 2026-08-23 vino a arreglar. Un
        /// `economy.json` al que se le caiga cualquiera de las tres tiene que no
        /// cargar, en vez de quedarse sin regla en silencio.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            defaultCostMultiplier = try container.decode(Double.self, forKey: .defaultCostMultiplier)
            defaultCostGrowth = try container.decode(Double.self, forKey: .defaultCostGrowth)
            priceGrowthPerTier = try container.decode(Double.self, forKey: .priceGrowthPerTier)
            gateTierDistance = try container.decode(Int.self, forKey: .gateTierDistance)
            frontierEscalationPerTier = try container.decode(
                Double.self, forKey: .frontierEscalationPerTier
            )
            // Ésta SÍ con `decodeIfPresent`, al revés que las tres de arriba: su
            // default (1) es "la escalada corre desde el principio", que es la
            // conducta sin umbral y no una política escondida. Con la escalada
            // apagada (`D = 1`) el umbral no significa nada.
            frontierEscalationFromTier = try container.decodeIfPresent(
                Int.self, forKey: .frontierEscalationFromTier
            ) ?? HireConfig.escalationFromFirstTier
        }

        enum CodingKeys: String, CodingKey {
            case defaultCostMultiplier, defaultCostGrowth, priceGrowthPerTier
            case gateTierDistance, frontierEscalationPerTier, frontierEscalationFromTier
        }
    }

    /// Mejoras POR PERSONAJE compradas con plata (se pierden al reencarnar).
    /// Efecto: `1 + nivel × effectStepPerLevel` sobre el income del tipo.
    /// Costo: `baseCostMultiplier × tapYield(tier) × costGrowth^nivel`.
    public struct CharUpgradesConfig: Codable, Sendable, Equatable {
        public let baseCostMultiplier: Double
        public let costGrowth: Double
        /// Cuánto SUMA cada nivel al multiplicador del tipo. Con 1,0 la
        /// secuencia es ×2, ×3, ×4 … ×20, que es la que pidió el dueño el
        /// 2026-08-22.
        ///
        /// Se llamaba `effectFactorPerLevel` y era la BASE de una potencia
        /// (`2^nivel`, o sea ×1.048.576 al nivel 20). El nombre viejo mentiría
        /// sobre la fórmula nueva, y esta rama ya pagó dos veces por comentarios
        /// y nombres que mentían. [TUNEABLE]
        public let effectStepPerLevel: Double
        /// Tope de niveles por personaje.
        ///
        /// **19**, que con el paso en 1,0 clava el tope en ×20 —el número que
        /// escribió el dueño—. Con 20 niveles el tope sería ×21, que nadie pidió.
        ///
        /// Ya no existe para frenar un overflow: eso era problema del `2^nivel`
        /// viejo (decisión del dueño 2026-08-19), y una recta no desborda. Hoy
        /// su único trabajo es ser ese ×20. [TUNEABLE]
        public let maxLevel: Int

        public init(
            baseCostMultiplier: Double,
            costGrowth: Double,
            effectStepPerLevel: Double,
            maxLevel: Int = 19
        ) {
            self.baseCostMultiplier = baseCostMultiplier
            self.costGrowth = costGrowth
            self.effectStepPerLevel = effectStepPerLevel
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
        /// Desde qué piso el botón de reencarnar EXISTE aunque todavía no haya
        /// ORO por cobrar (muestra el progreso hacia el próximo): id de
        /// `floors[]`, decisión del dueño 2026-08-28 ("al llegar a lujo").
        /// Opcional por la misma razón que `tapFloorMultiplierExponent`: un
        /// `economy.json` viejo o una fixture sin la clave siguen decodificando
        /// y sin ella el botón se comporta como siempre (aparece con el ORO).
        /// [TUNEABLE]
        public let prestigeTeaserFloorId: String?

        public init(
            divisor: Double,
            exponent: Double,
            globalMultiplierPerOro: Double,
            prestigeTeaserFloorId: String? = nil
        ) {
            self.divisor = divisor
            self.exponent = exponent
            self.globalMultiplierPerOro = globalMultiplierPerOro
            self.prestigeTeaserFloorId = prestigeTeaserFloorId
        }
    }

    public let schemaVersion: Int
    public let baseTapYieldTier1: Double
    public let yieldGrowthPerTier: Double
    public let passiveRatio: Double
    public let passiveUnlockCostMultiplier: Double
    /// Con qué exponente el TAP recibe el `incomeMultiplier` del piso (el pasivo
    /// lo recibe siempre entero; el PRECIO de contratación lo recibe con este
    /// mismo exponente desde el rebalance de pacing — ver `hireCost`).
    /// Default `1` = la conducta histórica.
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
    /// Desde cuántos segundos afuera aparece el popup de ganancias. Lo de menos
    /// se acredita igual, en silencio.
    ///
    /// Opcional por el mismo motivo que `tapFloorMultiplierExponent`: el
    /// `economy.json` viejo y las fixtures sin la clave siguen decodificando, y
    /// el valor efectivo sale de `offlinePopupThreshold`, el único lugar donde
    /// vive el default. [TUNEABLE]
    public let offlinePopupMinSeconds: Double?
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
        offlinePopupMinSeconds: Double? = nil,
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
        self.offlinePopupMinSeconds = offlinePopupMinSeconds
        self.floors = floors
    }

    public var offlinePopupThreshold: TimeInterval { offlinePopupMinSeconds ?? 30 }

    /// Multiplicador de hire efectivo del piso (override o default punitivo).
    public func hireCostMultiplier(for floor: FloorDef) -> Double {
        floor.hireCostMultiplierOverride ?? hire.defaultCostMultiplier
    }

    /// Growth de hire efectivo del piso (override o default).
    ///
    /// El default es 6 % por compra y **el callejón overridea a 3 %**. La
    /// asimetría es a propósito y está medida (quinta ronda de
    /// `Docs/balance-log.md`): este factor compone sobre el contador de compras
    /// del MISMO tipo, y ese contador **se duplica con cada tier** —subir uno
    /// pide `2^(frontera−1)` unidades—, así que `growth^(2^k)` es una doble
    /// exponencial. Arriba eso no molesta porque hay varios tipos comprables y
    /// el contador se reparte; **abajo no hay dónde repartirlo**: hasta que la
    /// frontera llega a `gateTierDistance + 1` el tier base es lo único que la
    /// compuerta habilita, así que la cuesta entera se paga con una sola curva
    /// y con el 6 % el último tier salía ×32 el anterior.
    ///
    /// Bajar el GLOBAL fue lo primero que se probó y midió peor: arregla el
    /// arranque y desarma la pared de la desaceleración (de seis runs trabadas a
    /// dos con 1,03). Lo pinea `thePreGateClimbHasNoWallInIt`.
    public func hireCostGrowth(for floor: FloorDef) -> Double {
        floor.hireCostGrowthOverride ?? hire.defaultCostGrowth
    }

    /// El multiplicador de piso que recibe **el tap** — y, desde el rebalance de
    /// pacing, también **el precio de contratación** (ver `hireCost`), que es lo
    /// que mantiene literal la regla de los clicks. El único que sigue recibiendo
    /// `floor.incomeMultiplier` entero y siempre es **el pasivo**.
    ///
    /// Único lugar donde vive el default del exponente: repetir el `?? 1` en cada
    /// llamador es exactamente cómo se desincronizaron los dos literales `1.8` del
    /// viejo `tierPremium` antes de que ese default se mudara a una constante.
    public func tapFloorMultiplier(for floor: FloorDef) -> Double {
        let exponent = tapFloorMultiplierExponent ?? 1.0
        guard exponent != 1.0 else { return floor.incomeMultiplier }
        return pow(floor.incomeMultiplier, exponent)
    }

    /// Costo de contratar UN TIER CONCRETO en su piso, ANTES de descuentos
    /// permanentes y modificadores temporales. **Ésta es LA fórmula de precio de
    /// contratación, y la única**: no hay otra copia ni otra firma.
    ///
    /// **Regla del dueño (2026-08-23), en dos renglones:**
    /// 1. Contratar **a tu frontera** cuesta `hireCostMultiplier` clicks de ese
    ///    personaje —600 en los nueve pisos de arriba, 25 en el callejón, que es
    ///    lo que ancla al primer Fisura—.
    /// 2. Cada tier que bajás descuenta sólo `priceGrowthPerTier` (1,5), y
    ///    fusionar necesita el DOBLE de unidades: bajar un tier deja la unidad de
    ///    frontera 2/1,5 = **1,33× más cara**. Comprar hondo dejó de ser un atajo.
    ///
    /// **Reemplaza a la regla de los 600 clicks del 2026-08-04** ("el tier base
    /// de un piso cuesta 600 veces lo que rinde un click SUYO ahí"), que ataba el
    /// precio a `tapYield(tier)` — la misma curva que el rendimiento, 2,8 por
    /// tier. Eso hacía que una unidad de tu frontera comprada `d` tiers abajo
    /// saliera `(2/2,8)^d`, o `(2/5,04)^d` dentro de un piso con el
    /// `tierPremium` puesto: **comprar hondo siempre salía más barato** y la
    /// compuerta por tiers abarataba el juego en vez de encarecerlo. El
    /// diagnóstico completo y las tres salidas están en `Docs/balance-log.md`
    /// (tercera ronda); el dueño eligió ésta.
    ///
    /// **Por qué el ancla tiene que ser la frontera y no el tier.** El diseño
    /// quiere dos cosas a la vez: que subir un tier cueste siempre lo mismo en
    /// TIEMPO (o sea precio ∝ rendimiento de tu frontera, que es de donde sale tu
    /// ingreso) y que la pendiente por tier del precio sea ≤ 2 (o sea menos que
    /// el factor de merge). Un precio que dependa SÓLO del tier no puede tener
    /// las dos: la primera le fija la pendiente en 2,8. Anclarlo a la frontera
    /// separa el nivel (2,8 por tier de frontera, que mantiene el pacing plano)
    /// de la pendiente (1,5 por tier comprado, que cierra el atajo).
    ///
    /// El factor de piso es `tapFloorMultiplier(for:)` —el MISMO que cobra
    /// `GameActions.applyTap`— y no `floor.incomeMultiplier` crudo. Es lo que
    /// mantiene la regla literal: cuando el rebalance le sacó al tap el
    /// multiplicador de piso, con el `incomeMultiplier` crudo acá contratar el
    /// tier base del reino divino pasaba de 600 clicks a 600 × 620 = 372.000, y
    /// la regla dejaba de ser cierta sin que nada hiciera ruido.
    ///
    /// ⚠️ **El exponente puede ser NEGATIVO y está bien.** La pantalla de laburos
    /// cotiza también lo que todavía no podés comprar: un tipo por encima de tu
    /// frontera sale `1,5^(tier − frontera)` **más** caro, que es el orden que la
    /// vitrina necesita. Nadie puede aprovecharlo porque `TowerActions.canHire`
    /// no autoriza nada por encima de `frontera − gateTierDistance`.
    ///
    /// ⚠️ **La única costura es el callejón**, y es el precio de la decisión
    /// cerrada del Fisura a 25: su multiplicador (25 contra 600) lo deja 24×
    /// barato, así que comprar en el callejón y subir es un descuento acotado —no
    /// compuesto— que **se agota solo** en el tier 22 de 37, a mitad de la torre
    /// (`25 × 1,33^(f−4)` alcanza a `600 × 1,33^gate`). Medido en la cuarta
    /// ronda; lo pinea `elDescuentoDelCallejonSeAgotaSolo`.
    ///
    /// Vive acá y no en `TowerActions` porque el `PacingSimulator` necesita el
    /// mismo número: duplicar la fórmula fue lo que llevó a que el simulador
    /// cotizara distinto que el juego.
    ///
    /// - Parameter frontierTier: tu frontera de merge (`run.maxTierReached`), el
    ///   ancla del precio.
    public func hireCost(floor: FloorDef, tier: Int, frontierTier: Int, purchases: Double) -> Double {
        hireCostMultiplier(for: floor)
            * StandardEconomy(config: self).tapYield(forTier: frontierTier)
            * tapFloorMultiplier(for: floor)
            * pow(
                hire.frontierEscalationPerTier,
                Double(max(0, frontierTier - hire.frontierEscalationFromTier))
            )
            * pow(hire.priceGrowthPerTier, Double(tier - frontierTier))
            * pow(hireCostGrowth(for: floor), purchases)
    }
}
