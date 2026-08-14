import Foundation
import Testing
@testable import EconomyKit

// MARK: - Cotización de contratación POR TIPO (rediseño de UI §5.2)
//
// La pantalla de laburos vende CUALQUIER tipo desbloqueado, no sólo el tier base
// del piso visible. Eso abre un atajo que el juego no puede permitir —comprar el
// tier alto directo en vez de comprar dos del anterior y mergear—, y `tierPremium`
// es lo que lo cierra: cada tier por encima del base del piso multiplica el precio
// otra vez. Con tapYield creciendo 2,8×/tier y premium 1,8, subir un tier sale
// ~5×: mergear (2 unidades) siempre gana.

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

    /// El pin que sostiene a todos los demás: para el tier BASE de un piso el
    /// premium es `1.8^0 = 1`, así que la cotización nueva tiene que dar el
    /// MISMO número que la vieja por piso. Es lo que garantiza que el primer
    /// Fisura siga costando 50 y la regla 600×/50× siga en pie.
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
    /// rompieran juntos: f1 overridea a 15 y f2 usa el default punitivo 100 ×
    /// tapYield(T3) POR FÓRMULA (3,8² = 14,44).
    @Test("el premium no toca el tier base: a = 15, c_law = 1444")
    func premiumNeutroEnElTierBase() throws {
        let (state, _, _) = try fxStateAndTower()
        let a = try #require(quote(type: "a", state: state))
        #expect(abs(a.cost - 15) < 1e-9)
        let cLaw = try #require(quote(type: "c_law", state: state))
        #expect(abs(cLaw.cost - 1444) < 1e-9)
    }

    // MARK: La regla anti-atajo

    /// Regla del spec §5.2: comprar el tier de arriba NUNCA puede convenir
    /// contra comprar dos del de abajo y mergear. O sea `costo(t+1) > 2 × costo(t)`
    /// para todo par de tiers vecinos DENTRO de un piso (cruzar de piso cambia
    /// también el multiplicador del piso, y ese salto es mucho mayor).
    @Test("subir un tier dentro del piso cuesta más que el doble")
    func subirUnTierMasQueDuplica() throws {
        for ordinal in 0..<floorTable.count {
            let floor = floorTable[ordinal]
            guard floor.lastTier > floor.firstTier else { continue }
            for tier in floor.firstTier..<floor.lastTier {
                let bajo = config.hireCost(floor: floor, tier: tier, purchases: 0)
                let alto = config.hireCost(floor: floor, tier: tier + 1, purchases: 0)
                #expect(alto > 2 * bajo, "\(floor.id) T\(tier)→T\(tier + 1): \(alto) ≤ 2 × \(bajo)")
            }
        }
    }

    /// Y lo mismo por el camino que usa la pantalla: `b` (T2) vive en f1 igual
    /// que `a` (T1), así que su precio sale del mismo multiplicador barato y la
    /// única diferencia es tapYield × premium = 3,8 × 1,8 = 6,84.
    @Test("el premium se ve en el quote: b sale 6,84× lo que sale a")
    func premiumVisibleEnElQuote() throws {
        let (state, _, _) = try fxStateAndTower()
        let a = try #require(quote(type: "a", state: state))
        let b = try #require(quote(type: "b", state: state))
        #expect(abs(b.cost - 15 * 3.8 * 1.8) < 1e-9)
        #expect(b.cost > 2 * a.cost)
    }

    /// La regla anti-atajo con los números que SE ENVÍAN, no con los de la
    /// fixture: `yieldGrowthPerTier` 2,8 × `tierPremium` 1,8 = 5,04.
    @Test("con los valores reales (2,8 × 1,8) el salto por tier es ~5×")
    func reglaAntiAtajoConValoresReales() throws {
        let real = EconomyConfig(
            schemaVersion: 2,
            baseTapYieldTier1: 1,
            yieldGrowthPerTier: 2.8,
            passiveRatio: 0.5,
            passiveUnlockCostMultiplier: 60,
            hire: .init(defaultCostMultiplier: 600, defaultCostGrowth: 1.2),
            charUpgrades: .init(baseCostMultiplier: 50, costGrowth: 4, effectFactorPerLevel: 2),
            oro: .init(divisor: 3_000_000, exponent: 0.45, globalMultiplierPerOro: 0.18),
            critChanceBase: 0,
            critMultiplier: 5,
            offlineEfficiencyBase: 0.35,
            offlineCapHours: 10,
            floors: [
                FloorDef(
                    id: "alley", background: "alley", firstTier: 1, lastTier: 4,
                    capacity: 10, incomeMultiplier: 1.0, hireCostMultiplierOverride: 50
                ),
                FloorDef(
                    id: "urban", background: "urban", firstTier: 5, lastTier: 8,
                    capacity: 10, incomeMultiplier: 2.0
                ),
            ]
        )
        #expect(real.hire.tierPremium == 1.8)
        for floor in real.floors {
            for tier in floor.firstTier..<floor.lastTier {
                let bajo = real.hireCost(floor: floor, tier: tier, purchases: 0)
                let alto = real.hireCost(floor: floor, tier: tier + 1, purchases: 0)
                #expect(abs(alto / bajo - 2.8 * 1.8) < 1e-9, "\(floor.id) T\(tier): ×\(alto / bajo)")
                #expect(alto > 2 * bajo)
            }
        }
        // Y el tier base sigue anclado donde el dueño lo dejó: 50 y 60.
        let alley = real.floors[0]
        #expect(real.hireCost(floor: alley, tier: 1, purchases: 0) == 50)
        #expect(abs(real.hireCost(floor: alley, tier: 1, purchases: 1) - 60) < 1e-9)
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
        let colocado = try TowerActions.hire(quote: primero, state: &state, tower: &tower, floorTable: table)
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

    /// `tierPremium` es un campo NUEVO de `hire`: un `economy.json` viejo (o una
    /// fixture de test) no lo trae y tiene que caer al default 1,8. `HireConfig`
    /// decodificaba sintetizado, y el Codable sintetizado NO respeta los valores
    /// por defecto de las propiedades: sin decoder manual esto tira `keyNotFound`.
    @Test("hire sin tierPremium decodifica al default 1,8")
    func tierPremiumEsOpcionalEnElJSON() throws {
        let viejo = Data(#"{"defaultCostMultiplier": 600, "defaultCostGrowth": 1.2}"#.utf8)
        let decodificado = try JSONDecoder().decode(EconomyConfig.HireConfig.self, from: viejo)
        #expect(decodificado.tierPremium == 1.8)

        let nuevo = Data(#"{"defaultCostMultiplier": 600, "defaultCostGrowth": 1.2, "tierPremium": 2.5}"#.utf8)
        #expect(try JSONDecoder().decode(EconomyConfig.HireConfig.self, from: nuevo).tierPremium == 2.5)
    }

    /// El premium sale de la config, no de una constante escondida en el código.
    @Test("el premium sale de la config")
    func premiumViveEnLaConfig() throws {
        let sinPremium = fxConfig(tierPremium: 1.0)
        let tabla = try fxFloorTable(config: sinPremium)
        let f1 = tabla[0]
        #expect(abs(sinPremium.hireCost(floor: f1, tier: 2, purchases: 0) - 15 * 3.8) < 1e-9)
        #expect(abs(config.hireCost(floor: f1, tier: 2, purchases: 0) - 15 * 3.8 * 1.8) < 1e-9)
    }
}
