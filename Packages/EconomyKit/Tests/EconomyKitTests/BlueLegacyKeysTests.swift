import Foundation
import Testing
@testable import EconomyKit

// MARK: - El save de antes de E14b B14: el blue con sus claves viejas
//
// Hasta E14b B14 el blue se guardaba con otro nombre. Un save escrito así se lee
// sin perder un solo blue, y al guardarse de nuevo sale sólo con las claves nuevas.

@Suite("El save viejo del blue")
struct BlueLegacyKeysTests {
    /// Clave nueva → clave vieja, por diccionario del sobre.
    private static let metaKeys = [
        "blue": "oro",
        "blueEarnedLifetime": "oroEarnedLifetime",
        "blueUpgradeLevels": "oroUpgradeLevels",
        "bluePurchases": "oroPurchases",
        "purchasedBlueReconstructed": "purchasedOroReconstructed",
    ]
    private static let statsKeys = ["blueSpentEver": "oroSpentEver"]
    private static let wheelKeys = ["blueSpinsUsed": "oroSpinsUsed"]
    private static let visitorsKeys = ["blueExchangedToday": "oroExchangedToday"]

    private func stateWithBlue() -> PlayerState {
        var state = fxState()
        state.meta.blue = 37
        state.meta.blueEarnedLifetime = 120
        state.meta.blueUpgradeLevels = ["offline": 2]
        state.meta.recordBluePurchase(transactionID: "t1", amount: 160)
        state.meta.purchasedBlueReconstructed = false
        state.meta.stats.blueSpentEver = 9
        state.meta.engagement.wheel = WheelState(day: "2026-10-14", blueSpinsUsed: 2, repeatableSegmentId: "blue_3")
        state.meta.engagement.visitors.blueExchangedToday = 1
        return state
    }

    private func renaming(_ object: [String: Any], _ keys: [String: String]) -> [String: Any] {
        var renamed = object
        for (new, old) in keys {
            guard let value = renamed.removeValue(forKey: new) else { continue }
            renamed[old] = value
        }
        return renamed
    }

    private func object(_ state: PlayerState) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    }

    /// El sobre de `state` como lo escribía un build anterior a B14.
    private func legacyBlob(_ state: PlayerState) throws -> Data {
        var envelope = try object(state)
        var meta = try #require(envelope["meta"] as? [String: Any])
        var engagement = try #require(meta["engagement"] as? [String: Any])
        var wheel = renaming(try #require(engagement["wheel"] as? [String: Any]), Self.wheelKeys)
        wheel["repeatableSegmentId"] = "oro_3"
        engagement["wheel"] = wheel
        engagement["visitors"] = renaming(try #require(engagement["visitors"] as? [String: Any]), Self.visitorsKeys)
        meta["engagement"] = engagement
        meta["stats"] = renaming(try #require(meta["stats"] as? [String: Any]), Self.statsKeys)
        envelope["meta"] = renaming(meta, Self.metaKeys)
        return try JSONSerialization.data(withJSONObject: envelope)
    }

    @Test("un save con las claves viejas se lee sin perder blue")
    func legacyBlobKeepsEveryBlue() throws {
        let original = stateWithBlue()
        let decoded = try JSONDecoder().decode(PlayerState.self, from: legacyBlob(original))
        #expect(decoded == original)
        #expect(decoded.meta.blue == 37)
        #expect(decoded.meta.bluePurchasedLifetime == 160)
        #expect(decoded.meta.engagement.wheel.repeatableSegmentId == "blue_3")
    }

    @Test("ida y vuelta: lo leído con las claves viejas se guarda sólo con las nuevas")
    func legacyBlobRoundTripsToNewKeys() throws {
        let decoded = try JSONDecoder().decode(PlayerState.self, from: legacyBlob(stateWithBlue()))
        let envelope = try object(decoded)
        let meta = try #require(envelope["meta"] as? [String: Any])
        let stats = try #require(meta["stats"] as? [String: Any])
        let engagement = try #require(meta["engagement"] as? [String: Any])
        let wheel = try #require(engagement["wheel"] as? [String: Any])
        let visitors = try #require(engagement["visitors"] as? [String: Any])
        for (dictionary, keys) in [(meta, Self.metaKeys), (stats, Self.statsKeys),
                                   (wheel, Self.wheelKeys), (visitors, Self.visitorsKeys)] {
            for (new, old) in keys {
                #expect(dictionary[new] != nil, "falta \(new)")
                #expect(dictionary[old] == nil, "quedó \(old)")
            }
        }
        #expect(try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(decoded)) == decoded)
    }

    @Test("si están las dos claves, manda la nueva")
    func newKeyWins() throws {
        var envelope = try object(stateWithBlue())
        var meta = try #require(envelope["meta"] as? [String: Any])
        meta["oro"] = 999
        envelope["meta"] = meta
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONSerialization.data(withJSONObject: envelope))
        #expect(decoded.meta.blue == 37)
    }

    @Test("un premio guardado con el nombre viejo del blue se lee como blue y se escribe como blue")
    func legacyRewardKind() throws {
        let reward = try JSONDecoder().decode(RewardSpec.self, from: Data(#"{"kind": "oro", "amount": 2}"#.utf8))
        #expect(reward == .blue(2))
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(reward)) as? [String: Any])
        #expect(encoded["kind"] as? String == "blue")
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RewardSpec.self, from: Data(#"{"kind": "nada", "amount": 2}"#.utf8))
        }
    }
}
