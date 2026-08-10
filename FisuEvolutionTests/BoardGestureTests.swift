import SpriteKit
import Testing
@testable import FisuEvolution

/// Los dos gestos que hacen que fusionar deje de ser fiddly: al levantar a un
/// personaje sus hermanos se destacan, y un doble toque fusiona al par sin
/// arrastrar nada.
///
/// Se testea acá y no con una captura porque las dos cosas son **invisibles en
/// una imagen**: el z sólo se nota cuando dos cuerpos se superponen, y el
/// deambular congelado sólo se nota comparando cuadros. Es la lección de la
/// trampa 9 del HANDOFF —la mano del tutorial estaba en pantalla y no latía— y
/// de `CrowdDepthTests`: cuando el veredicto es un número, el número es la
/// verificación.
///
/// Sin `SKView` nadie evalúa las `SKAction`, así que lo que se observa es el
/// estado que los gestos dejan (z, paseo, acciones encargadas) y no el final de
/// las animaciones.
@Suite("Gestos del tablero: fusión asistida")
@MainActor
struct BoardGestureTests {
    /// Una escena con al menos un par mergeable y un personaje de otro tipo en
    /// el mismo piso, para poder distinguir "se destaca" de "se destacan todos".
    private func makeScene() async -> (BoardScene, GameState) {
        let gameState = await makeGameState()
        // El par del tier máximo, más el Fisura con el que arranca la partida.
        gameState.debugGrantPair()
        let scene = BoardScene(gameState: gameState)
        scene.layoutBoard()
        return (scene, gameState)
    }

