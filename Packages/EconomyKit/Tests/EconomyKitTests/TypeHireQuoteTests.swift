import Foundation
import Testing
@testable import EconomyKit

// MARK: - Cotización de contratación POR TIPO (rediseño de UI §5.2)
//
// La pantalla de laburos vende CUALQUIER tipo desbloqueado, no sólo el tier base
// del piso visible, y desde el 2026-08-23 el precio no sale del tier que comprás
// sino de **tu frontera**: `mult × tapYield(frontera) × priceGrowthPerTier^(tier
// − frontera) × growth^compras`.
//
// El atajo que hay que cerrar cambió de mano, y por eso los asserts de este
// archivo están dados vuelta respecto de la versión anterior. El de "comprar el
// tier alto directo en vez de mergear dos del anterior" lo cierra la COMPUERTA
// (`canHire` no autoriza nada por encima de `frontera − gateTierDistance`), no
// el precio. El que sí es del precio es el contrario —comprar hondo y subir
// mergeando—, y lo cierra `priceGrowthPerTier < 2`: bajar un tier abarata 1,5×
// pero duplica cuántas unidades hacen falta, así que la unidad de frontera sale
// 2/1,5 = 1,33× más cara por cada tier de profundidad.

@Suite("Cotización de contratación por tipo (§5.2)")
struct TypeHireQuoteTests {
    let config = fxConfig()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    private func quote(type typeId: String, state: PlayerState) -> HireQuote? {
        TowerActions.hireQuote(
            typeId: typeId, state: state, config: config,
            floorTable: floorTable, tiers: tiers
        )
    }

    private func quote(floor ordinal: Int, state: PlayerState) -> HireQuote? {
        TowerActions.hireQuote(
            floorOrdinal: ordinal, state: state, tiers: tiers,
            floorTable: floorTable, config: config
        )
    }

    // MARK: El tier base no se mueve

    /// El pin que sostiene a todos los demás: los dos caminos de cotización —por
    /// piso (el atajo del HUD) y por tipo (FisuJobs)— cobran el mismo número por
    /// el tier base de cada piso. Es lo que garantiza que el primer Fisura siga
    /// costando lo que el dueño clavó.
    @Test("el tier base de cada piso cuesta lo mismo por tipo que por piso")
    func tierBaseCuestaIgualPorLosDosCaminos() throws {
        let (state, _, _) = try fxStateAndTower()
        for ordinal in 0..<floorTable.count {
            let porPiso = try #require(quote(floor: ordinal, state: state))
            let porTipo = try #require(quote(type: porPiso.type.id, state: state))
            #expect(porTipo.floorOrdinal == ordinal, "\(porPiso.type.id) cotizó en otro piso")
            #expect(abs(porTipo.cost - porPiso.cost) < 1e-9, "\(porPiso.type.id): \(porTipo.cost) ≠ \(porPiso.cost)")
        }
    }

    /// Los mismos números explícitos, por si algún día los dos caminos se
    /// rompieran juntos. La fixture arranca con la frontera en T1, así que:
    /// - `a` (T1, f1) sale su multiplicador limpio: 15 × tapYield(1) × 1,5⁰ = **15**.
    /// - `c_law` (T3, f2) está DOS tiers por encima de la frontera: 100 ×
    ///   tapYield(1) × 1,5² = **225**.
    ///
    /// El 1444 de antes salía de `100 × tapYield(T3)` = 100 × 3,8²: el precio
    /// seguía a lo que rinde el personaje que comprás. Ahora sigue a lo que rinde
    /// TU frontera, y `yieldGrowthPerTier` (3,8 en la fixture) ya no aparece en
    /// la cuenta de un tipo cotizado a frontera fija.
    @Test("el ancla es la frontera: a = 15, c_law = 225")
    func elPrecioSeAnclaALaFrontera() throws {
        let (state, _, _) = try fxStateAndTower()
        #expect(state.run.maxTierReached == 1, "la fixture tiene que arrancar con la frontera en T1")
        let a = try #require(quote(type: "a", state: state))
        #expect(abs(a.cost - 15) < 1e-9)
        let cLaw = try #require(quote(type: "c_law", state: state))
        #expect(abs(cLaw.cost - 225) < 1e-9)
    }

