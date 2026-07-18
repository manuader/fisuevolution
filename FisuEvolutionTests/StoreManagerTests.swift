import EconomyKit
import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import FisuEvolution

/// StoreKit 2 contra la configuración local — cero cuenta paga (bible §4.4).
/// SKTestSession simula la App Store: compra, refund y estado persistente.
@Suite("StoreManager (SKTestSession)", .serialized)
@MainActor
struct StoreManagerTests {
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "FisuEvolution")
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    private func makeGameState() async -> GameState {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "store-\(UUID().uuidString).json")
        )
        let gameState = GameState(repository: repository)
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
        await waitUntil { gameState.player?.removedAds == true }
        #expect(gameState.player?.removedAds == true)
    }

    @Test func skinPurchaseAllowsActivation() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        let golden = try #require(store.products.first { $0.id == "com.fisuevolution.iap.skin_golden" })
        await store.purchase(golden)
        await waitUntil { gameState.player?.ownedSkins.contains("golden") == true }
        #expect(gameState.player?.ownedSkins == ["golden"])

        gameState.setActiveSkin("golden")
        #expect(gameState.player?.activeSkin == "golden")
        // Una skin no comprada no se puede activar.
        gameState.setActiveSkin("god")
        #expect(gameState.player?.activeSkin == "golden")
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
        await waitUntil { gameState.player?.removedAds == false }
        #expect(gameState.player?.removedAds == false)
    }
}
