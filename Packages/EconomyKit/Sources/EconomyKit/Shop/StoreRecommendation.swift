import Foundation

/// Qué pack de la Tienda se destaca a cada jugador (2.1 E15 F5, contrato C2). Función pura: sólo agrega
/// un destaque; nunca oculta productos, ni cambia el orden, ni el precio (los tiers de App Store son fijos).
///
/// `base` no destaca nada: es la Tienda de la 2.0, el interruptor de la personalización apaga esto.
public enum StoreRecommendation {
    /// Un producto candidato a destacarse, tal como está en el catálogo de la app.
    public struct Pack: Equatable, Sendable {
        public enum Kind: Sendable { case starter, blue }

        public let id: String
        public let kind: Kind
        /// El monto de blue (ordena los packs de blue de menor a mayor). Sin sentido en el pack de inicio.
        public let blueAmount: Int

        public init(id: String, kind: Kind, blueAmount: Int) {
            self.id = id
            self.kind = kind
            self.blueAmount = blueAmount
        }
    }

    /// El `productId` a destacar, o `nil` si no se destaca nada.
    /// - `base` → `nil`.
    /// - Quien ya compró → el pack de blue siguiente al último comprado (el más chico si el último no
    ///   es un pack de blue; `nil` si ya compró el más grande).
    /// - Quien no compró y es `high` → el pack de inicio. Los demás → `nil`.
    public static func highlight(
        segment: PlayerSegment,
        hasPurchased: Bool,
        lastPurchasedID: String?,
        packs: [Pack]
    ) -> String? {
        guard segment != .base else { return nil }
        if hasPurchased {
            let ladder = packs.filter { $0.kind == .blue }.sorted { $0.blueAmount < $1.blueAmount }
            guard let last = lastPurchasedID, let index = ladder.firstIndex(where: { $0.id == last }) else {
                return ladder.first?.id
            }
            let next = ladder.index(after: index)
            return next < ladder.endIndex ? ladder[next].id : nil
        }
        guard segment == .high else { return nil }
        return packs.first { $0.kind == .starter }?.id
    }
}
