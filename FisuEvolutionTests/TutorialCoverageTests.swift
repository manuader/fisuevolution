import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// "Toda mecánica del juego tiene su lección" (pedido del dueño, PLAN-v2 E9). El `switch` de
/// `TutorialMechanic.coverage` la hace cumplir al compilar; esto cuida que la cobertura exista
/// de verdad y que ninguna lección quede huérfana.
@Suite("Cobertura del tutorial")
@MainActor
struct TutorialCoverageTests {
    @Test("cada mecánica está cubierta por algo que existe")
    func everyMechanicIsCovered() throws {
        let sources = try TutorialCurriculumTests.swiftSources()
        for mechanic in TutorialMechanic.allCases where !TutorialMechanic.knownGaps.contains(mechanic) {
            switch mechanic.coverage {
            case .core(let id):
                #expect(TutorialCurriculum.core.contains { $0.id == id }, "\(mechanic): \(id)")
            case .lesson(let lesson):
                #expect(!lesson.steps.isEmpty, "\(mechanic): \(lesson)")
            case .inline(let lesson):
                #expect(!lesson.steps.isEmpty, "\(mechanic): \(lesson)")
            case .selfExplained(let id):
                #expect(TutorialMechanic.selfExplaining.contains(id), "\(mechanic): \(id)")
                #expect(sources.contains("\"\(id)\""), "\(mechanic): ninguna vista publica \(id)")
            case .gap:
                Issue.record("\(mechanic) no tiene lección y no está en knownGaps")
            }
        }
    }

    @Test("los huecos declarados son exactamente las mecánicas sin lección")
    func gapsMatchMechanicsWithoutLesson() {
        let uncovered = Set(TutorialMechanic.allCases.filter { $0.coverage == .gap })
        #expect(uncovered == TutorialMechanic.knownGaps)
    }

    @Test("ninguna lección queda fuera del registro")
    func noOrphanLessons() {
        let covered = TutorialMechanic.allCases.map(\.coverage)
        for lesson in GameState.TutorialLesson.allCases {
            #expect(covered.contains(.lesson(lesson)), "\(lesson) no enseña ninguna mecánica registrada")
        }
        for lesson in TutorialInlineLesson.allCases {
            #expect(covered.contains(.inline(lesson)), "\(lesson) no enseña ninguna mecánica registrada")
        }
    }

    @Test("cada ítem de la tienda de ORO es una mecánica con lección")
    func everyShopItemIsTaught() throws {
        let content = try GameContentLoader.load(from: .main)
        #expect(!content.oroShop.items.isEmpty)
        if case .lesson(let lesson) = TutorialMechanic.oroShopShelf.coverage {
            #expect(!lesson.steps.isEmpty)
        } else {
            #expect(TutorialMechanic.knownGaps.contains(.oroShopShelf), "la tienda de ORO necesita su lección")
        }
    }

    @Test("el único hueco es skinEffects: las skins por código no existen (E6b T1r)")
    func theOnlyGapIsSkinEffects() {
        #expect(TutorialMechanic.knownGaps == [.skinEffects])
        #expect(TutorialMechanic.knownGaps.count <= TutorialMechanic.knownGapsCeiling)
        #expect(TutorialMechanic.gapReasons[.skinEffects]?.isEmpty == false)
    }

    @Test("ninguna lección conserva un paso heredado")
    func noLessonKeepsALegacyStep() {
        for mechanic in TutorialMechanic.allCases {
            if case .lesson(let lesson) = mechanic.coverage {
                #expect(!lesson.steps.isEmpty, "\(mechanic)")
                #expect(!lesson.steps.contains { $0.id.hasSuffix(".legacy") }, "\(mechanic) sigue con el paso de la v1")
            }
        }
    }
}
