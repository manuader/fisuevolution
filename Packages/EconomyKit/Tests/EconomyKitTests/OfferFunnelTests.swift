import Foundation
import Testing
@testable import EconomyKit

// MARK: - E15 C3: cómo convierte cada oferta con video, por lugar

@Suite("OfferFunnel (E15)")
struct OfferFunnelTests {
    @Test("suma por etapa y por lugar")
    func countsByStageAndSite() {
        var funnel = OfferFunnel.empty
        funnel.record(.shown, site: "offline.x2")
        funnel.record(.shown, site: "offline.x2")
        funnel.record(.accepted, site: "offline.x2")
        funnel.record(.completed, site: "offline.x2")
        funnel.record(.dismissed, site: "ads.watch.double_earnings")

        let offline = funnel.counts(site: "offline.x2")
        #expect(offline == OfferFunnel.Counts(shown: 2, accepted: 1, completed: 1, unfilled: 0, dismissed: 0))
        #expect(funnel.counts(site: "ads.watch.double_earnings")[.dismissed] == 1)
        #expect(funnel.counts(site: "nunca.visto") == .zero)
    }

    @Test("el abandono es accepted − completed − unfilled, nunca negativo")
    func abandonedIsDerived() {
        var funnel = OfferFunnel.empty
        for _ in 1...4 { funnel.record(.accepted, site: "double.wheel") }
        funnel.record(.completed, site: "double.wheel")
        funnel.record(.unfilled, site: "double.wheel")
        #expect(funnel.counts(site: "double.wheel").abandoned == 2)
        #expect(OfferFunnel.Counts(shown: 0, accepted: 0, completed: 1, unfilled: 0, dismissed: 0).abandoned == 0)
    }

    @Test("los ids del paso 2 (double.*) son lugares como cualquier otro")
    func doubleSitesAreAccepted() {
        var funnel = OfferFunnel.empty
        for site in ["double.visit.el-ministro", "double.offline", "double.wheel"] {
            funnel.record(.shown, site: site)
        }
        #expect(funnel.sites.keys.sorted() == ["double.offline", "double.visit.el-ministro", "double.wheel"])
    }

    @Test("tope de 64 lugares: el 65.º y los que sigan van a _other")
    func capsSitesAtSixtyFour() {
        var funnel = OfferFunnel.empty
        for index in 0..<OfferFunnel.maxSites { funnel.record(.shown, site: "site.\(index)") }
        funnel.record(.shown, site: "site.extra.a")
        funnel.record(.accepted, site: "site.extra.b")
        funnel.record(.shown, site: "site.0")

        #expect(funnel.sites.count == OfferFunnel.maxSites + 1)
        #expect(funnel.sites["site.extra.a"] == nil)
        #expect(funnel.counts(site: OfferFunnel.overflowSite)[.shown] == 1)
        #expect(funnel.counts(site: OfferFunnel.overflowSite)[.accepted] == 1)
        #expect(funnel.counts(site: "site.0")[.shown] == 2, "un lugar ya conocido sigue sumando en el suyo")
    }

    @Test("ida y vuelta Codable, byte-estable")
    func codableRoundTripIsByteStable() throws {
        var funnel = OfferFunnel.empty
        for stage in OfferStage.allCases {
            funnel.record(stage, site: "offline.x2")
            funnel.record(stage, site: "double.wheel")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(funnel)
        let decoded = try JSONDecoder().decode(OfferFunnel.self, from: data)
        #expect(decoded == funnel)
        #expect(try encoder.encode(decoded) == data)
    }

    @Test("sincronizar: el máximo de cada contador, lugar por lugar")
    func resolveTakesMaxPerCounter() {
        var lhs = OfferFunnel.empty
        for _ in 1...3 { lhs.record(.shown, site: "offline.x2") }
        lhs.record(.completed, site: "offline.x2")
        var rhs = OfferFunnel.empty
        rhs.record(.shown, site: "offline.x2")
        for _ in 1...2 { rhs.record(.completed, site: "offline.x2") }
        rhs.record(.dismissed, site: "double.wheel")

        let merged = OfferFunnel.resolve(lhs, rhs)
        #expect(merged.counts(site: "offline.x2") == OfferFunnel.Counts(shown: 3, accepted: 0, completed: 2, unfilled: 0, dismissed: 0))
        #expect(merged.counts(site: "double.wheel")[.dismissed] == 1)
        #expect(merged == OfferFunnel.resolve(rhs, lhs), "conmutativo")
        #expect(OfferFunnel.resolve(merged, merged) == merged, "idempotente")
    }

    @Test("sincronizar con más de 64 lugares en la unión: idempotente, conmutativo y sin sumar a _other")
    func resolveOverTheCapIsIdempotent() {
        var lhs = OfferFunnel.empty
        for index in 0..<OfferFunnel.maxSites { lhs.record(.shown, site: "a.\(index)") }
        lhs.record(.shown, site: "a.extra")
        var rhs = OfferFunnel.empty
        for index in 0..<OfferFunnel.maxSites {
            rhs.record(.shown, site: "b.\(index)")
            rhs.record(.accepted, site: "b.\(index)")
        }
        rhs.record(.shown, site: "b.extra")
        rhs.record(.shown, site: "b.extra.2")

        let merged = OfferFunnel.resolve(lhs, rhs)
        #expect(merged.sites.count == 2 * OfferFunnel.maxSites + 1, "la unión entera, _other incluido")
        #expect(merged.counts(site: OfferFunnel.overflowSite)[.shown] == 2, "el máximo de los dos _other, no la suma")
        #expect(merged.counts(site: "b.63") == OfferFunnel.Counts(shown: 1, accepted: 1, completed: 0, unfilled: 0, dismissed: 0))
        #expect(OfferFunnel.resolve(merged, rhs) == merged, "idempotente contra el lado viejo")
        #expect(OfferFunnel.resolve(merged, lhs) == merged)
        #expect(OfferFunnel.resolve(rhs, merged) == merged)
        #expect(OfferFunnel.resolve(rhs, lhs) == merged, "conmutativo")
    }

    @Test("después de una unión sobre el tope, record no abre lugares nuevos")
    func recordAfterOversizedUnionGoesToOverflow() {
        var lhs = OfferFunnel.empty
        for index in 0..<OfferFunnel.maxSites { lhs.record(.shown, site: "a.\(index)") }
        var rhs = OfferFunnel.empty
        for index in 0..<OfferFunnel.maxSites { rhs.record(.shown, site: "b.\(index)") }
        var merged = OfferFunnel.resolve(lhs, rhs)
        merged.record(.shown, site: "nuevo")
        merged.record(.shown, site: "a.0")
        #expect(merged.sites["nuevo"] == nil)
        #expect(merged.counts(site: OfferFunnel.overflowSite)[.shown] == 1)
        #expect(merged.counts(site: "a.0")[.shown] == 2)
    }
}
