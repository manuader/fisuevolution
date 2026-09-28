import Foundation

/// Runtime feature switches, mirrored 1:1 from `feature_flags.json`.
/// F6 flips `gameCenterEnabled`/`cloudKitEnabled` by editing the JSON — no code changes.
struct FeatureFlags: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let gameCenterEnabled: Bool
    let cloudKitEnabled: Bool
    let useRealAds: Bool
    /// `"dev"` during development; `"store"` builds serve only review-safe content.
    let buildVariant: String
    /// El campo reacciona a los eventos. Apagarlo devuelve el campo de antes,
    /// sin tocar código: es la llave por si algo se ve mal en TestFlight.
    let eventReactionsEnabled: Bool
}

extension FeatureFlags {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, gameCenterEnabled, cloudKitEnabled, useRealAds, buildVariant
        case eventReactionsEnabled
    }

    /// Las claves nuevas entran con default: un `feature_flags.json` que no la
    /// nombra no rompe el arranque ni apaga la feature. Va en una extensión para
    /// no perder el init memberwise.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        gameCenterEnabled = try container.decode(Bool.self, forKey: .gameCenterEnabled)
        cloudKitEnabled = try container.decode(Bool.self, forKey: .cloudKitEnabled)
        useRealAds = try container.decode(Bool.self, forKey: .useRealAds)
        buildVariant = try container.decode(String.self, forKey: .buildVariant)
        eventReactionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .eventReactionsEnabled) ?? true
    }
}
