import SpriteKit

/// Skins are an engine treatment (tint + glow), not per-character re-renders —
/// decision from the approved plan (zero extra art assets per skin).
@MainActor
enum SkinResolver {
    static func tint(for skinId: String?) -> SKColor? {
        switch skinId {
        case "golden": Palette.yellow
        case "galaxy": SKColor(named: "PaletteBlue") ?? .systemBlue
        case "god": .white
        default: nil
        }
    }
}
