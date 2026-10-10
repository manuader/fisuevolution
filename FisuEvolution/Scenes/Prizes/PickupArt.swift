import SpriteKit
import UIKit

/// El arte de las cajas y el colchón del tablero: el del atlas `ui` si E8 ya lo
/// entregó, y si no, uno dibujado por código.
@MainActor
enum PickupArt {
    enum Piece: String, CaseIterable {
        case package = "pickup_package"
        case packageLid = "pickup_package_lid"
        case mattress = "pickup_mattress"
    }

    private static var cache: [Piece: SKTexture] = [:]

    static func texture(_ piece: Piece) -> SKTexture {
        if let cached = cache[piece] { return cached }
        let texture = SKTexture(image: UIArt.uiImage(piece.rawValue) ?? placeholder(piece))
        cache[piece] = texture
        return texture
    }

    /// El respaldo, a escala de 96 pt (la escena lo achica).
    static func placeholder(_ piece: Piece) -> UIImage {
        let size: CGSize = switch piece {
        case .package: CGSize(width: 96, height: 84)
        case .packageLid: CGSize(width: 100, height: 28)
        case .mattress: CGSize(width: 96, height: 60)
        }
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3)
            let body = UIBezierPath(roundedRect: rect, cornerRadius: piece == .mattress ? 14 : 8)
            (UIColor(named: piece == .mattress ? "PaletteBlue" : "PaletteBrown") ?? .brown).setFill()
            body.fill()
            if piece != .mattress {
                (UIColor(named: "PaletteYellow") ?? .yellow).setFill()
                context.fill(CGRect(x: rect.midX - 5, y: rect.minY, width: 10, height: rect.height))
            }
            (UIColor(named: "PaletteInk") ?? .black).setStroke()
            body.lineWidth = 3
            body.stroke()
        }
    }
}
