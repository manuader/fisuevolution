import Foundation
import Testing
@testable import EconomyKit

@Suite("La audiencia de una oferta: a quién se le abre (2.1 F5 T1)")
struct OfferAudienceTests {
    private func catalog(audience: String?) throws -> OffersCatalog {
        let audienceField = audience.map { #", "audience": \#($0)"# } ?? ""
        let json = """
        {"schemaVersion": 1, "windowHours": 24, "cooldownDays": 3, "offers": [
          {"id": "bienvenida", "productId": "p.bienvenida", "trigger": "secondDay", "iconKey": "k", "symbol": "s",
           "rewards": [{"kind": "blue", "amount": 120}]\(audienceField)}
        ]}
        """
        return try JSONDecoder().decode(OffersCatalog.self, from: Data(json.utf8))
    }

    @Test("se lee con segmentos y comprador")
    func decodes() throws {
        let catalog = try catalog(audience: #"{"segments": ["mid", "high"], "buyer": "nonBuyer"}"#)
        let audience = try #require(catalog.offer(id: "bienvenida")?.audience)
        #expect(audience.segments == [.mid, .high])
        #expect(audience.buyer == .nonBuyer)
        try catalog.validate()
    }

    @Test("sin audiencia es para todos, como en la 2.0")
    func absentIsEveryone() throws {
        let catalog = try catalog(audience: nil)
        #expect(catalog.offer(id: "bienvenida")?.audience == nil)
        try catalog.validate()
    }

    @Test("sin segmentos ni comprador: todos los segmentos y cualquier comprador")
    func defaults() throws {
        let catalog = try catalog(audience: "{}")
        let audience = try #require(catalog.offer(id: "bienvenida")?.audience)
        #expect(audience.segments == nil)
        #expect(audience.buyer == .any)
        for segment in PlayerSegment.allCases {
            #expect(audience.admits(segment: segment, hasPurchased: true))
            #expect(audience.admits(segment: segment, hasPurchased: false))
        }
    }

    @Test("una lista de segmentos vacía es inválida")
    func emptySegmentsInvalid() throws {
        let catalog = try catalog(audience: #"{"segments": []}"#)
        #expect(throws: OffersCatalog.ValidationError.badAudience("bienvenida")) { try catalog.validate() }
    }

    @Test("nombrar base es inválido: base es la 2.0 y no se apunta")
    func baseInvalid() throws {
        let catalog = try catalog(audience: #"{"segments": ["base", "high"]}"#)
        #expect(throws: OffersCatalog.ValidationError.badAudience("bienvenida")) { try catalog.validate() }
    }

    @Test("ida y vuelta: se escribe y se vuelve a leer igual")
    func roundTrip() throws {
        let original = try catalog(audience: #"{"segments": ["low"], "buyer": "buyer"}"#)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OffersCatalog.self, from: data)
        #expect(decoded == original)
        #expect(decoded.offer(id: "bienvenida")?.audience == OfferAudience(segments: [.low], buyer: .buyer))

        let plain = try catalog(audience: nil)
        let plainDecoded = try JSONDecoder().decode(OffersCatalog.self, from: JSONEncoder().encode(plain))
        #expect(plainDecoded == plain)
        #expect(plainDecoded.offer(id: "bienvenida")?.audience == nil)
    }

    @Test("admite según segmento y compra")
    func admits() {
        let audience = OfferAudience(segments: [.high], buyer: .nonBuyer)
        #expect(audience.admits(segment: .high, hasPurchased: false))
        #expect(!audience.admits(segment: .high, hasPurchased: true), "nonBuyer no abre para quien compró")
        #expect(!audience.admits(segment: .mid, hasPurchased: false), "[high] no abre para mid")

        let buyers = OfferAudience(segments: nil, buyer: .buyer)
        #expect(buyers.admits(segment: .low, hasPurchased: true))
        #expect(!buyers.admits(segment: .low, hasPurchased: false))
    }

    @Test("con base la audiencia se ignora: el interruptor apaga F5")
    func baseIgnoresAudience() {
        let audience = OfferAudience(segments: [.high], buyer: .buyer)
        #expect(audience.admits(segment: .base, hasPurchased: false))
        #expect(audience.admits(segment: .base, hasPurchased: true))
    }
}
