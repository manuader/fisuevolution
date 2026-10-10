import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El Álbum de especiales")
@MainActor
struct SpecialsAlbumTests {
    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "album-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return gameState
    }

    @Test("están los diez, en el orden del catálogo; sin conseguir, sin efecto")
    func allTenInCatalogOrder() async throws {
        let gameState = await makeGameState()
        let catalog = try #require(gameState.content?.specials.specials.map(\.id))
        #expect(gameState.albumEntries.map(\.id) == catalog)
        #expect(gameState.albumEntries.count == 10)
        #expect(gameState.albumEntries.allSatisfy { !$0.owned && $0.effectText.isEmpty })
        #expect(gameState.albumOwnedCount == 0)
    }

    @Test("uno conseguido muestra lo que da, con el formateador de siempre")
    func anOwnedSpecialShowsItsEffect() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.ownedSpecials.append("sp_cryptobro")
        let entry = try #require(gameState.albumEntries.first { $0.id == "sp_cryptobro" })
        #expect(entry.owned)
        #expect(entry.effectText == String(localized: "album.effect.income \("+3%")"))
        #expect(gameState.albumOwnedCount == 1)
    }

    @Test("el pasivo de un especial se lee como bonus o descuento, nunca como factor")
    func specialAmounts() {
        #expect(EffectFormatter.text(EffectDescriptor.amount(forSpecial: .incomeMultiplier, magnitude: 1.1)) == "+10%")
        #expect(EffectFormatter.text(EffectDescriptor.amount(forSpecial: .offlineEfficiencyBonus, magnitude: 0.05)) == "+5%")
        #expect(EffectFormatter.text(EffectDescriptor.amount(forSpecial: .critChanceBonus, magnitude: 0.02)) == "+2%")
        #expect(EffectFormatter.text(EffectDescriptor.amount(forSpecial: .spawnDiscount, magnitude: 0.05)) == "−5%")
    }

    private func entry(_ id: String, owned: Bool) -> AlbumEntry {
        AlbumEntry(id: id, owned: owned, nameKey: "", flavorKey: "", effectText: "", minTier: 1)
    }

    @Test("al entrar, la enfocada es el primer especial que tenés; sin ninguno, nadie")
    func initialFocusIsTheFirstOwned() {
        let entries = [entry("a", owned: false), entry("b", owned: true), entry("c", owned: true)]
        #expect(AlbumFocus.initial(entries) == "b")
        #expect(AlbumFocus.initial([entry("a", owned: false)]) == nil)
    }

    @Test("tocar uno tuyo lo enfoca; uno que falta o el enfocado no cambian nada")
    func tapMovesFocusOnlyToOwned() {
        let entries = [entry("a", owned: true), entry("b", owned: true), entry("c", owned: false)]
        #expect(AlbumFocus.tap("b", entries: entries, current: "a") == "b")
        #expect(AlbumFocus.tap("c", entries: entries, current: "a") == "a")
        #expect(AlbumFocus.tap("a", entries: entries, current: "a") == "a")
    }
}
