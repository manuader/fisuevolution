import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Lo que anota la telemetría, para ver el `exposure` y el `ctx` del embudo.
@MainActor
private final class MomentsTelemetrySpy: TelemetryRecording {
    private(set) var events: [TelemetryPayload] = []

    func start() {}
    func didBecomeActive() {}
    func record(_ event: TelemetryPayload) { events.append(event) }
    func flush() {}
    func settle() async {}

    func events(named name: TelemetryEventName) -> [TelemetryPayload] {
        events.filter { $0.name == name }
    }
}

/// Un proveedor sin video cargado.
@MainActor
private final class MomentsNoAds: AdsProvider {
    var lastRewardedAttempt = RewardedAttempt.noInventory
    var lastRewardedInterstitialAttempt = RewardedAttempt.noInventory
    var onImpression: (@MainActor (AdImpression) -> Void)?
    var isInterstitialReady: Bool { false }
    var isRewardedInterstitialReady: Bool { false }
    var isAppOpenReady: Bool { false }
    func isRewardedReady(for placement: RewardedPlacement) -> Bool { false }
    func preloadRewarded(for placement: RewardedPlacement) {}
    func showRewarded(for placement: RewardedPlacement) async -> Bool { false }
    func showInterstitial() async -> Bool { false }
    func preloadRewardedInterstitial() {}
    func showRewardedInterstitial() async -> Bool { false }
    func preloadAppOpen() {}
    func showAppOpen() async -> Bool { false }
    func prepare() {}
}

/// Los momentos en el juego (2.1 E15 F3 T5): la foto del estado, el planificador, la oferta a la vista,
/// el pago por el punto único de premios y la telemetría (`exposure`, `ctx`).
@Suite("Momentos: la oferta en el momento de necesidad", .serialized)
@MainActor
struct MomentsWiringTests {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    // MARK: - La preparación

    /// Una partida con el tablero a la vista, el segmento forzado (`--uitest-segment`, que deja la
    /// sección `moments` en la semilla del bundle), video o no y el azar con semilla.
    private func world(
        segment: PlayerSegment,
        adReady: Bool = true,
        moment: NeedMoment? = .priceWall,
        arm: String? = "pw_small"
    ) async -> (GameState, MomentsTelemetrySpy) {
        let gameState = await makeGameState()
        calm(gameState)
        gameState.tutorialPhaseActive = false
        if adReady {
            gameState.ads = AdsCoordinator(provider: ScriptedAdsProvider())
        } else {
            gameState.ads = AdsCoordinator(provider: MomentsNoAds())
        }
        let spy = MomentsTelemetrySpy()
        gameState.attachTelemetry(spy, defaults: .isolatedForTest())
        let service = PersonalizationService(
            source: FakePersonalizationSource(enabled: false),
            store: PersonalizationStore(url: FileManager.default.temporaryDirectory
                .appending(path: "moments-\(UUID().uuidString)").appending(path: "personalization.json")),
            device: { (nil, nil) },
            installId: { "8c1f0c6e-0000-4000-8000-000000000005" },
            consentAllows: { false },
            underAgeSignal: { false },
            arguments: [PersonalizationGate.forcedSegmentArgument, segment.rawValue],
            isDebug: false
        )
        gameState.attachPersonalization(service)
        await service.settle()
        let runtime = gameState.momentsRuntime
        runtime.rng = SplitMix64(seed: 2026)
        runtime.forcedMoment = moment
        runtime.forcedArmId = arm
        return (gameState, spy)
    }

    private func calm(_ gameState: GameState) {
        var guardrail = 12
        while let kind = gameState.showing, guardrail > 0 {
            guardrail -= 1
            switch kind {
            case .dailyReward: gameState.dismissDailyClaim()
            case .offlineEarnings:
                gameState.dismissOfflineReward()
                gameState.celebrationFinished(.offlineEarnings)
            case .chestOpening: gameState.dismissChestReward()
            default: gameState.celebrationFinished(kind)
            }
        }
    }

    private func coins(_ gameState: GameState) -> Double {
        gameState.player?.run.coins ?? 0
    }

