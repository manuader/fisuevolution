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
    /// Las poses de los visitantes (`npcs.atlas`): la canónica de los 8 nuevos y
    /// `_talk`/`_action`/`_face`. La sección la crea `process_dropbox.py` con el
    /// primer visitante integrado; hasta entonces no está y todo cae a su respaldo.
    var npcs: [String: String]? = nil
}
