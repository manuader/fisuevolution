import SwiftUI

/// Nombres visibles de los pisos de la Torre.
///
/// `LocalizedStringKey` no resuelve claves construidas por interpolación, así
/// que el mapeo id→clave tiene que ser estático para que el catálogo las
/// traduzca. Vive acá y no dentro de una vista porque lo necesitan el HUD (pill
/// de piso) y la ficha de personaje (condición de desbloqueo de una skin).
enum TowerNaming {
    static func floorNameKey(for floorID: String) -> LocalizedStringKey {
        switch floorID {
        case "alley": "tower.floor.alley"
        case "urban": "tower.floor.urban"
        case "corporate": "tower.floor.corporate"
        case "luxury": "tower.floor.luxury"
        case "island": "tower.floor.island"
        case "moon": "tower.floor.moon"
        case "mars": "tower.floor.mars"
        case "solar": "tower.floor.solar"
        case "galaxy": "tower.floor.galaxy"
        case "cosmic": "tower.floor.cosmic"
        case "god_realm": "tower.floor.god_realm"
        default: "tower.floor.alley"
        }
    }

    /// Gemelo del anterior para cuando hace falta el `String` ya resuelto (p.ej.
    /// interpolarlo dentro de otra clave localizada).
    static func floorName(for floorID: String) -> String {
        switch floorID {
        case "alley": String(localized: "tower.floor.alley")
        case "urban": String(localized: "tower.floor.urban")
        case "corporate": String(localized: "tower.floor.corporate")
        case "luxury": String(localized: "tower.floor.luxury")
        case "island": String(localized: "tower.floor.island")
        case "moon": String(localized: "tower.floor.moon")
        case "mars": String(localized: "tower.floor.mars")
        case "solar": String(localized: "tower.floor.solar")
        case "galaxy": String(localized: "tower.floor.galaxy")
        case "cosmic": String(localized: "tower.floor.cosmic")
        case "god_realm": String(localized: "tower.floor.god_realm")
        default: floorID
        }
    }
}
