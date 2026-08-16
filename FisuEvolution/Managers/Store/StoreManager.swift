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

    /// De dónde salen los productos. Es una propiedad y no una llamada directa
    /// a `Product.products(for:)` por una sola razón: **la única forma de tener
    /// una tienda que no contesta es poner un fetch que no conteste**, y el
    /// defecto que este manager arregla (HANDOFF §8) es justamente ese.
    @ObservationIgnored
    var productsFetcher: @Sendable ([String]) async throws -> [Product] = {
        try await Product.products(for: $0)
    }

    /// Cuánto se espera a StoreKit antes de dar la carga por perdida. Es `var`
    /// para que los tests corran la carrera en milisegundos en vez de en diez
    /// segundos; en la app nadie lo toca.
    @ObservationIgnored
    var loadTimeout: Duration = .seconds(10)

    /// Qué carga es la vigente. Una carga vieja que contesta tarde —el fetch que
    /// perdió la carrera y volvió igual, después de que el jugador tocó
    /// "Reintentar"— no puede pisar el resultado de la nueva.
    @ObservationIgnored private var loadGeneration = 0

    init() {}

    /// **Sólo para tests**: el manager con el catálogo ya puesto y sin el
    /// listener de `Transaction.updates`, para poder ejercitar `loadProducts()`
    /// sin la App Store de por medio. `start(gameState:)` es el camino de la app.
    init(catalog: ProductCatalog, productsFetcher: @escaping @Sendable ([String]) async throws -> [Product]) {
        self.catalog = catalog
        self.productsFetcher = productsFetcher
    }

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
        #if DEBUG
        // Fixture: la tienda que no contesta (sin red, o la app corriendo sin
        // configuración de StoreKit).
        //
        // Hace falta una puerta porque **desde un test no se puede llegar a esa
        // rama de otro modo**: el runner levanta la app con la configuración de
        // StoreKit del scheme y los productos cargan siempre. Y esa rama es la
        // que dibuja "Precio no disponible" en Pintas, o sea justo lo que hay
        // que proteger de volver a mentir "no está a la venta".
        if ProcessInfo.processInfo.arguments.contains("--uitest-storekit-empty") {
            products = []
            loadState = .failed
            return
        }
        #endif
        loadGeneration += 1
        let generation = loadGeneration
        let outcome = await fetchWithDeadline(ids: catalog.allProductIDs)
        // La carga que contesta cuando ya hay otra en curso se descarta: el
        // jugador tocó "Reintentar" y lo que vale es el intento nuevo.
        guard generation == loadGeneration else { return }

        switch outcome {
        case .loaded(let loaded):
            // Orden estable: el del catálogo (remove ads primero, skins después).
            let order = Dictionary(uniqueKeysWithValues: catalog.allProductIDs.enumerated().map { ($1, $0) })
            products = loaded.sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
            loadState = .loaded
        case .failed:
            loadState = .failed
        case .timedOut:
            Log.store.error("product load timed out after \(self.loadTimeout, privacy: .public)")
            loadState = .failed
        }
    }

    /// Cómo terminó una carga.
    private enum LoadOutcome: Sendable {
        case loaded([Product])
        /// StoreKit contestó con un error.
        case failed
        /// StoreKit no contestó a tiempo. Se distingue de `failed` para poder
        /// nombrarlo en el log: es el defecto que la pantalla no podía ver.
        case timedOut
    }

    /// El fetch de productos con plazo: gana el primero que conteste.
    ///
    /// ⚠️ **La carrera no se escribe con `withThrowingTaskGroup`** aunque sea el
    /// reflejo obvio. Un grupo no termina hasta que TODOS sus hijos terminan, y
    /// cancelarlo es sólo un pedido: con el fetch colgado —que es exactamente el
    /// defecto que esto arregla— el grupo no sale nunca y `loadProducts()`
    /// seguiría sin volver, con plazo y todo. Con el canal, se lee al ganador y
    /// al perdedor se lo suelta: lo que llegue tarde cae en un `AsyncStream` que
    /// ya no lee nadie, y la guarda de generación se ocupa del resto.
    private func fetchWithDeadline(ids: [String]) async -> LoadOutcome {
        let (outcomes, publish) = AsyncStream<LoadOutcome>.makeStream()
        let fetcher = productsFetcher
        let timeout = loadTimeout

        let fetch = Task {
            do {
                publish.yield(.loaded(try await fetcher(ids)))
            } catch {
                Log.store.error("product load failed: \(error)")
                publish.yield(.failed)
            }
        }
        let deadline = Task {
            // Cancelado (ganó el fetch) no publica nada: sin este `return`, el
            // sueño interrumpido se leería como un plazo vencido.
            do { try await Task.sleep(for: timeout) } catch { return }
            publish.yield(.timedOut)
        }
        defer {
            fetch.cancel()
            deadline.cancel()
        }

        for await outcome in outcomes { return outcome }
        return .timedOut
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
