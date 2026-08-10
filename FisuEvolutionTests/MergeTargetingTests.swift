import CoreGraphics
import Testing
@testable import FisuEvolution

/// Fusionar era la acción más fiddly del juego por tres razones, y la que no
/// se veía es la que se fija acá: el drop se resolvía contra el **ancla** del
/// slot y no contra dónde está parado el personaje. Desde que el reconciliador
/// conserva la posición deambulada esos dos puntos difieren hasta media celda,
/// así que soltar encima de alguien no lo enganchaba.
///
/// La regla vive en un tipo puro para que estos tests prueben la regla misma y
/// no una copia suya, igual que `BoardReconciliation`.
@Suite("MergeTargeting")
struct MergeTargetingTests {
    /// El valor real en un iPhone de 390 pt con cinco columnas.
    private let cellSize: CGFloat = 71.6

    private func unit(_ slot: Int, _ typeId: String, _ x: CGFloat, _ y: CGFloat) -> MergeTargeting.Unit {
        MergeTargeting.Unit(slot: slot, typeId: typeId, position: CGPoint(x: x, y: y))
    }

    // MARK: - Quiénes son compañeros

    @Test("los compañeros son los del mismo tipo, sin contarse a sí mismo")
    func partnersAreTheSameTypeExcludingSelf() {
        let units = [
            unit(0, "homeless", 50, 40),
            unit(1, "homeless", 100, 40),
            unit(2, "cartonero", 150, 40),
            unit(3, "homeless", 200, 40),
        ]

        let partners = MergeTargeting.partnerSlots(of: units[0], among: units)

        #expect(partners == [1, 3])
    }

    @Test("sin nadie del mismo tipo no hay compañeros")
    func aLoneTypeHasNoPartners() {
        let units = [unit(0, "homeless", 50, 40), unit(1, "cartonero", 100, 40)]

        #expect(MergeTargeting.partnerSlots(of: units[0], among: units).isEmpty)
    }

    // MARK: - El compañero del doble toque

    @Test("el doble toque engancha al compañero más cercano")
    func theDoubleTapPicksTheClosestPartner() {
        let units = [
            unit(0, "homeless", 50, 40),
            unit(1, "homeless", 200, 40),
            unit(2, "homeless", 90, 40),
        ]

        let partner = MergeTargeting.nearestPartner(
            of: units[0], among: units,
            within: cellSize * MergeTargeting.doubleTapReachRatio
        )

        #expect(partner?.slot == 2, "entre dos compañeros tiene que ganar el de al lado")
    }

    @Test("un compañero fuera del alcance no engancha")
    func aPartnerOutOfReachDoesNotCount() {
        let reach = cellSize * MergeTargeting.doubleTapReachRatio
        let units = [unit(0, "homeless", 0, 0), unit(1, "homeless", reach + 1, 0)]

        #expect(MergeTargeting.nearestPartner(of: units[0], among: units, within: reach) == nil)
        // Y justo adentro sí: el borde del radio es la regla, no una zona gris.
        let touching = [unit(0, "homeless", 0, 0), unit(1, "homeless", reach - 1, 0)]
        #expect(MergeTargeting.nearestPartner(of: touching[0], among: touching, within: reach)?.slot == 1)
    }

    @Test("dos vecinos deambulados al peor caso siguen enganchando")
    func neighboursStillReachEachOtherAtTheWorstWander() {
        // Dos columnas contiguas están a ~0,73 celdas de ancla a ancla; el
        // deambular puede separarlas ±17 pt en X y ±47 pt en Y. Es EL caso que
        // decidió el radio de 2 celdas: con uno más chico el gesto fallaría
        // entre vecinos, que es donde el jugador lo va a usar siempre.
        let units = [
            unit(0, "homeless", 0, 0),
            unit(1, "homeless", cellSize * 0.73 + 34, 94),
        ]

        let partner = MergeTargeting.nearestPartner(
            of: units[0], among: units,
            within: cellSize * MergeTargeting.doubleTapReachRatio
        )

        #expect(partner?.slot == 1)
    }

    // MARK: - El drop

