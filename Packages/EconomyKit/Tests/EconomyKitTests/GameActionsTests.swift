import Foundation
import Testing
@testable import EconomyKit

// MARK: - Acciones de juego v2 (F7 "La Torre")
//
// El spawn progresivo v1 (SpawnQuote, tierOffset, board) murió con F7: acá viven
// las acciones que quedaron — applyTap, applyPassiveUnlock y TowerActions.hire.
// La CURVA de precios de hire (hireQuote: overrides por piso, growth, descuentos)
// se cubre en su propia suite; acá solo usamos el quote para contratar.

// MARK: - Tap (GameActions.applyTap)

@Suite("Tap")
struct TapActionTests {
    let economy = fxEconomy()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    @Test func tapCreditsCoinsAndLifetime() throws {
        var state = fxState()
        let a = try #require(tiers.type(id: "a"))
        let gain = economy.applyTap(type: a, state: &state, floorTable: floorTable, now: 0)
        #expect(gain == 1)
        #expect(state.run.coins == 1)
        // El lifetime es la base del ORO: cada tap tiene que sumar ahí también.
        #expect(state.meta.lifetimeEarnings == 1)
    }

    @Test func charUpgradeLevelsMultiplyTap() throws {
        var state = fxState()
        state.run.charUpgradeLevels["a"] = 2
        let a = try #require(tiers.type(id: "a"))
        let gain = economy.applyTap(type: a, state: &state, floorTable: floorTable, now: 0)
        // Efecto SECUENCIAL desde el 2026-08-22 (`1 + nivel`): nivel 2 ⇒ ×3.
        // Con la potencia vieja este mismo nivel valía ×4, y el tap de "a" es 1.
        #expect(abs(gain - 3) < 1e-12)
    }

    @Test func floorMultiplierScalesTapOnlyForItsFloor() throws {
        // c_law vive en f2: con f2 ×3 su tap se triplica; "a" (f1) ni se entera.
        // applyTap usa el tapYield ALMACENADO del tipo (14.44), no la fórmula.
        let boosted = fxConfig(f2IncomeMultiplier: 3.0)
        let boostedTable = try fxFloorTable(config: boosted)
        var state = fxState()
        let cLaw = try #require(tiers.type(id: "c_law"))
        let gainF2 = economy.applyTap(type: cLaw, state: &state, floorTable: boostedTable, now: 0)
        #expect(abs(gainF2 - 14.44 * 3) < 1e-9)
        let a = try #require(tiers.type(id: "a"))
        let gainF1 = economy.applyTap(type: a, state: &state, floorTable: boostedTable, now: 0)
        #expect(abs(gainF1 - 1) < 1e-12)
    }

    @Test("tapFloorMultiplierExponent separa la curva del tap de la del pasivo")
    func tapFloorExponentSeparatesTapFromPassive() throws {
        // Rebalance de pacing §4.3: `passiveYield = tapYield × passiveRatio` era
        // UN knob para dos curvas que el diseño necesita distintas. El exponente
        // las separa por el único factor que crece con la altura de la torre:
        // con 0 el tap cobra el tier pelado y el pasivo sigue cobrando el piso
        // entero. Un piso ×620 (el reino divino real) lo hace visible.
        let sinPiso = fxConfig(f2IncomeMultiplier: 620, tapFloorMultiplierExponent: 0)
        let table = try fxFloorTable(config: sinPiso)
        var state = fxState()
        let cLaw = try #require(tiers.type(id: "c_law"))
        let gain = StandardEconomy(config: sinPiso).applyTap(
            type: cLaw, state: &state, floorTable: table, now: 0
        )
        #expect(abs(gain - 14.44) < 1e-9, "el tap del tier alto ya no cobra el ×620 del piso")

        // El pasivo del MISMO tipo en el MISMO piso sigue cobrándolo entero.
        state.run.units = ["c_law": 1]
        state.run.passiveUnlocked["c_law"] = true
        let passive = IncomeTicker.passivePerSecond(
            state: state, tiers: tiers, floorTable: table, config: sinPiso, now: 0
        )
        #expect(abs(passive - 14.44 * 0.3 * 620) < 1e-9)
    }

