import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// De lo que avisa el `paidEventHandler` de AdMob a un `AdImpression` (E15 T2), sin el SDK: el
/// valor en micros, la precisión, la moneda tal cual, y el `site` que pone el coordinador.
@Suite("Del paidEventHandler a la impresión")
@MainActor
struct AdImpressionMappingTests {
    private func paid(_ amount: String, currency: String = "USD", precision: AdValuePrecision = .precise)
        -> AdImpressionMapping.PaidValue {
        AdImpressionMapping.PaidValue(amount: Decimal(string: amount)!, currencyCode: currency, precision: precision)
    }

    @Test("unidades de moneda a micros, redondeando al más cercano",
          arguments: [
              ("0.000123", 123),
              ("1.5", 1_500_000),
              ("0", 0),
              ("0.0000005", 1),
              ("0.0000004", 0),
              ("0.0123456789", 12_346),
          ] as [(String, Int64)])
    func decimalToMicros(amount: String, micros: Int64) {
        #expect(AdImpressionMapping.micros(Decimal(string: amount)!) == micros)
    }

    @Test("un valor que no entra en Int64 queda en el tope, sin romper")
    func hugeValueSaturates() {
        #expect(AdImpressionMapping.micros(Decimal(string: "1e30")!) == .max)
    }

    @Test("cada precisión del SDK (por su rawValue de GADAdValuePrecision) a la nuestra",
          arguments: [
              (0, .unknown),
              (1, .estimated),
              (2, .publisherProvided),
              (3, .precise),
              (99, .unknown),
              (-1, .unknown),
          ] as [(Int, AdValuePrecision)])
    func precisionMapping(raw: Int, expected: AdValuePrecision) {
        #expect(AdImpressionMapping.precision(sdkRawValue: raw) == expected)
    }

    @Test("la moneda va tal cual, la fuente nil queda nil y la hora es epoch")
    func makeKeepsWhatTheSDKSaid() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let impression = AdImpressionMapping.make(
            value: paid("0.000123", currency: "EUR", precision: .estimated),
            format: .rewarded, site: "gifts", source: nil, now: now
        )
        #expect(impression == AdImpression(
            format: .rewarded, site: "gifts", valueMicros: 123, currency: "EUR",
            precision: .estimated, adSource: nil, at: 1_800_000_000
        ))
    }

    @Test("la fuente de la mediación viaja tal cual")
    func makeKeepsTheAdSource() {
        let impression = AdImpressionMapping.make(
            value: paid("0.01"), format: .interstitial, site: "x", source: "Unity Ads", now: Date()
        )
        #expect(impression.adSource == "Unity Ads")
    }

    @Test("el site: el rewarded trae el suyo, el intersticial lleva el corte, la pausa y el app open el fijo")
    func stampingSites() {
        func stamped(_ format: AdFormat, site: String) -> String {
            let impression = AdImpression(
                format: format, site: site, valueMicros: 1, currency: "USD",
                precision: .unknown, adSource: nil, at: 0
            )
            return AdImpressionMapping.stampingSite(impression, interstitialSite: "sheetClosed").site
        }
        #expect(stamped(.rewarded, site: "wheel") == "wheel")
        #expect(stamped(.interstitial, site: AdImpressionMapping.Site.interstitial) == "sheetClosed")
        #expect(stamped(.rewardedInterstitial, site: "otro") == "adBreak")
        #expect(stamped(.appOpen, site: "otro") == "appOpen")
    }

    @Test("el coordinador reenvía lo que avisa el proveedor, con el site del corte en el intersticial")
    func coordinatorForwardsWithTheSite() async {
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(provider: provider)
        let sink = ImpressionSink()
        ads.onImpression = { sink.received.append($0) }

        _ = await ads.showRewarded(for: .chestExtra)
        await ads.showInterstitial(site: NaturalBreak.reincarnation.rawValue)
        await ads.showAppOpen()

        #expect(sink.received.map(\.format) == [.rewarded, .interstitial, .appOpen])
        #expect(sink.received.map(\.site) == ["chestExtra", "reincarnation", "appOpen"])
    }

    @Test("el site del corte dura lo que dura su intersticial: el siguiente sin corte lleva el default")
    func interstitialSiteDoesNotLeakToTheNextOne() async {
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(provider: provider)
        let sink = ImpressionSink()
        ads.onImpression = { sink.received.append($0) }

        await ads.showInterstitial(site: NaturalBreak.reincarnation.rawValue)
        #expect(ads.interstitialSite == AdImpressionMapping.Site.interstitial, "vuelve al default al cerrarse")
        await ads.showInterstitial()
        await ads.showInterstitial(site: NaturalBreak.sheetClosed.rawValue)

        #expect(sink.received.map(\.site) == ["reincarnation", "interstitial", "sheetClosed"])
    }

    @Test("con remove_ads un forzado no se presenta, así que tampoco deja impresión")
    func removedAdsLeavesNoForcedImpression() async {
        let provider = ScriptedAdsProvider()
        let ads = AdsCoordinator(provider: provider)
        let sink = ImpressionSink()
        ads.onImpression = { sink.received.append($0) }
        ads.setRemovedAds(true)

        await ads.showInterstitial()
        await ads.showAppOpen()

        #expect(sink.received.isEmpty)
    }
}

/// Junta lo que reenvía el coordinador. Una clase y no un `var` capturado: el cierre de
/// `onImpression` es `@MainActor` y, por lo tanto, `Sendable`.
@MainActor
final class ImpressionSink {
    var received: [AdImpression] = []
}
