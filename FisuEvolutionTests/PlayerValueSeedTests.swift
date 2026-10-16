import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// `player_value.json` es la tabla SEMILLA del valor por jugador (2.1 E15 F1, decisión V5: sin
/// exportes, sólo tiers públicos de eCPM de rewarded en iOS). La reemplaza F7-T4 con el
/// `networkReport` propio; hasta entonces sólo tiene que decodificar, validar y decir lo obvio.
@Suite("Tabla semilla de valor por jugador")
struct PlayerValueSeedTests {
    private func seed() throws -> PlayerValueTables {
        let url = try #require(Bundle.main.url(forResource: "player_value", withExtension: "json"))
        return try JSONDecoder().decode(PlayerValueTables.self, from: Data(contentsOf: url))
    }

    @Test("el archivo del bundle decodifica y valida")
    func decodesAndValidates() throws {
        let tables = try seed()
        try tables.validate()
        #expect(tables.version == "seed-2026-10-16")
    }

    @Test("Estados Unidos es tier 1 y Argentina tier 3")
    func countryTiers() throws {
        let tables = try seed()
        #expect(tables.resolvedCountryTier(storefront: "USA") == 1)
        #expect(tables.resolvedCountryTier(storefront: "ESP") == 2)
        #expect(tables.resolvedCountryTier(storefront: "ARG") == 3)
        #expect(tables.resolvedCountryTier(storefront: "ZZZ") == tables.defaultCountryTier)
    }

    @Test("un iPhone17,1 es tier 1, uno de dos años antes tier 2 y uno viejo el de por defecto")
    func deviceTiers() throws {
        let tables = try seed()
        #expect(tables.resolvedDeviceTier(model: "iPhone17,1") == 1)
        #expect(tables.resolvedDeviceTier(model: "iPhone15,2") == 2)
        #expect(tables.resolvedDeviceTier(model: "iPhone12,1") == tables.defaultDeviceTier)
        #expect(tables.resolvedDeviceTier(model: "iPad13,1") == 2)
    }

    @Test("todas las claves de país son alfa-3 en mayúsculas y los tiers existen en tierMicros")
    func countryKeysAreAlpha3() throws {
        let tables = try seed()
        for (code, tier) in tables.countryTier {
            #expect(code.count == 3 && code.allSatisfy { $0.isASCII && $0.isUppercase && $0.isLetter }, "\(code)")
            #expect(tables.tierMicros[String(tier)] != nil, "\(code) apunta a un tier sin precio")
        }
    }
}
