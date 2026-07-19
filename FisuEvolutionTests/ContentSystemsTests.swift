import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// PRNG determinístico real (SplitMix64). Un generador de valor constante
/// cuelga `Int.random` (rechazo infinito en el muestreo de Lemire) — bug
/// encontrado en carne propia.
private struct FixedRNG: RandomNumberGenerator {
    var state: UInt64

    init(values: [UInt64]) {
        state = values.first ?? 42
    }

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite("Sistemas de contenido F5 (contra los JSON reales)")
@MainActor
struct ContentSystemsTests {
    let content: GameContent
    let economy: StandardEconomy

    init() throws {
        content = try GameContentLoader.load(from: .main)
        economy = StandardEconomy(config: content.economy)
    }

    private func makeState(maxTier: Int = 1, coins: Double = 0) -> PlayerState {
        var state = PlayerState.newGame(
            startTypeId: content.tiers.baseType.id,
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: content.economy.critChanceBase,
            now: 1000
        )
        state.maxTierReached = maxTier
        state.coins = coins
        return state
    }

    // MARK: Upgrades

    @Test func upgradePurchaseAppliesDerivedEffect() throws {
        var state = makeState(coins: 10_000)
        try UpgradeManager.purchase(
            lineId: "tap",
            state: &state,
            config: content.upgradesConfig,
            specials: content.specials,
            viral: content.viral,
            economy: economy
        )
        #expect(state.upgradeLevels["tap"] == 1)
        #expect(abs(state.upgrades.tapMultiplier - 1.25) < 1e-9)
        #expect(state.coins < 10_000)
    }

    @Test func upgradeCostGrowsExponentially() throws {
        let line = try #require(content.upgradesConfig.upgrades.first { $0.id == "income" })
        #expect(UpgradeManager.cost(of: line, level: 0) == 500)
        #expect(UpgradeManager.cost(of: line, level: 2) == 500 * 64)
    }

