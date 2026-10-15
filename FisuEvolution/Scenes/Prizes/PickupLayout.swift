import CoreGraphics
import EconomyKit

/// Dónde se paran las cajas del Paquete y el colchón (E14 C10). Las cajas (E14b B22) y el colchón
/// (B24) caen en cualquier lugar de la superficie del piso: entre el horizonte y la barra de abajo,
/// lejos de los bordes, que son de la columna lateral (E7b), lejos uno del otro y de la zona por
/// donde camina el visitante. El colchón, además, en la mitad de adelante: atrás lo tapaban las
/// hileras (`GameState.placeMattressIfNeeded`).
struct PickupLayout: Equatable {
    /// El lado de una caja, en celdas: 0,62 × 1,85 (C10 pide entre +80 % y +100 %).
    static let sideRatio: CGFloat = 1.15
    /// Cuántas cajas se dibujan por piso: las demás esperan a que se abra una.
    static let maxVisibleBoxes = 3
    /// Lo que se deja libre sobre la línea de atrás, en lados de caja: la caja, el cartel LLENO y
    /// su rebote (la altura de la pila de tres que había antes de B22).
    static let headroomSides: CGFloat = 1.6
    /// Lo que se deja libre contra cada borde: el ancho de la columna de E7b (sello de
    /// 62 pt de toque y su margen), sin aire de más para que la caja entre en un SE.
    static let edgeClearance: CGFloat = 66
    /// Cuánto del ancho de la ficha del visitante es cuerpo: el resto es aire
    /// transparente del sprite, y no hace falta dejárselo libre. Medido sobre los PNG de
    /// `npcs.atlas`: 0,49–0,69 del lienzo (el sindicalista, con los brazos abiertos, 0,83).
    static let visitorBodyRatio: CGFloat = 0.65
    /// Nada sube más arriba de esta fracción del alto: más arriba queda bajo el HUD.
    static let maxTopRatio: CGFloat = 0.82
    /// El área de toque nunca baja de esto (HIG: 44; el dueño pidió ≥ 60).
    static let minTouchSide: CGFloat = 60
    /// La separación mínima entre dos cajas, en lados: de costado, una caja entera; de fondo, la
    /// mitad, porque una detrás de otra se ve escalonada y no encimada (E14b B22).
    static let boxGapSides: CGFloat = 1
    static let boxDepthGapSides: CGFloat = 0.5
    /// Por dónde camina el visitante (B20): el ancho de la pantalla y el fondo de la superficie
    /// (de 0 al frente a 1 en el horizonte). Al integrar se une con la zona de `StageLayout`.
    static let visitorWalkWidth: ClosedRange<CGFloat> = 0.35...0.65
    static let visitorWalkDepth: ClosedRange<Double> = 0.3...0.7
    /// Una caja sin lugar (sin asignar): atrás a la izquierda, donde se paraban siempre. La segunda
    /// y la tercera se corren a la derecha un lado de caja cada una (`packageFeet(at:unplacedIndex:)`).
    static let unplacedSpot = PackageSpot(x: 0, y: 1)

    let sceneSize: CGSize
    let bottomInset: CGFloat
    let cellSize: CGFloat
    /// El fondo del piso que se ve y su desplazamiento: de ellos sale el horizonte.
    var background: String?
    var backgroundOffset: Double = 0
    /// Dónde apoya el fondo su borde de abajo (`StageLayout.floorBottom`).
    var floorBottom: CGFloat?