    @Test("sin el exponente declarado el tap cobra el piso entero, como siempre")
    func tapFloorExponentDefaultsToOne() throws {
        // El knob se agregó en el rebalance: un `economy.json` (o una fixture)
        // que no lo declare tiene que seguir midiendo lo de antes.
        let sinDeclarar = fxConfig(f2IncomeMultiplier: 620)
        let table = try fxFloorTable(config: sinDeclarar)
        var state = fxState()
        let cLaw = try #require(tiers.type(id: "c_law"))
        let gain = StandardEconomy(config: sinDeclarar).applyTap(
            type: cLaw, state: &state, floorTable: table, now: 0
        )
        #expect(abs(gain - 14.44 * 620) < 1e-9)
    }

    @Test func derivedTapAndIncomeMultipliersStack() throws {
        var state = fxState()
        state.meta.derivedEffects.tapMultiplier = 2
        state.meta.derivedEffects.incomeMultiplier = 1.5
        let a = try #require(tiers.type(id: "a"))
        let gain = economy.applyTap(type: a, state: &state, floorTable: floorTable, now: 0)
        // Las dos líneas de mejora permanente multiplican entre sí.
        #expect(abs(gain - 3) < 1e-12)
    }

    @Test func globalMultiplierScalesTap() throws {
        var state = fxState()
        state.meta.globalMultiplier = 1.5
        let a = try #require(tiers.type(id: "a"))
        let gain = economy.applyTap(type: a, state: &state, floorTable: floorTable, now: 0)
        #expect(abs(gain - 1.5) < 1e-12)
    }

    @Test func activeModifiersMultiplyTap() throws {
        var state = fxState()
        state.run.activeModifiers = [
            ActiveModifier(effect: .tapMultiplier, magnitude: 2, expiresAt: 100, sourceKey: "boost.cafe"),
            ActiveModifier(effect: .incomeMultiplier, magnitude: 3, expiresAt: 100, sourceKey: "event.plan_platita"),
        ]
        let a = try #require(tiers.type(id: "a"))
        let gain = economy.applyTap(type: a, state: &state, floorTable: floorTable, now: 50)
        // tap × income vivos: 2 × 3.
        #expect(abs(gain - 6) < 1e-12)
    }

    @Test func expiredAndUnrelatedModifiersDoNotAffectTap() throws {
        var state = fxState()
        state.run.activeModifiers = [
            // Vencido: expiró en 40, estamos en 50.
            ActiveModifier(effect: .tapMultiplier, magnitude: 2, expiresAt: 40, sourceKey: "boost.cafe"),
            // Vivo pero de spawn: el tap no lo mira.
            ActiveModifier(effect: .spawnCostMultiplier, magnitude: 0.5, expiresAt: 100, sourceKey: "boost.mate"),
        ]
        let a = try #require(tiers.type(id: "a"))
        let gain = economy.applyTap(type: a, state: &state, floorTable: floorTable, now: 50)
        #expect(gain == 1)
    }
}

// MARK: - Compra de pasivo (GameActions.applyPassiveUnlock)
// (El EFECTO del unlock sobre el income vive en "Pasivo por tipo"; acá la compra.)

@Suite("Compra de pasivo")
struct PassiveUnlockPurchaseTests {
    let economy = fxEconomy()
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    @Test func unlockDebitsCoinsAndMarksType() throws {
        var state = fxState()
        state.run.coins = 150
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        // Costo almacenado del tipo: tapYield 1 × 100.
        #expect(state.run.coins == 50)
        #expect(state.run.passiveUnlocked["a"] == true)
    }

