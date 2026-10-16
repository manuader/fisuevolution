import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los textos y la ilustración de la tarjeta del momento (2.1 E15 F3 T6).
@Suite("La tarjeta del momento")
@MainActor
struct MomentOfferCardTests {
    @Test("cada momento tiene su texto, con una clave propia")
    func everyMomentHasItsBody() {
        let keys = NeedMoment.allCases.map(MomentOfferCard.bodyKey(for:))
        #expect(Set(keys).count == NeedMoment.allCases.count)
        #expect(keys.contains("moment.card.body.price_wall"))
        #expect(keys.contains("moment.card.body.floor_full"))
    }

    @Test("la plata se ilustra con plata; «Fusionar todo», con la evolución")
    func illustration() {
        #expect(MomentOfferCard.kind(for: .grant(.coinsSeconds(300))) == .coins)
        #expect(MomentOfferCard.kind(for: .mergeAll) == .evolve)
    }

    @Test("el premio exacto: la plata que paga ahora")
    func amountIsTheExactCoins() {
        let label = MomentOfferCard.amountLabel(reward: .grant(.coinsSeconds(300)), coins: 1500)
        #expect(label == "+" + CoinFormatter.string(from: 1500))
    }
}
