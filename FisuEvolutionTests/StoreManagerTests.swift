import EconomyKit
import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import FisuEvolution

/// StoreKit 2 contra la configuración local — cero cuenta paga (bible §4.4).
/// SKTestSession simula la App Store: compra, refund y estado persistente.
/// v4: los entitlements se cachean en `meta` (removedAds / ownedSkins); las
/// skins de milestone viven en `meta.milestoneSkins`, que StoreKit NO pisa.
@Suite("StoreManager (SKTestSession)", .serialized)
@MainActor
struct StoreManagerTests {
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "FisuEvolution")
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    private func makeRepository() -> PlayerStateRepository {
        PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "store-\(UUID().uuidString).json")
        )
    }

    private func makeGameState(repository: PlayerStateRepository? = nil) async -> GameState {
        let gameState = GameState(repository: repository ?? makeRepository())
        await gameState.bootstrap()
        return gameState
    }

    /// Espera hasta que `condition` sea cierta (los updates de StoreKit son async).
    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    @Test func loadsTheFourCatalogProducts() async throws {
        let session = try makeSession()
        defer { _ = session }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        #expect(store.loadState == .loaded)
        #expect(store.products.count == 4)
        #expect(store.products.first?.id == "com.fisuevolution.iap.remove_ads")
    }

    @Test func purchaseGrantsEntitlementAndCachesInPlayerState() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        let removeAds = try #require(store.products.first { $0.id == "com.fisuevolution.iap.remove_ads" })
        await store.purchase(removeAds)

        await waitUntil { store.isPurchased(removeAds.id) }
        #expect(store.isPurchased(removeAds.id))
        // v4: el cache del entitlement vive en meta.
        await waitUntil { gameState.player?.meta.removedAds == true }
        #expect(gameState.player?.meta.removedAds == true)
    }

    @Test func skinPurchaseAllowsActivation() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        let golden = try #require(store.products.first { $0.id == "com.fisuevolution.iap.skin_golden" })
        await store.purchase(golden)
        await waitUntil { gameState.player?.meta.ownedSkins.contains("golden") == true }
        #expect(gameState.player?.meta.ownedSkins == ["golden"])
        #expect(gameState.ownedSkins == ["golden"])

        // Puente F7.1: con más de un tipo poseído, la skin "global" se aplica
        // a TODOS los tipos (la selección por ficha llega en F7.5).
        gameState.debugSetMaxTier(2)
        gameState.debugGrantPair()
        let before = try #require(gameState.player)
        #expect(before.run.units.count >= 2)

        gameState.setActiveSkin("golden")
        let after = try #require(gameState.player)
        for typeId in after.run.units.keys {
            #expect(after.meta.activeSkinByType[typeId] == "golden")
        }
        #expect(after.meta.activeSkinByType.count == after.run.units.count)
        // La proyección legacy del GameState lee la skin del tipo base.
        #expect(gameState.activeSkin == "golden")

        // Una skin no comprada no se puede activar.
        gameState.setActiveSkin("god")
        #expect(gameState.activeSkin == "golden")

        // nil limpia el puente entero.
        gameState.setActiveSkin(nil)
        #expect(gameState.player?.meta.activeSkinByType.isEmpty == true)
        #expect(gameState.activeSkin == nil)
    }

    @Test func refundRevokesEntitlement() async throws {
        let session = try makeSession()
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        let removeAds = try #require(store.products.first { $0.id == "com.fisuevolution.iap.remove_ads" })
        await store.purchase(removeAds)
        await waitUntil { store.isPurchased(removeAds.id) }

        let transaction = try #require(session.allTransactions().first)
        try session.refundTransaction(identifier: UInt(transaction.identifier))

        await waitUntil { !store.isPurchased(removeAds.id) }
        #expect(!store.isPurchased(removeAds.id))
        await waitUntil { gameState.player?.meta.removedAds == false }
        #expect(gameState.player?.meta.removedAds == false)
    }

    /// StoreKit reescribe `meta.ownedSkins` ENTERA en cada sync, pero las skins
    /// de milestone son un campo aparte: sobreviven al sync, siguen contando
    /// como poseídas (unión) y una milestone activa no se desactiva.
    @Test func storeSyncPreservesMilestoneSkins() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        // Save preexistente con una skin de milestone ganada y activa.
        let repository = makeRepository()
        var seeded = PlayerState.newGame(
            startTypeId: "homeless",
            startFloorId: "alley",
            offlineEfficiencyBase: 0.35,
            critChanceBase: 0,
            now: Date().timeIntervalSince1970
        )
        seeded.meta.milestoneSkins = ["milestone_asado"]
        seeded.meta.activeSkinByType = ["homeless": "milestone_asado"]
        // Daily ya reclamado hoy: este test verifica el store, no el daily.
        seeded.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
        await repository.save(seeded)

        let gameState = await makeGameState(repository: repository)
        let store = StoreManager()
        await store.start(gameState: gameState)

        let golden = try #require(store.products.first { $0.id == "com.fisuevolution.iap.skin_golden" })
        await store.purchase(golden)
        await waitUntil { gameState.player?.meta.ownedSkins.contains("golden") == true }

        let player = try #require(gameState.player)
        // El cache de StoreKit quedó reescrito solo con lo comprado…
        #expect(player.meta.ownedSkins == ["golden"])
        // …y la milestone no fue pisada.
        #expect(player.meta.milestoneSkins == ["milestone_asado"])
        // La proyección de la UI muestra la unión, ordenada.
        #expect(gameState.ownedSkins == ["golden", "milestone_asado"])
        // El filtro anti-huérfanos de applyStoreEntitlements no echó a la activa.
        #expect(player.meta.activeSkinByType["homeless"] == "milestone_asado")
        #expect(gameState.activeSkin == "milestone_asado")
    }
}