    @Test func unknownTypeThrowsAndMutatesNothing() {
        var state = fxState()
        state.run.coins = 1_000_000
        #expect(throws: PassiveUnlockError.unknownType) {
            try economy.applyPassiveUnlock(typeId: "sin_registrar", state: &state, tiers: tiers)
        }
        #expect(state.run.coins == 1_000_000)
        #expect(state.run.passiveUnlocked.isEmpty)
    }

    @Test func alreadyUnlockedThrowsWithoutDoubleCharge() {
        var state = fxState()
        state.run.coins = 500
        state.run.passiveUnlocked["a"] = true
        #expect(throws: PassiveUnlockError.alreadyUnlocked) {
            try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        }
        #expect(state.run.coins == 500)
    }

    @Test func insufficientCoinsThrowsWithoutMarking() {
        var state = fxState()
        state.run.coins = 99
        #expect(throws: PassiveUnlockError.insufficientCoins) {
            try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        }
        #expect(state.run.coins == 99)
        #expect(state.run.passiveUnlocked["a"] != true)
    }
}

// MARK: - Contratación (TowerActions.hire — spec §3.3)

@Suite("Contratación")
struct HireActionTests {
    let config = fxConfig()
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private func makeQuote(on floorOrdinal: Int, state: PlayerState, floorTable: FloorTable) throws -> HireQuote {
        try #require(TowerActions.hireQuote(
            floorOrdinal: floorOrdinal, state: state, tiers: tiers,
            floorTable: floorTable, config: config
        ))
    }

    @Test func hireChargesCountsAndOccupiesSlot() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 1])
        state.run.coins = 20
        let quote = try makeQuote(on: 0, state: state, floorTable: floorTable)
        let placement = try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable, config: config)
        // f1 overridea a 15 × tapYield(T1)=1, cero compras previas ⇒ 15.
        #expect(abs(state.run.coins - 5) < 1e-9)
        #expect(state.run.hireCounts["f1"] == 1)
        #expect(state.run.units["a"] == 2)
        #expect(placement.floorOrdinal == 0)
        #expect(placement.typeId == "a")
        #expect(tower.typeId(floorOrdinal: 0, slot: placement.slot) == "a")
        #expect(tower.unitCounts == state.run.units)
    }

    @Test func hireOnLockedFloorThrowsAndMutatesNothing() throws {
        // f2 nunca desbloqueado: aunque sobre la plata, no se puede contratar ahí.
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 1], unlockedFloors: ["f1"])
        state.run.coins = 10_000
        let quote = try makeQuote(on: 1, state: state, floorTable: floorTable)
        let before = (state, tower)
        #expect(throws: TowerError.floorLocked) {
            try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable, config: config)
        }
        #expect(state == before.0)
        #expect(tower == before.1)
    }

    @Test func hireWithoutCoinsThrowsAndMutatesNothing() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 1])
        state.run.coins = 14  // el hire de f1 sale 15
        let quote = try makeQuote(on: 0, state: state, floorTable: floorTable)
        let before = (state, tower)
        #expect(throws: TowerError.insufficientCoins) {
            try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable, config: config)
        }
        #expect(state == before.0)
        #expect(tower == before.1)
    }

    @Test func hireOnFullFloorThrowsAndMutatesNothing() throws {
        // f1 lleno (capacity 5 con 5 "a"): plata de sobra no alcanza sin slot.
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 5])
        state.run.coins = 1_000
        let quote = try makeQuote(on: 0, state: state, floorTable: floorTable)
        let before = (state, tower)
        #expect(throws: TowerError.floorFull) {
            try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable, config: config)
        }
        #expect(state == before.0)
        #expect(tower == before.1)
    }
}

