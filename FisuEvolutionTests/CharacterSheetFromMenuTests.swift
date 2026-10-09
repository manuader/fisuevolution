import EconomyKit
import Testing
@testable import FisuEvolution

@Suite("La ficha desde Personajes")
@MainActor
struct CharacterSheetFromMenuTests {
    @Test("la ficha de un tipo apunta a una unidad suya, aunque esté en otro piso")
    func sheetFindsAUnit() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let types = content.tiers.concreteTypes.sorted { $0.tier < $1.tier }
        let base = try #require(types.first)
        let upper = try #require(types.first { content.floorTable.ordinal(forTier: $0.tier) > 0 })
        gameState.player?.run.units = [base.id: 2, upper.id: 1]
        gameState.reconcileTower()
        gameState.visibleFloorOrdinal = 0

        let sheet = try #require(gameState.characterSheet(forTypeId: upper.id))

        #expect(sheet.floorOrdinal == content.floorTable.ordinal(forTier: upper.tier))
        #expect(sheet.canDismiss)
        gameState.dismissCharacter(floorOrdinal: sheet.floorOrdinal, slot: sheet.cellIndex)
        #expect(gameState.player?.run.units[upper.id] ?? 0 == 0)
        #expect(gameState.player?.run.units[base.id] == 2)
    }

    @Test("sin unidades del tipo, la ficha abre igual pero no deja despedir")
    func sheetWithoutUnits() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let type = try #require(content.tiers.concreteTypes.first { $0.tier == 3 })
        gameState.debugMarkTypesSeen(throughTier: 3)

        let sheet = try #require(gameState.characterSheet(forTypeId: type.id))

        #expect(sheet.instanceCount == 0 && !sheet.canDismiss && sheet.floorOrdinal == -1)
    }
}
