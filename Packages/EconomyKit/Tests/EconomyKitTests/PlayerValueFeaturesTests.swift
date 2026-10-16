import Foundation
import Testing
@testable import EconomyKit

// MARK: - 2.1 E15 F6 T2: las features del modelo v2
//
// Este test es el contrato con `Tools/player-value-model/train.py` (`FEATURES`): mismos nombres, mismo
// orden. Si uno cambia, cambian los dos y sube `PlayerValueFeatures.version`.

@Suite("PlayerValueFeatures (2.1 F6)")
struct PlayerValueFeaturesTests {
    private static let contract = [
        "country_tier", "device_tier", "sessions_7d", "mean_session_seconds", "rewarded_count",
        "avg_rewarded_micros", "has_purchased", "offers_seen", "prestige_count",
    ]

    private func tables() throws -> PlayerValueTables {
        let tables = try samplePlayerValueTables()
        try tables.validate()
        return tables
    }

    private func model(features: [String]) -> TreeEnsemble {
        TreeEnsemble(
            version: TreeEnsemble.formatVersion, features: features, baseScore: 0, link: .identity,
            trees: [.init(left: [-1], right: [-1], feature: [-1], threshold: [0], defaultLeft: [true], value: [0])]
        )
    }

    private func fullInputs() -> PlayerValueInputs {
        PlayerValueInputs(
            storefront: "usa", deviceModel: "iPhone16,2", rewardedCount: 6, averageRewardedMicros: 12_000,
            hasPurchased: true, sessionsLast7Days: 9, meanSessionSeconds: 300,
            offersSeenLast7Days: 4, prestigesLast7Days: 2
        )
    }

    @Test("los nombres y el orden son los del contrato, versionados")
    func namesAndOrderAreTheContract() {
        #expect(PlayerValueFeatures.names == Self.contract)
        #expect(PlayerValueFeatures.version == "pvf-1")
    }

    @Test("el orden coincide con FEATURES de train.py")
    func matchesTrainScript() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let script = try String(contentsOf: root.appending(path: "Tools/player-value-model/train.py"), encoding: .utf8)
        let start = try #require(script.range(of: "FEATURES = ["))
        let end = try #require(script.range(of: "]", range: start.upperBound..<script.endIndex))
        let names = script[start.upperBound..<end.lowerBound]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            .filter { !$0.isEmpty }
        #expect(names == PlayerValueFeatures.names)
    }

    @Test("cada feature sale de las entradas y de las tablas")
    func valuesFromInputsAndTables() throws {
        let features = PlayerValueFeatures.features(from: fullInputs(), tables: try tables())
        #expect(Set(features.keys) == Set(Self.contract))
        #expect(features["country_tier"] == 1, "USA es tier 1 (en minúsculas también)")
        #expect(features["device_tier"] == 1, "iPhone16, es tier 1")
        #expect(features["sessions_7d"] == 9)
        #expect(features["mean_session_seconds"] == 300)
        #expect(features["rewarded_count"] == 6)
        #expect(features["avg_rewarded_micros"] == 12_000)
        #expect(features["has_purchased"] == 1)
        #expect(features["offers_seen"] == 4)
        #expect(features["prestige_count"] == 2)
    }

    @Test("sin datos: tiers por defecto, conteos en 0 y promedios en NaN como el NULL del export")
    func emptyInputs() throws {
        let tables = try tables()
        let features = PlayerValueFeatures.features(from: PlayerValueInputs(averageRewardedMicros: 9_000), tables: tables)
        #expect(features["country_tier"] == Double(tables.defaultCountryTier))
        #expect(features["device_tier"] == Double(tables.defaultDeviceTier))
        #expect(features["sessions_7d"] == 0)
        #expect(features["mean_session_seconds"]?.isNaN == true)
        #expect(features["rewarded_count"] == 0)
        #expect(features["avg_rewarded_micros"]?.isNaN == true, "sin videos no hay promedio aunque venga un número")
        #expect(features["has_purchased"] == 0)
        #expect(features["offers_seen"] == 0)
        #expect(features["prestige_count"] == 0)
    }

    @Test("negativos y no finitos no pasan como valores")
    func insaneInputs() throws {
        var inputs = PlayerValueInputs(rewardedCount: -3, sessionsLast7Days: -1, meanSessionSeconds: .infinity)
        inputs.offersSeenLast7Days = -2
        inputs.prestigesLast7Days = -5
        let features = PlayerValueFeatures.features(from: inputs, tables: try tables())
        #expect(features["rewarded_count"] == 0)
        #expect(features["sessions_7d"] == 0)
        #expect(features["mean_session_seconds"]?.isNaN == true)
        #expect(features["avg_rewarded_micros"]?.isNaN == true)
        #expect(features["offers_seen"] == 0)
        #expect(features["prestige_count"] == 0)
    }

    @Test("el vector sigue el orden del modelo, no el del contrato")
    func vectorFollowsModelOrder() throws {
        let features = PlayerValueFeatures.features(from: fullInputs(), tables: try tables())
        let reordered = model(features: ["prestige_count", "rewarded_count", "country_tier"])
        #expect(PlayerValueFeatures.vector(for: reordered, from: features) == [2, 6, 1])
        #expect(PlayerValueFeatures.supports(reordered))

        let full = model(features: Self.contract)
        #expect(PlayerValueFeatures.vector(for: full, from: features) == [1, 1, 9, 300, 6, 12_000, 1, 4, 2])
    }

    @Test("una feature que el modelo pide y no existe deja el modelo sin vector")
    func unknownFeatureMeansNoVector() throws {
        let features = PlayerValueFeatures.features(from: fullInputs(), tables: try tables())
        let foreign = model(features: ["country_tier", "vibrate_switch"])
        #expect(PlayerValueFeatures.vector(for: foreign, from: features) == nil)
        #expect(!PlayerValueFeatures.supports(foreign))
    }
}
