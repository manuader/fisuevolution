import Foundation

/// Data-driven IAP catalog, mirrored 1:1 from `products.json`. Code never
/// hardcodes a product id.
struct ProductCatalog: Codable, Sendable, Equatable {
    struct Entry: Codable, Sendable, Equatable, Identifiable {
        enum Entitlement: String, Codable, Sendable {
            case removeAds
            case skin
            /// Consumible: plata de la run, en proporción a dónde estás parado.
            case coins
            /// Consumible: saldo de ORO gastable. NO mueve el multiplicador
            /// global, que sigue saliendo sólo de reencarnar.
            case oro
            /// El combo de bienvenida: plata + quitar los ads + una skin. Es
            /// `nonConsumable` porque dos de las tres cosas son restaurables.
            case starterPack
        }

        let id: String
        let type: String
        let entitlement: Entitlement
        let skinId: String?
        /// `coins`: factor sobre `passiveUnlockCost(tier máximo)`, igual que el
        /// cofre de carrera. Un monto fijo envejece mal en un idle exponencial.
        let coinFactor: Double?
        /// `oro`: monto fijo. Acá sí es fijo porque los sinks de ORO
        /// (`upgrades.json`) tienen costos fijos, no exponenciales en la run.
        let oroAmount: Int?

        /// Sale del entitlement y no del campo `type`, que es un String suelto:
        /// lo que decide si algo se puede volver a comprar es QUÉ entrega, y una
        /// falta de ortografía en el JSON no debería regalar compras infinitas.
        /// El starter pack no entra: dos de sus tres cosas son restaurables.
        var isConsumable: Bool {
            switch entitlement {
            case .coins, .oro: true
            case .removeAds, .skin, .starterPack: false
            }
        }
    }

    let schemaVersion: Int
    let products: [Entry]

    var allProductIDs: [String] { products.map(\.id) }

    /// Plural: el starter pack también quita los ads, así que tener cualquiera
    /// de los dos alcanza. Con la versión singular, comprar el combo dejaba los
    /// anuncios puestos.
    var removeAdsProductIDs: Set<String> {
        Set(products.filter { $0.entitlement == .removeAds || $0.entitlement == .starterPack }.map(\.id))
    }

    /// productID → skinId for every skin product.
    var skinByProductID: [String: String] {
        Dictionary(uniqueKeysWithValues: products.compactMap { entry in
            entry.skinId.map { (entry.id, $0) }
        })
    }

    static func load(from bundle: Bundle) throws -> ProductCatalog {
        guard let url = bundle.url(forResource: "products", withExtension: "json") else {
            throw GameError.contentFileMissing("products.json")
        }
        do {
            return try JSONDecoder().decode(ProductCatalog.self, from: Data(contentsOf: url))
        } catch {
            throw GameError.contentInvalid(file: "products.json", reason: "\(error)")
        }
    }
}
