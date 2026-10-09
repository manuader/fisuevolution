import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El app open al volver (PLAN-v2 §2): ≥ 3 min afuera, desde la 2ª sesión, y
/// antes del popup offline, nunca debajo.
@Suite("El app open al volver", .serialized)
@MainActor
struct AppOpenWiringTests {
    private struct Rig {
        let gameState: GameState
        let ads: AdsCoordinator
        let provider: ScriptedAdsProvider
        let clock: TestClock
        let pacer: ForcedAdsPacer
        let scratch: ScratchDefaults
    }

    /// Un juego que produce (así hay popup offline), con el app open prendido,
    /// en la sesión `session`.
    private func rig(session: Int, appOpenEnabled: Bool = true) async throws -> Rig {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        ads.settleDelay = .zero
        let scratch = ScratchDefaults()
        let store = AdsPacingStore(defaults: scratch.defaults)
        let policy = NaturalBreakPolicy.default.with(appOpenEnabled: appOpenEnabled)
        var pacer = ForcedAdsPacer(policy: policy, store: store, now: clock.read)
        for _ in 1..<max(1, session) {
            pacer = ForcedAdsPacer(policy: policy, store: store, now: clock.read)
        }
        ads.attachPacer(pacer)
        gameState.attachAds(ads)
        return Rig(gameState: gameState, ads: ads, provider: provider, clock: clock, pacer: pacer, scratch: scratch)
    }

    /// Irse y volver como lo hace iOS, con `away` segundos afuera.
    private func leaveAndReturn(_ rig: Rig, away: TimeInterval) {
        let t0 = Date().timeIntervalSince1970
        rig.gameState.handleScenePhase(from: .active, to: .inactive, now: t0)
        rig.gameState.handleScenePhase(from: .inactive, to: .background, now: t0 + 1)
        rig.clock.advance(by: away)
        rig.gameState.handleScenePhase(from: .background, to: .inactive, now: t0 + away)
        rig.gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + away + 1)
    }

    @Test("al irse se pide; al volver tras 10 min sale, y el popup offline espera a que se cierre")
    func appOpenBeforeTheOfflinePopup() async throws {
        let rig = try await rig(session: 2)
        defer { rig.scratch.clear() }
        rig.provider.holdsOpen = true
        leaveAndReturn(rig, away: 600)
        #expect(rig.provider.preloaded.contains("appOpen"))
        await rig.provider.waitUntilShowing()
        #expect(rig.provider.shown == ["appOpen"])
        #expect(rig.gameState.showing == nil, "el popup offline no se presenta debajo del anuncio")
        rig.provider.closeCurrentAd()
        await rig.ads.naturalBreakTask?.value
        #expect(rig.gameState.showing == .offlineEarnings)
        #expect(rig.pacer.pacing.lastAppOpenAt == rig.clock.read())
    }

    @Test("en la primera sesión no se pide ni sale")
    func notOnTheFirstSession() async throws {
        let rig = try await rig(session: 1)
        defer { rig.scratch.clear() }
        leaveAndReturn(rig, away: 600)
        await rig.ads.naturalBreakTask?.value
        #expect(!rig.provider.preloaded.contains("appOpen"))
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("con el interruptor apagado en ads.json no se pide ni sale")
    func notWithTheSwitchOff() async throws {
        let rig = try await rig(session: 3, appOpenEnabled: false)
        defer { rig.scratch.clear() }
        leaveAndReturn(rig, away: 600)
        await rig.ads.naturalBreakTask?.value
        #expect(!rig.provider.preloaded.contains("appOpen"))
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("una vuelta corta (el centro de notificaciones) no da app open")
    func notAfterAShortAbsence() async throws {
        let rig = try await rig(session: 3)
        defer { rig.scratch.clear() }
        leaveAndReturn(rig, away: 60)
        await rig.ads.naturalBreakTask?.value
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("con remove_ads no se pide ni sale")
    func notWithRemovedAds() async throws {
        let rig = try await rig(session: 3)
        defer { rig.scratch.clear() }
        rig.gameState.player?.meta.removedAds = true
        rig.ads.setRemovedAds(true)
        leaveAndReturn(rig, away: 600)
        await rig.ads.naturalBreakTask?.value
        #expect(!rig.provider.preloaded.contains("appOpen"))
        #expect(rig.provider.shown.isEmpty)
    }

    @Test("dos vueltas en 20 min: un solo app open")
    func oneEveryTwentyMinutes() async throws {
        let rig = try await rig(session: 2)
        defer { rig.scratch.clear() }
        leaveAndReturn(rig, away: 600)
        await rig.ads.naturalBreakTask?.value
        leaveAndReturn(rig, away: 300)
        await rig.ads.naturalBreakTask?.value
        #expect(rig.provider.shown == ["appOpen"])
    }

    @Test("si el anuncio no llega a la pantalla, no se anota y el popup offline sale igual")
    func aFailedPresentationCostsNothing() async throws {
        let rig = try await rig(session: 2)
        defer { rig.scratch.clear() }
        rig.provider.hasInventory = false
        leaveAndReturn(rig, away: 600)
        await rig.ads.naturalBreakTask?.value
        #expect(rig.pacer.pacing.lastAppOpenAt == nil)
        #expect(rig.pacer.pacing.lastFullScreenAt == nil)
        #expect(rig.gameState.showing == .offlineEarnings)
    }

    @Test("el intersticial no sale pegado al app open: cerrar el popup offline no lo dispara")
    func noInterstitialRightAfterTheAppOpen() async throws {
        let rig = try await rig(session: 2)
        defer { rig.scratch.clear() }
        leaveAndReturn(rig, away: 600)
        await rig.ads.naturalBreakTask?.value
        #expect(rig.gameState.showing == .offlineEarnings)
        rig.gameState.celebrationFinished(.offlineEarnings)
        await rig.gameState.naturalBreak(.offlinePopupDismissed)
        #expect(rig.provider.shown == ["appOpen"])
    }

    @Test("soltar la cola devuelve la restricción que había, no la borra")
    func releasingTheQueueRestoresThePreviousRestriction() async throws {
        let rig = try await rig(session: 2)
        defer { rig.scratch.clear() }
        rig.gameState.celebrations.restrict(to: [.boardCelebration])
        rig.gameState.holdCelebrationsForAd()
        rig.gameState.holdCelebrationsForAd()
        #expect(rig.gameState.celebrations.allowedKinds == [])
        rig.gameState.releaseCelebrationsAfterAd()
        #expect(rig.gameState.celebrations.allowedKinds == [.boardCelebration])
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
