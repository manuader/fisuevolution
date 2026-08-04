import CoreGraphics
import Testing
@testable import FisuEvolution

/// `renderPlacements` reciclaba y rearmaba los diez personajes en CADA spawn,
/// merge, movida y cambio de piso, aunque un spawn toque un solo slot y un merge
/// dos —y contratar es el tap más repetido del juego—. Además del trabajo
/// tirado, el efecto se veía: cada contratación reiniciaba el wander de toda la
/// multitud y el tablero entero pegaba un salto de vuelta a sus anclas.
///
/// El riesgo del arreglo es el simétrico: dejar quieto un nodo que en realidad
/// tenía que rearmarse (textura vieja, skin vieja, tamaño de celda viejo). Por
/// eso la decisión vive en un tipo puro y se fija acá, slot por slot.
@Suite("BoardReconciliation")
struct BoardReconciliationTests {
    private let cellSize: CGFloat = 71.6
    private let columns = 5

    private func unit(_ typeId: String, skin: String? = nil, cellSize: CGFloat? = nil) -> RenderedUnit {
        RenderedUnit(
            typeId: typeId,
            skinID: skin,
            cellSize: cellSize ?? self.cellSize,
            columns: columns
        )
    }

    @Test("contratar toca un solo slot y deja quietos a los demás")
    func hiringOnlyBuildsTheNewSlot() {
        let before = [0: unit("homeless"), 1: unit("homeless")]
        let after = [0: unit("homeless"), 1: unit("homeless"), 2: unit("homeless")]

        let plan = BoardReconciliation(rendered: before, wanted: after)

        #expect(plan.rebuilt == [2])
        #expect(plan.kept == [0, 1])
        #expect(plan.discarded.isEmpty, "los que no cambiaron no vuelven al pool")
    }

    @Test("un merge rearma sólo los dos slots que cambiaron")
    func mergeOnlyTouchesItsTwoSlots() {
        let before = [0: unit("homeless"), 1: unit("homeless"), 2: unit("homeless")]
        // Los dos fisuras de 0 y 1 se funden en un cartonero que queda en 0.
        let after = [0: unit("cartonero"), 2: unit("homeless")]

        let plan = BoardReconciliation(rendered: before, wanted: after)

        #expect(plan.rebuilt == [0], "el slot 0 cambió de tipo")
        #expect(plan.kept == [2])
        #expect(plan.discarded == [0, 1], "el nodo viejo del 0 y el del 1 vuelven al pool")
    }

    @Test("cambiar la skin de un tipo rearma todas sus instancias")
    func equippingASkinRebuildsEveryInstanceOfTheType() {
        let before = [0: unit("homeless"), 1: unit("homeless"), 2: unit("cartonero")]
        let after = [
            0: unit("homeless", skin: "second_life"),
            1: unit("homeless", skin: "second_life"),
            2: unit("cartonero"),
        ]

        let plan = BoardReconciliation(rendered: before, wanted: after)

        #expect(plan.rebuilt == [0, 1], "una skin equipada tiene que verse en TODAS las instancias")
        #expect(plan.kept == [2], "el otro tipo no se entera")
    }

    @Test("un cambio de tamaño de celda rearma el tablero entero")
    func aDifferentCellSizeRebuildsEverything() {
        let before = [0: unit("homeless"), 1: unit("homeless")]
        let after = [0: unit("homeless", cellSize: 96), 1: unit("homeless", cellSize: 96)]

        let plan = BoardReconciliation(rendered: before, wanted: after)

        #expect(plan.kept.isEmpty, "reusar el nodo lo dejaría dibujado al tamaño del piso anterior")
        #expect(plan.rebuilt == [0, 1])
        #expect(plan.discarded == [0, 1])
    }

    @Test("un slot que se vacía devuelve su nodo al pool")
    func anEmptiedSlotReturnsItsNode() {
        let before = [0: unit("homeless"), 1: unit("homeless")]
        let after = [0: unit("homeless")]

        let plan = BoardReconciliation(rendered: before, wanted: after)

        #expect(plan.kept == [0])
        #expect(plan.rebuilt.isEmpty)
        #expect(plan.discarded == [1], "un nodo huérfano se queda dibujado y clickeable")
    }
}