    private func quote(seconds: Double, _ gameState: GameState) throws -> Double {
        let player = try #require(gameState.player)
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        return GameState.coinReward(seconds: seconds, player: player, content: content, economy: economy)
    }

    // MARK: - Cuándo sale

    @Test("base nunca arma una oferta, ni con el momento forzado y video listo")
    func baseNeverOffers() async {
        let (gameState, spy) = await world(segment: .base)
        gameState.evaluateMoments(now: start)
        gameState.evaluateMoments(now: start.addingTimeInterval(3600))
        #expect(gameState.momentOffer == nil)
        #expect(gameState.momentsRuntime.history.sessionTurns == 0)
        #expect(spy.events(named: .exposure).isEmpty)
    }

    @Test("sin video cargado no hay oferta y no se gasta frecuencia")
    func noVideoNoOffer() async {
        let (gameState, spy) = await world(segment: .high, adReady: false)
        gameState.evaluateMoments(now: start)
        #expect(gameState.momentOffer == nil)
        #expect(gameState.momentsRuntime.history.sessionTurns == 0)
        #expect(spy.events(named: .exposure).isEmpty)
    }

    @Test("con un pop-up encima del tablero no hay momento")
    func coveredBoardHasNoMoment() async {
        let (gameState, _) = await world(segment: .high)
        gameState.uiCoversBoard = true
        #expect(gameState.momentSnapshot(now: start).uiCoversBoard)
        gameState.evaluateMoments(now: start)
        #expect(gameState.momentOffer == nil)
        gameState.uiCoversBoard = false
        gameState.evaluateMoments(now: start)
        #expect(gameState.momentOffer != nil)
    }

    @Test("con el tutorial obligatorio corriendo no hay momento")
    func tutorialHasNoMoment() async {
        let (gameState, _) = await world(segment: .high)
        gameState.tutorialPhaseActive = true
        gameState.evaluateMoments(now: start)
        #expect(gameState.momentOffer == nil)
    }

    @Test("la oferta lleva el brazo, el momento y el premio de la config")
    func offerCarriesTheArm() async throws {
        let (gameState, _) = await world(segment: .high)
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        #expect(offer.armId == "pw_small")
        #expect(offer.moment == .priceWall)
        #expect(offer.reward == .grant(.coinsSeconds(300)))
        #expect(offer.site == "moment.pw_small")
        #expect(gameState.momentsRuntime.history.offerOpen)
    }

    @Test("un brazo de otro segmento no sale: pw_big es de mid y high, no de low")
    func armOfAnotherSegmentNeverShows() async {
        let (gameState, _) = await world(segment: .low, arm: "pw_big")
        gameState.evaluateMoments(now: start)
        #expect(gameState.momentOffer == nil)
    }

    @Test("Fusionar todo sin nada para fusionar no es elegible")
    func mergeAllWithoutPairsIsNotOffered() async {
        let (gameState, _) = await world(segment: .high, moment: .floorFull, arm: "ff_merge")
        gameState.player?.run.units = ["homeless": 1]
        gameState.reconcileTower()
        gameState.evaluateMoments(now: start)
        #expect(gameState.momentOffer == nil)
    }

    @Test("la foto cada 5 s del tick, no en cada cuadro")
    func evaluatesEveryFiveSeconds() async {
        let (gameState, _) = await world(segment: .high)
        gameState.advanceMoments(delta: 1)
        #expect(gameState.momentOffer == nil, "todavía no pasaron 5 s")
        gameState.advanceMoments(delta: 4.5)
        #expect(gameState.momentOffer != nil)
    }

    // MARK: - El pago

    @Test("aceptar paga exactamente el premio del brazo, una sola vez (doble toque)")
    func acceptPaysExactlyOnce() async throws {
        let (gameState, _) = await world(segment: .high)
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        let expected = try quote(seconds: 300, gameState)
        let before = coins(gameState)
        #expect(gameState.claimMomentOffer(id: offer.id, now: start.addingTimeInterval(30)))
        #expect(abs(coins(gameState) - before - expected) <= max(1e-6, expected * 1e-9))
        #expect(gameState.momentOffer == nil)
        #expect(!gameState.momentsRuntime.history.offerOpen)

        let afterFirst = coins(gameState)
        #expect(!gameState.claimMomentOffer(id: offer.id, now: start.addingTimeInterval(31)), "el segundo premio no cobra")
        #expect(coins(gameState) == afterFirst)
    }

