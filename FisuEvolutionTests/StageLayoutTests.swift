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

    @Test("se para en el horizonte: lejos de la barra de abajo y adentro de la pantalla, en los diez fondos")
    func standsOnTheHorizon() {
        for (size, cell) in Self.screens {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            for background in StageLayout.horizons.keys {
                let y = layout.standY(background: background)
                #expect(y >= 118 + cell, "\(size) \(background): pisa la barra de abajo")
                #expect(y + layout.actorSide < size.height * StageLayout.maxHeadRatio, "\(size) \(background): se sale por arriba")
            }
        }
    }

    @Test("cada fondo tiene su horizonte, y uno desconocido cae al de siempre")
    func horizonPerBackground() {
        let layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        #expect(layout.standY(background: "moon") > layout.standY(background: "solar"))
        #expect(layout.standY(background: "no_existe") == layout.standY(background: nil))
        #expect(Set(StageLayout.horizons.keys).count == 10)
    }

    @Test("un fondo bajado un poco baja la línea, con el tope del sobrante del fondo")
    func backgroundOffsetLowersTheLine() {
        let layout = StageLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        let base = layout.standY(background: "urban")
        #expect(layout.standY(background: "urban", backgroundOffset: 0.05) < base)
        #expect(layout.standY(background: "urban", backgroundOffset: 5) >= 118 + 72)
    }

    // MARK: - E14b B3: el horizonte, un solo dato por escenario

    /// El borde de arriba de la barra que usa la app (`BoardScene.floorBottom`), y el default de los tests puros.
    private static let floorBottoms: [CGFloat?] = [nil, 96]

    @Test("el horizonte de cada fondo queda arriba de la barra y los pies pisan suelo, en los diez fondos")
    func horizonSitsAboveTheBar() {
        for (size, cell) in Self.screens {
            for floorBottom in Self.floorBottoms {
                let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: floorBottom)
                for background in StageLayout.horizons.keys {
                    let horizon = layout.horizonY(background: background)
                    #expect(horizon > layout.floorBase, "\(size) \(background): el horizonte queda bajo la barra")
                    let y = layout.standY(background: background)
                    #expect(y <= horizon + 0.001, "\(size) \(background): los pies pasan del horizonte")
                    #expect(y >= 118 + cell, "\(size) \(background): pisa la barra")
                    #expect(y + layout.actorSide < size.height * StageLayout.maxHeadRatio, "\(size) \(background): la cabeza llega al HUD")
                }
            }
        }
    }

    @Test("terminar el fondo arriba de la barra sube el horizonte exactamente lo que sube su borde")
    func lowerEdgeRaisesTheHorizon() {
        for (size, cell) in Self.screens {
            let flush = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: 0)
            let raised = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: 96)
            for background in StageLayout.horizons.keys {
                let rise = raised.horizonY(background: background) - flush.horizonY(background: background)
                #expect(abs(rise - 96) < 0.001, "\(size) \(background): subió \(rise)")
            }
        }
    }

    @Test("el fondo bajado se mide con la misma cuenta que lo dibuja")
    func liftMatchesTheDrawing() {
        let size = CGSize(width: 393, height: 852)
        let slack = StageLayout.spriteHeight(sceneSize: size) - (size.height - 96)
        #expect(StageLayout.backgroundLift(offset: 0, sceneSize: size, floorBase: 96) == 0)
        #expect(StageLayout.backgroundLift(offset: 0.05, sceneSize: size, floorBase: 96) == 0.05 * size.height)
        #expect(StageLayout.backgroundLift(offset: 5, sceneSize: size, floorBase: 96) == slack)
    }

    @Test("el visitante crece entre un 20 y un 30 % y su cuerpo guarda la proporción con el de un empleado")
    func visitorScaleKeepsTheProportion() {
        let before: CGFloat = 1.35
        let growth = StageLayout.actorScale / before - 1
        #expect(growth >= 0.2 && growth <= 0.3, "creció \(growth)")
        let employeeBody = StageLayout.employeeSideRatio * StageLayout.employeeCanvasBodyRatio
        let visitorBody = StageLayout.actorScale * StageLayout.visitorCanvasBodyRatio
        #expect(abs(visitorBody / employeeBody - StageLayout.visitorHeightRatio) < 0.001)
        #expect(visitorBody < employeeBody, "el visitante no supera a un empleado en la misma hilera")
        for (size, cell) in Self.screens {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            #expect(abs(layout.actorSide - cell * StageLayout.actorScale) < 0.001)
        }
    }

    @Test("el lado del arte del empleado espeja al nodo del tablero")
    @MainActor
    func employeeSideMirrorsTheNode() {
        #expect(abs(StageLayout.employeeSideRatio - 0.92 * CharacterNode.realArtScale) < 0.0001)
    }
}