    /// Los slots de un par del mismo tipo y, si lo hay, uno de otro tipo.
    private func cast(_ gameState: GameState) throws -> (pair: [Int], stranger: Int?) {
        let placements = gameState.visiblePlacements
        let byType = Dictionary(grouping: placements, by: \.typeId)
        let pair = try #require(
            byType.values.first(where: { $0.count >= 2 }),
            "el fixture tiene que dejar un par mergeable en el piso visible"
        )
        let pairType = pair[0].typeId
        return (pair.prefix(2).map(\.slot), placements.first(where: { $0.typeId != pairType })?.slot)
    }

    // MARK: - Agarrar destaca a los hermanos

    @Test("al agarrar uno, sus hermanos suben por encima de la multitud")
    func grabbingLiftsTheSiblingsAboveTheCrowd() async throws {
        let (scene, gameState) = await makeScene()
        let (pair, stranger) = try cast(gameState)
        let sibling = try #require(scene.debugNode(atSlot: pair[1]))
        let restingZ = sibling.zPosition

        scene.simulateGrab(slot: pair[0])

        // Con tolerancia porque SpriteKit guarda `zPosition` en un `Float`: leer
        // el valor de reposo y volver a sumarle 5 no da el mismo `Double`.
        #expect(abs((sibling.zPosition - restingZ) - BoardScene.candidateZLift) < 0.001,
                "el hermano tiene que saltar por encima de la franja de la multitud")
        if let stranger, let other = scene.debugNode(atSlot: stranger) {
            #expect(sibling.zPosition > other.zPosition,
                    "y quedar adelante de los que no son de su tipo")
        }
    }

    @Test("el hermano deja de deambular mientras le apuntás")
    func theSiblingStopsWanderingWhileYouAim() async throws {
        let (scene, gameState) = await makeScene()
        let (pair, stranger) = try cast(gameState)
        let sibling = try #require(scene.debugNode(atSlot: pair[1]))
        #expect(sibling.action(forKey: "wander") != nil, "arranca deambulando")

        scene.simulateGrab(slot: pair[0])

        // A 44 pt/s el blanco se corre más de medio cuerpo por segundo: apuntarle
        // a algo que camina es la mitad de por qué fusionar se sentía fiddly.
        #expect(sibling.action(forKey: "wander") == nil)
        #expect(sibling.action(forKey: "candidate") != nil, "y pega el pop que lo señala")
        if let stranger, let other = scene.debugNode(atSlot: stranger) {
            #expect(other.action(forKey: "wander") != nil, "el que no es de su tipo sigue su vida")
        }
    }

    @Test("soltar devuelve a los hermanos a la multitud")
    func releasingPutsTheSiblingsBack() async throws {
        let (scene, gameState) = await makeScene()
        let (pair, _) = try cast(gameState)
        let sibling = try #require(scene.debugNode(atSlot: pair[1]))
        let restingZ = sibling.zPosition

        scene.simulateGrab(slot: pair[0])
        scene.simulateRelease()

        #expect(sibling.zPosition == restingZ, "el realce no puede quedar pegado")
        #expect(sibling.action(forKey: "wander") != nil, "y el paseo tiene que volver")
    }

    // MARK: - Doble toque

    /// El compañero que arrancó viaje hacia su par, si alguno lo hizo.
    private func travelling(_ scene: BoardScene, among slots: [Int]) -> Int? {
        slots.first { scene.debugNode(atSlot: $0)?.action(forKey: "assistedMerge") != nil }
    }

    @Test("dos toques seguidos mandan al compañero a fusionarse")
    func twoQuickTapsSendThePartnerOver() async throws {
        let (scene, gameState) = await makeScene()
        let (pair, _) = try cast(gameState)

        scene.simulateTap(slot: pair[0], at: 100)
        scene.simulateTap(slot: pair[0], at: 100 + BoardScene.doubleTapWindow / 2)

        #expect(travelling(scene, among: pair) != nil,
                "el doble toque tiene que arrancar la fusión sin arrastrar nada")
    }

    @Test("dos toques lentos son dos toques, no una fusión")
    func twoSlowTapsAreJustTwoTaps() async throws {
        let (scene, gameState) = await makeScene()
        let (pair, _) = try cast(gameState)

        scene.simulateTap(slot: pair[0], at: 100)
        scene.simulateTap(slot: pair[0], at: 100 + BoardScene.doubleTapWindow + 0.05)

        #expect(travelling(scene, among: pair) == nil)
    }

    @Test("un toque en cada uno tampoco fusiona")
    func tappingTwoDifferentCharactersDoesNotMerge() async throws {
        let (scene, gameState) = await makeScene()
        let (pair, _) = try cast(gameState)

        scene.simulateTap(slot: pair[0], at: 100)
        scene.simulateTap(slot: pair[1], at: 100.1)

        #expect(travelling(scene, among: pair) == nil,
                "el doble toque es sobre el MISMO personaje")
    }

    @Test("tocar rápido no encadena fusiones")
    func hammeringDoesNotChainMerges() async throws {
        let (scene, gameState) = await makeScene()
        let (pair, _) = try cast(gameState)

        // Una ráfaga de taps para ganar monedas: los dos primeros toques de
        // cualquier ráfaga son indistinguibles de un doble toque deliberado y
        // van a fusionar. Lo que no puede pasar es que la ráfaga se lleve puesto
        // el piso entero.
        scene.simulateTap(slot: pair[0], at: 100)
        scene.simulateTap(slot: pair[0], at: 100.1)
        let first = try #require(travelling(scene, among: pair))
        scene.debugNode(atSlot: first)?.removeAction(forKey: "assistedMerge")

        scene.simulateTap(slot: pair[0], at: 100.2)
        scene.simulateTap(slot: pair[0], at: 100.3)

        #expect(travelling(scene, among: pair) == nil,
                "dentro de la gracia de \(BoardScene.assistedMergeCooldown) s no puede salir otra")
    }

    @Test("sin compañero cerca el doble toque no hace nada")
    func withoutAPartnerNothingHappens() async throws {
        let gameState = await makeGameState()
        let scene = BoardScene(gameState: gameState)
        scene.layoutBoard()
        let placements = gameState.visiblePlacements
        let lonely = try #require(placements.first?.slot, "la partida arranca con un personaje")
        #expect(placements.count == 1, "y con uno solo, que es el punto de este test")

        scene.simulateTap(slot: lonely, at: 100)
        scene.simulateTap(slot: lonely, at: 100.1)

        #expect(scene.debugNode(atSlot: lonely)?.action(forKey: "assistedMerge") == nil)
    }
}
