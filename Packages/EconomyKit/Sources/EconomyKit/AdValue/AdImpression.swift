import Foundation

/// El formato del anuncio que pagó (E15 C1).
public enum AdFormat: String, Codable, Sendable, CaseIterable {
    case rewarded, interstitial, rewardedInterstitial, appOpen
}

/// Qué tan cierto es el valor que informó el SDK (`GADAdValuePrecision`, con nombre propio).
/// Una precisión que este build no conoce (de un build futuro) se lee como `.unknown`: no tira la
/// impresión.
public enum AdValuePrecision: String, Codable, Sendable {
    case unknown, estimated, publisherProvided, precise

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AdValuePrecision(rawValue: raw) ?? .unknown
    }
}

/// Lo que pagó UNA impresión, ya sin tipos del SDK: lo arma la app desde el `paidEventHandler`
/// de AdMob y EconomyKit sólo lo guarda (E15 C1). Ningún cálculo de economía lo lee.
public struct AdImpression: Codable, Sendable, Equatable {
    public let format: AdFormat
    /// `RewardedPlacement.rawValue` para los rewarded; `NaturalBreak.rawValue` o `"adBreak"`/`"appOpen"`
    /// para los forzados.
    public let site: String
    /// El valor × 1_000_000, redondeado (el SDK de iOS da un `NSDecimalNumber` en unidades de moneda).
    public let valueMicros: Int64
    /// ISO 4217 del SDK, tal cual.
    public let currency: String
    public let precision: AdValuePrecision
    /// `responseInfo.loadedAdNetworkResponseInfo.adSourceName` (Google, Unity, Meta); nil si no hay.
    public let adSource: String?
    /// Epoch.
    public let at: TimeInterval

    public init(
        format: AdFormat,
        site: String,
        valueMicros: Int64,
        currency: String,
        precision: AdValuePrecision,
        adSource: String?,
        at: TimeInterval
    ) {
        self.format = format
        self.site = site
        self.valueMicros = valueMicros
        self.currency = currency
        self.precision = precision
        self.adSource = adSource
        self.at = at
    }
}