    @Test func upgradeRespectsMaxLevelAndCoins() throws {
        var state = makeState(coins: 100)
        #expect(throws: UpgradeManager.PurchaseError.insufficientCoins) {
            try UpgradeManager.purchase(lineId: "income", state: &state, config: content.upgradesConfig, specials: content.specials, viral: content.viral, economy: economy)
        }
        state.upgradeLevels["income"] = 20
        state.coins = 1e30
        #expect(throws: UpgradeManager.PurchaseError.maxLevelReached) {
            try UpgradeManager.purchase(lineId: "income", state: &state, config: content.upgradesConfig, specials: content.specials, viral: content.viral, economy: economy)
        }
    }

    @Test func sharesAddCappedIncomeBonus() {
        var state = makeState()
        state.sharesCompleted = 100 // por encima del cap (20)
        UpgradeManager.recomputeDerivedEffects(state: &state, config: content.upgradesConfig, specials: content.specials, viral: content.viral, economy: economy)
        #expect(abs(state.upgrades.incomeMultiplier - 1.1) < 1e-9)
    }

    // MARK: Eventos

    @Test func eventRollRespectsMinTierAndAppliesModifier() throws {
        var state = makeState(maxTier: 2)
        var rng = FixedRNG(values: [0])
        let roll = EventManager.fireRandomEvent(
            state: &state,
            config: content.events,
            tiers: content.tiers,
            economy: economy,
            now: 1000,
            lastFired: [:],
            rng: &rng
        )
        let fired = try #require(roll)
        #expect(fired.event.minTier <= 2)
        if fired.event.effectType == .incomeMultiplier {
            #expect(state.activeModifiers.contains { $0.sourceKey == "event.\(fired.event.id)" })
        }
    }

    @Test func eventCooldownExcludesRecentlyFired() {
        var state = makeState(maxTier: 30)
        var rng = FixedRNG(values: [0])
        let now = 1000.0
        let allRecent = Dictionary(uniqueKeysWithValues: content.events.events.map { ($0.id, now - 1) })
        let roll = EventManager.fireRandomEvent(
            state: &state, config: content.events, tiers: content.tiers,
            economy: economy, now: now, lastFired: allRecent, rng: &rng
        )
        #expect(roll == nil)
    }

    @Test func aguinaldoPaysPassiveIncomeSeconds() throws {
        var state = makeState(maxTier: 30)
        state.coins = 1e6
        try economy.applyPassiveUnlock(typeId: content.tiers.baseType.id, state: &state, tiers: content.tiers)
        let coinsBefore = state.coins
        var rng = FixedRNG(values: [0])
        // Forzar aguinaldo: solo él sin cooldown.
        let lastFired = Dictionary(uniqueKeysWithValues: content.events.events.filter { $0.id != "aguinaldo" }.map { ($0.id, 1000.0 - 1) })
        let roll = EventManager.fireRandomEvent(
            state: &state, config: content.events, tiers: content.tiers,
            economy: economy, now: 1000, lastFired: lastFired, rng: &rng
        )
        #expect(roll?.event.id == "aguinaldo")
        #expect(state.coins > coinsBefore)
    }

    // MARK: Boosts

    @Test func boostActivatesAndEntersCooldown() throws {
        var state = makeState()
        let chest = try BoostManager.activate(
            boostId: "cafe", state: &state, config: content.boosts,
            upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
            tiers: content.tiers, economy: economy, now: 1000
        )
        #expect(chest == nil)
        #expect(state.activeModifiers.contains { $0.sourceKey == "boost.cafe" && $0.effect == .tapMultiplier })

        #expect(throws: BoostManager.ActivationError.self) {
            try BoostManager.activate(
                boostId: "cafe", state: &state, config: content.boosts,
                upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
                tiers: content.tiers, economy: economy, now: 1001
            )
        }
    }

    @Test func milanesaPermanentlyImprovesOffline() throws {
        var state = makeState()
        let before = state.upgrades.offlineEfficiency
        _ = try BoostManager.activate(
            boostId: "milanesa", state: &state, config: content.boosts,
            upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
            tiers: content.tiers, economy: economy, now: 1000
        )
        #expect(abs(state.upgrades.offlineEfficiency - before - 0.05) < 1e-9)
    }

    @Test func asadoGrantsChestScaledToMaxTier() throws {
        var state = makeState(maxTier: 5)
        let chest = try BoostManager.activate(
            boostId: "asado", state: &state, config: content.boosts,
            upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
            tiers: content.tiers, economy: economy, now: 1000
        )
        let expected = economy.passiveUnlockCost(forTier: 5) * 4.0
        #expect(abs((chest ?? 0) - expected) < 1e-6)
        #expect(abs(state.coins - expected) < 1e-6)
    }

    // MARK: Specials

    @Test func specialDropAppliesPassiveEffectViaDerivation() {
        var state = makeState(maxTier: 30)
        var rng = FixedRNG(seed: 7)
        // dropChance ~0.5%: con seed fija, iterar merges hasta el drop es
        // determinístico (esperado ≈ p50 en ~140 tiradas).
        var dropped: SpecialsConfig.Special?
        for _ in 0..<10_000 where dropped == nil {
            dropped = SpecialDropManager.rollOnMerge(
                state: &state, config: content.specials,
                upgrades: content.upgradesConfig, viral: content.viral,
                economy: economy, rng: &rng
            )
        }
        #expect(dropped != nil)
        #expect(state.ownedSpecials.count == 1)
        // Prestige 0: los secretos no pueden caer.
        #expect(dropped?.requiresPrestigeLevel == 0)
    }

    @Test func specialsNeverDropTwice() {
        var state = makeState(maxTier: 30)
        state.ownedSpecials = content.specials.specials.map(\.id)
        var rng = FixedRNG(values: [0])
        let dropped = SpecialDropManager.rollOnMerge(
            state: &state, config: content.specials,
            upgrades: content.upgradesConfig, viral: content.viral,
            economy: economy, rng: &rng
        )
        #expect(dropped == nil)
    }

    // MARK: Daily

    @Test func dailyClaimGrantsCoinsAndAdvancesCycle() throws {
        var state = makeState(maxTier: 3)
        var rng = FixedRNG(values: [0])
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let claim = try #require(DailyRewardManager.claimIfAvailable(
            state: &state, config: content.dailyRewards, specials: content.specials,
            upgrades: content.upgradesConfig, viral: content.viral, economy: economy,
            today: today, rng: &rng
        ))
        #expect(claim.day.day == 1)
        #expect(claim.coinsGranted > 0)
        #expect(state.daily.cycleDay == 2)

        // Mismo día: no hay segundo claim.
        let second = DailyRewardManager.claimIfAvailable(
            state: &state, config: content.dailyRewards, specials: content.specials,
            upgrades: content.upgradesConfig, viral: content.viral, economy: economy,
            today: today, rng: &rng
        )
        #expect(second == nil)
    }

    @Test func skippedDayResetsCycle() throws {
        var state = makeState()
        state.daily.cycleDay = 5
        state.daily.lastClaimDay = "2023-11-10"
        var rng = FixedRNG(values: [0])
        // 2023-11-14 (calendario local): hay días salteados desde el 10 → reset.
        let today = try #require(Calendar.current.date(from: DateComponents(year: 2023, month: 11, day: 14, hour: 12)))
        let claim = try #require(DailyRewardManager.claimIfAvailable(
            state: &state, config: content.dailyRewards, specials: content.specials,
            upgrades: content.upgradesConfig, viral: content.viral, economy: economy,
            today: today, rng: &rng
        ))
        #expect(claim.day.day == 1)
    }
}