    /// Y la frontera se MUEVE el precio: mergear dos `a` deja la frontera en T2 y
    /// todo el catálogo se multiplica por `yieldGrowthPerTier / priceGrowthPerTier`
    /// = 3,8 / 1,5 = **2,533×**.
    ///
    /// Es la consecuencia user-visible de la regla nueva y por eso tiene su
    /// propio test: los precios de FisuJobs suben cada vez que la torre sube. Lo
    /// que se mantiene plano es el TIEMPO —tu ingreso también sale de la
    /// frontera—, que es exactamente lo que la regla vieja no lograba.
    @Test("la frontera mueve todo el catálogo: ×3,8/1,5 por tier")
    func laFronteraMueveTodoElCatalogo() throws {
        var (state, _, _) = try fxStateAndTower()
        let antes = try #require(quote(type: "a", state: state)).cost
        state.run.maxTierReached = 2
        let despues = try #require(quote(type: "a", state: state)).cost
        #expect(abs(despues / antes - 3.8 / 1.5) < 1e-9, "×\(despues / antes)")
    }

    // MARK: La regla anti-atajo (dada vuelta el 2026-08-23)

    /// **El invariante nuevo, y el que reemplaza a la regla de los 600 clicks:**
    /// obtener una unidad de tu frontera comprando `d` tiers más abajo cuesta
    /// `(2 / priceGrowthPerTier)^d`, o sea **más caro cuanto más hondo compres**.
    /// Con 1,5, bajar un tier sale 1,33× más.
    ///
    /// ⚠️ **Este assert es el opuesto exacto del que había acá hasta el
    /// 2026-08-22** (`costo(t+1) > 2 × costo(t)`), y no es un aflojamiento: es
    /// que las dos condiciones son complementarias y no pueden valer juntas.
    /// `costo(t+1)/costo(t) > 2` ⟺ comprar hondo sale más barato;
    /// `costo(t+1)/costo(t) < 2` ⟺ comprar arriba sale más barato. El filo es
    /// exactamente el factor de merge.
    ///
    /// El diseño eligió el segundo lado, y el primero lo cubre la COMPUERTA en
    /// vez del precio: `canHire` no autoriza nada por encima de
    /// `frontera − gateTierDistance`, así que "comprar arriba" no es una compra
    /// disponible. El agujero que quedaba abierto —comprar hondo— era el que
    /// medía la tercera ronda: con el precio atado a `tapYield(tier)` la unidad
    /// de frontera salía `(2/2,8)^d`, y una compuerta más profunda ABARATABA el
    /// juego (N=4 → 6,67 h · N=6 → 5,34 h; `Docs/balance-log.md`).
    /// ⚠️ **La excepción es el salto de MULTIPLICADOR entre pisos**, y en el
    /// juego real es el ancla del Fisura: el callejón cotiza con 25 y todo lo
    /// demás con 600, así que comprar ahí sale 24× menos. Es un descuento
    /// ACOTADO —no compuesto— y se agota solo cuando la frontera sube lo
    /// suficiente; quien lo pinea contra el contenido real es
    /// `elDescuentoDelCallejonSeAgotaSolo`. Acá se mide la misma costura en la
    /// fixture (15 contra 100) para que quede escrita y no se lea como un bug.
    @Test("bajar un tier encarece la unidad de frontera 2/1,5 = 1,33×")
    func bajarUnTierEncareceLaUnidadDeFrontera() throws {
        let frontier = 4
        let unidadDeFrontera = { (tier: Int) -> Double in
            let floor = self.floorTable[self.floorTable.ordinal(forTier: tier)]
            let unidadesQueHacenFalta = pow(2.0, Double(frontier - tier))
            return unidadesQueHacenFalta * self.config.hireCost(
                floor: floor, tier: tier, frontierTier: frontier, purchases: 0
            )
        }
        for tier in 1..<frontier {
            let mismoMultiplicador = config.hireCostMultiplier(for: floorTable[floorTable.ordinal(forTier: tier)])
                == config.hireCostMultiplier(for: floorTable[floorTable.ordinal(forTier: tier + 1)])
            guard mismoMultiplicador else { continue }
            let masCaro = unidadDeFrontera(tier) / unidadDeFrontera(tier + 1)
            #expect(abs(masCaro - 2 / 1.5) < 1e-9, "T\(tier) → T\(tier + 1): ×\(masCaro)")
        }
        // La costura: f1 cotiza con 15 y f2 con 100, así que bajar de T3 a T2
        // abarata 100/15 ÷ 1,33 = 5×. Es lo único que rompe la monotonía.
        #expect(abs(unidadDeFrontera(3) / unidadDeFrontera(2) - 5) < 1e-9)
    }

