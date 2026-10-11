import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Lo que el jugador lee —chip, fila, carta, aviso— es exactamente lo que el
/// juego aplica. Cada `for … in allCases` lleva un `switch` SIN `default`: un
/// efecto nuevo sin fila acá no compila. E4: `.eventImmunity` suma su fila.
@Suite("Contrato: lo que se muestra es lo que se aplica")
@MainActor
struct EffectContractTests {
    let content: GameContent
    let economy: StandardEconomy

    init() throws {
        content = try GameContentLoader.load(from: .main)
        economy = StandardEconomy(config: content.economy)
    }

    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "contract-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    private var base: CharacterType { content.tiers.baseType }

    private func producing() throws -> (state: PlayerState, tower: TowerState) {
        var state = PlayerState.newGame(
            startTypeId: base.id, startFloorId: content.floorTable[0].id,
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: 0, now: 0
        )
        state.run.units[base.id] = 3
        state.run.passiveUnlocked[base.id] = true
        state.run.coins = 1e12
        let tower = TowerReconciler.reconcile(run: &state.run, floorTable: content.floorTable, tiers: content.tiers).tower
        return (state, tower)
    }

    private func passive(_ state: PlayerState, now: TimeInterval = 0) -> Double {
        IncomeTicker.passivePerSecond(state: state, tiers: content.tiers, floorTable: content.floorTable,
                                      config: content.economy, now: now)
    }

