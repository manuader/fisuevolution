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

@Suite("Sistemas de contenido F7 (contra los JSON reales)")
@MainActor
struct ContentSystemsTests {
    let content: GameContent
    let economy: StandardEconomy

    init() throws {
        content = try GameContentLoader.load(from: .main)
        economy = StandardEconomy(config: content.economy)
    }

    /// Estado v4 (run/meta): tipo base en el primer piso de la torre. Los ids
    /// salen de la data (`baseType`, `floorTable[0]`), nunca hardcodeados.
    private func makeState(maxTier: Int = 1, coins: Double = 0) -> PlayerState {
        var state = PlayerState.newGame(
            startTypeId: content.tiers.baseType.id,
            startFloorId: content.floorTable[0].id,
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: content.economy.critChanceBase,
            now: 1000
        )
        state.run.maxTierReached = maxTier
        state.run.coins = coins
        return state
    }

    // MARK: Upgrades

    @Test func oroUpgradePurchaseAppliesDerivedEffectWithoutSpendingCoins() throws {
        var state = makeState(coins: 10_000)
        state.meta.oro = 10
        try UpgradeManager.purchase(
            lineId: "tap",
            state: &state,
            config: content.upgradesConfig,
            specials: content.specials,
            viral: content.viral,
            economy: economy
        )
        #expect(state.meta.oroUpgradeLevels["tap"] == 1)
        #expect(abs(state.meta.derivedEffects.tapMultiplier - 1.25) < 1e-9)
        #expect(state.meta.oro == 9)
        #expect(state.run.coins == 10_000)
    }

    @Test func upgradeCostGrowsExponentially() throws {
        let line = try #require(content.upgradesConfig.upgrades.first { $0.id == "income" })
        #expect(UpgradeManager.cost(of: line, level: 0) == 1)
        #expect(UpgradeManager.cost(of: line, level: 2) == 4)
    }