    /// Y lo mismo por el camino que usa la pantalla: `b` (T2) vive en f1 igual
    /// que `a` (T1), así que su precio sale del mismo multiplicador barato y la
    /// única diferencia es `priceGrowthPerTier` = 1,5.
    @Test("el quote sube 1,5× por tier: b sale 22,5 y a sale 15")
    func laPendienteSeVeEnElQuote() throws {
        let (state, _, _) = try fxStateAndTower()
        let a = try #require(quote(type: "a", state: state))
        let b = try #require(quote(type: "b", state: state))
        #expect(abs(b.cost - 15 * 1.5) < 1e-9)
        // Menos que el doble: es el número que hace que mergear dos `a` para
        // llegar a `b` NO sea el camino barato. Lo que impide el atajo es la
        // compuerta, no el precio.
        #expect(b.cost < 2 * a.cost)
    }

    /// El invariante con los números que SE ENVÍAN, no con los de la fixture:
    /// `yieldGrowthPerTier` 2,8 y `priceGrowthPerTier` 1,5.
    @Test("con los valores reales el precio sube 1,5× por tier")
    func reglaAntiAtajoConValoresReales() throws {
        let real = EconomyConfig(
            schemaVersion: 2,
            baseTapYieldTier1: 1,
            yieldGrowthPerTier: 2.8,
            passiveRatio: 0.5,
            passiveUnlockCostMultiplier: 60,
            hire: .init(defaultCostMultiplier: 600, defaultCostGrowth: 1.06, priceGrowthPerTier: 1.5),
            charUpgrades: .init(baseCostMultiplier: 50, costGrowth: 4, effectStepPerLevel: 1),
            oro: .init(divisor: 3_000_000_000_000, exponent: 0.25, globalMultiplierPerOro: 0.18),
            critChanceBase: 0,
            critMultiplier: 5,
            offlineEfficiencyBase: 0.35,
            offlineCapHours: 10,
            floors: [
                FloorDef(
                    id: "alley", background: "alley", firstTier: 1, lastTier: 4,
                    capacity: 10, incomeMultiplier: 1.0, hireCostMultiplierOverride: 25,
                    hireCostGrowthOverride: 1.03
                ),
                FloorDef(
                    id: "urban", background: "urban", firstTier: 5, lastTier: 8,
                    capacity: 10, incomeMultiplier: 2.0
                ),
            ]
        )
        #expect(real.hire.priceGrowthPerTier == 1.5)
        for floor in real.floors {
            for tier in floor.firstTier..<floor.lastTier {
                let bajo = real.hireCost(floor: floor, tier: tier, frontierTier: 8, purchases: 0)
                let alto = real.hireCost(floor: floor, tier: tier + 1, frontierTier: 8, purchases: 0)
                #expect(abs(alto / bajo - 1.5) < 1e-9, "\(floor.id) T\(tier): ×\(alto / bajo)")
                #expect(alto < 2 * bajo, "la pendiente tiene que quedar por DEBAJO del factor de merge")
            }
        }
        // Y el tier base sigue anclado donde el dueño lo dejó: 25 el primero
        // (bajó de 50 el 2026-08-18 para acortar el tutorial). El SEGUNDO sigue
        // al growth por compra, que bajó dos veces por la misma razón —compone
        // sobre un contador que se duplica con cada tier—: 30 con el 1,2 global,
        // 26,5 con el 1,06 global y **25,75 con el 1,03 que el callejón
        // overridea** (quinta ronda, el muro de la cuesta pre-compuerta; el
        // global se quedó en 1,06 porque es una pata de la desaceleración). El
        // ancla del dueño es el primero, y la frontera al empezar una partida es
        // T1 —el Fisura con el que arrancás—, así que ninguna lo mueve.
        let alley = real.floors[0]
        #expect(real.hireCost(floor: alley, tier: 1, frontierTier: 1, purchases: 0) == 25)
        #expect(abs(real.hireCost(floor: alley, tier: 1, frontierTier: 1, purchases: 1) - 25.75) < 1e-9)
    }

