import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// E14b B13: toda recompensa se ve llegar. La animación es presentación pura:
/// estos tests fijan qué se anima por fuente y que el saldo no se toca.
@Suite("Recompensas animadas: el plan, el tope y el centro")
@MainActor
struct RewardFlightPlanTests {
    @Test("la plata sale con su monto en el formato del HUD, y los .coinsSeconds de la lista no suman otra vez")
    func coinsUseTheHUDFormat() {
        let items = RewardFlightPlan.items(for: [.coinsSeconds(900)], coins: 1_200_000)
        #expect(items == [RewardFlightItem(kind: .coins, destination: .coins, amount: 1_200_000)])
        #expect(items.first?.label == "+" + CoinFormatter.string(from: 1_200_000))
    }

    @Test("el blue vuela al botón del blue y el ×2 duplica su monto")
    func blueDoublesWithTheVideo() {
        let items = RewardFlightPlan.items(for: [.oro(15)], multiplier: 2)
        #expect(items == [RewardFlightItem(kind: .blue, destination: .blue, amount: 30)])
        #expect(items.first?.label == "+30")
    }

    @Test("boosts, paquetes, cofres y giros vuelan con su ícono a su lugar")
    func nonMoneyRewardsFlyToTheirSpot() {
        let items = RewardFlightPlan.items(for: [
            .modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 60),
            .autoTap(perSecond: 5, seconds: 60),
            .clearBoostCooldowns,
            .package(2),
            .skinChest(1),
            .wheelSpin(3),
        ])
        #expect(items.map(\.destination) == [.boosts, .boosts, .boosts, .seals, .seals, .seals])
        #expect(items.map(\.kind) == [.incomeBoost, .tapBoost, .boostRefresh, .package, .chest, .wheelSpin])
        #expect(items.map(\.label) == [nil, nil, nil, "+2", "+1", "+3"])
    }

    @Test("lo que no se puede mostrar no vuela: lugares extra, plata cero y montos que no son números")
    func nothingToShow() {
        #expect(RewardFlightPlan.items(for: [.extraSlots(3), .coinsSeconds(60), .oro(0)]).isEmpty)
        #expect(RewardFlightPlan.items(for: [], coins: 0).isEmpty)
        #expect(RewardFlightPlan.items(for: [], coins: .infinity).isEmpty)
        #expect(RewardFlightPlan.items(for: [], coins: -5).isEmpty)
    }

    @Test("el tope de partículas: la tanda no pasa de su tope y el total vivo tampoco")
    func particleBudget() {
        #expect(RewardFlightBudget.allocate(requested: [9, 5], alreadyLive: 0, liveCap: 24) == [9, 1])
        #expect(RewardFlightBudget.allocate(requested: [9, 5], alreadyLive: 20, liveCap: 24) == [4, 0])
        #expect(RewardFlightBudget.allocate(requested: [9], alreadyLive: 30, liveCap: 24) == [0])
        #expect(RewardFlightBudget.liveCap(forModel: "iPhone14,6") == RewardFlightBudget.compactLiveCap)
        #expect(RewardFlightBudget.liveCap(forModel: "iPhone17,2") == RewardFlightBudget.standardLiveCap)
        #expect(RewardFlightBudget.compactLiveCap < RewardFlightBudget.standardLiveCap)
    }

    @Test("un destino sin medir o vacío cae a un respaldo dentro de la pantalla")
    func geometryFallsBack() {
        let size = CGSize(width: 390, height: 844)
        let geometry = RewardFlightGeometry(
            size: size, layerOrigin: .zero,
            anchors: [.boosts: .zero, .coins: CGRect(x: 100, y: 20, width: 200, height: 40)]
        )
        #expect(geometry.target(for: .coins) == CGPoint(x: 200, y: 40))
        for destination in [RewardFlightDestination.blue, .boosts, .seals] {
            let point = geometry.target(for: destination)
            #expect(CGRect(origin: .zero, size: size).contains(point))
        }
        #expect(geometry.point(for: .popup) == CGPoint(x: 195, y: size.height * 0.42))
    }
}

