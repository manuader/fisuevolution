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
        // La línea `tap` pasó de 20 niveles × 0,25 a 10 × 0,5 en el rebalance
        // (mismo efecto TOTAL al tope, +5,0): un nivel ahora vale 0,5.
        #expect(abs(state.meta.derivedEffects.tapMultiplier - 1.5) < 1e-9)
        #expect(state.meta.oro == 9)
        #expect(state.run.coins == 10_000)
    }

    @Test func upgradeCostGrowsExponentially() throws {
        let line = try #require(content.upgradesConfig.upgrades.first { $0.id == "income" })
        // `baseCost × costGrowth^nivel`. El rebalance bajó el growth de `income`
        // de 2,0 a 1,10 para que las siete líneas cuesten algo comparable
        // (`crit` era el 99,99 % del costo de ganar): 1 × 1,10² = 1,21.
        #expect(UpgradeManager.cost(of: line, level: 0) == 1)
        #expect(abs(UpgradeManager.cost(of: line, level: 2) - 1.21) < 1e-9)
        #expect(UpgradeManager.cost(of: line, level: 2) > UpgradeManager.cost(of: line, level: 1))
    }

    @Test func oroUpgradeRespectsMaxLevelAndBalance() throws {
        var state = makeState(coins: 100)
        #expect(throws: UpgradeManager.PurchaseError.insufficientOro) {
            try UpgradeManager.purchase(lineId: "income", state: &state, config: content.upgradesConfig, specials: content.specials, viral: content.viral, economy: economy)
        }
        // El tope sale del catálogo y no de un literal: el rebalance de pacing
        // bajó `income` de 20 niveles a 10, y un 20 hardcodeado acá seguía
        // "pasando" por estar POR ENCIMA del tope en vez de EN el tope.
        let income = try #require(content.upgradesConfig.upgrades.first { $0.id == "income" })
        state.meta.oroUpgradeLevels["income"] = income.maxLevel
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
        // magnitude 3 → tier máximo alcanzado − 3 (era 2, ver
        // `theGenerousEventsWereDialedDown`).
        #expect(content.tiers.type(id: granted)?.tier == 6)
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

    // MARK: Cadencia y dosis de los eventos

    /// La queja del dueño fue la FRECUENCIA, no la existencia: "los banners
    /// aparecen muy seguido". 300 + 180 daban un banner cada 5-8 min (~35 en una
    /// partida de 3 h); 900 + 300 lo llevan a uno cada 15-20 min.
    @Test func eventCadenceIsFifteenToTwentyMinutes() {
        #expect(content.events.baseIntervalSeconds == 900)
        #expect(content.events.intervalJitterSeconds == 300)
        // La cuenta que hace `GameState.scheduleNextEvent`: base + jitter.
        let shortest = content.events.baseIntervalSeconds
        let longest = content.events.baseIntervalSeconds + content.events.intervalJitterSeconds
        #expect(shortest >= 15 * 60)
        #expect(longest <= 20 * 60)
    }

    /// Devaluación, corralito y cayó Mercado Pago son la ÚNICA tensión negativa
    /// del juego. Espaciar la cadencia y dosificar a los buenos no puede
    /// convertir la torre en un jardín: el peso de los malos tiene que seguir
    /// siendo al menos el de los buenos.
    @Test func badEventsCarryAtLeastHalfTheWeight() {
        let good = content.events.events.filter(\.isBuff).map(\.weight).reduce(0, +)
        let bad = content.events.events.filter { !$0.isBuff }.map(\.weight).reduce(0, +)
        #expect(bad >= good, "peso buenos \(good) vs malos \(bad)")
        #expect(good > 0, "sin eventos buenos se pierde el humor, que no es lo que se estaba dosificando")
    }

    /// Y no se apagó ninguno: los ocho siguen en el sorteo.
    @Test func everyEventStaysInTheDraw() {
        #expect(content.events.events.count == 8)
        #expect(content.events.events.allSatisfy { $0.weight > 0 })
    }

    /// Los cinco que aceleran, dosificados: menos magnitud y más espera entre
    /// apariciones.
    @Test func theGenerousEventsWereDialedDown() throws {
        let byId = Dictionary(uniqueKeysWithValues: content.events.events.map { ($0.id, $0) })
        let planPlatita = try #require(byId["plan_platita"])
        let alienigena = try #require(byId["inversion_alienigena"])
        let aguinaldo = try #require(byId["aguinaldo"])
        let blanqueo = try #require(byId["blanqueo"])
        let startup = try #require(byId["startup_comprada"])

        #expect(planPlatita.magnitude == 3)   // era ×5 de income
        #expect(alienigena.magnitude == 5)    // era ×10
        #expect(aguinaldo.magnitude == 300)   // eran 900 s (15 min) de producción regalados

        // ⚠️ `blanqueo.magnitude` es un OFFSET DE TIER, no una cantidad de
        // personajes: el evento regala UNO solo, de `maxTierReached − magnitude`
        // (ver `EventManager.apply`, caso `.freeHighTier`). BAJARLA lo haría más
        // generoso; subirla es lo que lo dosifica.
        #expect(blanqueo.magnitude == 3)      // era 2 → el regalo baja un tier

        #expect(planPlatita.cooldownSeconds >= 1800)
        #expect(startup.cooldownSeconds >= 2700)
        #expect(alienigena.cooldownSeconds >= 7200)
        #expect(aguinaldo.cooldownSeconds >= 5400)
        #expect(blanqueo.cooldownSeconds >= 5400)
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
