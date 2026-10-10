import CoreGraphics

/// Dónde se paran las cajas del Paquete y el colchón: abajo, sobre la línea del
/// escenario (E4b), a los costados de donde se para un visitante y lejos de los
/// bordes, que son de la columna lateral (E7b) y de la botonera (E3a).
struct PickupLayout: Equatable {
    static let packageXRatio: CGFloat = 0.31
    static let mattressXRatio: CGFloat = 0.69
    /// El lado de una caja, en celdas.
    static let sideRatio: CGFloat = 0.62
    /// Cada caja de más se apila encima, montada sobre la de abajo.
    static let stackStep: CGFloat = 0.55
    static let maxVisibleBoxes = 3
    /// Lo que se deja libre contra cada borde: el ancho de la columna de E7b, con aire.
    static let edgeClearance: CGFloat = 72

    let sceneSize: CGSize
    let bottomInset: CGFloat
    let cellSize: CGFloat

    var side: CGFloat { cellSize * Self.sideRatio }
    /// La misma línea que pisa un visitante (`StageLayout.baselineY`).
    var baselineY: CGFloat { bottomInset + cellSize * 0.25 }

    func packagePosition(index: Int) -> CGPoint {
        CGPoint(x: sceneSize.width * Self.packageXRatio,
                y: baselineY + side / 2 + CGFloat(index) * side * Self.stackStep)
    }

    var mattressPosition: CGPoint {
        CGPoint(x: sceneSize.width * Self.mattressXRatio, y: baselineY + side * 0.35)
    }
}
