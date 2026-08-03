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
    let economy = fxEconomy()
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private func makeQuote(on floorOrdinal: Int, state: PlayerState, floorTable: FloorTable) throws -> HireQuote {
        try #require(TowerActions.hireQuote(
            floorOrdinal: floorOrdinal, state: state, tiers: tiers,
            floorTable: floorTable, config: config, economy: economy
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
