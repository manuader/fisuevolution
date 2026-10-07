import Foundation

/// El ORO que la v1 vendió, reconstruido desde el historial de StoreKit.
enum PurchasedOroHistory {
    /// Lo que la v1 acreditaba por cada pack. Es una foto, como
    /// `SaveMigrator.rebalanceLevelCaps`: E6 reescala `products.json` y esta
    /// cuenta no puede cambiar con él.
    static let v1OroAmountByProductID: [String: Int] = [
        "com.fisuevolution.iap.oro_small": 250,
        "com.fisuevolution.iap.oro_medium": 750,
        "com.fisuevolution.iap.oro_large": 2000,
    ]

    struct Record: Equatable, Sendable {
        let transactionID: String
        let productID: String
        let isRevoked: Bool
    }

    /// Sólo cuenta lo que la v1 acreditó: una transacción sin acreditar la
    /// entrega el listener por el camino de siempre, que ya suma al contador.
    static func reconstruct(records: [Record], creditedTransactionIDs: Set<String>) -> Int {
        records
            .filter { !$0.isRevoked && creditedTransactionIDs.contains($0.transactionID) }
            .compactMap { v1OroAmountByProductID[$0.productID] }
            .reduce(0, +)
    }
}