    // MARK: La curva es por TIPO

    /// `hireCounts` (por piso) deja de alimentar el exponente: lo hace
    /// `hireCountsByType`. En f1 el growth es 1,15 (override de la fixture).
    @Test("la curva escala por tipo y no por piso")
    func curvaPorTipo() throws {
        var (state, _, _) = try fxStateAndTower()
        // Contador POR PISO cargado: no tiene que mover el precio de nadie.
        state.run.hireCounts["f1"] = 4
        let base = try #require(quote(type: "a", state: state))
        #expect(abs(base.cost - 15) < 1e-9)
        #expect(base.purchases == 0)

        state.run.hireCountsByType["a"] = 2
        let dos = try #require(quote(type: "a", state: state))
        #expect(abs(dos.cost - 15 * 1.15 * 1.15) < 1e-9)
        #expect(dos.purchases == 2)

        // Comprar OTRO tipo del mismo piso no escala al primero.
        state.run.hireCountsByType["b"] = 7
        let despues = try #require(quote(type: "a", state: state))
        #expect(abs(despues.cost - dos.cost) < 1e-9)
    }

    /// Y de punta a punta: el quote por tipo entra al `hire` EXISTENTE sin
    /// cambios de firma, y es él quien mueve el contador que cotiza la próxima.
    @Test("el quote por tipo entra al hire existente y encarece al mismo tipo")
    func hireConQuotePorTipo() throws {
        var (state, tower, table) = try fxStateAndTower()
        state.run.coins = 10_000

        let primero = try #require(quote(type: "b", state: state))
        let colocado = try TowerActions.hire(quote: primero, state: &state, tower: &tower, floorTable: table, config: config)
        #expect(colocado.floorOrdinal == 0)
        #expect(colocado.typeId == "b")
        #expect(state.run.hireCountsByType["b"] == 1)
        #expect(state.run.units["b"] == 1)

        let segundo = try #require(quote(type: "b", state: state))
        #expect(segundo.purchases == 1)
        #expect(abs(segundo.cost - primero.cost * 1.15) < 1e-9)
        // Y el vecino de piso quedó donde estaba.
        let vecino = try #require(quote(type: "a", state: state))
        #expect(abs(vecino.cost - 15) < 1e-9)
    }

    // MARK: Qué NO se cotiza

    @Test("el nodo de elección no se contrata")
    func nodoDeEleccionNoCotiza() throws {
        let (state, _, _) = try fxStateAndTower()
        #expect(quote(type: "choice", state: state) == nil)
    }

    @Test("un typeId inexistente no cotiza")
    func typeIdInexistenteNoCotiza() throws {
        let (state, _, _) = try fxStateAndTower()
        #expect(quote(type: "no_existe", state: state) == nil)
    }

    // MARK: Piso y descuentos

    @Test("el piso del quote es el del tipo, no el visible")
    func pisoDelQuoteEsElDelTipo() throws {
        let (state, _, _) = try fxStateAndTower()
        #expect(try #require(quote(type: "b", state: state)).floorOrdinal == 0)
        #expect(try #require(quote(type: "d", state: state)).floorOrdinal == 1)
    }

