import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los cortes naturales en la partida (PLAN-v2 E7): quién los pide, qué los
/// frena y que el intersticial se muestre una vez y quede anotado.
@Suite("Los cortes naturales en la partida", .serialized)
@MainActor
struct NaturalBreakWiringTests {
    private struct Rig {
        let gameState: GameState
        let ads: AdsCoordinator
        let provider: ScriptedAdsProvider
        let clock: TestClock
        let pacer: ForcedAdsPacer
        let scratch: ScratchDefaults
    }

    /// Un juego listo, con un pacer cuya gracia de arranque ya pasó.
    private func rig() async -> Rig {
        let gameState = await makeGameState()
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        ads.settleDelay = .zero
        let scratch = ScratchDefaults()
        let pacer = ForcedAdsPacer(store: AdsPacingStore(defaults: scratch.defaults), now: clock.read)
        ads.attachPacer(pacer)
        gameState.attachAds(ads)
        clock.advance(by: 1000)
        return Rig(gameState: gameState, ads: ads, provider: provider, clock: clock, pacer: pacer, scratch: scratch)
    }

    /// Cierra lo que haya en la cola como lo cerraría el jugador.
    private func drainCelebrations(_ gameState: GameState) {
        var guardrail = 12
        while let kind = gameState.showing, guardrail > 0 {
            guardrail -= 1
            switch kind {
            case .chestOpening: gameState.dismissChestReward()
            case .dailyReward: gameState.dismissDailyClaim()
            case .specialDrop: gameState.dismissSpecialDrop()
            case .skinAward:
                gameState.skinAward = nil
                gameState.celebrationFinished(.skinAward)
            default: gameState.celebrationFinished(kind)
            }
        }
    }

    private func queueDailyClaim(_ gameState: GameState) throws {
        let day = try #require(gameState.content?.dailyRewards.days.first)
        gameState.dailyClaim = DailyRewardManager.Claim(
            day: day, coinsGranted: 1, specialGranted: nil, chestGranted: false
        )
        gameState.syncCelebrations()
    }

    @Test("cerrar el menú es un corte: sale el intersticial y queda anotado")
    func closingTheMenuShowsAnInterstitial() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.menuDidClose()
        #expect(rig.provider.shown == ["interstitial"])
        #expect(rig.pacer.pacing.lastFullScreenAt == rig.clock.read())
    }

    @Test("dos cortes seguidos: el segundo choca con los 2 min")
    func twoBreaksInARow() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.naturalBreak(.sheetClosed)
        rig.clock.advance(by: 30)
        await rig.gameState.naturalBreak(.offlinePopupDismissed)
        #expect(rig.provider.shown == ["interstitial"])
    }

    @Test("sin pacer (tests, UI tests) no sale nada")
    func withoutAPacerNothingShows() async {
        let gameState = await makeGameState()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(provider: provider)
        ads.settleDelay = .zero
        gameState.attachAds(ads)
        await gameState.naturalBreak(.sheetClosed)
        #expect(provider.shown.isEmpty)
    }

    @Test("con el tutorial no sale nada")
    func nothingDuringTheTutorial() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.beginTutorialPhase()
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("si no es un momento calmo (E4a), la política tampoco lo es")
    func calmMomentAndContextAgree() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.uiCoversBoard = true
        #expect(!rig.gameState.isCalmMoment)
        await rig.gameState.naturalBreak(.sheetClosed)
        rig.gameState.uiCoversBoard = false
        rig.gameState.debugPresentCareerChoice()
        #expect(!rig.gameState.isCalmMoment)
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("ni el viaje en ascensor ni una compra en curso admiten un corte")
    func notDuringARideOrAPurchase() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.fullScreenUIActive = { true }
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown.isEmpty)
        rig.gameState.fullScreenUIActive = { false }
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown == ["interstitial"])
    }

    @Test("una cinemática en la cola frena el corte")
    func notDuringACinematic() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.cinematic = .reencarnacion
        rig.gameState.syncCelebrations()
        #expect(rig.gameState.showing == .cinematic)
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("terminar una celebración grande con la cola vacía es un corte")
    func aDrainedQueueIsABreak() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        try queueDailyClaim(rig.gameState)
        #expect(rig.gameState.showing == .dailyReward)
        rig.gameState.dismissDailyClaim()
        await rig.ads.naturalBreakTask?.value
        #expect(rig.provider.shown == ["interstitial"])
    }

    @Test("un aviso chico que se va no es un corte")
    func aToastIsNotABreak() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        rig.gameState.syncCelebrations()
        rig.gameState.celebrationFinished(.towerNotice)
        await rig.ads.naturalBreakTask?.value
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("reencarnar es un corte: un intersticial, cuando la cola queda libre")
    func reincarnationIsABreak() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.giveEarningsForPrestigeTesting()
        rig.gameState.confirmPrestige()
        await rig.ads.naturalBreakTask?.value
        drainCelebrations(rig.gameState)
        await rig.ads.naturalBreakTask?.value
        #expect(rig.provider.shown == ["interstitial"], "uno solo: el de la reencarnación o el del final de su cofre")
    }

    @Test("mientras el anuncio está en pantalla la cola no presenta nada, y después sí")
    func theQueueWaitsForTheAd() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.provider.holdsOpen = true
        rig.gameState.scheduleNaturalBreak(.sheetClosed)
        await rig.provider.waitUntilShowing()
        try queueDailyClaim(rig.gameState)
        #expect(rig.gameState.showing == nil, "una hoja no se presenta debajo del anuncio")
        rig.provider.closeCurrentAd()
        await rig.ads.naturalBreakTask?.value
        #expect(rig.gameState.showing == .dailyReward)
    }

    @Test("volver del background reinicia la gracia de arranque")
    func returningRestartsTheGrace() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.adsDidEnterBackground()
        rig.clock.advance(by: 3600)
        rig.gameState.adsDidReturnFromBackground()
        rig.clock.advance(by: 60)
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown.isEmpty)
    }
}

private struct ScratchDefaults {
    let name = "e7b-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: name) ?? .standard
    }

    func clear() {
        defaults.removePersistentDomain(forName: name)
    }
}
