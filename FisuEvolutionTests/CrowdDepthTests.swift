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
    /// De la más chica que soporta la app a la más grande.
    private let screens: [CGSize] = [
        CGSize(width: 320, height: 568),
        CGSize(width: 375, height: 667),
        CGSize(width: 390, height: 844),
        CGSize(width: 402, height: 874),
        CGSize(width: 430, height: 932),
        CGSize(width: 440, height: 956),
    ]
    private let horizontalInset: CGFloat = 16
    private let rows = 2

    private func cellSize(screenWidth: CGFloat, capacity: Int) -> CGFloat {
        let columns = max(1, (capacity + rows - 1) / rows)
        return (screenWidth - horizontalInset * 2) / CGFloat(columns)
    }

    /// El z más bajo que puede alcanzar un personaje en ese piso y pantalla.
    private func lowestCrowdZ(screen: CGSize, capacity: Int) -> CGFloat {
        let cell = cellSize(screenWidth: screen.width, capacity: capacity)
        let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: cell, rows: rows)
        return BoardScene.fieldBaseZ + BoardScene.depthZ(y: band.topY, rows: rows, cellSize: cell)
    }

    @Test("ningún personaje puede quedar detrás del fondo de su piso")
    func crowdNeverSinksBehindItsFloor() throws {
        let content = try GameContentLoader.load(from: .main)
        let floors = content.floorTable.floors
        // El piso más alto es el fondo que llega más arriba en la banda de z.
        let highestFloorZ = FloorNode.backgroundZ(ordinal: floors.count - 1)

        for floor in floors {
            for screen in screens {
                let lowestZ = lowestCrowdZ(screen: screen, capacity: floor.capacity)
                #expect(
                    lowestZ > highestFloorZ,
                    """
                    piso \(floor.id) en \(screen.width)×\(screen.height): el personaje \
                    más atrás queda en z=\(lowestZ) y el fondo más alto en \
                    z=\(highestFloorZ). Por debajo del fondo se vuelve invisible \
                    pero clickeable.
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
        let content = try GameContentLoader.load(from: .main)
        let highestFloorZ = FloorNode.backgroundZ(ordinal: content.floorTable.floors.count - 1)
        #expect(BoardScene.fieldBaseZ > highestFloorZ)
    }

    /// Los specials son decorado: van detrás de la multitud entera, pero delante
    /// de los fondos. Su z sale de la franja justamente porque una constante
    /// fija se queda corta apenas la franja se agranda.
    @Test("los specials quedan detrás de la multitud y delante del fondo")
    func specialsSitBetweenTheFloorAndTheCrowd() throws {
        let content = try GameContentLoader.load(from: .main)
        let highestFloorZ = FloorNode.backgroundZ(ordinal: content.floorTable.floors.count - 1)

        for floor in content.floorTable.floors {
            for screen in screens {
                let cell = cellSize(screenWidth: screen.width, capacity: floor.capacity)
                let band = BoardScene.crowdBand(sceneHeight: screen.height, cellSize: cell, rows: rows)
                let specialZ = BoardScene.fieldBaseZ
                    + BoardScene.specialZ(band: band, rows: rows, cellSize: cell)
                #expect(specialZ < lowestCrowdZ(screen: screen, capacity: floor.capacity))
                #expect(specialZ > highestFloorZ, "un special tampoco puede irse detrás del fondo")
            }
        }
    }

    /// La profundidad entre personajes tiene que seguir funcionando: el de
    /// adelante (menor `y`) tapa al de atrás. Es lo que le da volumen a la
    /// multitud y lo que usa el hit-testing para elegir a quién tocaste.
    @Test("el de adelante sigue tapando al de atrás")
    func nearerCharactersStayInFront() {
        let cell: CGFloat = 74
        let band = BoardScene.crowdBand(sceneHeight: 874, cellSize: cell, rows: rows)
        let front = BoardScene.depthZ(y: band.frontY, rows: rows, cellSize: cell)
        let back = BoardScene.depthZ(y: band.frontY + band.rowDepth, rows: rows, cellSize: cell)
        #expect(front > back, "la fila delantera tiene que dibujarse sobre la trasera")
    }
}

/// La franja por la que camina la multitud llega hasta donde diga
/// `crowdTopRatio`. El deambular sale DERIVADO de la franja, así que las dos
/// filas la cubren entera y ningún personaje puede pasarse por arriba.
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
    ]
    private let rows = 2

    private func cellSize(screenWidth: CGFloat) -> CGFloat {
        (screenWidth - 32) / 5
    }

    @Test("el techo de la franja cae donde dice el knob")
    func bandTopFollowsTheRatio() {
        for screen in screens {
            let band = BoardScene.crowdBand(
                sceneHeight: screen.height, cellSize: cellSize(screenWidth: screen.width), rows: rows
            )
            // `topY` va en coordenadas del campo, que arranca en `bottomInset`.
            let onScreen = band.topY + BoardScene.bottomInset
            let expected = screen.height * BoardScene.crowdTopRatio
            #expect(
                abs(onScreen - expected) < 0.5,
                "en \(screen.height) de alto el techo quedó en \(onScreen) y se esperaba \(expected)"
            )
        }
    }

    @Test("ningún personaje se pasa del techo de la franja")
    func nobodyWandersPastTheTop() {
        for screen in screens {
            let band = BoardScene.crowdBand(
                sceneHeight: screen.height, cellSize: cellSize(screenWidth: screen.width), rows: rows
            )
            let backRowTop = band.frontY + band.rowDepth * CGFloat(rows - 1) + band.wanderRange / 2
            #expect(backRowTop <= band.topY + 0.001, "la fila trasera llega a \(backRowTop) y el techo es \(band.topY)")
        }
    }

    /// Con las dos filas separadas y un deambular chico, la multitud se ve como
    /// dos hileras y no como una multitud. Al derivar el deambular de la franja,
    /// lo que recorre cada fila se toca con lo que recorre la siguiente.
    @Test("las filas cubren la franja sin dejar un hueco entre ellas")
    func rowsCoverTheBandWithoutGaps() {
        for screen in screens {
            let band = BoardScene.crowdBand(
                sceneHeight: screen.height, cellSize: cellSize(screenWidth: screen.width), rows: rows
            )
            let frontRowTop = band.frontY + band.wanderRange / 2
            let backRowBottom = band.frontY + band.rowDepth - band.wanderRange / 2
            #expect(
                frontRowTop >= backRowBottom - 0.001,
                "queda un hueco entre \(frontRowTop) y \(backRowBottom)"
            )
        }
    }
}
