import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Cuándo suena cada cinemática")
@MainActor
struct CinematicTriggerTests {
    private func world() async -> GameState {
        let gameState = await makeGameState()
        gameState.cinematicsAutorun = true
        return gameState
    }

    /// Todo lo que va saliendo de la cola, en orden, con tope.
    private func drain(_ gameState: GameState) -> [CelebrationKind] {
        var seen: [CelebrationKind] = []
        while let kind = gameState.showing, seen.count < 10 {
            seen.append(kind)
            gameState.celebrationFinished(kind)
        }
        return seen
    }

    private func standOnGod(_ gameState: GameState, revealed: Bool) throws -> Int {
        let god = try #require(gameState.godTier)
        gameState.debugSetMaxTier(god)
        gameState.player?.run.revealedTier = revealed ? god : god - 1
        return god
    }

    @Test("reencarnar la pide antes del cofre, que espera detrás")
    func reincarnationBeforeTheChest() async throws {
        let gameState = await world()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        gameState.confirmPrestige()
        #expect(gameState.showing == .cinematic)
        #expect(gameState.cinematic == .reencarnacion)
        #expect(gameState.player?.meta.prestigeChestsPending == 1, "el cofre se ganó igual")
        gameState.openChest()
        #expect(gameState.showing == .cinematic, "el cofre no la corta")
        let after = drain(gameState)
        #expect(after.contains(.chestOpening), "el cofre sale detrás de la cinemática")
        #expect(after.first == .cinematic)
        #expect(gameState.player?.meta.engagement.seenCinematics["reencarnacion"] == 1)
    }

    @Test("sin cinemáticas, reencarnar es lo de siempre")
    func reincarnationWithoutCinematics() async {
        let gameState = await makeGameState()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        gameState.confirmPrestige()
        #expect(gameState.showing != .cinematic)
        #expect(gameState.cinematic == nil)
        #expect(gameState.player?.meta.prestigeChestsPending == 1)
    }

    @Test("si nadie dibuja la cinemática, reencarnar no se traba: el watchdog la libera y la cuenta vista")
    func reincarnationDoesNotHangWithoutAPlayer() async {
        let gameState = await world()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        gameState.confirmPrestige()
        gameState.openChest()
        gameState.advanceCelebrations(delta: 12.5)
        #expect(gameState.cinematic == nil)
        #expect(gameState.player?.meta.engagement.seenCinematics["reencarnacion"] == 1)
        #expect(gameState.showing != .cinematic)
        #expect(drain(gameState).contains(.chestOpening), "el cofre toma el turno detrás")
    }

    @Test("política de video apagada: el overlay la cierra en el acto y el juego sigue")
    func closedAtOnceWhenVideoIsOff() async {
        let gameState = await world()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        gameState.confirmPrestige()
        gameState.celebrationFinished(.cinematic)
        #expect(gameState.showing != .cinematic)
        #expect(!gameState.celebrationHidesUI)
        #expect(gameState.player?.meta.engagement.seenCinematics["reencarnacion"] == 1)
        #expect(gameState.player?.meta.prestigeLevel == 1)
    }

    @Test("Dios pendiente sobrevive a reencarnar: la de reencarnación se descarta y suena el SFX")
    func pendingGodSurvivesReincarnation() async {
        let gameState = await world()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        #expect(gameState.playCinematicIfDue(.dios))
        gameState.confirmPrestige()
        #expect(gameState.cinematic == .dios, "la única de Dios no se pierde")
        gameState.celebrationFinished(.cinematic)
        #expect(gameState.player?.meta.engagement.seenCinematics["dios"] == 1)
        #expect(gameState.player?.meta.prestigeLevel == 1)
    }

    @Test("Dios: después del reveal, sin un momento calmo en el medio, y una sola vez")
    func godAfterTheRevealOnce() async throws {
        let gameState = await world()
        let god = try standOnGod(gameState, revealed: false)
        gameState.celebrations.enqueue(.boardCelebration)
        gameState.syncCelebrations()
        gameState.markRevealed(tier: god)
        #expect(gameState.showing == .boardCelebration)
        #expect(gameState.cinematic == .dios)
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.showing == .cinematic, "toma el turno en el acto")
        #expect(!gameState.isCalmMoment, "la tarjeta de E12 todavía no")
        gameState.celebrationFinished(.cinematic)
        #expect(gameState.player?.meta.engagement.seenCinematics["dios"] == 1)

