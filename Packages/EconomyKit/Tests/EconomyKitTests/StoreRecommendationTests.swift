import Foundation
import Testing
@testable import EconomyKit

@Suite("El pack de blue destacado según el segmento (2.1 F5 T2)")
struct StoreRecommendationTests {
    private let starter = StoreRecommendation.Pack(id: "iap.starter", kind: .starter, blueAmount: 0)
    private let small = StoreRecommendation.Pack(id: "iap.oro_small", kind: .blue, blueAmount: 160)
    private let medium = StoreRecommendation.Pack(id: "iap.oro_medium", kind: .blue, blueAmount: 550)
    private let large = StoreRecommendation.Pack(id: "iap.oro_large", kind: .blue, blueAmount: 1400)

    /// Desordenado a propósito: el orden del catálogo no manda, manda el monto.
    private var packs: [StoreRecommendation.Pack] { [large, starter, small, medium] }

    private func highlight(
        _ segment: PlayerSegment, bought: Bool, last: String? = nil, packs: [StoreRecommendation.Pack]? = nil
    ) -> String? {
        StoreRecommendation.highlight(
            segment: segment, hasPurchased: bought, lastPurchasedID: last, packs: packs ?? self.packs
        )
    }

    @Test("base no destaca nada: la Tienda de la 2.0, compre o no")
    func baseIsNil() {
        #expect(highlight(.base, bought: false) == nil)
        #expect(highlight(.base, bought: true, last: small.id) == nil)
    }

    @Test("quien compró ve el pack siguiente al último comprado")
    func buyerGetsNextPack() {
        #expect(highlight(.mid, bought: true, last: small.id) == medium.id)
        #expect(highlight(.high, bought: true, last: medium.id) == large.id)
        #expect(highlight(.low, bought: true, last: small.id) == medium.id)
    }

    @Test("quien ya compró el más grande no ve un pack que no existe")
    func buyerOfLargestGetsNil() {
        #expect(highlight(.high, bought: true, last: large.id) == nil)
    }

    @Test("quien compró algo que no es un pack de blue ve el más chico")
    func buyerOfOtherThingGetsSmallest() {
        #expect(highlight(.mid, bought: true, last: "iap.remove_ads") == small.id)
        #expect(highlight(.mid, bought: true, last: nil) == small.id)
    }

    @Test("quien no compró y es high ve el pack de inicio")
    func nonBuyerHighGetsStarter() {
        #expect(highlight(.high, bought: false) == starter.id)
    }

    @Test("quien no compró y es low o mid no ve destaque")
    func nonBuyerLowAndMidGetNil() {
        #expect(highlight(.low, bought: false) == nil)
        #expect(highlight(.mid, bought: false) == nil)
    }

    @Test("nunca devuelve un producto fuera del catálogo")
    func neverOutsideCatalog() {
        let ids = Set(packs.map(\.id))
        for segment in PlayerSegment.allCases {
            for last in [nil, small.id, medium.id, large.id, "iap.fantasma"] {
                for bought in [false, true] {
                    if let id = highlight(segment, bought: bought, last: last) { #expect(ids.contains(id)) }
                }
            }
        }
        #expect(highlight(.high, bought: false, packs: [small, medium]) == nil)
        #expect(highlight(.high, bought: true, last: small.id, packs: []) == nil)
        #expect(highlight(.high, bought: true, last: "iap.fantasma", packs: [starter]) == nil)
    }

    @Test("sólo agrega un destaque: no cambia el catálogo ni el orden de precios")
    func doesNotMutateCatalog() {
        let before = packs
        _ = highlight(.high, bought: true, last: small.id)
        #expect(packs == before)
    }
}
