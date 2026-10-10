import CoreGraphics
import SwiftUI

/// El globo de diálogo de la 2.0, uno solo para SpriteKit y SwiftUI (PLAN-v2 E4):
/// un rectángulo redondeado con la cola abajo, en un único contorno (sin costura
/// entre cuerpo y cola cuando se traza el borde).
enum BubbleGeometry {
    static let cornerRadius: CGFloat = 14
    static let tailWidth: CGFloat = 18
    static let tailHeight: CGFloat = 12

    /// `tailX` en las coordenadas de `rect`; se acomoda para no comerse una esquina.
    /// `yUp`: SpriteKit (y crece hacia arriba: la cola cuelga hacia y chico).
    static func path(in rect: CGRect, tailX: CGFloat, yUp: Bool) -> CGPath {
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(0, rect.height - tailHeight))
        let radius = min(cornerRadius, body.height / 2, body.width / 2)
        let half = tailWidth / 2
        let tip = min(max(tailX, body.minX + radius + half), body.maxX - radius - half)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        path.addLine(to: CGPoint(x: body.maxX - radius, y: body.minY))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY + radius), radius: radius)
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - radius))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX - radius, y: body.maxY), radius: radius)
        path.addLine(to: CGPoint(x: tip + half, y: body.maxY))
        path.addLine(to: CGPoint(x: tip, y: rect.maxY))
        path.addLine(to: CGPoint(x: tip - half, y: body.maxY))
        path.addLine(to: CGPoint(x: body.minX + radius, y: body.maxY))
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY - radius), radius: radius)
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + radius))
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX + radius, y: body.minY), radius: radius)
        path.closeSubpath()
        guard yUp else { return path }
        var flip = CGAffineTransform(translationX: 0, y: rect.minY + rect.maxY).scaledBy(x: 1, y: -1)
        return path.copy(using: &flip) ?? path
    }
}

/// El mismo globo, para SwiftUI (la frase del popup de un visitante o de un evento).
struct BubbleShape: Shape {
    /// Dónde va la cola, como fracción del ancho.
    var tailFraction: CGFloat = 0.5

    func path(in rect: CGRect) -> Path {
        Path(BubbleGeometry.path(in: rect, tailX: rect.minX + rect.width * tailFraction, yUp: false))
    }
}
