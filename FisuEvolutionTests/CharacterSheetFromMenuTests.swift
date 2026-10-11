import EconomyKit
import Foundation
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

    private func manifest(_ keys: [String]) throws -> LoopsManifest {
        let entries = keys.map { #""\#($0)":{"file":"\#($0).mov","width":512,"height":512,"alpha":true,"audio":false}"# }
            .joined(separator: ",")
        return try JSONDecoder().decode(
            LoopsManifest.self, from: Data(#"{"schemaVersion":1,"characters":{\#(entries)}}"#.utf8))
    }

    @Test("en la ficha sólo la opción seleccionada y tuya lleva clip; una pinta sin clip queda quieta")
    func sheetClipOnlyForSelectedOwnedWithOwnClip() throws {
        let loops = try manifest(["homeless", "homeless__pijama"])
        func clip(_ skin: String?, selected: Bool = true, owned: Bool = true) -> ArtClip? {
            CharacterSheetView.clip(skinID: skin, type: "homeless", isSelected: selected, owned: owned, in: loops)
        }
        #expect(clip(nil) == .character("homeless"))
        #expect(clip("pijama") == .character("homeless__pijama"))
        #expect(clip("oro") == nil, "una pinta sin clip no hereda el video de la base")
        #expect(clip(nil, selected: false) == nil && clip("pijama", selected: false) == nil)
        #expect(clip("pijama", owned: false) == nil, "la silueta no anima")
    }
}