// MARK: - La compuerta de contratación (distancia en TIERS)
//
// ⚠️ **Reescrita entera el 2026-08-22 porque la regla cambió de significado.**
// Antes la compuerta se medía en PISOS —para contratar en el piso F hacía falta
// F+1 desbloqueado— y estos tests pineaban esa conducta. Ahora se mide en TIERS
// contra `run.maxTierReached`, así que ni los asserts ni el fixture podían
// sobrevivir: no se aflojaron rangos, se reemplazó lo que se mide.
//
// El fixture es una torre de 3 pisos × 4 tiers (12 tiers), que es la forma de la
// real: hace falta un piso con VARIOS tiers para poder mostrar lo único que la
// regla nueva arregla —que dos tipos del mismo piso se habiliten en momentos
// distintos—, y el fixture chico de dos pisos de un tier no puede.
//
// `gateTierDistance: 3` y no el 5 del juego: los números quedan chicos y se
// derivan a mano en una línea (t2 pide 5, t3 pide 6, t4 pide 7…), y una torre de
// 12 tiers con distancia 5 dejaría medio catálogo inalcanzable.

private func gateTiers() throws -> TierRepository {
    try TierRepository(types: (1...12).map {
        fxType("t\($0)", tier: $0, tapYield: pow(2.8, Double($0 - 1)),
               mergesInto: $0 < 12 ? "t\($0 + 1)" : nil)
    })
}

private func gateConfig(distance: Int = 3) -> EconomyConfig {
    EconomyConfig(
        schemaVersion: 2,
        baseTapYieldTier1: 1,
        yieldGrowthPerTier: 2.8,
        passiveRatio: 0.5,
        passiveUnlockCostMultiplier: 60,
        hire: .init(defaultCostMultiplier: 600, defaultCostGrowth: 1.06,
                    priceGrowthPerTier: 1.5, gateTierDistance: distance),
        charUpgrades: .init(baseCostMultiplier: 50, costGrowth: 1.5, effectStepPerLevel: 1.0),
        oro: .init(divisor: 1e9, exponent: 0.25, globalMultiplierPerOro: 0.18),
        critChanceBase: 0,
        critMultiplier: 5,
        offlineEfficiencyBase: 0.35,
        offlineCapHours: 10,
        floors: (0..<3).map { index in
            FloorDef(
                id: "g\(index + 1)", background: "alley",
                firstTier: index * 4 + 1, lastTier: index * 4 + 4,
                capacity: 5, incomeMultiplier: 1.0
            )
        }
    )
}