        gameState.player?.run.revealedTier = god - 1
        gameState.markRevealed(tier: god)
        #expect(gameState.cinematic == nil)
    }

    @Test("un tier que no es el tope no la pide")
    func notGodNoCinematic() async throws {
        let gameState = await world()
        let god = try #require(gameState.godTier)
        gameState.markRevealed(tier: god - 1)
        #expect(gameState.cinematic == nil)
    }

    @Test("al arrancar parado en Dios sin haberla visto, se pide; vista, no vuelve")
    func reconcileOnBoot() async throws {
        let gameState = await world()
        let god = try #require(gameState.godTier)
        gameState.player?.run.revealedTier = god
        gameState.reconcileCinematics()
        #expect(gameState.cinematic == .dios)
        gameState.celebrationFinished(.cinematic)
        gameState.reconcileCinematics()
        #expect(gameState.cinematic == nil)
    }

    @Test("la app muere con Dios esperando turno: el save no lo vio y al cargar se re-encola, una sola vez")
    func godSurvivesAppDeath() async throws {
        let first = await world()
        let god = try standOnGod(first, revealed: false)
        first.markRevealed(tier: god)
        #expect(first.cinematic == .dios)
        let saved = try JSONEncoder().encode(try #require(first.player))

        let second = await world()
        second.player = try JSONDecoder().decode(PlayerState.self, from: saved)
        #expect(second.cinematic == nil, "lo que esperaba turno no se guardó")
        second.reconcileCinematics()
        #expect(second.showing == .cinematic)
        second.celebrationFinished(.cinematic)

        let saved2 = try JSONEncoder().encode(try #require(second.player))
        let third = await world()
        third.player = try JSONDecoder().decode(PlayerState.self, from: saved2)
        third.reconcileCinematics()
        #expect(third.cinematic == nil, "ya la vio: no vuelve")
    }

    @Test("sin cinemáticas habilitadas, reconcile no pide nada")
    func reconcileRespectsAutorun() async throws {
        let gameState = await makeGameState()
        let god = try #require(gameState.godTier)
        gameState.player?.run.revealedTier = god
        gameState.reconcileCinematics()
        #expect(gameState.cinematic == nil)
        #expect(gameState.showing == nil)
    }

    @Test("resetear la partida suelta la cinemática que esperaba")
    func resetClearsPendingCinematic() async {
        let gameState = await world()
        #expect(gameState.playCinematicIfDue(.dios))
        gameState.debugResetSave()
        #expect(gameState.cinematic == nil)
        #expect(gameState.showing == nil)
    }

    @Test("la intro: una partida nueva la pide y el tutorial no la estorba ni ella a él")
    func introOnNewGameCoexistsWithTheTutorial() async {
        let gameState = await world()
        gameState.reconcileIntro(isNewGame: true)
        gameState.beginTutorialPhase()
        gameState.celebrations.enqueue(.boardCelebration)
        gameState.syncCelebrations()
        #expect(gameState.showing == .cinematic, "la restricción no la desaloja")
        #expect(gameState.cinematic == .intro)
        #expect(!gameState.isCalmMoment)
        gameState.celebrationFinished(.cinematic)
        #expect(gameState.player?.meta.engagement.seenCinematics["intro"] == 1)
        #expect(gameState.showing == .boardCelebration, "el reveal del tutorial toma el turno detrás")
    }

    @Test("la intro pedida con el tutorial ya activo espera sin trabar al reveal")
    func introRequestedDuringTutorialWaits() async {
        let gameState = await world()
        gameState.beginTutorialPhase()
        gameState.celebrations.enqueue(.boardCelebration)
        gameState.reconcileIntro(isNewGame: true)
        #expect(gameState.showing == .boardCelebration)
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.showing == nil, "la fase obligatoria la retiene")
        gameState.tutorialPhaseFinished()
        #expect(gameState.showing == .cinematic)
    }

    @Test("un save de antes de la 2.0 da la intro por vista sin mostrarla")
    func introSkippedForVeterans() async {
        let gameState = await world()
        gameState.reconcileIntro(isNewGame: false)
        #expect(gameState.cinematic == nil)
        #expect(gameState.showing == nil)
        #expect(gameState.player?.meta.engagement.seenCinematics["intro"] == 1)
        gameState.reconcileIntro(isNewGame: true)
        #expect(gameState.cinematic == nil, "ya anotada: no vuelve")
    }

    @Test("sin cinemáticas habilitadas la intro no se pide ni se anota")
    func introRespectsAutorun() async {
        let gameState = await makeGameState()
        gameState.reconcileIntro(isNewGame: true)
        gameState.reconcileIntro(isNewGame: false)
        #expect(gameState.cinematic == nil)
        #expect(gameState.player?.meta.engagement.seenCinematics["intro"] == nil)
    }

    @Test("sin entrada en el manifest la intro es inerte")
    func introInertWithoutManifestEntry() async {
        let gameState = await world()
        gameState.reconcileIntro(isNewGame: true, manifest: .empty)
        gameState.reconcileIntro(isNewGame: false, manifest: .empty)
        #expect(gameState.cinematic == nil)
        #expect(gameState.showing == nil)
        #expect(gameState.player?.meta.engagement.seenCinematics["intro"] == nil)
    }
}
