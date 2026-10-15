import CoreGraphics
import Observation
import UIKit

/// El globo de texto de quien está en escena (E14b B19, D13). Ya no se dibuja en SpriteKit: va en
/// una capa de SwiftUI por encima del HUD, las esquinas, los chips y los avisos
/// (`StageBubbleLayer`), así nada lo tapa. La escena sólo dice qué dice y a qué cabeza apunta.
struct StageBubble: Equatable {
    /// La visita que habla.
    let visitId: UUID
    let text: String
    /// La cabeza: dónde apoya la punta de la cola, en puntos de la escena con el origen ARRIBA a la
    /// izquierda (como SwiftUI).
    let tip: CGPoint
    /// El tamaño de la escena en el que se midió `tip`: la capa lo escala si su lienzo no coincide.
    let sceneSize: CGSize
    /// El ancho que el globo prefiere (`StageLayout.bubbleMaxWidth`).
    let preferredWidth: CGFloat
    /// Cuánto puede bajar el globo sobre la cabeza para no tapar el HUD (`StageBubbleLayout`).
    let maxDrop: CGFloat
    /// Tocarlo abre el popup de la visita, igual que tocar al visitante. En un reto de toques, o
    /// mientras todavía camina, no: los toques pasan a lo que está debajo.
    let tappable: Bool
}

/// Lo que la escena le publica a la capa de SwiftUI. Se escribe sólo cuando cambia algo que se ve
/// (el texto, la cabeza movida medio punto, si se puede tocar): no en cada cuadro.
@MainActor
@Observable
final class StageBubbleFeed {
    private(set) var bubble: StageBubble?
    /// Lo que hace un toque sobre el globo. Lo enchufa `BoardScene`, para que pase por la misma
    /// puerta que un toque del tablero (saltear una celebración primero).
    @ObservationIgnored var onTap: () -> Void = {}
    /// Los marcos de las dos esquinas (`CornersView`), en puntos de la pantalla con el origen arriba
    /// a la izquierda: el visitante camina y el globo se acomoda sin tocarlos (E14b B20, D14). Los
    /// mide SwiftUI y los lee la escena por cuadro: no redibujan nada.
    @ObservationIgnored private(set) var corners: [StageCorner: CGRect] = [:]

    var cornerFrames: [CGRect] { Array(corners.values) }

    func reportCorner(_ corner: StageCorner, frame: CGRect) {
        corners[corner] = frame
    }

    func publish(_ bubble: StageBubble?) {
        if self.bubble != bubble { self.bubble = bubble }
    }

    func tap() {
        onTap()
    }
}

/// Las dos columnas de las esquinas de arriba (`CornersView`).
enum StageCorner: Hashable {
    case left, right
}

/// Dónde va el globo en la pantalla: centrado sobre la cabeza, **entero en la pantalla** (tope
/// arriba y a los costados) y, cuando se puede, **sin tapar el HUD**. Es puro para que
/// `StageBubbleTests` lo recorra en los diez escenarios y en el SE y el Pro Max.
///
/// Para esquivar el HUD prueba, en orden: el ancho de siempre y, si no alcanza, todo el ancho de la
/// pantalla (menos renglones, globo más bajo); con cada uno, primero sobre la cabeza y después
/// bajando hasta `maxDrop` sobre ella. Si nada alcanza (un piso alto en un teléfono chico) se queda
/// donde menos tapa: arriba de todo igual, nada lo tapa a él.
enum StageBubbleLayout {
    static let margin: CGFloat = StageLayout.bubbleMargin
    static let padding: CGFloat = 12
    /// El aire entre el borde de abajo del HUD y el globo.
    static let hudGap: CGFloat = 6
    static let fontName = "AvenirNext-Bold"
    static let fontSize: CGFloat = 15
    /// El carril más angosto entre las esquinas donde todavía conviene meter el globo: más angosto,
    /// el texto no entra legible y se queda donde estaba (arriba de todo igual, B19).
    static let minLaneWidth: CGFloat = 120

    struct Placement: Equatable {
        /// El globo entero, cola incluida, con el origen arriba a la izquierda.
        let frame: CGRect
        /// La punta de la cola, desde el borde izquierdo del globo.
        let tailX: CGFloat
        /// El ancho del texto adentro (`frame` menos el relleno).
        let textWidth: CGFloat
    }

    /// El texto medido con la fuente del globo, envuelto en `maxWidth`.
    static func measure(_ text: String, maxWidth: CGFloat) -> CGSize {
        let font = UIFont(name: fontName, size: fontSize) ?? .boldSystemFont(ofSize: fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: max(1, maxWidth), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil
        )
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }

    /// El globo (cola incluida) de un texto envuelto en `maxWidth`.
    static func bubbleSize(of text: String, maxWidth: CGFloat,
                           measure: (String, CGFloat) -> CGSize = StageBubbleLayout.measure) -> CGSize {
        let inner = measure(text, max(1, maxWidth - padding * 2))
        return CGSize(width: min(maxWidth, inner.width + padding * 2),
                      height: inner.height + padding * 2 + BubbleGeometry.tailHeight)
    }

