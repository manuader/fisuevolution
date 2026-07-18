import Foundation
import Testing
@testable import EconomyKit

// MARK: - Fixtures compartidas de F2

private func makeEconomy() -> StandardEconomy {
    StandardEconomy(config: EconomyConfig(
        schemaVersion: 1,
        baseTapYieldTier1: 1,
        yieldGrowthPerTier: 3.8,
        passiveRatio: 0.3,
        passiveUnlockCostMultiplier: 100,
        spawn: .init(baseCost: 15, costGrowth: 1.15, tierOffset: 4),
        critChanceBase: 0,
        critMultiplier: 5,
        offlineEfficiencyBase: 0.5,
        offlineCapHours: 8,
        prestige: .init(soulPointsDivisor: 1_000_000, soulPointsExponent: 0.5, globalMultiplierPerSoulPoint: 0.02),
        board: .init(columns: 5, rows: 7)
    ))
}

private func makeType(
    _ id: String,
    tier: Int,
    tapYield: Double = 1,
    mergesInto: String? = nil,
    isChoiceNode: Bool = false,
    choiceOptions: [String]? = nil
) -> CharacterType {
    CharacterType(
        id: id, tier: tier, phase: .earth, displayName: id,
        spritePlaceholder: "sf:person.fill", spriteAssetKey: nil,
        tapYield: tapYield, passiveYieldPerInstance: tapYield * 0.3, passiveUnlockCost: tapYield * 100,
        mergesInto: mergesInto, isChoiceNode: isChoiceNode, choiceOptions: choiceOptions
    )
}

/// Escalera con choice node en T3 (espejo chico de la real con carrera en T9):
/// a(1) → b(2) → [choice] c_prog/c_law (3) → d(4, terminal)
private func makeTiers() throws -> TierRepository {
    try TierRepository(types: [
        makeType("a", tier: 1, mergesInto: "b"),
        makeType("b", tier: 2, mergesInto: "choice"),
        makeType("choice", tier: 3, isChoiceNode: true, choiceOptions: ["c_prog", "c_law"]),
        makeType("c_prog", tier: 3, tapYield: 14.44, mergesInto: "d"),
        makeType("c_law", tier: 3, tapYield: 14.44, mergesInto: "d"),
        makeType("d", tier: 4, tapYield: 54.87),
    ])
}

private func makeState(board: [(Int, String)] = [(0, "a")]) -> PlayerState {
    var state = PlayerState.newGame(startTypeId: "a", offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 1000)
    state.board = board.map { BoardPlacement(cellIndex: $0.0, typeId: $0.1) }
    return state
}

// MARK: - Merge (bible §2.3 regla 2 + carrera)

@Suite("MergeRules")
struct MergeRulesTests {
    let tiers: TierRepository

    init() throws {
        tiers = try makeTiers()
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

// MARK: - Board

@Suite("BoardActions")
struct BoardActionsTests {
    let tiers: TierRepository

    init() throws {
        tiers = try makeTiers()
    }

    @Test func moveToEmptyCellSucceeds() {
        var state = makeState(board: [(0, "a")])
        #expect(BoardActions.moveUnit(fromCell: 0, toCell: 5, state: &state))
        #expect(state.board == [BoardPlacement(cellIndex: 5, typeId: "a")])
    }

    @Test func moveToOccupiedCellIsRejected() {
        var state = makeState(board: [(0, "a"), (1, "b")])
        #expect(!BoardActions.moveUnit(fromCell: 0, toCell: 1, state: &state))
        #expect(state.board.count == 2)
    }

    @Test func mergeConsumesPairAndAdvancesMaxTier() {
        var state = makeState(board: [(0, "a"), (1, "a")])
        BoardActions.applyMerge(sourceCell: 0, targetCell: 1, newTypeId: "b", state: &state, tiers: tiers)
        #expect(state.board == [BoardPlacement(cellIndex: 1, typeId: "b")])
        #expect(state.maxTierReached == 2)
    }

    @Test func mergeNeverLowersMaxTier() {
        var state = makeState(board: [(0, "a"), (1, "a")])
        state.maxTierReached = 4
        BoardActions.applyMerge(sourceCell: 0, targetCell: 1, newTypeId: "b", state: &state, tiers: tiers)
        #expect(state.maxTierReached == 4)
    }
}

// MARK: - Pasivo por tipo (bible §2.3 regla 3)

@Suite("Pasivo por tipo")
struct PassiveTests {
    let economy = makeEconomy()
    let tiers: TierRepository

    init() throws {
        tiers = try makeTiers()
    }

    @Test func lockedTypeYieldsZero() {
        let state = makeState(board: [(0, "a"), (1, "a")])
        #expect(IncomeTicker.passivePerSecond(state: state, tiers: tiers) == 0)
    }

    @Test func unlockAffectsAllInstancesOfThatTypeOnly() throws {
        var state = makeState(board: [(0, "a"), (1, "a"), (2, "a"), (3, "b")])
        state.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        #expect(state.coins == 0)
        // 3 fisuras × 0.3 × mult 1.0; el 'b' sigue sin generar.
        #expect(abs(IncomeTicker.passivePerSecond(state: state, tiers: tiers) - 0.9) < 1e-12)
    }

    @Test func unlocksAreIndependentPerType() throws {
        var state = makeState(board: [(0, "a"), (1, "b")])
        state.coins = 1000
        try economy.applyPassiveUnlock(typeId: "b", state: &state, tiers: tiers)
        // Solo 'b': 1 × (3.8... no: b tapYield 1 default) — b yield 0.3.
        #expect(abs(IncomeTicker.passivePerSecond(state: state, tiers: tiers) - 0.3) < 1e-12)
    }

    @Test func unlockFailsWithoutCoins() {
        var state = makeState()
        state.coins = 99
        #expect(throws: PassiveUnlockError.insufficientCoins) {
            try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        }
    }

    @Test func unlockFailsIfAlreadyUnlocked() throws {
        var state = makeState()
        state.coins = 500
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        #expect(throws: PassiveUnlockError.alreadyUnlocked) {
            try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        }
    }
}

