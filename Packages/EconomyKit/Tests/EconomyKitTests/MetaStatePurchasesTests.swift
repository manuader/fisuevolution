import Foundation
import Testing
@testable import EconomyKit

@Suite("MetaState: el ORO comprado por transacción")
struct MetaStatePurchasesTests {
    @Test("una cuenta nueva no compró nada")
    func freshMetaHasNoPurchases() {
        let meta = fxState().meta
        #expect(meta.oroPurchases.isEmpty)
        #expect(meta.revokedPurchases.isEmpty)
        #expect(meta.oroPurchasedLifetime == 0)
    }

    @Test("anotar dos veces la misma transacción no suma")
    func recordingTheSameTransactionTwiceDoesNotAdd() {
        var meta = fxState().meta
        meta.recordOroPurchase(transactionID: "tx", amount: 250)
        meta.recordOroPurchase(transactionID: "tx", amount: 250)
        #expect(meta.oroPurchasedLifetime == 250)
    }

    @Test("transacciones distintas suman")
    func differentTransactionsAdd() {
        var meta = fxState().meta
        meta.recordOroPurchase(transactionID: "a", amount: 250)
        meta.recordOroPurchase(transactionID: "b", amount: 750)
        #expect(meta.oroPurchasedLifetime == 1000)
    }

    @Test("una anotación posterior con otro monto se queda con el mayor")
    func aLaterRecordKeepsTheLargerAmount() {
        var meta = fxState().meta
        meta.recordOroPurchase(transactionID: "tx", amount: 750)
        meta.recordOroPurchase(transactionID: "tx", amount: 250)
        #expect(meta.oroPurchasedLifetime == 750)
        meta.recordOroPurchase(transactionID: "tx", amount: 2000)
        #expect(meta.oroPurchasedLifetime == 2000)
    }

    @Test("lo revocado deja de contar, y anotarlo de nuevo no lo resucita")
    func revokedPurchasesStopCounting() {
        var meta = fxState().meta
        meta.recordOroPurchase(transactionID: "a", amount: 250)
        meta.recordOroPurchase(transactionID: "b", amount: 750)
        meta.revokePurchase(transactionID: "b")
        #expect(meta.oroPurchasedLifetime == 250)
        meta.recordOroPurchase(transactionID: "b", amount: 750)
        #expect(meta.oroPurchasedLifetime == 250)
    }

    @Test("revocar una transacción que todavía no se vio también la deja afuera")
    func revokingAnUnseenTransactionExcludesItLater() {
        var meta = fxState().meta
        meta.revokePurchase(transactionID: "later")
        meta.recordOroPurchase(transactionID: "later", amount: 750)
        #expect(meta.oroPurchasedLifetime == 0)
    }

    @Test("ida y vuelta por Codable")
    func codableRoundTrip() throws {
        var state = fxState()
        state.meta.recordOroPurchase(transactionID: "a", amount: 250)
        state.meta.recordOroPurchase(transactionID: "b", amount: 750)
        state.meta.revokePurchase(transactionID: "b")

        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(state))

        #expect(decoded == state)
        #expect(decoded.meta.oroPurchases == ["a": 250, "b": 750])
        #expect(decoded.meta.revokedPurchases == ["b"])
        #expect(decoded.meta.oroPurchasedLifetime == 250)
    }

    @Test("un save sin las claves nuevas decodifica con el mapa vacío")
    func aSaveWithoutTheNewKeysDecodesEmpty() throws {
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(fxState())) as? [String: Any]
        )
        var meta = try #require(object["meta"] as? [String: Any])
        meta.removeValue(forKey: "oroPurchases")
        meta.removeValue(forKey: "revokedPurchases")
        object["meta"] = meta

        let decoded = try JSONDecoder().decode(
            PlayerState.self, from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(decoded.meta.oroPurchases.isEmpty)
        #expect(decoded.meta.revokedPurchases.isEmpty)
        #expect(decoded.meta.oroPurchasedLifetime == 0)
    }

    @Test("el contador viejo de un save de desarrollo se ignora y reabre la reconstrucción")
    func theLegacyCounterIsIgnoredAndReopensTheReconstruction() throws {
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(fxState())) as? [String: Any]
        )
        var meta = try #require(object["meta"] as? [String: Any])
        meta["oroPurchasedLifetime"] = 550
        meta["purchasedOroReconstructed"] = true
        object["meta"] = meta

        let decoded = try JSONDecoder().decode(
            PlayerState.self, from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(decoded.meta.oroPurchasedLifetime == 0, "sin ids no hay cómo saber qué se contó")
        #expect(!decoded.meta.purchasedOroReconstructed, "la reconstrucción rehace la cuenta")
    }

    @Test("el contador viejo no reabre nada si el mapa ya tiene compras")
    func theLegacyCounterIsIgnoredWhenTheMapHasPurchases() throws {
        var state = fxState()
        state.meta.recordOroPurchase(transactionID: "a", amount: 250)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var meta = try #require(object["meta"] as? [String: Any])
        meta["oroPurchasedLifetime"] = 9999
        object["meta"] = meta

        let decoded = try JSONDecoder().decode(
            PlayerState.self, from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(decoded.meta.oroPurchasedLifetime == 250)
        #expect(decoded.meta.purchasedOroReconstructed)
    }

    @Test("el contador calculado no se escribe al save")
    func theComputedCounterIsNotEncoded() throws {
        var state = fxState()
        state.meta.recordOroPurchase(transactionID: "a", amount: 250)
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]
        )
        let meta = try #require(object["meta"] as? [String: Any])
        #expect(meta["oroPurchasedLifetime"] == nil)
    }
}
