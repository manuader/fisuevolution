import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("ORO comprado en la v1")
@MainActor
struct PurchasedOroHistoryTests {
    private let small = "com.fisuevolution.iap.oro_small"
    private let large = "com.fisuevolution.iap.oro_large"

    private func oroPack(amount: Int) -> ProductCatalog.Entry {
        ProductCatalog.Entry(
            id: "pack.oro",
            type: "consumable",
            entitlement: .oro,
            skinId: nil,
            coinFactor: nil,
            oroAmount: amount
        )
    }

    private func coinPack() -> ProductCatalog.Entry {
        ProductCatalog.Entry(
            id: "pack.coins",
            type: "consumable",
            entitlement: .coins,
            skinId: nil,
            coinFactor: 15,
            oroAmount: nil
        )
    }

    @Test("suma sólo lo que la v1 acreditó, con los montos de la v1")
    func reconstructsWhatV1Credited() {
        let records: [PurchasedOroHistory.Record] = [
            .init(transactionID: "1", productID: small, isRevoked: false),
            .init(transactionID: "2", productID: large, isRevoked: false),
            .init(transactionID: "3", productID: small, isRevoked: true),
            .init(transactionID: "4", productID: small, isRevoked: false),
            .init(transactionID: "5", productID: "com.fisuevolution.iap.coins_small", isRevoked: false),
        ]
        let total = PurchasedOroHistory.reconstruct(records: records, creditedTransactionIDs: ["1", "2", "3", "5"])
        #expect(total == 250 + 2000)
    }

    @Test("los montos de la v1 son una foto: no siguen a products.json")
    func v1AmountsAreFrozen() {
        #expect(PurchasedOroHistory.v1OroAmountByProductID == [
            "com.fisuevolution.iap.oro_small": 250,
            "com.fisuevolution.iap.oro_medium": 750,
            "com.fisuevolution.iap.oro_large": 2000,
        ])
    }

    @Test("un save de la v1 pide la reconstrucción y uno ya resuelto no")
    func v1SaveNeedsTheReconstruction() async {
        let gameState = await makeGameState()
        #expect(gameState.needsPurchasedOroReconstruction == false)
        gameState.player?.meta.purchasedOroReconstructed = false
        #expect(gameState.needsPurchasedOroReconstruction == true)
    }

    @Test("se reconstruye una sola vez")
    func reconstructionRunsOnce() async {
        let gameState = await makeGameState()
        gameState.player?.meta.purchasedOroReconstructed = false
        gameState.player?.meta.creditedPurchases = ["1"]
        let record = PurchasedOroHistory.Record(transactionID: "1", productID: small, isRevoked: false)
        gameState.completePurchasedOroReconstruction(records: [record])
        gameState.completePurchasedOroReconstruction(records: [record])
        #expect(gameState.player?.meta.oroPurchasedLifetime == 250)
        #expect(gameState.needsPurchasedOroReconstruction == false)
    }

    @Test("un historial vacío cierra la reconstrucción en 0: no se reintenta")
    func emptyHistoryClosesTheReconstructionAtZero() async {
        let gameState = await makeGameState()
        gameState.player?.meta.purchasedOroReconstructed = false
        gameState.player?.meta.creditedPurchases = ["1"]
        gameState.completePurchasedOroReconstruction(records: [])
        #expect(gameState.player?.meta.oroPurchasedLifetime == 0)
        #expect(gameState.needsPurchasedOroReconstruction == false)
    }

    @Test("una compra de ORO suma al total comprado en el acto, una vez por transacción")
    func anOroPurchaseCountsInTheAct() async {
        let gameState = await makeGameState()
        let oroBefore = gameState.player?.meta.oro ?? 0
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "10")
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "10")
        gameState.creditStorePurchase(oroPack(amount: 750), transactionID: "11")
        #expect(gameState.player?.meta.oroPurchasedLifetime == 1000)
        #expect(gameState.player?.meta.oro == oroBefore + 1000)
    }

    @Test("lo que se acredita después de reconstruir se suma a lo reconstruido")
    func newPurchasesAddToTheReconstructedTotal() async {
        let gameState = await makeGameState()
        gameState.player?.meta.purchasedOroReconstructed = false
        gameState.player?.meta.creditedPurchases = ["1"]
        gameState.completePurchasedOroReconstruction(records: [
            .init(transactionID: "1", productID: small, isRevoked: false),
        ])
        gameState.creditStorePurchase(oroPack(amount: 750), transactionID: "2")
        #expect(gameState.player?.meta.oroPurchasedLifetime == 250 + 750)
    }

    @Test("lo que no es ORO no suma al total comprado")
    func nonOroPurchasesDoNotCount() async {
        let gameState = await makeGameState()
        gameState.creditStorePurchase(coinPack(), transactionID: "20")
        #expect(gameState.player?.meta.oroPurchasedLifetime == 0)
    }

    @Test("el bundle pide el historial de consumibles")
    func infoPlistIncludesConsumables() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "SKIncludeConsumableInAppPurchaseHistory") as? Bool == true)
    }
}
