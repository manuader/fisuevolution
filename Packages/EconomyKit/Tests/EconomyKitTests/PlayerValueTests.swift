import Foundation
import Testing
@testable import EconomyKit

// MARK: - 2.1 E15 F1 C1: el valor estimado y el segmento de cada jugador

@Suite("PlayerValue (2.1 F1)")
struct PlayerValueTests {
    private func validTables() throws -> PlayerValueTables {
        let tables = try samplePlayerValueTables()
        try tables.validate()
        return tables
    }

    private func isClose(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 1e-9
    }

    // (a)
    @Test("sin impresiones propias usa el tier del país por el del aparato")
    func countryTimesDeviceWithoutOwnImpressions() throws {
        let tables = try validTables()
        func expected(_ storefront: String?, _ model: String?) -> Int64 {
            PlayerValue.expectedMicrosPerVideo(
                PlayerValueInputs(storefront: storefront, deviceModel: model), tables: tables
            )
        }
        #expect(expected("ARG", "iPhone16,2") == 1500, "tier 3 × aparato 1")
        #expect(expected("ARG", "iPhone14,5") == 1200, "tier 3 × 0,8")
        #expect(expected("ARG", "Mac14,2") == 900, "aparato desconocido: tier 3 × 0,6")
        #expect(expected("USA", "iPhone15,1") == 14400, "tier 1 × 0,8")
        #expect(expected("USA", nil) == 10800, "sin modelo: tier por defecto (3) × 0,6")
    }

    // (b)
    @Test("con minOwnImpressions mezcla el promedio propio con el del país por ownWeight")
    func blendsOwnAverageFromMinImpressions() throws {
        let tables = try validTables()
        var inputs = PlayerValueInputs(storefront: "USA", rewardedCount: 5, averageRewardedMicros: 10_000)
        #expect(PlayerValue.expectedMicrosPerVideo(inputs, tables: tables) == 12_400, "0,7 × 10 000 + 0,3 × 18 000")
        inputs.rewardedCount = 4
        #expect(PlayerValue.expectedMicrosPerVideo(inputs, tables: tables) == 10_800, "con 4 todavía no: país × aparato")
    }

    // (c)
    @Test("el tier del aparato sale del prefijo más largo")
    func longestPrefixWins() throws {
        var tables = try validTables()
        tables.deviceTier = ["iPhone1": 3, "iPhone16,": 1, "iPhone": 2]
        try tables.validate()
        #expect(tables.resolvedDeviceTier(model: "iPhone16,2") == 1, "iPhone16, le gana a iPhone1 y a iPhone")
        #expect(tables.resolvedDeviceTier(model: "iPhone12,1") == 3, "iPhone1 le gana a iPhone")
        #expect(tables.resolvedDeviceTier(model: "iPhone9,1") == 2)
        #expect(tables.resolvedDeviceTier(model: "iPad13,4") == tables.defaultDeviceTier)
        #expect(tables.resolvedDeviceTier(model: "") == tables.defaultDeviceTier)
        #expect(tables.resolvedDeviceTier(model: nil) == tables.defaultDeviceTier)
    }

    // (d)
    @Test("un país desconocido o ausente usa defaultCountryTier")
    func unknownCountryUsesDefault() throws {
        let tables = try validTables()
        #expect(tables.resolvedCountryTier(storefront: "XYZ") == 3)
        #expect(tables.resolvedCountryTier(storefront: nil) == 3)
        #expect(tables.resolvedCountryTier(storefront: "usa") == 1, "la tienda se compara en mayúsculas")
        #expect(tables.countryMicros(for: "XYZ") == 1500)
    }

    @Test("el score suma valor, engagement y compra con sus pesos")
    func scoreFormula() throws {
        let tables = try validTables()
        let top = PlayerValueInputs(
            storefront: "USA", deviceModel: "iPhone16,2", hasPurchased: true,
            sessionsLast7Days: 30, meanSessionSeconds: 5000
        )
        let topEstimate = PlayerValue.evaluate(top, tables: tables, previous: nil)
        #expect(topEstimate.expectedMicrosPerVideo == 18_000)
        #expect(isClose(topEstimate.score, 1), "todo saturado en 1")
        #expect(topEstimate.segment == .high)
        #expect(topEstimate.tablesVersion == "seed-2026-10-16")

        let quiet = PlayerValueInputs(storefront: "ARG", deviceModel: "iPhone16,2", sessionsLast7Days: 7)
        let quietEstimate = PlayerValue.evaluate(quiet, tables: tables, previous: nil)
        // 0,6 × 1500/18 000 + 0,25 × (7/14 + 0) / 2 = 0,05 + 0,0625
        #expect(isClose(quietEstimate.score, 0.1125))
        #expect(quietEstimate.segment == .low)
    }

    // (e)
    @Test("umbrales sin anterior: 0,34 → low, 0,35 → mid, 0,70 → high")
    func thresholds() throws {
        let tables = try validTables()
        #expect(PlayerValue.segment(forScore: 0.34, tables: tables, previous: nil) == .low)
        #expect(PlayerValue.segment(forScore: 0.35, tables: tables, previous: nil) == .mid)
        #expect(PlayerValue.segment(forScore: 0.69, tables: tables, previous: nil) == .mid)
        #expect(PlayerValue.segment(forScore: 0.70, tables: tables, previous: nil) == .high)
        #expect(PlayerValue.segment(forScore: 0.70, tables: tables, previous: .base) == .high, "base = sin anterior")
    }

