import EconomyKit
import SwiftUI

/// La imagen de SwiftUI de un personaje con su pinta: la textura en su atlas (el
/// del personaje, o el de su familia) o, si el arte todavía no existe, el retrato
/// base. Una sola resolución para Pintas, la ficha y la tienda; el tinte lo pone
/// quien dibuja, con `colorMultiply`.
@MainActor
enum SkinArt {
    static func image(
        type: CharacterType,
        skinID: String?,
        skins: SkinsConfig,
        manifest: AssetsManifest
    ) -> Image? {
        guard let asset = manifest.characters[type.id] else { return nil }
        if case let .texture(key) = SkinResolver.treatment(for: skinID, characterType: type.id, config: skins) {
            let atlas = SkinResolver.atlas(for: skinID, characterType: type.id, config: skins) ?? asset.atlas
            if let art = UIArt.characterImage(atlas: atlas, key: key) { return art }
        }
        return UIArt.characterImage(atlas: asset.atlas, key: asset.key)
    }
}
