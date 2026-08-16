import SpriteKit
import Testing
@testable import FisuEvolution

/// Los personajes miran hacia donde caminan y, cada tanto, se dan vuelta solos.
/// Es lo que hace que diez figuras paradas en un campo se lean como una
/// multitud viva y no como diez calcomanías.
///
/// Se testea acá y no sólo con una captura porque el espejado tiene DOS trampas
/// que una imagen no muestra:
///
/// 1. **Dónde vive el espejado.** Si fuera `node.xScale`, cualquiera de los
///    `SKAction.scale(to:)` del tablero (rebote del tap, pop del candidato,
///    snap-back, ascenso) lo pisaría: `scale(to:)` escribe xScale e yScale a la
///    vez y devolvería al personaje a mirar a la derecha de un salto. Vive en el
///    sprite, que es hijo del nodo y no lo toca ninguna de esas acciones.
/// 2. **El ciclo de vida.** El volteo periódico NO comparte clave ni ciclo con
///    el paseo: el personaje congelado por una fusión o por el recorte del
///    tutorial se queda quieto, y darse vuelta es justamente lo único que lo
///    mantiene vivo mientras no camina.
///
/// Sin `SKView` nadie evalúa las `SKAction` (misma limitación que
/// `BoardGestureTests`), así que se observa el estado que dejan —qué acciones
/// quedaron encargadas y con qué escala quedó cada hijo— y no el final de las
/// animaciones. El rumbo del paseo, que sí necesita que las acciones corran, se
/// verifica en el simulador.
@Suite("Espejado: los personajes miran hacia donde caminan")
@MainActor
struct CharacterFacingTests {
    /// Una escena con la partida real, y con un par mergeable para poder
    /// ejercitar los congelamientos.
    ///
    /// Reduce Motion se **declara**, nunca se hereda del simulador: es la misma
    /// trampa que el tutorial y los ajustes en `UserDefaults` (trampa 9 del
    /// HANDOFF). Con el flag prendido en el device, media suite mediría lo
    /// contrario de lo que dice medir y nadie se enteraría.
    ///
    /// ⚠️ El override es estado global del proceso. Se pone DESPUÉS del último
    /// `await` y cada test lo devuelve a `nil` con un `defer`: entre esas dos
    /// líneas no hay suspensiones, así que ninguna otra prueba puede colarse a
    /// ver el flag ajeno.
    private func makeScene(reduceMotion: Bool = false) async -> (BoardScene, GameState) {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        BoardScene.reduceMotionOverride = reduceMotion
        let scene = BoardScene(gameState: gameState)
        scene.layoutBoard()
        return (scene, gameState)
    }

    private func slots(_ gameState: GameState) -> [Int] {
        gameState.visiblePlacements.map(\.slot)
    }

    // MARK: - El loop de volteo

