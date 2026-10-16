import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Lo que el bandido aprende en cada teléfono (2.1 E15 F3 T7): los aciertos y fallos por brazo se
/// guardan en `Application Support/bandit.json` sobre los priors de la config, y vuelven a cero si
/// cambia la `version` de `moments`.
@Suite("El bandido aprende: BanditStore")
struct BanditStoreTests {
    private static let seed = """
    {
      "version": "seed-2026-10-16",
      "thresholds": {"priceWallMinutes": 8, "backOfflineMinutes": 120},
      "caps": {"maxPerHour": 3, "minSecondsBetween": 600, "cooldownAfterDeclineSeconds": 1200, "maxPerSession": 6},
      "arms": [
        {"id": "pw_small", "moment": "price_wall", "reward": {"kind": "coinsSeconds", "seconds": 300},
         "alpha": 2, "beta": 3, "segments": ["low", "mid", "high"]},
        {"id": "pw_big", "moment": "price_wall", "reward": {"kind": "coinsSeconds", "seconds": 600},
         "alpha": 1, "beta": 1, "segments": ["mid", "high"]},
        {"id": "control", "moment": "*", "control": true, "alpha": 1, "beta": 1}
      ]
    }
    """

    private func config(version: String = "seed-2026-10-16") throws -> MomentsConfig {
        var config = try JSONDecoder().decode(MomentsConfig.self, from: Data(Self.seed.utf8))
        config.version = version
        return config
    }

    private func temporaryStore() -> BanditStore {
        BanditStore(url: FileManager.default.temporaryDirectory
            .appending(path: "bandit-\(UUID().uuidString)").appending(path: "bandit.json"))
    }

    @Test("sin archivo: los priors de la config")
    func missingFileIsThePriors() throws {
        let config = try config()
        let record = temporaryStore().load(version: config.version)
        #expect(record == BanditRecord(version: config.version))
        #expect(record.bandit(over: config) == config.bandit())
    }

    @Test("ida y vuelta: lo aprendido se suma a los priors de la config")
    func roundTrip() throws {
        let config = try config()
        let store = temporaryStore()
        var record = store.load(version: config.version)
        record.observe(arm: "pw_small", success: true)
        record.observe(arm: "pw_small", success: true)
        record.observe(arm: "pw_small", success: false)
        record.observe(arm: "pw_big", success: false)
        store.save(record)

        let loaded = store.load(version: config.version)
        #expect(loaded == record)
        let bandit = loaded.bandit(over: config)
        #expect(bandit.arm("pw_small")?.alpha == 4)
        #expect(bandit.arm("pw_small")?.beta == 4)
        #expect(bandit.arm("pw_big")?.alpha == 1)
        #expect(bandit.arm("pw_big")?.beta == 2)
        #expect(bandit.arm("control") == config.bandit().arm("control"))
    }

    @Test("versión nueva de moments: vuelven los priors de la config")
    func newVersionResets() throws {
        let store = temporaryStore()
        var record = store.load(version: "seed-2026-10-16")
        record.observe(arm: "pw_small", success: true)
        store.save(record)

        let next = try config(version: "v2")
        let loaded = store.load(version: next.version)
        #expect(loaded == BanditRecord(version: "v2"))
        #expect(loaded.bandit(over: next) == next.bandit())
    }

    @Test("archivo roto: los priors de la config, y el próximo guardado lo pisa")
    func brokenFileIsThePriors() throws {
        let config = try config()
        let store = temporaryStore()
        try FileManager.default.createDirectory(
            at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ esto no es un bandido".utf8).write(to: store.url)

        var record = store.load(version: config.version)
        #expect(record.bandit(over: config) == config.bandit())
        record.observe(arm: "pw_big", success: true)
        store.save(record)
        #expect(store.load(version: config.version) == record)
    }

    @Test("un brazo que la config ya no trae no cuenta; uno nuevo arranca en su prior")
    func armsFollowTheConfig() throws {
        var record = BanditRecord(version: "seed-2026-10-16")
        record.observe(arm: "gone", success: true)
        record.observe(arm: "pw_small", success: false)
        let bandit = record.bandit(over: try config())
        #expect(bandit.arm("gone") == nil)
        #expect(bandit.arms.map(\.id) == ["pw_small", "pw_big", "control"])
        #expect(bandit.arm("pw_small")?.beta == 4)
    }
}

/// El resultado de cada oferta del momento llega al bandido desde el embudo de la tarjeta
/// (`recordMomentOfferStage`) y desde el regreso del video (`endMomentWatch`): una observación por
/// oferta, el control nunca.
@Suite("El bandido aprende: el resultado desde el embudo", .serialized)
@MainActor
struct BanditLearningTests {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func world(arm: String = "pw_small") async -> (GameState, BanditStore) {
        let gameState = await makeGameState()
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
        gameState.tutorialPhaseActive = false
        gameState.ads = AdsCoordinator(provider: ScriptedAdsProvider())
        let service = PersonalizationService(
            source: FakePersonalizationSource(enabled: false),
            store: PersonalizationStore(url: FileManager.default.temporaryDirectory
                .appending(path: "bandit-\(UUID().uuidString)").appending(path: "personalization.json")),
            device: { (nil, nil) },
            installId: { "8c1f0c6e-0000-4000-8000-000000000007" },
            consentAllows: { false },
            underAgeSignal: { false },
            arguments: [PersonalizationGate.forcedSegmentArgument, PlayerSegment.high.rawValue],
            isDebug: false
        )
        gameState.attachPersonalization(service)
        await service.settle()
        let store = BanditStore(url: FileManager.default.temporaryDirectory
            .appending(path: "bandit-\(UUID().uuidString)").appending(path: "bandit.json"))
        let runtime = gameState.momentsRuntime
        runtime.banditStore = store
        runtime.rng = SplitMix64(seed: 2026)
        runtime.forcedMoment = .priceWall
        runtime.forcedArmId = arm
        return (gameState, store)
    }

