import Foundation
import Testing
@testable import FisuEvolution

/// El azar con ORO se apaga en Bélgica y Australia (PLAN-v2 §2, loot boxes).
@Suite("El azar con ORO, por tienda")
struct LootBoxGateTests {
    @Test("Argentina sí; Bélgica y Australia no, escriban como escriban")
    func restrictedStorefronts() {
        let restricted = ["BEL", "AUS"]
        #expect(LootBoxGate.allows(countryCode: "ARG", restricted: restricted))
        #expect(!LootBoxGate.allows(countryCode: "BEL", restricted: restricted))
        #expect(!LootBoxGate.allows(countryCode: "aus", restricted: restricted))
    }

    @Test("sin tienda conocida, no: mejor no ofrecer que ofrecer donde está prohibido")
    func unknownStorefrontFailsClosed() {
        #expect(!LootBoxGate.allows(countryCode: nil, restricted: []))
        #expect(!LootBoxGate.allows(countryCode: "", restricted: []))
        #expect(!LootBoxGate.allows(countryCode: nil, restricted: ["BEL", "AUS"]))
    }

    @Test("sin lista de restringidas, cualquier tienda conocida pasa")
    func emptyRestrictionList() {
        #expect(LootBoxGate.allows(countryCode: "BEL", restricted: []))
    }

    @Test("la config que viaja en el bundle apaga Bélgica y Australia")
    func theBundledConfigRestricts() throws {
        let loader = AdsRemoteConfigLoader(
            cacheURL: FileManager.default.temporaryDirectory.appending(path: "e5-\(UUID().uuidString).json")
        )
        let config = try #require(loader.current()?.config)
        #expect(Set(config.restrictedStorefronts) == ["BEL", "AUS"])
        #expect(!LootBoxGate.allows(countryCode: "BEL", restricted: config.restrictedStorefronts))
        #expect(LootBoxGate.allows(countryCode: "USA", restricted: config.restrictedStorefronts))
    }

    @Test("sin config en disco (ni caché ni bundle) la respuesta es no")
    func noConfigFailsClosed() async {
        let loader = AdsRemoteConfigLoader(
            cacheURL: FileManager.default.temporaryDirectory.appending(path: "e5-\(UUID().uuidString).json"),
            bundledURL: nil
        )
        #expect(await !LootBoxGate.current(loader: loader))
    }
}
