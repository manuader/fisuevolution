import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Toda recompensa gratis en dos pasos (E14b B29, D17), fuente por fuente: el paso 1 cobra 1×; el paso 2
/// con el video visto cobra otra vez lo mismo, una sola vez; «No, gracias» no cobra; sin anuncio no hay
/// paso 2; y lo que ya costó un video (o se pagó) no lo tiene.
@Suite("Recompensas en dos pasos: el ×2 con video después de cobrar", .serialized)
@MainActor
struct RewardDoubleTests {
    /// Las fuentes gratis con paso 2.
    enum Source: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case ministro, punteroBolson, sindicalistaAumento, vecinaChisme, retoGanado
        case offline, diario, carrera, ruletaGratis, colchonDeRegalo, logroPlata, logroBlue, aguinaldo

        var testDescription: String { rawValue }

        var site: String {
            switch self {
            case .ministro: "double.visit.ministro_subsidio"
            case .punteroBolson: "double.visit.puntero_bolson"
            case .sindicalistaAumento: "double.visit.sindicalista_aumento"
            case .vecinaChisme: "double.visit.vecina_chisme"
            case .retoGanado: "double.visit.vecina_favor"
            case .offline: "double.offline"
            case .diario: "double.daily"
            case .carrera: "double.career"
            case .ruletaGratis: "double.wheel"
            case .colchonDeRegalo: "double.mattress"
            case .logroPlata, .logroBlue: "double.achievement"
            case .aguinaldo: "double.event.aguinaldo"
            }
        }
    }

    /// Lo que ya costó un video, o se pagó: no tiene paso 2.
    enum PaidSource: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case colchonPagado, otroColchon, giroPorVideo, cartaDelVendedor, multaPerdonada, tratoQueSeLleva

        var testDescription: String { rawValue }
    }

    /// Plata, blue, cajas y segundos de efectos vivos: todo lo que una fuente gratis puede dar dos veces.
    struct Wallet {
        var coins: Double
        var blue: Int
        var boxes: Int
        var modifierSeconds: Double

        static func read(_ gameState: GameState, now: TimeInterval) -> Wallet {
            let player = gameState.player
            return Wallet(
                coins: player?.run.coins ?? 0,
                blue: player?.meta.blue ?? 0,
                boxes: player?.meta.engagement.packages.waiting ?? 0,
                modifierSeconds: (player?.run.activeModifiers ?? [])
                    // La marca de «hay un evento corriendo» no es un premio.
                    .filter { $0.isActive(at: now) && $0.effect != .eventPresence }
                    .reduce(0) { $0 + ($1.expiresAt - now) }
            )
        }

        static func - (lhs: Wallet, rhs: Wallet) -> Wallet {
            Wallet(coins: lhs.coins - rhs.coins, blue: lhs.blue - rhs.blue, boxes: lhs.boxes - rhs.boxes,
                   modifierSeconds: lhs.modifierSeconds - rhs.modifierSeconds)
        }

        var gaveSomething: Bool { coins > 0 || blue > 0 || boxes > 0 || modifierSeconds > 0.01 }

        func matches(_ other: Wallet) -> Bool {
            abs(coins - other.coins) <= max(1e-6, abs(other.coins) * 1e-9) && blue == other.blue
                && boxes == other.boxes && abs(modifierSeconds - other.modifierSeconds) < 0.01
        }
    }

    private var now: TimeInterval { Date().timeIntervalSince1970 }

    // MARK: - La preparación

    /// Cierra lo que haya en la cola como lo cerraría el jugador (antes de que haya anuncios).
    private func calm(_ gameState: GameState) {
        var guardrail = 12
        while let kind = gameState.showing, guardrail > 0 {
            guardrail -= 1
            switch kind {
            case .dailyReward: gameState.dismissDailyClaim()
            case .offlineEarnings:
                gameState.dismissOfflineReward()
                gameState.celebrationFinished(.offlineEarnings)
            case .careerChoice:
                gameState.careerPrompt = nil
                gameState.celebrationFinished(.careerChoice)
            case .chestOpening: gameState.dismissChestReward()
            case .specialDrop: gameState.dismissSpecialDrop()
            case .skinAward:
                gameState.skinAward = nil
                gameState.celebrationFinished(.skinAward)
            default: gameState.celebrationFinished(kind)
            }
        }
    }

    /// Frontera en 6, plata y duplicados: los visitantes tienen con qué tratar.
    private func world() async -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 6)
        gameState.debugGrantCoins()
        gameState.debugGrantPair()
        gameState.debugGrantPair()
        calm(gameState)
        return gameState
    }

    private func arrive(_ gameState: GameState, _ scriptId: String) throws {
        let script = try #require(gameState.content?.visitors.script(id: scriptId))
        gameState.presentVisitor(script)
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
    }

    /// Todo lo que va ANTES del paso 1 (no toca la billetera). `ads` en `nil`: sin anuncio.
    private func prepare(_ source: Source, ads: (any AdsProvider)?) async throws -> GameState {
        let gameState: GameState
        switch source {
        case .ministro, .punteroBolson, .sindicalistaAumento, .vecinaChisme, .retoGanado:
            gameState = await world()
            switch source {
            case .ministro: try arrive(gameState, "ministro_subsidio")
            case .punteroBolson: try arrive(gameState, "puntero_bolson")
            case .sindicalistaAumento: try arrive(gameState, "sindicalista_aumento")
            case .vecinaChisme: try arrive(gameState, "vecina_chisme")
            default:
                try arrive(gameState, "turista_propina")
                let terms = ChallengeTerms(taps: 1, windowSeconds: 10, coins: 100, rewards: [.package(1)],
                                           videoDoubles: false)
                gameState.beginChallenge(scriptId: "vecina_favor", terms: terms, now: 0)
            }
        case .offline:
            gameState = await makeGameState()
            calm(gameState)
            let base = try #require(gameState.content?.tiers.baseType.id)
            gameState.player?.run.passiveUnlocked[base] = true
            gameState.player?.meta.lastSeenTimestamp = now - 3600
        case .diario:
            gameState = await makeGameState()
            calm(gameState)
            let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
            gameState.player?.meta.daily.cycleDay = 3
            gameState.player?.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: yesterday)
        case .carrera:
            gameState = await makeGameState()
            calm(gameState)
            gameState.debugPresentCareerChoice()
        case .ruletaGratis:
            gameState = await makeGameState()
            calm(gameState)
            gameState.player?.meta.engagement.wheel.bonusSpins = 40
        case .colchonDeRegalo:
            gameState = await makeGameState()
            calm(gameState)
            gameState.player?.meta.engagement.treasures = TreasuresState(secondsUntilNext: 600, phase: .onBoard,
                                                                         gifted: true)
        case .logroPlata, .logroBlue:
            gameState = await makeGameState()
            calm(gameState)
            gameState.player?.meta.unlockedAchievements.insert(source == .logroPlata ? "ach_floor_urban" : "ach_hires_1000")
        case .aguinaldo:
            gameState = await makeGameState()
            calm(gameState)
            gameState.tutorialPhaseActive = false
        }
        if let ads { gameState.ads = AdsCoordinator(provider: ads) }
        return gameState
    }

    /// El paso 1: lo que hace el botón único del pop-up de la fuente.
    private func collect(_ source: Source, _ gameState: GameState, now: TimeInterval) throws {
        switch source {
        case .ministro, .punteroBolson, .sindicalistaAumento:
            #expect(gameState.stageVisit?.offer?.options.contains { $0.kind == .acceptWithVideo } == false,
                    "el primer pop-up no ofrece duplicar")
            #expect(gameState.chooseVisitOption("accept", now: now))
        case .vecinaChisme:
            #expect(gameState.chooseVisitOption("listen", now: now))
        case .retoGanado:
            gameState.noteStageTap(now: 1)
            #expect(gameState.stageChallenge == nil, "ganado")
        case .offline:
            gameState.applyOfflineProgressIfNeeded(now: now)
            #expect(gameState.offlineReward != nil)
            gameState.dismissOfflineReward()
        case .diario:
            gameState.claimDailyIfAvailable()
            #expect(gameState.dailyClaim != nil)
            gameState.dismissDailyClaim()
        case .carrera:
            gameState.chooseCareerOfferingDouble(optionId: "junior_lawyer")
            #expect(gameState.careerPrompt == nil)
        case .ruletaGratis:
            // El cofre (5 %) no se duplica: se gira hasta que salga otra cosa.
            for _ in 0..<40 {
                let outcome = try #require(gameState.spinWheel(.bonus, now: now))
                if outcome.segment.reward.kind == .skinChest { continue }
                gameState.offerWheelDouble(outcome, source: .bonus)
                return
            }
            Issue.record("cuarenta cofres seguidos")
        case .colchonDeRegalo:
            let outcome = try #require(gameState.openMattress(now: now))
            #expect(outcome.isGift)
            gameState.offerMattressDouble(outcome)
        case .logroPlata:
            gameState.claimAchievement(id: "ach_floor_urban", now: now)
        case .logroBlue:
            gameState.claimAchievement(id: "ach_hires_1000", now: now)
        case .aguinaldo:
            let event = try #require(gameState.content?.events.event(id: "aguinaldo"))
            gameState.startEvent(event, now: now)
        }
    }

    // MARK: - Los cinco casos

    @Test("el paso 1 cobra 1× y deja el paso 2 con lo mismo a la vista", arguments: Source.allCases)
    func stepOnePaysOnce(source: Source) async throws {
        let now = self.now
        let gameState = try await prepare(source, ads: ScriptedAdsProvider())
        let before = Wallet.read(gameState, now: now)
        try collect(source, gameState, now: now)
        let paid = Wallet.read(gameState, now: now) - before
        #expect(paid.gaveSomething)
        let double = try #require(gameState.rewardDouble, "con video listo sale el paso 2")
        #expect(double.site == source.site)
        #expect(abs(double.shownCoins - paid.coins) <= max(1e-6, paid.coins * 1e-9), "muestra lo mismo que cobró")
    }

    @Test("el paso 2 con el video visto cobra otra vez lo mismo, una sola vez", arguments: Source.allCases)
    func stepTwoPaysTheSameAgain(source: Source) async throws {
        let now = self.now
        let gameState = try await prepare(source, ads: ScriptedAdsProvider())
        let before = Wallet.read(gameState, now: now)
        try collect(source, gameState, now: now)
        let afterStepOne = Wallet.read(gameState, now: now)
        let double = try #require(gameState.rewardDouble)
        let videos = gameState.player?.meta.stats.videosWatchedEver ?? 0
        #expect(gameState.claimRewardDouble(id: double.id, now: now))
        let again = Wallet.read(gameState, now: now) - afterStepOne
        #expect(again.matches(afterStepOne - before), "\(again) contra \(afterStepOne - before)")
        #expect(gameState.rewardDouble == nil)
        #expect((gameState.player?.meta.stats.videosWatchedEver ?? 0) == videos + 1, "el video cuenta")
        let settled = Wallet.read(gameState, now: now)
        #expect(!gameState.claimRewardDouble(id: double.id, now: now), "un segundo premio no cobra")
        #expect((Wallet.read(gameState, now: now) - settled).gaveSomething == false)
    }

    @Test("«No, gracias» no cobra y suelta lo que esperaba", arguments: Source.allCases)
    func declineDoesNotPay(source: Source) async throws {
        let now = self.now
        let gameState = try await prepare(source, ads: ScriptedAdsProvider())
        try collect(source, gameState, now: now)
        let afterStepOne = Wallet.read(gameState, now: now)
        let double = try #require(gameState.rewardDouble)
        gameState.declineRewardDouble(id: double.id)
        #expect(gameState.rewardDouble == nil)
        #expect((Wallet.read(gameState, now: now) - afterStepOne).gaveSomething == false)
        #expect(!gameState.claimRewardDouble(id: double.id, now: now), "un video tardío no cobra lo rechazado")
        #expect((Wallet.read(gameState, now: now) - afterStepOne).gaveSomething == false)
    }

    @Test("sin anuncio cargado (o sin consentimiento, o sin conexión) no hay paso 2", arguments: Source.allCases)
    func noAdNoStepTwo(source: Source) async throws {
        let now = self.now
        for ads in [nil, NotReadyAds()] as [(any AdsProvider)?] {
            let gameState = try await prepare(source, ads: ads)
            let before = Wallet.read(gameState, now: now)
            try collect(source, gameState, now: now)
            #expect((Wallet.read(gameState, now: now) - before).gaveSomething, "el paso 1 cobra igual")
            #expect(gameState.rewardDouble == nil)
        }
    }

    @Test("lo que ya costó un video, o se pagó, no tiene paso 2", arguments: PaidSource.allCases)
    func paidSourcesHaveNoStepTwo(source: PaidSource) async throws {
        let now = self.now
        let gameState = await world()
        gameState.ads = AdsCoordinator(provider: ScriptedAdsProvider())
        switch source {
        case .colchonPagado:
            gameState.player?.meta.engagement.treasures = TreasuresState(secondsUntilNext: 600, phase: .onBoard)
            let outcome = try #require(gameState.openMattress(now: now))
            #expect(!outcome.isGift)
            #expect(!gameState.offerMattressDouble(outcome))
        case .otroColchon:
            gameState.player?.meta.engagement.treasures = TreasuresState(secondsUntilNext: 600, phase: .none,
                                                                         extraOpensLeft: 1, gifted: true)
            let outcome = try #require(gameState.openExtraMattress(now: now))
            #expect(!gameState.offerMattressDouble(outcome))
        case .giroPorVideo:
            let outcome = try #require(gameState.spinWheel(.video, now: now))
            #expect(!gameState.offerWheelDouble(outcome, source: .video))
        case .cartaDelVendedor:
            try arrive(gameState, "vendedor_ofertas")
            let card = try #require(gameState.stageVisit?.offer?.options.first)
            #expect(gameState.chooseVisitOption(card.id, now: now))
        case .multaPerdonada:
            try arrive(gameState, "comisario_multa")
            #expect(gameState.chooseVisitOption("video", now: now))
        case .tratoQueSeLleva:
            try arrive(gameState, "influencer_novio")
            #expect(gameState.stageVisit?.offer?.option(id: "accept")?.departures.isEmpty == false, "se lleva a uno")
            #expect(gameState.chooseVisitOption("accept", now: now))
        }
        #expect(gameState.rewardDouble == nil)
    }

    // MARK: - Las reglas del paso 2

    @Test("un efecto con duración no pega dos veces: el ×2 lo hace durar el doble")
    func durableEffectsLastTwiceAsLong() async throws {
        let now = self.now
        let gameState = try await prepare(.sindicalistaAumento, ads: ScriptedAdsProvider())
        try collect(.sindicalistaAumento, gameState, now: now)
        let source = "visit.sindicalista_aumento"
        let first = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == source })
        let double = try #require(gameState.rewardDouble)
        #expect(gameState.claimRewardDouble(id: double.id, now: now))
        let live = gameState.player?.run.activeModifiers.filter { $0.sourceKey == source } ?? []
        #expect(live.count == 1)
        #expect(live.first?.magnitude == first.magnitude)
        #expect(abs((live.first?.expiresAt ?? 0) - now - 2 * (first.expiresAt - now)) < 0.01)
    }

    @Test("lo que no se duplica no ofrece paso 2: una skin, un giro, vaciar los cooldowns")
    func onlyDoublableRewardsOffer() async throws {
        let gameState = await world()
        gameState.ads = AdsCoordinator(provider: ScriptedAdsProvider())
        for rewards in [[RewardSpec.skinChest(1)], [.wheelSpin(1)], [.clearBoostCooldowns]] {
            #expect(!gameState.offerGrantDouble(site: "double.test", placement: .visitor, coins: 0, rewards: rewards,
                                                source: "test"))
        }
        #expect(gameState.rewardDouble == nil)
    }

    @Test("con un pop-up de la cola en pantalla el paso 2 del tablero no sale; en la Ruleta y el Menú, sí")
    func noStepTwoOverAnotherPopup() async throws {
        let gameState = await world()
        gameState.ads = AdsCoordinator(provider: ScriptedAdsProvider())
        gameState.debugPresentCareerChoice()
        #expect(gameState.showing == .careerChoice)
        #expect(!gameState.offerGrantDouble(site: "double.test", placement: .visitor, coins: 10, rewards: [],
                                            source: "test"))
        #expect(gameState.offerGrantDouble(site: "double.test", placement: .gifts, host: .menu, coins: 10,
                                           rewards: [], source: "test"))
    }

    @Test("uno a la vez: con un paso 2 en pantalla no se ofrece otro")
    func oneAtATime() async throws {
        let gameState = await world()
        gameState.ads = AdsCoordinator(provider: ScriptedAdsProvider())
        #expect(gameState.offerGrantDouble(site: "double.a", placement: .visitor, coins: 10, rewards: [], source: "a"))
        #expect(!gameState.offerGrantDouble(site: "double.b", placement: .visitor, coins: 20, rewards: [], source: "b"))
        #expect(gameState.rewardDouble?.site == "double.a")
    }

    @Test("lo que espera al paso 2 corre al resolverse, se vea o no el video")
    func followUpsRunOnResolution() async throws {
        let gameState = await world()
        gameState.ads = AdsCoordinator(provider: ScriptedAdsProvider())
        var ran = 0
        gameState.whenRewardDoubleResolved { ran += 1 }
        #expect(ran == 1, "sin paso 2, corre ya")
        #expect(gameState.offerGrantDouble(site: "double.a", placement: .visitor, coins: 10, rewards: [], source: "a"))
        gameState.whenRewardDoubleResolved { ran += 1 }
        #expect(ran == 1, "espera")
        gameState.declineRewardDouble(id: try #require(gameState.rewardDouble?.id))
        #expect(ran == 2)
    }

    @Test("el offline cobrado y su ×2 esperan para soltar la cola: el corte no cae encima del paso 2")
    func offlineHoldsTheQueue() async throws {
        let now = self.now
        let gameState = try await prepare(.offline, ads: ScriptedAdsProvider())
        try collect(.offline, gameState, now: now)
        #expect(gameState.offlineReward == nil, "el primer pop-up se fue")
        let double = try #require(gameState.rewardDouble)
        #expect(double.placement == .offlineX2)
        #expect(!gameState.offerOfflineDouble(GameState.OfflineReward(amount: 1)), "una vez por vuelta")
    }
}

/// Un proveedor sin inventario: lo que pasa sin anuncio cargado, sin consentimiento o sin conexión.
@MainActor
private final class NotReadyAds: AdsProvider {
    var lastRewardedAttempt = RewardedAttempt.noInventory
    var lastRewardedInterstitialAttempt = RewardedAttempt.noInventory
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