    @Test func oroUpgradeRespectsMaxLevelAndBalance() throws {
        var state = makeState(coins: 100)
        #expect(throws: UpgradeManager.PurchaseError.insufficientOro) {
            try UpgradeManager.purchase(lineId: "income", state: &state, config: content.upgradesConfig, specials: content.specials, viral: content.viral, economy: economy)
        }
        state.meta.oroUpgradeLevels["income"] = 20
        state.meta.oro = 1_000
        #expect(throws: UpgradeManager.PurchaseError.maxLevelReached) {
            try UpgradeManager.purchase(lineId: "income", state: &state, config: content.upgradesConfig, specials: content.specials, viral: content.viral, economy: economy)
        }
    }

    @Test func sharesAddCappedIncomeBonus() {
        var state = makeState()
        state.meta.sharesCompleted = 100 // por encima del cap (20)
        UpgradeManager.recomputeDerivedEffects(state: &state, config: content.upgradesConfig, specials: content.specials, viral: content.viral, economy: economy)
        #expect(abs(state.meta.derivedEffects.incomeMultiplier - 1.1) < 1e-9)
    }

    // MARK: Eventos

    @Test func eventRollRespectsMinTierAndAppliesModifier() throws {
        var state = makeState(maxTier: 2)
        var rng = FixedRNG(values: [0])
        let roll = EventManager.fireRandomEvent(
            state: &state,
            config: content.events,
            tiers: content.tiers,
            floorTable: content.floorTable,
            economy: economy,
            now: 1000,
            lastFired: [:],
            rng: &rng
        )
        let fired = try #require(roll)
        #expect(fired.event.minTier <= 2)
        if fired.event.effectType == .incomeMultiplier {
            #expect(state.run.activeModifiers.contains { $0.sourceKey == "event.\(fired.event.id)" })
        }
    }

    @Test func eventCooldownExcludesRecentlyFired() {
        var state = makeState(maxTier: 30)
        var rng = FixedRNG(values: [0])
        let now = 1000.0
        let allRecent = Dictionary(uniqueKeysWithValues: content.events.events.map { ($0.id, now - 1) })
        let roll = EventManager.fireRandomEvent(
            state: &state, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
            economy: economy, now: now, lastFired: allRecent, rng: &rng
        )
        #expect(roll == nil)
    }

    @Test func aguinaldoPaysPassiveIncomeSeconds() throws {
        var state = makeState(maxTier: 30)
        state.run.coins = 1e6
        try economy.applyPassiveUnlock(typeId: content.tiers.baseType.id, state: &state, tiers: content.tiers)
        let coinsBefore = state.run.coins
        var rng = FixedRNG(values: [0])
        // Forzar aguinaldo: solo él sin cooldown.
        let lastFired = Dictionary(uniqueKeysWithValues: content.events.events.filter { $0.id != "aguinaldo" }.map { ($0.id, 1000.0 - 1) })
        let roll = EventManager.fireRandomEvent(
            state: &state, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
            economy: economy, now: 1000, lastFired: lastFired, rng: &rng
        )
        #expect(roll?.event.id == "aguinaldo")
        #expect(state.run.coins > coinsBefore)
    }

    @Test func blanqueoReturnsUnitTypeWithoutPlacing() throws {
        // freeHighTier post-F7: el evento YA NO coloca en ningún board — devuelve
        // el typeId y el caller (GameState) lo ubica en la torre.
        var state = makeState(maxTier: 9)
        let unitsBefore = state.run.units
        var rng = FixedRNG(values: [0])
        let lastFired = Dictionary(uniqueKeysWithValues: content.events.events.filter { $0.id != "blanqueo" }.map { ($0.id, 1000.0 - 1) })
        let roll = try #require(EventManager.fireRandomEvent(
            state: &state, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
            economy: economy, now: 1000, lastFired: lastFired, rng: &rng
        ))
        #expect(roll.event.id == "blanqueo")
        let granted = try #require(roll.grantedUnitTypeId)
        // magnitude 2 → tier máximo alcanzado − 2.
        #expect(content.tiers.type(id: granted)?.tier == 7)
        #expect(roll.unitsChanged == false)
        #expect(state.run.units == unitsBefore)
    }

    @Test func startupCompradaEvolvesTopUnitAndFlagsUnitsChanged() throws {
        // instantEvolution muta run.units (merge gratis conceptual) y marca
        // unitsChanged para que el caller re-sincronice la torre.
        var state = makeState(maxTier: 5)
        let base = content.tiers.baseType
        let nextId = try #require(base.mergesInto)
        var rng = FixedRNG(values: [0])
        let lastFired = Dictionary(uniqueKeysWithValues: content.events.events.filter { $0.id != "startup_comprada" }.map { ($0.id, 1000.0 - 1) })
        let roll = try #require(EventManager.fireRandomEvent(
            state: &state, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
            economy: economy, now: 1000, lastFired: lastFired, rng: &rng
        ))
        #expect(roll.event.id == "startup_comprada")
        #expect(roll.unitsChanged)
        #expect(roll.grantedUnitTypeId == nil)
        #expect(state.run.units[base.id] == nil)
        #expect(state.run.units[nextId] == 1)
        // Evolucionar a T2 no baja el máximo histórico de la run.
        #expect(state.run.maxTierReached == 5)
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
        #expect(state.run.activeModifiers.contains { $0.sourceKey == "boost.cafe" && $0.effect == .tapMultiplier })

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
        let before = state.meta.derivedEffects.offlineEfficiency
        _ = try BoostManager.activate(
            boostId: "milanesa", state: &state, config: content.boosts,
            upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
            tiers: content.tiers, economy: economy, now: 1000
        )
        #expect(abs(state.meta.derivedEffects.offlineEfficiency - before - 0.05) < 1e-9)
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
        #expect(abs(state.run.coins - expected) < 1e-6)
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
        #expect(state.meta.ownedSpecials.count == 1)
        // Prestige 0: los secretos no pueden caer.
        #expect(dropped?.requiresPrestigeLevel == 0)
    }

    @Test func specialsNeverDropTwice() {
        var state = makeState(maxTier: 30)
        state.meta.ownedSpecials = content.specials.specials.map(\.id)
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
        #expect(state.meta.daily.cycleDay == 2)

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
        state.meta.daily.cycleDay = 5
        state.meta.daily.lastClaimDay = "2023-11-10"
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
