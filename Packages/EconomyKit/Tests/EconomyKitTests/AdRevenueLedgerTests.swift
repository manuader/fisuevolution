import Foundation
import Testing
@testable import EconomyKit

// MARK: - E15 C2: lo que pagó cada impresión, por formato

@Suite("AdRevenueLedger (E15)")
struct AdRevenueLedgerTests {
    private func impression(
        _ format: AdFormat = .rewarded,
        micros: Int64,
        currency: String = "USD",
        at: TimeInterval = 1000
    ) -> AdImpression {
        AdImpression(
            format: format, site: "ads.watch.double_earnings", valueMicros: micros,
            currency: currency, precision: .estimated, adSource: "Google", at: at
        )
    }

    @Test("una impresión suma count, total y máximo, y entra al anillo")
    func oneImpressionAggregates() {
        var ledger = AdRevenueLedger.empty
        ledger.record(impression(micros: 12_500))
        let stats = ledger.stats(.rewarded)
        #expect(stats.count == 1)
        #expect(stats.totalMicros == 12_500)
        #expect(stats.maxMicros == 12_500)
        #expect(stats.recent == [impression(micros: 12_500)])
        #expect(ledger.currency == "USD")
        #expect(ledger.stats(.interstitial) == .empty)
    }

    @Test("la 21.ª saca a la más vieja del anillo y los agregados cuentan las 21")
    func ringDropsOldestButAggregatesKeepCounting() {
        var ledger = AdRevenueLedger.empty
        for index in 1...21 {
            ledger.record(impression(micros: Int64(index) * 100, at: TimeInterval(index)))
        }
        let stats = ledger.stats(.rewarded)
        #expect(stats.recent.count == AdRevenueLedger.recentCapacity)
        #expect(stats.recent.first?.at == 2, "la 1.ª salió")
        #expect(stats.recent.last?.at == 21)
        #expect(stats.count == 21)
        #expect(stats.totalMicros == 23_100, "100 + 200 + … + 2100")
        #expect(stats.maxMicros == 2100)
        #expect(stats.meanMicros == 1100)
        #expect(ledger.recentMicros(format: .rewarded) == 1150, "(200 + … + 2100) / 20: el anillo, sin la 1.ª")
    }

    @Test("sin impresiones la media es 0, sin dividir por cero")
    func meanOfNothingIsZero() {
        let ledger = AdRevenueLedger.empty
        #expect(ledger.stats(.appOpen).meanMicros == 0)
        #expect(ledger.recentMicros(format: .appOpen) == 0)
        #expect(ledger.averageRewardedMicros == 0)
        #expect(ledger.maxMicros == 0)
    }

    @Test("otra moneda entra al anillo y a foreignCurrencyCount, no a los agregados")
    func foreignCurrencyStaysOutOfAggregates() {
        var ledger = AdRevenueLedger.empty
        ledger.record(impression(micros: 1000, currency: "USD"))
        ledger.record(impression(micros: 9_000_000, currency: "EUR"))
        let stats = ledger.stats(.rewarded)
        #expect(ledger.currency == "USD", "manda la primera")
        #expect(stats.recent.count == 2)
        #expect(stats.count == 1)
        #expect(stats.totalMicros == 1000)
        #expect(stats.maxMicros == 1000)
        #expect(ledger.foreignCurrencyCount == 1)
        #expect(ledger.recentMicros(format: .rewarded) == 1000, "el promedio del anillo mira sólo su moneda")
    }

    @Test("averageRewardedMicros sólo mira los rewarded; maxMicros mira todos")
    func shortcutsLookWhereTheySay() {
        var ledger = AdRevenueLedger.empty
        ledger.record(impression(.rewarded, micros: 2000))
        ledger.record(impression(.rewarded, micros: 4000))
        ledger.record(impression(.interstitial, micros: 50_000))
        ledger.record(impression(.appOpen, micros: 7000))
        #expect(ledger.averageRewardedMicros == 3000)
        #expect(ledger.maxMicros == 50_000)
        #expect(ledger.stats(.interstitial).count == 1)
    }

