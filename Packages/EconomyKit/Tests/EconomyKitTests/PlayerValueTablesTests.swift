import Foundation
import Testing
@testable import EconomyKit

// MARK: - 2.1 E15 F1 C2: las tablas del valor por jugador

/// El ejemplo de C2 tal cual (sin la clave «…» de país, que en el plan es un comodín de texto).
let playerValueTablesSampleJSON = """
{
  "version": "seed-2026-10-16",
  "countryTier": {"USA": 1, "GBR": 1, "ARG": 3, "ESP": 2},
  "defaultCountryTier": 3,
  "tierMicros": {"1": 18000, "2": 6000, "3": 1500},
  "deviceTier": {"iPhone17,": 1, "iPhone16,": 1, "iPhone15,": 2, "iPhone14,": 2, "iPad": 2},
  "defaultDeviceTier": 3,
  "minOwnImpressions": 5,
  "ownWeight": 0.7,
  "engagement": {"sessionsFor1": 14, "secondsFor1": 900},
  "weights": {"value": 0.6, "engagement": 0.25, "purchase": 0.15},
  "thresholds": {"mid": 0.35, "high": 0.7},
  "hysteresis": 0.05
}
"""

func samplePlayerValueTables() throws -> PlayerValueTables {
    try JSONDecoder().decode(PlayerValueTables.self, from: Data(playerValueTablesSampleJSON.utf8))
}

@Suite("PlayerValueTables (2.1 F1)")
struct PlayerValueTablesTests {
    @Test("el ejemplo de C2 decodifica y valida")
    func sampleDecodesAndValidates() throws {
        let tables = try samplePlayerValueTables()
        try tables.validate()
        #expect(tables.version == "seed-2026-10-16")
        #expect(tables.countryTier["ARG"] == 3)
        #expect(tables.tierMicros["1"] == 18000)
        #expect(tables.deviceTier["iPhone16,"] == 1)
        #expect(tables.minOwnImpressions == 5)
        #expect(tables.ownWeight == 0.7)
        #expect(tables.engagement == .init(sessionsFor1: 14, secondsFor1: 900))
        #expect(tables.weights == .init(value: 0.6, engagement: 0.25, purchase: 0.15))
        #expect(tables.thresholds == .init(mid: 0.35, high: 0.7))
        #expect(tables.hysteresis == 0.05)
    }

    @Test("ida y vuelta por JSON da las mismas tablas")
    func roundTrip() throws {
        let tables = try samplePlayerValueTables()
        let data = try JSONEncoder().encode(tables)
        #expect(try JSONDecoder().decode(PlayerValueTables.self, from: data) == tables)
    }

    @Test("pesos que no suman 1 invalidan el archivo")
    func weightsMustSumToOne() throws {
        var tables = try samplePlayerValueTables()
        tables.weights.purchase = 0.2
        #expect(throws: PlayerValueTables.ValidationError.self) { try tables.validate() }
        tables.weights.purchase = 0.1505
        try tables.validate()
    }

    @Test("un peso negativo invalida aunque la suma dé 1")
    func negativeWeightRejected() throws {
        var tables = try samplePlayerValueTables()
        tables.weights = .init(value: 1.1, engagement: 0.05, purchase: -0.15)
        #expect(throws: PlayerValueTables.ValidationError.negativeWeight("purchase")) { try tables.validate() }
    }

    @Test("mid ≥ high, mid ≤ 0 o high ≥ 1 invalidan")
    func thresholdsMustBeOrdered() throws {
        var tables = try samplePlayerValueTables()
        tables.thresholds = .init(mid: 0.7, high: 0.7)
        #expect(throws: PlayerValueTables.ValidationError.badThresholds) { try tables.validate() }
        tables.thresholds = .init(mid: 0.8, high: 0.7)
        #expect(throws: PlayerValueTables.ValidationError.badThresholds) { try tables.validate() }
        tables.thresholds = .init(mid: 0, high: 0.7)
        #expect(throws: PlayerValueTables.ValidationError.badThresholds) { try tables.validate() }
        tables.thresholds = .init(mid: 0.35, high: 1)
        #expect(throws: PlayerValueTables.ValidationError.badThresholds) { try tables.validate() }
        tables.thresholds = .init(mid: .nan, high: 0.7)
        #expect(throws: PlayerValueTables.ValidationError.badThresholds) { try tables.validate() }
    }

    @Test("un país que no es alfa-3 en mayúsculas invalida")
    func countryCodeMustBeAlpha3() throws {
        for bad in ["ar", "arg", "AR", "ARGE", "A1G", "ÁRG"] {
            var tables = try samplePlayerValueTables()
            tables.countryTier[bad] = 3
            #expect(throws: PlayerValueTables.ValidationError.badCountryCode(bad)) { try tables.validate() }
        }
    }

