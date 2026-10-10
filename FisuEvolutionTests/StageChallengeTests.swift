import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El reto de toques: lo que dibuja su chip y cómo corre su reloj", .serialized)
@MainActor
struct StageChallengeTests {
    private let terms = ChallengeTerms(taps: 15, windowSeconds: 20, coins: 0, rewards: [], videoDoubles: false)

    @Test("el avance es toques sobre la meta, con tope")
    func progress() {
        #expect(StageChallenge(scriptId: "x", terms: terms, taps: 0, endsAt: 20).progress == 0)
        #expect(StageChallenge(scriptId: "x", terms: terms, taps: 6, endsAt: 20).progress == 0.4)
        #expect(StageChallenge(scriptId: "x", terms: terms, taps: 40, endsAt: 20).progress == 1)
    }

    @Test("lo que falta nunca es negativo")
    func remaining() {
        let challenge = StageChallenge(scriptId: "x", terms: terms, taps: 0, endsAt: 20)
        #expect(challenge.remaining(at: 5) == 15)
        #expect(challenge.remaining(at: 25) == 0)
    }

    private func startChallenge() async throws -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 6)
        gameState.engagementAutorun = true
        gameState.player?.meta.ownedSpecials.append("sp_coach")
        let script = try #require(gameState.content?.visitors.script(id: "coach_reto"))
        gameState.presentVisitor(script)
        gameState.stageActorArrived(id: try #require(gameState.stageVisit?.id))
        #expect(gameState.chooseVisitOption("challenge"))
        return gameState
    }

    @Test("el reloj del reto corre con el delta del juego, no con la fecha de pared")
    func theClockFollowsGameDelta() async throws {
        let gameState = try await startChallenge()
        let challenge = try #require(gameState.stageChallenge)
        let window = challenge.terms.windowSeconds
        gameState.advanceStage(delta: window - 1)
        #expect(gameState.stageChallenge != nil, "pasó casi toda la ventana de juego")
        #expect(gameState.stageChallenge?.remaining(at: gameState.stageRuntime.challengeClock) == 1)
        gameState.advanceStage(delta: 2)
        #expect(gameState.stageChallenge == nil, "venció por juego activo")
        #expect(gameState.stageVisit?.bubble == VisitCopy.text("visit.challenge.lost"))
    }

    @Test("los toques cuentan contra el reloj del juego")
    func tapsCountAgainstTheGameClock() async throws {
        let gameState = try await startChallenge()
        gameState.noteStageTap()
        #expect(gameState.stageChallenge?.taps == 1)
    }

    @Test("mientras dura el reto no hay corte natural")
    func theChallengeBlocksNaturalBreaks() async throws {
        let gameState = try await startChallenge()
        #expect(gameState.naturalBreakContext.sheetOpen, "un intersticial no corta un reto")
        gameState.finishChallenge(won: false)
        #expect(gameState.naturalBreakContext.sheetOpen == false)
    }
}
