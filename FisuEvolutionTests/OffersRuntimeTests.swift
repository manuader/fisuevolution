import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Las ofertas en la partida: cuándo se abren y cómo se presentan")
@MainActor
struct OffersRuntimeTests {
    /// Reloj de pared real: `offerToPresent` y el chip miran `Date()`, y el día del
    /// disparador de Bienvenida sale del `now`. Un `now` de 1970 los separaría.
    private let now = Date().timeIntervalSince1970

    private func day(_ time: TimeInterval) -> String {
        DailyRewardManager.dayString(for: Date(timeIntervalSince1970: time), calendar: GameState.gregorianCalendar)
    }

    /// Un juego con los motores prendidos y la línea de base ya tomada.
    private func running() async -> GameState {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.advanceOffers(now: now, chanceAllowed: true)
        return gameState
    }

    /// Bienvenida abierta, con el azar permitido.
    private func withWelcomeOpen() async -> GameState {
        let gameState = await running()
        gameState.player?.meta.engagement.firstLaunchDay = day(now - 86_400)
        gameState.advanceOffers(now: now + 1, chanceAllowed: true)
        return gameState
    }

    @Test("el primer arranque anota el día, aunque los motores estén apagados")
    func firstLaunchDayIsRecorded() async throws {
        let gameState = await makeGameState()
        #expect(!gameState.engagementAutorun)
        gameState.advanceOffers(now: now, chanceAllowed: true)
        #expect(gameState.player?.meta.engagement.firstLaunchDay == day(now))
        #expect(gameState.activeOffers(now: now).isEmpty)
    }

    @Test("reencarnar abre Renacer, y la oferta se presenta una sola vez")
    func rebirthOpensAndPresentsOnce() async throws {
        let gameState = await running()
        gameState.player?.meta.prestigeLevel += 1
        gameState.advanceOffers(now: now + 1, chanceAllowed: true)
        #expect(gameState.activeOffers(now: now + 1).map(\.id) == ["renacer"])
        #expect(gameState.offerToPresent?.id == "renacer")
        gameState.syncCelebrations()
        #expect(gameState.showing == .offer)
        drain(gameState)
        #expect(gameState.offerToPresent == nil, "ya se presentó")
        #expect(gameState.activeOffers(now: now + 2).map(\.id) == ["renacer"], "sigue en el chip")
    }

    @Test("durante el tutorial no se abre ninguna")
    func neverDuringTheTutorial() async throws {
        let gameState = await running()
        gameState.beginTutorialPhase()
        gameState.player?.meta.prestigeLevel += 1
        gameState.advanceOffers(now: now + 1, chanceAllowed: true)
        #expect(gameState.activeOffers(now: now + 1).isEmpty)
    }

    @Test("la de Bienvenida no se abre donde el azar está apagado")
    func welcomeRespectsTheGate() async throws {
        let gameState = await running()
        gameState.player?.meta.engagement.firstLaunchDay = day(now - 86_400)
        gameState.advanceOffers(now: now + 1, chanceAllowed: false)
        #expect(gameState.activeOffers(now: now + 1).isEmpty)
        gameState.advanceOffers(now: now + 2, chanceAllowed: true)
        #expect(gameState.activeOffers(now: now + 2).map(\.id) == ["bienvenida"])
    }

    @Test("abrir un piso abre Mudanza")
    func newFloorOpensMovingDay() async throws {
        let gameState = await running()
        gameState.debugUnlockFloors(throughTier: 5)
        gameState.advanceOffers(now: now + 1, chanceAllowed: true)
        #expect(gameState.activeOffers(now: now + 1).map(\.id).contains("mudanza"))
    }

    @Test("a las 24 h se va del chip")
    func expires() async throws {
        let gameState = await running()
        gameState.debugOpenOffer(id: "renacer", now: now)
        #expect(gameState.activeOffers(now: now + 86_399).count == 1)
        #expect(gameState.activeOffers(now: now + 86_400).isEmpty)
    }

