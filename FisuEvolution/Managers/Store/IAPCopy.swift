import EconomyKit
import Foundation

/// El nombre y la descripción de cada producto de la tienda, desde el catálogo
/// de strings del juego (PLAN-v2, ítem 19).
///
/// Hasta la 1.x salían de `product.displayName` y `product.description`, o sea
/// de App Store Connect. Ahí el idioma principal de la app es el inglés, así que
/// un jugador en castellano veía los IAP en inglés cada vez que su variante de
/// español no estaba cargada **y aprobada** (es-ES contra un es-MX solo, por
/// ejemplo). Con las claves `iap.<productID>.name` y `.desc` el texto viaja con
/// el binario, traducido como todo lo demás, y App Store Connect pasa a ser el
/// respaldo y no la fuente.
///
/// **El respaldo es lo de StoreKit, y sólo cuando falta la clave.** Un producto
/// nuevo que todavía no tiene su texto en el catálogo se ve con el nombre de
/// App Store Connect en vez de con la clave cruda. `LocalizationCompletenessTests`
/// es lo que impide que eso llegue a shippearse.
enum IAPCopy {
    static func nameKey(for productID: String) -> String { "iap.\(productID).name" }
    static func descriptionKey(for productID: String) -> String { "iap.\(productID).desc" }

    /// El nombre visible del producto, o `fallback` si el catálogo no lo tiene.
    static func name(for productID: String, fallback: String, bundle: Bundle = .main) -> String {
        lookup(nameKey(for: productID), in: bundle) ?? fallback
    }

    /// La descripción del producto, o `fallback` si el catálogo no la tiene.
    ///
    /// `quantity` es el número del que habla la descripción (ver `quantity(for:skins:)`).
    /// Va interpolado desde los datos y no escrito en el texto: los packs de ORO
    /// cambian de monto en la 2.0 y un número escrito a mano en dos idiomas se
    /// queda viejo en silencio.
    static func description(
        for productID: String,
        quantity: Int?,
        fallback: String,
        bundle: Bundle = .main,
        locale: Locale = .current
    ) -> String {
        guard let text = lookup(descriptionKey(for: productID), in: bundle) else { return fallback }
        // Sin número no se formatea: `String(format:)` sobre un texto con un `%`
        // literal se comería el carácter de al lado.
        guard let quantity else { return text }
        return String(format: text, locale: locale, quantity.formatted(.number.locale(locale)))
    }

    /// El número que interpola la descripción de un producto, o `nil` si su
    /// texto no habla de ninguno.
    ///
    /// - ORO: el monto del pack, de `products.json`.
    /// - Un paquete de skins (las de Diamante): cuántos personajes trae, contados
    ///   en `skins.json`. Una skin suelta no lleva número.
    static func quantity(for entry: ProductCatalog.Entry, skins: SkinsConfig?) -> Int? {
        switch entry.entitlement {
        case .oro:
            return entry.oroAmount
        case .skin:
            guard let skinID = entry.skinId, let skins else { return nil }
            let count = skins.skins.filter { $0.id == skinID }.count
            return count > 1 ? count : nil
        case .coins, .removeAds, .starterPack, .offer:
            return nil
        }
    }

    /// Un valor que ninguna traducción va a tener, para distinguir "falta la
    /// clave" de cualquier texto real: `localizedString` devuelve el `value`
    /// cuando no la encuentra.
    private static let missing = "<iap.missing>"

    private static func lookup(_ key: String, in bundle: Bundle) -> String? {
        let text = bundle.localizedString(forKey: key, value: missing, table: nil)
        return text == missing ? nil : text
    }
}
