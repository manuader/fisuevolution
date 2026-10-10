import SpriteKit
import Testing
@testable import FisuEvolution

/// Los personajes se ordenan entre sí con `depthZ` (los de abajo tapan a los de
/// arriba, para que la multitud tenga profundidad), y los fondos de los pisos se
/// ordenan entre sí con `FloorNode.backgroundZ`. Son dos escalas distintas que
/// **no pueden tocarse**: si el z de un personaje cae dentro de la banda de los
/// fondos, el fondo de su propio piso lo tapa y queda invisible pero clickeable
/// —el hit-testing es geométrico y no mira el z—.
///
/// Ya pasó: subir la franja de piso mandó la fila trasera a y≈156 cuando `depthZ`
/// cruzaba el cero en 148, así que los cuatro de atrás quedaron en z≈−0.08 contra
/// un fondo en 0.00. Medido en el simulador: la pill decía 9/10 y se dibujaban 6.
///
/// Se testea acá y no con una captura porque el veredicto es numérico y cubre
/// todos los pisos y todos los tamaños de pantalla de una, incluidos los que no
/// se pueden alcanzar a mano sin horas de partida.
@Suite("Profundidad: la multitud nunca cae detrás del fondo")
@MainActor
struct CrowdDepthTests {
    /// De la más chica que soporta la app a la más grande, iPad incluido.
    private let screens: [CGSize] = [
        CGSize(width: 320, height: 568),
        CGSize(width: 375, height: 667),
        CGSize(width: 390, height: 844),
        CGSize(width: 402, height: 874),
        CGSize(width: 430, height: 932),
        CGSize(width: 440, height: 956),
        CGSize(width: 744, height: 1133),
        CGSize(width: 1032, height: 1376),
    ]
    /// Los de hoy (10), los de la crítica de Marco (15) y el permanente de ORO (20).
    private let capacities = [10, 15, 20]

    /// El z más bajo que puede alcanzar un personaje en esa pantalla y capacidad.
    private func lowestCrowdZ(screen: CGSize, capacity: Int) -> CGFloat {
        let layout = PlayLayout(size: screen, capacity: capacity)
        let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: layout.cellSize, rows: layout.rows)
        return BoardScene.fieldBaseZ + BoardScene.depthZ(y: band.topY, rows: layout.rows, cellSize: layout.cellSize)
    }

    private func highestFloorZ() throws -> CGFloat {
        let content = try GameContentLoader.load(from: .main)
        return FloorNode.backgroundZ(ordinal: content.floorTable.floors.count - 1)
    }

    @Test("ningún personaje puede quedar detrás del fondo de su piso")
    func crowdNeverSinksBehindItsFloor() throws {
        let floorZ = try highestFloorZ()
        for capacity in capacities {
            for screen in screens {
                let lowestZ = lowestCrowdZ(screen: screen, capacity: capacity)
                #expect(
                    lowestZ > floorZ,
                    """
                    capacidad \(capacity) en \(screen.width)×\(screen.height): el personaje \
                    más atrás queda en z=\(lowestZ) y el fondo más alto en z=\(floorZ). \
                    Por debajo del fondo se vuelve invisible pero clickeable.
                    """
                )
            }
        }
    }

    /// Toda la base del campo tiene que quedar por encima de los fondos, no sólo
    /// el rango de `depthZ`: cualquier z que se le asigne a un nodo del campo
    /// —el arrastre, un valor transitorio— parte de esta base.
    @Test("la base del campo entero queda por encima de los fondos")
    func theWholeFieldSitsAboveTheBackgrounds() throws {
        #expect(BoardScene.fieldBaseZ > (try highestFloorZ()))
    }

    /// La profundidad entre personajes tiene que seguir funcionando: el de
    /// adelante (menor `y`) tapa al de atrás. Es lo que le da volumen a la
    /// multitud y lo que usa el hit-testing para elegir a quién tocaste.
    @Test("el de adelante sigue tapando al de atrás", arguments: [2, 3])
    func nearerCharactersStayInFront(rows: Int) {
        let cell: CGFloat = 74
        let band = BoardScene.crowdBand(sceneHeight: 874, cellSize: cell, rows: rows)
        let front = BoardScene.depthZ(y: band.frontY, rows: rows, cellSize: cell)
        let back = BoardScene.depthZ(y: band.frontY + band.rowDepth, rows: rows, cellSize: cell)
        #expect(front > back, "la fila delantera tiene que dibujarse sobre la trasera")
    }
}

/// La franja por la que camina la multitud llega hasta donde diga
/// `PlayLayout.crowdTopRatio(rows:)`. El deambular sale DERIVADO de la franja,
/// así que las filas la cubren entera y ningún personaje puede pasarse por arriba.
///
/// Los asserts van contra el knob y no contra un número, para que dialarlo sea
/// cambiar UNA constante y no perseguir tests.
@Suite("La franja de la multitud")
@MainActor
struct CrowdBandTests {
    private let screens: [CGSize] = [
        CGSize(width: 320, height: 568),
        CGSize(width: 402, height: 874),
        CGSize(width: 440, height: 956),
        CGSize(width: 1032, height: 1376),
    ]

    private func cellSize(screen: CGSize) -> CGFloat {
        PlayLayout(size: screen, capacity: 10).cellSize
    }

    @Test("el techo de la franja cae donde dice el knob", arguments: [2, 3, 4])
    func bandTopFollowsTheRatio(rows: Int) {
        for screen in screens {
            let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: cellSize(screen: screen), rows: rows)
            // `topY` va en coordenadas del campo, que arranca en `bottomInset`.
            let onScreen = band.topY + BoardScene.bottomInset
            let expected = screen.height * PlayLayout.crowdTopRatio(rows: rows)
            #expect(
                abs(onScreen - expected) < 0.5,
                "\(rows) filas en \(screen.height) de alto: el techo quedó en \(onScreen) y se esperaba \(expected)"
            )
        }
    }

    @Test("ningún personaje se pasa del techo de la franja", arguments: [2, 3, 4])
    func nobodyWandersPastTheTop(rows: Int) {
        for screen in screens {
            let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: cellSize(screen: screen), rows: rows)
            let backRowTop = band.frontY + band.rowDepth * CGFloat(rows - 1) + band.wanderRange / 2
            #expect(backRowTop <= band.topY + 0.001, "la fila trasera llega a \(backRowTop) y el techo es \(band.topY)")
        }
    }

    /// Con las filas separadas y un deambular chico, la multitud se ve como
    /// hileras y no como una multitud. Al derivar el deambular de la franja,
    /// lo que recorre cada fila se toca con lo que recorre la siguiente.
    @Test("las filas cubren la franja sin dejar un hueco entre ellas", arguments: [2, 3, 4])
    func rowsCoverTheBandWithoutGaps(rows: Int) {
        for screen in screens {
            let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: cellSize(screen: screen), rows: rows)
            let frontRowTop = band.frontY + band.wanderRange / 2
            let backRowBottom = band.frontY + band.rowDepth - band.wanderRange / 2
            #expect(frontRowTop >= backRowBottom - 0.001, "queda un hueco entre \(frontRowTop) y \(backRowBottom)")
        }
    }
}
