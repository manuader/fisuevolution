import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("Los efectos de escena: Apagón y Campeones", .serialized)
@MainActor
struct StageEffectsTests {
    private func effects() async -> (GameState, StageEffects) {
        let gameState = await makeGameState()
        let effects = StageEffects(gameState: gameState)
        effects.attach(to: SKNode())
        effects.layout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118)
        return (gameState, effects)
    }

    @Test("el Apagón baja el velo y cada toque prende una velita, hasta ×1")
    func blackoutCandles() async throws {
        let (gameState, effects) = await effects()
        gameState.debugStartEvent(id: "apagon")
        #expect(gameState.runningEventScenes(now: Date().timeIntervalSince1970).contains(.blackout))
        let start = try #require(gameState.blackoutCandles(now: Date().timeIntervalSince1970))
        #expect(start.lit == 0)
        #expect(start.total == 10)
        effects.update(delta: 1.0 / 60, reduceMotion: false, units: [])
        let dark = effects.veilAlpha
        #expect(dark > 0.5)
        #expect(gameState.lightCandleIfBlackout())
        effects.update(delta: 1.0 / 60, reduceMotion: false, units: [])
        #expect(effects.litCandles == 1)
        #expect(effects.veilAlpha < dark)
        while gameState.lightCandleIfBlackout() {}
        #expect(gameState.blackoutCandles(now: Date().timeIntervalSince1970)?.lit == 10)
        let income = gameState.player?.run.activeModifiers.first { $0.sourceKey == "event.apagon" }
        #expect(income?.magnitude == 1)
        effects.update(delta: 1.0 / 60, reduceMotion: false, units: [])
        #expect(effects.veilAlpha == 0)
    }

    @Test("con Reduce Motion el velo y las velitas siguen: son información")
    func blackoutSurvivesReduceMotion() async {
        let (gameState, effects) = await effects()
        gameState.debugStartEvent(id: "apagon")
        gameState.lightCandleIfBlackout()
        effects.update(delta: 1.0 / 60, reduceMotion: true, units: [])
        #expect(effects.veilAlpha > 0)
        #expect(effects.litCandles == 1)
    }

    @Test("sin apagón no hay velo ni velitas, y tocar no prende nada")
    func noBlackoutNoVeil() async {
        let (gameState, effects) = await effects()
        effects.update(delta: 1.0 / 60, reduceMotion: false, units: [])
        #expect(effects.veilAlpha == 0)
        #expect(!gameState.lightCandleIfBlackout())
    }

    @Test("con Campeones bailan; con Reduce Motion, no; al terminar quedan derechos")
    func championsDance() async throws {
        let (gameState, effects) = await effects()
        let units = [SKNode(), SKNode(), SKNode()]
        gameState.debugStartEvent(id: "campeones")
        effects.update(delta: 0.2, reduceMotion: false, units: units)
        #expect(effects.isDancing)
        #expect(units.contains { $0.zRotation != 0 })
        effects.update(delta: 0.2, reduceMotion: true, units: units)
        #expect(!effects.isDancing)
        #expect(units.allSatisfy { $0.zRotation == 0 })
        effects.update(delta: 0.2, reduceMotion: false, units: units)
        gameState.player?.run.activeModifiers.removeAll { $0.sourceKey == "event.campeones" }
        effects.update(delta: 0.2, reduceMotion: false, units: units)
        #expect(units.allSatisfy { $0.zRotation == 0 })
    }

    @Test("el Apagón suena su propio corte de luz")
    func blackoutSound() {
        #expect(AudioManager.accent(forEvent: "apagon") == .blackout)
    }
}
