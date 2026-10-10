import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Premios: un solo punto de entrega")
@MainActor
struct RewardGrantTests {
    @Test("la plata se cotiza en segundos de producción y el video la duplica")
    func coinsAreProductionSeconds() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        let expected = GameState.coinReward(seconds: 900, player: before, content: content, economy: economy)
        let credited = gameState.grant(.coinsSeconds(900), source: "test")
        #expect(abs(credited - expected) < 1e-6 * max(1, expected))
        let after = try #require(gameState.player)
        #expect(abs(after.run.coins - before.run.coins - expected) < 1e-6 * max(1, expected))
        #expect(abs(after.meta.lifetimeEarnings - before.meta.lifetimeEarnings - expected) < 1e-6 * max(1, expected))
        let doubled = gameState.grant(.coinsSeconds(900), multiplier: 2, source: "test")
        let expectedDouble = GameState.coinReward(seconds: 1800, player: after, content: content, economy: economy)
        #expect(abs(doubled - expectedDouble) < 1e-6 * max(1, expectedDouble))
    }

    @Test("un modificador dura lo que dice, lleva su origen, y el video lo estira")
    func modifiersLastAndCarryTheirSource() async throws {
        let gameState = await makeGameState()
        gameState.grant(.modifier(effect: .incomeMultiplier, magnitude: 1.5, seconds: 600),
                        multiplier: 2, source: "visit.sindicalista_aumento", now: 1000)
        let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "visit.sindicalista_aumento" })
        #expect(modifier.magnitude == 1.5)
        #expect(modifier.expiresAt == 2200)
    }

    @Test("ORO al balance, nunca al ORO de por vida (el multiplicador lo gana sólo el prestigio)")
    func oroGoesToTheBalance() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player?.meta)
        gameState.grant(.oro(3), source: "visit.arbolito_cambio")
        #expect(gameState.player?.meta.oro == before.oro + 3)
        #expect(gameState.player?.meta.oroEarnedLifetime == before.oroEarnedLifetime)
    }

    @Test("cofres a la cola de cofres, cooldowns a cero, inmunidad como modificador")
    func theOtherKinds() async throws {
        let gameState = await makeGameState()
        let chests = try #require(gameState.player?.meta.chestsPending)
        gameState.grant(.skinChest(1), source: "test")
        #expect(gameState.player?.meta.chestsPending == chests + 1)
        gameState.player?.meta.boostActivations = ["mate": 1, "cafe": 2]
        gameState.grant(.clearBoostCooldowns, source: "visit.bug_reinicio")
        #expect(gameState.player?.meta.boostActivations.isEmpty == true)
        gameState.grant(.eventImmunity(seconds: 1800), source: "career.junior_doctor", now: 10)
        let player = try #require(gameState.player)
        #expect(ModifierMath.isImmuneToEvents(player.run.activeModifiers, now: 11))
    }

    @Test("lo que todavía no se puede entregar no toca nada",
          arguments: [RewardSpec.extraSlots(3)])
    func notYetGrantable(reward: RewardSpec) async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player)
        #expect(gameState.grant(reward, source: "test") == 0)
        #expect(gameState.player == before)
    }

    @Test("lo entregable es exactamente lo que este punto sabe dar")
    func grantableKinds() {
        #expect(GameState.grantableRewardKinds == [.coinsSeconds, .oro, .skinChest, .modifier, .clearBoostCooldowns, .eventImmunity, .package, .wheelSpin,
                .autoTap, .nextOfflineMultiplier, .nextDailyMultiplier])
    }

    @Test("varios premios juntos: una sola pasada, la plata sumada")
    func severalRewards() async throws {
        let gameState = await makeGameState()
        let credited = gameState.grant([.coinsSeconds(60), .oro(1), .coinsSeconds(60)], source: "test")
        #expect(credited > 0)
        #expect(gameState.player?.meta.oro == 1)
    }

    @Test("un segundo de producción vale algo aunque la torre no produzca (el piso de los premios)")
    func productionSecondHasAFloor() async throws {
        let gameState = await makeGameState()
        #expect(gameState.coinsPerProductionSecond > 0)
    }

    @Test("el momento calmo: tablero a la vista, sin hoja, sin celebración, sin tutorial, sin ficha")
    func calmMoment() async throws {
        let gameState = await makeGameState()
        #expect(gameState.isCalmMoment)
        gameState.uiCoversBoard = true
        #expect(!gameState.isCalmMoment)
        gameState.uiCoversBoard = false
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        #expect(!gameState.isCalmMoment)
        gameState.celebrationFinished(.towerNotice)
        #expect(gameState.isCalmMoment)
        gameState.beginTutorialPhase()
        #expect(!gameState.isCalmMoment)
        gameState.tutorialPhaseFinished()
        drain(gameState)
        gameState.handleScenePhase(from: .active, to: .inactive)
        #expect(!gameState.isCalmMoment, "con la escena inactiva no aparece nadie")
    }

    /// El cofre de bienvenida que cae al cerrar la fase toma el turno: se vacía la cola.
    private func drain(_ gameState: GameState) {
        for _ in 0..<12 {
            guard let current = gameState.showing else { return }
            if current == .chestOpening { gameState.chestReward = nil }
            gameState.celebrationFinished(current)
        }
    }
}
