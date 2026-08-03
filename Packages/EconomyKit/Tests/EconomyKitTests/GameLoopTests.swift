import Foundation
import Testing
@testable import EconomyKit

// MARK: - Merge (bible §2.3 regla 2 + carrera) — sin cambios en F7

@Suite("MergeRules")
struct MergeRulesTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    @Test func sameTypeMergesIntoNextTier() {
        #expect(MergeRules.evaluate(sourceTypeId: "a", targetTypeId: "a", chosenCareerPath: nil, tiers: tiers)
            == .merged(newTypeId: "b"))
    }

    @Test func differentTypesAreInvalid() {
        #expect(MergeRules.evaluate(sourceTypeId: "a", targetTypeId: "b", chosenCareerPath: nil, tiers: tiers) == .invalid)
    }

    @Test func terminalTierCannotMerge() {
        #expect(MergeRules.evaluate(sourceTypeId: "d", targetTypeId: "d", chosenCareerPath: nil, tiers: tiers) == .invalid)
    }

    @Test func choiceNodeWithoutCareerAsksForChoice() {
        #expect(MergeRules.evaluate(sourceTypeId: "b", targetTypeId: "b", chosenCareerPath: nil, tiers: tiers)
            == .requiresCareerChoice(options: ["c_prog", "c_law"]))
    }

    @Test func choiceNodeWithCareerResolvesDirectly() {
        #expect(MergeRules.evaluate(sourceTypeId: "b", targetTypeId: "b", chosenCareerPath: "law", tiers: tiers)
            == .merged(newTypeId: "c_law"))
    }

    @Test func careerVariantsMergeOnwardWithoutChoice() {
        #expect(MergeRules.evaluate(sourceTypeId: "c_prog", targetTypeId: "c_prog", chosenCareerPath: "prog", tiers: tiers)
            == .merged(newTypeId: "d"))
    }

    @Test func careerPathDerivesFromOptionId() {
        #expect(MergeRules.careerPath(fromOptionId: "junior_programmer") == "programmer")
        #expect(MergeRules.careerPath(fromOptionId: "c_law") == "law")
    }
}

// MARK: - Torre: move / merge / ascenso / remove (F7 §3.4)

