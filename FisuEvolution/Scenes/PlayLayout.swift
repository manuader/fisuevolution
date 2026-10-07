import CoreGraphics

/// La geometría del tablero para una pantalla y un piso (PLAN-v2 E3).
///
/// Pura y sin SpriteKit: la escena la pide en `layoutBoard()` y los tests la
/// pinean sin levantar una escena. Junta lo que vivía suelto en `BoardScene`
/// —filas, columnas, celda, origen del campo— y suma lo del iPad: la celda con
/// tope y el campo centrado.
///
/// ⚠️ **En iPhone (ancho ≤ 440) y con 10 lugares da exactamente la v1**: dos
/// filas, cinco columnas, la celda al ancho y el campo a 16 pt del borde. Lo
/// pinea `PlayLayoutTests.iPhoneIsTheV1Layout`.
struct PlayLayout: Equatable {
    /// Hasta este ancho la pantalla es un teléfono (el 16/17 Pro Max mide 440).
    static let phoneMaxWidth: CGFloat = 440
    /// Tope de la celda. El sprite mide ~2 celdas: en el iPad 13" queda en
    /// ~224 pt, el 16,5 % del alto, como en el 16 Pro.
    static let maxCellSize: CGFloat = 112
    /// Margen lateral mínimo del campo.
    static let horizontalInset: CGFloat = 16
    /// Lugares por fila: 10 son dos filas, 15 son tres y 20 son cuatro.
    static let slotsPerRow = 5
    /// Los textos de SpriteKit en pantallas anchas.
    static let wideTextScale: CGFloat = 1.25
    /// Tope del lado de la foto del reveal. En iPhone no se alcanza nunca.
    static let revealMaxSide: CGFloat = 380

    let rows: Int
    let columns: Int
    let cellSize: CGFloat
    /// Borde izquierdo del campo, en coordenadas de escena.
    let fieldX: CGFloat
    let textScale: CGFloat
    /// Techo de la franja de la multitud, en fracción del alto de pantalla.
    let crowdTopRatio: CGFloat

    var fieldWidth: CGFloat { CGFloat(columns) * cellSize }

    init(size: CGSize, capacity: Int) {
        let rows = Self.rows(forCapacity: capacity)
        let columns = max(1, (capacity + rows - 1) / rows)
        let available = max(1, size.width - Self.horizontalInset * 2)
        let cell = min(available / CGFloat(columns), Self.maxCellSize)
        self.rows = rows
        self.columns = columns
        self.cellSize = cell
        self.fieldX = (size.width - CGFloat(columns) * cell) / 2
        self.textScale = size.width > Self.phoneMaxWidth ? Self.wideTextScale : 1
        self.crowdTopRatio = Self.crowdTopRatio(rows: rows)
    }

    /// Dos filas hasta 10 lugares (la v1) y una fila más cada cinco.
    static func rows(forCapacity capacity: Int) -> Int {
        max(2, (capacity + slotsPerRow - 1) / slotsPerRow)
    }

    /// El knob del alto de la multitud. Con dos filas sigue en el 0,44 de la v1;
    /// con tres o más sube al 0,63 que pidió la crítica de Marco (PLAN-v2 §2).
    ///
    /// ⚠️ 0,63 y no el ~0,70 del plan: medido en el spike S5, con 0,70 las
    /// cabezas de la fila de atrás entran 42 pt en el display del ascensor del
    /// iPhone SE, que admite hasta 0,637.
    static func crowdTopRatio(rows: Int) -> CGFloat {
        rows <= 2 ? 0.44 : 0.63
    }

    /// Lo que publica el marcador `board.layout`: "5x3@112·1.25".
    var marker: String {
        "\(columns)x\(rows)@\(Int(cellSize.rounded()))·\(textScale)"
    }
}
