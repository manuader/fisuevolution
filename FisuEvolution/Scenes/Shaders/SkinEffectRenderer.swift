import SpriteKit

/// La foto de un efecto, con el MISMO `SKShader` del tablero, para las pantallas
/// de SwiftUI (Pintas, la ficha, la tienda). Una sola implementación del efecto:
/// lo que se ve antes de comprar es lo que se ve en el tablero, quieto.
@MainActor
enum SkinEffectRenderer {
    private static let view = SKView(frame: CGRect(x: 0, y: 0, width: 256, height: 256))
    private static let cache = NSCache<NSString, CGImage>()

    /// `shaderID == nil` es la foto sin efecto (la usa el test para comparar).
    static func snapshot(of texture: SKTexture, shaderID: String?, side: CGFloat) -> CGImage? {
        let key = "\(ObjectIdentifier(texture).hashValue)|\(shaderID ?? "-")|\(Int(side))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: side, height: side))
        SkinShaders.apply(shaderID, to: sprite, phase: 0.37)
        guard let image = view.texture(from: sprite)?.cgImage() else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
