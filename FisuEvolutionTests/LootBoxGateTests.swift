import Foundation
import Testing
@testable import FisuEvolution

/// El azar con ORO se apaga en Bélgica y Australia (PLAN-v2 §2, loot boxes).
@Suite("El azar con ORO, por tienda")
struct LootBoxGateTests {
    private func bundledConfig() throws -> AdsRemoteConfig {
        let loader = AdsRemoteConfigLoader(
            cacheURL: FileManager.default.temporaryDirectory.appending(path: "e5-\(UUID().uuidString).json")
        )
        return try #require(loader.current()?.config)
    }

    @Test("Argentina sí; Bélgica y Australia no, escriban como escriban")
    func restrictedStorefronts() throws {
        let config = try bundledConfig()
        #expect(Set(config.restrictedStorefronts) == ["BEL", "AUS"])
        #expect(LootBoxGate.allows(countryCode: "ARG", config: config))
        #expect(LootBoxGate.allows(countryCode: "USA", config: config))
        #expect(!LootBoxGate.allows(countryCode: "BEL", config: config))
        #expect(!LootBoxGate.allows(countryCode: "aus", config: config))
    }

    @Test("sin tienda conocida, no: mejor no ofrecer que ofrecer donde está prohibido")
    func unknownStorefrontFailsClosed() throws {
        let config = try bundledConfig()
        #expect(!LootBoxGate.allows(countryCode: nil, config: config))
        #expect(!LootBoxGate.allows(countryCode: "", config: config))
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