@Suite("TowerActions")
struct TowerActionsTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    @Test func moveToEmptySlotSucceeds() throws {
        var (state, tower, _) = try fxStateAndTower(units: ["a": 1])
        let from = try #require(fxSlot(of: "a", onFloor: 0, in: tower))
        let to = try #require(tower.floors[0].firstFreeSlot())
        #expect(TowerActions.move(floorOrdinal: 0, fromSlot: from, toSlot: to, tower: &tower))
        #expect(tower.typeId(floorOrdinal: 0, slot: to) == "a")
        #expect(tower.typeId(floorOrdinal: 0, slot: from) == nil)
        #expect(tower.unitCounts == state.run.units)
    }

    @Test func moveToOccupiedSlotIsRejected() throws {
        var (_, tower, _) = try fxStateAndTower(units: ["a": 1, "b": 1])
        let from = try #require(fxSlot(of: "a", onFloor: 0, in: tower))
        let to = try #require(fxSlot(of: "b", onFloor: 0, in: tower))
        #expect(!TowerActions.move(floorOrdinal: 0, fromSlot: from, toSlot: to, tower: &tower))
    }

    @Test func mergeConsumesPairAdvancesMaxTierAndKeepsInvariant() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 2])
        let slots = fxSlots(of: "a", onFloor: 0, in: tower)
        let result = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: slots[0], targetSlot: slots[1],
            newTypeId: "b", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )
        #expect(result == .stayed(floorOrdinal: 0, slot: slots[1], newTypeId: "b"))
        #expect(state.run.units == ["b": 1])
        #expect(state.run.maxTierReached == 2)
        #expect(tower.unitCounts == state.run.units)
    }

    @Test func mergeNeverLowersMaxTier() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["a": 2])
        state.run.maxTierReached = 4
        let slots = fxSlots(of: "a", onFloor: 0, in: tower)
        _ = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: slots[0], targetSlot: slots[1],
            newTypeId: "b", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )
        #expect(state.run.maxTierReached == 4)
    }

    @Test func mergeAcrossFloorBoundaryPromotes() throws {
        // b+b → c_law (T3) pertenece a f2: asciende y desbloquea f2 si hacía falta.
        var (state, tower, floorTable) = try fxStateAndTower(units: ["b": 2], unlockedFloors: ["f1"])
        state.run.chosenCareerPath = "law"
        let slots = fxSlots(of: "b", onFloor: 0, in: tower)
        let result = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: slots[0], targetSlot: slots[1],
            newTypeId: "c_law", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )
        guard case .promoted(let toFloor, let slot, let newTypeId, let unlockedFloorId) = result else {
            Issue.record("expected .promoted, got \(result)")
            return
        }
        #expect(toFloor == 1)
        #expect(newTypeId == "c_law")
        #expect(unlockedFloorId == "f2")
        #expect(tower.typeId(floorOrdinal: 1, slot: slot) == "c_law")
        #expect(state.run.unlockedFloors.contains("f2"))
        #expect(tower.unitCounts == state.run.units)
    }

    @Test func promotionAlreadyUnlockedFloorHasNilUnlockId() throws {
        var (state, tower, floorTable) = try fxStateAndTower(units: ["b": 2], unlockedFloors: ["f1", "f2"])
        state.run.chosenCareerPath = "law"
        let slots = fxSlots(of: "b", onFloor: 0, in: tower)
        let result = try TowerActions.applyMerge(
            floorOrdinal: 0, sourceSlot: slots[0], targetSlot: slots[1],
            newTypeId: "c_law", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
        )
        guard case .promoted(_, _, _, let unlockedFloorId) = result else {
            Issue.record("expected .promoted")
            return
        }
        #expect(unlockedFloorId == nil)
    }

    @Test func promotionBlockedWhenDestinationFloorFullAndNothingMutates() throws {
        // f2 lleno (capacity 5 con 5 c_law) + par de b en f1.
        var (state, tower, floorTable) = try fxStateAndTower(units: ["b": 2, "c_law": 5])
        state.run.chosenCareerPath = "law"
        let before = (state, tower)
        let slots = fxSlots(of: "b", onFloor: 0, in: tower)
        #expect(throws: TowerError.destinationFloorFull(floorId: "f2")) {
            try TowerActions.applyMerge(
                floorOrdinal: 0, sourceSlot: slots[0], targetSlot: slots[1],
                newTypeId: "c_law", state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
            )
        }
        #expect(state == before.0)
        #expect(tower == before.1)
    }

    @Test func removeUnitFreesSlotButNeverRemovesLastUnit() throws {
        var (state, tower, _) = try fxStateAndTower(units: ["a": 2])
        let slot = try #require(fxSlot(of: "a", onFloor: 0, in: tower))
        #expect(TowerActions.removeUnit(floorOrdinal: 0, slot: slot, state: &state, tower: &tower))
        #expect(state.run.units == ["a": 1])
        // Última unidad de la torre: no se puede despedir.
        let last = try #require(fxSlot(of: "a", onFloor: 0, in: tower))
        #expect(!TowerActions.removeUnit(floorOrdinal: 0, slot: last, state: &state, tower: &tower))
        #expect(state.run.units == ["a": 1])
        #expect(tower.unitCounts == state.run.units)
    }
}

// MARK: - Pasivo por tipo (bible §2.3 regla 3)

@Suite("Pasivo por tipo")
struct PassiveTests {
    let config = fxConfig()
    let economy = fxEconomy()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    @Test func lockedTypeYieldsZero() {
        let state = fxState(units: ["a": 2])
        #expect(IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 0) == 0)
    }

    @Test func unlockAffectsAllInstancesOfThatTypeOnly() throws {
        var state = fxState(units: ["a": 3, "b": 1])
        state.run.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        #expect(state.run.coins == 0)
        // 3 × 0.3; el 'b' sigue sin generar.
        #expect(abs(IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 0) - 0.9) < 1e-12)
    }

    @Test func unlocksAreIndependentPerType() throws {
        var state = fxState(units: ["a": 1, "b": 1])
        state.run.coins = 1000
        try economy.applyPassiveUnlock(typeId: "b", state: &state, tiers: tiers)
        #expect(abs(IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 0) - 0.3) < 1e-12)
    }

    @Test func unlockFailsWithoutCoins() {
        var state = fxState()
        state.run.coins = 99
        #expect(throws: PassiveUnlockError.insufficientCoins) {
            try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        }
    }

    @Test func unlockFailsIfAlreadyUnlocked() throws {
        var state = fxState()
        state.run.coins = 500
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        #expect(throws: PassiveUnlockError.alreadyUnlocked) {
            try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        }
    }

    @Test func floorMultiplierScalesPassive() throws {
        // c_law vive en f2; con f2 ×3 el pasivo del tipo se triplica.
        let boosted = fxConfig(f2IncomeMultiplier: 3.0)
        let boostedTable = try fxFloorTable(config: boosted)
        var state = fxState(units: ["c_law": 1])
        state.run.passiveUnlocked["c_law"] = true
        let base = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 0)
        let tripled = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: boostedTable, config: boosted, now: 0)
        #expect(abs(tripled - base * 3) < 1e-9)
    }

    @Test func charUpgradeDoublesTypeIncome() throws {
        var state = fxState(units: ["a": 2])
        state.run.passiveUnlocked["a"] = true
        let base = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 0)
        state.run.charUpgradeLevels["a"] = 1
        let doubled = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 0)
        #expect(abs(doubled - base * 2) < 1e-12)
    }
}

