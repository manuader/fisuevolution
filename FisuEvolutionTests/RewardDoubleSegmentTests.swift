import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El paso 2 de B29 según el segmento (2.1 E15 F2 T6): con `base` paga exactamente lo de la 2.0 (×2); con
/// una palanca de premio paga `shownCoins × (multiplicador − 1)` en plata y lo que no es plata una vez más,
/// y el pop-up muestra exactamente lo que paga (G4).
@Suite("Recompensas en dos pasos: el ×N según el segmento", .serialized)
@MainActor
struct RewardDoubleSegmentTests {
    /// `high` con premio más grande en tres fuentes; `low` y `mid` en la base (la monotonía se cumple).
    static let boosted = """
    {"version":"test-t6","segments":{"low":{},"mid":{},"high":{"videoRewardMultiplier":\
    {"offline":2.5,"daily":2.5,"mattress":2.25}}}}
    """

    private var now: TimeInterval { Date().timeIntervalSince1970 }

    /// Un servicio de personalización con la compuerta abierta, la config de `segments` dada y el segmento
    /// forzado (como el panel de debug).
    private func personalize(_ gameState: GameState, as segment: PlayerSegment,
                             segments: String = Self.boosted) async {
        let json = PersonalizationFixtures.envelope(
            sections: ["player_value": PersonalizationFixtures.playerValue, "segments": segments])
        let store = PersonalizationStore(url: FileManager.default.temporaryDirectory
            .appending(path: "reward-double-segment-\(UUID().uuidString)")
            .appending(path: "personalization.json"))
        let service = PersonalizationService(
            source: FakePersonalizationSource(enabled: true, json: json),
            store: store,
            device: { ("USA", "iPhone16,2") },
            installId: { "8c1f0c6e-0000-4000-8000-0000000000t6" },
            consentAllows: { true },
            underAgeSignal: { false },
            arguments: [],
            isDebug: false
        )
        gameState.attachPersonalization(service)
        await service.settle()
        service.debugForce(segment)
    }

    /// Cierra lo que haya en la cola como lo cerraría el jugador.
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

    private func world(_ segment: PlayerSegment?) async -> GameState {
        let gameState = await makeGameState()
        calm(gameState)
        if let segment { await personalize(gameState, as: segment) }
        gameState.ads = AdsCoordinator(provider: ScriptedAdsProvider())
        return gameState
    }

    /// El offline de una hora, cobrado (paso 1): deja el paso 2 a la vista.
    private func offlineStepOne(_ gameState: GameState, now: TimeInterval) throws {
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        gameState.player?.meta.lastSeenTimestamp = now - 3600
        gameState.applyOfflineProgressIfNeeded(now: now)
        #expect(gameState.offlineReward != nil)
        gameState.dismissOfflineReward()
    }