@Suite("Compuerta de contratación (distancia en tiers)")
struct HireGateTests {
    let config = gateConfig()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try gateTiers()
        floorTable = try FloorTable(floors: config.floors, maxTier: 12)
    }

    // MARK: La regla

    /// El Fisura es la única compra libre: sin él no hay de dónde sacar material
    /// de merge y la torre entera queda en un huevo-y-gallina.
    @Test("el tier base de la torre no tiene compuerta")
    func theBaseTierIsExempt() {
        #expect(TowerActions.canHire(tier: 1, maxTierReached: 1, floorTable: floorTable, config: config))
        #expect(TowerActions.canHire(tier: 1, maxTierReached: 12, floorTable: floorTable, config: config))
    }

    /// Derivado a mano: con distancia 3, el t2 pide frontera 5 y el t5 pide 8.
    @Test("de ahí para arriba hace falta la frontera N tiers más alta")
    func everyOtherTierNeedsTheFrontierAbove() {
        #expect(!TowerActions.canHire(tier: 2, maxTierReached: 4, floorTable: floorTable, config: config))
        #expect(TowerActions.canHire(tier: 2, maxTierReached: 5, floorTable: floorTable, config: config))
        #expect(!TowerActions.canHire(tier: 5, maxTierReached: 7, floorTable: floorTable, config: config))
        #expect(TowerActions.canHire(tier: 5, maxTierReached: 8, floorTable: floorTable, config: config))
    }

    /// **El borde dentado, que es lo que esta regla viene a matar.** Con la
    /// compuerta por pisos, habilitar g1 habilitaba sus cuatro tiers de una, y
    /// el jugador compraba el más alto —a un tier de su frontera, dos unidades—.
    /// Ahora cada tier del mismo piso abre en su propio momento.
    @Test("dos tipos del MISMO piso se habilitan en momentos distintos")
    func typesOfTheSameFloorOpenAtDifferentTimes() {
        // Frontera en 6: t2 (pide 5) y t3 (pide 6) sí, t4 (pide 7) todavía no.
        // Los tres viven en g1.
        #expect(TowerActions.canHire(tier: 2, maxTierReached: 6, floorTable: floorTable, config: config))
        #expect(TowerActions.canHire(tier: 3, maxTierReached: 6, floorTable: floorTable, config: config))
        #expect(!TowerActions.canHire(tier: 4, maxTierReached: 6, floorTable: floorTable, config: config))
        #expect(floorTable.ordinal(forTier: 2) == 0)
        #expect(floorTable.ordinal(forTier: 4) == 0)
    }

    /// El piso de abajo ya no está exento ENTERO: lo que está exento es un tier.
    /// Era uno de los dos parches por piso que la regla nueva deja sin trabajo.
    @Test("el piso de abajo sólo trae libre su tier base")
    func theGroundFloorIsNotExemptAsAWhole() {
        #expect(TowerActions.canHire(floorOrdinal: 0, maxTierReached: 1, floorTable: floorTable, config: config))
        #expect(!TowerActions.canHire(tier: 4, maxTierReached: 4, floorTable: floorTable, config: config))
    }

    /// El default de fixture (`noTierGate`): con 0, la compuerta no existe y
    /// queda sólo el guard de piso abierto, que es la conducta histórica.
    @Test("con la distancia en cero la compuerta no gatea nada")
    func zeroDistanceDisablesTheGate() throws {
        let sinCompuerta = gateConfig(distance: 0)
        let tabla = try FloorTable(floors: sinCompuerta.floors, maxTier: 12)
        for tier in 1...12 {
            #expect(TowerActions.canHire(tier: tier, maxTierReached: 1, floorTable: tabla, config: sinCompuerta))
        }
    }

    // MARK: `hire` la hace cumplir — y la mira POR TIPO

    /// **El hueco que esta ronda cierra.** `hire` gateaba por PISO, así que el
    /// quote de un tier alto de un piso abierto se vendía igual: el docstring de
    /// `hireQuote(typeId:)` lo declaraba y le dejaba la compuerta a la vista.
    @Test("hire rechaza por TIPO, no por piso, y no muta nada")
    func hireRejectsByTypeAndDoesNotMutate() throws {
        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "g1",
            offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 1000
        )
        state.run.units = ["t1": 1]
        var tower = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers).tower
        state.run.unlockedFloors = ["g1"]      // el piso del t4 está ABIERTO
        state.run.maxTierReached = 4           // …y la frontera es 4: el t4 pide 7
        state.run.coins = 1_000_000_000
        let quote = try #require(TowerActions.hireQuote(
            typeId: "t4", state: state, config: config, floorTable: floorTable, tiers: tiers
        ))
        let before = (state, tower)

        #expect(throws: TowerError.hireLocked) {
            try TowerActions.hire(
                quote: quote, state: &state, tower: &tower,
                floorTable: floorTable, config: config
            )
        }
        #expect(state == before.0, "un hire rechazado no puede cobrar")
        #expect(tower == before.1, "ni ocupar un slot")

        // Y con la frontera en 7 el MISMO quote pasa: lo que rechazaba era la
        // compuerta y nada más.
        state.run.maxTierReached = 7
        #expect(throws: Never.self) {
            try TowerActions.hire(
                quote: quote, state: &state, tower: &tower,
                floorTable: floorTable, config: config
            )
        }
        #expect(state.run.units["t4"] == 1)
    }

    @Test("hire sigue exigiendo el piso abierto")
    func hireStillNeedsTheFloorUnlocked() throws {
        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "g1",
            offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 1000
        )
        state.run.units = ["t1": 1]
        var tower = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers).tower
        state.run.unlockedFloors = ["g1"]
        state.run.maxTierReached = 12   // la compuerta del t5 (pide 8) pasa…
        state.run.coins = 1_000_000_000
        let quote = try #require(TowerActions.hireQuote(
            typeId: "t5", state: state, config: config, floorTable: floorTable, tiers: tiers
        ))
        #expect(throws: TowerError.floorLocked) {   // …pero g2 no está abierto
            try TowerActions.hire(
                quote: quote, state: &state, tower: &tower,
                floorTable: floorTable, config: config
            )
        }
    }

    // MARK: Qué se destraba cuando la frontera sube

    @Test("subir la frontera destraba el piso cuya base acaba de alcanzar")
    func raisingTheFrontierOpensTheFloorItReaches() {
        // g2 arranca en t5, que con distancia 3 pide frontera 8.
        #expect(
            TowerActions.newlyHireableFloors(
                maxTierBefore: 7, maxTierAfter: 8, floorTable: floorTable, config: config
            ) == [1]
        )
    }

    @Test("una fusión que no mueve la frontera no destraba nada")
    func aMergeThatDoesNotRaiseTheFrontierOpensNothing() {
        #expect(
            TowerActions.newlyHireableFloors(
                maxTierBefore: 8, maxTierAfter: 8, floorTable: floorTable, config: config
            ).isEmpty
        )
        // Y subir de 5 a 6 tampoco: ninguna base de piso cae en ese tramo (g2
        // pide 8 y g3 pide 12).
        #expect(
            TowerActions.newlyHireableFloors(
                maxTierBefore: 5, maxTierAfter: 6, floorTable: floorTable, config: config
            ).isEmpty
        )
    }

    // MARK: A dónde cae la contratación

    @Test("con la compuerta abierta, la contratación cae en el piso que estás mirando")
    func hireTargetIsTheVisibleFloorWhenTheGateIsOpen() {
        let abiertos = ["g1", "g2", "g3"]
        #expect(TowerActions.hireTargetFloor(
            visibleOrdinal: 1, unlockedFloors: abiertos, maxTierReached: 8,
            floorTable: floorTable, config: config
        ) == 1)
        #expect(TowerActions.hireTargetFloor(
            visibleOrdinal: 0, unlockedFloors: ["g1"], maxTierReached: 1,
            floorTable: floorTable, config: config
        ) == 0)
    }

    /// La garantía que se fue con la regla vieja: antes bajar UN piso alcanzaba
    /// siempre, porque el de abajo tenía el de arriba abierto por construcción.
    @Test("con la compuerta cerrada baja los pisos que haga falta, no uno")
    func hireTargetFallsAsManyFloorsAsNeeded() {
        let abiertos = ["g1", "g2", "g3"]
        // Parado en g3 (base t9, pide 12) con la frontera en 7: g2 (base t5,
        // pide 8) tampoco pasa, así que la compra cae DOS pisos abajo, en g1.
        #expect(TowerActions.hireTargetFloor(
            visibleOrdinal: 2, unlockedFloors: abiertos, maxTierReached: 7,
            floorTable: floorTable, config: config
        ) == 0)
        // Con la frontera en 8, g2 ya pasa y cae uno solo.
        #expect(TowerActions.hireTargetFloor(
            visibleOrdinal: 2, unlockedFloors: abiertos, maxTierReached: 8,
            floorTable: floorTable, config: config
        ) == 1)
    }

    @Test("desde un piso todavía cerrado no se contrata en ningún lado")
    func lockedFloorHasNoHireTarget() {
        #expect(TowerActions.hireTargetFloor(
            visibleOrdinal: 2, unlockedFloors: ["g1", "g2"], maxTierReached: 12,
            floorTable: floorTable, config: config
        ) == nil)
        #expect(TowerActions.hireTargetFloor(
            visibleOrdinal: 9, unlockedFloors: ["g1"], maxTierReached: 12,
            floorTable: floorTable, config: config
        ) == nil)
    }
}
