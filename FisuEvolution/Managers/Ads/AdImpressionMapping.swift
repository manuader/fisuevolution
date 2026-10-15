import EconomyKit
import Foundation

/// De lo que avisa el `paidEventHandler` de AdMob a un `AdImpression` (E15 C1).
///
/// Vive suelto, puro y **sin tipos del SDK** por dos razones: un `AdValue` de Google no se puede
/// construir en un test, y el SDK exporta un `AdFormat` y un `AdValuePrecision` con el mismo nombre
/// que los de EconomyKit. Este archivo no importa `GoogleMobileAds`, así que acá los dos nombres son
/// los nuestros; el proveedor real le pasa lo que leyó del `AdValue` ya en tipos de Foundation.
enum AdImpressionMapping {
    /// Lo que trae un `AdValue` del SDK: `value` (un `NSDecimalNumber` en unidades de moneda),
    /// `currencyCode` y la precisión ya traducida.
    struct PaidValue: Sendable, Equatable {
        let amount: Decimal
        let currencyCode: String
        let precision: AdValuePrecision
    }

    /// El `site` de los formatos que no son un rewarded pedido desde un lugar.
    enum Site {
        /// La pausa publicitaria (intersticial bonificado).
        static let adBreak = "adBreak"
        static let appOpen = "appOpen"
        /// Un intersticial que no salió de un corte natural conocido (el panel de debug).
        static let interstitial = "interstitial"
    }

    static func make(value: PaidValue, format: AdFormat, site: String, source: String?, now: Date) -> AdImpression {
        AdImpression(
            format: format,
            site: site,
            valueMicros: micros(value.amount),
            currency: value.currencyCode,
            precision: value.precision,
            adSource: source,
            at: now.timeIntervalSince1970
        )
    }

    /// Unidades de moneda → micros, redondeado al entero más cercano (la mitad se aleja del cero).
    /// Lo que no entra en `Int64` queda en el tope: medir nunca puede tirar abajo la app.
    static func micros(_ amount: Decimal) -> Int64 {
        var scaled = amount * 1_000_000
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        if rounded >= Decimal(Int64.max) { return .max }
        if rounded <= Decimal(Int64.min) { return .min }
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    /// `GADAdValuePrecision` por su `rawValue`, tal como lo declara `GADAdValue.h` (SDK 13.11):
    /// 0 desconocida, 1 estimada, 2 la del editor (CPM manual de mediación), 3 precisa. Un valor que
    /// este build no conoce cae en `.unknown`.
    static func precision(sdkRawValue: Int) -> AdValuePrecision {
        switch sdkRawValue {
        case 1: .estimated
        case 2: .publisherProvided
        case 3: .precise
        default: .unknown
        }
    }

    /// El `site` definitivo, que pone el coordinador: el rewarded trae el suyo (su lugar), la pausa
    /// y el app open tienen uno fijo, y el intersticial lleva el corte natural que lo mostró.
    static func stampingSite(_ impression: AdImpression, interstitialSite: String) -> AdImpression {
        let site = switch impression.format {
        case .rewarded: impression.site
        case .interstitial: interstitialSite
        case .rewardedInterstitial: Site.adBreak
        case .appOpen: Site.appOpen
        }
        guard site != impression.site else { return impression }
        return AdImpression(
            format: impression.format,
            site: site,
            valueMicros: impression.valueMicros,
            currency: impression.currency,
            precision: impression.precision,
            adSource: impression.adSource,
            at: impression.at
        )
    }
}
