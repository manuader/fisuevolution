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
        // Efecto ×2 por nivel: nivel 2 ⇒ ×4.
        #expect(abs(gain - 4) < 1e-12)
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
        let placement = try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable)
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
            try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable)
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
            try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable)
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
            try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable)
        }
        #expect(state == before.0)
        #expect(tower == before.1)
    }
}

// MARK: - Gate de contratación (el piso de arriba desbloqueado)
//
// El fixture de la torre tiene sólo DOS pisos, y con dos pisos el gate es
// invisible: el ordinal 1 siempre cae en el escape del tope, así que
// `hireLocked` es inalcanzable. Este suite arma su propia tabla de CUATRO pisos
// de un tier cada uno, que sigue entrando en `maxTier: 4` y por lo tanto sirve
// con `fxTiers()` sin tocarlo.

private func gateFloor(_ id: String, _ tier: Int) -> FloorDef {
    FloorDef(
        id: id, background: "alley", firstTier: tier, lastTier: tier,
        capacity: 5, incomeMultiplier: 1.0
    )
}

@Suite("Gate de contratación")
struct HireGateTests {
    let config = fxConfig()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try FloorTable(
            floors: [gateFloor("g1", 1), gateFloor("g2", 2), gateFloor("g3", 3), gateFloor("g4", 4)],
            maxTier: 4
        )
    }

    @Test("el piso de abajo siempre deja contratar, aunque no haya nada arriba")
    func groundFloorIsAlwaysHireable() {
        #expect(TowerActions.canHire(floorOrdinal: 0, unlockedFloors: ["g1"], floorTable: floorTable))
    }

    @Test("un piso necesita el de arriba desbloqueado")
    func upperFloorNeedsTheOneAbove() {
        #expect(!TowerActions.canHire(floorOrdinal: 1, unlockedFloors: ["g1", "g2"], floorTable: floorTable))
        #expect(TowerActions.canHire(floorOrdinal: 1, unlockedFloors: ["g1", "g2", "g3"], floorTable: floorTable))
    }

    @Test("un piso exento contrata con el de arriba cerrado")
    func exemptFloorIgnoresTheGate() throws {
        // Cobertura del gate, no profundidad: sigue siendo de UN piso. El urbano
        // se declaró exento en la Ola 3 porque el gate + el remapeo de tiers
        // dejaban 268 h de pared antes de corporativo (ver balance-log).
        let exempt = try FloorTable(
            floors: [
                gateFloor("g1", 1),
                FloorDef(
                    id: "g2", background: "alley", firstTier: 2, lastTier: 2,
                    capacity: 5, incomeMultiplier: 1.0, hireGateExempt: true
                ),
                gateFloor("g3", 3),
                gateFloor("g4", 4),
            ],
            maxTier: 4
        )
        #expect(TowerActions.canHire(floorOrdinal: 1, unlockedFloors: ["g1", "g2"], floorTable: exempt))
        // El resto de la torre no se contagia: g3 sigue pidiendo g4.
        #expect(!TowerActions.canHire(floorOrdinal: 2, unlockedFloors: ["g1", "g2", "g3"], floorTable: exempt))
    }

    @Test("el último piso se destraba a sí mismo al abrirse")
    func topOfTowerEscapes() {
        // g4 no tiene ninguno por encima: sin el escape nunca dejaría contratar.
        #expect(!TowerActions.canHire(floorOrdinal: 3, unlockedFloors: ["g1", "g2", "g3"], floorTable: floorTable))
        #expect(!TowerActions.canHire(floorOrdinal: 2, unlockedFloors: ["g1", "g2", "g3"], floorTable: floorTable))
        let all = ["g1", "g2", "g3", "g4"]
        #expect(TowerActions.canHire(floorOrdinal: 3, unlockedFloors: all, floorTable: floorTable))
        #expect(TowerActions.canHire(floorOrdinal: 2, unlockedFloors: all, floorTable: floorTable))
    }

    @Test("hire rechaza con hireLocked y no muta nada")
    func hireRejectsWhenGateClosed() throws {
        var state = PlayerState.newGame(
            startTypeId: "a", startFloorId: "g1",
            offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 1000
        )
        state.run.units = ["a": 1, "b": 1]
        var tower = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers).tower
        // Después del reconcile: el reconciliador sincroniza unlockedFloors por
        // unidades, así que fijar el escenario acá y no antes.
        state.run.unlockedFloors = ["g1", "g2"]   // g3 cerrado ⇒ el gate de g2 no pasa
        state.run.coins = 1_000_000
        let quote = try #require(TowerActions.hireQuote(
            floorOrdinal: 1, state: state, tiers: tiers,
            floorTable: floorTable, config: config
        ))
        let before = (state, tower)

        #expect(throws: TowerError.hireLocked) {
            try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable)
        }
        #expect(state == before.0, "un hire rechazado no puede cobrar")
        #expect(tower == before.1, "ni ocupar un slot")
    }

    @Test("desbloquear un piso destraba la contratación del que está justo abajo")
    func unlockingAFloorOpensHiringRightBelow() {
        #expect(
            TowerActions.newlyHireableFloors(
                unlockedBefore: ["g1", "g2"], unlockedAfter: ["g1", "g2", "g3"], floorTable: floorTable
            ) == [1],
            "abrir g3 sólo destraba g2"
        )
    }

    @Test("abrir el último piso destraba también al último por el escape")
    func unlockingTheTopAlsoOpensItself() {
        let before = ["g1", "g2", "g3"]
        #expect(
            TowerActions.newlyHireableFloors(
                unlockedBefore: before, unlockedAfter: before + ["g4"], floorTable: floorTable
            ) == [2, 3],
            "g3 por la regla y g4 por el escape, que si no nunca se abriría"
        )
    }

    @Test("un unlock que no destraba a nadie devuelve vacío")
    func unlockingNothingNewReturnsEmpty() {
        #expect(
            TowerActions.newlyHireableFloors(
                unlockedBefore: ["g1"], unlockedAfter: ["g1", "g2"], floorTable: floorTable
            ).isEmpty,
            "abrir g2 no le da el piso de arriba a nadie: g1 ya podía y g2 necesita g3"
        )
    }

    // MARK: A dónde cae la contratación

    @Test("con el gate abierto, la contratación cae en el piso que estás mirando")
    func hireTargetIsTheVisibleFloorWhenTheGateIsOpen() {
        let open = ["g1", "g2", "g3"]
        #expect(TowerActions.hireTargetFloor(visibleOrdinal: 1, unlockedFloors: open, floorTable: floorTable) == 1)
        #expect(TowerActions.hireTargetFloor(visibleOrdinal: 0, unlockedFloors: ["g1"], floorTable: floorTable) == 0)
    }

    @Test("con el gate cerrado, la contratación cae en el piso de abajo")
    func hireTargetFallsToTheFloorBelowWhenTheGateIsClosed() {
        // Parado en g2, que es la frontera: g3 sigue cerrado, así que el gate de
        // g2 no pasa y la compra tiene que caer en g1 en vez de no hacer nada.
        #expect(TowerActions.hireTargetFloor(visibleOrdinal: 1, unlockedFloors: ["g1", "g2"], floorTable: floorTable) == 0)
        // Y baja UN piso, no hasta el fondo: parado en g3 cae en g2.
        #expect(TowerActions.hireTargetFloor(visibleOrdinal: 2, unlockedFloors: ["g1", "g2", "g3"], floorTable: floorTable) == 1)
    }

    @Test("desde un piso todavía cerrado no se contrata en ningún lado")
    func lockedFloorHasNoHireTarget() {
        // El preview con candado: estás mirando g3 sin haberlo abierto.
        #expect(TowerActions.hireTargetFloor(visibleOrdinal: 2, unlockedFloors: ["g1", "g2"], floorTable: floorTable) == nil)
        #expect(TowerActions.hireTargetFloor(visibleOrdinal: 9, unlockedFloors: ["g1"], floorTable: floorTable) == nil)
    }
}
