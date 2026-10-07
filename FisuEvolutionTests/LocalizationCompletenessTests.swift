import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El juego entero en los dos idiomas (PLAN-v2, E3 i18n).
///
/// Lee los `.xcstrings` FUENTE y no los `.strings` compilados: el estado de una
/// traducción (`translated`, `new`, `needs_review`) sólo existe en la fuente, y
/// un `new` compila igual y llega a la pantalla sin que nada avise. Los ubica con
/// `#filePath`, como la guarda de los legales de `SettingsPersistenceTests`.
///
/// Tres frentes:
/// - **Toda clave** del catálogo está `translated` en castellano y en inglés, y
///   las dos traducciones piden los mismos argumentos (un `%@` de más en una
///   sola se come un argumento ajeno o imprime basura).
/// - **Las familias dinámicas, contra el contenido.** Las claves que el juego
///   arma en runtime desde los JSON (`tier.name.<id>`, los `titleKey` de los
///   logros, `iap.<productID>.name`…) no son literales del código, así que
///   Xcode no puede extraerlas y nada avisa cuando a un elemento nuevo le falta
///   la suya: se veía la clave cruda, o el castellano del dato en el juego en
///   inglés.
/// - **`InfoPlist.xcstrings`**: el nombre de la app y el diálogo de ATT.
@Suite("Catálogo de strings completo")
struct LocalizationCompletenessTests {
    /// Los dos idiomas de la app. El castellano es el de desarrollo.
    static let languages = ["es", "en"]

    // MARK: - Las tres reglas

    @Test("toda clave del catálogo está traducida a los dos idiomas, con los mismos placeholders")
    func everyKeyIsTranslatedInBothLanguages() throws {
        let catalog = try Self.catalog("Localizable")
        #expect(!catalog.strings.isEmpty)
        let problems = catalog.strings.keys.sorted().flatMap { Self.problems(of: $0, in: catalog) }
        #expect(problems.isEmpty, "\(problems.count) problemas:\n\(problems.joined(separator: "\n"))")
    }

    @Test("cada elemento del contenido tiene su clave, traducida a los dos idiomas",
          arguments: DynamicFamily.allCases)
    @MainActor
    func everyDynamicFamilyCoversTheContent(_ family: DynamicFamily) throws {
        let content = try GameContentLoader.load(from: .main)
        let catalog = try Self.catalog("Localizable")
        let keys = try family.keys(in: content)
        // Una familia vacía pasaría siempre: si el contenido dejó de tenerla,
        // la familia se borra de acá a conciencia.
        #expect(!keys.isEmpty, "la familia \(family.rawValue) no tiene elementos")
        let problems = keys.flatMap { Self.problems(of: $0, in: catalog) }
        #expect(problems.isEmpty, "\(family.rawValue):\n\(problems.joined(separator: "\n"))")
    }

    /// `tower.floor.<id>` está en el catálogo, pero quien la pide es un `switch`
    /// de `TowerNaming`: un piso nuevo sin su caso cae al id crudo (o, en la
    /// variante `LocalizedStringKey`, al nombre del Callejón).
    @Test("TowerNaming nombra cada piso del contenido")
    @MainActor
    func towerNamingCoversEveryFloor() throws {
        let content = try GameContentLoader.load(from: .main)
        for floor in content.floorTable.floors {
            #expect(TowerNaming.floorName(for: floor.id) != floor.id, "el piso \(floor.id) no tiene nombre")
        }
    }

    @Test("InfoPlist.xcstrings está completo en los dos idiomas")
    func infoPlistIsComplete() throws {
        let catalog = try Self.catalog("InfoPlist")
        // Los dos que el jugador ve: el nombre bajo el ícono y el diálogo de ATT.
        for key in ["CFBundleDisplayName", "NSUserTrackingUsageDescription"] {
            #expect(catalog.strings[key] != nil, "falta \(key)")
        }
        let problems = catalog.strings.keys.sorted().flatMap { Self.problems(of: $0, in: catalog) }
        #expect(problems.isEmpty, "\(problems.count) problemas:\n\(problems.joined(separator: "\n"))")
    }

    @Test("el lector de placeholders distingue un formato de un porcentaje")
    func placeholderReader() {
        #expect(Self.placeholders(in: "Te da %@ de ORO") == ["@"])
        #expect(Self.placeholders(in: "%@ en %lld días") == ["@", "lld"])
        // Con posición se comparan por posición: el inglés puede invertirlas.
        #expect(Self.placeholders(in: "%2$lld de %1$@") == ["@", "lld"])
        // Los flavors dicen "+5% de income": un porcentaje, no un `% d`.
        #expect(Self.placeholders(in: "+5% de income, 100%% seguro, 5% cheaper").isEmpty)
    }

    // MARK: - Familias dinámicas

    /// Una familia de claves que el juego arma en runtime. Cada caso dice de
    /// dónde salen sus elementos, que es lo único que este test necesita saber:
    /// un tier, una skin o un producto nuevos entran solos.
    enum DynamicFamily: String, CaseIterable, CustomTestStringConvertible {
        /// `tier.name.<id>` (`CharacterTypeName`), sobre `tiers.json`.
        case tiers
        /// El `displayNameKey` de cada skin (sin clave, el id embellecido).
        case skins
        case achievements
        case specials
        /// Las dos variantes: la de siempre y la review-safe de la build de store.
        case boosts
        case events
        case dailyRewards
        case gameCenter
        case rewardedAds
        /// El título del JSON y `upgrades.flavor.<id>`, que arma `upgradeFlavorText`.
        case upgrades
        /// `tower.floor.<id>`, sobre los pisos de `economy.json`.
        case floors
        /// `iap.<productID>.name` y `.desc` (`IAPCopy`), sobre `products.json`.
        case iap
        /// `LocalizedStringKey(tip.lesson.textKey)` en el globo de las lecciones.
        case tutorialTips
        /// `notif.<id>.title` y `.body` (`NotificationCopy`), sobre `notifications.json`.
        case notifications
        /// Las filas de Ajustes cuyo identifier es también su clave.
        case settingsRows

