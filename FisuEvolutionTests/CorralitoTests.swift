import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Corralito en el juego")
@MainActor
struct CorralitoTests {
    @Test("el evento congela el gasto con su motivo, y el video lo levanta")
    func corralitoFreezesAndTheVideoLifts() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.debugStartCorralito()
        gameState.refreshProjections()
        #expect(gameState.spendingFrozenUntil != nil)
        let base = try #require(gameState.content?.tiers.baseType.id)
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.hireCharacter(typeId: base)
        #expect(gameState.player?.run.totalUnits == units)
        #expect(gameState.towerNotice?.kind == .spendingFrozen)
        gameState.escapeActiveEvent()
        gameState.refreshProjections()
        #expect(gameState.spendingFrozenUntil == nil)
        gameState.hireCharacter(typeId: base)
        #expect(gameState.player?.run.totalUnits == units + 1)
    }

    @Test("el JSON del Corralito dice lo que hace")
    func corralitoDataMatchesTheDecision() async throws {
        let gameState = await makeGameState()
        let corralito = try #require(gameState.content?.events.events.first { $0.id == "corralito" })
        #expect(corralito.effectType == .spendingFrozen)
        #expect(corralito.escape == "video")
        #expect(corralito.durationSeconds == 45)
    }

    @Test("la UI se congela entera: atajo, filas, mejoras y pasivos")
    func frozenUIReportsNothingAffordable() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.canAffordSpawn)
        #expect(gameState.quickHireOffer?.affordable == true)
        #expect(gameState.jobRows.contains { $0.affordable })
        let upgradable = try #require(gameState.characterUpgradeRows.first { $0.canAffordUpgrade })
        #expect(gameState.characterUpgradeRows.contains { $0.canAffordPassive })

        gameState.debugStartCorralito()
        gameState.refreshProjections()

        #expect(!gameState.canAffordSpawn)
        #expect(gameState.quickHireOffer?.affordable == false)
        #expect(gameState.jobRows.allSatisfy { !$0.affordable })
        #expect(gameState.characterUpgradeRows.allSatisfy { !$0.canAffordUpgrade && !$0.canAffordPassive })

        let coins = try #require(gameState.player?.run.coins)
        gameState.buyCharacterUpgrade(typeID: upgradable.id)
        #expect(gameState.player?.run.coins == coins)
        #expect(gameState.towerNotice?.kind == .spendingFrozen)
    }

    @Test("contratar gratis sigue valiendo durante el Corralito, y la UI lo dice")
    func freeHiringStaysAvailable() async throws {
        let gameState = await makeGameState()
        gameState.debugStartCorralito()
        var player = try #require(gameState.player)
        player.run.coins = 0
        player.run.activeModifiers.append(ActiveModifier(
            effect: .spawnCostMultiplier, magnitude: 0,
            expiresAt: Date().timeIntervalSince1970 + 600, sourceKey: "test.free"
        ))
        gameState.player = player
        gameState.refreshProjections()

        #expect(gameState.spendingFrozenUntil != nil)
        #expect(gameState.canAffordSpawn)
        #expect(gameState.quickHireOffer?.affordable == true)
        #expect(gameState.jobRows.contains { $0.affordable })
        let base = try #require(gameState.content?.tiers.baseType.id)
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.hireCharacter(typeId: base)
        #expect(gameState.player?.run.totalUnits == units + 1)
        #expect(gameState.towerNotice == nil)
    }
}
