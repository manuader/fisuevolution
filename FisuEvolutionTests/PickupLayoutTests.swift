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
    /// Sin borde (el default de los tests puros) y el de la app, `BoardScene.floorBottom`.
    private static let floorBottoms: [CGFloat?] = [nil, 96]

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
            for floorBottom in Self.floorBottoms {
                for background in Self.backgrounds {
                    let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: background, floorBottom: floorBottom)
                    let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: floorBottom)
                    let horizon = stage.standY(background: background)
                    let stackTop = horizon + layout.side * (1 + CGFloat(PickupLayout.maxVisibleBoxes - 1) * PickupLayout.stackStep)
                    let label = "\(size) \(background ?? "-") \(String(describing: floorBottom))"
                    #expect(layout.baselineY <= horizon + 0.5, "\(label): flota sobre el horizonte")
                    if stackTop < size.height * PickupLayout.maxTopRatio - 0.5 {
                        #expect(abs(layout.packagePosition(index: 0).y - layout.side / 2 - horizon) < 0.5, label)
                        #expect(abs(layout.baselineY - horizon) < 0.5, label)
                    } else {
                        #expect(layout.baselineY + layout.side * 1.6 <= size.height * PickupLayout.maxTopRatio, "\(label): la pila llena pasa del tope")
                    }
                }
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

    @Test("en los diez escenarios la caja y el colchón apoyan en el suelo: ni bajo la barra ni sobre el horizonte")
    func neverFloatsInAnyScenario() {
        for (size, cell) in Self.screens {
            for background in StageLayout.horizons.keys {
                let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: background, floorBottom: 96)
                let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: 96)
                #expect(layout.baselineY >= 118 + cell, "\(size) \(background): la caja toca la barra")
                #expect(layout.baselineY <= stage.horizonY(background: background), "\(size) \(background): la caja flota sobre el horizonte")
                #expect(layout.packagePosition(index: PickupLayout.maxVisibleBoxes - 1).y + layout.side / 2 < size.height * PickupLayout.maxTopRatio)
            }
        }
    }
}
