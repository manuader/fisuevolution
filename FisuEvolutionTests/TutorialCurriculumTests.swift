import Foundation
import Testing
@testable import FisuEvolution

@Suite("El currículo: claves y anclas")
@MainActor
struct TutorialCurriculumTests {
    private static let repoRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// Todo el código de la app, junto, para buscar literales.
    static func swiftSources() throws -> String {
        let root = repoRoot.appending(path: "FisuEvolution")
        return try FileManager.default.subpathsOfDirectory(atPath: root.path())
            .filter { $0.hasSuffix(".swift") }
            .map { try String(contentsOf: root.appending(path: $0), encoding: .utf8) }
            .joined(separator: "\n")
    }

    /// Las claves que las tareas todavía no aplicaron al catálogo (`claves-pendientes/*.json`,
    /// las aplica el controlador al integrar): con es y en escritos, cuentan como presentes.
    private static func pendingKeys() throws -> Set<String> {
        let folder = repoRoot.appending(path: "Tools/v2/claves-pendientes")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path()).filter { $0.hasSuffix(".json") }
        var keys: Set<String> = []
        for file in files {
            let data = try Data(contentsOf: folder.appending(path: file))
            let snapshot = try JSONDecoder().decode([String: [String: String]].self, from: data)
            for (key, languages) in snapshot where languages["es"]?.isEmpty == false && languages["en"]?.isEmpty == false {
                keys.insert(key)
            }
        }
        return keys
    }

    @Test("cada paso tiene su texto en es y en")
    func everyStepIsTranslated() throws {
        let catalog = try LocalizationCompletenessTests.catalog("Localizable")
        let pending = try Self.pendingKeys()
        let keys = TutorialMechanic.allCurriculumSteps.map(\.textKey)
        #expect(!keys.isEmpty)
        let problems = keys
            .filter { catalog.strings[$0] != nil || !pending.contains($0) }
            .flatMap { LocalizationCompletenessTests.problems(of: $0, in: catalog) }
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }

    @Test("cada ancla que el currículo señala la publica alguna vista")
    func everyTargetIsPublished() throws {
        let sources = try Self.swiftSources()
        let notViews: Set<TutorialTarget> = [.boardUnit]
        let targets = Set(TutorialMechanic.allCurriculumSteps.compactMap(\.target)).subtracting(notViews)
        #expect(!targets.isEmpty)
        for target in targets {
            let literal = ".tutorialAnchor(.\(target.rawValue)"
            #expect(sources.contains(literal) || TutorialMechanic.dynamicAnchors.contains(target),
                    "nadie publica \(literal)")
        }
        for target in TutorialMechanic.dynamicAnchors {
            #expect(sources.contains(".\(target.rawValue)"), "\(target) se declara dinámica pero no aparece")
        }
    }

    @Test("los ids de los pasos no se repiten")
    func uniqueStepIDs() {
        let ids = TutorialMechanic.allCurriculumSteps.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