    @Test("el drop se mide contra la posición real y no contra el ancla")
    func theDropIsMeasuredAgainstTheRealPositionNotTheAnchor() {
        // El personaje del slot 1 deambuló 70 pt a la izquierda de su ancla y el
        // dedo lo soltó justo encima. El slot 0 está vacío y su ancla quedó más
        // cerca del dedo que el ANCLA del 1.
        //
        // Ésta es exactamente la forma del bug: midiendo contra anclas, el
        // ocupado más cercano quedaba fuera del radio de 0,95 celdas y ganaba el
        // ancla libre — soltabas encima de un personaje y en vez de fusionar te
        // mudabas al hueco de al lado.
        let anchors = [CGPoint(x: 0, y: 40), CGPoint(x: 100, y: 40), CGPoint(x: 200, y: 40)]
        let units = [
            unit(1, "homeless", 30, 40),
            unit(2, "homeless", 200, 40),
        ]
        let finger = CGPoint(x: 30, y: 40)

        let target = MergeTargeting.dropTarget(
            at: finger, dragging: units[1], units: units, anchors: anchors, cellSize: cellSize
        )

        #expect(target == 1, "tiene que enganchar al que está debajo del dedo, no al hueco de al lado")
    }

    @Test("el compañero le gana a un vecino incompatible más cercano")
    func aPartnerBeatsACloserIncompatibleNeighbour() {
        // Amontonamiento típico: soltás en el montón y hay un compañero a 1,2
        // celdas y un incompatible a 0,4. El que querés es el compañero.
        let anchors = [CGPoint(x: 0, y: 40), CGPoint(x: 100, y: 40), CGPoint(x: 200, y: 40)]
        let units = [
            unit(0, "homeless", 0, 40),
            unit(1, "cartonero", 100, 40),
            unit(2, "homeless", 100 + cellSize * 1.2, 40),
        ]
        let finger = CGPoint(x: 100 + cellSize * 0.4, y: 40)

        let target = MergeTargeting.dropTarget(
            at: finger, dragging: units[0], units: units, anchors: anchors, cellSize: cellSize
        )

        #expect(target == 2)
    }

    @Test("fuera del radio del compañero manda el ocupado más cercano")
    func beyondThePartnerRadiusTheClosestOccupiedWins() {
        let anchors = [CGPoint(x: 0, y: 40), CGPoint(x: 100, y: 40), CGPoint(x: 400, y: 40)]
        let units = [
            unit(0, "homeless", 0, 40),
            unit(1, "cartonero", 100, 40),
            unit(2, "homeless", 400, 40),
        ]
        let finger = CGPoint(x: 100 + cellSize * 0.5, y: 40)

        let target = MergeTargeting.dropTarget(
            at: finger, dragging: units[0], units: units, anchors: anchors, cellSize: cellSize
        )

        #expect(target == 1, "el compañero está lejísimos: gana el que tenés debajo")
    }

    @Test("soltar en el vacío mueve al slot libre más cercano")
    func droppingOnEmptyGroundMovesToTheClosestFreeSlot() {
        let anchors = [CGPoint(x: 0, y: 40), CGPoint(x: 100, y: 40), CGPoint(x: 200, y: 40)]
        let units = [unit(0, "homeless", 0, 40)]
        let finger = CGPoint(x: 205, y: 45)

        let target = MergeTargeting.dropTarget(
            at: finger, dragging: units[0], units: units, anchors: anchors, cellSize: cellSize
        )

        #expect(target == 2)
    }

    @Test("soltar lejos de todo no engancha nada")
    func droppingFarFromEverythingHitsNothing() {
        let anchors = [CGPoint(x: 0, y: 40), CGPoint(x: 100, y: 40)]
        let units = [unit(0, "homeless", 0, 40), unit(1, "cartonero", 100, 40)]
        let finger = CGPoint(x: 900, y: 900)

        let target = MergeTargeting.dropTarget(
            at: finger, dragging: units[0], units: units, anchors: anchors, cellSize: cellSize
        )

        #expect(target == nil, "sin nada cerca la escena tiene que hacer snap-back")
    }

    @Test("el slot que estás arrastrando no es su propio destino")
    func theDraggedSlotIsNeverItsOwnTarget() {
        let anchors = [CGPoint(x: 0, y: 40), CGPoint(x: 300, y: 40)]
        let units = [unit(0, "homeless", 0, 40), unit(1, "homeless", 300, 40)]

        let target = MergeTargeting.dropTarget(
            at: CGPoint(x: 0, y: 40), dragging: units[0], units: units, anchors: anchors, cellSize: cellSize
        )

        #expect(target == nil, "soltarlo donde estaba no puede fusionarlo consigo mismo")
    }
}
