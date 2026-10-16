import Foundation

/// Una sección de la config de personalización que se valida al leerla (todo o nada). La conforman
/// las tablas de cada fase: `PlayerValueTables` (F1), `SegmentLevers` (F2), `MomentsConfig` (F3).
protocol PersonalizationSection: Decodable {
    func validate() throws
}

/// La config de personalización (2.1 E15 F1, contrato C3): el envoltorio que devuelve
/// `rpc/personalization_config`, `{ "version": 3, "sections": { "player_value": …, "segments": … } }`.
///
/// Cada fase decodifica **su** sección con `section(_:as:)`. Una sección que falta, no decodifica o
/// no valida devuelve `nil` y deja esa fase en `base`, sin tocar a las otras.
struct PersonalizationConfig: Sendable, Equatable {
    let version: Int
    /// El JSON de cada sección, tal cual (con las claves ordenadas), para decodificarlo por fase.
    private let sections: [String: Data]

    init(version: Int, sections: [String: Data]) {
        self.version = version
        self.sections = sections
    }

    static let empty = PersonalizationConfig(version: 0, sections: [:])

    var sectionKeys: [String] { sections.keys.sorted() }

    /// Una sección decodificada y, si es una `PersonalizationSection`, validada; `nil` si no.
    func section<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = sections[key], let value = try? JSONDecoder().decode(type, from: data) else { return nil }
        if let section = value as? any PersonalizationSection {
            do { try section.validate() } catch { return nil }
        }
        return value
    }

    /// El envoltorio, si `data` es un objeto JSON con `sections` objeto (y `version` entera, si está;
    /// sin ella cuenta como 0). Una sección que no es un objeto no entra.
    static func decode(_ data: Data) -> PersonalizationConfig? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawSections = root["sections"] as? [String: Any] else { return nil }
        let version: Int
        switch root["version"] {
        case nil: version = 0
        case let number as NSNumber where CFGetTypeID(number) != CFBooleanGetTypeID(): version = number.intValue
        default: return nil
        }
        var sections: [String: Data] = [:]
        for (key, value) in rawSections {
            guard let object = value as? [String: Any],
                  let encoded = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { continue }
            sections[key] = encoded
        }
        return PersonalizationConfig(version: version, sections: sections)
    }
}