    @Test("Fusionar todo: los pares se encolan antes de cerrar la oferta, y una sola vez")
    func mergeAllQueuesOnce() async throws {
        let (gameState, _) = await world(segment: .high, moment: .floorFull, arm: "ff_merge")
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        #expect(offer.reward == .mergeAll)
        let units = try #require(gameState.player?.run.units)
        let coinsBefore = coins(gameState)

        #expect(gameState.claimMomentOffer(id: offer.id, now: start))
        let queued = gameState.pendingBoardChanges.count
        #expect(queued >= 2)
        #expect(gameState.pendingBoardChanges.allSatisfy { $0.origin == .rewardedMergeAll })
        #expect(gameState.player?.run.units == units, "se planea, no se aplica en el acto")
        #expect(coins(gameState) == coinsBefore, "Fusionar todo no paga plata")

        #expect(!gameState.claimMomentOffer(id: offer.id, now: start))
        #expect(gameState.pendingBoardChanges.count == queued, "el doble toque no encola otra cadena")
    }

    @Test("el video visto cuenta en las estadísticas")
    func claimCountsTheVideo() async throws {
        let (gameState, _) = await world(segment: .high)
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        let videos = gameState.player?.meta.stats.videosWatchedEver ?? 0
        gameState.claimMomentOffer(id: offer.id, now: start)
        #expect(gameState.player?.meta.stats.videosWatchedEver == videos + 1)
    }

    @Test("un id viejo no cobra la oferta nueva")
    func staleIdDoesNotPay() async throws {
        let (gameState, _) = await world(segment: .high)
        gameState.evaluateMoments(now: start)
        let first = try #require(gameState.momentOffer)
        gameState.declineMomentOffer(id: first.id, now: start)
        gameState.momentsRuntime.forcedMoment = .floorFull
        gameState.momentsRuntime.forcedArmId = "ff_merge"
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        gameState.evaluateMoments(now: start.addingTimeInterval(700))
        #expect(gameState.momentOffer != nil)
        let before = coins(gameState)
        let changes = gameState.pendingBoardChanges.count
        #expect(!gameState.claimMomentOffer(id: first.id, now: start.addingTimeInterval(701)))
        #expect(coins(gameState) == before)
        #expect(gameState.pendingBoardChanges.count == changes)
    }

    // MARK: - El rechazo

    @Test("«No, gracias» no paga y abre la espera de ese momento")
    func declineOpensTheCooldown() async throws {
        let (gameState, _) = await world(segment: .high)
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        let before = coins(gameState)
        gameState.declineMomentOffer(id: offer.id, now: start)
        #expect(gameState.momentOffer == nil)
        #expect(coins(gameState) == before)
        #expect(!gameState.claimMomentOffer(id: offer.id, now: start), "rechazada no se cobra")

        // Pasó la espera entre turnos (600 s) pero no la del rechazo (1200 s).
        gameState.evaluateMoments(now: start.addingTimeInterval(700))
        #expect(gameState.momentOffer == nil)
        gameState.evaluateMoments(now: start.addingTimeInterval(1300))
        #expect(gameState.momentOffer != nil)
    }

    @Test("con el video en curso, «No, gracias» espera: si el video paga, se cobra")
    func declineDuringTheVideoWaits() async throws {
        let (gameState, _) = await world(segment: .high)
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        gameState.beginMomentWatch(id: offer.id)
        gameState.declineMomentOffer(id: offer.id, now: start)
        #expect(gameState.momentOffer != nil, "el video visto se cobra")
        let before = coins(gameState)
        #expect(gameState.claimMomentOffer(id: offer.id, now: start))
        #expect(coins(gameState) > before)
        gameState.endMomentWatch(id: offer.id, now: start)
        #expect(gameState.momentOffer == nil)
    }

