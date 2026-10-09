import Foundation
import Testing
@testable import FisuEvolution

/// Los dos formatos nuevos de la 2.0 en la costura de anuncios: la pausa
/// publicitaria (intersticial bonificado) y el app open (PLAN-v2, E7).
///
/// Lo que se prueba es la parte que no depende del SDK: cuánto vive cada
/// inventario, qué corta `remove_ads` y que dos anuncios nunca se encimen. El
/// SDK de Google no se puede ejercitar en un test (sus anuncios no se
/// construyen a mano), así que el proveedor de estos tests es uno guionado.
@Suite("Formatos de anuncio de la 2.0")
@MainActor
struct AdFormatsTests {

    // MARK: - Vida del inventario

    @Test("un rewarded, un interstitial o una pausa viven 55 min; un app open, 3 h 30")
    func inventoryLifetimes() {
        #expect(AdInventoryLifetime.standard == 55 * 60)
        #expect(AdInventoryLifetime.appOpen == 3 * 3600 + 30 * 60)
    }

    @Test("el inventario se tira justo al cumplir su vida, no un segundo después",
          arguments: [AdInventoryLifetime.standard, AdInventoryLifetime.appOpen])
    func inventoryExpiresAtItsLifetime(lifetime: TimeInterval) {
        let loadedAt = Date(timeIntervalSince1970: 1_000_000)
        let inventory = AdInventory(ad: "anuncio", loadedAt: loadedAt, lifetime: lifetime)
        #expect(inventory.isFresh(now: loadedAt))
        #expect(inventory.isFresh(now: loadedAt.addingTimeInterval(lifetime - 1)))
        #expect(!inventory.isFresh(now: loadedAt.addingTimeInterval(lifetime)))
    }

    /// Lo que justifica la vida larga: un app open precargado al irse a
    /// background tiene que sobrevivir a una salida de dos horas, cosa que con
    /// la hora de los otros formatos no pasaría.
    @Test("un app open cargado hace dos horas sigue sirviendo; un rewarded no")
    func appOpenOutlivesTheOthers() {
        let loadedAt = Date(timeIntervalSince1970: 1_000_000)
        let twoHoursLater = loadedAt.addingTimeInterval(2 * 3600)
        let appOpen = AdInventory(ad: "app open", loadedAt: loadedAt, lifetime: AdInventoryLifetime.appOpen)
        let rewarded = AdInventory(ad: "rewarded", loadedAt: loadedAt, lifetime: AdInventoryLifetime.standard)
        #expect(appOpen.isFresh(now: twoHoursLater))
        #expect(!rewarded.isFresh(now: twoHoursLater))
    }

    // MARK: - remove_ads

    @Test("remove_ads apaga los tres forzados y deja los videos opt-in")
    func removeAdsCutsTheThreeForcedFormats() {
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(provider: provider)
        #expect(ads.isInterstitialReady)
        #expect(ads.isRewardedInterstitialReady)
        #expect(ads.isAppOpenReady)

        ads.setRemovedAds(true)

        #expect(!ads.isInterstitialReady)
        #expect(!ads.isRewardedInterstitialReady)
        #expect(!ads.isAppOpenReady)
        for placement in RewardedPlacement.allCases {
            #expect(ads.isRewardedReady(for: placement), "\(placement)")
        }
    }

    @Test("con remove_ads no se presenta ni se precarga ningún forzado")
    func removeAdsNeverPresentsAForcedFormat() async {
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(provider: provider)
        ads.setRemovedAds(true)

        await ads.showInterstitial()
        let earned = await ads.showRewardedInterstitial()
        await ads.showAppOpen()
        ads.preloadRewardedInterstitial()
        ads.preloadAppOpen()

        #expect(!earned)
        #expect(provider.shown.isEmpty)
        #expect(provider.preloaded.isEmpty)

        // El video que el jugador pide, en cambio, sigue.
        let rewarded = await ads.showRewarded(for: .wheel)
        #expect(rewarded)
        #expect(provider.shown == ["rewarded:wheel"])
    }

    // MARK: - Pausa publicitaria

    @Test("la pausa publicitaria devuelve lo que diga el proveedor sobre el premio",
          arguments: [true, false])
    func rewardedInterstitialReportsTheReward(earned: Bool) async {
        let provider = ScriptedAdsProvider()
        provider.earnsReward = earned
        let ads = AdsCoordinator(provider: provider)

        let result = await ads.showRewardedInterstitial()

        #expect(result == earned)
        #expect(provider.shown == ["rewardedInterstitial"])
    }

