import SpriteKit
import SwiftUI
import UIKit

/// El arte de un visitante, con respaldo (PLAN-v2 §5, `Docs/biblia-visitantes.md`):
/// las poses nuevas viven en `npcs.atlas` y la canónica de los 10 especiales es
/// la de la v1 (`characters`). Sin entrada, el juego no espera al batch: un disco
/// con el símbolo y el color del visitante (`visitors.json`).
@MainActor
enum VisitorArt {
    enum Pose: String {
        case canonical = ""
        case talk = "_talk"
        case action = "_action"
        case face = "_face"
    }

    /// (atlas, clave) de una pose; si la pose no está, la canónica. `nil` sin arte.
    static func asset(for visitorId: String, pose: Pose, manifest: AssetsManifest) -> (atlas: String, key: String)? {
        if let key = manifest.npcs?[visitorId + pose.rawValue] { return ("npcs", key) }
        if pose != .canonical { return asset(for: visitorId, pose: .canonical, manifest: manifest) }
        if let character = manifest.characters[visitorId] { return (character.atlas, character.key) }
        return nil
    }

    static func texture(for visitorId: String, pose: Pose, manifest: AssetsManifest) -> SKTexture? {
        guard let asset = asset(for: visitorId, pose: pose, manifest: manifest) else { return nil }
        return AtlasCache.texture(named: asset.key, inAtlas: asset.atlas)
    }

    static func image(for visitorId: String, pose: Pose, manifest: AssetsManifest) -> Image? {
        guard let asset = asset(for: visitorId, pose: pose, manifest: manifest) else { return nil }
        return UIArt.characterImage(atlas: asset.atlas, key: asset.key)
    }

    /// Hay una cara dibujada; si no, la vista recorta la cabeza de la canónica.
    static func hasOwnFace(_ visitorId: String, manifest: AssetsManifest) -> Bool {
        manifest.npcs?[visitorId + Pose.face.rawValue] != nil
    }

    static func placeholderTexture(symbol: String, tint: String, side: CGFloat = 128) -> SKTexture {
        SKTexture(image: placeholderImage(symbol: symbol, tint: tint, side: side))
    }

    /// El respaldo: un disco del color del visitante, con borde de tinta y su
    /// símbolo en blanco.
    static func placeholderImage(symbol: String, tint: String, side: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { context in
            let disc = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: 3, dy: 3)
            (UIColor(named: tint) ?? .systemBlue).setFill()
            context.cgContext.fillEllipse(in: disc)
            (UIColor(named: "PaletteInk") ?? .darkGray).setStroke()
            context.cgContext.setLineWidth(3)
            context.cgContext.strokeEllipse(in: disc)
            let configuration = UIImage.SymbolConfiguration(pointSize: side * 0.42, weight: .heavy)
            guard let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            else { return }
            glyph.draw(in: CGRect(
                x: (side - glyph.size.width) / 2, y: (side - glyph.size.height) / 2,
                width: glyph.size.width, height: glyph.size.height
            ))
        }
    }
}
