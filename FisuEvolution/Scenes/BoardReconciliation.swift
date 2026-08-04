import CoreGraphics

/// Lo que un slot del tablero está mostrando. Dos slots con la misma
/// `RenderedUnit` se dibujan idénticos, así que su nodo se puede dejar como
/// está. Todo lo que consume `CharacterNode.configure` tiene que estar acá: el
/// tipo (de donde salen textura, tier y nombre), la skin activa (de donde salen
/// el tinte y la textura alternativa) y la geometría del piso.
struct RenderedUnit: Equatable {
    let typeId: String
    let skinID: String?
    let cellSize: CGFloat
    let columns: Int
}

/// Qué hacer con cada slot al re-renderizar el piso visible.
///
/// Antes no había decisión: `renderPlacements` reciclaba y rearmaba los diez
/// personajes en CADA spawn, merge, movida y cambio de piso, aunque un spawn
/// toque un solo slot y un merge dos —y contratar es el tap más repetido del
/// juego—. Además del trabajo tirado, el efecto se veía: cada contratación
/// reiniciaba el wander de toda la multitud y el tablero entero pegaba un salto
/// de vuelta a sus anclas.
struct BoardReconciliation {
    /// Slots cuyo nodo queda intacto: sin reconfigurar, sin reposicionar y sin
    /// reiniciar su wander.
    let kept: Set<Int>
    /// Slots que hay que construir desde el pool.
    let rebuilt: Set<Int>
    /// Slots cuyo nodo ya no corresponde y vuelve al pool. Incluye a los que se
    /// rearman: ese nodo tampoco sirve como está.
    let discarded: Set<Int>

    init(rendered: [Int: RenderedUnit], wanted: [Int: RenderedUnit]) {
        var kept: Set<Int> = []
        var rebuilt: Set<Int> = []
        for (slot, unit) in wanted {
            if rendered[slot] == unit {
                kept.insert(slot)
            } else {
                rebuilt.insert(slot)
            }
        }
        self.kept = kept
        self.rebuilt = rebuilt
        self.discarded = Set(rendered.keys).subtracting(kept)
    }
}
