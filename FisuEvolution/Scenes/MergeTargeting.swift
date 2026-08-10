import CoreGraphics

/// A quién le apunta un gesto de fusión en el campo.
///
/// Vive afuera de `BoardScene` por la misma razón que `BoardReconciliation`: es
/// una decisión con reglas y radios que se puede fijar en un test, y adentro de
/// la escena el test tendría que probar una copia de la regla en vez de la
/// regla.
///
/// ⚠️ **Todo se mide contra la posición REAL del personaje, nunca contra el
/// ancla de su slot.** El reconciliador conserva la posición deambulada, así que
/// el ancla y el personaje pueden estar a media celda de distancia: resolver un
/// drop contra las anclas es soltar sobre el lugar donde el personaje **estaba**.
/// Es la trampa 3 del HANDOFF —"los drags por coordenadas fijas fallan seguido"—
/// y es la razón por la que el helper de merge de `TutorialUITests` barría ocho
/// coordenadas para conseguir una fusión. Las anclas quedan sólo para los slots
/// **vacíos**, que por definición no tienen nodo.
enum MergeTargeting {
    /// Un personaje parado en el campo. `position` son los **pies**, en
    /// coordenadas de `fieldNode`, que es exactamente lo que `touchesMoved` le
    /// asigna al nodo que se arrastra: así el punto del dedo y las posiciones de
    /// los demás se comparan en la misma métrica.
    struct Unit: Equatable {
        let slot: Int
        let typeId: String
        let position: CGPoint
    }

    // MARK: - Radios, en múltiplos de `cellSize`

    /// Soltar sobre un compañero del mismo tipo. Más generoso que el resto: es
    /// el gesto que el jugador quiere que salga.
    static let partnerCaptureRatio: CGFloat = 1.5
    /// Soltar sobre cualquier otro ocupado.
    static let occupiedCaptureRatio: CGFloat = 0.95
    /// Mover a un slot libre.
    static let emptyCaptureRatio: CGFloat = 1.05
    /// Hasta dónde busca compañero el doble toque.
    ///
    /// Es 2,0 y no "que se estén pisando" por una medición: dos vecinos de
    /// columna están a ~0,73 celdas de ancla a ancla, pero el deambular
    /// (±17 pt en X, ±47 pt en Y en una pantalla de 844 pt) los puede separar
    /// hasta ~1,8 celdas. Con un radio chico el doble toque fallaría entre
    /// vecinos, y eso se lee como "a veces no anda" — peor que no tenerlo.
    static let doubleTapReachRatio: CGFloat = 2.0

    // MARK: - Consultas

    /// Los slots que pueden fusionarse con `unit`. Fusionar es "dos del mismo
    /// tipo" (`MergeRules.evaluate`), así que la regla se puede responder sin
    /// consultar la economía.
    static func partnerSlots(of unit: Unit, among units: [Unit]) -> Set<Int> {
        var slots: Set<Int> = []
        for candidate in units where candidate.slot != unit.slot && candidate.typeId == unit.typeId {
            slots.insert(candidate.slot)
        }
        return slots
    }

    /// El compañero más cercano dentro de `radius`, o nil si no hay ninguno.
    static func nearestPartner(of unit: Unit, among units: [Unit], within radius: CGFloat) -> Unit? {
        var best: (unit: Unit, distance: CGFloat)?
        for candidate in units where candidate.slot != unit.slot && candidate.typeId == unit.typeId {
            let distance = distance(candidate.position, unit.position)
            guard distance <= radius else { continue }
            if best == nil || distance < best!.distance { best = (candidate, distance) }
        }
        return best?.unit
    }

    /// A qué slot cae un drop, en orden de preferencia: el compañero más cercano
    /// (radio generoso) → cualquier otro ocupado → el slot libre más cercano →
    /// nada, que en la escena es un snap-back.
    ///
    /// Que el compañero gane **antes** de mirar distancias contra los demás es
    /// lo que hace que soltar en un amontonamiento fusione en vez de moverte a
    /// un hueco: entre un compañero a 1,2 celdas y un vecino incompatible a 0,4,
    /// el que el jugador quiere es el compañero.
    static func dropTarget(
        at point: CGPoint,
        dragging: Unit,
        units: [Unit],
        anchors: [CGPoint],
        cellSize: CGFloat
    ) -> Int? {
        guard cellSize > 0 else { return nil }

        var nearestPartner: (slot: Int, distance: CGFloat)?
        var nearestOccupied: (slot: Int, distance: CGFloat)?
        var occupiedSlots: Set<Int> = []
        for unit in units {
            occupiedSlots.insert(unit.slot)
            guard unit.slot != dragging.slot else { continue }
            let distance = distance(unit.position, point)
            if nearestOccupied == nil || distance < nearestOccupied!.distance {
                nearestOccupied = (unit.slot, distance)
            }
            guard unit.typeId == dragging.typeId else { continue }
            if nearestPartner == nil || distance < nearestPartner!.distance {
                nearestPartner = (unit.slot, distance)
            }
        }

        if let partner = nearestPartner, partner.distance <= cellSize * partnerCaptureRatio {
            return partner.slot
        }
        if let occupied = nearestOccupied, occupied.distance <= cellSize * occupiedCaptureRatio {
            return occupied.slot
        }

        var nearestFree: (slot: Int, distance: CGFloat)?
        for (slot, anchor) in anchors.enumerated() where !occupiedSlots.contains(slot) {
            let distance = distance(anchor, point)
            if nearestFree == nil || distance < nearestFree!.distance { nearestFree = (slot, distance) }
        }
        if let free = nearestFree, free.distance <= cellSize * emptyCaptureRatio { return free.slot }
        return nil
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
