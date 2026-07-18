import Foundation

/// Data-driven IAP catalog, mirrored 1:1 from `products.json`. Code never
/// hardcodes a product id.
struct ProductCatalog: Codable, Sendable, Equatable {
    struct Entry: Codable, Sendable, Equatable, Identifiable {
        enum Entitlement: String, Codable, Sendable {
            case removeAds
            case skin
        }

        let id: String
        let type: String
        let entitlement: Entitlement
        let skinId: String?
    }

    let schemaVersion: Int
    let products: [Entry]

    var allProductIDs: [String] { products.map(\.id) }

    var removeAdsProductID: String? {
        products.first { $0.entitlement == .removeAds }?.id
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
