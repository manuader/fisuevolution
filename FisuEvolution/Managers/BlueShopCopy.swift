import EconomyKit
import Foundation

/// Lo que dice cada fila de la tienda de blue. Lo que da un consumible se dice
/// como cualquier premio (`RewardCopy`, E5b T1): una sola forma de decir "×3
/// durante 30 min" en todo el juego. Sólo "Fusionar todo" y los permanentes, que
/// no son un premio, tienen descripción propia, con sus números del dato.
enum BlueShopCopy {
    static func nameKey(_ id: String) -> String { "blueShop.item.\(id).name" }
    static func descriptionKey(_ id: String) -> String { "blueShop.item.\(id).desc" }
    static func shelfKey(_ shelf: BlueShopCatalog.Shelf) -> String { "blueShop.shelf.\(shelf.rawValue)" }

    /// Lo que no es un premio dice lo suyo; lo demás lo dice `RewardCopy`.
    static func hasOwnDescription(_ item: BlueShopCatalog.Item) -> Bool {
        item.rewards.isEmpty
    }

    static func name(for item: BlueShopCatalog.Item, bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: nameKey(item.id), value: nil, table: nil)
    }

    /// Qué da. `level` es el nivel comprado de un permanente: la fila describe el
    /// PRÓXIMO (o el último, al máximo).
    static func detail(for item: BlueShopCatalog.Item, level: Int, bundle: Bundle = .main) -> String {
        guard hasOwnDescription(item) else {
            return item.rewards.map(RewardCopy.title).joined(separator: " + ")
        }
        let template = bundle.localizedString(forKey: descriptionKey(item.id), value: nil, table: nil)
        let arguments = arguments(for: item, level: level)
        // Sin números no se formatea: un `%` literal se comería el carácter de al lado.
        guard !arguments.isEmpty else { return template }
        return String(format: template, arguments: arguments)
    }

    private static func arguments(for item: BlueShopCatalog.Item, level: Int) -> [String] {
        guard let perk = item.perk, !item.levels.isEmpty else { return [] }
        let next = min(max(0, level), item.levels.count - 1)
        switch perk {
        case .bestSupplier:
            return [String(next + 1), String(item.levels.count)]
        case .wheelDailySpins, .extraSlots:
            return [item.levels[next].value.formatted(.number.precision(.fractionLength(0)))]
        }
    }
}
