import Foundation
import Testing
@testable import EconomyKit

@Suite("De las banderas de la v1 a las de la 2.0")
struct TutorialMigrationTests {
    private let known: Set<String> = ["upgrades", "skins", "gifts"]

    private func plan(hasSave: Bool, version: Int? = nil, coreDone: Bool = false,
                      lessons: Set<String> = []) -> TutorialMigration.Plan? {
        TutorialMigration.plan(
            .init(hasSave: hasSave, storedVersion: version, legacyCoreDone: coreDone, legacyLessonsDone: lessons),
            currentVersion: 1,
            veteranKnownLessons: known
        )
    }

    @Test("ya migrado: no se toca nada")
    func alreadyMigrated() {
        #expect(plan(hasSave: true, version: 1, coreDone: true) == nil)
        #expect(plan(hasSave: false, version: 1) == nil)
    }

    @Test("instalación nueva: núcleo por delante, sin Tour")
    func freshInstall() {
        let result = plan(hasSave: false, coreDone: true)
        #expect(result == .init(coreCompleted: false, tourPending: false, lessonsDone: [], version: 1),
                "sin save no hay veterano, aunque quede una bandera vieja de otra instalación")
    }

    @Test("veterano de la v1 (save + núcleo hecho): Tour, y lo que la v1 ya enseñaba queda dado")
    func veteran() {
        let result = plan(hasSave: true, coreDone: true, lessons: ["store", "prestige"])
        #expect(result?.coreCompleted == true)
        #expect(result?.tourPending == true)
        #expect(result?.lessonsDone == ["store", "prestige", "upgrades", "skins", "gifts"])
        #expect(result?.version == 1)
    }

    @Test("save de la v1 a medio núcleo: sigue el núcleo, sin Tour")
    func halfwayThroughTheCore() {
        let result = plan(hasSave: true, coreDone: false, lessons: [])
        #expect(result == .init(coreCompleted: false, tourPending: false, lessonsDone: [], version: 1))
    }
}
