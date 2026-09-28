import SpriteKit
import Testing
@testable import FisuEvolution

/// Las reacciones de campo, cableadas a la escena real y al contenido real.
///
/// Sin `SKView` las `SKAction` no se evalúan, así que lo que se observa es el
/// estado que deja el disparo —quién tiene un emote encargado, quién perdió el
/// paseo— y no el final de las animaciones. Es la misma regla que
/// `BoardGestureTests`: cuando el veredicto es un estado, el estado es la
/// verificación.
///
/// El fixture arranca con El Fisura en el campo, y la tabla dice que ante la
/// Devaluación se encoge de hombros ("la mitad de nada es nada").
@Suite("Reacciones de campo: cableado")
@MainActor
struct EventReactionsWiringTests {
    private func makeScene() async throws -> (BoardScene, GameState, CharacterNode) {
        let gameState = await makeGameState()
        let scene = BoardScene(gameState: gameState)
        scene.layoutBoard()
        let slot = try #require(
            gameState.visiblePlacements.first { $0.typeId == "homeless" }?.slot,
            "el fixture tiene que arrancar con El Fisura en el campo"
        )
        let fisura = try #require(scene.debugNode(atSlot: slot))
        #expect(gameState.content?.eventReactions.emote(eventId: "devaluacion", typeId: "homeless") != .indiferente,
                "si la tabla cambia, este fixture elige otro par")
        return (scene, gameState, fisura)
    }

    /// Anuncia la Devaluación y exige que su banner tenga el turno.
    private func announce(_ gameState: GameState) throws {
        gameState.debugAnnounceEvent(id: "devaluacion")
        try #require(gameState.showing == .eventBanner, "el banner tiene que tener el turno")
    }

    @Test("cuando el banner toma el turno, el que tiene reacción reacciona y se queda quieto")
    func reactsOnTheBannerTurn() async throws {
        let (scene, gameState, fisura) = try await makeScene()
        scene.simulateEventReactionsFrame()
        #expect(!fisura.isEmoting, "sin evento no reacciona nadie")

        try announce(gameState)
        scene.simulateEventReactionsFrame()
        #expect(fisura.isEmoting)
        #expect(fisura.action(forKey: "wander") == nil, "reacciona quieto: si camina, no se lee")
    }

    @Test("una sola vez por disparo")
    func reactsOncePerFiring() async throws {
        let (scene, gameState, fisura) = try await makeScene()
        try announce(gameState)
        scene.simulateEventReactionsFrame()
        fisura.cancelEmote()   // como si hubiera terminado

        for _ in 0..<5 { scene.simulateEventReactionsFrame() }
        #expect(!fisura.isEmoting, "el mismo disparo no puede hacer reaccionar dos veces")
    }

    /// Depende del arreglo de la cola (`announcedEvent` por valor): con el id,
    /// la segunda Devaluación no pasaba por el turno del banner.
    @Test("la misma Devaluación dos veces seguidas: dos reacciones")
    func sameEventTwiceReactsTwice() async throws {
        let (scene, gameState, fisura) = try await makeScene()
        try announce(gameState)
        scene.simulateEventReactionsFrame()
        #expect(fisura.isEmoting)
        fisura.cancelEmote()
        gameState.celebrationFinished(.eventBanner)
        gameState.activeEvent = nil

        try announce(gameState)
        scene.simulateEventReactionsFrame()
        #expect(fisura.isEmoting, "el segundo disparo es otro evento")
    }

    @Test("con el flag apagado, el campo es el de antes")
    func flagOffMeansNothing() async throws {
        let (scene, gameState, fisura) = try await makeScene()
        BoardScene.eventReactionsOverride = false
        defer { BoardScene.eventReactionsOverride = nil }
        try announce(gameState)
        scene.simulateEventReactionsFrame()
        #expect(!fisura.isEmoting)
    }

    @Test("con Reduce Motion no reacciona nadie")
    func reduceMotionMeansNothing() async throws {
        let (scene, gameState, fisura) = try await makeScene()
        BoardScene.reduceMotionOverride = true
        defer { BoardScene.reduceMotionOverride = nil }
        try announce(gameState)
        scene.simulateEventReactionsFrame()
        #expect(!fisura.isEmoting)
    }

    @Test("el que tiene el dedo encima no reacciona")
    func draggedNodeIsExcluded() async throws {
        let (scene, gameState, fisura) = try await makeScene()
        scene.simulateTouchDown(slot: fisura.cellIndex)
        try announce(gameState)
        scene.simulateEventReactionsFrame()
        #expect(!fisura.isEmoting)
    }

    @Test("agarrar al que está reaccionando corta la reacción")
    func grabbingCancelsTheEmote() async throws {
        let (scene, gameState, fisura) = try await makeScene()
        try announce(gameState)
        scene.simulateEventReactionsFrame()
        #expect(fisura.isEmoting)
        scene.simulateTouchDown(slot: fisura.cellIndex)
        #expect(!fisura.isEmoting)
    }

    /// El invariante que protege al merge: `MergeTargeting` lee `node.position`,
    /// y el drop resuelve por `cellIndex`. Reaccionar no puede mover ninguno.
    @Test("reaccionar no mueve al nodo ni su celda")
    func reactingNeverMovesTheNode() async throws {
        let (scene, gameState, fisura) = try await makeScene()
        let position = fisura.position
        let cell = fisura.cellIndex
        try announce(gameState)
        scene.simulateEventReactionsFrame()
        #expect(fisura.position == position)
        #expect(fisura.cellIndex == cell)
        fisura.cancelEmote()
        #expect(fisura.position == position)
    }
}
