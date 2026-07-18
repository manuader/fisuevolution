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

private func makeType(_ id: String, tier: Int, mergesInto: String? = nil) -> CharacterType {
    CharacterType(
        id: id, tier: tier, phase: .earth, displayName: id,
        spritePlaceholder: "sf:person.fill", spriteAssetKey: nil,
        tapYield: 1, passiveYieldPerInstance: 0.3, passiveUnlockCost: 100,
        mergesInto: mergesInto, isChoiceNode: false, choiceOptions: nil
    )
}

@Suite("ActiveModifier (rewarded/eventos/boosts)")
struct ActiveModifierTests {
    let economy = makeEconomy()
    let tiers: TierRepository

    init() throws {
        tiers = try TierRepository(types: [makeType("a", tier: 1, mergesInto: "b"), makeType("b", tier: 2)])
    }

    private func stateWithModifier(_ effect: ActiveModifier.Effect, magnitude: Double, expiresAt: TimeInterval) -> PlayerState {
        var state = PlayerState.newGame(startTypeId: "a", offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 0)
        state.activeModifiers = [
            ActiveModifier(effect: effect, magnitude: magnitude, expiresAt: expiresAt, sourceKey: "test")
        ]
        return state
    }

    @Test func incomeModifierMultipliesTapAndPassive() throws {
        var state = stateWithModifier(.incomeMultiplier, magnitude: 2.0, expiresAt: 100)
        let gain = economy.applyTap(type: makeType("a", tier: 1), state: &state, now: 50)
        #expect(gain == 2.0)

        state.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        #expect(abs(IncomeTicker.passivePerSecond(state: state, tiers: tiers, now: 50) - 0.6) < 1e-12)
    }

    @Test func expiredModifierHasNoEffect() {
        var state = stateWithModifier(.incomeMultiplier, magnitude: 2.0, expiresAt: 100)
        let gain = economy.applyTap(type: makeType("a", tier: 1), state: &state, now: 100)
        #expect(gain == 1.0)
    }

    @Test func tapModifierDoesNotAffectPassive() throws {
        var state = stateWithModifier(.tapMultiplier, magnitude: 3.0, expiresAt: 100)
        state.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        #expect(abs(IncomeTicker.passivePerSecond(state: state, tiers: tiers, now: 50) - 0.3) < 1e-12)
        let gain = economy.applyTap(type: makeType("a", tier: 1), state: &state, now: 50)
        #expect(gain == 3.0)
    }

    @Test func modifiersStack() {
        var state = stateWithModifier(.incomeMultiplier, magnitude: 2.0, expiresAt: 100)
        state.activeModifiers.append(
            ActiveModifier(effect: .incomeMultiplier, magnitude: 3.0, expiresAt: 100, sourceKey: "test2")
        )
        let gain = economy.applyTap(type: makeType("a", tier: 1), state: &state, now: 50)
        #expect(gain == 6.0)
    }

    @Test func spawnCostModifierDiscountsQuote() throws {
        let state = stateWithModifier(.spawnCostMultiplier, magnitude: 0.7, expiresAt: 100)
        let quote = try #require(economy.spawnQuote(state: state, tiers: tiers, now: 50))
        #expect(abs(quote.cost - 15 * 0.7) < 1e-9)
        let expired = try #require(economy.spawnQuote(state: state, tiers: tiers, now: 200))
        #expect(abs(expired.cost - 15) < 1e-9)
    }

    @Test func permanentModifierNeverExpires() {
        var state = stateWithModifier(.incomeMultiplier, magnitude: 1.5, expiresAt: .infinity)
        let gain = economy.applyTap(type: makeType("a", tier: 1), state: &state, now: 1e12)
        #expect(abs(gain - 1.5) < 1e-12)
    }

    @Test func pruneRemovesOnlyExpired() {
        var state = stateWithModifier(.incomeMultiplier, magnitude: 2, expiresAt: 100)
        state.activeModifiers.append(
            ActiveModifier(effect: .tapMultiplier, magnitude: 2, expiresAt: 500, sourceKey: "vivo")
        )
        let pruned = ModifierMath.prune(&state, now: 200)
        #expect(pruned)
        #expect(state.activeModifiers.count == 1)
        #expect(state.activeModifiers[0].sourceKey == "vivo")
        #expect(!ModifierMath.prune(&state, now: 200))
    }
}
