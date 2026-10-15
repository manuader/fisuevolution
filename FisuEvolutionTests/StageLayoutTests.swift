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

    // MARK: - E14b B17: los que caminan por el medio, 20 pt más abajo

    @Test("quien camina por el medio pisa 20 pt debajo de la línea de las hileras, sin bajar de la barra")
    func walkersDropBelowTheGround() {
        #expect(StageLayout.walkDrop == 20)
        for (size, cell) in Self.screens {
            for floorBottom in Self.floorBottoms {
                let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: floorBottom)
                for background in StageLayout.horizons.keys {
                    for offset in [0, 0.05] {
                        let ground = layout.groundY(background: background, backgroundOffset: offset)
                        let stand = layout.standY(background: background, backgroundOffset: offset)
                        let label = "\(size) \(background) \(offset) \(String(describing: floorBottom))"
                        if ground - StageLayout.walkDrop >= layout.groundFloorY {
                            #expect(abs(ground - stand - StageLayout.walkDrop) < 0.001, "\(label): bajó \(ground - stand)")
                        } else {
                            #expect(stand == layout.groundFloorY, "\(label): pasó bajo la barra")
                        }
                        #expect(stand >= layout.floorBase, "\(label): pasó debajo de floorBottom")
                        #expect(stand >= 118 + cell, "\(label): pisa la barra")
                        #expect(stand + layout.actorSide < size.height * StageLayout.maxHeadRatio, "\(label): la cabeza llega al HUD")
                    }
                }
            }
        }
    }

    @Test("con el tope de la cabeza del SE (moon, mars, galaxy) el corrimiento se mantiene")
    func walkDropHoldsUnderTheSECeiling() {
        let layout = StageLayout(sceneSize: CGSize(width: 375, height: 667), bottomInset: 118, cellSize: 68, floorBottom: 96)
        for background in ["moon", "mars", "galaxy"] {
            let ground = layout.groundY(background: background)
            #expect(abs(ground - layout.standY(background: background) - StageLayout.walkDrop) < 0.001, "\(background)")
        }
    }

    // MARK: - E14b B20: en el medio del piso, caminando por la franja central

    /// El SE y el Pro Max, con la barra que usa la app (`BoardScene.floorBottom`).
    private static let phones: [(String, CGSize, CGFloat)] = [
        ("SE", CGSize(width: 375, height: 667), 68),
        ("Pro Max", CGSize(width: 440, height: 956), 81),
    ]

    @Test("el visitante pisa el medio del piso: entre el suelo de las hileras y la barra, en los diez fondos")
    func visitorStandsMidFloor() {
        for (name, size, cell) in Self.phones {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: 96)
            for background in StageLayout.horizons.keys {
                let ground = layout.groundY(background: background)
                let feet = layout.visitorY(background: background)
                let label = "\(name) \(background)"
                #expect(abs(feet - max(layout.groundFloorY, (ground + layout.floorBase) / 2)) < 0.001, "\(label)")
                #expect(feet < layout.standY(background: background), "\(label): no bajó de la línea de B17")
                #expect(feet >= 118 + cell, "\(label): pisa la barra")
                #expect(feet < ground, "\(label): los pies, en el piso y no en la línea de las cabezas")
                #expect(feet + layout.actorSide < size.height * StageLayout.maxHeadRatio, "\(label): la cabeza llega al HUD")
            }
        }
    }

    @Test("sin nada en las esquinas camina del 35 al 65 % del ancho, centrado")
    func walkZoneWithoutCorners() {
        for (name, size, cell) in Self.phones {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: 96)
            let zone = layout.walkRange(feetY: layout.visitorY(background: "alley"), corners: [])
            #expect(abs(zone.lowerBound - size.width * 0.35) < 0.001, "\(name)")
            #expect(abs(zone.upperBound - size.width * 0.65) < 0.001, "\(name)")
            #expect(zone.contains(layout.standX), "\(name): llega al medio y de ahí camina")
        }
    }

    /// Las esquinas en el peor caso (`SideRailUITests`, D14): a la izquierda, cuatro sellos con su
    /// cinta; a la derecha, la tarjeta del especial, el sello de la oferta, cuatro boosts («Paquetes
    /// ×10» con su reloj) y el «+N». Medidas a ojo de las vistas, con aire.
    private static func worstCorners(screen: CGSize) -> [CGRect] {
        let hudBottom: CGFloat = screen.height > 800 ? 150 : 110
        let left = CGRect(x: 4, y: hudBottom, width: 62, height: 4 * 82)
        let right = CGRect(x: screen.width - 4 - 150, y: hudBottom, width: 150, height: 62 + 66 + 4 * 46 + 44)
        return [left, right]
    }

    @Test("la zona de caminata no toca los chips de las esquinas, en el SE y el Pro Max y los diez fondos")
    func walkZoneClearsTheCorners() {
        for (name, size, cell) in Self.phones {
            let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: 96)
            let corners = Self.worstCorners(screen: size)
            let half = layout.actorSide * StageLayout.walkBodyRatio / 2
            for background in StageLayout.horizons.keys {
                let feet = layout.visitorY(background: background)
                let zone = layout.walkRange(feetY: feet, corners: corners)
                let label = "\(name) \(background)"
                #expect(zone.lowerBound >= size.width * StageLayout.walkZone.lowerBound - 0.001, "\(label)")
                #expect(zone.upperBound <= size.width * StageLayout.walkZone.upperBound + 0.001, "\(label)")
                let top = size.height - (feet + layout.actorSide)
                let bottom = size.height - feet
                for x in [zone.lowerBound, zone.upperBound] {
                    let body = CGRect(x: x - half, y: top, width: half * 2, height: bottom - top)
                    for corner in corners {
                        #expect(!body.intersects(corner), "\(label): en x = \(x) el cuerpo toca \(corner)")
                    }
                }
            }
        }
    }

    @Test("una esquina que no le queda a la altura del cuerpo no achica la zona")
    func cornersAboveDoNotShrinkTheZone() {
        let size = CGSize(width: 375, height: 667)
        let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: 68, floorBottom: 96)
        let feet = layout.visitorY(background: "alley")
        let head = size.height - (feet + layout.actorSide)
        let high = CGRect(x: size.width - 154, y: 110, width: 150, height: head - 110 - 1)
        #expect(layout.walkRange(feetY: feet, corners: [high]) == layout.walkRange(feetY: feet, corners: []))
    }

    @Test("si no entra, la zona se achica hasta un punto: nunca se encima")
    func noRoomCollapsesTheZone() {
        let size = CGSize(width: 375, height: 667)
        let layout = StageLayout(sceneSize: size, bottomInset: 118, cellSize: 68, floorBottom: 96)
        let feet = layout.visitorY(background: "alley")
        let wall = CGRect(x: 4, y: 0, width: 180, height: size.height)
        let other = CGRect(x: 190, y: 0, width: 180, height: size.height)
        let zone = layout.walkRange(feetY: feet, corners: [wall, other])
        #expect(zone.lowerBound == zone.upperBound)
    }

    @Test("la caminata de espera va y vuelve, dándose vuelta en los bordes, y vuelve caminando si quedó afuera")
    func strollTurnsAtTheEdges() {
        let range: ClosedRange<CGFloat> = 100...200
        var x: CGFloat = 150
        var heading: CGFloat = 1
        var turns = 0
        for _ in 0..<200 {
            let step = StageLayout.stroll(x: x, heading: heading, range: range, step: 3)
            if step.heading != heading { turns += 1 }
            x = step.x
            heading = step.heading
            #expect(range.contains(x))
        }
        #expect(turns >= 4, "se dio vuelta \(turns) veces")
        let outside = StageLayout.stroll(x: 260, heading: 1, range: range, step: 3)
        #expect(outside.x == 257 && outside.heading == -1, "vuelve caminando, sin saltar")
        let point = StageLayout.stroll(x: 150, heading: 1, range: 160...160, step: 3)
        #expect(point.x == 153)
        #expect(StageLayout.stroll(x: 160, heading: 1, range: 160...160, step: 3).x == 160, "y ahí se queda")
    }

    @Test("el lado del arte del empleado espeja al nodo del tablero")
    @MainActor
    func employeeSideMirrorsTheNode() {
        #expect(abs(StageLayout.employeeSideRatio - 0.92 * CharacterNode.realArtScale) < 0.0001)
    }
}
