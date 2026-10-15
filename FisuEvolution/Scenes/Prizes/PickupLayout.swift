import CoreGraphics

/// Dónde se paran las cajas del Paquete y el colchón (E14 C10): sobre la línea del
/// horizonte del fondo del piso, la misma donde se para un visitante
/// (`StageLayout.standY`), no pegadas a la barra de abajo, donde las tapaban las
/// solapas de Contratar y Reencarnar. Van a los costados del visitante parado en el
/// medio y lejos de los bordes, que son de la columna lateral (E7b).
struct PickupLayout: Equatable {
    /// El lado de una caja, en celdas: 0,62 × 1,85 (C10 pide entre +80 % y +100 %).
    static let sideRatio: CGFloat = 1.15
    /// Cada caja de más se apila encima, montada sobre la de abajo.
    static let stackStep: CGFloat = 0.3
    static let maxVisibleBoxes = 3
    /// Lo que se deja libre contra cada borde: el ancho de la columna de E7b (sello de
    /// 62 pt de toque y su margen), sin aire de más para que la caja entre en un SE.
    static let edgeClearance: CGFloat = 66
    /// Cuánto del ancho de la ficha del visitante es cuerpo: el resto es aire
    /// transparente del sprite, y no hace falta dejárselo libre. Medido sobre los PNG de
    /// `npcs.atlas`: 0,49–0,69 del lienzo (el sindicalista, con los brazos abiertos, 0,83).
    static let visitorBodyRatio: CGFloat = 0.65
    /// La pila de cajas no sube más arriba de esta fracción del alto: más arriba queda bajo el HUD.
    static let maxTopRatio: CGFloat = 0.82
    /// El área de toque nunca baja de esto (HIG: 44; el dueño pidió ≥ 60).
    static let minTouchSide: CGFloat = 60

    let sceneSize: CGSize
    let bottomInset: CGFloat
    let cellSize: CGFloat
    /// El fondo del piso que se ve y su desplazamiento: de ellos sale el horizonte.
    var background: String?
    var backgroundOffset: Double = 0
    /// Dónde apoya el fondo su borde de abajo (`StageLayout.floorBottom`).
    var floorBottom: CGFloat?

    private var stage: StageLayout {
        StageLayout(sceneSize: sceneSize, bottomInset: bottomInset, cellSize: cellSize, floorBottom: floorBottom)
    }

    var side: CGFloat { cellSize * Self.sideRatio }
    /// Lo que sube la pila entera de cajas sobre su línea de apoyo.
    private var stackHeight: CGFloat { side * (1 + CGFloat(Self.maxVisibleBoxes - 1) * Self.stackStep) }
    /// Donde apoyan las cajas y el colchón: la línea del suelo (`StageLayout.groundY`, que ya queda
    /// arriba de las solapas de la barra) `walkDrop` más abajo, como los pies de un visitante
    /// (B17). Si con la pila llena el tope pasaría de `maxTopRatio`, primero baja lo justo y
    /// después el mismo `walkDrop`: el corrimiento vale también con los topes del SE.
    var baselineY: CGFloat {
        let ground = stage.groundY(background: background, backgroundOffset: backgroundOffset)
        let ceiling = sceneSize.height * Self.maxTopRatio - stackHeight - 0.5
        return max(stage.groundFloorY, min(ground, ceiling) - StageLayout.walkDrop)
    }

    /// Lo que ocupa el cuerpo del visitante parado en el medio.
    private var visitorSpan: ClosedRange<CGFloat> {
        let half = stage.actorSide * Self.visitorBodyRatio / 2
        return (stage.standX - half)...(stage.standX + half)
    }

    /// Las cajas, en el hueco entre la columna izquierda y el visitante.
    var packageX: CGFloat { (Self.edgeClearance + visitorSpan.lowerBound) / 2 }
    /// El colchón, en el hueco entre el visitante y el borde derecho.
    var mattressX: CGFloat { (visitorSpan.upperBound + sceneSize.width - Self.edgeClearance) / 2 }

    func packagePosition(index: Int) -> CGPoint {
        CGPoint(x: packageX, y: baselineY + side / 2 + CGFloat(index) * side * Self.stackStep)
    }

    var mattressPosition: CGPoint {
        CGPoint(x: mattressX, y: baselineY + side * 0.35)
    }
}
