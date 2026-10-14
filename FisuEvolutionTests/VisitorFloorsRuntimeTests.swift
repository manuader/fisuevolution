import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// E14b B7 (D6): al cambiar de piso, el visitante de ese piso se congela —la
/// espera y la escena— y sigue cuando se vuelve. Puede haber uno en cada piso.
@Suite("Los visitantes, uno por piso", .serialized)
@MainActor
struct VisitorFloorsRuntimeTests {
    /// Frontera en 6: el callejón y varios pisos arriba abiertos, el visible en el callejón.
    private func world() async -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 6)
        gameState.debugGrantCoins()
        gameState.engagementAutorun = true
        return gameState
    }

    private func arrive(_ gameState: GameState, _ scriptId: String) throws {
        let script = try #require(gameState.content?.visitors.script(id: scriptId))
        gameState.presentVisitor(script)
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
    }

    @Test("el tick con su piso fuera de pantalla deja la espera intacta, y al volver sigue")
    func leavingTheFloorFreezesTheWait() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        gameState.advanceStage(delta: 5)
        let visit = try #require(gameState.stageVisit)
        let patience = gameState.stageRuntime.patienceLeft
        #expect(patience < (gameState.content?.visitors.patienceSeconds ?? 0), "en su piso, la espera corre")

        gameState.setVisibleFloor(1)
        #expect(gameState.stageVisit == nil, "se quedó en su piso")
        #expect(gameState.waitingVisitor(onFloor: 0)?.patienceLeft == patience)
        for _ in 0..<40 { gameState.advanceStage(delta: 5) }
        #expect(gameState.waitingVisitor(onFloor: 0)?.patienceLeft == patience, "congelado: 200 s y no se fue")

        gameState.setVisibleFloor(0)
        #expect(gameState.stageVisit?.id == visit.id, "el mismo, no uno nuevo")
        #expect(gameState.stageVisit?.offer == visit.offer)
        #expect(gameState.stageVisit?.phase == .waiting)
        #expect(gameState.stageRuntime.patienceLeft == patience)
        #expect(gameState.waitingVisitor(onFloor: 0) == nil)
    }

    @Test("con uno congelado en otro piso, el piso nuevo puede recibir a otro: varios a la vez")
    func severalFloorsAtOnce() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        gameState.setVisibleFloor(1)
        #expect(gameState.canPresentOnStage)
        gameState.player?.meta.engagement.visitors.secondsUntilVisit = 1
        gameState.advanceVisitors(delta: 2)
        let second = try #require(gameState.stageVisit)
        #expect(second.actorId != "npc_turista", "el que espera en otro piso no entra dos veces")
        #expect(second.floorOrdinal == 1)

        gameState.debugClearStage()
        try arrive(gameState, "ministro_subsidio")
        gameState.setVisibleFloor(2)
        #expect(gameState.visitorsWaitingElsewhere.map(\.floorOrdinal) == [1, 0])
        #expect(gameState.visitorsWaitingElsewhere.map(\.visitorId) == ["npc_ministro", "npc_turista"])
    }

    @Test("un piso con alguien congelado no recibe a otro hasta que ese vuelva a la escena")
    func aFrozenFloorIsNotFree() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        gameState.setVisibleFloor(1)
        gameState.visibleFloorOrdinal = 0
        #expect(!gameState.canPresentOnStage, "ni en el tick antes de que vuelva")
        gameState.advanceStage(delta: 0)
        #expect(gameState.stageVisit?.actorId == "npc_turista")
    }

    @Test("desde el aviso se lo despacha: lleva a su piso y abre su popup")
    func theNoticeAttendsTheVisitor() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        gameState.setVisibleFloor(2)
        gameState.attendWaitingVisitor(onFloor: 0)
        #expect(gameState.visibleFloorOrdinal == 0)
        #expect(gameState.stageVisit?.actorId == "npc_turista")
        #expect(gameState.visitorPopup != nil)
        #expect(gameState.visitorsWaitingElsewhere.isEmpty)
    }

    @Test("después de relanzar, el que esperaba vuelve con su espera y una oferta cotizada de nuevo")
    func aRelaunchRequotesTheOffer() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        let first = try #require(gameState.stageVisit?.id)
        let patience = gameState.stageRuntime.patienceLeft
        gameState.setVisibleFloor(1)
        gameState.stageRuntime.parked = [:]
        gameState.setVisibleFloor(0)
        let back = try #require(gameState.stageVisit)
        #expect(back.id != first)
        #expect(back.role == .visitor(scriptId: "turista_propina"))
        #expect(back.offer != nil)
        #expect(gameState.stageRuntime.patienceLeft == patience)
    }

    @Test("el que ya cerró su trato no se congela: se va")
    func aClosedDealDoesNotFreeze() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        #expect(gameState.chooseVisitOption("accept"))
        gameState.setVisibleFloor(1)
        #expect(gameState.stageVisit == nil)
        #expect(gameState.visitorsWaitingElsewhere.isEmpty)
        gameState.setVisibleFloor(0)
        #expect(gameState.stageVisit == nil)
    }

    @Test("reencarnar despide también a los congelados")
    func reincarnatingDismissesTheFrozen() async throws {
        let gameState = await world()
        try arrive(gameState, "turista_propina")
        gameState.setVisibleFloor(1)
        #expect(!gameState.visitorsWaitingElsewhere.isEmpty)
        gameState.giveEarningsForPrestigeTesting(blue: 3)
        gameState.confirmPrestige()
        #expect(gameState.player?.meta.engagement.visitors.waiting.isEmpty == true)
        #expect(gameState.stageRuntime.parked.isEmpty)
    }
}
