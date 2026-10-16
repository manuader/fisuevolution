import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Las ofertas y la Tienda según el segmento (2.1 E15 F5 T3): con `base`, todo igual a la 2.0; con
/// otro segmento cambia **qué** se ofrece y qué se destaca, nunca el precio, y en la UE se avisa.
@Suite("Las ofertas y la Tienda según el segmento")
@MainActor
struct OffersSegmentTests {
    private let now = Date().timeIntervalSince1970

    private func day(_ time: TimeInterval) -> String {
        DailyRewardManager.dayString(for: Date(timeIntervalSince1970: time), calendar: GameState.gregorianCalendar)
    }

    /// Un juego con los motores prendidos, la línea de base tomada y el segundo día cumplido: lo
    /// próximo que se evalúe dispara Bienvenida.
    private func onTheSecondDay(segment: PlayerSegment, bought: Bool) async -> GameState {
        let gameState = await makeGameState()
        gameState.engagementAutorun = true
        gameState.advanceOffers(now: now, chanceAllowed: true, segment: segment)
        if bought { gameState.player?.meta.creditedPurchases.insert("tx.1") }
        gameState.player?.meta.engagement.firstLaunchDay = day(now - 86_400)
        return gameState
    }

    private func catalog() throws -> [ProductCatalog.Entry] {
        try ProductCatalog.load(from: .main).products
    }

    // MARK: El contenido

    @Test("offers.json: Bienvenida es para quien no compró; Renacer y Mudanza, para todos")
    func seededAudiences() throws {
        let offers = try GameContentLoader.load(from: .main).offers
        #expect(offers.offer(id: "bienvenida")?.audience == OfferAudience(buyer: .nonBuyer))
        #expect(offers.offer(id: "renacer")?.audience == nil)
        #expect(offers.offer(id: "mudanza")?.audience == nil)
    }

