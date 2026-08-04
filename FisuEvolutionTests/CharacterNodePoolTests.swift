import SpriteKit
import Testing
@testable import FisuEvolution

/// El pool es el único punto por el que pasan TODOS los caminos de reutilización
/// de un `CharacterNode`, así que es el único lugar donde limpiar tiene sentido.
///
/// Bug que originó esta suite: el clon del ascenso termina su vuelo con
/// `alpha = 0` y vuelve al pool; el siguiente personaje que lo reutilizaba
/// renderizaba invisible pero seguía siendo clickeable, porque el hit-testing
/// mira la posición y no la opacidad. Como el primer ascenso es justo lo que
/// desbloquea el piso 2, el síntoma aparecía al llegar ahí y volvía en cada
/// merge que promovía.
@Suite("CharacterNodePool")
@MainActor
struct CharacterNodePoolTests {
    @Test("un nodo reciclado vuelve a entregarse visible")
    func recycledNodeIsHandedBackClean() {
        let pool = CharacterNodePool()
        let node = pool.obtain()

        // Estado en que lo dejan los efectos: el vuelo del ascenso (alpha 0 +
        // escala 0.72) y el drag (alpha 0.95).
        node.alpha = 0
        node.setScale(0.72)
        node.zRotation = 0.4
        node.isHidden = true

        pool.recycle(node)
        let reused = pool.obtain()

        #expect(reused === node, "el pool debería reutilizar el mismo nodo")
        #expect(reused.alpha == 1, "un nodo con alpha 0 se ve invisible pero se puede clickear")
        #expect(reused.xScale == 1)
        #expect(reused.yScale == 1)
        #expect(reused.zRotation == 0)
        #expect(reused.isHidden == false)
    }

    @Test("las acciones a medio correr no sobreviven al reciclado")
    func recyclingStopsRunningActions() {
        let pool = CharacterNodePool()
        let node = pool.obtain()
        node.run(.repeatForever(.sequence([.fadeOut(withDuration: 1), .fadeIn(withDuration: 1)])))
        #expect(node.hasActions())

        pool.recycle(node)
        #expect(pool.obtain().hasActions() == false, "una animación vieja seguiría peleando con la nueva posición")
    }

    @Test("reciclar dos veces no entrega el mismo nodo a dos personajes")
    func doubleRecycleDoesNotDuplicate() {
        let pool = CharacterNodePool()
        let node = pool.obtain()

        pool.recycle(node)
        pool.recycle(node)

        let first = pool.obtain()
        let second = pool.obtain()
        #expect(first === node)
        #expect(second !== first, "dos placements compartiendo un nodo hacen desaparecer a uno")
    }
}