    @Test("ida y vuelta Codable, byte-estable")
    func codableRoundTripIsByteStable() throws {
        var ledger = AdRevenueLedger.empty
        for (index, format) in AdFormat.allCases.enumerated() {
            ledger.record(impression(format, micros: Int64(index + 1) * 333, at: TimeInterval(index)))
        }
        ledger.record(impression(micros: 5, currency: "ARS"))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(ledger)
        let decoded = try JSONDecoder().decode(AdRevenueLedger.self, from: data)
        #expect(decoded == ledger)
        #expect(try encoder.encode(decoded) == data)
    }

    @Test("sincronizar: por formato gana el lado con más impresiones, con su anillo")
    func resolveTakesTheFormatWithMoreCount() {
        var winner = AdRevenueLedger.empty
        winner.record(impression(.rewarded, micros: 100))
        winner.record(impression(.rewarded, micros: 100))
        winner.record(impression(.interstitial, micros: 900))
        var loser = AdRevenueLedger.empty
        for _ in 1...3 { loser.record(impression(.rewarded, micros: 10)) }
        loser.record(impression(.appOpen, micros: 70))

        let merged = AdRevenueLedger.resolve(winner: winner, loser: loser)
        #expect(merged.stats(.rewarded) == loser.stats(.rewarded))
        #expect(merged.stats(.interstitial) == winner.stats(.interstitial))
        #expect(merged.stats(.appOpen) == loser.stats(.appOpen))
        #expect(AdRevenueLedger.resolve(winner: winner, loser: winner) == winner, "idempotente")
        #expect(AdRevenueLedger.resolve(winner: .empty, loser: loser) == loser)
    }

    @Test("sincronizar con monedas distintas no mezcla agregados: queda el lado con más impresiones")
    func resolveAcrossCurrenciesKeepsOneSide() {
        var dollars = AdRevenueLedger.empty
        dollars.record(impression(micros: 100, currency: "USD"))
        var euros = AdRevenueLedger.empty
        euros.record(impression(.interstitial, micros: 100, currency: "EUR"))
        euros.record(impression(.appOpen, micros: 100, currency: "EUR"))
        #expect(AdRevenueLedger.resolve(winner: dollars, loser: euros) == euros)
        #expect(AdRevenueLedger.resolve(winner: euros, loser: dollars) == euros)
    }

    @Test("un formato o una precisión de un build futuro no tiran el ledger: lo conocido se conserva")
    func decodingToleratesUnknownFormatAndPrecision() throws {
        let json = """
        {
          "currency": "USD",
          "foreignCurrencyCount": 0,
          "formats": {
            "rewarded": {
              "count": 2, "totalMicros": 300, "maxMicros": 200,
              "recent": [
                {"format": "rewarded", "site": "wheel", "valueMicros": 100, "currency": "USD",
                 "precision": "estimated", "adSource": "Google", "at": 1},
                {"format": "rewarded", "site": "wheel", "valueMicros": 200, "currency": "USD",
                 "precision": "algoNuevo", "at": 2}
              ]
            },
            "nativeVideo": {
              "count": 1, "totalMicros": 50, "maxMicros": 50,
              "recent": [
                {"format": "nativeVideo", "site": "feed", "valueMicros": 50, "currency": "USD",
                 "precision": "precise", "at": 3},
                {"format": "rewarded", "site": "wheel", "valueMicros": 7, "currency": "USD",
                 "precision": "precise", "at": 4}
              ]
            }
          }
        }
        """
        let ledger = try JSONDecoder().decode(AdRevenueLedger.self, from: Data(json.utf8))
        let rewarded = ledger.stats(.rewarded)
        #expect(rewarded.count == 2)
        #expect(rewarded.totalMicros == 300)
        #expect(rewarded.recent.map(\.valueMicros) == [100, 200])
        #expect(rewarded.recent.last?.precision == .unknown, "la precisión nueva cae en .unknown")
        let future = try #require(ledger.formats["nativeVideo"])
        #expect(future.count == 1, "los agregados del formato nuevo se conservan")
        #expect(future.recent.map(\.at) == [4], "la impresión de formato desconocido se saltea, la otra queda")
        #expect(ledger.currency == "USD")
    }
}
