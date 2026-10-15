import CoreGraphics
import EconomyKit
import Testing
@testable import FisuEvolution

/// Dónde se paran las cajas y el colchón (E14 C10): grandes, ni bajo la columna de E7b ni bajo las
/// solapas de la barra, ni encima de quien está en escena. Desde E14b B22 las cajas van en cualquier
/// lugar de la superficie del piso, entre el frente y la línea de atrás.
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

    /// Los cuatro rincones de la superficie y el medio.
    private static let spots = [
        PackageSpot(x: 0, y: 0), PackageSpot(x: 1, y: 0), PackageSpot(x: 0, y: 1), PackageSpot(x: 1, y: 1),
        PackageSpot(x: 0.5, y: 0.5),
    ]

    @Test("las cajas lejos de las columnas de los dos bordes; el colchón al costado del visitante")
    func clearOfTheEdgesAndTheVisitor() {
        for (size, cell) in Self.screens {
            let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let visitorRight = stage.standX + stage.actorSide * PickupLayout.visitorBodyRatio / 2
            for spot in Self.spots {
                let box = layout.packagePosition(at: spot)
                #expect(box.x - layout.side / 2 >= PickupLayout.edgeClearance - 0.001, "\(size) \(spot): bajo la columna izquierda")
                #expect(box.x + layout.side / 2 <= size.width - PickupLayout.edgeClearance + 0.001, "\(size) \(spot): bajo la columna derecha")
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
                    let headroomTop = ground + layout.side * PickupLayout.headroomSides
                    let label = "\(size) \(background ?? "-") \(String(describing: floorBottom))"
                    #expect(layout.baselineY <= horizon + 0.5, "\(label): flota sobre el horizonte")
                    if headroomTop < size.height * PickupLayout.maxTopRatio - 0.5 {
                        #expect(abs(layout.packageFeet(at: PackageSpot(x: 0, y: 1)).y - horizon) < 0.5, "\(label): la de atrás, en el horizonte")
                        #expect(abs(layout.baselineY - horizon) < 0.5, "\(label)")
                    } else {
                        #expect(layout.baselineY + layout.side * PickupLayout.headroomSides <= size.height * PickupLayout.maxTopRatio, "\(label): pasa del tope")
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

    @Test("nada queda bajo las solapas de la barra y la caja de atrás se ve entera")
    @MainActor
    func clearOfTheBarAndTheTopOfTheScreen() {
        for (size, cell) in Self.screens {
            for background in Self.backgrounds {
                let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: background)
                let barTop = GameTabBar.barHeight + (118 - GameTabBar.panelHeight)
                #expect(layout.baselineY >= barTop + 8, "\(size) \(background ?? "-"): la caja toca la barra")
                #expect(layout.packageFeetRange.lowerBound >= barTop + 8, "\(size) \(background ?? "-"): la de adelante toca la barra")
                let top = layout.packagePosition(at: PackageSpot(x: 0, y: 1)).y + layout.side / 2
                #expect(top < size.height * 0.82, "\(size) \(background ?? "-"): la caja sube hasta \(top)")
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
                #expect(layout.packagePosition(at: PackageSpot(x: 0, y: 1)).y + layout.side / 2 < size.height * PickupLayout.maxTopRatio)
                #expect(layout.packageFeetRange.lowerBound >= 118 + cell - 0.001, "\(size) \(background): la de adelante toca la barra")
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
                    let ceiling = size.height * PickupLayout.maxTopRatio - layout.side * PickupLayout.headroomSides - 0.5
                    let label = "\(size) \(background) \(String(describing: floorBottom))"
                    if layout.baselineY > stage.groundFloorY {
                        #expect(abs(min(ground, ceiling) - layout.baselineY - StageLayout.walkDrop) < 0.001, "\(label): bajó \(min(ground, ceiling) - layout.baselineY)")
                    }
                    #expect(layout.baselineY >= stage.floorBase, "\(label): la caja pasa debajo de floorBottom")
                    #expect(layout.packageFeetRange.lowerBound >= stage.floorBase - 0.001)
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

    // MARK: - E14b B22: la superficie de las cajas

    private static func close(_ a: CGPoint, _ b: CGPoint) -> Bool {
        abs(a.x - b.x) < 0.001 && abs(a.y - b.y) < 0.001
    }

    @Test("la superficie va de columna a columna y del frente a la línea de atrás; fuera de 0…1 se queda en el borde")
    func theSurfaceSpansTheFloor() {
        for (size, cell) in Self.screens {
            for background in Self.backgrounds {
                let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: background, floorBottom: 96)
                let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell, floorBottom: 96)
                let xs = layout.packageXRange
                let ys = layout.packageFeetRange
                let label = "\(size) \(background ?? "-")"
                #expect(abs(xs.lowerBound - (PickupLayout.edgeClearance + layout.side / 2)) < 0.001, "\(label)")
                #expect(abs(xs.upperBound - (size.width - PickupLayout.edgeClearance - layout.side / 2)) < 0.001, "\(label)")
                #expect(ys.upperBound == layout.baselineY, "\(label): atrás, la línea del horizonte")
                #expect(ys.lowerBound == min(stage.groundFloorY, layout.baselineY), "\(label): adelante, arriba de la barra")
                #expect(Self.close(layout.packageFeet(at: PackageSpot(x: 0, y: 0)), CGPoint(x: xs.lowerBound, y: ys.lowerBound)))
                #expect(Self.close(layout.packageFeet(at: PackageSpot(x: 1, y: 1)), CGPoint(x: xs.upperBound, y: ys.upperBound)))
                #expect(Self.close(layout.packageFeet(at: PackageSpot(x: 5, y: -2)), CGPoint(x: xs.upperBound, y: ys.lowerBound)))
                #expect(layout.packageFeet(at: nil) == layout.packageFeet(at: PickupLayout.unplacedSpot), "sin lugar, atrás a la izquierda")
                let center = layout.packagePosition(at: PackageSpot(x: 0.3, y: 0.6))
                #expect(abs(center.y - layout.packageFeet(at: PackageSpot(x: 0.3, y: 0.6)).y - layout.side / 2) < 0.001)
            }
        }
    }

    @Test("las reglas de la caída: la separación es de un lado de costado y medio de fondo, en fracciones de la superficie")
    func theAreaGapIsOneSide() {
        for (size, cell) in Self.screens {
            let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: "alley", floorBottom: 96)
            let area = layout.packageArea
            let width = layout.packageXRange.upperBound - layout.packageXRange.lowerBound
            let depth = layout.packageFeetRange.upperBound - layout.packageFeetRange.lowerBound
            #expect(abs(area.gapX * Double(width) - Double(layout.side)) < 0.001, "\(size)")
            if depth > 0 {
                #expect(abs(area.gapY * Double(depth) - Double(layout.side * PickupLayout.boxDepthGapSides)) < 0.001, "\(size)")
            } else {
                #expect(area.gapY == .infinity, "\(size): sin fondo sólo separa el costado")
            }
        }
    }

    @Test("el centro de ninguna caja cae en la zona de caminata del visitante, ni la caja sobre el colchón")
    func boxesStayOffTheWalkAndTheMattress() {
        for (size, cell) in Self.screens {
            let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell, background: "alley", floorBottom: 96)
            let area = layout.packageArea
            let depth = layout.packageFeetRange.upperBound - layout.packageFeetRange.lowerBound
            var rng = SystemRandomNumberGenerator()
            for _ in 0..<200 {
                let spot = PackagePlacer.place(among: [], in: area, using: &rng)
                let box = layout.packagePosition(at: spot)
                let inWalkDepth = depth <= 0 || PickupLayout.visitorWalkDepth.contains(spot.y)
                let walk = size.width * PickupLayout.visitorWalkWidth.lowerBound...size.width * PickupLayout.visitorWalkWidth.upperBound
                if inWalkDepth {
                    #expect(box.x <= walk.lowerBound + 0.5 || box.x >= walk.upperBound - 0.5,
                            "\(size) \(spot): la caja cae en la zona de caminata")
                }
                #expect(abs(box.x - layout.mattressX) >= layout.side - 0.5 || spot.y < 1 - min(1, area.gapY),
                        "\(size) \(spot): la caja pisa el colchón")
            }
        }
    }

    @Test("el teléfono de referencia de GameState es el tablero de la app")
    @MainActor
    func theReferenceIsTheAppBoard() {
        let reference = PickupLayout.reference(background: "urban", backgroundOffset: 0.02)
        #expect(reference == PickupLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: BoardScene.bottomInset,
                                          cellSize: 72, background: "urban", backgroundOffset: 0.02, floorBottom: BoardScene.floorBottom))
    }
}
