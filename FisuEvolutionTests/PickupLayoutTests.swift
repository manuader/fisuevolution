import CoreGraphics
import Testing
@testable import FisuEvolution

/// Dónde se paran las cajas y el colchón: ni bajo la columna de E7b ni bajo la
/// botonera, ni encima de quien está en escena (E4b).
@Suite("Las cajas y el colchón: dónde se paran")
struct PickupLayoutTests {
    /// iPhone SE, 16 Pro, Pro Max y el iPad 13", con la celda de `PlayLayout`.
    static let screens: [(CGSize, CGFloat)] = [
        (CGSize(width: 375, height: 667), 68),
        (CGSize(width: 393, height: 852), 72),
        (CGSize(width: 440, height: 956), 81.6),
        (CGSize(width: 1032, height: 1376), 112),
    ]

    @Test("lejos de los bordes y a los costados del visitante")
    func clearOfTheEdgesAndTheVisitor() {
        for (size, cell) in Self.screens {
            let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let visitorLeft = stage.standX - stage.actorSide / 2
            let visitorRight = stage.standX + stage.actorSide / 2
            for index in 0..<PickupLayout.maxVisibleBoxes {
                let box = layout.packagePosition(index: index)
                #expect(box.x - layout.side / 2 >= PickupLayout.edgeClearance, "\(size): la caja \(index) va bajo la columna")
                #expect(box.x + layout.side / 2 <= visitorLeft + 0.5, "\(size): la caja \(index) pisa al visitante")
            }
            let mattress = layout.mattressPosition
            #expect(mattress.x - layout.side / 2 >= visitorRight - 0.5, "\(size): el colchón pisa al visitante")
            #expect(mattress.x + layout.side / 2 <= size.width - PickupLayout.edgeClearance, "\(size): el colchón va al borde")
        }
    }

    @Test("apoyados en la línea del escenario, y la pila no pasa de media pantalla")
    func onTheStageLine() {
        for (size, cell) in Self.screens {
            let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            #expect(abs(layout.packagePosition(index: 0).y - layout.side / 2 - stage.baselineY) < 0.5)
            let top = layout.packagePosition(index: PickupLayout.maxVisibleBoxes - 1).y + layout.side / 2
            #expect(top < size.height / 2, "\(size): la pila sube hasta \(top)")
        }
    }
}