    // MARK: La puerta del azar se mira cada vez que la oferta aparece

    @Test("si la tienda se vuelve restringida, la de Bienvenida abierta no se presenta ni se ve en el chip")
    func chanceOfferHidesWhenTheStorefrontCloses() async throws {
        let gameState = await withWelcomeOpen()
        #expect(gameState.visibleOffers(now: now + 2, chanceAllowed: true).map(\.id) == ["bienvenida"])
        #expect(gameState.presentableOffer(chanceAllowed: true)?.id == "bienvenida")
        #expect(gameState.visibleOffers(now: now + 2, chanceAllowed: false).isEmpty)
        #expect(gameState.presentableOffer(chanceAllowed: false) == nil)
    }

    @Test("lo que no trae azar se ve en cualquier tienda")
    func plainOffersIgnoreTheGate() async throws {
        let gameState = await running()
        gameState.debugOpenOffer(id: "renacer", now: now)
        #expect(gameState.visibleOffers(now: now + 1, chanceAllowed: false).map(\.id) == ["renacer"])
    }

    @Test("una hoja que se queda sin oferta no congela la cola")
    func theQueueDoesNotFreezeWhenTheOfferGoesAway() async throws {
        let gameState = await running()
        gameState.debugOpenOffer(id: "renacer", now: now)
        #expect(gameState.showing == .offer)
        gameState.player?.meta.engagement.offers.active.removeAll()
        gameState.syncCelebrations()
        #expect(gameState.showing == nil)
    }

    // MARK: Plata: un solo cobro por toque

    @Test("dos toques seguidos al precio inician una sola compra")
    func theLatchAllowsOnePurchase() async throws {
        let gameState = await running()
        gameState.debugOpenOffer(id: "renacer", now: now)
        var latch = PurchaseLatch()
        #expect(gameState.beginOfferPurchase("renacer", latch: &latch, chanceAllowed: true, now: now + 1))
        #expect(!gameState.beginOfferPurchase("renacer", latch: &latch, chanceAllowed: true, now: now + 1))
        latch.release()
        #expect(gameState.beginOfferPurchase("renacer", latch: &latch, chanceAllowed: true, now: now + 1),
                "terminada la compra se puede volver a intentar")
    }

    @Test("una oferta vencida, ya comprada o desconocida no se cobra y suelta el cerrojo")
    func nothingToBuyDoesNotLock() async throws {
        let gameState = await running()
        gameState.debugOpenOffer(id: "renacer", now: now)
        var latch = PurchaseLatch()
        #expect(!gameState.beginOfferPurchase("renacer", latch: &latch, chanceAllowed: true, now: now + 86_400))
        #expect(!latch.isLocked)
        #expect(!gameState.beginOfferPurchase("fantasma", latch: &latch, chanceAllowed: true, now: now + 1))
        #expect(!latch.isLocked)
        gameState.creditOffer("renacer", transactionID: "t-1", now: now + 2)
        #expect(!gameState.beginOfferPurchase("renacer", latch: &latch, chanceAllowed: true, now: now + 3))
        #expect(!latch.isLocked)
    }

    @Test("la de Bienvenida no se cobra donde el azar está apagado")
    func chanceOfferIsNotChargedWhenClosed() async throws {
        let gameState = await withWelcomeOpen()
        var latch = PurchaseLatch()
        #expect(!gameState.beginOfferPurchase("bienvenida", latch: &latch, chanceAllowed: false, now: now + 2))
        #expect(!latch.isLocked)
        #expect(gameState.beginOfferPurchase("bienvenida", latch: &latch, chanceAllowed: true, now: now + 2))
    }

    /// El cofre de bienvenida y lo que haya esperando toman su turno antes.
    private func drain(_ gameState: GameState) {
        for _ in 0..<12 {
            guard let current = gameState.showing else { return }
            if current == .chestOpening { gameState.chestReward = nil }
            gameState.celebrationFinished(current)
        }
    }
}