        var testDescription: String { rawValue }

        @MainActor
        func keys(in content: GameContent) throws -> [String] {
            switch self {
            case .tiers:
                return content.tiers.types.map { "tier.name.\($0.id)" }
            case .skins:
                return content.skins.skins.map { $0.displayNameKey ?? "skin.name.\($0.id)" }
            case .achievements:
                return content.achievements.achievements.flatMap { [$0.titleKey, $0.descKey] }
            case .specials:
                return content.specials.specials.flatMap { [$0.displayNameKey, $0.flavorTextKey] }
            case .boosts:
                return content.boosts.boosts.flatMap {
                    [$0.displayNameKey, $0.flavorTextKey, $0.reviewSafe.displayNameKey, $0.reviewSafe.flavorTextKey]
                }
            case .events:
                return content.events.events.map(\.flavorTextKey)
            case .dailyRewards:
                return content.dailyRewards.days.map(\.titleKey)
            case .gameCenter:
                return content.gameCenter.leaderboards.map(\.titleKey) + content.gameCenter.achievements.map(\.titleKey)
            case .rewardedAds:
                return content.rewardedAds.rewards.map(\.titleKey)
            case .upgrades:
                return content.upgradesConfig.upgrades.flatMap { [$0.titleKey, "upgrades.flavor.\($0.id)"] }
            case .floors:
                return content.floorTable.floors.map { "tower.floor.\($0.id)" }
            case .iap:
                return try ProductCatalog.load(from: .main).products.flatMap {
                    [IAPCopy.nameKey(for: $0.id), IAPCopy.descriptionKey(for: $0.id)]
                }
            case .tutorialTips:
                return GameState.TutorialLesson.allCases.map(\.textKey)
            case .notifications:
                return content.notifications.kinds.flatMap { [$0.titleKey, $0.bodyKey] }
            case .settingsRows:
                return LanguagePreference.allCases.map(\.identifier) + LegalDocument.Kind.allCases.map(\.identifier)
            }
        }
    }

    // MARK: - Lectura del catálogo

    /// Lo justo de un `.xcstrings` para juzgarlo.
    struct Catalog: Decodable {
        struct Entry: Decodable {
            let localizations: [String: Localization]?
        }

        struct Localization: Decodable {
            let stringUnit: StringUnit?
            /// Plurales y variantes por dispositivo: `{"plural": {"one": …}}`.
            let variations: [String: [String: Localization]]?

            var units: [StringUnit] {
                let nested = variations?.values.flatMap { $0.values.flatMap(\.units) } ?? []
                return (stringUnit.map { [$0] } ?? []) + nested
            }
        }

        struct StringUnit: Decodable {
            let state: String
            let value: String
        }

        let strings: [String: Entry]
    }

    static func catalog(_ name: String) throws -> Catalog {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()  // FisuEvolutionTests/
            .deletingLastPathComponent()  // raíz del repo
            .appending(path: "FisuEvolution/Resources/\(name).xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }

    /// Lo que le falta a una clave para estar completa; vacío si no le falta nada.
    static func problems(of key: String, in catalog: Catalog) -> [String] {
        guard let entry = catalog.strings[key] else { return ["\(key): no está en el catálogo"] }
        var problems: [String] = []
        var signatures: [String: [String]] = [:]
        for language in languages {
            guard let localization = entry.localizations?[language], !localization.units.isEmpty else {
                problems.append("\(key): sin \(language)")
                continue
            }
            for unit in localization.units where unit.state != "translated" {
                problems.append("\(key): \(language) en estado \(unit.state)")
            }
            signatures[language] = signature(of: localization)
        }
        if let es = signatures["es"], let en = signatures["en"], es != en {
            problems.append("\(key): placeholders distintos (es \(es), en \(en))")
        }
        return problems
    }

    /// Los placeholders de una traducción. Con variantes vale la unión: el caso
    /// "one" de un plural puede omitir el número y es correcto.
    private static func signature(of localization: Catalog.Localization) -> [String] {
        if localization.variations == nil, let unit = localization.stringUnit {
            return placeholders(in: unit.value)
        }
        return Set(localization.units.flatMap { placeholders(in: $0.value) }).sorted()
    }

    /// Los especificadores de formato de un texto, en orden de argumento.
    ///
    /// Sin el flag de espacio a propósito: `printf` lo admite, pero los flavors
    /// dicen "+5% de income" y un `% d` ahí es un porcentaje, no un formato.
    static func placeholders(in value: String) -> [String] {
        let spec = #/%(\d+\$)?[-+#0]*\d*(?:\.\d+)?(lld|llu|ld|lu|lf|d|i|u|f|@|%)/#
        var specs: [(position: Int?, type: String)] = []
        for match in value.matches(of: spec) where match.output.2 != "%" {
            specs.append((match.output.1.flatMap { Int($0.dropLast()) }, String(match.output.2)))
        }
        guard specs.contains(where: { $0.position != nil }) else { return specs.map { $0.type } }
        return specs.enumerated()
            .sorted { ($0.element.position ?? $0.offset + 1) < ($1.element.position ?? $1.offset + 1) }
            .map { $0.element.type }
    }
}
