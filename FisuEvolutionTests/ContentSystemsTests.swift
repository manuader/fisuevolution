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
        state.run.raiseFrontier(to: maxTier)
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
            boosts: content.boosts,
            economy: economy,
            now: 0
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
            try UpgradeManager.purchase(lineId: "income", state: &state, config: content.upgradesConfig, specials: content.specials, viral: content.viral, boosts: content.boosts, economy: economy, now: 0)
        }
        // El tope sale del catálogo y no de un literal: el rebalance de pacing
        // bajó `income` de 20 niveles a 10, y un 20 hardcodeado acá seguía
        // "pasando" por estar POR ENCIMA del tope en vez de EN el tope.
        let income = try #require(content.upgradesConfig.upgrades.first { $0.id == "income" })
        state.meta.oroUpgradeLevels["income"] = income.maxLevel
        state.meta.oro = 1_000
        #expect(throws: UpgradeManager.PurchaseError.maxLevelReached) {
            try UpgradeManager.purchase(lineId: "income", state: &state, config: content.upgradesConfig, specials: content.specials, viral: content.viral, boosts: content.boosts, economy: economy, now: 0)
        }
    }

    @Test func coinUpgradeBouncesWhileSpendingIsFrozen() throws {
        var coinConfig = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(content.upgradesConfig)
        ) as? [String: Any] ?? [:]
        var lines = coinConfig["upgrades"] as? [[String: Any]] ?? []
        let index = try #require(lines.firstIndex { $0["id"] as? String == "income" })
        lines[index]["currency"] = "coins"
        coinConfig["upgrades"] = lines
        let config = try JSONDecoder().decode(
            UpgradesConfig.self, from: JSONSerialization.data(withJSONObject: coinConfig)
        )
        var state = makeState(coins: 1_000_000)
        state.run.activeModifiers = [
            ActiveModifier(effect: .spendingFrozen, magnitude: 1, expiresAt: 100, sourceKey: "event.corralito"),
        ]
        func buy(at now: TimeInterval) throws {
            try UpgradeManager.purchase(
                lineId: "income", state: &state, config: config, specials: content.specials,
                viral: content.viral, boosts: content.boosts, economy: economy, now: now
            )
        }
        #expect(throws: UpgradeManager.PurchaseError.spendingFrozen) { try buy(at: 50) }
        #expect(state.run.coins == 1_000_000)
        #expect(state.meta.oroUpgradeLevels["income"] == nil)
        try buy(at: 150)
        #expect(state.meta.oroUpgradeLevels["income"] == 1)
    }

    @Test func sharesAddCappedIncomeBonus() {
        var state = makeState()
        state.meta.sharesCompleted = 100 // por encima del cap (20)
        UpgradeManager.recomputeDerivedEffects(state: &state, config: content.upgradesConfig, specials: content.specials, viral: content.viral, boosts: content.boosts, economy: economy)
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
            isApplicable: { _ in true },
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
            economy: economy, now: now, lastFired: allRecent, isApplicable: { _ in true }, rng: &rng
        )
        #expect(roll == nil)
    }

    @Test func aguinaldoPaysPassiveIncomeSeconds() throws {
        var state = makeState(maxTier: 30)
        state.run.coins = 1e6
        try economy.applyPassiveUnlock(typeId: content.tiers.baseType.id, state: &state, tiers: content.tiers, now: 0)
        let coinsBefore = state.run.coins
        var rng = FixedRNG(values: [0])
        // Forzar aguinaldo: solo él sin cooldown.
        let lastFired = Dictionary(uniqueKeysWithValues: content.events.events.filter { $0.id != "aguinaldo" }.map { ($0.id, 1000.0 - 1) })
        let roll = EventManager.fireRandomEvent(
            state: &state, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
            economy: economy, now: 1000, lastFired: lastFired, isApplicable: { _ in true }, rng: &rng
        )
        #expect(roll?.event.id == "aguinaldo")
        #expect(state.run.coins > coinsBefore)
    }

    @Test func blanqueoReturnsUnitTypeWithoutPlacing() throws {
        // freeHighTier post-F7: el evento YA NO coloca en ningún board — devuelve
        // la intención y el caller (GameState) la planea por el embudo.
        var state = makeState(maxTier: 9)
        let unitsBefore = state.run.units
        var rng = FixedRNG(values: [0])
        let lastFired = Dictionary(uniqueKeysWithValues: content.events.events.filter { $0.id != "blanqueo" }.map { ($0.id, 1000.0 - 1) })
        let roll = try #require(EventManager.fireRandomEvent(
            state: &state, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
            economy: economy, now: 1000, lastFired: lastFired, isApplicable: { _ in true }, rng: &rng
        ))
        #expect(roll.event.id == "blanqueo")
        guard case .grantUnit(let granted)? = roll.boardIntent else {
            Issue.record("el Blanqueo no devolvió la llegada")
            return
        }
        // magnitude 3 → tier máximo alcanzado − 3 (era 2, ver
        // `theGenerousEventsWereDialedDown`).
        #expect(content.tiers.type(id: granted)?.tier == 6)
        #expect(state.run.units == unitsBefore)
    }

    @Test func startupCompradaDefersTheEvolutionToTheFunnel() throws {
        // instantEvolution ya no muta nada: devuelve la intención y el caller la planea.
        var state = makeState(maxTier: 5)
        let unitsBefore = state.run.units
        var rng = FixedRNG(values: [0])
        let lastFired = Dictionary(uniqueKeysWithValues: content.events.events.filter { $0.id != "startup_comprada" }.map { ($0.id, 1000.0 - 1) })
        let roll = try #require(EventManager.fireRandomEvent(
            state: &state, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
            economy: economy, now: 1000, lastFired: lastFired, isApplicable: { _ in true }, rng: &rng
        ))
        #expect(roll.event.id == "startup_comprada")
        #expect(roll.boardIntent == .evolveBestUnit)
        #expect(state.run.units == unitsBefore)
        // El máximo histórico de la run no se mueve: el cambio sólo se planeó.
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
            tiers: content.tiers, floorTable: content.floorTable, economy: economy, now: 1000
        )
        #expect(chest == nil)
        #expect(state.run.activeModifiers.contains { $0.sourceKey == "boost.cafe" && $0.effect == .tapMultiplier })

        #expect(throws: BoostManager.ActivationError.self) {
            try BoostManager.activate(
                boostId: "cafe", state: &state, config: content.boosts,
                upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
                tiers: content.tiers, floorTable: content.floorTable, economy: economy, now: 1001
            )
        }
    }

    @Test func milanesaPermanentlyImprovesOffline() throws {
        var state = makeState()
        let before = state.meta.derivedEffects.offlineEfficiency
        _ = try BoostManager.activate(
            boostId: "milanesa", state: &state, config: content.boosts,
            upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
            tiers: content.tiers, floorTable: content.floorTable, economy: economy, now: 1000
        )
        #expect(abs(state.meta.derivedEffects.offlineEfficiency - before - 0.05) < 1e-9)
    }

    @Test("la Milanesa suma lo que dice su JSON, no un número escrito en el código")
    func milanesaReadsItsMagnitude() throws {
        let boosts = try Self.boosts(content.boosts, milanesaMagnitude: 0.2)
        var state = makeState(maxTier: 30)
        let before = state.meta.derivedEffects.offlineEfficiency
        try BoostManager.activate(
            boostId: "milanesa", state: &state, config: boosts,
            upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
            tiers: content.tiers, floorTable: content.floorTable, economy: economy, now: 0
        )
        #expect(abs(state.meta.derivedEffects.offlineEfficiency - before - 0.2) < 1e-9)
    }

    /// El catálogo real con la magnitud de la Milanesa cambiada: un valor que el
    /// literal viejo (0,05) no puede imitar.
    private static func boosts(_ config: BoostsConfig, milanesaMagnitude: Double) throws -> BoostsConfig {
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        var list = try #require(json["boosts"] as? [[String: Any]])
        for index in list.indices where list[index]["id"] as? String == "milanesa" {
            list[index]["magnitude"] = milanesaMagnitude
        }
        json["boosts"] = list
        return try JSONDecoder().decode(BoostsConfig.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("el asado paga sus minutos de producción")
    func asadoPaysItsMinutes() throws {
        var state = makeState(maxTier: 5)
        let expected = RewardScale.coinPayout(minutes: 10, state: state, tiers: content.tiers,
                                              floorTable: content.floorTable, config: content.economy)
        let chest = try BoostManager.activate(
            boostId: "asado", state: &state, config: content.boosts,
            upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
            tiers: content.tiers, floorTable: content.floorTable, economy: economy, now: 1000
        )
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
                boosts: content.boosts, economy: economy, rng: &rng
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
            boosts: content.boosts, economy: economy, rng: &rng
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
            skins: content.skins, upgrades: content.upgradesConfig, viral: content.viral,
            boosts: content.boosts, economy: economy,
            tiers: content.tiers, floorTable: content.floorTable, today: today, rng: &rng
        ))
        #expect(claim.day.day == 1)
        #expect(claim.coinsGranted > 0)
        #expect(state.meta.daily.cycleDay == 2)

        // Mismo día: no hay segundo claim.
        let second = DailyRewardManager.claimIfAvailable(
            state: &state, config: content.dailyRewards, specials: content.specials,
            skins: content.skins, upgrades: content.upgradesConfig, viral: content.viral,
            boosts: content.boosts, economy: economy,
            tiers: content.tiers, floorTable: content.floorTable, today: today, rng: &rng
        )
        #expect(second == nil)
    }

    @Test("el diario paga los minutos de su día")
    func dailyPaysItsMinutes() throws {
        var state = makeState(maxTier: 5)
        var rng = FixedRNG(seed: 1)
        let expected = RewardScale.coinPayout(minutes: 5, state: state, tiers: content.tiers,
                                              floorTable: content.floorTable, config: content.economy)
        let claim = try #require(DailyRewardManager.claimIfAvailable(
            state: &state, config: content.dailyRewards, specials: content.specials, skins: content.skins,
            upgrades: content.upgradesConfig, viral: content.viral, boosts: content.boosts, economy: economy,
            tiers: content.tiers, floorTable: content.floorTable, today: Date(), rng: &rng
        ))
        #expect(abs(claim.coinsGranted - expected) < 1e-6)
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
            skins: content.skins, upgrades: content.upgradesConfig, viral: content.viral,
            boosts: content.boosts, economy: economy,
            tiers: content.tiers, floorTable: content.floorTable, today: today, rng: &rng
        ))
        #expect(claim.day.day == 1)
    }

    /// El día 7 tiene tres escalones y este test los recorre en orden: special,
    /// cofre, plata. El cofre entra en el medio y **no puede pisarle el premio al
    /// special**: mientras queden specials por sacar, el día 7 sigue siendo, ante
    /// todo, su día.
    @Test("el día 7 da cofre sólo cuando ya están los diez specials")
    func daySevenFallsThroughSpecialThenChest() throws {
        var state = makeState(maxTier: 3)
        state.meta.daily.cycleDay = 7
        var rng = FixedRNG(seed: 2)
        let today = Date(timeIntervalSince1970: 1_700_000_000)

        // Primer escalón: con specials pendientes NO hay cofre.
        let conSpecials = try #require(DailyRewardManager.claimIfAvailable(
            state: &state, config: content.dailyRewards, specials: content.specials,
            skins: content.skins, upgrades: content.upgradesConfig, viral: content.viral,
            boosts: content.boosts, economy: economy,
            tiers: content.tiers, floorTable: content.floorTable, today: today, rng: &rng
        ))
        #expect(conSpecials.specialGranted != nil)
        #expect(conSpecials.chestGranted == false)
        #expect(state.meta.chestsPending == 0)

        // Segundo escalón: con los diez specials tomados y pintas por sacar, cofre.
        state.meta.ownedSpecials = content.specials.specials.map(\.id)
        state.meta.daily.cycleDay = 7
        state.meta.daily.lastClaimDay = nil
        let sinSpecials = try #require(DailyRewardManager.claimIfAvailable(
            state: &state, config: content.dailyRewards, specials: content.specials,
            skins: content.skins, upgrades: content.upgradesConfig, viral: content.viral,
            boosts: content.boosts, economy: economy,
            tiers: content.tiers, floorTable: content.floorTable, today: today, rng: &rng
        ))
        #expect(sinSpecials.specialGranted == nil)
        #expect(sinSpecials.chestGranted)
        #expect(state.meta.chestsPending == 1)
        #expect(sinSpecials.coinsGranted == 0, "el cofre reemplaza a la plata, no se suma")

        // Tercer escalón: sin specials y sin pintas por sacar, vuelve la plata.
        state.meta.ownedSkins = content.skins.chestPool.map(\.id)
        state.meta.daily.cycleDay = 7
        state.meta.daily.lastClaimDay = nil
        let conTodo = try #require(DailyRewardManager.claimIfAvailable(
            state: &state, config: content.dailyRewards, specials: content.specials,
            skins: content.skins, upgrades: content.upgradesConfig, viral: content.viral,
            boosts: content.boosts, economy: economy,
            tiers: content.tiers, floorTable: content.floorTable, today: today, rng: &rng
        ))
        #expect(conTodo.chestGranted == false)
        #expect(conTodo.coinsGranted > 0)
        #expect(state.meta.chestsPending == 1, "la colección completa no suma un cofre más")
    }

    /// El agujero que deja preguntar por el sorteo en vez de por el catálogo:
    /// `eligible` filtra **también** por `requiresPrestigeLevel`, así que
    /// quedarse sin sorteo NO es lo mismo que tener los diez. Siete de los diez
    /// specials piden prestigio 0 y los otros piden 3, 5 y 8; colgado de
    /// `eligible`, el día 7 sería una canilla semanal de cofres desde que un
    /// jugador en prestigio 0 junta esos siete.
    @Test("con specials que el prestigio todavía no habilita, el día 7 paga plata y no cofre")
    func daySevenWithoutPrestigeGatedSpecialsPaysCoins() throws {
        var state = makeState(maxTier: 3)
        let alAlcance = content.specials.specials.filter { $0.requiresPrestigeLevel == 0 }
        #expect(alAlcance.count < content.specials.specials.count,
                "el caso pide que queden specials fuera del alcance del prestigio 0")

        // Tomados los que puede sacar; los que piden prestigio, no.
        state.meta.ownedSpecials = alAlcance.map(\.id)
        state.meta.daily.cycleDay = 7
        var rng = FixedRNG(seed: 3)
        let today = Date(timeIntervalSince1970: 1_700_000_000)

        let claim = try #require(DailyRewardManager.claimIfAvailable(
            state: &state, config: content.dailyRewards, specials: content.specials,
            skins: content.skins, upgrades: content.upgradesConfig, viral: content.viral,
            boosts: content.boosts, economy: economy,
            tiers: content.tiers, floorTable: content.floorTable, today: today, rng: &rng
        ))
        #expect(claim.specialGranted == nil, "en prestigio 0 no hay ninguno de los tres para sortear")
        #expect(claim.chestGranted == false, "sin los diez tomados no hay cofre")
        #expect(claim.coinsGranted > 0, "y el premio vuelve a ser el de siempre: plata")
        #expect(state.meta.chestsPending == 0)
    }
}