    // (f)
    @Test("histéresis: hay que pasar el umbral por 0,05 para subir y para bajar")
    func hysteresis() throws {
        let tables = try validTables()
        #expect(PlayerValue.segment(forScore: 0.72, tables: tables, previous: .mid) == .mid, "umbral 0,75")
        #expect(PlayerValue.segment(forScore: 0.76, tables: tables, previous: .mid) == .high)
        #expect(PlayerValue.segment(forScore: 0.66, tables: tables, previous: .high) == .high, "para bajar, < 0,65")
        #expect(PlayerValue.segment(forScore: 0.64, tables: tables, previous: .high) == .mid)
        #expect(PlayerValue.segment(forScore: 0.31, tables: tables, previous: .mid) == .mid, "para bajar, < 0,30")
        #expect(PlayerValue.segment(forScore: 0.29, tables: tables, previous: .mid) == .low)
        #expect(PlayerValue.segment(forScore: 0.38, tables: tables, previous: .low) == .low, "para subir, ≥ 0,40")
        #expect(PlayerValue.segment(forScore: 0.41, tables: tables, previous: .low) == .mid)
    }

    // (g)
    @Test("nunca salta dos escalones en una evaluación")
    func atMostOneStep() throws {
        let tables = try validTables()
        #expect(PlayerValue.segment(forScore: 0.95, tables: tables, previous: .low) == .mid)
        #expect(PlayerValue.segment(forScore: 0, tables: tables, previous: .high) == .mid)
        let rich = PlayerValueInputs(
            storefront: "USA", deviceModel: "iPhone16,2", hasPurchased: true,
            sessionsLast7Days: 30, meanSessionSeconds: 5000
        )
        #expect(PlayerValue.evaluate(rich, tables: tables, previous: .low).segment == .mid)
        #expect(PlayerValue.evaluate(rich, tables: tables, previous: .mid).segment == .high)
    }

    // (h)
    @Test("nunca devuelve base, con cualquier score y cualquier anterior")
    func neverBase() throws {
        let tables = try validTables()
        let previous: [PlayerSegment?] = [nil] + PlayerSegment.allCases.map(Optional.some)
        for step in 0...100 {
            let score = Double(step) / 100
            for before in previous {
                #expect(PlayerValue.segment(forScore: score, tables: tables, previous: before) != .base)
            }
        }
        for weird in [-1, .nan, .infinity, -.infinity, 2] as [Double] {
            #expect(PlayerValue.segment(forScore: weird, tables: tables, previous: nil) != .base)
        }
    }

    // (i)
    @Test("determinista: mismas entradas, mismo resultado")
    func deterministic() throws {
        let tables = try validTables()
        let inputs = PlayerValueInputs(
            storefront: "GBR", deviceModel: "iPhone15,3", rewardedCount: 12, averageRewardedMicros: 9000,
            recentRewardedMicros: 11_000, hasPurchased: false, sessionsLast7Days: 9, meanSessionSeconds: 420,
            videosWatchedEver: 40
        )
        let first = PlayerValue.evaluate(inputs, tables: tables, previous: .mid)
        for _ in 0..<20 {
            #expect(PlayerValue.evaluate(inputs, tables: tables, previous: .mid) == first)
        }
    }

    // (j)
    @Test("entradas absurdas (negativos, NaN, infinitos) valen 0 y no rompen")
    func absurdInputsAreZero() throws {
        let tables = try validTables()
        let zero = PlayerValueInputs(storefront: "ARG", deviceModel: "iPhone16,2")
        let absurd = PlayerValueInputs(
            storefront: "ARG", deviceModel: "iPhone16,2", rewardedCount: -3, averageRewardedMicros: -100,
            recentRewardedMicros: -5, sessionsLast7Days: -5, meanSessionSeconds: .nan, videosWatchedEver: -1
        )
        #expect(PlayerValue.evaluate(absurd, tables: tables, previous: nil)
            == PlayerValue.evaluate(zero, tables: tables, previous: nil))

        var infinite = zero
        infinite.meanSessionSeconds = .infinity
        #expect(PlayerValue.evaluate(infinite, tables: tables, previous: nil)
            == PlayerValue.evaluate(zero, tables: tables, previous: nil))

        let negativeOwn = PlayerValueInputs(storefront: "USA", rewardedCount: 10, averageRewardedMicros: -50_000)
        #expect(PlayerValue.expectedMicrosPerVideo(negativeOwn, tables: tables) == 5400, "0,7 × 0 + 0,3 × 18 000")

        let huge = PlayerValueInputs(storefront: "USA", rewardedCount: .max, averageRewardedMicros: .max,
                                     sessionsLast7Days: .max, meanSessionSeconds: .greatestFiniteMagnitude)
        let estimate = PlayerValue.evaluate(huge, tables: tables, previous: nil)
        #expect(estimate.expectedMicrosPerVideo > 0)
        #expect(estimate.score.isFinite && estimate.score <= 1)
    }
}
