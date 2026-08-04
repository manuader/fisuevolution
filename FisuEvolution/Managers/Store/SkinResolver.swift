import EconomyKit
import SpriteKit

/// Traduce una elección persistida en la ficha a un tratamiento de render.
/// No hay IDs de skin en código: `skins.json` es la única fuente de verdad.
@MainActor
enum SkinResolver {
    enum Treatment: Equatable {
        case base
        case tint(hex: String)
        case texture(key: String)
    }

    static func treatment(
        for skinID: String?,
        characterType typeID: String,
        config: SkinsConfig
    ) -> Treatment {
        guard let skinID,
              let skin = config.entries(forCharacterType: typeID).first(where: { $0.id == skinID })
        else { return .base }

        switch skin.treatment {
        case .tint:
            return skin.tintHex.map(Treatment.tint(hex:)) ?? .base
        case .texture:
            return skin.textureKey.map(Treatment.texture(key:)) ?? .base
        }
    }

    static func tintColor(for treatment: Treatment) -> SKColor? {
        guard case let .tint(hex) = treatment else { return nil }
        return SKColor(hex: hex)
    }
}

private extension SKColor {
    convenience init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let raw = Int(value, radix: 16) else { return nil }
        self.init(
            red: CGFloat((raw >> 16) & 0xFF) / 255,
            green: CGFloat((raw >> 8) & 0xFF) / 255,
            blue: CGFloat(raw & 0xFF) / 255,
            alpha: 1
        )
    }
}
