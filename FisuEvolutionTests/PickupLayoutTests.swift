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
                    let ground = stage.groundY(background: background)
                    let stackTop = ground + layout.side * (1 + CGFloat(PickupLayout.maxVisibleBoxes - 1) * PickupLayout.stackStep)
                    let label = "\(size) \(background ?? "-") \(String(describing: floorBottom))"
                    #expect(layout.baselineY <= horizon + 0.5, "\(label): flota sobre el horizonte")
                    if stackTop < size.height * PickupLayout.maxTopRatio - 0.5 {
                        #expect(abs(layout.packagePosition(index: 0).y - layout.side / 2 - horizon) < 0.5, "\(label)")
                        #expect(abs(layout.baselineY - horizon) < 0.5, "\(label)")
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

    // MARK: - E14b B17: la caja y el colchón, 20 pt más abajo

    @Test("la caja y el colchón bajan 20 pt sobre la línea de las hileras, también con el tope del SE, y nunca debajo de floorBottom")
    func pickupsDropBelowTheGround() {
        for (size, cell) in Self.screens {
            for floorBottom in Self.floorBottoms {
                for background in StageLayout.horizons.keys {
                    let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: background, floorBottom: floorBottom)
                    let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: floorBottom)
                    let ground = stage.groundY(background: background)
                    let stackHeight = layout.side * (1 + CGFloat(PickupLayout.maxVisibleBoxes - 1) * PickupLayout.stackStep)
                    let ceiling = size.height * PickupLayout.maxTopRatio - stackHeight - 0.5
                    let label = "\(size) \(background) \(String(describing: floorBottom))"
                    if layout.baselineY > stage.groundFloorY {
                        #expect(abs(min(ground, ceiling) - layout.baselineY - StageLayout.walkDrop) < 0.001, "\(label): bajó \(min(ground, ceiling) - layout.baselineY)")
                    }
                    #expect(layout.baselineY >= stage.floorBase, "\(label): la caja pasa debajo de floorBottom")
                    #expect(layout.packagePosition(index: 0).y - layout.side / 2 >= stage.floorBase - 0.001)
                    #expect(layout.mattressPosition.y - layout.side * 0.35 >= stage.floorBase - 0.001)
                }
            }
        }
    }

    @Test("en alley, luxury y moon la caja apoya donde pisa el visitante, 20 pt bajo las hileras")
    func pickupsMatchTheWalkers() {
        for (size, cell) in Self.screens {
            for background in ["alley", "luxury", "moon"] {
                let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: background, floorBottom: 96)
                let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: 96)
                #expect(layout.baselineY <= stage.standY(background: background) + 0.001, "\(size) \(background)")
                #expect(layout.baselineY <= stage.groundY(background: background) - StageLayout.walkDrop + 0.001, "\(size) \(background)")
            }
        }
    }

    // MARK: - E14b B18: el lugar de cada caja en su piso

    @Test("en cualquier lugar de su franja la caja no pisa la columna ni al visitante ni al colchón")
    func anyPlaceStaysClear() {
        for (size, cell) in Self.screens {
            let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: "alley")
            let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let visitorLeft = stage.standX - stage.actorSide * PickupLayout.visitorBodyRatio / 2
            for fraction in stride(from: 0.0, through: 1.0, by: 0.1) {
                for index in 0..<PickupLayout.maxVisibleBoxes {
                    let box = layout.packagePosition(index: index, at: fraction)
                    #expect(box.x - layout.side / 2 >= PickupLayout.edgeClearance - 0.001, "\(size) \(fraction): bajo la columna")
                    #expect(box.x + layout.side / 2 <= visitorLeft + 0.5, "\(size) \(fraction): pisa al visitante")
                    #expect(box.x + layout.side / 2 < layout.mattressPosition.x - layout.side / 2, "\(size) \(fraction): pisa el colchón")
                    #expect(abs(box.y - layout.packagePosition(index: index).y) < 0.001, "la pila sube igual")
                }
            }
        }
    }

    @Test("el lugar va de un borde al otro de la franja, y sin lugar es el medio de siempre")
    func placeSpansTheRange() {
        let layout = PickupLayout(sceneSize: CGSize(width: 1032, height: 1376), bottomInset: 118, cellSize: 112)
        let range = layout.packageXRange
        #expect(range.upperBound > range.lowerBound, "en el iPad hay hueco para moverse")
        #expect(abs(layout.packageCenterX(at: 0) - range.lowerBound) < 0.001)
        #expect(abs(layout.packageCenterX(at: 1) - range.upperBound) < 0.001)
        #expect(abs(layout.packageCenterX(at: 5) - range.upperBound) < 0.001, "fuera de rango se queda en el borde")
        #expect(layout.packageCenterX(at: nil) == layout.packageX)
        #expect(layout.packageCenterX(at: 0.25) < layout.packageCenterX(at: 0.75))
    }
}
