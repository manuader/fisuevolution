import Foundation

/// Art ↔ code junction, mirrored 1:1 from `assets_manifest.json` (bible §6.4).
///
/// The golden rule: code never references a sprite directly. A character id with an
/// entry here renders real art from its atlas; without one it renders the programmatic
/// placeholder. F3 fills this file in batches — zero Swift changes per batch.
struct AssetsManifest: Codable, Sendable, Equatable {
    struct CharacterAsset: Codable, Sendable, Equatable {
        let atlas: String
        let key: String
        /// Sprite anchor point, `[x, y]` in unit coordinates.
        let anchor: [Double]
        let scale: Double
    }

    let schemaVersion: Int
    let characters: [String: CharacterAsset]
    let backgrounds: [String: String]
    let ui: [String: String]
}
