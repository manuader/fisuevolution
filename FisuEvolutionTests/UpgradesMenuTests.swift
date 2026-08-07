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

    // MARK: RF-06 — las permanentes dicen qué hacen

    @Test("ninguna mejora permanente queda sin línea de efecto")
    func everyPermanentUpgradeExplainsItself() async throws {
        let gameState = await makeGameState()
        let lines = try #require(gameState.content?.upgradesConfig.upgrades)
        #expect(!lines.isEmpty)
        for line in lines {
            let text = gameState.upgradeEffectText(for: line)
            #expect(!text.isEmpty, "\(line.id) no dice qué hace")
            #expect(text.contains("%") || text.contains("×"), "\(line.id) no muestra ningún número")
        }
    }

    @Test("la línea de efecto muestra a cuánto saltás, y en el tope avisa que no sube más")
    func effectTextShowsProgressionAndCap() async throws {
        let gameState = await makeGameState()
        let line = try #require(gameState.content?.upgradesConfig.upgrades.first { $0.id == "income" })
        #expect(gameState.upgradeEffectText(for: line).contains("→"), "tiene que decir a cuánto saltás")

        var player = try #require(gameState.player)
        player.meta.oroUpgradeLevels[line.id] = line.maxLevel
        gameState.player = player
        let maxed = gameState.upgradeEffectText(for: line)
        #expect(!maxed.contains("→"), "en el nivel máximo no hay salto que mostrar")
    }

    @Test("las siete mejoras permanentes tienen su texto de color en el catálogo")
    func everyPermanentUpgradeHasFlavor() async throws {
        let gameState = await makeGameState()
        let lines = try #require(gameState.content?.upgradesConfig.upgrades)
        for line in lines {
            // Se llama a la MISMA función que dibuja la fila: buscar la clave por
            // otro camino dejaría pasar una vista que imprime la clave cruda, que
            // es exactamente lo que pasó la primera vez (trampa 5 del HANDOFF).
            let text = gameState.upgradeFlavorText(for: line)
            #expect(text != "upgrades.flavor.\(line.id)", "\(line.id) no tiene texto de color en el catálogo")
            #expect(!text.isEmpty)
        }
    }
}