    @Test("ninguna oferta cambia de producto: los ids de App Store son los de la 2.0")
    func productsUntouched() throws {
        let offers = try GameContentLoader.load(from: .main).offers
        #expect(offers.offers.map(\.productId) == [
            "com.fisuevolution.iap.offer_bienvenida",
            "com.fisuevolution.iap.offer_renacer",
            "com.fisuevolution.iap.offer_mudanza",
        ])
    }

    // MARK: Las señales

    @Test("las señales llevan el segmento y si compró")
    func signalsCarrySegmentAndPurchase() async throws {
        let gameState = await makeGameState()
        #expect(gameState.offerSignals(today: "2026-10-16").segment == .base, "sin servicio, la 2.0")
        #expect(!gameState.hasPaidPurchase)
        gameState.player?.meta.creditedPurchases.insert("tx.1")
        let signals = gameState.offerSignals(today: "2026-10-16", segment: .high)
        #expect(signals.segment == .high)
        #expect(signals.hasPurchased)
        #expect(gameState.hasPaidPurchase)
    }

    @Test("con base, Bienvenida se abre también para quien compró: la 2.0")
    func baseIgnoresAudience() async throws {
        let gameState = await onTheSecondDay(segment: .base, bought: true)
        gameState.advanceOffers(now: now + 1, chanceAllowed: true, segment: .base)
        #expect(gameState.activeOffers(now: now + 1).map(\.id) == ["bienvenida"])
    }

    @Test("con high y una compra, Bienvenida no se abre")
    func buyerSkipsWelcome() async throws {
        let gameState = await onTheSecondDay(segment: .high, bought: true)
        gameState.advanceOffers(now: now + 1, chanceAllowed: true, segment: .high)
        #expect(gameState.activeOffers(now: now + 1).isEmpty)
    }

    @Test("con high y sin compras, Bienvenida se abre")
    func nonBuyerGetsWelcome() async throws {
        let gameState = await onTheSecondDay(segment: .high, bought: false)
        gameState.advanceOffers(now: now + 1, chanceAllowed: true, segment: .high)
        #expect(gameState.activeOffers(now: now + 1).map(\.id) == ["bienvenida"])
    }

    // MARK: El aviso

    @Test("el aviso sale en la UE, para una oferta con audiencia y un segmento que no es base")
    func chosenNoticeForHighInTheEU() async throws {
        let gameState = await makeGameState()
        #expect(gameState.isOfferChosenForPlayer("bienvenida", segment: .high))
        #expect(gameState.showsChosenNotice(offerId: "bienvenida", storefront: "DEU", segment: .high))
        #expect(!gameState.showsChosenNotice(offerId: "bienvenida", storefront: "USA", segment: .high))
        #expect(!gameState.showsChosenNotice(offerId: "bienvenida", storefront: nil, segment: .high))
    }

    @Test("con base, o con una oferta para todos, no hay aviso")
    func noNoticeForBaseOrOpenOffers() async throws {
        let gameState = await makeGameState()
        #expect(!gameState.isOfferChosenForPlayer("bienvenida", segment: .base))
        #expect(!gameState.showsChosenNotice(offerId: "bienvenida", storefront: "DEU", segment: .base))
        #expect(!gameState.isOfferChosenForPlayer("renacer", segment: .high))
        #expect(!gameState.showsChosenNotice(offerId: "renacer", storefront: "DEU", segment: .high))
        #expect(!gameState.isOfferChosenForPlayer("no-existe", segment: .high))
    }

    @Test("la UE son los 27, en alfa-3")
    func euStorefronts() {
        #expect(OfferNotice.euStorefronts.count == 27)
        #expect(OfferNotice.euStorefronts.allSatisfy { $0.count == 3 && $0 == $0.uppercased() })
        for member in ["DEU", "FRA", "ESP", "ITA", "IRL", "MLT", "CYP", "HRV"] {
            #expect(OfferNotice.isEU(storefront: member), "\(member)")
        }
        for outsider in ["GBR", "CHE", "NOR", "USA", "ARG", "ISL"] {
            #expect(!OfferNotice.isEU(storefront: outsider), "\(outsider)")
        }
        #expect(OfferNotice.isEU(storefront: "deu"), "el storefront llega en mayúsculas, pero no se confía")
        #expect(!OfferNotice.isEU(storefront: nil))
        #expect(!OfferNotice.isEU(storefront: ""))
    }

    // MARK: La Tienda

    @Test("con base la Tienda no destaca nada: la 2.0")
    func baseStoreHasNoHighlight() async throws {
        let gameState = await makeGameState()
        let entries = try catalog()
        #expect(gameState.storeHighlight(entries: entries, segment: .base) == nil)
        gameState.player?.meta.creditedPurchases.insert("tx.1")
        #expect(gameState.storeHighlight(entries: entries, segment: .base) == nil)
    }

    @Test("high sin compras: se destaca el pack de inicio")
    func highNonBuyerSeesTheStarter() async throws {
        let gameState = await makeGameState()
        #expect(gameState.storeHighlight(entries: try catalog(), segment: .high) == "com.fisuevolution.iap.starter_pack")
        #expect(gameState.storeHighlight(entries: try catalog(), segment: .low) == nil)
    }

    @Test("quien compró blue ve destacado el pack siguiente al más grande que compró")
    func buyerSeesTheNextPack() async throws {
        let gameState = await makeGameState()
        let entries = try catalog()
        gameState.player?.meta.creditedPurchases.insert("tx.1")
        #expect(gameState.storeHighlight(entries: entries, segment: .mid) == "com.fisuevolution.iap.oro_small",
                "compró, pero no blue: el más chico")
        gameState.player?.meta.recordBluePurchase(transactionID: "tx.1", amount: 160)
        #expect(gameState.storeHighlight(entries: entries, segment: .mid) == "com.fisuevolution.iap.oro_medium")
        gameState.player?.meta.creditedPurchases.insert("tx.2")
        gameState.player?.meta.recordBluePurchase(transactionID: "tx.2", amount: 1400)
        #expect(gameState.storeHighlight(entries: entries, segment: .mid) == nil, "ya compró el más grande")
    }

    @Test("el destaque es siempre un producto del catálogo que se le pasa")
    func highlightNeverOutsideTheCatalog() async throws {
        let gameState = await makeGameState()
        let entries = try catalog()
        let ids = Set(entries.map(\.id))
        for segment in PlayerSegment.allCases {
            for bought in [false, true] {
                if bought { gameState.player?.meta.creditedPurchases.insert("tx.\(segment)") }
                if let id = gameState.storeHighlight(entries: entries, segment: segment) {
                    #expect(ids.contains(id))
                }
            }
        }
        #expect(gameState.storeHighlight(entries: [], segment: .high) == nil)
    }
}
