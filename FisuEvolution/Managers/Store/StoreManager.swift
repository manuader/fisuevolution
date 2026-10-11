import Foundation
import Observation
import StoreKit
#if DEBUG
import StoreKitTest
#endif

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
    @ObservationIgnored private var isStarted = false

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

    /// De dónde sale el historial de transacciones para reconstruir el ORO de la
    /// v1. Es una propiedad por lo mismo que `productsFetcher`: la única forma de
    /// probar un historial que no contesta es poder ponerle uno que no conteste.
    @ObservationIgnored
    var historyReader: @Sendable () async -> [PurchasedOroHistory.Record] = {
        var records: [PurchasedOroHistory.Record] = []
        for await result in Transaction.all {
            guard case .verified(let transaction) = result else { continue }
            records.append(.init(
                transactionID: String(transaction.id),
                productID: transaction.productID,
                isRevoked: transaction.revocationDate != nil
            ))
        }
        return records
    }

    /// Cuánto se espera al historial antes de darlo por fallado. `var` por lo
    /// mismo que `loadTimeout`.
    @ObservationIgnored
    var historyTimeout: Duration = .seconds(10)

    /// Qué carga es la vigente. Una carga vieja que contesta tarde —el fetch que
    /// perdió la carrera y volvió igual, después de que el jugador tocó
    /// "Reintentar"— no puede pisar el resultado de la nueva.
    @ObservationIgnored private var loadGeneration = 0

    #if DEBUG
    /// La tienda local para builds que corren SIN Xcode (instaladas por
    /// `simctl`, abiertas tocando el icono): el `.storekit` del scheme sólo se
    /// inyecta cuando Xcode lanza la app, y sin él StoreKit devuelve el
    /// catálogo vacío — la pantalla mostraba "sin conexión" para siempre (lo
    /// vio el dueño probando la v4 instalada a mano, 2026-08-18). La sesión
    /// levanta la MISMA configuración desde el bundle; corriendo desde Xcode
    /// simplemente la pisa con una idéntica. Vive en una propiedad porque
    /// soltarla cierra la sesión.
    @ObservationIgnored private var localStoreSession: SKTestSession?
    #endif

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
        guard !isStarted else { return }
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

        // Antes del primer `await`: `start` se suspende en la reconstrucción y
        // un segundo llamado que entre en ese hueco no puede repetirla.
        isStarted = true

        // La tienda local ANTES de leer el historial: sin la sesión, una build
        // DEBUG instalada por `simctl` ve un `Transaction.all` vacío y cierra la
        // reconstrucción en 0 para siempre.
        #if DEBUG
        startLocalStoreIfNeeded()
        #endif
        await reconstructPurchasedOroIfNeeded()

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }

        await loadProducts()
        await refreshEntitlements()
        // La puerta del azar (E5a), para lo que se decide sin esperar a StoreKit.
        // Bajo XCTest no: las suites deciden la puerta por parámetro.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            await LootBoxGate.refreshLastKnown()
            LootBoxGate.startWatchingStorefront()
        }
    }

    #if DEBUG
    /// Ver `localStoreSession`. Bajo XCTest NO se arranca: `StoreManagerTests`
    /// crea su propia `SKTestSession` por test y la del host le pisaría el
    /// estado (es la asimetría de la trampa 4 del HANDOFF, no se la agranda).
    private func startLocalStoreIfNeeded() {
        guard localStoreSession == nil,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        // StoreKitTest va linkeado DÉBIL (ver project.yml): si dyld no pudo
        // cargarlo —su dependencia XCTest no existe fuera del entorno de tests
        // ni de un bundle que la embeba— la clase no está y tocar el símbolo
        // abortaría. Se pregunta antes: sin framework no hay tienda local y la
        // carga sigue el camino de siempre (el scheme de Xcode o el sandbox).
        guard NSClassFromString("SKTestSession") != nil else {
            Log.store.info("StoreKitTest ausente: sin tienda local en este entorno")
            return
        }
        // El `StoreKitTest` del RUNTIME 26 aborta el init de `SKTestSession`
        // fuera de un runner XCTest (SIGABRT medido dos veces el 2026-08-25:
        // `-[SKTestSession bundleID]` → `__getXCTestConfigurationClass` →
        // `abort_report_np`; cargar XCTest a mano con `dlopen` NO alcanza —
        // exige la sesión de test real). El framework lo sirve el runtime del
        // simulador, así que el check es `#available` del OS y no del SDK: en
        // 18.6 sirve el framework viejo y el truco sigue andando. En 26+ la
        // tienda local queda ausente —"sin conexión" al instalar por simctl,
        // como antes del 2026-08-18— y la carga sigue el camino de siempre
        // (el scheme de Xcode la inyecta igual).
        if #available(iOS 26.0, *) {
            Log.store.info("runtime 26: sin tienda local (SKTestSession exige un runner XCTest)")
            return
        }
        do {
            localStoreSession = try SKTestSession(configurationFileNamed: "FisuEvolution")
        } catch {
            // Con el framework pero sin el recurso en el bundle tampoco hay
            // tienda local: mismo camino de siempre.
            Log.store.info("local StoreKit session unavailable: \(error.localizedDescription)")
        }
    }
    #endif

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
            // ⚠️ Este log NO es ruido: es la única forma de distinguir las tres
            // maneras de terminar con la tienda vacía, que en pantalla se ven
            // todas iguales ("No se pudieron cargar las compras"). Faltando
            // TODOS: no hay catálogo —ni el .storekit local ni los productos
            // en App Store Connect—. Faltando ALGUNOS: esos ids no existen del
            // otro lado, casi siempre un typo, porque `Product.products(for:)`
            // omite en silencio lo que no resuelve y nunca tira error.
            //
            // Sin esto, averiguar cuál de los tres casos era costó una tarde
            // entera de bisecar a ciegas (2026-09-22). Los ids no son dato
            // personal: son constantes del build.
            let faltan = Set(catalog.allProductIDs).subtracting(products.map(\.id))
            if faltan.isEmpty {
                Log.store.info("catálogo completo: \(self.products.count, privacy: .public) productos")
            } else {
                Log.store.error(
                    "catálogo incompleto: \(self.products.count, privacy: .public) de \(catalog.allProductIDs.count, privacy: .public); StoreKit no resolvió \(faltan.sorted().joined(separator: ", "), privacy: .public)"
                )
            }
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
    private func fetchWithDeadline(ids: [String]) async -> LoadOutcome {
        let fetcher = productsFetcher
        let outcome = await withDeadline(loadTimeout) { () -> LoadOutcome in
            do {
                return .loaded(try await fetcher(ids))
            } catch {
                Log.store.error("product load failed: \(error)")
                return .failed
            }
        }
        return outcome ?? .timedOut
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

    /// Una vez por save de la v1. Corre antes del listener: así ninguna
    /// transacción nueva entra a la cuenta como si fuera de la v1.
    private func reconstructPurchasedOroIfNeeded() async {
        guard let gameState, gameState.needsPurchasedOroReconstruction else { return }
        let reader = historyReader
        let records = await withDeadline(historyTimeout) { await reader() }
        // Un plazo vencido deja la reconstrucción abierta: se reintenta en el
        // próximo arranque. Cerrarla en 0 perdería el ORO comprado para siempre.
        guard let records else {
            Log.store.error("purchase history timed out after \(self.historyTimeout, privacy: .public)")
            return
        }
        gameState.completePurchasedOroReconstruction(records: records)
        let total = gameState.player?.meta.oroPurchasedLifetime ?? 0
        Log.store.info(
            "purchased ORO reconstructed: \(total, privacy: .public) ORO from \(records.count, privacy: .public) transactions"
        )
    }

    /// Gana el primero que conteste; `nil` si vence el plazo.
    ///
    /// ⚠️ **La carrera no se escribe con `withThrowingTaskGroup`** aunque sea el
    /// reflejo obvio. Un grupo no termina hasta que TODOS sus hijos terminan, y
    /// cancelarlo es sólo un pedido: con el trabajo colgado —que es exactamente
    /// el defecto que esto arregla— el grupo no sale nunca y el llamador seguiría
    /// sin volver, con plazo y todo. Con el canal, se lee al ganador y al
    /// perdedor se lo suelta: lo que llegue tarde cae en un `AsyncStream` que ya
    /// no lee nadie (en `loadProducts()`, la guarda de generación hace el resto).
    private func withDeadline<T: Sendable>(
        _ timeout: Duration,
        _ work: @escaping @Sendable () async -> T
    ) async -> T? {
        let (outcomes, publish) = AsyncStream<T?>.makeStream()
        let job = Task { publish.yield(await work()) }
        let deadline = Task {
            // Cancelado (ganó el trabajo) no publica nada: sin este `return`, el
            // sueño interrumpido se leería como un plazo vencido.
            do { try await Task.sleep(for: timeout) } catch { return }
            publish.yield(nil)
        }
        defer {
            job.cancel()
            deadline.cancel()
        }
        for await outcome in outcomes { return outcome }
        return nil
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else {
            Log.store.error("unverified transaction dropped")
            return
        }
        let entry = catalog?.products.first { $0.id == transaction.productID }

        if transaction.revocationDate != nil {
            purchasedProductIDs.remove(transaction.productID)
            if entry?.entitlement == .oro || entry?.entitlement == .offer {
                gameState?.revokeStorePurchase(transactionID: String(transaction.id))
            }
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