    /// La superficie de un teléfono de referencia, con la barra de la app: con ella `GameState`
    /// sortea el lugar de una caja sin escena. Las fracciones viajan igual a cualquier pantalla.
    @MainActor
    static func reference(background: String?, backgroundOffset: Double) -> PickupLayout {
        PickupLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: BoardScene.bottomInset, cellSize: 72,
                     background: background, backgroundOffset: backgroundOffset, floorBottom: BoardScene.floorBottom)
    }

    /// El teléfono más chico que se soporta (el SE, 375 × 667, con la celda de su tablero de cinco
    /// columnas): el de menos fondo y menos ancho, donde la misma fracción encima antes.
    @MainActor
    static func smallest(background: String?, backgroundOffset: Double) -> PickupLayout {
        PickupLayout(sceneSize: CGSize(width: 375, height: 667), bottomInset: BoardScene.bottomInset, cellSize: 68,
                     background: background, backgroundOffset: backgroundOffset, floorBottom: BoardScene.floorBottom)
    }

    /// Las superficies donde un lugar tiene que quedar libre (E14b B22): el teléfono de referencia y
    /// el más chico. Las fracciones se estiran distinto en cada pantalla: dos cajas separadas sólo
    /// por el fondo en la de referencia se enciman en el SE si no se mira también el SE.
    @MainActor
    static func placementAreas(background: String?, backgroundOffset: Double) -> [PackageFloorArea] {
        [reference(background: background, backgroundOffset: backgroundOffset).packageArea,
         smallest(background: background, backgroundOffset: backgroundOffset).packageArea]
    }

    private var stage: StageLayout {
        StageLayout(sceneSize: sceneSize, bottomInset: bottomInset, cellSize: cellSize, floorBottom: floorBottom)
    }

    var side: CGFloat { cellSize * Self.sideRatio }

    /// La línea de atrás, donde apoyan el colchón y las cajas del fondo: la línea del suelo
    /// (`StageLayout.groundY`, que ya queda arriba de las solapas de la barra) `walkDrop` más abajo,
    /// como los pies de un visitante (B17). Si con `headroomSides` el tope pasaría de `maxTopRatio`,
    /// primero baja lo justo y después el mismo `walkDrop`: el corrimiento vale también con los
    /// topes del SE.
    var baselineY: CGFloat {
        let ground = stage.groundY(background: background, backgroundOffset: backgroundOffset)
        let ceiling = sceneSize.height * Self.maxTopRatio - side * Self.headroomSides - 0.5
        return max(stage.groundFloorY, min(ground, ceiling) - StageLayout.walkDrop)
    }

    // MARK: - La superficie de las cajas (E14b B22)

    /// Por dónde puede pararse el centro de una caja de costado: de columna a columna.
    var packageXRange: ClosedRange<CGFloat> {
        let lower = Self.edgeClearance + side / 2
        let upper = sceneSize.width - Self.edgeClearance - side / 2
        return upper > lower ? lower...upper : sceneSize.width / 2...sceneSize.width / 2
    }

    /// Dónde pueden apoyar los pies de una caja de fondo: del frente (arriba de la barra) a la
    /// línea de atrás. Con el horizonte bajo (el SE) es una sola línea.
    var packageFeetRange: ClosedRange<CGFloat> {
        min(stage.groundFloorY, baselineY)...baselineY
    }

    /// Dónde apoya la caja del lugar `spot`. Fuera de 0...1 se queda en el borde. Sin lugar,
    /// `unplacedSpot` corrida `unplacedIndex` lados de caja a la derecha (la enésima sin asignar del
    /// piso), sin pasar el borde: así no se enciman.
    func packageFeet(at spot: PackageSpot?, unplacedIndex: Int = 0) -> CGPoint {
        let xs = packageXRange
        let ys = packageFeetRange
        let width = xs.upperBound - xs.lowerBound
        guard let spot else {
            let shift = min(width, CGFloat(max(0, unplacedIndex)) * side * Self.boxGapSides)
            return CGPoint(x: xs.lowerBound + CGFloat(Self.unplacedSpot.x) * width + shift,
                           y: ys.lowerBound + CGFloat(Self.unplacedSpot.y) * (ys.upperBound - ys.lowerBound))
        }
        let x = CGFloat(min(max(spot.x, 0), 1))
        let y = CGFloat(min(max(spot.y, 0), 1))
        return CGPoint(x: xs.lowerBound + x * width,
                       y: ys.lowerBound + y * (ys.upperBound - ys.lowerBound))
    }

    /// El centro de la caja del lugar `spot`: medio lado arriba de sus pies.
    func packagePosition(at spot: PackageSpot?) -> CGPoint {
        let feet = packageFeet(at: spot)
        return CGPoint(x: feet.x, y: feet.y + side / 2)
    }

    /// Las reglas de la caída en las fracciones de la superficie: la separación entre cajas y la zona
    /// de caminata del visitante. El colchón ya no tiene un lugar fijo: ocupa el suyo como una caja
    /// más (`PackageFloorArea.keepingClear(of:)`, B24).
    var packageArea: PackageFloorArea {
        let xs = packageXRange
        let ys = packageFeetRange
        let width = xs.upperBound - xs.lowerBound
        let depth = ys.upperBound - ys.lowerBound
        guard width > 0 else { return .open }
        let gapX = Double(side * Self.boxGapSides / width)
        // Sin fondo (una sola línea) la y no separa: sólo cuenta el costado.
        let gapY = depth > 0 ? Double(side * Self.boxDepthGapSides / depth) : .infinity
        let fraction = { (x: CGFloat) in Double((x - xs.lowerBound) / width) }
        let walk = sceneSize.width * Self.visitorWalkWidth.lowerBound...sceneSize.width * Self.visitorWalkWidth.upperBound
        // El centro de una caja no cae en la zona de caminata; el borde sí puede asomar: en un SE
        // la zona más media caja de cada lado ocupa todo el ancho.
        let visitor = PackageFloorArea.Zone(x: fraction(walk.lowerBound)...fraction(walk.upperBound),
                                            y: depth > 0 ? Self.visitorWalkDepth : 0...1)
        return PackageFloorArea(gapX: gapX, gapY: gapY, keepOut: [visitor])
    }
}
