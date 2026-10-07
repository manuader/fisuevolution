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

    /// Lo que el historial dice, por id de transacción: se asigna, no se suma.
    struct Reconstruction: Equatable {
        /// id de transacción → ORO que le dio la v1. Sólo las no revocadas.
        let purchases: [String: Int]
        /// Las que se reembolsaron: dejan de contar donde sea que estén anotadas.
        let revoked: Set<String>
    }

    /// Sólo cuenta lo que la v1 acreditó: una transacción sin acreditar la
    /// entrega el listener por el camino de siempre, que ya la anota.
    static func reconstruct(records: [Record], creditedTransactionIDs: Set<String>) -> Reconstruction {
        var purchases: [String: Int] = [:]
        var revoked: Set<String> = []
        for record in records {
            guard let amount = v1OroAmountByProductID[record.productID] else { continue }
            if record.isRevoked {
                revoked.insert(record.transactionID)
            } else if creditedTransactionIDs.contains(record.transactionID) {
                purchases[record.transactionID] = amount
            }
        }
        return Reconstruction(purchases: purchases, revoked: revoked)
    }
}
