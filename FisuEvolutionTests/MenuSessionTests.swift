import Testing
@testable import FisuEvolution

/// La sesión del menú deslizable (PLAN-v2 E3): recorrer páginas no es una pausa;
/// cerrar el menú sí, y ahí se pide el intersticial UNA vez.
@Suite("La sesión de menú", .serialized)
@MainActor
struct MenuSessionTests {
    @Test("el intersticial se pide una vez al cerrar el menú, nunca al cambiar de página")
    func interstitialOnlyOnClose() async {
        let gameState = await makeGameState()
        let clock = TestClock()
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(now: clock.read, provider: provider)
        gameState.attachAds(ads)
        clock.advance(by: 10_000)
        ads.armIfDue()
        #expect(ads.isInterstitialArmed, "el escenario es un intersticial que ya toca")

        gameState.menuDidOpen(at: .upgrades)
        gameState.menuPageChanged(to: .skins)
        gameState.menuPageChanged(to: .jobs)
        #expect(provider.shown.isEmpty, "cambiar de página no es una pausa natural")

        await gameState.menuDidClose()
        #expect(provider.shown == ["interstitial"])
    }

    @Test("el paginador arranca en la página pedida y monta sólo a las vecinas")
    func pagerStartsOnTheRequestedPage() {
        let pages = GameScreen.barOrder
        #expect(MenuPagerView.startIndex(of: .jobs, in: pages) == 2)
        #expect(MenuPagerView.startIndex(of: .menu, in: [.upgrades, .skins]) == 0,
                "una página que no está desbloqueada cae en la primera")
        #expect(MenuPagerView.isMounted(index: 1, current: 2))
        #expect(MenuPagerView.isMounted(index: 3, current: 2))
        #expect(!MenuPagerView.isMounted(index: 4, current: 2))
    }
}
