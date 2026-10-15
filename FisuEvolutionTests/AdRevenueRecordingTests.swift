import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Cada impresión queda anotada en el save (E15 T2): con su lugar, gane o no gane el premio, y sin
/// acreditar nada.
@Suite("Las impresiones en el save", .serialized)
@MainActor
struct AdRevenueRecordingTests {
    private struct Rig {
        let gameState: GameState
        let ads: AdsCoordinator
        let provider: ScriptedAdsProvider
        let scratch: ScratchDefaults
    }

    /// Un juego listo con el proveedor guionado; `alternation` decide qué forzado sale primero.
    private func rig(alternation: [ForcedAdFormat] = [.interstitial, .rewardedInterstitial]) async -> Rig {
        let gameState = await makeGameState()
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        ads.settleDelay = .zero
        let scratch = ScratchDefaults()
        var policy = NaturalBreakPolicy.default
        policy.alternation = alternation
        ads.attachPacer(ForcedAdsPacer(policy: policy, store: AdsPacingStore(defaults: scratch.defaults), now: clock.read))
        gameState.attachAds(ads)
        clock.advance(by: 1000)
        return Rig(gameState: gameState, ads: ads, provider: provider, scratch: scratch)
    }

    private func ledger(_ rig: Rig) throws -> AdRevenueLedger {
        try #require(rig.gameState.player?.meta.adRevenue)
    }

    @Test("un rewarded completado anota una impresión con su lugar como site")
    func rewardedIsRecordedWithItsPlacement() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        #expect(try ledger(rig) == .empty)

        let earned = await rig.ads.showRewarded(for: .gifts)

        #expect(earned)
        let stats = try ledger(rig).stats(.rewarded)
        #expect(stats.count == 1)
        #expect(stats.totalMicros == rig.provider.paidMicros)
        #expect(stats.recent.last?.site == RewardedPlacement.gifts.rawValue)
    }

    @Test("un intersticial lleva el corte natural que lo mostró")
    func interstitialCarriesTheNaturalBreak() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }

        await rig.gameState.naturalBreak(.sheetClosed)

        #expect(rig.provider.shown == ["interstitial"])
        let stats = try ledger(rig).stats(.interstitial)
        #expect(stats.count == 1)
        #expect(stats.recent.last?.site == NaturalBreak.sheetClosed.rawValue)
    }

    @Test("un video cerrado a la mitad también se anota —se pagó— pero no acredita premio")
    func closedHalfwayIsRecordedButPaysNothing() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        rig.provider.earnsReward = false

        let earned = await rig.ads.showRewarded(for: .offlineX2)

        #expect(!earned, "el contrato de showRewarded no cambió: true sólo con premio")
        let stats = try ledger(rig).stats(.rewarded)
        #expect(stats.count == 1)
        #expect(stats.recent.last?.site == RewardedPlacement.offlineX2.rawValue)
    }

    @Test("la pausa cerrada sin premio se anota con site adBreak y no da la plata")
    func adBreakClosedHalfwayIsRecordedButPaysNothing() async throws {
        let rig = await rig(alternation: [.rewardedInterstitial, .interstitial])
        defer { rig.scratch.clear() }
        rig.provider.earnsReward = false
        let coins = try #require(rig.gameState.player?.run.coins)

        await rig.gameState.naturalBreak(.sheetClosed)
        await rig.gameState.adBreakAccepted()

        #expect(rig.provider.shown == ["rewardedInterstitial"])
        #expect(rig.gameState.player?.run.coins == coins)
        let stats = try ledger(rig).stats(.rewardedInterstitial)
        #expect(stats.count == 1)
        #expect(stats.recent.last?.site == AdImpressionMapping.Site.adBreak)
    }

    @Test("anotar no toca la plata ni el resto de la partida: sólo el ledger")
    func recordingOnlyTouchesTheLedger() async throws {
        let rig = await rig()
        defer { rig.scratch.clear() }
        var before = try #require(rig.gameState.player)

        rig.gameState.recordImpression(AdImpression(
            format: .appOpen, site: "appOpen", valueMicros: 7_000, currency: "USD",
            precision: .estimated, adSource: "Google", at: 0
        ))

        let after = try #require(rig.gameState.player)
        #expect(after.meta.adRevenue.stats(.appOpen).count == 1)
        before.meta.adRevenue = after.meta.adRevenue
        #expect(after == before)
    }
}

/// Un dominio de `UserDefaults` descartable para el reloj de los forzados.
private struct ScratchDefaults {
    let name = "e15-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: name) ?? .standard
    }

    func clear() {
        defaults.removePersistentDomain(forName: name)
    }
}