    @Test("las precargas de los formatos nuevos llegan al proveedor")
    func preloadsReachTheProvider() {
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(provider: provider)
        ads.preloadRewardedInterstitial()
        ads.preloadAppOpen()
        #expect(provider.preloaded == ["rewardedInterstitial", "appOpen"])
    }

    // MARK: - Nunca dos anuncios encimados

    @Test("con un anuncio en pantalla, otro de cualquier formato no se presenta")
    func noTwoAdsAtOnce() async {
        let provider = ScriptedAdsProvider()
        provider.holdsOpen = true
        let ads = AdsCoordinator(provider: provider)

        let first = Task { await ads.showAppOpen() }
        await provider.waitUntilShowing()
        #expect(ads.isPresentingFullScreen)
        #expect(!ads.isInterstitialReady)
        #expect(!ads.isRewardedInterstitialReady)

        await ads.showInterstitial()
        let earned = await ads.showRewardedInterstitial()
        let rewarded = await ads.showRewarded(for: .gifts)
        #expect(!earned)
        #expect(!rewarded)
        #expect(provider.shown == ["appOpen"])

        provider.closeCurrentAd()
        _ = await first.value
        #expect(!ads.isPresentingFullScreen)
    }
}

// MARK: - Andamio

/// Un reloj que avanza sólo cuando el test lo pide.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var instant = Date(timeIntervalSince1970: 1_000_000)

    var read: @Sendable () -> Date {
        { [self] in lock.withLock { instant } }
    }

    func advance(by seconds: TimeInterval) {
        lock.withLock { instant = instant.addingTimeInterval(seconds) }
    }
}

/// Un proveedor que anota todo y deja al test decidir cuándo se cierra el
/// anuncio. Siempre tiene inventario.
@MainActor
final class ScriptedAdsProvider: AdsProvider {
    /// Lo que se presentó, en orden: `"interstitial"`, `"rewarded:<placement>"`…
    private(set) var shown: [String] = []
    private(set) var preloaded: [String] = []
    var earnsReward = true
    /// Cuánto tarda en "llegar" un video que no estaba cargado; el presentado
    /// recién aparece después. `nil` = ya estaba.
    var loadDelay: Duration?
    /// `false` = no hay inventario: `showRewarded` devuelve `false` sin
    /// presentar nada.
    var hasInventory = true
    private(set) var lastRewardedAttempt = RewardedAttempt.noInventory
    /// Si es `true`, el anuncio queda en pantalla hasta `closeCurrentAd()`.
    var holdsOpen = false
    private var open: CheckedContinuation<Void, Never>?

    var isInterstitialReady: Bool { true }
    var isRewardedInterstitialReady: Bool { true }
    var isAppOpenReady: Bool { true }
    func isRewardedReady(for placement: RewardedPlacement) -> Bool { true }

    func preloadRewarded(for placement: RewardedPlacement) { preloaded.append("rewarded:\(placement)") }
    func preloadRewardedInterstitial() { preloaded.append("rewardedInterstitial") }
    func preloadAppOpen() { preloaded.append("appOpen") }
    func prepare() {}

    func showRewarded(for placement: RewardedPlacement) async -> Bool {
        lastRewardedAttempt = .noInventory
        if let loadDelay {
            // Como la espera real: cancelada, se rinde sin presentar nada.
            do { try await Task.sleep(for: loadDelay) } catch { return false }
        }
        guard hasInventory else { return false }
        lastRewardedAttempt = .presented
        await present("rewarded:\(placement)")
        return earnsReward
    }

    func showInterstitial() async -> Bool {
        guard hasInventory else { return false }
        await present("interstitial")
        return true
    }

    func showRewardedInterstitial() async -> Bool {
        await present("rewardedInterstitial")
        return earnsReward
    }

    func showAppOpen() async -> Bool {
        guard hasInventory else { return false }
        await present("appOpen")
        return true
    }

    func closeCurrentAd() {
        open?.resume()
        open = nil
    }

    /// Espera a que el anuncio en vuelo haya llegado a la pantalla, con tope
    /// para no colgar la corrida si nunca llega.
    func waitUntilShowing() async {
        var attempts = 0
        while open == nil, attempts < 500 {
            attempts += 1
            await Task.yield()
        }
    }

    private func present(_ name: String) async {
        shown.append(name)
        guard holdsOpen else { return }
        await withCheckedContinuation { open = $0 }
    }
}
