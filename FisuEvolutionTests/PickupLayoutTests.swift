import CoreGraphics
import Testing
@testable import FisuEvolution

/// Dónde se paran las cajas y el colchón (E14 C10): grandes, en la línea del horizonte, ni
/// bajo la columna de E7b ni bajo las solapas de la barra, ni encima de quien está en escena.
@Suite("Las cajas y el colchón: dónde se paran")
struct PickupLayoutTests {
    /// iPhone SE, 16 Pro, Pro Max y el iPad 13", con la celda de `PlayLayout`.
    static let screens: [(CGSize, CGFloat)] = [
        (CGSize(width: 375, height: 667), 68),
        (CGSize(width: 393, height: 852), 72),
        (CGSize(width: 440, height: 956), 81.6),
        (CGSize(width: 1032, height: 1376), 112),
    ]

    private static let backgrounds: [String?] = [nil, "alley", "moon", "god_realm"]

    @Test("lejos de los bordes y a los costados del visitante")
    func clearOfTheEdgesAndTheVisitor() {
        for (size, cell) in Self.screens {
            let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let body = stage.actorSide * PickupLayout.visitorBodyRatio / 2
            let visitorLeft = stage.standX - body
            let visitorRight = stage.standX + body
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

    @Test("más grandes: entre +80 % y +100 % de las 0,62 celdas de antes")
    func biggerThanBefore() {
        let growth = PickupLayout.sideRatio / 0.62 - 1
        #expect(growth >= 0.8 && growth <= 1.0, "crecieron \(growth)")
    }

    @Test("apoyados en el horizonte del fondo, el mismo donde se para el visitante")
    func onTheHorizon() {
        for (size, cell) in Self.screens {
            for background in Self.backgrounds {
                let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: background)
                let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
                let horizon = stage.standY(background: background)
                #expect(abs(layout.packagePosition(index: 0).y - layout.side / 2 - horizon) < 0.5)
                #expect(abs(layout.baselineY - horizon) < 0.5)
            }
        }
    }

    @Test("el horizonte sigue al desplazamiento del fondo")
    func followsTheBackgroundOffset() {
        let size = CGSize(width: 393, height: 852)
        let flat = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: 72, background: "alley")
        let lifted = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: 72, background: "alley", backgroundOffset: 0.05)
        #expect(lifted.baselineY < flat.baselineY)
    }

    @Test("nada queda bajo las solapas de la barra y la pila se ve entera")
    @MainActor
    func clearOfTheBarAndTheTopOfTheScreen() {
        for (size, cell) in Self.screens {
            for background in Self.backgrounds {
                let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: background)
                let barTop = GameTabBar.barHeight + (118 - GameTabBar.panelHeight)
                #expect(layout.baselineY >= barTop + 8, "\(size) \(background ?? "-"): la caja toca la barra")
                let top = layout.packagePosition(index: PickupLayout.maxVisibleBoxes - 1).y + layout.side / 2
                #expect(top < size.height * 0.82, "\(size) \(background ?? "-"): la pila sube hasta \(top)")
            }
        }
    }

    @Test("el colchón también va en el horizonte y entero a la vista")
    func mattressOnTheHorizon() {
        for (size, cell) in Self.screens {
            let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: "urban")
            #expect(abs(layout.mattressPosition.y - layout.side * 0.35 - layout.baselineY) < 0.01)
            #expect(layout.mattressPosition.y + layout.side / 2 < size.height)
        }
    }
}