    private func dailyStepOne(_ gameState: GameState) throws {
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        gameState.player?.meta.daily.cycleDay = 3
        gameState.player?.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: yesterday)
        gameState.claimDailyIfAvailable()
        #expect(gameState.dailyClaim != nil)
        gameState.dismissDailyClaim()
    }

    private func mattressStepOne(_ gameState: GameState, now: TimeInterval) throws {
        gameState.player?.meta.engagement.treasures = TreasuresState(
            secondsUntilNext: 600, freeBoard: FreeBoardMattress(clockStartedAt: 0, waiting: true))
        let outcome = try #require(gameState.openFreeMattress(now: now))
        #expect(outcome.isGift)
        gameState.offerMattressDouble(outcome)
    }

    private func coins(_ gameState: GameState) -> Double { gameState.player?.run.coins ?? 0 }

    private func near(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= max(1e-6, abs(rhs) * 1e-9)
    }

    // MARK: - El multiplicador

    @Test("con la base, las ocho fuentes son ×2: el número de la 2.0")
    func baseIsTimesTwoEverywhere() {
        for source in SegmentLevers.Source.allCases {
            for site in ["double.\(source.rawValue)", "double.\(source.rawValue).algo"] {
                #expect(GameState.rewardDoubleMultiplier(site: site, levers: .identity) == 2, "\(site)")
            }
        }
    }

    @Test("la palanca de la fuente manda; una fuente sin palanca o un site ajeno es ×2")
    func leverPerSource() {
        let levers = SegmentLevers.Levers(videoRewardMultiplier: ["offline": 2.5, "visit": 2.25])
        #expect(GameState.rewardDoubleMultiplier(site: "double.offline", levers: levers) == 2.5)
        #expect(GameState.rewardDoubleMultiplier(site: "double.visit.ministro_subsidio", levers: levers) == 2.25)
        #expect(GameState.rewardDoubleMultiplier(site: "double.daily", levers: levers) == 2)
        #expect(GameState.rewardDoubleMultiplier(site: "otra.cosa", levers: levers) == 2)
    }

    @Test("los topes del código mandan aunque las palancas lleguen fuera de rango")
    func codeCapsWin() {
        let levers = SegmentLevers.Levers(videoRewardMultiplier: ["offline": 9, "daily": 1, "career": .nan])
        #expect(GameState.rewardDoubleMultiplier(site: "double.offline", levers: levers)
            == SegmentLevers.Caps.videoRewardMultiplierRange(for: .offline).upperBound)
        #expect(GameState.rewardDoubleMultiplier(site: "double.daily", levers: levers) == 2)
        #expect(GameState.rewardDoubleMultiplier(site: "double.career", levers: levers) == 2)
    }

    @Test("con ×2 la plata extra es, bit a bit, la del paso 1")
    func baseExtraIsExact() {
        for amount in [0.0, 1, 7.3, 1_234_567.891, 9.87e15, 1.0e300] {
            let double = RewardDouble(site: "double.offline", placement: .offlineX2, host: .board,
                                      payout: .grant(coins: amount, rewards: [], source: "x"),
                                      shownCoins: amount, shownRewards: [])
            #expect(double.multiplier == 2)
            #expect(double.extraCoins == amount)
            #expect(!double.isBoosted)
        }
    }

    // MARK: - Lo que paga

    @Test("base con la config cargada: el offline paga exactamente lo de la 2.0")
    func baseOfflinePaysTheSame() async throws {
        let now = self.now
        for segment in [nil, PlayerSegment.base] {
            let gameState = await world(segment)
            try offlineStepOne(gameState, now: now)
            let double = try #require(gameState.rewardDouble)
            #expect(double.multiplier == 2)
            let before = coins(gameState)
            #expect(gameState.claimRewardDouble(id: double.id, now: now))
            #expect(coins(gameState) - before == double.shownCoins)
        }
    }

    @Test("base con la config cargada: el diario y el colchón pagan lo de la 2.0")
    func baseDailyAndMattressPayTheSame() async throws {
        let now = self.now
        let daily = await world(.base)
        try dailyStepOne(daily)
        let dailyDouble = try #require(daily.rewardDouble)
        let beforeDaily = coins(daily)
        #expect(daily.claimRewardDouble(id: dailyDouble.id, now: now))
        #expect(coins(daily) - beforeDaily == dailyDouble.shownCoins)

        let mattress = await world(.base)
        try mattressStepOne(mattress, now: now)
        let mattressDouble = try #require(mattress.rewardDouble)
        #expect(mattressDouble.multiplier == 2)
        #expect(mattressDouble.extraCoins == mattressDouble.shownCoins)
    }

    @Test("high con ×2,5 en offline: el paso 2 paga 1,5 × lo del paso 1, y eso muestra")
    func highOfflinePaysOneAndAHalf() async throws {
        let now = self.now
        let gameState = await world(.high)
        let before = coins(gameState)
        try offlineStepOne(gameState, now: now)
        let stepOne = coins(gameState) - before
        let double = try #require(gameState.rewardDouble)
        #expect(double.multiplier == 2.5)
        #expect(near(double.extraCoins, stepOne * 1.5))
        let shown = RewardDoubleOffer.label(coins: double.extraCoins, rewards: double.shownRewards)
        let afterStepOne = coins(gameState)
        #expect(gameState.claimRewardDouble(id: double.id, now: now))
        let paid = coins(gameState) - afterStepOne
        #expect(near(paid, stepOne * 1.5))
        #expect(paid == double.extraCoins, "lo mostrado = lo pagado (G4)")
        #expect(shown == "+" + CoinFormatter.string(from: paid))
    }

    @Test("high con ×2,5 en el diario: 1,5 × la plata del diario, una vez")
    func highDailyPaysOneAndAHalf() async throws {
        let now = self.now
        let gameState = await world(.high)
        try dailyStepOne(gameState)
        let claim = try #require(gameState.rewardDouble)
        #expect(claim.multiplier == 2.5)
        let before = coins(gameState)
        #expect(gameState.claimRewardDouble(id: claim.id, now: now))
        #expect(near(coins(gameState) - before, claim.shownCoins * 1.5))
        #expect(coins(gameState) - before == claim.extraCoins)
    }

    @Test("high con ×2,25 en el colchón: la plata crece y lo que no es plata se da una vez más")
    func highMattressNonMoneyOnceMore() async throws {
        let now = self.now
        let gameState = await world(.high)
        let player0 = try #require(gameState.player)
        try mattressStepOne(gameState, now: now)
        let player1 = try #require(gameState.player)
        let double = try #require(gameState.rewardDouble)
        #expect(double.multiplier == 2.25)
        #expect(gameState.claimRewardDouble(id: double.id, now: now))
        let player2 = try #require(gameState.player)
        #expect(near(player2.run.coins - player1.run.coins, double.shownCoins * 1.25))
        #expect(player2.run.coins - player1.run.coins == double.extraCoins)
        #expect(player2.meta.blue - player1.meta.blue == player1.meta.blue - player0.meta.blue,
                "el blue no se multiplica")
        #expect(player2.meta.engagement.packages.waiting - player1.meta.engagement.packages.waiting
                == player1.meta.engagement.packages.waiting - player0.meta.engagement.packages.waiting,
                "no hay media caja")
    }

    @Test("el segmento se lee al ofrecer: cambiarlo después no cambia lo que ya está a la vista")
    func multiplierIsFrozenAtOffer() async throws {
        let now = self.now
        let gameState = await world(.high)
        try offlineStepOne(gameState, now: now)
        let double = try #require(gameState.rewardDouble)
        gameState.personalization?.debugForce(.base)
        let before = coins(gameState)
        #expect(gameState.claimRewardDouble(id: double.id, now: now))
        #expect(coins(gameState) - before == double.extraCoins)
        #expect(double.multiplier == 2.5)
    }

    // MARK: - Los cerrojos

    @Test("doble toque o premio repetido del mismo video: paga una sola vez, también con ×2,5")
    func doubleTapPaysOnce() async throws {
        let now = self.now
        let gameState = await world(.high)
        try offlineStepOne(gameState, now: now)
        let double = try #require(gameState.rewardDouble)
        gameState.beginRewardDoubleWatch(id: double.id)
        gameState.beginRewardDoubleWatch(id: double.id)
        let before = coins(gameState)
        #expect(gameState.claimRewardDouble(id: double.id, now: now))
        #expect(gameState.rewardDouble == nil, "la oferta se borra al cobrar")
        let settled = coins(gameState)
        #expect(!gameState.claimRewardDouble(id: double.id, now: now))
        gameState.endRewardDoubleWatch(id: double.id)
        #expect(coins(gameState) == settled)
        #expect(settled - before == double.extraCoins)
        #expect(gameState.offlineRewardDoubled)
    }

    @Test("«No, gracias» con el video en curso y premio tardío: paga el ×N una vez")
    func latePrizeAfterPendingDecline() async throws {
        let now = self.now
        let gameState = await world(.high)
        try offlineStepOne(gameState, now: now)
        let double = try #require(gameState.rewardDouble)
        gameState.beginRewardDoubleWatch(id: double.id)
        gameState.declineRewardDouble(id: double.id)
        #expect(gameState.rewardDouble?.declinePending == true)
        let before = coins(gameState)
        #expect(gameState.claimRewardDouble(id: double.id, now: now))
        gameState.endRewardDoubleWatch(id: double.id)
        #expect(coins(gameState) - before == double.extraCoins)
        #expect(gameState.rewardDouble == nil)
    }

    // MARK: - El botón

    @Test("con ×2 el botón y el título usan las claves de siempre")
    func baseButtonUsesTheUsualKey() {
        #expect(RewardDoubleOffer.videoTitle(multiplier: 2) == String(localized: "reward.double.video"))
        #expect(RewardDoubleOffer.titleKey(multiplier: 2) == "reward.double.title")
    }

    @Test("con otro ×N el botón lo dice con su número")
    func boostedButtonSaysTheNumber() {
        let title = RewardDoubleOffer.videoTitle(multiplier: 2.5)
        #expect(title != String(localized: "reward.double.video"))
        #expect(title.contains(RewardDoubleOffer.multiplierText(2.5)))
        #expect(RewardDoubleOffer.titleKey(multiplier: 2.5) == "reward.double.title.boosted")
        #expect(RewardDoubleOffer.multiplierText(2.25) == 2.25.formatted(.number.precision(.fractionLength(0...2))))
    }
}