    /// `screen`: el lienzo de la capa (el de la escena). `safeTop`: lo que tapa la isla arriba.
    /// `hudBottom`: el borde de abajo del panel del HUD, si se conoce. `corners`: los marcos de las
    /// esquinas (`CornersView`), en el mismo lienzo: el globo no se les encima (E14b B20, D14).
    static func place(_ bubble: StageBubble, screen: CGSize, safeTop: CGFloat, hudBottom: CGFloat?,
                      corners: [CGRect] = [],
                      measure: (String, CGFloat) -> CGSize = StageBubbleLayout.measure) -> Placement {
        let placed = placeOverHead(bubble, screen: screen, safeTop: safeTop, hudBottom: hudBottom, measure: measure)
        let scaleX = bubble.sceneSize.width > 0 ? screen.width / bubble.sceneSize.width : 1
        let tipX = bubble.tip.x * scaleX
        return avoiding(corners, placed, text: bubble.text, tipX: tipX, screen: screen,
                        top: max(safeTop, margin), measure: measure)
    }

    /// Si el globo pisa el marco de una esquina que le queda a la misma altura, se angosta al carril
    /// libre entre ellas, con el borde de abajo (la cola, sobre la cabeza) donde estaba.
    private static func avoiding(_ corners: [CGRect], _ placement: Placement, text: String, tipX: CGFloat,
                                 screen: CGSize, top: CGFloat,
                                 measure: (String, CGFloat) -> CGSize) -> Placement {
        let solid = corners.filter { !$0.isEmpty }
        guard solid.contains(where: { $0.intersects(placement.frame) }) else { return placement }
        // Angostarlo suma renglones y lo estira hacia arriba, donde puede alcanzar otra esquina: se
        // vuelve a medir el carril con el globo nuevo, pocas veces.
        var current = placement
        for _ in 0..<3 {
            let frame = current.frame
            var lower = margin
            var upper = screen.width - margin
            for corner in solid where corner.maxY > frame.minY && corner.minY < frame.maxY {
                if corner.midX < tipX {
                    lower = max(lower, corner.maxX + StageLayout.cornerGap)
                } else {
                    upper = min(upper, corner.minX - StageLayout.cornerGap)
                }
            }
            guard upper - lower >= minLaneWidth else { return current }
            let size = bubbleSize(of: text, maxWidth: min(frame.width, upper - lower), measure: measure)
            let x = min(max(tipX - size.width / 2, lower), upper - size.width)
            let y = max(top, frame.maxY - size.height)
            current = Placement(frame: CGRect(x: x, y: y, width: size.width, height: size.height),
                                tailX: tipX - x, textWidth: max(0, size.width - padding * 2))
            if !solid.contains(where: { $0.intersects(current.frame) }) { return current }
        }
        return current
    }

    /// Sobre la cabeza, entero en la pantalla y, cuando se puede, sin tapar el HUD.
    private static func placeOverHead(_ bubble: StageBubble, screen: CGSize, safeTop: CGFloat, hudBottom: CGFloat?,
                                      measure: (String, CGFloat) -> CGSize) -> Placement {
        let scaleX = bubble.sceneSize.width > 0 ? screen.width / bubble.sceneSize.width : 1
        let scaleY = bubble.sceneSize.height > 0 ? screen.height / bubble.sceneSize.height : 1
        let tip = CGPoint(x: bubble.tip.x * scaleX, y: bubble.tip.y * scaleY)
        let widest = max(1, screen.width - margin * 2)
        let preferred = min(max(1, bubble.preferredWidth), widest)
        let widths = widest > preferred + 1 ? [preferred, widest] : [preferred]
        let top = max(safeTop, margin)
        var fallback: Placement?
        for width in widths {
            let measured = bubbleSize(of: bubble.text, maxWidth: width, measure: measure)
            let natural = tip.y - measured.height
            guard let hudBottom else { return placement(size: measured, y: natural, tip: tip, screen: screen, top: top) }
            let clear = hudBottom + hudGap
            if natural >= clear {
                return placement(size: measured, y: natural, tip: tip, screen: screen, top: top)
            }
            if natural + max(0, bubble.maxDrop) >= clear {
                return placement(size: measured, y: clear, tip: tip, screen: screen, top: top)
            }
            let candidate = placement(size: measured, y: natural, tip: tip, screen: screen, top: top)
            // Sin despejar el HUD, el que menos lo tapa; empatados (los dos contra el tope), el más bajo.
            let better = fallback.map {
                candidate.frame.minY > $0.frame.minY
                    || (candidate.frame.minY == $0.frame.minY && candidate.frame.height < $0.frame.height)
            } ?? true
            if better { fallback = candidate }
        }
        return fallback ?? placement(size: bubbleSize(of: bubble.text, maxWidth: preferred, measure: measure),
                                     y: tip.y, tip: tip, screen: screen, top: top)
    }

    /// Centrado sobre la cabeza y metido en la pantalla: a los costados por el margen, arriba por
    /// `top` (aunque tenga que bajar sobre la cabeza) y abajo por el borde.
    private static func placement(size: CGSize, y: CGFloat, tip: CGPoint, screen: CGSize, top: CGFloat) -> Placement {
        let x = min(max(tip.x - size.width / 2, margin), max(margin, screen.width - margin - size.width))
        let lowest = screen.height - margin - size.height
        let clampedY = max(top, min(y, lowest))
        return Placement(frame: CGRect(x: x, y: clampedY, width: size.width, height: size.height),
                         tailX: tip.x - x, textWidth: max(0, size.width - padding * 2))
    }
}
