import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Las pintas de la v1 que dejaron el cofre y se venden con blue (PLAN-v2 E6b T8).
///
/// La lista es del dueño y se cambia en dos lugares a la vez: `skins.json` (quitar
/// `bluePrice`, devolver `chestRarity`) y `blueExclusives` de acá. El dueño no aprobó
/// ningún efecto de shader: el catálogo no vende nada de ese tipo.
@Suite("Las exclusivas de blue entre las pintas de la v1")
@MainActor
struct BlueSkinsContentTests {
    nonisolated static let blueExclusives: [String: Int] = [
        "agujero_negro": 300, "dinastia": 300, "iluminado": 300, "titan": 300,
        "corona_solar": 150, "selenita": 150, "terraformador": 150, "moneda_propia": 150,
    ]
    nonisolated static let approvedEffects: [String] = []

    private let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private func makeGameState() async -> GameState {
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "orot8-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        return gameState
    }

    @Test("sin efectos aprobados el catálogo no vende ningún comodín de shader")
    func noEffectsForSale() {
        #expect(Self.approvedEffects.isEmpty)
        #expect(content.skins.skins.allSatisfy { $0.characterType != "*" })
    }

    @Test("cada exclusiva se vende con su precio y dejó el cofre y los hitos", arguments: Array(blueExclusives.keys.sorted()))
    func exclusiveLeftTheChest(id: String) throws {
        let entries = content.skins.skins.filter { $0.id == id }
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.chestRarity == nil)
        #expect(!entry.isMilestone)
        #expect(entry.bluePrice == Self.blueExclusives[id])
        #expect(content.skins.blueSkinIDs.contains(id))
        #expect(!content.skins.chestPool.contains { $0.id == id })
    }

    @Test("la tienda las lista como pinta de un solo personaje")
    func shelfListsThemAsOutfits() throws {
        let rows = CosmeticRow.rows(skins: content.skins, owned: [])
        for (id, price) in Self.blueExclusives {
            let row = try #require(rows.first { $0.id == id }, "falta \(id)")
            #expect(row.price == price)
            #expect(!row.owned)
            guard case .outfit = row.kind else {
                Issue.record("\(id) tiene que ser una pinta de un personaje")
                continue
            }
        }
    }

    @Test("el resto de la bolsa sigue entera: las demás pintas de la v1 siguen saliendo del cofre")
    func restOfThePoolIsIntact() {
        let pool = content.skins.chestPool
        #expect(pool.count == 41 - Self.blueExclusives.count)
        #expect(pool.contains { $0.id == "oraculo" })
        #expect(pool.contains { $0.id == content.chests.welcomeSkinId })
        for rarity in SkinsConfig.Rarity.allCases {
            #expect(pool.contains { $0.chestRarity == rarity }, "\(rarity) quedó vacía")
        }
    }

    @Test("miles de cofres con todo desbloqueado nunca reparten una exclusiva, y sí las demás")
    func chestNeverDealsAnExclusive() {
        let unlocked = Set(content.tiers.concreteTypes.map(\.id))
        var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
        var seen = Set<String>()
        var seenRarities = Set<SkinsConfig.Rarity>()
        for _ in 0..<3000 {
            guard case let .prize(.skin(id, _, rarity)) = ChestRoller.roll(
                owned: [], unlocked: unlocked, skins: content.skins, config: content.chests, using: &rng
            ) else { Issue.record("con la bolsa vacía tiene que salir una pinta"); return }
            seen.insert(id)
            seenRarities.insert(rarity)
        }
        #expect(seen.isDisjoint(with: Self.blueExclusives.keys), "salió \(seen.intersection(Self.blueExclusives.keys))")
        #expect(seen.count >= 25, "la prueba no es vacua: salen las demás (\(seen.count))")
        #expect(seenRarities == Set(SkinsConfig.Rarity.allCases))
    }

    @Test("con la bolsa entera ganada el cofre paga plata: una exclusiva no se cuela de relleno")
    func completeCollectionPaysCoinsNotAnExclusive() {
        let unlocked = Set(content.tiers.concreteTypes.map(\.id))
        let owned = Set(content.skins.chestPool.map(\.id))
        var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            guard case .prize(.coins) = ChestRoller.roll(
                owned: owned, unlocked: unlocked, skins: content.skins, config: content.chests, using: &rng
            ) else { Issue.record("la colección está completa: tenía que pagar plata"); return }
        }
    }

    @Test("quien ya la tenía la conserva y no se le cobra")
    func ownerKeepsIt() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.milestoneSkins = ["titan"]
        gameState.player?.meta.blue = 5000
        #expect(gameState.ownsSkin("titan"))
        #expect(gameState.buySkinWithBlue(skinID: "titan") == .unavailable)
        #expect(gameState.player?.meta.blue == 5000, "no se cobra lo que ya es tuyo")
        #expect(gameState.player?.meta.milestoneSkins.contains("titan") == true)
        let row = try #require(gameState.cosmeticRows.first { $0.id == "titan" })
        #expect(row.owned)
        #expect(gameState.cosmeticRows.first { $0.id == "dinastia" }?.owned == false, "la otra no es suya")
    }

    @Test("quien no la tenía la ve con precio, la compra una vez y le cuesta lo del catálogo")
    func newcomerPaysOnce() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.blue = 1000
        let row = try #require(gameState.cosmeticRows.first { $0.id == "agujero_negro" })
        #expect(!row.owned)
        #expect(row.price == 300)
        #expect(gameState.buySkinWithBlue(skinID: "agujero_negro") == .bought)
        #expect(gameState.buySkinWithBlue(skinID: "agujero_negro") == .unavailable)
        #expect(gameState.player?.meta.blue == 700, "cobra una sola vez")
        #expect(gameState.ownsSkin("agujero_negro"))
        #expect(gameState.cosmeticRows.first { $0.id == "agujero_negro" }?.owned == true)
    }

    @Test("sin blue suficiente no cobra ni entrega")
    func cannotAffordDoesNothing() async {
        let gameState = await makeGameState()
        gameState.player?.meta.blue = 299
        #expect(gameState.buySkinWithBlue(skinID: "dinastia") == .refused(.cantAfford))
        #expect(gameState.player?.meta.blue == 299)
        #expect(!gameState.ownsSkin("dinastia"))
    }
}
