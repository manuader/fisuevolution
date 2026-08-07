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

    /// El catálogo completo de RF-02b, en el orden de `products.json`:
    /// `loadProducts()` reordena lo que devuelve StoreKit, que no garantiza
    /// ninguno. El orden es de venta —el combo primero, las skins al final— y
    /// este test es lo que lo pinea.
    @Test func loadsTheCatalogProducts() async throws {
        let session = try makeSession()
        defer { _ = session }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        #expect(store.loadState == .loaded)
        #expect(store.products.map(\.id) == [
            "com.fisuevolution.iap.starter_pack",
            "com.fisuevolution.iap.remove_ads",
            "com.fisuevolution.iap.coins_small",
            "com.fisuevolution.iap.coins_medium",
            "com.fisuevolution.iap.coins_large",
            "com.fisuevolution.iap.oro_small",
            "com.fisuevolution.iap.oro_medium",
            "com.fisuevolution.iap.oro_large",
            "com.fisuevolution.iap.skin_mundialista",
            "com.fisuevolution.iap.skin_parrillero",
        ])
    }

    /// RF-02b, el recorrido entero de un CONSUMIBLE, que no es el de un
    /// entitlement: StoreKit no lo devuelve nunca en `currentEntitlements`, así
    /// que si `handle` no lo acredita en el momento la plata no llega nunca.
    @Test func purchasingACoinPackCreditsCoins() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        gameState.debugSetMaxTier(12)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player).run.coins
        let expected = economy.passiveUnlockCost(forTier: 12) * 15

        let pack = try #require(store.products.first { $0.id == "com.fisuevolution.iap.coins_small" })
        await store.purchase(pack)

        await waitUntil { (gameState.player?.run.coins ?? 0) > before }
        #expect(gameState.player?.run.coins == before + expected)
    }

    @Test func purchasingAnOroPackCreditsSpendableOro() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        let before = try #require(gameState.player).meta.oro

        let pack = try #require(store.products.first { $0.id == "com.fisuevolution.iap.oro_small" })
        await store.purchase(pack)

        await waitUntil { (gameState.player?.meta.oro ?? 0) > before }
        #expect(gameState.player?.meta.oro == before + 250)
        // La compra no compra multiplicador: eso sólo lo da reencarnar.
        #expect(gameState.player?.meta.oroEarnedLifetime == 0)
    }

    /// Un consumible se vuelve a comprar. Si quedara marcado como "comprado" la
    /// tienda le pondría el tilde y el jugador no podría comprar el segundo.
    @Test func aCoinPackStaysBuyableAfterBuyingIt() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        let before = try #require(gameState.player).run.coins
        let pack = try #require(store.products.first { $0.id == "com.fisuevolution.iap.coins_small" })
        await store.purchase(pack)
        await waitUntil { (gameState.player?.run.coins ?? 0) > before }

        #expect(!store.isPurchased(pack.id))
    }

    /// El combo reparte por los dos caminos a la vez: la plata la acredita el
    /// camino de consumible, y quitar los ads y la skin el de entitlement.
    @Test func theStarterPackGrantsItsThreeThings() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        let before = try #require(gameState.player).run.coins
        let pack = try #require(store.products.first { $0.id == "com.fisuevolution.iap.starter_pack" })
        await store.purchase(pack)

        await waitUntil { gameState.player?.meta.removedAds == true }
        #expect(gameState.player?.meta.removedAds == true)
        #expect(gameState.ownsSkin("mundialista"))
        #expect((gameState.player?.run.coins ?? 0) > before)
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

    /// Sin tintes IAP la tienda ya no vende skins, pero el contrato de EQUIPAR
    /// sigue igual de vivo y ahora se ejercita con la única fuente que queda:
    /// las de milestone. Equipar es POR TIPO — una skin puesta en un personaje
    /// no se derrama sobre los demás— y una que no tenés no se puede equipar.
    @Test func equippingIsScopedToTheCharacterType() async throws {
        let repository = makeRepository()
        var seeded = PlayerState.newGame(
            startTypeId: "homeless",
            startFloorId: "alley",
            offlineEfficiencyBase: 0.35,
            critChanceBase: 0,
            now: Date().timeIntervalSince1970
        )
        seeded.meta.milestoneSkins = ["second_life"]
        seeded.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
        await repository.save(seeded)
        let gameState = await makeGameState(repository: repository)

        gameState.debugSetMaxTier(2)
        gameState.debugGrantPair()
        let before = try #require(gameState.player)
        #expect(before.run.units.count >= 2)

        gameState.equipSkin(id: "second_life", forCharacterType: "homeless")
        let after = try #require(gameState.player)
        #expect(after.meta.activeSkinByType["homeless"] == "second_life")
        #expect(after.meta.activeSkinByType.count == 1)
        #expect(gameState.activeSkinID(forCharacterType: "homeless") == "second_life")
        #expect(gameState.activeSkinID(forCharacterType: "cartonero") == nil)

        // Una skin que no tenés no se puede equipar.
        gameState.equipSkin(id: "urban_trailblazer", forCharacterType: "homeless")
        #expect(gameState.activeSkinID(forCharacterType: "homeless") == "second_life")

        // nil vuelve ese tipo a su apariencia base.
        gameState.equipSkin(id: nil, forCharacterType: "homeless")
        #expect(gameState.activeSkinID(forCharacterType: "homeless") == nil)
    }

    @Test func refundRevokesEntitlement() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        let removeAds = try #require(store.products.first { $0.id == "com.fisuevolution.iap.remove_ads" })
        await store.purchase(removeAds)
        await waitUntil { store.isPurchased(removeAds.id) }

        // Por productID, NO `.first`: desde que la tienda vende tres productos
        // `allTransactions()` no tiene un orden garantizado, y refundear la
        // transacción equivocada dejaba el test rojo de manera intermitente.
        let transaction = try #require(
            session.allTransactions().first { $0.productIdentifier == removeAds.id },
            "no apareció la transacción de remove_ads"
        )
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

        // Sin skins en la tienda, el sync se dispara igual con cualquier compra:
        // lo que se prueba es que reescribir `ownedSkins` no pise las milestone.
        let removeAds = try #require(store.products.first { $0.id == "com.fisuevolution.iap.remove_ads" })
        await store.purchase(removeAds)
        await waitUntil { gameState.player?.meta.removedAds == true }

        let player = try #require(gameState.player)
        // El cache de StoreKit quedó reescrito sin skins…
        #expect(player.meta.ownedSkins.isEmpty)
        // …y la milestone no fue pisada.
        #expect(player.meta.milestoneSkins == ["milestone_asado"])
        // La proyección de la UI muestra la unión, ordenada.
        #expect(gameState.ownedSkins == ["milestone_asado"])
        // El filtro anti-huérfanos de applyStoreEntitlements no echó a la activa.
        #expect(player.meta.activeSkinByType["homeless"] == "milestone_asado")
        #expect(gameState.activeSkinID(forCharacterType: "homeless") == "milestone_asado")
    }

    /// RF-13: las dos skins de arte propio se venden. Un caso por skin.
    ///
    /// El recorrido entero de una compra cosmética: antes de pagar la skin NO se
    /// puede equipar (aunque `skins.json` la declare para ese tipo), la compra la
    /// acredita en `meta.ownedSkins`, y recién ahí la ficha de personaje la deja
    /// poner. Se ejercita `equipSkin`, que es la misma función que llama la ficha
    /// — un test que sólo mirara `ownedSkins` pasaría sin probar que se equipa.
    @Test(arguments: [
        (productID: "com.fisuevolution.iap.skin_mundialista", skinID: "mundialista", characterType: "homeless"),
        (productID: "com.fisuevolution.iap.skin_parrillero", skinID: "parrillero", characterType: "god"),
    ])
    func purchasingASkinMakesItEquippable(
        productID: String,
        skinID: String,
        characterType: String
    ) async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let gameState = await makeGameState()
        let store = StoreManager()
        await store.start(gameState: gameState)

        // La skin está en el catálogo de ese tipo, pero todavía no es suya.
        #expect(gameState.skinOptions(forCharacterType: characterType).contains { $0.id == skinID })
        #expect(!gameState.ownsSkin(skinID))
        gameState.equipSkin(id: skinID, forCharacterType: characterType)
        #expect(gameState.activeSkinID(forCharacterType: characterType) == nil, "se equipó sin comprarla")

        let product = try #require(store.products.first { $0.id == productID })
        await store.purchase(product)

        await waitUntil { store.isPurchased(productID) }
        #expect(store.isPurchased(productID))
        // El entitlement se cachea en `ownedSkins`, no en `milestoneSkins`.
        await waitUntil { gameState.ownsSkin(skinID) }
        let player = try #require(gameState.player)
        #expect(player.meta.ownedSkins.contains(skinID))
        #expect(!player.meta.milestoneSkins.contains(skinID))

        // Y ahora sí la ficha la deja equipar, sólo en su propio tipo.
        gameState.equipSkin(id: skinID, forCharacterType: characterType)
        #expect(gameState.activeSkinID(forCharacterType: characterType) == skinID)
        #expect(SkinResolver.treatment(
            for: skinID,
            characterType: characterType,
            config: try #require(gameState.content?.skins)
        ) != .base, "la skin comprada no cambia el render")
    }
}
