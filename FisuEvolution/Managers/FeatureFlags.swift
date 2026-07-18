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
}
