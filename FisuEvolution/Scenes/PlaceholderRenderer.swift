import EconomyKit
import SpriteKit
import UIKit

/// Resolves a character's texture. Manifest entry present → real art from its atlas
/// (F3+); otherwise the programmatic placeholder: the `sf:<symbol>` SF Symbol from
/// `spritePlaceholder`, rendered white and cached. Code never names a sprite directly.
@MainActor
final class PlaceholderRenderer {
    private var cache: [String: SKTexture] = [:]
    private var atlases: [String: SKTextureAtlas] = [:]

    func texture(for type: CharacterType, manifest: AssetsManifest) -> SKTexture? {
        if let asset = manifest.characters[type.id] {
            let atlas = atlases[asset.atlas] ?? SKTextureAtlas(named: asset.atlas)
            atlases[asset.atlas] = atlas
            return atlas.textureNamed(asset.key)
        }
        return placeholderTexture(named: type.spritePlaceholder)
    }

    private func placeholderTexture(named reference: String) -> SKTexture? {
        if let cached = cache[reference] {
            return cached
        }
        guard reference.hasPrefix("sf:") else {
            Log.assets.error("unsupported placeholder reference '\(reference)'")
            return nil
        }
        let symbolName = String(reference.dropFirst(3))
        let configuration = UIImage.SymbolConfiguration(pointSize: 64, weight: .bold)
        guard let image = UIImage(systemName: symbolName, withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        else {
            Log.assets.error("unknown SF Symbol '\(symbolName)' in placeholder")
            return nil
        }
        let texture = SKTexture(image: image)
        cache[reference] = texture
        return texture
    }
}
