import Foundation
import StoreKit
import Testing
@testable import FisuEvolution

/// El plazo de la carga de la tienda (HANDOFF §8): **la tienda no se cuelga**.
///
/// El defecto que estos tests cubren se veía lanzando la app por `simctl` —que
/// no inyecta el `.storekit`, cosa que sólo hace el esquema de Xcode—: como
/// `Product.products(for:)` no volvía nunca y no había plazo, `loadState`
/// quedaba en `.loading` para siempre y la pantalla se quedaba con el spinner,
/// sin llegar nunca al cartel de error que ya existía.
///
/// ⚠️ Nada de esto usa `SKTestSession`: la tienda de verdad se prueba en
/// `StoreManagerTests`. Acá el fetch está **inyectado**, que es la única forma de
/// tener una tienda que no contesta. Como no se puede construir un `Product` a
/// mano (StoreKit no expone su init), los fetchers que "andan" devuelven la lista
/// vacía: lo que se asserta es el `loadState`, no el contenido.
@Suite("Plazo de carga de la tienda", .serialized)
@MainActor
struct StoreTimeoutTests {
    /// Un catálogo mínimo. Basta con que tenga un id: lo único que hace
    /// `loadProducts()` con él es pasárselo al fetch y ordenar la respuesta.
    private static func catalog() -> ProductCatalog {
        ProductCatalog(
            schemaVersion: 1,
            products: [
                ProductCatalog.Entry(
                    id: "pack.coins",
                    type: "consumable",
                    entitlement: .coins,
                    skinId: nil,
                    coinFactor: 15,
                    oroAmount: nil
                )
            ]
        )
    }

    /// Espera a que `condition` se cumpla, o se rinde. Es lo que permite probar
    /// un fetch que no vuelve **sin colgar la corrida**: el test mira el estado
    /// en vez de esperar a que `loadProducts()` termine.
    private func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test("una tienda que contesta dentro del plazo queda cargada")
    func aFetchThatAnswersInTimeLoads() async {
        let store = StoreManager(catalog: Self.catalog()) { _ in
            try await Task.sleep(for: .milliseconds(20))
            return []
        }
        store.loadTimeout = .milliseconds(600)

        await store.loadProducts()

        #expect(store.loadState == .loaded)
    }

    @Test("una tienda que tarda más que el plazo cae en falla")
    func aSlowFetchTimesOut() async {
        let store = StoreManager(catalog: Self.catalog()) { _ in
            try await Task.sleep(for: .seconds(5))
            return []
        }
        store.loadTimeout = .milliseconds(100)

        await store.loadProducts()

        #expect(store.loadState == .failed)
    }

    /// El caso de verdad: el fetch **no vuelve nunca y encima ignora la
    /// cancelación**. Es lo que hace que la carrera no se pueda escribir con un
    /// `withThrowingTaskGroup` —un grupo no sale hasta que todos sus hijos
    /// terminan, cancelados o no—, y es exactamente lo que se veía en el
    /// simulador.
    @Test("una tienda que no contesta NUNCA no deja la pantalla colgada")
    func aFetchThatNeverAnswersDoesNotHangTheStore() async {
        let store = StoreManager(catalog: Self.catalog()) { _ in
            // `try?` se come la cancelación a propósito: esta tarea no se muere
            // ni pidiéndoselo, igual que la llamada colgada de StoreKit.
            while true { try? await Task.sleep(for: .seconds(1)) }
        }
        store.loadTimeout = .milliseconds(100)

        // ⚠️ La llamada va en una tarea aparte y el test espera POR EL ESTADO:
        // sin el plazo, `loadProducts()` no vuelve nunca y esto se colgaría en
        // vez de fallar. Un test colgado no informa nada y se lleva puesta la
        // corrida entera.
        let load = Task { await store.loadProducts() }
        defer { load.cancel() }

        await waitUntil { store.loadState == .failed }
        #expect(store.loadState == .failed)
    }

    /// Y después del plazo se puede volver a intentar: es lo que hace que el
    /// botón "Reintentar" de la pantalla sirva para algo. `start()` no alcanza
    /// —corta con su guarda de idempotencia—, así que el camino del botón es
    /// `loadProducts()` directo, y este test lo pinea.
    @Test("después de un plazo vencido, reintentar carga")
    func retryingAfterATimeoutSucceeds() async {
        let attempts = AttemptCounter()
        let store = StoreManager(catalog: Self.catalog()) { _ in
            // El primer intento se cuelga; el segundo contesta.
            if await attempts.next() == 1 {
                while true { try? await Task.sleep(for: .seconds(1)) }
            }
            return []
        }
        store.loadTimeout = .milliseconds(100)

        let first = Task { await store.loadProducts() }
        defer { first.cancel() }
        await waitUntil { store.loadState == .failed }
        #expect(store.loadState == .failed)

        await store.loadProducts()

        #expect(store.loadState == .loaded)
    }
}

/// Contador compartido entre el test y el fetch, que corre fuera del actor
/// principal. Un `var` capturado no compila con concurrencia estricta.
private actor AttemptCounter {
    private var count = 0

    func next() -> Int {
        count += 1
        return count
    }
}