// MARK: - Tick (bible §2.4) + clamp de delta

@Suite("IncomeTicker")
struct IncomeTickTests {
    let config = fxConfig()
    let economy = fxEconomy()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    private func unlockedState() throws -> PlayerState {
        var state = fxState(units: ["a": 2])
        state.run.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        return state
    }

    @Test func tickIsProportionalToDelta() throws {
        var state = try unlockedState()
        let short = IncomeTicker.tick(state: &state, tiers: tiers, floorTable: floorTable, config: config, delta: 0.016, now: 0)
        var state2 = try unlockedState()
        let long = IncomeTicker.tick(state: &state2, tiers: tiers, floorTable: floorTable, config: config, delta: 1.0, now: 0)
        #expect(abs(long / short - 62.5) < 1e-6)
        #expect(abs(long - 0.6) < 1e-12)
    }

    @Test func tickAccumulatesLifetime() throws {
        var state = try unlockedState()
        let before = state.meta.lifetimeEarnings
        IncomeTicker.tick(state: &state, tiers: tiers, floorTable: floorTable, config: config, delta: 1.0, now: 0)
        #expect(abs(state.meta.lifetimeEarnings - before - 0.6) < 1e-12)
    }

    @Test func tickAppliesGlobalMultiplier() throws {
        var state = try unlockedState()
        state.meta.globalMultiplier = 2.0
        let earned = IncomeTicker.tick(state: &state, tiers: tiers, floorTable: floorTable, config: config, delta: 1.0, now: 0)
        #expect(abs(earned - 1.2) < 1e-12)
    }

    @Test func hugeDeltaAfterResumeIsIgnored() throws {
        var state = try unlockedState()
        let earned = IncomeTicker.tick(state: &state, tiers: tiers, floorTable: floorTable, config: config, delta: 3600, now: 0)
        #expect(earned == 0)
        #expect(state.run.coins == 0)
    }

    @Test func negativeDeltaIsIgnored() throws {
        var state = try unlockedState()
        #expect(IncomeTicker.tick(state: &state, tiers: tiers, floorTable: floorTable, config: config, delta: -1, now: 0) == 0)
    }
}

// MARK: - Offline (bible §3)

@Suite("OfflineCalculator")
struct OfflineTests {
    let config = fxConfig()
    let economy = fxEconomy()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    private func unlockedState() throws -> PlayerState {
        var state = fxState(units: ["a": 2])
        state.run.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        state.meta.lastSeenTimestamp = 1000
        return state
    }

    @Test func offlineIsCappedAtConfiguredHours() throws {
        let state = try unlockedState()
        let at8h = OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 1000 + 8 * 3600)
        let at20h = OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 1000 + 20 * 3600)
        #expect(at8h == at20h)
        // 2 unidades × 0.3 × 8h × 0.5 efficiency
        #expect(abs(at8h - 0.6 * 8 * 3600 * 0.5) < 1e-6)
    }

    @Test func offlineAppliesEfficiencyUpgrade() throws {
        var state = try unlockedState()
        state.meta.derivedEffects.offlineEfficiency = 1.0
        let full = OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 1000 + 3600)
        state.meta.derivedEffects.offlineEfficiency = 0.5
        let half = OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 1000 + 3600)
        #expect(abs(full - 2 * half) < 1e-9)
    }

    @Test func offlineIsZeroWithoutPassives() {
        var state = fxState(units: ["a": 2])
        state.meta.lastSeenTimestamp = 1000
        #expect(OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: config, now: 1000 + 3600) == 0)
    }

    @Test func applyCreditsCoinsAndStampsTimestamp() throws {
        var state = try unlockedState()
        let coinsBefore = state.run.coins
        let credited = OfflineCalculator.apply(state: &state, tiers: tiers, floorTable: floorTable, config: config, now: 1000 + 3600)
        #expect(credited > 0)
        #expect(abs(state.run.coins - coinsBefore - credited) < 1e-9)
        #expect(state.meta.lastSeenTimestamp == 1000 + 3600)
    }

    @Test func shortAbsencesCreditNothingButStamp() throws {
        var state = try unlockedState()
        let credited = OfflineCalculator.apply(state: &state, tiers: tiers, floorTable: floorTable, config: config, now: 1010)
        #expect(credited == 0)
        #expect(state.meta.lastSeenTimestamp == 1010)
    }
}

// MARK: - Reencarnación (F7 §3.7: gate por ORO)

