import Foundation
import Testing
@testable import EconomyKit

// MARK: - 2.1 E15 F6 T2: el valor estimado con modelo
//
// El modelo de prueba es un tocón con link identity: rewarded_count < 5 → 1.0; si no → 3.0
// (NaN → izquierda). Cuantiles [0.5, 1.5, 2.5, 3.5]: predicción 1.0 → percentil 0.25 (low);
// 3.0 → 0.75 (high, con los umbrales 0.35 / 0.7 del ejemplo de C2).

@Suite("PlayerValue con modelo (2.1 F6)")
struct PlayerValueModelTests {
    private static let quantiles = [0.5, 1.5, 2.5, 3.5]

    private func tables(modelThresholds: [Double]? = quantiles) throws -> PlayerValueTables {
        var tables = try samplePlayerValueTables()
        tables.modelThresholds = modelThresholds
        try tables.validate()
        return tables
    }

    private func stump(feature: String = "rewarded_count", low: Double = 1, high: Double = 3, link: TreeEnsemble.Link = .identity) throws -> TreeEnsemble {
        let model = TreeEnsemble(
            version: TreeEnsemble.formatVersion, features: ["country_tier", feature], baseScore: 0, link: link,
            trees: [.init(left: [1, -1, -1], right: [2, -1, -1], feature: [1, -1, -1], threshold: [5, 0, 0],
                          defaultLeft: [true, true, true], value: [0, low, high])]
        )
        try model.validate()
        return model
    }

    private func inputs(rewarded: Int) -> PlayerValueInputs {
        PlayerValueInputs(storefront: "USA", deviceModel: "iPhone16,2", rewardedCount: rewarded, averageRewardedMicros: 9_000)
    }

    @Test("sin modelo da exactamente lo de las reglas")
    func noModelIsRules() throws {
        let tables = try tables()
        for previous in [nil, PlayerSegment.low, .mid, .high] {
            let input = inputs(rewarded: 7)
            let rules = PlayerValue.evaluate(input, tables: tables, previous: previous)
            #expect(PlayerValue.evaluate(input, tables: tables, model: nil, previous: previous) == rules)
            #expect(rules.source == .rules)
        }
    }

    @Test("con modelo el score es el percentil de la predicción y el segmento sale de él")
    func modelScoreIsPercentile() throws {
        let tables = try tables()
        let model = try stump()

        let low = PlayerValue.evaluate(inputs(rewarded: 2), tables: tables, model: model, previous: nil)
        #expect(low.source == .model)
        #expect(low.score == 0.25)
        #expect(low.segment == .low)
        #expect(low.tablesVersion == tables.version)

        let high = PlayerValue.evaluate(inputs(rewarded: 6), tables: tables, model: model, previous: nil)
        #expect(high.score == 0.75)
        #expect(high.segment == .high)
        #expect(high.expectedMicrosPerVideo == PlayerValue.expectedMicrosPerVideo(inputs(rewarded: 6), tables: tables),
                "el valor por video sigue siendo el de las reglas")
    }

    @Test("con modelo valen la histéresis y el tope de un escalón")
    func modelKeepsHysteresisAndStep() throws {
        let estimate = PlayerValue.evaluate(inputs(rewarded: 6), tables: try tables(), model: try stump(), previous: .low)
        #expect(estimate.score == 0.75)
        #expect(estimate.segment == .mid, "de low sube un solo escalón")
    }

    @Test("NaN en una feature va por default_left, como en el entrenamiento")
    func nanGoesDefaultLeft() throws {
        let model = try stump(feature: "avg_rewarded_micros", low: 1, high: 3)
        let estimate = PlayerValue.evaluate(inputs(rewarded: 0), tables: try tables(), model: model, previous: nil)
        #expect(estimate.source == .model)
        #expect(estimate.score == 0.25, "sin videos el promedio es NaN → izquierda → 1.0")
    }

    @Test("sin modelThresholds, o con unos inservibles, se usan las reglas")
    func badThresholdsFallBack() throws {
        let model = try stump()
        for thresholds in [nil, [], [2.0, 1.0], [0.5, .nan], [.infinity]] as [[Double]?] {
            let tables = try tables(modelThresholds: thresholds)
            let input = inputs(rewarded: 6)
            let estimate = PlayerValue.evaluate(input, tables: tables, model: model, previous: nil)
            #expect(estimate == PlayerValue.evaluate(input, tables: tables, previous: nil))
            #expect(estimate.source == .rules)
        }
    }

    @Test("un modelo que pide una feature que no existe cae a las reglas")
    func unknownFeatureFallsBack() throws {
        let tables = try tables()
        let model = try stump(feature: "vibrate_switch")
        let input = inputs(rewarded: 6)
        #expect(PlayerValue.evaluate(input, tables: tables, model: model, previous: .mid)
            == PlayerValue.evaluate(input, tables: tables, previous: .mid))
    }

    @Test("una predicción no finita cae a las reglas")
    func nonFinitePredictionFallsBack() throws {
        let tables = try tables()
        let model = try stump(low: 1000, high: 1000, link: .expm1)
        let input = inputs(rewarded: 6)
        #expect(PlayerValue.modelScore(input, tables: tables, model: model) == nil)
        #expect(PlayerValue.evaluate(input, tables: tables, model: model, previous: nil).source == .rules)
    }

    @Test("el percentil: debajo de todo 0, el empate cuenta, arriba de todo 1")
    func percentileEdges() {
        let q = Self.quantiles
        #expect(PlayerValue.percentile(0.1, among: q) == 0)
        #expect(PlayerValue.percentile(0.5, among: q) == 0.25)
        #expect(PlayerValue.percentile(2.0, among: q) == 0.5)
        #expect(PlayerValue.percentile(3.5, among: q) == 1)
        #expect(PlayerValue.percentile(99, among: q) == 1)
        #expect(PlayerValue.percentile(1, among: []) == 0)
    }

    @Test("modelThresholds es opcional en C2: sin la clave decodifica nil, con ella ida y vuelta")
    func modelThresholdsIsOptional() throws {
        #expect(try samplePlayerValueTables().modelThresholds == nil)
        let tables = try tables()
        let data = try JSONEncoder().encode(tables)
        #expect(try JSONDecoder().decode(PlayerValueTables.self, from: data).modelThresholds == Self.quantiles)
    }
}
