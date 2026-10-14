import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("blue comprado en la v1")
@MainActor
struct PurchasedBlueHistoryTests {
    private let small = "com.fisuevolution.iap.oro_small"
    private let large = "com.fisuevolution.iap.oro_large"

    private func bluePack(amount: Int) -> ProductCatalog.Entry {
        ProductCatalog.Entry(
            id: "pack.blue",
            type: "consumable",
            entitlement: .blue,
            skinId: nil,
            coinMinutes: nil,
            blueAmount: amount
        )
    }

    private func coinPack() -> ProductCatalog.Entry {
        ProductCatalog.Entry(
            id: "pack.coins",
            type: "consumable",
            entitlement: .coins,
            skinId: nil,
            coinMinutes: 60,
            blueAmount: nil
        )
    }

    @Test("asigna por id sólo lo que la v1 acreditó, con los montos de la v1, y separa los reembolsos")
    func reconstructsWhatV1Credited() {
        let records: [PurchasedBlueHistory.Record] = [
            .init(transactionID: "1", productID: small, isRevoked: false),
            .init(transactionID: "2", productID: large, isRevoked: false),
            .init(transactionID: "3", productID: small, isRevoked: true),
            .init(transactionID: "4", productID: small, isRevoked: false),
            .init(transactionID: "5", productID: "com.fisuevolution.iap.coins_small", isRevoked: false),
        ]
        let history = PurchasedBlueHistory.reconstruct(records: records, creditedTransactionIDs: ["1", "2", "3", "5"])
        #expect(history.purchases == ["1": 250, "2": 2000])
        #expect(history.revoked == ["3"])
    }