    @Test("un país con un tier sin precio invalida")
    func countryTierMustHaveMicros() throws {
        var tables = try samplePlayerValueTables()
        tables.countryTier["BRA"] = 4
        #expect(throws: PlayerValueTables.ValidationError.unknownCountryTier("BRA")) { try tables.validate() }
        tables = try samplePlayerValueTables()
        tables.defaultCountryTier = 9
        #expect(throws: PlayerValueTables.ValidationError.unknownCountryTier("defaultCountryTier")) {
            try tables.validate()
        }
    }

    @Test("tierMicros en 0 o negativo invalida")
    func tierMicrosMustBePositive() throws {
        var tables = try samplePlayerValueTables()
        tables.tierMicros["3"] = 0
        #expect(throws: PlayerValueTables.ValidationError.nonPositiveTierMicros("3")) { try tables.validate() }
        tables.tierMicros["3"] = -1
        #expect(throws: PlayerValueTables.ValidationError.nonPositiveTierMicros("3")) { try tables.validate() }
    }

    @Test("una clave de tier que no es un entero ≥ 1 invalida, y sin tier 1 no hay techo")
    func tierKeysAndTopTier() throws {
        var tables = try samplePlayerValueTables()
        tables.tierMicros["x"] = 100
        #expect(throws: PlayerValueTables.ValidationError.badTierKey("x")) { try tables.validate() }
        tables = try samplePlayerValueTables()
        tables.tierMicros["01"] = 100
        #expect(throws: PlayerValueTables.ValidationError.badTierKey("01")) { try tables.validate() }
        tables = try samplePlayerValueTables()
        tables.tierMicros["1"] = nil
        tables.countryTier = [:]
        #expect(throws: PlayerValueTables.ValidationError.missingTopTier) { try tables.validate() }
    }

    @Test("histéresis fuera de [0, 0,2] invalida")
    func hysteresisRange() throws {
        var tables = try samplePlayerValueTables()
        tables.hysteresis = 0.3
        #expect(throws: PlayerValueTables.ValidationError.outOfRange("hysteresis")) { try tables.validate() }
        tables.hysteresis = -0.01
        #expect(throws: PlayerValueTables.ValidationError.outOfRange("hysteresis")) { try tables.validate() }
        tables.hysteresis = 0
        try tables.validate()
        tables.hysteresis = 0.2
        try tables.validate()
    }

    @Test("ownWeight fuera de [0, 1] invalida")
    func ownWeightRange() throws {
        var tables = try samplePlayerValueTables()
        tables.ownWeight = 1.2
        #expect(throws: PlayerValueTables.ValidationError.outOfRange("ownWeight")) { try tables.validate() }
        tables.ownWeight = .nan
        #expect(throws: PlayerValueTables.ValidationError.outOfRange("ownWeight")) { try tables.validate() }
    }

    @Test("tiers de aparato fuera de 1…3, engagement en 0 y versión que no es token invalidan")
    func otherRules() throws {
        var tables = try samplePlayerValueTables()
        tables.deviceTier["iPod"] = 4
        #expect(throws: PlayerValueTables.ValidationError.badDeviceTier("iPod")) { try tables.validate() }

        tables = try samplePlayerValueTables()
        tables.engagement.sessionsFor1 = 0
        #expect(throws: PlayerValueTables.ValidationError.outOfRange("engagement.sessionsFor1")) {
            try tables.validate()
        }

        tables = try samplePlayerValueTables()
        tables.minOwnImpressions = 0
        #expect(throws: PlayerValueTables.ValidationError.outOfRange("minOwnImpressions")) { try tables.validate() }

        for bad in ["", "con espacio", String(repeating: "v", count: 33)] {
            tables = try samplePlayerValueTables()
            tables.version = bad
            #expect(throws: PlayerValueTables.ValidationError.badVersion) { try tables.validate() }
        }
    }

    @Test("una clave que falta no decodifica: el archivo no se usa")
    func missingKeyFailsDecoding() {
        let broken = playerValueTablesSampleJSON.replacingOccurrences(of: "\"hysteresis\": 0.05", with: "\"x\": 0")
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(PlayerValueTables.self, from: Data(broken.utf8))
        }
    }

    @Test("un segmento desconocido se lee como base; el orden es base < low < mid < high")
    func segmentDecodingAndOrder() throws {
        let decoded = try JSONDecoder().decode([PlayerSegment].self, from: Data(#"["high","vip","low"]"#.utf8))
        #expect(decoded == [.high, .base, .low])
        #expect(PlayerSegment.allCases.sorted() == [.base, .low, .mid, .high])
        #expect(PlayerSegment.low < .mid && PlayerSegment.mid < .high && PlayerSegment.base < .low)
    }
}