    @Test("cada personaje del piso sale con su volteo encargado")
    func everyCharacterGetsItsFlipLoop() async throws {
        let (scene, gameState) = await makeScene()
        defer { BoardScene.reduceMotionOverride = nil }
        let cast = slots(gameState)
        #expect(cast.count >= 2, "el fixture tiene que dejar más de un personaje en el piso")

        for slot in cast {
            let node = try #require(scene.debugNode(atSlot: slot))
            #expect(
                node.action(forKey: CharacterNode.facingActionKey) != nil,
                "el personaje del slot \(slot) tiene que darse vuelta cada tanto"
            )
        }
    }

    @Test("con Reduce Motion nadie se da vuelta ni deambula")
    func reduceMotionSilencesBothMechanisms() async throws {
        let (scene, gameState) = await makeScene(reduceMotion: true)
        defer { BoardScene.reduceMotionOverride = nil }

        for slot in slots(gameState) {
            let node = try #require(scene.debugNode(atSlot: slot))
            #expect(node.action(forKey: CharacterNode.facingActionKey) == nil,
                    "un volteo es movimiento: con Reduce Motion no va")
            #expect(node.action(forKey: "wander") == nil,
                    "y el paseo tampoco, que es el guard que ya existía")
        }
    }

    @Test("el congelado por una fusión sigue dándose vuelta")
    func frozenCandidatesKeepFlipping() async throws {
        let (scene, gameState) = await makeScene()
        defer { BoardScene.reduceMotionOverride = nil }
        let placements = gameState.visiblePlacements
        let byType = Dictionary(grouping: placements, by: \.typeId)
        let pair = try #require(
            byType.values.first(where: { $0.count >= 2 }),
            "el fixture tiene que dejar un par mergeable en el piso visible"
        ).prefix(2).map(\.slot)
        let sibling = try #require(scene.debugNode(atSlot: pair[1]))

        scene.simulateGrab(slot: pair[0])

        #expect(sibling.action(forKey: "wander") == nil, "el hermano se congela para que le apuntes")
        #expect(sibling.action(forKey: CharacterNode.facingActionKey) != nil,
                "pero el volteo no comparte ciclo con el paseo: quieto y mirando fijo parece de cartón")
    }

    // MARK: - Dónde vive el espejado

    @Test("espejar toca el sprite y nada más")
    func mirroringOnlyTouchesTheSprite() async throws {
        let (scene, gameState) = await makeScene()
        defer { BoardScene.reduceMotionOverride = nil }
        let slot = try #require(slots(gameState).first)
        let node = try #require(scene.debugNode(atSlot: slot))
        #expect(node.isFacingLeft == false, "todos arrancan mirando a la derecha")

        node.setFacing(left: true)

        #expect(node.isFacingLeft)
        #expect(node.xScale == 1, "el espejado en el NODO se lo lleva puesto cualquier scale(to:)")
        #expect(node.yScale == 1)
        let mirrored = node.children.filter { $0.xScale < 0 }
        #expect(mirrored.count == 1, "sólo el sprite se espeja")
        #expect(mirrored.first is SKSpriteNode, "la sombra y las etiquetas no se espejan")

        node.setFacing(left: false)
        #expect(node.isFacingLeft == false)
        #expect(node.children.allSatisfy { $0.xScale > 0 }, "volver a la derecha no puede dejar rastro")
    }

    @Test("el rebote del tap no endereza al que mira a la izquierda")
    func theTapBounceDoesNotResetTheFacing() async throws {
        let (scene, gameState) = await makeScene()
        defer { BoardScene.reduceMotionOverride = nil }
        let slot = try #require(slots(gameState).first)
        let node = try #require(scene.debugNode(atSlot: slot))
        node.setFacing(left: true)

        scene.simulateTap(slot: slot, at: 100)
        #expect(node.action(forKey: "tapBounce") != nil, "el tap tiene que haber encargado su rebote")

        // Sin `SKView` nadie evalúa las acciones, así que se aplica a mano el
        // final del rebote: es EXACTAMENTE lo que hace `scale(to: 1.0)`, y lo
        // mismo que hacen el snap-back, el pop del candidato y el pool.
        node.setScale(1.0)

        #expect(node.isFacingLeft, "un tap no puede darlo vuelta de un salto")
    }

    // MARK: - El pool

    @Test("un nodo reciclado vuelve mirando a la derecha y sin volteo")
    func recycledNodeComesBackFacingRight() {
        let pool = CharacterNodePool()
        let node = pool.obtain()
        node.setFacing(left: true)
        node.run(.repeatForever(.wait(forDuration: 1)), withKey: CharacterNode.facingActionKey)

        pool.recycle(node)
        let reused = pool.obtain()

        #expect(reused === node, "el pool debería reutilizar el mismo nodo")
        // `setScale(1)` limpia el NODO, no a sus hijos: el espejado vive en el
        // sprite y sobreviviría al reciclado, así que un personaje nuevo podría
        // aparecer dado vuelta sin que nadie lo haya dado vuelta.
        #expect(reused.isFacingLeft == false)
        #expect(reused.action(forKey: CharacterNode.facingActionKey) == nil)
    }

    @Test("el próximo layout le devuelve el volteo al nodo reciclado")
    func theNextLayoutRestartsTheLoop() async throws {
        let (scene, gameState) = await makeScene()
        defer { BoardScene.reduceMotionOverride = nil }
        let slot = try #require(slots(gameState).first)
        let node = try #require(scene.debugNode(atSlot: slot))
        node.setFacing(left: true)

        // Cambiar el tamaño cambia el `cellSize`, así que la reconciliación
        // rearma los personajes: pasan por el pool y vuelven a salir de él.
        scene.size = CGSize(width: 430, height: 932)
        scene.layoutBoard()

        let reused = try #require(scene.debugNode(atSlot: slot))
        #expect(reused.isFacingLeft == false, "el que sale del pool arranca derecho")
        #expect(reused.action(forKey: CharacterNode.facingActionKey) != nil,
                "y `renderPlacements` le vuelve a encargar el volteo")
    }
}
