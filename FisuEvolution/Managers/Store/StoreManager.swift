import Foundation
import Observation
import StoreKit

/// StoreKit 2 front-end. StoreKit is the source of truth for entitlements;
/// `PlayerState` only caches them (survives reinstalls via restore/sync).
/// Testable end-to-end against the local `.storekit` file — no paid account.
@Observable @MainActor
final class StoreManager {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    private(set) var loadState: LoadState = .idle
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isPurchasing = false
    private(set) var lastErrorMessage: String?

    private var catalog: ProductCatalog?
    private weak var gameState: GameState?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// Called once from the app root. Starts the lifetime `Transaction.updates`
    /// listener (required: purchases can arrive at any moment) and hydrates.
    func start(gameState: GameState) async {
        guard updatesTask == nil else { return }
        self.gameState = gameState

        do {
            catalog = try ProductCatalog.load(from: .main)
        } catch let error as GameError {
            Log.store.critical("catalog unavailable: \(error.debugDetail)")
            loadState = .failed
            return
        } catch {
            loadState = .failed
            return
        }

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }

        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        guard let catalog else { return }
        loadState = .loading
        do {
            let loaded = try await Product.products(for: catalog.allProductIDs)
            // Orden estable: el del catálogo (remove ads primero, skins después).
            let order = Dictionary(uniqueKeysWithValues: catalog.allProductIDs.enumerated().map { ($1, $0) })
            products = loaded.sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
            loadState = .loaded
        } catch {
            Log.store.error("product load failed: \(error)")
            loadState = .failed
        }
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        lastErrorMessage = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            Log.store.error("purchase failed: \(error)")
            lastErrorMessage = String(localized: "store.error.purchase")
        }
    }

    func restore() async {
        lastErrorMessage = nil
        do {
            try await AppStore.sync()
        } catch {
            Log.store.error("restore failed: \(error)")
            lastErrorMessage = String(localized: "store.error.restore")
        }
        await refreshEntitlements()
    }

    func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    func skinId(for productID: String) -> String? {
        catalog?.skinByProductID[productID]
    }

    /// La entrada del catálogo de un producto. La tienda la necesita para
    /// agrupar las filas por lo que entregan y para pedirle a `GameState` el
    /// monto concreto de un pack.
    func entry(for productID: String) -> ProductCatalog.Entry? {
        catalog?.products.first { $0.id == productID }
    }

    // MARK: - Internals

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else {
            Log.store.error("unverified transaction dropped")
            return
        }
        let entry = catalog?.products.first { $0.id == transaction.productID }

        if transaction.revocationDate != nil {
            purchasedProductIDs.remove(transaction.productID)
            Log.store.warning("entitlement revoked: \(transaction.productID)")
        } else {
            // Acreditar ANTES de `finish()`: una transacción sin finalizar se
            // vuelve a entregar en el arranque siguiente, así que si la app se
            // muere en el medio la plata igual llega. Que no llegue DOS veces
            // lo garantiza la guarda de `creditStorePurchase`, que está en el save.
            if let entry {
                gameState?.creditStorePurchase(entry, transactionID: String(transaction.id))
            }
            // Un consumible no queda "comprado": se vuelve a vender.
            if entry?.isConsumable != true {
                purchasedProductIDs.insert(transaction.productID)
            }
            Log.store.info("entitlement granted: \(transaction.productID)")
        }
        pushEntitlementsToGameState()
        await transaction.finish()
    }

    private func refreshEntitlements() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
        pushEntitlementsToGameState()
    }

    private func pushEntitlementsToGameState() {
        guard let catalog else { return }
        let removedAds = !catalog.removeAdsProductIDs.isDisjoint(with: purchasedProductIDs)
        let ownedSkins = catalog.skinByProductID
            .filter { purchasedProductIDs.contains($0.key) }
            .map(\.value)
            .sorted()
        gameState?.applyStoreEntitlements(removedAds: removedAds, ownedSkins: ownedSkins)
    }
}
