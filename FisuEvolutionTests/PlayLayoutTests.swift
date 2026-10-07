import CoreGraphics
import Testing
@testable import FisuEvolution

/// La geometría del tablero en cualquier pantalla (PLAN-v2 E3).
///
/// ⚠️ `iPhoneIsTheV1Layout` es el golden: escribe a mano los números de la v1
/// (dos filas, cinco columnas, la celda al ancho y el campo a 16 pt del borde).
/// Si se pone rojo, cambió el juego en todos los iPhone.
@Suite("PlayLayout: el tablero en cualquier pantalla")
struct PlayLayoutTests {
    /// Los seis iPhone que soporta la app, del más chico al más grande.
    static let phones: [CGSize] = [
        CGSize(width: 320, height: 568),
        CGSize(width: 375, height: 667),
        CGSize(width: 390, height: 844),
        CGSize(width: 402, height: 874),
        CGSize(width: 430, height: 932),
        CGSize(width: 440, height: 956),
    ]

    /// Los dos iPad y dos ventanas que no son de ningún dispositivo: con el SDK
    /// de iOS 27 `UIRequiresFullScreen` se ignora y la app puede vivir en una.
    static let wide: [CGSize] = [
        CGSize(width: 744, height: 1133),
        CGSize(width: 1032, height: 1376),
        CGSize(width: 500, height: 800),
        CGSize(width: 700, height: 1000),
    ]

    @Test("en iPhone, con 10 lugares, es exactamente el layout de la v1", arguments: phones)
    func iPhoneIsTheV1Layout(size: CGSize) {
        let layout = PlayLayout(size: size, capacity: 10)
        #expect(layout.rows == 2)
        #expect(layout.columns == 5)
        #expect(abs(layout.cellSize - (size.width - 32) / 5) < 0.001)
        #expect(abs(layout.fieldX - 16) < 0.001)
        #expect(layout.textScale == 1)
        #expect(layout.crowdTopRatio == 0.44)
    }

    @Test("en pantallas anchas la celda tiene tope y el campo va centrado", arguments: wide)
    func wideScreensCapTheCellAndCenterTheField(size: CGSize) {
        let layout = PlayLayout(size: size, capacity: 10)
        #expect(layout.cellSize <= PlayLayout.maxCellSize)
        #expect(layout.fieldX >= PlayLayout.horizontalInset - 0.001)
        #expect(abs(layout.fieldX * 2 + layout.fieldWidth - size.width) < 0.001, "centrado")
        #expect(layout.textScale == PlayLayout.wideTextScale)
    }

    /// El sprite mide ~2 celdas (`CharacterNode`): con el tope, en el iPad 13"
    /// ocupa la misma fracción del alto que en el 16 Pro.
    @Test("en el iPad 13\" el personaje ocupa el 16,5 % del alto, como en el 16 Pro")
    func iPadCharacterMatchesTheSixteenPro() {
        let ipad = PlayLayout(size: CGSize(width: 1032, height: 1376), capacity: 10)
        let phone = PlayLayout(size: CGSize(width: 402, height: 874), capacity: 10)
        let ipadShare = ipad.cellSize * 2 / 1376
        let phoneShare = phone.cellSize * 2 / 874
        #expect(abs(ipadShare - 0.165) < 0.005)
        #expect(abs(ipadShare - phoneShare) < 0.01)
    }

    @Test("la capacidad decide las filas: 10 son dos, 15 son tres y 20 son cuatro",
          arguments: [(10, 2, 5), (15, 3, 5), (20, 4, 5), (8, 2, 4), (5, 2, 3), (1, 2, 1)])
    func capacityDrivesTheRows(capacity: Int, rows: Int, columns: Int) {
        let layout = PlayLayout(size: CGSize(width: 402, height: 874), capacity: capacity)
        #expect(layout.rows == rows)
        #expect(layout.columns == columns)
    }

    @Test("la multitud: 0,44 del alto con dos filas (la v1) y 0,63 con tres o más")
    func crowdHeightFollowsTheRows() {
        #expect(PlayLayout.crowdTopRatio(rows: 2) == 0.44)
        #expect(PlayLayout.crowdTopRatio(rows: 3) == 0.63)
        #expect(PlayLayout.crowdTopRatio(rows: 4) == 0.63)
    }

    @Test("el tope de la foto del reveal nunca se alcanza en iPhone")
    func revealCapIsInvisibleOnPhones() {
        // `BoardScene.revealLayout` usa `min(ancho × 0,82, alto × 0,52)`: en el
        // iPhone más ancho eso da 360,8, por debajo del tope.
        #expect(440 * 0.82 < PlayLayout.revealMaxSide)
    }

    @Test("el marcador del test de UI dice columnas, filas, celda y escala")
    func markerFormat() {
        #expect(PlayLayout(size: CGSize(width: 1032, height: 1376), capacity: 15).marker == "5x3@112·1.25")
        #expect(PlayLayout(size: CGSize(width: 402, height: 874), capacity: 10).marker == "5x2@74·1.0")
    }
}