    private func tally(_ store: BanditStore, _ arm: String) -> BanditRecord.Tally? {
        store.load(version: "seed-2026-10-16").tallies[arm]
    }

    @Test("video completo: un acierto, guardado")
    func completedIsASuccess() async throws {
        let (gameState, store) = await world()
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        gameState.recordMomentOfferStage(.shown, site: offer.site)
        gameState.recordMomentOfferStage(.accepted, site: offer.site)
        gameState.beginMomentWatch(id: offer.id)
        gameState.claimMomentOffer(id: offer.id, now: start)
        gameState.recordMomentOfferStage(.completed, site: offer.site)
        gameState.endMomentWatch(id: offer.id, now: start)
        #expect(tally(store, "pw_small") == BanditRecord.Tally(successes: 1, failures: 0))
    }

    @Test("«No, gracias»: un fallo")
    func dismissedIsAFailure() async throws {
        let (gameState, store) = await world()
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        gameState.recordMomentOfferStage(.shown, site: offer.site)
        gameState.declineMomentOffer(id: offer.id, now: start)
        gameState.recordMomentOfferStage(.dismissed, site: offer.site)
        #expect(tally(store, "pw_small") == BanditRecord.Tally(successes: 0, failures: 1))
    }

    @Test("sin video al tocar: un fallo, y si después lo cierra no cuenta otra vez")
    func unfilledIsOneFailure() async throws {
        let (gameState, store) = await world()
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        gameState.recordMomentOfferStage(.shown, site: offer.site)
        gameState.recordMomentOfferStage(.accepted, site: offer.site)
        gameState.beginMomentWatch(id: offer.id)
        gameState.recordMomentOfferStage(.unfilled, site: offer.site)
        gameState.endMomentWatch(id: offer.id, now: start)
        gameState.declineMomentOffer(id: offer.id, now: start)
        gameState.recordMomentOfferStage(.dismissed, site: offer.site)
        #expect(tally(store, "pw_small") == BanditRecord.Tally(successes: 0, failures: 1))
    }

    @Test("el abandono a mitad de video también es un fallo")
    func abandonIsAFailure() async throws {
        let (gameState, store) = await world()
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        gameState.recordMomentOfferStage(.shown, site: offer.site)
        gameState.recordMomentOfferStage(.accepted, site: offer.site)
        gameState.beginMomentWatch(id: offer.id)
        gameState.endMomentWatch(id: offer.id, now: start)
        #expect(gameState.momentOffer != nil, "la oferta sigue a la vista")
        #expect(tally(store, "pw_small") == BanditRecord.Tally(successes: 0, failures: 1))
    }

    @Test("un `shown` o un `accepted` solos no enseñan nada")
    func openStagesTeachNothing() async throws {
        let (gameState, store) = await world()
        gameState.evaluateMoments(now: start)
        let offer = try #require(gameState.momentOffer)
        gameState.recordMomentOfferStage(.shown, site: offer.site)
        gameState.recordMomentOfferStage(.accepted, site: offer.site)
        #expect(tally(store, "pw_small") == nil)
    }

    @Test("el control no aprende: no muestra nada")
    func controlLearnsNothing() async {
        let (gameState, store) = await world(arm: "control")
        gameState.evaluateMoments(now: start)
        gameState.recordMomentOfferStage(.dismissed, site: MomentOffer.site(armId: "control"))
        #expect(store.load(version: "seed-2026-10-16").tallies.isEmpty)
    }

    @Test("lo aprendido elige: el bandido del planificador sale del registro guardado")
    func plannerUsesTheStore() async throws {
        let (gameState, store) = await world()
        var record = store.load(version: "seed-2026-10-16")
        for _ in 0..<40 { record.observe(arm: "pw_small", success: false) }
        store.save(record)
        gameState.momentsRuntime.banditRecord = nil
        gameState.evaluateMoments(now: start)
        let bandit = try #require(gameState.momentsRuntime.banditRecord).bandit(over: try #require(gameState.momentsConfig))
        #expect(bandit.arm("pw_small")?.beta == 41)
    }
}