@Suite("Recompensas animadas: el centro de vuelos")
@MainActor
struct RewardFlightCenterTests {
    private func makeCenter(reduceMotion: Bool = false, liveCap: Int = 24) -> RewardFlightCenter {
        let center = RewardFlightCenter()
        center.reduceMotion = { reduceMotion }
        center.liveCap = liveCap
        return center
    }

    private let coins = RewardFlightItem(kind: .coins, destination: .coins, amount: 900)

    @Test("la plata retiene su monto hasta que aterriza y cada moneda suma su parte")
    func heldCoinsDrainOnLanding() throws {
        let center = makeCenter()
        center.launch([coins])
        let batch = try #require(center.batches.first)
        #expect(batch.particles.count == RewardFlightBudget.coinParticles)
        #expect(center.heldCoins == 900)
        center.land(batch.particles[0].id)
        #expect(center.heldCoins == 800)
        #expect(center.landings == 1)
        for particle in batch.particles.dropFirst() { center.land(particle.id) }
        #expect(abs(center.heldCoins) < 1e-9)
        #expect(center.bumpCount(.coins) >= 1)
    }

    @Test("cerrar la tanda suelta lo que no aterrizó: el contador nunca queda retenido")
    func finishReleasesWhatNeverLanded() throws {
        let center = makeCenter()
        center.launch([coins])
        let id = try #require(center.batches.first?.id)
        center.finish(id)
        #expect(center.heldCoins == 0)
        #expect(center.batches.isEmpty)
    }

    @Test("con Reduce Motion no hay partículas ni retención: sólo el rótulo")
    func reduceMotionOnlyShowsTheLabel() throws {
        let center = makeCenter(reduceMotion: true)
        center.launch([coins])
        let batch = try #require(center.batches.first)
        #expect(batch.particles.isEmpty)
        #expect(center.heldCoins == 0)
        #expect(batch.labels.map(\.text) == [coins.label])
    }

    @Test("el tope vivo recorta la tanda siguiente y no retiene lo que no vuela")
    func liveCapTrimsTheNextBatch() {
        let center = makeCenter(liveCap: RewardFlightBudget.coinParticles)
        center.launch([coins])
        center.launch([coins])
        #expect(center.liveParticles == RewardFlightBudget.coinParticles)
        #expect(center.batches.last?.particles.isEmpty == true)
        #expect(center.heldCoins == 900)
        #expect(center.batches.last?.labels.count == 1, "sin vuelo igual se ve el rótulo")
    }

    @Test("dos tandas seguidas no se pisan: cada rótulo toma su escalón")
    func labelsStackInSlots() {
        let center = makeCenter()
        center.launch([coins])
        center.launch([RewardFlightItem(kind: .blue, destination: .blue, amount: 5)])
        #expect(center.batches.map(\.slot) == [0, 1])
    }

    @Test("el historial recuerda lo lanzado, en orden")
    func historyKeepsTheOrder() {
        let center = makeCenter()
        let blue = RewardFlightItem(kind: .blue, destination: .blue, amount: 5)
        center.launch([coins, blue])
        #expect(center.launched == [coins, blue])
    }
}

