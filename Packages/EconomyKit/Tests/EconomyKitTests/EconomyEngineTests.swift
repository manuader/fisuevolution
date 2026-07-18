import Foundation
import Testing
@testable import EconomyKit

private func makeConfig(tierOffset: Int = 4) -> EconomyConfig {
    EconomyConfig(
        schemaVersion: 1,
        baseTapYieldTier1: 1,
        yieldGrowthPerTier: 3.8,
        passiveRatio: 0.3,
        passiveUnlockCostMultiplier: 100,
        spawn: .init(baseCost: 15, costGrowth: 1.15, tierOffset: tierOffset),
        critChanceBase: 0,
        critMultiplier: 5,
        offlineEfficiencyBase: 0.5,
        offlineCapHours: 8,
        prestige: .init(soulPointsDivisor: 1_000_000, soulPointsExponent: 0.5, globalMultiplierPerSoulPoint: 0.02),
        board: .init(columns: 5, rows: 7)
    )
}

@Suite("StandardEconomy formulas (bible §3)")
struct EconomyEngineTests {
    let economy = StandardEconomy(config: makeConfig())

    @Test func tapYieldMatchesFormula() {
        #expect(economy.tapYield(forTier: 1) == 1)
        #expect(abs(economy.tapYield(forTier: 2) - 3.8) < 1e-12)
        #expect(abs(economy.tapYield(forTier: 9) - pow(3.8, 8)) < 1e-6)
    }

    @Test func tapYieldIsStrictlyIncreasing() {
        for tier in 1..<30 {
            #expect(economy.tapYield(forTier: tier + 1) > economy.tapYield(forTier: tier))
        }
    }

    @Test func passiveYieldIsRatioOfTap() {
        for tier in [1, 5, 17, 30] {
            #expect(abs(economy.passiveYield(forTier: tier) - economy.tapYield(forTier: tier) * 0.3) < 1e-9)
        }
    }

    @Test func passiveUnlockCostIsMultipleOfTap() {
        for tier in [1, 9, 30] {
            #expect(abs(economy.passiveUnlockCost(forTier: tier) - economy.tapYield(forTier: tier) * 100) < 1e-9)
        }
    }

    @Test func spawnTierProgressesWithMaxTierAndClampsAtOne() {
        #expect(economy.spawnTier(maxTierReached: 1) == 1)
        #expect(economy.spawnTier(maxTierReached: 4) == 1)
        #expect(economy.spawnTier(maxTierReached: 5) == 1)
        #expect(economy.spawnTier(maxTierReached: 9) == 5)
        #expect(economy.spawnTier(maxTierReached: 30) == 26)
    }

    @Test func spawnCostCurveMatchesBible() {
        #expect(abs(economy.spawnCost(spawnTier: 1, purchases: 0) - 15) < 1e-9)
        #expect(abs(economy.spawnCost(spawnTier: 1, purchases: 1) - 17.25) < 1e-9)
        #expect(abs(economy.spawnCost(spawnTier: 1, purchases: 2) - 19.8375) < 1e-9)
    }

    @Test func spawnCostScalesWithSpawnedTier() {
        let tier1 = economy.spawnCost(spawnTier: 1, purchases: 0)
        let tier5 = economy.spawnCost(spawnTier: 5, purchases: 0)
        #expect(abs(tier5 / tier1 - pow(3.8, 4)) < 1e-9)
    }

    @Test func soulPointsMatchesBibleFormula() {
        #expect(economy.soulPoints(lifetimeEarnings: 0) == 0)
        #expect(economy.soulPoints(lifetimeEarnings: 999_999) == 0)
        #expect(economy.soulPoints(lifetimeEarnings: 1_000_000) == 1)
        #expect(economy.soulPoints(lifetimeEarnings: 4_000_000) == 2)
        #expect(economy.soulPoints(lifetimeEarnings: 1e12) == 1000)
    }

    @Test func soulPointsClampsInsteadOfTrapping() {
        #expect(economy.soulPoints(lifetimeEarnings: .greatestFiniteMagnitude) == .max)
        #expect(StandardEconomy.clampedFloor(1e19) == .max)
        #expect(StandardEconomy.clampedFloor(1e20) == .max)
        #expect(StandardEconomy.clampedFloor(.infinity) == .max)
        #expect(StandardEconomy.clampedFloor(-5) == 0)
    }

    @Test func globalMultiplierPerSoulPoint() {
        #expect(economy.globalMultiplier(soulPoints: 0) == 1.0)
        #expect(abs(economy.globalMultiplier(soulPoints: 50) - 2.0) < 1e-12)
    }
}