// MARK: - Tick (bible §2.4) + clamp de delta

@Suite("IncomeTicker")
struct IncomeTickTests {
    let economy = makeEconomy()
    let tiers: TierRepository

    init() throws {
        tiers = try makeTiers()
    }

    private func unlockedState() throws -> PlayerState {
        var state = makeState(board: [(0, "a"), (1, "a")])
        state.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        return state
    }

    @Test func tickIsProportionalToDelta() throws {
        var state = try unlockedState()
        let short = IncomeTicker.tick(state: &state, tiers: tiers, delta: 0.016)
        var state2 = try unlockedState()
        let long = IncomeTicker.tick(state: &state2, tiers: tiers, delta: 1.0)
        #expect(abs(long / short - 62.5) < 1e-6)
        #expect(abs(long - 0.6) < 1e-12)
    }

    @Test func tickAccumulatesLifetime() throws {
        var state = try unlockedState()
        let before = state.lifetimeEarnings
        IncomeTicker.tick(state: &state, tiers: tiers, delta: 1.0)
        #expect(abs(state.lifetimeEarnings - before - 0.6) < 1e-12)
    }

    @Test func tickAppliesGlobalMultiplier() throws {
        var state = try unlockedState()
        state.globalMultiplier = 2.0
        let earned = IncomeTicker.tick(state: &state, tiers: tiers, delta: 1.0)
        #expect(abs(earned - 1.2) < 1e-12)
    }

    @Test func hugeDeltaAfterResumeIsIgnored() throws {
        var state = try unlockedState()
        let earned = IncomeTicker.tick(state: &state, tiers: tiers, delta: 3600)
        #expect(earned == 0)
        #expect(state.coins == 0)
    }

    @Test func negativeDeltaIsIgnored() throws {
        var state = try unlockedState()
        #expect(IncomeTicker.tick(state: &state, tiers: tiers, delta: -1) == 0)
    }
}

// MARK: - Offline (bible §3)

@Suite("OfflineCalculator")
struct OfflineTests {
    let economy = makeEconomy()
    let tiers: TierRepository

    init() throws {
        tiers = try makeTiers()
    }

    private func unlockedState() throws -> PlayerState {
        var state = makeState(board: [(0, "a"), (1, "a")])
        state.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        state.lastSeenTimestamp = 1000
        return state
    }

    @Test func offlineIsCappedAtConfiguredHours() throws {
        let state = try unlockedState()
        let config = economy.config
        let at8h = OfflineCalculator.earnings(state: state, tiers: tiers, config: config, now: 1000 + 8 * 3600)
        let at20h = OfflineCalculator.earnings(state: state, tiers: tiers, config: config, now: 1000 + 20 * 3600)
        #expect(at8h == at20h)
        // 2 unidades × 0.3 × 8h × 0.5 efficiency
        #expect(abs(at8h - 0.6 * 8 * 3600 * 0.5) < 1e-6)
    }