@Suite("Recompensas animadas: cada fuente dispara su vuelo")
@MainActor
struct RewardFlightSourcesTests {
    private var noon: TimeInterval {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))
        return date?.timeIntervalSince1970 ?? 0
    }

    private func start() async -> GameState {
        RewardFlightCenter.shared.reset()
        return await makeGameState()
    }

    private func isClose(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= max(1e-6, abs(rhs) * 1e-9)
    }

    @Test("anunciar un premio no toca el saldo: con y sin animación queda igual")
    func announcingNeverChangesTheBalance() async throws {
        let gameState = await start()
        let before = try #require(gameState.player)
        gameState.announceReward([.oro(5), .package(1)], coins: 1_000)
        #expect(gameState.player == before)
        #expect(RewardFlightCenter.shared.launched.map(\.kind) == [.coins, .blue, .package])

        let animated = await start()
        let plain = await makeGameState()
        let reward = RewardSpec.coinsSeconds(600)
        let grantedPlain = plain.grant(reward, source: "test")
        let grantedAnimated = animated.grant(reward, source: "test")
        animated.announceReward(reward, coins: grantedAnimated)
        #expect(isClose(grantedAnimated, grantedPlain))
        #expect(isClose(animated.player?.run.coins ?? 0, plain.player?.run.coins ?? -1))
    }

    @Test("la ruleta anuncia el premio del segmento, con la plata acreditada")
    func wheelAnnouncesTheSegmentReward() async throws {
        let gameState = await start()
        let outcome = try #require(gameState.spinWheel(.video, now: noon))
        let expected = RewardFlightPlan.items(for: [outcome.segment.reward], coins: outcome.coins)
        #expect(RewardFlightCenter.shared.launched == expected)
    }

    @Test("el colchón anuncia su premio")
    func mattressAnnouncesItsPrize() async throws {
        let gameState = await start()
        gameState.debugSpawnMattress(onBoard: true)
        let outcome = try #require(gameState.openMattress())
        let expected = RewardFlightPlan.items(for: outcome.rewards, coins: outcome.coins)
        #expect(!expected.isEmpty)
        #expect(RewardFlightCenter.shared.launched == expected)
    }

    @Test("una oferta pagada anuncia su blue y sus premios")
    func offerAnnouncesItsRewards() async throws {
        let gameState = await start()
        let offer = try #require(gameState.content?.offers.offer(id: "renacer"))
        let coinsBefore = try #require(gameState.player?.run.coins)
        gameState.creditOffer("renacer", transactionID: "t-flight", now: noon)
        let gained = (gameState.player?.run.coins ?? 0) - coinsBefore
        let launched = RewardFlightCenter.shared.launched
        #expect(launched.map(\.kind) == RewardFlightPlan.items(for: offer.rewards, coins: gained).map(\.kind))
        #expect(launched.first { $0.kind == .blue }?.amount == Double(offer.oroAmount))
    }

    @Test("un evento de plata anuncia la plata que acreditó")
    func coinEventAnnouncesItsCoins() async throws {
        let gameState = await start()
        let content = try #require(gameState.content)
        let event = try #require(content.events.events.first { event in
            event.effects.contains { if case .coinsSeconds = $0 { true } else { false } }
        })
        let before = try #require(gameState.player?.run.coins)
        gameState.startEvent(event, now: noon)
        let coinItem = try #require(RewardFlightCenter.shared.launched.first { $0.kind == .coins })
        #expect(coinItem.amount > 0)
        #expect(isClose(coinItem.amount, (gameState.player?.run.coins ?? 0) - before))
    }

    @Test("el diario anuncia su plata al cerrar el popup, no al acreditarla")
    func dailyAnnouncesOnDismiss() async throws {
        let gameState = await start()
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        gameState.player?.meta.daily.cycleDay = 3
        gameState.player?.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: yesterday)
        RewardFlightCenter.shared.reset()
        gameState.claimDailyIfAvailable()
        let claim = try #require(gameState.dailyClaim)
        #expect(RewardFlightCenter.shared.launched.isEmpty)
        gameState.dismissDailyClaim()
        let chest: [RewardSpec] = claim.chestGranted ? [.skinChest(1)] : []
        #expect(RewardFlightCenter.shared.launched == RewardFlightPlan.items(for: chest, coins: claim.coinsGranted))
    }

    @Test("la vuelta offline anuncia su plata al cerrar el popup, con el ×2 si lo hubo")
    func offlineAnnouncesOnDismiss() async throws {
        let gameState = await start()
        gameState.offlineReward = GameState.OfflineReward(amount: 5_000)
        gameState.dismissOfflineReward()
        #expect(RewardFlightCenter.shared.launched == [RewardFlightItem(kind: .coins, destination: .coins, amount: 5_000)])
        #expect(gameState.offlineReward == nil)
    }
}
