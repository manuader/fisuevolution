import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los packs consumibles de la tienda (RF-02b): plata, ORO y el starter pack.
///
/// La diferencia con `StoreManagerTests` es de capa: allá se prueba StoreKit
/// contra el `.storekit`; acá se prueba **qué acredita** cada pack, que es la
/// parte que toca la economía y la única que puede romper el balance medido.
@Suite("Packs de la tienda", .serialized)
@MainActor
struct StorePacksTests {
    private func makeRepository() -> PlayerStateRepository {
        PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "packs-\(UUID().uuidString).json")
        )
    }

    private func makeGameState(repository: PlayerStateRepository? = nil) async -> GameState {
        let gameState = GameState(repository: repository ?? makeRepository())
        await gameState.bootstrap()
        return gameState
    }

    private func coinPack(id: String = "pack.coins", factor: Double) -> ProductCatalog.Entry {
        ProductCatalog.Entry(
            id: id,
            type: "consumable",
            entitlement: .coins,
            skinId: nil,
            coinFactor: factor,
            oroAmount: nil
        )
    }

    private func starterPack(id: String = "pack.starter") -> ProductCatalog.Entry {
        ProductCatalog.Entry(
            id: id,
            type: "nonConsumable",
            entitlement: .starterPack,
            skinId: "mundialista",
            coinFactor: 40,
            oroAmount: nil
        )
    }

    private func oroPack(id: String = "pack.oro", amount: Int) -> ProductCatalog.Entry {
        ProductCatalog.Entry(
            id: id,
            type: "consumable",
            entitlement: .oro,
            skinId: nil,
            coinFactor: nil,
            oroAmount: amount
        )
    }

    /// Un monto fijo de plata es basura a las veinte horas de juego: la escala
    /// sale de dónde estás parado, igual que el cofre de carrera (`coinChest`).
    @Test("un pack de plata rinde en proporción al tier más alto alcanzado")
    func coinPackScalesWithMaxTier() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(12)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        let expected = economy.passiveUnlockCost(forTier: 12) * 15

        gameState.creditStorePurchase(coinPack(factor: 15), transactionID: "1")

        let after = try #require(gameState.player)
        #expect(after.run.coins == before.run.coins + expected)
        // La plata comprada cuenta para el ORO, igual que la del cofre.
        #expect(after.meta.lifetimeEarnings == before.meta.lifetimeEarnings + expected)
    }

    /// **Decisión del dueño (2026-08-07)**: el ORO se compra para GASTARLO, no
    /// para saltearse el juego. El multiplicador global sale únicamente de
    /// reencarnar, y por eso se computa sobre `oroEarnedLifetime` y no sobre el
    /// balance. Este test es lo que impide que un pack lo mueva sin querer:
    /// `globalMultiplierPerOro` es el knob que la Ola 3 midió como el más
    /// peligroso de la economía (a 0,25 el colapso de ×1,00 vuelve entero).
    @Test("un pack de ORO da saldo gastable y no toca el multiplicador global")
    func oroPackDoesNotMoveTheGlobalMultiplier() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player)

        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "1")

        let after = try #require(gameState.player)
        #expect(after.meta.oro == before.meta.oro + 250)
        #expect(after.meta.oroEarnedLifetime == before.meta.oroEarnedLifetime)
        #expect(after.meta.globalMultiplier == before.meta.globalMultiplier)
    }

    /// La diferencia de fondo entre un consumible y un entitlement. Un
    /// entitlement se reescribe entero en cada sync y da igual cuántas veces
    /// llegue; una acreditación es un DELTA, y llega dos veces con más facilidad
    /// de la que parece: `purchase()` devuelve la transacción y
    /// `Transaction.updates` puede entregar la misma, y una transacción sin
    /// `finish()` se vuelve a entregar en el próximo arranque.
    @Test("la misma transacción no se acredita dos veces")
    func theSameTransactionCreditsOnce() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player)

        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "42")
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "42")

        let after = try #require(gameState.player)
        #expect(after.meta.oro == before.meta.oro + 250)
    }

    /// Y la guarda es por TRANSACCIÓN, no por producto: comprar dos veces el
    /// mismo pack tiene que acreditar las dos.
    @Test("dos compras distintas del mismo pack acreditan las dos")
    func twoPurchasesOfTheSamePackBothCredit() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player)

        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "42")
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "43")

        let after = try #require(gameState.player)
        #expect(after.meta.oro == before.meta.oro + 500)
    }

    /// El caso que hace que la guarda tenga que vivir en el save y no en
    /// memoria: si la app se cierra entre acreditar y `finish()`, StoreKit
    /// vuelve a entregar esa transacción en el arranque siguiente.
    @Test("la guarda sobrevive a cerrar y abrir la app")
    func theCreditGuardSurvivesARestart() async throws {
        let repository = makeRepository()
        let first = await makeGameState(repository: repository)
        let before = try #require(first.player)
        first.creditStorePurchase(oroPack(amount: 250), transactionID: "42")
        await first.persistNow()

        let reopened = await makeGameState(repository: repository)
        reopened.creditStorePurchase(oroPack(amount: 250), transactionID: "42")

        let after = try #require(reopened.player)
        #expect(after.meta.oro == before.meta.oro + 250)
    }

    /// El starter pack es lo único que reparte por dos caminos a la vez: la
    /// plata la acredita `creditStorePurchase` (una vez y nunca más), y quitar
    /// los ads y la skin salen por `applyStoreEntitlements`, que los reescribe
    /// en cada sync porque son restaurables. El catálogo tiene que declararlo en
    /// los dos lados o el jugador paga y le falta una de las tres.
    @Test("el starter pack cuenta como remove ads y como producto de skin")
    func starterPackGrantsTheRestorableHalf() throws {
        let catalog = ProductCatalog(schemaVersion: 1, products: [starterPack()])

        #expect(catalog.removeAdsProductIDs.contains("pack.starter"))
        #expect(catalog.skinByProductID["pack.starter"] == "mundialista")
    }

    /// La queja del playtest era que las cosas no dicen qué hacen. Un pack que
    /// dice "Fajo de Plata" y nada más es exactamente eso, y encima la plata que
    /// da depende de dónde estás parado: el número tiene que salir calculado.
    ///
    /// El test ejercita **la misma función que dibuja la fila** — un test que
    /// hiciera el lookup por otro camino pasaría con la clave cruda en pantalla
    /// (trampa 5 del HANDOFF, que ya pasó dos veces).
    @Test("la fila del pack de plata dice cuánta plata te da")
    func coinPackRowSaysHowMuchItGives() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(12)
        let economy = try #require(gameState.economy)
        let expected = CoinFormatter.string(from: economy.passiveUnlockCost(forTier: 12) * 15)

        let text = try #require(gameState.packRewardText(for: coinPack(factor: 15)))

        #expect(text.contains(expected))
        #expect(!text.contains("store.pack"), "quedó la clave de localización cruda en pantalla")
    }

    @Test("la fila del pack de ORO dice cuánto ORO te da")
    func oroPackRowSaysHowMuchItGives() async throws {
        let gameState = await makeGameState()

        let text = try #require(gameState.packRewardText(for: oroPack(amount: 750)))

        #expect(text.contains("750"))
        #expect(!text.contains("store.pack"), "quedó la clave de localización cruda en pantalla")
    }

    /// Los productos que no son packs no tienen línea calculada: su descripción
    /// la pone StoreKit y duplicarla sería desincronizarla.
    @Test("un producto que no es pack no inventa una línea")
    func nonPackProductsHaveNoRewardLine() async throws {
        let gameState = await makeGameState()
        let removeAds = ProductCatalog.Entry(
            id: "com.fisuevolution.iap.remove_ads",
            type: "nonConsumable",
            entitlement: .removeAds,
            skinId: nil,
            coinFactor: nil,
            oroAmount: nil
        )

        #expect(gameState.packRewardText(for: removeAds) == nil)
    }

    @Test("el starter pack acredita su plata")
    func starterPackCreditsItsCoins() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(3)
        let economy = try #require(gameState.economy)
        let before = try #require(gameState.player)
        let expected = economy.passiveUnlockCost(forTier: 3) * 40

        gameState.creditStorePurchase(starterPack(), transactionID: "1")

        let after = try #require(gameState.player)
        #expect(after.run.coins == before.run.coins + expected)
    }
}
