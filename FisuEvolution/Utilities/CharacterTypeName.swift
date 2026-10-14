import EconomyKit
import Foundation

extension CharacterType {
    /// El nombre del personaje en el idioma del jugador.
    ///
    /// `displayName` sale de `tiers.json`, que es **dato** y está escrito en
    /// castellano: dibujado tal cual, el juego en inglés muestra "El Fisura". La
    /// traducción vive en el catálogo bajo `tier.name.<id>`, con el mismo trato
    /// que `skin.name.<id>`.
    ///
    /// ⚠️ La clave se arma en runtime, así que el lookup va **por el bundle** y
    /// no por `LocalizedStringKey`: interpolar una clave construye
    /// `tier.name.%@` y deja la clave cruda en pantalla (trampa 5 del HANDOFF).
    ///
    /// El `value:` es el castellano del dato, así que un tier que entre a
    /// `tiers.json` antes que su string muestra su nombre y no la clave — el
    /// mismo criterio que `skinDisplayName(for:)` con el id embellecido.
    var localizedName: String {
        Bundle.main.localizedString(forKey: "tier.name.\(id)", value: displayName, table: nil)
    }

    /// La descripción del personaje para la hoja (E14b B16), en el idioma del jugador.
    ///
    /// Vive en el catálogo bajo `tier.desc.<id>`. Misma trampa que `localizedName`: la clave se arma
    /// en runtime, así que el lookup va por el bundle. Sin clave devuelve `nil` (la hoja no dibuja
    /// el bloque) y no la clave cruda.
    var localizedDescription: String? {
        let key = "tier.desc.\(id)"
        let text = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        return text == key ? nil : text
    }
}
