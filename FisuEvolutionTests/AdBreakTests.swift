import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// La pausa publicitaria (PLAN-v2 §2 y E7): pantalla previa, "No, gracias" que
/// no castiga y el premio que rota sólo cuando se gana.
@Suite("La pausa publicitaria", .serialized)
@MainActor
struct AdBreakTests {
    private struct Rig {
        let gameState: GameState
        let ads: AdsCoordinator
        let provider: ScriptedAdsProvider
        let clock: TestClock
        let pacer: ForcedAdsPacer
        let scratch: ScratchDefaults
    }

    /// Le toca a la pausa primero, con la gracia de arranque ya pasada.
    private func rig() async -> Rig {
        let gameState = await makeGameState()
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        ads.settleDelay = .zero
        let scratch = ScratchDefaults()
        var policy = NaturalBreakPolicy.default
        policy.alternation = [.rewardedInterstitial, .interstitial]
        let pacer = ForcedAdsPacer(policy: policy, store: AdsPacingStore(defaults: scratch.defaults), now: clock.read)
        ads.attachPacer(pacer)
        gameState.attachAds(ads)
        clock.advance(by: 1000)
        return Rig(gameState: gameState, ads: ads, provider: provider, clock: clock, pacer: pacer, scratch: scratch)
    }

    @Test("le toca a la pausa: sale la pantalla previa con el premio de turno, sin anuncio todavía")
    func theIntroComesFirst() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.naturalBreak(.sheetClosed)
        let offer = try #require(rig.gameState.adBreakOffer)
        let prizes = try #require(rig.gameState.content?.rewardedAds.effectiveAdBreak.prizes)
        #expect(offer.prize == prizes[0])
        #expect(offer.countdownSeconds == 5)
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("aceptar muestra el anuncio, entrega el premio, avisa y rota el premio")
    func acceptingPaysAndRotates() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        let before = try #require(rig.gameState.player?.run.coins)
        await rig.gameState.naturalBreak(.sheetClosed)
        await rig.gameState.adBreakAccepted()
        #expect(rig.provider.shown == ["rewardedInterstitial"])
        #expect(rig.gameState.adBreakOffer == nil)
        #expect(try #require(rig.gameState.player?.run.coins) > before, "el primero es plata")
        #expect(rig.pacer.pacing.adBreakPrizeIndex == 1)
        guard case .rewardGranted = rig.gameState.towerNotice?.kind else {
            Issue.record("sin aviso del premio")
            return
        }
    }

    @Test("si el anuncio se cierra sin premio, no paga ni rota")
    func noRewardNoPrize() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.provider.earnsReward = false
        let before = try #require(rig.gameState.player?.run.coins)
        await rig.gameState.naturalBreak(.sheetClosed)
        await rig.gameState.adBreakAccepted()
        #expect(rig.gameState.player?.run.coins == before)
        #expect(rig.pacer.pacing.adBreakPrizeIndex == 0)
        #expect(rig.pacer.pacing.lastFullScreenAt == rig.clock.read(), "se vio igual: cuenta para los 2 min")
    }

    @Test("«No, gracias» no castiga: sin anuncio, cuenta como el corte y el turno pasa al común")
    func decliningIsFree() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.naturalBreak(.sheetClosed)
        rig.gameState.adBreakDeclined()
        #expect(rig.gameState.adBreakOffer == nil)
        #expect(rig.provider.shown.isEmpty)
        #expect(rig.pacer.nextAlternatingFormat == .interstitial)
        rig.clock.advance(by: 30)
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(rig.provider.shown.isEmpty, "rechazarla cerró la ventana de 2 min")
    }

    @Test("con la pantalla previa arriba, ningún otro corte muestra nada")
    func theIntroBlocksOtherBreaks() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.naturalBreak(.sheetClosed)
        rig.clock.advance(by: 200)
        await rig.gameState.naturalBreak(.celebrationsDrained)
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("el premio rota en orden y vuelve al primero")
    func prizesRotate() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        let count = try #require(rig.gameState.content?.rewardedAds.effectiveAdBreak.prizes.count)
        for _ in 0..<count {
            rig.pacer.advanceAdBreakPrize(count: count)
        }
        #expect(rig.pacer.pacing.adBreakPrizeIndex == 0)
    }

    @Test("su anuncio se pide cuando le toca y falta menos de un minuto; antes no")
    func warmUpOnlyWhenDue() async {
        let gameState = await makeGameState()
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        let scratch = ScratchDefaults()
        defer { scratch.clear() }
        var policy = NaturalBreakPolicy.default
        policy.alternation = [.rewardedInterstitial, .interstitial]
        ads.attachPacer(ForcedAdsPacer(policy: policy, store: AdsPacingStore(defaults: scratch.defaults), now: clock.read))
        gameState.attachAds(ads)

        clock.advance(by: 100)
        gameState.warmForcedAds()
        #expect(!provider.preloaded.contains("rewardedInterstitial"), "faltan 80 s para la gracia de arranque")
        clock.advance(by: 30)
        gameState.warmForcedAds()
        #expect(provider.preloaded.contains("rewardedInterstitial"))
    }

    @Test("si el anuncio no llegó a la pantalla, no paga, no rota y no gasta el cupo")
    func noInventoryCostsNothing() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.provider.hasInventory = false
        let before = try #require(rig.gameState.player?.run.coins)
        await rig.gameState.naturalBreak(.sheetClosed)
        await rig.gameState.adBreakAccepted()
        #expect(rig.provider.shown.isEmpty)
        #expect(rig.gameState.player?.run.coins == before)
        #expect(rig.pacer.pacing.adBreakPrizeIndex == 0)
        #expect(rig.pacer.pacing.lastFullScreenAt == nil, "nada se vio: la ventana de 2 min no se cierra")
        #expect(rig.gameState.towerNotice == nil)
    }

    @Test("con la app inactiva la oferta se cae sin costo y sin anuncio")
    func inactiveSceneDropsTheOffer() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.naturalBreak(.sheetClosed)
        rig.gameState.isSceneActive = false
        await rig.gameState.adBreakAccepted()
        #expect(rig.gameState.adBreakOffer == nil)
        #expect(rig.provider.shown.isEmpty)
        #expect(rig.pacer.pacing.lastFullScreenAt == nil)
        #expect(rig.gameState.celebrationHold.isReleased)
    }

    @Test("la cola de celebraciones queda retenida mientras está la oferta y se suelta al irse")
    func celebrationsAreHeldDuringTheOffer() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        #expect(rig.gameState.celebrationHold.isReleased)
        await rig.gameState.naturalBreak(.sheetClosed)
        #expect(!rig.gameState.celebrationHold.isReleased)
        rig.gameState.adBreakDeclined()
        #expect(rig.gameState.celebrationHold.isReleased)
    }

    @Test("aceptar dos veces (la cuenta y el toque) muestra un solo anuncio")
    func acceptingTwiceShowsOnce() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        await rig.gameState.naturalBreak(.sheetClosed)
        await rig.gameState.adBreakAccepted()
        await rig.gameState.adBreakAccepted()
        #expect(rig.provider.shown == ["rewardedInterstitial"])
    }

    @Test("el pedido del anuncio no se repite a 8 Hz: uno cada 30 s")
    func warmUpIsThrottled() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.gameState.warmForcedAds()
        rig.gameState.warmForcedAds()
        #expect(rig.provider.preloaded.filter { $0 == "rewardedInterstitial" }.count == 1)
        rig.clock.advance(by: 29)
        rig.gameState.warmForcedAds()
        #expect(rig.provider.preloaded.filter { $0 == "rewardedInterstitial" }.count == 1)
        rig.clock.advance(by: 1)
        rig.gameState.warmForcedAds()
        #expect(rig.provider.preloaded.filter { $0 == "rewardedInterstitial" }.count == 2)
    }

    @Test("no se pide el anuncio de la pausa si le toca al común, ni a quien compró remove_ads")
    func warmUpRespectsTheTurnAndRemoveAds() async {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.pacer.recordShown(.rewardedInterstitial)
        rig.clock.advance(by: 500)
        rig.gameState.warmForcedAds()
        #expect(rig.provider.preloaded.isEmpty, "el turno es del común")

        let other = await rig2(removedAds: true)
        defer { other.scratch.clear() }
        other.gameState.warmForcedAds()
        #expect(other.provider.preloaded.isEmpty)
    }

    @Test("el premio de turno con la lista vacía o un índice raro no rompe")
    func prizeBounds() {
        let scratch = ScratchDefaults()
        defer { scratch.clear() }
        let pacer = ForcedAdsPacer(store: AdsPacingStore(defaults: scratch.defaults))
        #expect(pacer.adBreakPrize(in: []) == nil)
        pacer.advanceAdBreakPrize(count: 0)
        #expect(pacer.pacing.adBreakPrizeIndex == 0)
        let prizes: [RewardSpec] = [.oro(1), .oro(2)]
        pacer.advanceAdBreakPrize(count: 1)
        #expect(pacer.adBreakPrize(in: prizes) == .oro(1), "un patrón de uno solo siempre vuelve al primero")
        pacer.advanceAdBreakPrize(count: 2)
        #expect(pacer.adBreakPrize(in: prizes) == .oro(2))
    }

    /// El mismo montaje, con el comprador de `remove_ads` si se pide.
    private func rig2(removedAds: Bool) async -> Rig {
        let rig = await rig()
        if removedAds {
            rig.gameState.player?.meta.removedAds = true
            rig.ads.setRemovedAds(true)
        }
        return rig
    }

    @Test("los premios de la pausa están en el JSON y se pueden entregar")
    func prizesAreGrantable() throws {
        let content = try GameContentLoader.load(from: .main)
        #expect(content.rewardedAds.adBreak != nil, "el respaldo de código es sólo la red")
        let prizes = content.rewardedAds.effectiveAdBreak.prizes
        #expect(prizes.count == 3)
        for prize in prizes {
            try prize.validate()
            #expect(GameState.grantableRewardKinds.contains(prize.kind), "\(prize.kind) no se entrega")
        }
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