    @Test func offlineAppliesEfficiencyUpgrade() throws {
        var state = try unlockedState()
        state.upgrades.offlineEfficiency = 1.0
        let full = OfflineCalculator.earnings(state: state, tiers: tiers, config: economy.config, now: 1000 + 3600)
        state.upgrades.offlineEfficiency = 0.5
        let half = OfflineCalculator.earnings(state: state, tiers: tiers, config: economy.config, now: 1000 + 3600)
        #expect(abs(full - 2 * half) < 1e-9)
    }

    @Test func offlineIsZeroWithoutPassives() {
        var state = makeState(board: [(0, "a"), (1, "a")])
        state.lastSeenTimestamp = 1000
        #expect(OfflineCalculator.earnings(state: state, tiers: tiers, config: economy.config, now: 1000 + 3600) == 0)
    }

    @Test func applyCreditsCoinsAndStampsTimestamp() throws {
        var state = try unlockedState()
        let credited = OfflineCalculator.apply(state: &state, tiers: tiers, config: economy.config, now: 1000 + 3600)
        #expect(credited > 0)
        #expect(abs(state.coins - credited) < 1e-9)
        #expect(state.lastSeenTimestamp == 1000 + 3600)
    }

    @Test func shortAbsencesCreditNothingButStamp() throws {
        var state = try unlockedState()
        let credited = OfflineCalculator.apply(state: &state, tiers: tiers, config: economy.config, now: 1010)
        #expect(credited == 0)
        #expect(state.lastSeenTimestamp == 1010)
    }
}

// MARK: - Prestige (bible §5)

@Suite("PrestigeCalculator")
struct PrestigeTests {
    let economy = makeEconomy()
    let tiers: TierRepository

    init() throws {
        tiers = try makeTiers()
    }

    @Test func prestigeRequiresTerminalOnBoard() {
        #expect(!PrestigeCalculator.canPrestige(state: makeState(), tiers: tiers))
        #expect(PrestigeCalculator.canPrestige(state: makeState(board: [(0, "d")]), tiers: tiers))
    }

    @Test func gainedSoulPointsAreTheDelta() {
        var state = makeState()
        state.lifetimeEarnings = 4_000_000
        #expect(PrestigeCalculator.soulPointsGained(state: state, economy: economy) == 2)
        state.soulPoints = 1
        #expect(PrestigeCalculator.soulPointsGained(state: state, economy: economy) == 1)
    }

    @Test func applyResetsRunAndKeepsMeta() throws {
        var state = makeState(board: [(0, "d"), (3, "a")])
        state.coins = 5000
        state.lifetimeEarnings = 9_000_000
        state.spawnPurchases = ["a": 12]
        state.passiveUnlocked = ["a": true]
        state.chosenCareerPath = "law"
        state.maxTierReached = 4
        state.upgrades.tapMultiplier = 3
        state.ownedSpecials = ["sp_cryptobro"]
        state.removedAds = true

        PrestigeCalculator.applyPrestige(state: &state, economy: economy, tiers: tiers, now: 2000)

        #expect(state.soulPoints == 3)
        #expect(state.prestigeLevel == 1)
        #expect(abs(state.globalMultiplier - 1.06) < 1e-12)
        #expect(state.coins == 0)
        #expect(state.board == [BoardPlacement(cellIndex: 0, typeId: "a")])
        #expect(state.spawnPurchases.isEmpty)
        #expect(state.passiveUnlocked.isEmpty)
        #expect(state.chosenCareerPath == nil)
        #expect(state.maxTierReached == 1)
        // Meta preservada:
        #expect(state.lifetimeEarnings == 9_000_000)
        #expect(state.upgrades.tapMultiplier == 3)
        #expect(state.ownedSpecials == ["sp_cryptobro"])
        #expect(state.removedAds)
        #expect(state.lastSeenTimestamp == 2000)
    }

    @Test func repeatedPrestigeNeverDoubleEarnsPoints() {
        var state = makeState(board: [(0, "d")])
        state.lifetimeEarnings = 4_000_000
        PrestigeCalculator.applyPrestige(state: &state, economy: economy, tiers: tiers, now: 2000)
        #expect(state.soulPoints == 2)
        // Sin nuevas ganancias, otro prestige no suma puntos.
        state.board = [BoardPlacement(cellIndex: 0, typeId: "d")]
        PrestigeCalculator.applyPrestige(state: &state, economy: economy, tiers: tiers, now: 3000)
        #expect(state.soulPoints == 2)
        #expect(state.prestigeLevel == 2)
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
