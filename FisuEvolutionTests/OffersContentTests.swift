import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Las tres ofertas que aprobó el dueño (PLAN-v2 §2): precio en el `.storekit`,
/// contenido en `offers.json`.
@Suite("offers.json: las tres ofertas aprobadas")
@MainActor
struct OffersContentTests {
    let content: GameContent
    let products: ProductCatalog

    init() throws {
        content = try GameContentLoader.load(from: .main)
        products = try ProductCatalog.load(from: .main)
    }

    @Test("las tres, con su disparador y su contenido")
    func theApprovedOffers() throws {
        let offers = content.offers
        #expect(offers.windowHours == 24)
        #expect(offers.cooldownDays == 3)
        let welcome = try #require(offers.offer(id: "bienvenida"))
        #expect(welcome.trigger == .secondDay)
        #expect(welcome.oncePerAccount)
        #expect(welcome.isChance)
        #expect(welcome.rewards == [.oro(120), .coinsSeconds(7200), .skinChest(1)])
        let rebirth = try #require(offers.offer(id: "renacer"))
        #expect(rebirth.trigger == .reincarnation)
        #expect(rebirth.rewards == [.oro(300), .coinsSeconds(14_400), .modifier(effect: .incomeMultiplier, magnitude: 3, seconds: 1800)])
        let moving = try #require(offers.offer(id: "mudanza"))
        #expect(moving.trigger == .newFloor)
        #expect(moving.rewards == [.oro(500), .coinsSeconds(28_800), .package(3)])
    }

    @Test("cada oferta tiene su consumible y cada consumible de oferta, su oferta")
    func offersAndProductsMatch() throws {
        for offer in content.offers.offers {
            let entry = try #require(products.products.first { $0.id == offer.productId }, "\(offer.id) sin producto")
            #expect(entry.entitlement == .offer)
            #expect(entry.offerId == offer.id)
            #expect(entry.isConsumable, "Renacer y Mudanza vuelven: un no consumible se compra una vez en la vida")
        }
        for entry in products.products where entry.entitlement == .offer {
            #expect(content.offers.offer(id: entry.offerId ?? "") != nil, "\(entry.id) sin oferta")
        }
    }

    @Test("todo lo que trae una oferta se puede entregar")
    func everythingIsGrantable() {
        for offer in content.offers.offers {
            for reward in offer.rewards {
                #expect(GameState.grantableRewardKinds.contains(reward.kind), "\(offer.id): \(reward.kind) no se entrega")
            }
        }
    }
}
