import Foundation
import Testing
@testable import EconomyKit

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

private func makeType(_ id: String, tier: Int, tapYield: Double = 1, mergesInto: String? = nil) -> CharacterType {
    CharacterType(
        id: id, tier: tier, phase: .earth, displayName: id,
        spritePlaceholder: "sf:person.fill", spriteAssetKey: nil,
        tapYield: tapYield, passiveYieldPerInstance: tapYield * 0.3, passiveUnlockCost: tapYield * 100,
        mergesInto: mergesInto, isChoiceNode: false, choiceOptions: nil
    )
}

private func makeState() -> PlayerState {
    PlayerState.newGame(startTypeId: "a", offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 0)
}

/// a(T1) → b(T2) → c9_x(T3, dos "carreras") → d(T4)
private func makeTiers() throws -> TierRepository {
    try TierRepository(types: [
        makeType("a", tier: 1, mergesInto: "b"),
        makeType("b", tier: 2, mergesInto: "choice"),
        CharacterType(
            id: "choice", tier: 3, phase: .earth, displayName: "choice",
            spritePlaceholder: "sf:person.fill", spriteAssetKey: nil,
            tapYield: 14.44, passiveYieldPerInstance: 4.3, passiveUnlockCost: 1444,
            mergesInto: nil, isChoiceNode: true, choiceOptions: ["c_prog", "c_law"]
        ),
        makeType("c_prog", tier: 3, mergesInto: "d"),
        makeType("c_law", tier: 3, mergesInto: "d"),
        makeType("d", tier: 4),
    ])
}

@Suite("Acciones de juego (tap y spawn)")
struct GameActionsTests {
    let economy = makeEconomy()

    @Test func tapAddsGainAndLifetime() {
        var state = makeState()
        let type = makeType("a", tier: 1, tapYield: 1)
        let gain = economy.applyTap(type: type, state: &state)
        #expect(gain == 1)
        #expect(state.coins == 1)
        #expect(state.lifetimeEarnings == 1)
    }

    @Test func tapAppliesMultipliers() {
        var state = makeState()
        state.upgrades.tapMultiplier = 2
        state.globalMultiplier = 1.5
        let gain = economy.applyTap(type: makeType("a", tier: 1, tapYield: 10), state: &state)
        #expect(abs(gain - 30) < 1e-12)
        #expect(abs(state.lifetimeEarnings - 30) < 1e-12)
    }

    @Test func quoteOffersTierOneAtStart() throws {
        let tiers = try makeTiers()
        let quote = try #require(economy.spawnQuote(state: makeState(), tiers: tiers))
        #expect(quote.type.id == "a")
        #expect(quote.cost == 15)
    }

    @Test func quoteProgressesWithMaxTier() throws {
        let tiers = try makeTiers()
        var state = makeState()
        state.maxTierReached = 6
        let quote = try #require(economy.spawnQuote(state: state, tiers: tiers))
        #expect(quote.type.tier == 2)
        #expect(quote.type.id == "b")
    }

    @Test func quoteRespectsChosenCareerOnVariantTiers() throws {
        let tiers = try makeTiers()
        var state = makeState()
        state.maxTierReached = 7
        state.chosenCareerPath = "law"
        let quote = try #require(economy.spawnQuote(state: state, tiers: tiers))
        #expect(quote.type.id == "c_law")
    }

    @Test func quoteCostGrowsWithPurchasesOfThatType() throws {
        let tiers = try makeTiers()
        var state = makeState()
        state.spawnPurchases["a"] = 3
        let quote = try #require(economy.spawnQuote(state: state, tiers: tiers))
        #expect(abs(quote.cost - 15 * pow(1.15, 3)) < 1e-9)
    }

    @Test func totalBasisCountsEveryLifetimeSpawn() throws {
        var config = makeEconomy().config
        config = EconomyConfig(
            schemaVersion: config.schemaVersion,
            baseTapYieldTier1: config.baseTapYieldTier1,
            yieldGrowthPerTier: config.yieldGrowthPerTier,
            passiveRatio: config.passiveRatio,
            passiveUnlockCostMultiplier: config.passiveUnlockCostMultiplier,
            spawn: .init(baseCost: 15, costGrowth: 1.15, tierOffset: 4, costBasis: .total),
            critChanceBase: config.critChanceBase,
            critMultiplier: config.critMultiplier,
            offlineEfficiencyBase: config.offlineEfficiencyBase,
            offlineCapHours: config.offlineCapHours,
            prestige: config.prestige,
            board: config.board
        )
        let totalEconomy = StandardEconomy(config: config)
        let tiers = try makeTiers()
        var state = makeState()
        state.spawnPurchases = ["a": 2, "b": 3]
        let quote = try #require(totalEconomy.spawnQuote(state: state, tiers: tiers))
        // Exponente = 5 compras totales, aunque de "a" haya solo 2.
        #expect(abs(quote.cost - 15 * pow(1.15, 5)) < 1e-9)
        // El contador del quote sigue siendo per-type (lo usa applySpawn).
        #expect(quote.purchases == 2)
    }

    @Test func costBasisDefaultsToPerTypeWhenAbsentInJSON() throws {
        let json = """
        {"baseCost": 15, "costGrowth": 1.15, "tierOffset": 4}
        """
        let spawn = try JSONDecoder().decode(EconomyConfig.SpawnConfig.self, from: Data(json.utf8))
        #expect(spawn.costBasis == .perType)
    }

    @Test func spawnDeductsCoinsAndPlacesOnFirstFreeCell() throws {
        let tiers = try makeTiers()
        var state = makeState()
        state.coins = 20
        let quote = try #require(economy.spawnQuote(state: state, tiers: tiers))
        let placement = try economy.applySpawn(quote: quote, state: &state, boardCapacity: 35)
        #expect(placement.cellIndex == 1)
        #expect(abs(state.coins - 5) < 1e-9)
        #expect(state.spawnPurchases["a"] == 1)
        #expect(state.board.count == 2)
    }

    @Test func spawnFailsWithoutCoins() throws {
        let tiers = try makeTiers()
        var state = makeState()
        state.coins = 1
        let quote = try #require(economy.spawnQuote(state: state, tiers: tiers))
        #expect(throws: SpawnError.insufficientCoins) {
            try economy.applySpawn(quote: quote, state: &state, boardCapacity: 35)
        }
        #expect(state.coins == 1)
        #expect(state.board.count == 1)
    }

    @Test func spawnFailsWhenBoardFull() throws {
        let tiers = try makeTiers()
        var state = makeState()
        state.coins = 1000
        state.board = (0..<4).map { BoardPlacement(cellIndex: $0, typeId: "a") }
        let quote = try #require(economy.spawnQuote(state: state, tiers: tiers))
        #expect(throws: SpawnError.boardFull) {
            try economy.applySpawn(quote: quote, state: &state, boardCapacity: 4)
        }
    }
}