    /// Los MISMOS tres descuentos que la cotización por piso: `costMultiplier`
    /// del caller, el modificador temporal `.spawnCostMultiplier` y el descuento
    /// permanente de prestigio.
    @Test("aplica los mismos tres descuentos que la cotización por piso")
    func aplicaLosTresDescuentos() throws {
        var (state, _, _) = try fxStateAndTower()
        state.meta.derivedEffects.spawnDiscount = 0.25
        state.run.activeModifiers = [
            ActiveModifier(effect: .spawnCostMultiplier, magnitude: 0.5, expiresAt: 2000, sourceKey: "test"),
        ]
        let porTipo = try #require(TowerActions.hireQuote(
            typeId: "a", state: state, config: config,
            floorTable: floorTable, tiers: tiers, costMultiplier: 0.5, now: 1000
        ))
        let porPiso = try #require(TowerActions.hireQuote(
            floorOrdinal: 0, state: state, tiers: tiers, floorTable: floorTable,
            config: config, costMultiplier: 0.5, now: 1000
        ))
        #expect(abs(porTipo.cost - 15 * 0.5 * 0.5 * 0.75) < 1e-9)
        #expect(abs(porTipo.cost - porPiso.cost) < 1e-9)
    }

    // MARK: Decodificación

    /// **Las dos claves de política de `hire` son OBLIGATORIAS en el JSON**, y es
    /// la misma razón para las dos: ninguna tiene un default inocente.
    ///
    /// El de `gateTierDistance` sería CERO, que apaga la compuerta entera. El de
    /// `priceGrowthPerTier` sería 2,0, que es justo el filo del cuchillo —la
    /// indiferencia exacta entre comprar hondo y comprar a la frontera—, y un
    /// `economy.json` apoyado ahí sin decirlo es peor que uno que no carga. (El
    /// viejo `tierPremium` sí caía a un default, 1,8, y por eso este test decía
    /// lo contrario hasta el 2026-08-23.)
    ///
    /// El default 2,0 existe igual, pero sólo en el init de Swift y para las
    /// FIXTURES: un test que no habla de precios no tiene que elegir una política.
    @Test("hire sin alguna de las TRES claves de política no decodifica")
    func lasClavesDePoliticaSonObligatoriasEnElJSON() throws {
        let completo = #"{"defaultCostMultiplier": 600, "defaultCostGrowth": 1.2, "priceGrowthPerTier": 1.5, "gateTierDistance": 5, "frontierEscalationPerTier": 1.1}"#
        let decodificado = try JSONDecoder().decode(EconomyConfig.HireConfig.self, from: Data(completo.utf8))
        #expect(decodificado.priceGrowthPerTier == 1.5)
        #expect(decodificado.gateTierDistance == 5)

        for sinClave in [
            #"{"defaultCostMultiplier": 600, "defaultCostGrowth": 1.2, "gateTierDistance": 5, "frontierEscalationPerTier": 1.1}"#,
            #"{"defaultCostMultiplier": 600, "defaultCostGrowth": 1.2, "priceGrowthPerTier": 1.5, "frontierEscalationPerTier": 1.1}"#,
            #"{"defaultCostMultiplier": 600, "defaultCostGrowth": 1.2, "priceGrowthPerTier": 1.5, "gateTierDistance": 5}"#,
        ] {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(EconomyConfig.HireConfig.self, from: Data(sinClave.utf8))
            }
        }
        #expect(EconomyConfig.HireConfig.neutralPriceGrowthPerTier == 2.0, "el neutro es el factor de merge")
    }

    /// La pendiente sale de la config, no de una constante escondida en el código.
    @Test("priceGrowthPerTier vive en la config")
    func laPendienteViveEnLaConfig() throws {
        let plano = fxConfig(priceGrowthPerTier: 1.0)
        let tabla = try fxFloorTable(config: plano)
        let f1 = tabla[0]
        // Con 1,0 el tier no mueve el precio: comprar cualquiera cuesta lo mismo
        // que comprar tu frontera, y bajar `d` tiers sale 2^d.
        #expect(abs(plano.hireCost(floor: f1, tier: 2, frontierTier: 1, purchases: 0) - 15) < 1e-9)
        #expect(abs(config.hireCost(floor: f1, tier: 2, frontierTier: 1, purchases: 0) - 15 * 1.5) < 1e-9)
    }
}