@Suite("Reencarnación")
struct ReincarnationTests {
    let economy = fxEconomy()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    @Test func gateIsEarningAtLeastOneOro() {
        var state = fxState()
        #expect(!PrestigeCalculator.canReincarnate(state: state, economy: economy))
        // divisor fixture 1e6: lifetime 4e6 → oroTotal 2.
        state.meta.lifetimeEarnings = 4_000_000
        #expect(PrestigeCalculator.canReincarnate(state: state, economy: economy))
    }

    @Test func gainedOroIsTheDelta() {
        var state = fxState()
        state.meta.lifetimeEarnings = 4_000_000
        #expect(PrestigeCalculator.oroGained(state: state, economy: economy) == 2)
        state.meta.oroEarnedLifetime = 1
        #expect(PrestigeCalculator.oroGained(state: state, economy: economy) == 1)
    }

    @Test func applyResetsRunAndKeepsMeta() {
        var state = fxState(units: ["d": 1, "a": 1])
        state.run.coins = 5000
        state.run.hireCounts = ["f1": 12]
        state.run.passiveUnlocked = ["a": true]
        state.run.chosenCareerPath = "law"
        state.run.maxTierReached = 4
        state.run.charUpgradeLevels = ["a": 3]
        state.meta.lifetimeEarnings = 9_000_000
        state.meta.derivedEffects.tapMultiplier = 3
        state.meta.derivedEffects.prestigeBonus = 0
        state.meta.ownedSpecials = ["sp_cryptobro"]
        state.meta.removedAds = true

        PrestigeCalculator.applyReincarnation(state: &state, economy: economy, tiers: tiers, floorTable: floorTable, now: 2000)

        // ORO acreditado: floor(sqrt(9)) = 3.
        #expect(state.meta.oro == 3)
        #expect(state.meta.oroEarnedLifetime == 3)
        #expect(state.meta.prestigeLevel == 1)
        #expect(abs(state.meta.globalMultiplier - 1.06) < 1e-12)
        // Run muerta y fresca:
        #expect(state.run.coins == 0)
        #expect(state.run.units == ["a": 1])
        #expect(state.run.hireCounts.isEmpty)
        #expect(state.run.passiveUnlocked.isEmpty)
        #expect(state.run.chosenCareerPath == nil)
        #expect(state.run.maxTierReached == 1)
        #expect(state.run.charUpgradeLevels.isEmpty)
        #expect(state.run.unlockedFloors == ["f1"])
        // Meta preservada:
        #expect(state.meta.lifetimeEarnings == 9_000_000)
        #expect(state.meta.derivedEffects.tapMultiplier == 3)
        #expect(state.meta.ownedSpecials == ["sp_cryptobro"])
        #expect(state.meta.removedAds)
        #expect(state.meta.lastSeenTimestamp == 2000)
    }

    @Test func repeatedReincarnationNeverDoubleEarnsOro() {
        var state = fxState()
        state.meta.lifetimeEarnings = 4_000_000
        PrestigeCalculator.applyReincarnation(state: &state, economy: economy, tiers: tiers, floorTable: floorTable, now: 2000)
        #expect(state.meta.oro == 2)
        // Sin nuevas ganancias, otra reencarnación no suma ORO.
        PrestigeCalculator.applyReincarnation(state: &state, economy: economy, tiers: tiers, floorTable: floorTable, now: 3000)
        #expect(state.meta.oro == 2)
        #expect(state.meta.oroEarnedLifetime == 2)
        #expect(state.meta.prestigeLevel == 2)
    }

    @Test func spendingOroNeverLowersTheMultiplier() {
        var state = fxState()
        state.meta.lifetimeEarnings = 9_000_000
        PrestigeCalculator.applyReincarnation(state: &state, economy: economy, tiers: tiers, floorTable: floorTable, now: 2000)
        let multiplier = state.meta.globalMultiplier
        state.meta.oro = 0  // gastó todo
        // El multiplicador se computa sobre oroEarnedLifetime, no el balance.
        #expect(economy.globalMultiplier(oroEarnedLifetime: state.meta.oroEarnedLifetime, prestigeBonus: 0) == multiplier)
    }

    @Test func prestigeUnlocksDiscountAccumulatesAndCaps() {
        let unlocks = PrestigeUnlocks(
            schemaVersion: 1,
            spawnDiscountCap: 0.5,
            levels: (1...30).map { .init(level: $0, spawnCostDiscount: 0.05, unlockBackgrounds: [], unlockSkins: [], unlockSpecials: []) }
        )
        #expect(unlocks.cumulativeSpawnDiscount(atPrestigeLevel: 0) == 0)
        #expect(abs(unlocks.cumulativeSpawnDiscount(atPrestigeLevel: 2) - 0.1) < 1e-12)
        #expect(unlocks.cumulativeSpawnDiscount(atPrestigeLevel: 30) == 0.5)
    }
}
