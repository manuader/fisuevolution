import EconomyKit
import Testing
@testable import FisuEvolution

/// RF-03, RF-04 y RF-06: la pantalla de la que más se quejó el playtest. La lista
/// esconde personajes, el pasivo sólo se compra con un gesto que nadie descubre y
/// ninguna fila dice qué hace.
@Suite("Menú de mejoras")
@MainActor
struct UpgradesMenuTests {
    // MARK: RF-03 — la lista no se borra

    @Test("mergear el último Fisura no lo saca de la lista de mejoras")
    func mergingTheLastUnitKeepsItListed() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        #expect(gameState.characterUpgradeRows.contains { $0.id == base })

        // Sin unidades vivas del tipo base, la fila tiene que seguir estando: su
        // mejora sigue comprada y sigue rindiendo.
        var player = try #require(gameState.player)
        player.run.units[base] = nil
        gameState.player = player
        #expect(gameState.characterUpgradeRows.contains { $0.id == base })
    }

    @Test("un tipo que nunca desbloqueaste no aparece (no se espoilean evoluciones)")
    func unseenTypesStayHidden() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        #expect(gameState.characterUpgradeRows.map(\.id) == [base])
    }

    // MARK: RF-04 — dos botones por fila, con el número de ese personaje

    @Test("cada fila dice qué hace cada botón, con el número de ese personaje")
    func rowsExplainBothButtons() async throws {
        let gameState = await makeGameState()
        let row = try #require(gameState.characterUpgradeRows.first)
        #expect(row.multiplierText.hasPrefix("×"), "la fila tiene que decir el multiplicador, no el nivel")
        #expect(row.nextMultiplierText != row.multiplierText, "tiene que decir a cuánto saltás")
        #expect(row.passiveEffectText.contains("/s"), "el pasivo tiene que decir cuánto rinde por segundo")
        #expect(
            row.passiveEffectText.contains(row.displayName),
            "el texto tiene que nombrar al personaje, no hablar en abstracto"
        )
    }

    @Test("el multiplicador que muestra la fila es el que aplica la economía")
    func multiplierTextTracksTheConfig() async throws {
        let gameState = await makeGameState()
        let factor = try #require(gameState.content?.economy.charUpgrades.effectFactorPerLevel)
        let typeId = try #require(gameState.characterUpgradeRows.first?.id)
        gameState.debugGrantCoins()
        gameState.buyCharacterUpgrade(typeID: typeId)

        let row = try #require(gameState.characterUpgradeRows.first)
        #expect(gameState.characterUpgradeLevel(of: typeId) == 1)
        let applied = CharUpgrades.multiplier(
            typeId: typeId,
            levels: try #require(gameState.player?.run.charUpgradeLevels),
            config: try #require(gameState.content?.economy)
        )
        #expect(applied == factor)
        #expect(row.multiplierText.contains(factor.formatted(.number.precision(.fractionLength(0...1)))))
    }

    @Test("se compra el pasivo desde el menú y el income del tipo sube")
    func buyPassiveFromMenu() async throws {
        let gameState = await makeGameState()
        let typeId = try #require(gameState.characterUpgradeRows.first?.id)
        #expect(gameState.characterUpgradeRows[0].passiveUnlocked == false)

        gameState.debugGrantCoins()
        gameState.flushHUD()
        let before = gameState.towerIncomePerSecond

        gameState.buyPassiveFromMenu(typeId: typeId)
        gameState.flushHUD()

        #expect(gameState.characterUpgradeRows[0].passiveUnlocked)
        #expect(gameState.towerIncomePerSecond > before, "comprar el pasivo tiene que subir el income del tipo")
    }
}