    @Test("los montos de la v1 son una foto: no siguen a products.json")
    func v1AmountsAreFrozen() {
        #expect(PurchasedBlueHistory.v1BlueAmountByProductID == [
            "com.fisuevolution.iap.oro_small": 250,
            "com.fisuevolution.iap.oro_medium": 750,
            "com.fisuevolution.iap.oro_large": 2000,
        ])
    }

    @Test("un save de la v1 pide la reconstrucción y uno ya resuelto no")
    func v1SaveNeedsTheReconstruction() async {
        let gameState = await makeGameState()
        #expect(gameState.needsPurchasedBlueReconstruction == false)
        gameState.player?.meta.purchasedBlueReconstructed = false
        #expect(gameState.needsPurchasedBlueReconstruction == true)
    }

    @Test("se reconstruye una sola vez")
    func reconstructionRunsOnce() async {
        let gameState = await makeGameState()
        gameState.player?.meta.purchasedBlueReconstructed = false
        gameState.player?.meta.creditedPurchases = ["1"]
        let record = PurchasedBlueHistory.Record(transactionID: "1", productID: small, isRevoked: false)
        gameState.completePurchasedBlueReconstruction(records: [record])
        gameState.completePurchasedBlueReconstruction(records: [record])
        #expect(gameState.player?.meta.bluePurchasedLifetime == 250)
        #expect(gameState.needsPurchasedBlueReconstruction == false)
    }

    @Test("un historial vacío cierra la reconstrucción en 0: no se reintenta")
    func emptyHistoryClosesTheReconstructionAtZero() async {
        let gameState = await makeGameState()
        gameState.player?.meta.purchasedBlueReconstructed = false
        gameState.player?.meta.creditedPurchases = ["1"]
        gameState.completePurchasedBlueReconstruction(records: [])
        #expect(gameState.player?.meta.bluePurchasedLifetime == 0)
        #expect(gameState.needsPurchasedBlueReconstruction == false)
    }

    @Test("una compra de blue suma al total comprado en el acto, una vez por transacción")
    func anBluePurchaseCountsInTheAct() async {
        let gameState = await makeGameState()
        let blueBefore = gameState.player?.meta.blue ?? 0
        gameState.creditStorePurchase(bluePack(amount: 250), transactionID: "10")
        gameState.creditStorePurchase(bluePack(amount: 250), transactionID: "10")
        gameState.creditStorePurchase(bluePack(amount: 750), transactionID: "11")
        #expect(gameState.player?.meta.bluePurchasedLifetime == 1000)
        #expect(gameState.player?.meta.blue == blueBefore + 1000)
    }

    @Test("lo que se acredita después de reconstruir se suma a lo reconstruido")
    func newPurchasesAddToTheReconstructedTotal() async {
        let gameState = await makeGameState()
        gameState.player?.meta.purchasedBlueReconstructed = false
        gameState.player?.meta.creditedPurchases = ["1"]
        gameState.completePurchasedBlueReconstruction(records: [
            .init(transactionID: "1", productID: small, isRevoked: false),
        ])
        gameState.creditStorePurchase(bluePack(amount: 750), transactionID: "2")
        #expect(gameState.player?.meta.bluePurchasedLifetime == 250 + 750)
    }

    @Test("reconstruir dos veces, aunque se reabra la bandera, no cuenta doble")
    func reconstructingTwiceDoesNotCountTwice() async {
        let gameState = await makeGameState()
        let record = PurchasedBlueHistory.Record(transactionID: "1", productID: small, isRevoked: false)
        gameState.player?.meta.creditedPurchases = ["1"]
        for _ in 0..<2 {
            gameState.player?.meta.purchasedBlueReconstructed = false
            gameState.completePurchasedBlueReconstruction(records: [record])
        }
        #expect(gameState.player?.meta.bluePurchasedLifetime == 250)
    }

    @Test("una compra de la v2 que la reconstrucción vuelve a ver se cuenta una vez")
    func aCreditedPurchaseSeenByTheReconstructionCountsOnce() async {
        let gameState = await makeGameState()
        gameState.creditStorePurchase(bluePack(amount: 250), transactionID: "7")
        gameState.player?.meta.purchasedBlueReconstructed = false
        gameState.completePurchasedBlueReconstruction(records: [
            .init(transactionID: "7", productID: small, isRevoked: false),
        ])
        #expect(gameState.player?.meta.bluePurchasedLifetime == 250)
    }

    @Test("una compra de la v2 ya anotada no se pisa con el monto de la v1")
    func theReconstructionKeepsTheAmountOfAnAlreadyRecordedPurchase() async {
        let gameState = await makeGameState()
        gameState.creditStorePurchase(bluePack(amount: 100), transactionID: "7")
        gameState.player?.meta.purchasedBlueReconstructed = false
        gameState.completePurchasedBlueReconstruction(records: [
            .init(transactionID: "7", productID: small, isRevoked: false),
        ])
        #expect(gameState.player?.meta.bluePurchasedLifetime == 100)
    }

    @Test("un reembolso baja el total comprado, llegue antes o después de anotar la compra")
    func aRefundLowersThePurchasedTotal() async {
        let gameState = await makeGameState()
        gameState.creditStorePurchase(bluePack(amount: 250), transactionID: "10")
        gameState.creditStorePurchase(bluePack(amount: 750), transactionID: "11")
        gameState.revokeStorePurchase(transactionID: "11")
        #expect(gameState.player?.meta.bluePurchasedLifetime == 250)

        gameState.revokeStorePurchase(transactionID: "12")
        gameState.creditStorePurchase(bluePack(amount: 2000), transactionID: "12")
        #expect(gameState.player?.meta.bluePurchasedLifetime == 250)
    }

    @Test("la reconstrucción marca como revocado lo que el historial trae reembolsado")
    func theReconstructionMarksRefundedRecords() async {
        let gameState = await makeGameState()
        gameState.player?.meta.purchasedBlueReconstructed = false
        gameState.player?.meta.creditedPurchases = ["1", "2"]
        gameState.completePurchasedBlueReconstruction(records: [
            .init(transactionID: "1", productID: small, isRevoked: false),
            .init(transactionID: "2", productID: large, isRevoked: true),
        ])
        #expect(gameState.player?.meta.bluePurchasedLifetime == 250)
        #expect(gameState.player?.meta.revokedPurchases == ["2"])
    }

    @Test("lo que no es blue no suma al total comprado")
    func nonBluePurchasesDoNotCount() async {
        let gameState = await makeGameState()
        gameState.creditStorePurchase(coinPack(), transactionID: "20")
        #expect(gameState.player?.meta.bluePurchasedLifetime == 0)
    }

    @Test("el bundle pide el historial de consumibles")
    func infoPlistIncludesConsumables() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "SKIncludeConsumableInAppPurchaseHistory") as? Bool == true)
    }
}