    private func quote(_ state: PlayerState, now: TimeInterval = 0) throws -> HireQuote {
        try #require(TowerActions.hireQuote(typeId: base.id, state: state, config: content.economy,
                                            floorTable: content.floorTable, tiers: content.tiers, now: now))
    }

    /// El aplicado, escrito con el mismo formateador que lo mostrado.
    private func applied(_ ratio: Double, as unit: EffectUnit) -> String {
        switch unit {
        case .multiplier: EffectFormatter.text(EffectAmount(unit: .multiplier, value: ratio, isCapped: false))
        case .percentDiscount: EffectFormatter.text(EffectAmount(unit: .percentDiscount, value: 1 - ratio, isCapped: false))
        case .percentBonus: EffectFormatter.text(EffectAmount(unit: .percentBonus, value: ratio - 1, isCapped: false))
        case .chance: EffectFormatter.text(EffectAmount(unit: .chance, value: ratio, isCapped: false))
        case .minutes: EffectFormatter.text(EffectAmount(unit: .minutes, value: ratio, isCapped: false))
        }
    }

    @Test("cada efecto de modificador aplica el número de su chip")
    func modifierEffects() throws {
        for effect in ActiveModifier.Effect.allCases {
            let magnitude = effect == .spawnCostMultiplier ? 0.7 : 3
            let modifier = ActiveModifier(effect: effect, magnitude: magnitude, expiresAt: 100, sourceKey: "contract")
            let chip = try #require(ActiveBonusBuilder.bonuses(from: [modifier], catalog: [:], now: 0).first).effectText
            var (plain, tower) = try producing()
            var boosted = plain
            boosted.run.activeModifiers = [modifier]
            switch effect {
            case .incomeMultiplier:
                #expect(chip == applied(passive(boosted) / passive(plain), as: .multiplier))
            case .tapMultiplier:
                let tapPlain = economy.applyTap(type: base, state: &plain, tiers: content.tiers, floorTable: content.floorTable, now: 0)
                let tapBoosted = economy.applyTap(type: base, state: &boosted, tiers: content.tiers, floorTable: content.floorTable, now: 0)
                #expect(chip == applied(tapBoosted / tapPlain, as: .multiplier))
            case .spawnCostMultiplier:
                #expect(chip == applied(try quote(boosted).cost / quote(plain).cost, as: .percentDiscount))
            case .spendingFrozen:
                #expect(chip == String(localized: "bonus.chip.spending_frozen"))
                #expect(passive(boosted) == passive(plain), "congelar el gasto no toca los ingresos")
                #expect(throws: TowerError.spendingFrozen) {
                    try TowerActions.hire(quote: try quote(boosted), state: &boosted, tower: &tower,
                                          floorTable: content.floorTable, config: content.economy, countsAsPurchase: true)
                }
            case .passiveMultiplier:
                #expect(chip == applied(passive(boosted) / passive(plain), as: .multiplier))
                let tapPlain = economy.applyTap(type: base, state: &plain, tiers: content.tiers, floorTable: content.floorTable, now: 0)
                let tapBoosted = economy.applyTap(type: base, state: &boosted, tiers: content.tiers, floorTable: content.floorTable, now: 0)
                #expect(tapBoosted == tapPlain, "el pasivo no es el toque")
            case .eventImmunity:
                #expect(chip == String(localized: "bonus.chip.immunity"))
                #expect(passive(boosted) == passive(plain))
                #expect(ModifierMath.isImmuneToEvents(boosted.run.activeModifiers, now: 0))
            case .packageRateMultiplier:
                #expect(chip == String(localized: "bonus.chip.packages \(applied(3, as: .multiplier))"))
                #expect(passive(boosted) == passive(plain))
            case .autoTapPerSecond:
                #expect(chip == String(localized: "bonus.chip.autotap \(ActiveBonusBuilder.autoTapRateText(magnitude))"))
                #expect(passive(boosted) == passive(plain), "tocar solo no es el pasivo")
                let target = try #require(AutoTapper.target(state: plain, tiers: content.tiers))
                var probe = plain
                let oneTap = economy.applyTap(type: target, state: &probe, tiers: content.tiers,
                                              floorTable: content.floorTable, now: 0)
                let paid = AutoTapper.advance(state: &boosted, delta: 1, now: 0, tiers: content.tiers,
                                              floorTable: content.floorTable, economy: economy)
                #expect(abs(paid - oneTap * magnitude) < 1e-9 * max(1, paid), "el chip dice \(magnitude) por segundo y eso cobra")
            case .freeHire:
                #expect(chip == String(localized: "bonus.chip.free_hire"))
                #expect(try quote(boosted).cost == 0)
                #expect(passive(boosted) == passive(plain))
            }
        }
    }

    @Test("cada evento hace lo que su dato declara")
    func eventEffects() async throws {
        for event in content.events.events {
            let gameState = await makeGameState()
            gameState.debugUnlockFloors(throughTier: max(event.minTier, 12))
            gameState.player?.run.passiveUnlocked[base.id] = true
            let before = try #require(gameState.player)
            let now = Date().timeIntervalSince1970
            gameState.startEvent(event, now: now)
            let after = try #require(gameState.player)
            #expect(String(localized: String.LocalizationValue(event.phraseKey)) != event.phraseKey)
            #expect(String(localized: String.LocalizationValue(event.titleKey)) != event.titleKey)
            for effect in event.effects {
                switch effect {
                case let .modifier(kind, magnitude):
                    let modifier = try #require(after.run.activeModifiers.first { $0.sourceKey == event.sourceKey && $0.effect == kind })
                    #expect(modifier.magnitude == magnitude)
                    #expect(modifier.expiresAt == now + event.durationSeconds)
                case .coinsSeconds(let seconds):
                    let expected = GameState.coinReward(seconds: seconds, player: before, content: content, economy: economy)
                    #expect(abs(after.run.coins - before.run.coins - expected) < 1e-6 * max(1, expected))
                case .evolveBestUnit:
                    #expect(after.run.units == before.run.units, "el evento no muta el tablero: lo planea")
                    #expect(gameState.pendingBoardChanges.contains { $0.origin == .eventStartup })
                case .grantUnit(let below):
                    guard case .arrival(let typeId)? = gameState.pendingBoardChanges.first(where: { $0.origin == .eventBlanqueo })?.kind else {
                        Issue.record("\(event.id) no planeó una llegada")
                        continue
                    }
                    #expect(content.tiers.type(id: typeId)?.tier == max(1, before.run.maxTierReached - below))
                case .callVisitor(let script):
                    #expect(content.visitors.script(id: script) != nil)
                }
            }
        }
    }

    @Test("cada video aplica lo que su fila promete, y no cobra si no tiene efecto")
    func rewardedEffects() async throws {
        for effect in RewardedAdsConfig.EffectType.allCases {
            let reward = try #require(content.rewardedAds.rewards.first { $0.effectType == effect })
            let gameState = await makeGameState()
            switch effect {
            case .incomeMultiplier:
                let magnitude = try #require(reward.magnitude)
                gameState.applyRewardedReward(rewardId: reward.id, now: 0)
                let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "rewarded.\(reward.id)" })
                #expect(modifier.magnitude == magnitude)
                #expect(modifier.expiresAt == reward.durationSeconds)
            case .rareUnit:
                if gameState.isRewardApplicable(reward.id) {
                    gameState.applyRewardedReward(rewardId: reward.id)
                    #expect(!gameState.pendingBoardChanges.isEmpty)
                } else {
                    let row = try #require(gameState.rewardRows.first { $0.id == reward.id })
                    #expect(row.unavailableReason != nil, "inaplicable y ofrecido: el jugador miraría un video por nada")
                }
            case .skinChest:
                let before = try #require(gameState.player?.meta.chestsPending)
                gameState.applyRewardedReward(rewardId: reward.id)
                #expect(gameState.player?.meta.chestsPending == before + 1)
            }
        }
    }

    @Test("cada boost aplica el número de su fila (la Milanesa, el de su JSON)")
    func boostEffects() async throws {
        for effect in BoostsConfig.EffectType.allCases {
            guard let boost = content.boosts.boosts.first(where: { $0.effectType == effect }) else { continue }
            let gameState = await makeGameState()
            gameState.debugUnlockFloors(throughTier: content.tiers.maxTier)
            gameState.player?.meta.stats.maxFloorOrdinalEver = content.floorTable.count - 1
            let row = try #require(gameState.boostRows.first { $0.id == boost.id })
            let shown = EffectFormatter.text(EffectDescriptor.amount(forBoost: effect, magnitude: boost.magnitude))
            #expect(row.effectText.contains(shown))
            let offlineBefore = try #require(gameState.player?.meta.derivedEffects.offlineEfficiency)
            // Lo que el asado tiene que pagar, cotizado ANTES de activarlo.
            let expectedPayout = RewardScale.coinPayout(
                minutes: boost.magnitude, state: try #require(gameState.player),
                tiers: content.tiers, floorTable: content.floorTable, config: content.economy
            )
            let payout = gameState.activateBoost(id: boost.id)
            switch effect {
            case .incomeMultiplier, .tapMultiplier, .spawnCostMultiplier:
                let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "boost.\(boost.id)" })
                #expect(modifier.magnitude == boost.magnitude)
            case .offlineEfficiencyPermanent:
                let after = try #require(gameState.player?.meta.derivedEffects.offlineEfficiency)
                #expect(abs(after - offlineBefore - boost.magnitude) < 1e-9)
            case .periodicPayout:
                #expect(abs((payout ?? 0) - expectedPayout) < 1e-6 * max(1, expectedPayout))
            }
        }
    }

    @Test("cada línea permanente: las dos derivaciones y la fila dicen lo mismo")
    func permanentLines() throws {
        let lines = content.upgradesConfig.upgrades
        for effect in UpgradesConfig.EffectType.allCases {
            guard let line = lines.first(where: { $0.effectType == effect }) else { continue }
            var app = try producing().state
            app.meta.oroUpgradeLevels[line.id] = 2
            var kit = app
            UpgradeManager.recomputeDerivedEffects(state: &app, config: content.upgradesConfig, specials: content.specials,
                                                   viral: content.viral, boosts: content.boosts, economy: economy)
            PermanentUpgrades.recomputeDerivedEffects(state: &kit, lines: try PacingTests.permanentLines(from: content.upgradesConfig), economy: economy)
            let shown = EffectDescriptor.amount(for: effect, level: 2, magnitudePerLevel: line.magnitudePerLevel).value
            let (a, k) = (app.meta.derivedEffects, kit.meta.derivedEffects)
            switch effect {
            case .incomeMultiplier:
                #expect(a.incomeMultiplier == k.incomeMultiplier && abs(a.incomeMultiplier - 1 - shown) < 1e-9)
            case .tapMultiplier:
                #expect(a.tapMultiplier == k.tapMultiplier && abs(a.tapMultiplier - 1 - shown) < 1e-9)
            case .critChance:
                #expect(a.critChance == k.critChance && abs(a.critChance - shown) < 1e-9)
            case .goldenTouchChance:
                #expect(a.goldenChance == k.goldenChance && abs(a.goldenChance - shown) < 1e-9)
            case .luckyTouch:
                #expect(a.critChance == k.critChance && abs(a.critChance - shown) < 1e-9)
                #expect(a.goldenChance == k.goldenChance && abs(a.goldenChance - 2 * line.goldenPerLevel) < 1e-9)
            case .offlineEfficiency:
                #expect(a.offlineEfficiency == k.offlineEfficiency
                        && abs(a.offlineEfficiency - content.economy.offlineEfficiencyBase - shown) < 1e-9)
            case .spawnCostDiscount:
                #expect(a.spawnDiscount == k.spawnDiscount && abs(a.spawnDiscount - shown) < 1e-9)
            case .prestigeBonusPerSoulPoint:
                #expect(a.prestigeBonus == k.prestigeBonus && abs(a.prestigeBonus - shown) < 1e-9)
            }
        }
    }

    @Test("la carta de cada carrera promete lo que se cobra, aunque el merge suba la frontera")
    func careerPreviewEqualsCredited() async throws {
        let options = try #require(content.tiers.type(id: "junior")?.choiceOptions)
            .compactMap { content.tiers.type(id: $0) }
        for kind in CareersConfig.RewardKind.allCases {
            let career = try #require(content.careers.careers.first { $0.rewardKind == kind })
            let gameState = await makeGameState()
            gameState.player?.run.units = ["administrativo": 2]
            gameState.reconcileTower()
            let floor = content.floorTable.ordinal(forTier: 10)
            gameState.visibleFloorOrdinal = floor
            gameState.player?.run.raiseFrontier(to: 10)
            gameState.markRevealed(tier: 10)
            let pair = gameState.visiblePlacements.map(\.slot).sorted()
            gameState.careerPrompt = GameState.CareerPrompt(
                options: options, floorOrdinal: floor, sourceCell: pair[0], targetCell: pair[1]
            )
            let preview = try #require(gameState.careerRewards[career.id]).previewText
            let coinsBefore = try #require(gameState.player?.run.coins)
            gameState.chooseCareer(optionId: career.id)
            // El salto de frontera al T11 llega DESPUÉS del premio, en el turno del tablero.
            let change = try #require(gameState.beginNextBoardChange())
            gameState.confirmBoardChange(id: change.id)
            #expect(gameState.player?.run.maxTierReached == 11)
            switch kind {
            case .freeHires:
                let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "career.\(career.id)" })
                #expect(modifier.effect == .freeHire)
                #expect(preview.contains(String(Int((career.durationSeconds ?? 0) / 60))))
            case .skin:
                #expect(gameState.player?.meta.milestoneSkins.contains(career.skinId ?? "") == true)
            case .lawsuit, .healthPlan:
                let credited = try #require(gameState.player?.run.coins) - coinsBefore
                #expect(preview.contains(CoinFormatter.string(from: credited)))
            }
        }
    }

    @Test("con todos los descuentos juntos, FisuJobs cobra lo que muestra")
    func compoundDiscountsChargeWhatTheyShow() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.player?.run.activeModifiers = [
            ActiveModifier(effect: .spawnCostMultiplier, magnitude: 0.5, expiresAt: .greatestFiniteMagnitude, sourceKey: "career.junior_lawyer"),
            ActiveModifier(effect: .spawnCostMultiplier, magnitude: 0.7, expiresAt: .greatestFiniteMagnitude, sourceKey: "boost.mate"),
        ]
        gameState.player?.meta.prestigeLevel = 3
        gameState.player?.meta.derivedEffects.spawnDiscount = 0.2
        let row = try #require(gameState.jobRows.first { $0.id == base.id })
        let before = try #require(gameState.player?.run.coins)
        gameState.hireCharacter(typeId: base.id)
        let charged = before - (try #require(gameState.player?.run.coins))
        #expect(row.costText == CoinFormatter.cost(from: charged))
    }

    @Test("el offline paga la integral de los buffs, no la foto del momento de volver")
    func offlineMatchesTheIntegral() throws {
        var (state, _) = try producing()
        state.meta.lastSeenTimestamp = 0
        state.run.activeModifiers = [
            ActiveModifier(effect: .incomeMultiplier, magnitude: 3, expiresAt: 600, sourceKey: "a"),
            ActiveModifier(effect: .incomeMultiplier, magnitude: 2, expiresAt: 1500, sourceKey: "b"),
            ActiveModifier(effect: .incomeMultiplier, magnitude: 0.5, expiresAt: 9000, sourceKey: "c"),
        ]
        let credited = OfflineCalculator.earnings(state: state, tiers: content.tiers, floorTable: content.floorTable,
                                                  config: content.economy, now: 3600)
        let buffs = state.run.activeModifiers.filter { $0.magnitude >= 1 }
        let baseRate = IncomeTicker.basePassivePerSecond(state: state, tiers: content.tiers,
                                                         floorTable: content.floorTable, config: content.economy)
        let integral = (0..<3600).reduce(0.0) { total, second in
            total + baseRate * ModifierMath.factor(buffs, effect: .incomeMultiplier, now: Double(second))
        } * state.meta.derivedEffects.offlineEfficiency
        #expect(abs(credited - integral) < 1e-6 * integral)
    }

    @Test("pisos en marcha: lo que dice el mapa es lo que cobra la torre")
    func staffedFloorsShowWhatTheyPay() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let plainEconomy = content.economy
        gameState.replaceEconomy(try content.economy.tuned(EconomyKnobs(staffedFloorBonus: 0.05)))
        gameState.player?.run.units = [base.id: content.floorTable[0].capacity]
        gameState.player?.run.passiveUnlocked[base.id] = true
        gameState.reconcileTower()
        let summary = try #require(gameState.staffedSummary)
        #expect(summary.staffed == 1 && summary.total == content.floorTable.count)
        #expect(gameState.staffedSummaryText(summary).contains("1/\(content.floorTable.count)"),
                "sin la clave en el catálogo sale cruda y no dice 1/10")
        let player = try #require(gameState.player)
        let tuned = try #require(gameState.content).economy
        let staffed = IncomeTicker.basePassivePerSecond(state: player, tiers: content.tiers, floorTable: content.floorTable, config: tuned)
        let plain = IncomeTicker.basePassivePerSecond(state: player, tiers: content.tiers, floorTable: content.floorTable, config: plainEconomy)
        #expect(abs(staffed / plain - (1 + summary.bonus)) < 1e-9)
        #expect(abs(summary.bonus - 0.05) < 1e-12)
    }
}
