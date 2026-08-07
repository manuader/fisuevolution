import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import FisuEvolution

/// `products.json` y `StoreKitConfig/FisuEvolution.storekit` tienen que declarar
/// exactamente los mismos ids.
///
/// Por qué hace falta un test: cuando un id declarado no existe en el StoreKit,
/// `Product.products(for:)` **no falla ni loguea** — simplemente lo omite, y la
/// tienda queda con una fila menos sin que nadie se entere. Ya pasó: los tres
/// tintes IAP (`skin_golden`, `skin_galaxy`, `skin_god`) se sacaron del
/// `.storekit` el 2026-08-05 y quedaron declarados en `products.json`, así que
/// el jugador abrió el carrito y vio una sola fila.
@Suite("Catálogo de productos", .serialized)
struct StoreProductsTests {
    /// Sólo sirve para ubicar el bundle de los tests (el `.storekit` se copia ahí
    /// como recurso, ver `project.yml`).
    private final class BundleToken {}

    /// El `.storekit`, leído como JSON: sólo nos importan los ids.
    private struct StoreKitConfigFile: Decodable {
        struct Entry: Decodable {
            let productID: String
        }

        let products: [Entry]
    }

    private func declaredProductIDs() throws -> Set<String> {
        Set(try ProductCatalog.load(from: .main).allProductIDs)
    }

    private func storeKitProductIDs() throws -> Set<String> {
        let bundle = Bundle(for: BundleToken.self)
        let url = try #require(
            bundle.url(forResource: "FisuEvolution", withExtension: "storekit"),
            "el .storekit no está en el bundle de tests"
        )
        let config = try JSONDecoder().decode(StoreKitConfigFile.self, from: Data(contentsOf: url))
        return Set(config.products.map(\.productID))
    }

    @Test("todo producto declarado existe en el StoreKit local")
    func noPhantomProducts() async throws {
        let session = try SKTestSession(configurationFileNamed: "FisuEvolution")
        session.disableDialogs = true
        defer { _ = session }

        let declared = try declaredProductIDs()
        #expect(!declared.isEmpty, "products.json no declara ningún producto")

        let available = Set(try await Product.products(for: declared).map(\.id))
        #expect(
            declared == available,
            "declarados sin contraparte en el .storekit: \(declared.subtracting(available).sorted())"
        )
    }

    /// La dirección contraria: un producto que existe en el StoreKit pero que
    /// `products.json` no declara nunca se pide, así que no se vende.
    @Test("todo producto del StoreKit local está declarado")
    func noUnsoldProducts() throws {
        let declared = try declaredProductIDs()
        let inStoreKit = try storeKitProductIDs()
        #expect(
            inStoreKit.subtracting(declared).isEmpty,
            "en el .storekit pero sin declarar en products.json: \(inStoreKit.subtracting(declared).sorted())"
        )
    }
}
