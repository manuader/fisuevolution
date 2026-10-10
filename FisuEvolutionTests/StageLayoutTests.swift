import CoreGraphics
import Testing
@testable import FisuEvolution

@Suite("El escenario: la geometría")
struct StageLayoutTests {
    /// iPhone SE, 16 Pro, Pro Max y el iPad 13" (con la celda topeada de PlayLayout).
    static let screens: [(CGSize, CGFloat)] = [
        (CGSize(width: 375, height: 667), 68),
        (CGSize(width: 393, height: 852), 72),
        (CGSize(width: 440, height: 956), 81),
        (CGSize(width: 1032, height: 1376), 112),
    ]

    @Test("se para adentro de [28 %, 72 %] y entra desde afuera de la pantalla")
    func standsInsideTheStage() {
        for (size, cell) in Self.screens {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            #expect(layout.stageRange.contains(layout.standX))
            #expect(layout.offstageX(left: true) + layout.actorSide / 2 <= 0)
            #expect(layout.offstageX(left: false) - layout.actorSide / 2 >= size.width)
        }
    }

    @Test("la caminata entra en el turno, aun en la pantalla más ancha")
    func walkFitsTheTurn() {
        for (size, cell) in Self.screens {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            #expect(layout.walkSeconds(fromLeft: true) < 10 - 1, "\(size): el watchdog cortaría la entrada")
        }
    }

    @Test("el globo nunca se sale de la pantalla")
    func bubbleStaysOnScreen() {
        for (size, cell) in Self.screens {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            for tipX in [0, layout.standX, size.width] {
                let left = layout.bubbleLeft(width: layout.bubbleMaxWidth, tipX: tipX)
                #expect(left >= StageLayout.bubbleMargin)
                #expect(left + layout.bubbleMaxWidth <= size.width - StageLayout.bubbleMargin + 0.5)
            }
        }
    }

    @Test("el globo vectorial ocupa su rect, con la cola abajo y adentro")
    func bubbleGeometry() {
        let rect = CGRect(x: 10, y: 20, width: 200, height: 80)
        let down = BubbleGeometry.path(in: rect, tailX: 110, yUp: false)
        #expect(down.boundingBoxOfPath.insetBy(dx: -0.5, dy: -0.5).contains(rect))
        #expect(down.contains(CGPoint(x: 110, y: rect.maxY - 2)), "la punta de la cola, abajo")
        #expect(!down.contains(CGPoint(x: rect.minX + 2, y: rect.maxY - 2)), "al costado de la cola no hay globo")
        let up = BubbleGeometry.path(in: rect, tailX: 110, yUp: true)
        #expect(up.contains(CGPoint(x: 110, y: rect.minY + 2)), "en SpriteKit la cola cuelga hacia y chico")
        let clamped = BubbleGeometry.path(in: rect, tailX: -500, yUp: false)
        #expect(clamped.boundingBoxOfPath.minX >= rect.minX - 0.5, "una cola fuera del globo se acomoda adentro")
    }
}
