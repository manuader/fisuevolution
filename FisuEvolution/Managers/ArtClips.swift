import Foundation

/// Qué clip le toca a cada lugar. `nil` = el lugar se queda con su póster: nunca otro clip "parecido".
enum ArtClips {
    /// La clave de una pinta en `characters`: `"<tipo>__<pinta>"` (el id de pinta no es único).
    static func skinKey(type: String, skin: String) -> String {
        "\(type)__\(skin)"
    }

    /// Sin pinta, el cuerpo entero base; con pinta, sólo el de esa pinta. Una pinta sin clip → `nil`.
    static func character(type: String, skin: String?, in manifest: LoopsManifest) -> ArtClip? {
        let key = skin.map { skinKey(type: type, skin: $0) } ?? type
        return manifest.characters[key] == nil ? nil : .character(key)
    }

    /// El visitante del escenario: con globo, `.talking`; esperando sin globo, `.visitorAction`.
    static func stageVisitor(_ id: String, talking: Bool, in manifest: LoopsManifest) -> ArtClip? {
        if talking { return manifest.talking[id] == nil ? nil : .talking(id) }
        return manifest.visitorActions[id] == nil ? nil : .visitorAction(id)
    }

    static func event(_ id: String, in manifest: LoopsManifest) -> ArtClip? {
        manifest.events[id] == nil ? nil : .event(id)
    }

    /// Ítem de `oro_shop.json` → clave de `shopIcons`. Los nombres no coinciden: tabla fija.
    static let shopIconKeys: [String: String] = [
        "income_x2": "ui_oro_income_boost",
        "income_x3": "ui_oro_income_boost",
        "auto_tap": "ui_oro_autotap",
        "package_rain": "ui_oro_package_rain",
        "time_jump_1h": "ui_oro_time_skip",
        "time_jump_4h": "ui_oro_time_skip",
        "offline_x3": "ui_oro_offline_boost",
        "daily_x3": "ui_oro_daily_boost",
        "merge_all": "ui_oro_merge_all",
        "better_supplier": "ui_oro_better_supplier",
        "wheel_spins": "ui_oro_extra_spins",
    ]

    /// Clips de la tienda que todavía no tienen ítem, con la tarea que lo estrena.
    static let pendingShopIcons: [String: String] = [
        "ui_oro_extra_slots": "E6b T7",
    ]

    static func shopIcon(item: String, in manifest: LoopsManifest) -> ArtClip? {
        guard let key = shopIconKeys[item], manifest.shopIcons[key] != nil else { return nil }
        return .shopIcon(key)
    }
}
