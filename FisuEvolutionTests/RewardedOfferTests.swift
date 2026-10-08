import Foundation
import Testing
@testable import FisuEvolution

/// El botón de video responde al primer toque (PLAN-v2 E13 ítem 1): espera la
/// carga, presenta apenas llega, y tres toques seguidos son UN video.
@Suite("El botón de video: un toque, un video")
@MainActor
struct RewardedOfferTests {
    private func make(
        configure: (ScriptedAdsProvider) -> Void = { _ in }
    ) -> (RewardedOffer, AdsCoordinator, ScriptedAdsProvider) {
        let provider = ScriptedAdsProvider()
        configure(provider)
        let ads = AdsCoordinator(provider: provider)
        return (RewardedOffer(messageDuration: .milliseconds(80)), ads, provider)
    }

    @Test("carga lenta: el primer toque ya está cargando, presenta al llegar y paga una vez")
    func slowLoadPresentsOnArrival() async {
        let (offer, ads, provider) = make { $0.loadDelay = .milliseconds(120) }
        var paid = 0

        offer.tap(ads: ads, placement: .gifts) { paid += 1 }
        #expect(offer.phase == .busy, "desde el primer toque dice 'Cargando'")
        #expect(provider.shown.isEmpty, "todavía no llegó")

        await offer.settle()
        #expect(provider.shown == ["rewarded:gifts"])
        #expect(paid == 1)
        #expect(offer.phase == .idle)
    }

    @Test("tres toques con la carga en curso son UN solo video")
    func threeTapsOneShow() async {
        let (offer, ads, provider) = make { $0.loadDelay = .milliseconds(120) }
        var paid = 0

        let started = [
            offer.tap(ads: ads, placement: .gifts) { paid += 1 },
            offer.tap(ads: ads, placement: .gifts) { paid += 1 },
            offer.tap(ads: ads, placement: .gifts) { paid += 1 },
        ]
        await offer.settle()

        #expect(started == [true, false, false])
        #expect(provider.shown.count == 1)
        #expect(paid == 1)
    }

    @Test("también durante la presentación: los toques con el video en pantalla se ignoran")
    func tapsWhilePresentingAreIgnored() async {
        let (offer, ads, provider) = make { $0.holdsOpen = true }
        var paid = 0

        offer.tap(ads: ads, placement: .boost) { paid += 1 }
        await provider.waitUntilShowing()
        #expect(offer.tap(ads: ads, placement: .boost) { paid += 1 } == false)

        provider.closeCurrentAd()
        await offer.settle()
        #expect(provider.shown.count == 1)
        #expect(paid == 1)
    }

    @Test("sin inventario: avisa, no paga, y no gasta la gracia del próximo anuncio")
    func noInventorySaysSoAndSpendsNothing() async {
        let (offer, ads, provider) = make { $0.hasInventory = false }
        var paid = 0

        offer.tap(ads: ads, placement: .gifts) { paid += 1 }
        await offer.settle()

        #expect(provider.shown.isEmpty)
        #expect(paid == 0, "sin video no hay premio ni enfriamiento")
        #expect(offer.phase == .unavailable, "la UI dice 'No hay videos ahora'")
        #expect(ads.lastRewardedAt == nil, "no comió ninguna pantalla de publicidad")
    }

    @Test("el aviso se va solo y el botón vuelve a ofrecerse")
    func messageFadesAndTheButtonComesBack() async throws {
        let (offer, ads, provider) = make { $0.hasInventory = false }
        offer.tap(ads: ads, placement: .gifts) {}
        await offer.settle()
        #expect(offer.phase == .unavailable)

        try await Task.sleep(for: .milliseconds(250))
        #expect(offer.phase == .idle)

        provider.hasInventory = true
        var paid = 0
        offer.tap(ads: ads, placement: .gifts) { paid += 1 }
        await offer.settle()
        #expect(paid == 1, "un segundo intento con inventario paga")
    }

    @Test("cerrar el video a la mitad no paga y tampoco dice que no hay videos")
    func dismissedEarlyIsSilent() async {
        let (offer, ads, provider) = make { $0.earnsReward = false }
        var paid = 0

        offer.tap(ads: ads, placement: .gifts) { paid += 1 }
        await offer.settle()

        #expect(provider.shown.count == 1)
        #expect(paid == 0)
        #expect(offer.phase == .idle)
        #expect(ads.lastRewardedAt != nil, "ese sí comió la pantalla completa")
    }
}

@Suite("La espera de la carga")
@MainActor
struct AdLoadWaitTests {
    @Test("devuelve true apenas el video está")
    func resolvesWhenReady() async {
        var polls = 0
        let ready = await AdLoadWait.until(
            timeout: .seconds(2), interval: .milliseconds(5),
            isReady: { polls += 1; return polls >= 4 }, isLoading: { true }
        )
        #expect(ready)
    }

    @Test("si la carga se cayó sin dejar nada, no espera el plazo entero")
    func givesUpWhenLoadEnds() async {
        let clock = ContinuousClock()
        let start = clock.now
        let ready = await AdLoadWait.until(
            timeout: .seconds(5), interval: .milliseconds(5),
            isReady: { false }, isLoading: { false }
        )
        #expect(!ready)
        #expect(clock.now - start < .seconds(1))
    }

    @Test("vence el plazo con la carga todavía en vuelo")
    func timesOut() async {
        let ready = await AdLoadWait.until(
            timeout: .milliseconds(60), interval: .milliseconds(5),
            isReady: { false }, isLoading: { true }
        )
        #expect(!ready)
    }

    @Test("el plazo del botón es de 8 s")
    func timeoutIsEightSeconds() {
        #expect(AdLoadWait.rewardedTimeout == .seconds(8))
    }
}
