import Foundation
import Testing
@testable import FisuEvolution

/// Cada personaje de `tiers.json` tiene su descripción en los dos idiomas (E14b B16, D12).
///
/// Cuenta como presente la clave que está completa en el catálogo o, mientras el controlador no
/// la aplicó, la que trae el snapshot `claves-pendientes/e14b-b16.json` con es y en escritos.
@Suite("Descripciones de los personajes")
@MainActor
struct CharacterDescriptionTests {
    private static let repoRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private static func snapshot() throws -> [String: [String: String]] {
        let url = repoRoot.appending(path: "Tools/v2/claves-pendientes/e14b-b16.json")
        guard FileManager.default.fileExists(atPath: url.path()) else { return [:] }
        return try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))
    }

    @Test("cada tier.id tiene su tier.desc en es y en")
    func everyTierHasADescription() throws {
        let content = try GameContentLoader.load(from: .main)
        let catalog = try LocalizationCompletenessTests.catalog("Localizable")
        let pending = try Self.snapshot()
        #expect(!content.tiers.types.isEmpty)
        var problems: [String] = []
        for type in content.tiers.types {
            let key = "tier.desc.\(type.id)"
            if catalog.strings[key] != nil {
                problems += LocalizationCompletenessTests.problems(of: key, in: catalog)
            } else if let languages = pending[key] {
                for language in LocalizationCompletenessTests.languages
                where languages[language]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    problems.append("\(key): sin \(language) en el snapshot")
                }
            } else {
                problems.append("\(key): no está en el catálogo ni en el snapshot")
            }
        }
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }
}