    @Test("con el video en curso, «No, gracias» se aplica si el video vuelve sin premio")
    func declineAppliesWhenTheVideoFails() async throws {
        let (gameState, _) = await world(segment: .high)
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        gameState.beginMomentWatch(id: offer.id)
        gameState.declineMomentOffer(id: offer.id, now: start)
        gameState.endMomentWatch(id: offer.id, now: start)
        #expect(gameState.momentOffer == nil)
        #expect(gameState.momentsRuntime.history.lastDecline[NeedMoment.priceWall.rawValue] == start)
    }

    @Test("si el segmento vuelve a base, la oferta a la vista se retira sin cobrar")
    func backToBaseWithdraws() async throws {
        let (gameState, _) = await world(segment: .high)
        gameState.evaluateMoments(now: start)
        #expect(gameState.momentOffer != nil)
        let before = coins(gameState)
        gameState.momentsRuntime.segmentOverride = .base
        gameState.evaluateMoments(now: start.addingTimeInterval(5))
        #expect(gameState.momentOffer == nil)
        #expect(coins(gameState) == before)
    }

    // MARK: - La telemetría

    @Test("exposure una vez por sesión y brazo, con la versión de la config")
    func exposureOncePerSessionAndArm() async throws {
        let (gameState, spy) = await world(segment: .high)
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        gameState.declineMomentOffer(id: offer.id, now: start)
        gameState.evaluateMoments(now: start.addingTimeInterval(1300))
        #expect(gameState.momentOffer != nil, "segunda oferta del mismo brazo")
        let exposures = spy.events(named: .exposure)
        #expect(exposures == [.exposure(exp: "moments", arm: "pw_small", ver: "seed-2026-10-16")])
    }

    @Test("el control anota la exposición y el turno, y no muestra nada")
    func controlShowsNothing() async {
        let (gameState, spy) = await world(segment: .high, arm: "control")
        gameState.evaluateMoments(now: start)
        #expect(gameState.momentOffer == nil)
        #expect(gameState.momentsRuntime.history.sessionTurns == 1)
        #expect(spy.events(named: .exposure) == [.exposure(exp: "moments", arm: "control", ver: "seed-2026-10-16")])
    }

    @Test("el embudo de la tarjeta lleva el ctx del momento, también después de cobrar")
    func funnelCarriesTheContext() async throws {
        let (gameState, spy) = await world(segment: .high)
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        gameState.recordMomentOfferStage(.shown, site: offer.site)
        gameState.recordMomentOfferStage(.accepted, site: offer.site)
        gameState.claimMomentOffer(id: offer.id, now: start)
        gameState.recordMomentOfferStage(.completed, site: offer.site)
        #expect(spy.events(named: .offer) == [
            .offer(site: "moment.pw_small", stage: .shown, ctx: .priceWall),
            .offer(site: "moment.pw_small", stage: .accepted, ctx: .priceWall),
            .offer(site: "moment.pw_small", stage: .completed, ctx: .priceWall),
        ])
        let counts = gameState.player?.meta.offerFunnel.counts(site: "moment.pw_small")
        #expect(counts?.shown == 1)
        #expect(counts?.completed == 1)
    }

    // MARK: - La foto

    @Test("la foto lee el estado real: lugares libres del piso a la vista, ingreso y colchón")
    func snapshotReadsTheGame() async throws {
        let (gameState, _) = await world(segment: .high, moment: nil, arm: nil)
        let snapshot = gameState.momentSnapshot(now: start)
        #expect(!snapshot.uiCoversBoard)
        #expect(!snapshot.tutorialActive)
        #expect(snapshot.incomePerSecond == gameState.towerIncomePerSecond)
        #expect(snapshot.mattressReady == gameState.mattressOnBoard)
        let tower = try #require(gameState.tower)
        let floor = tower.floors[gameState.visibleFloorOrdinal]
        #expect(snapshot.freeSlots == floor.slots.count - floor.occupiedCount)
    }
}
