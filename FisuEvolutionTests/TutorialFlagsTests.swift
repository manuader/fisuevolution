import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Las banderas del tutorial")
struct TutorialFlagsTests {
    private func scratch() -> UserDefaults {
        let name = "tutorial-flags-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("el veterano de la v1: núcleo hecho, Tour pendiente, lecciones de la v1 dadas")
    func veteranMigration() {
        let defaults = scratch()
        defaults.set(true, forKey: TutorialFlags.legacyCompletedKey)
        defaults.set(true, forKey: "tutorial.lesson.store")
        let plan = TutorialFlags.migrate(hasSave: true, veteranKnownLessons: ["upgrades"], in: defaults)
        #expect(plan?.tourPending == true)
        #expect(TutorialFlags.coreCompleted(in: defaults))
        #expect(TutorialFlags.tourPending(in: defaults))
        #expect(TutorialFlags.knewOldBar(in: defaults), "el veterano conoció la barra vieja")
        #expect(TutorialFlags.isLessonDone("store", in: defaults))
        #expect(TutorialFlags.isLessonDone("upgrades", in: defaults))
        #expect(defaults.integer(forKey: TutorialFlags.versionKey) == TutorialFlags.currentVersion)
        #expect(defaults.object(forKey: TutorialFlags.legacyCompletedKey) == nil, "la bandera vieja se va")
        #expect(TutorialFlags.migrate(hasSave: true, veteranKnownLessons: [], in: defaults) == nil,
                "la segunda vez no hace nada")
    }

    @Test("una instalación nueva no conoció la barra vieja")
    func freshInstallDidNotKnowTheOldBar() {
        let defaults = scratch()
        TutorialFlags.migrate(hasSave: false, veteranKnownLessons: ["upgrades"], in: defaults)
        #expect(!TutorialFlags.knewOldBar(in: defaults))
    }

    @Test("una lección del blue hecha con su bandera vieja sigue hecha y no se repite")
    @MainActor func legacyBlueLessonsStayDone() {
        let defaults = scratch()
        for (lesson, legacy) in TutorialFlags.legacyLessonIDs {
            #expect(!TutorialFlags.isLessonDone(lesson, in: defaults))
            defaults.set(true, forKey: TutorialFlags.lessonKey(legacy))
            #expect(TutorialFlags.isLessonDone(lesson, in: defaults), "\(lesson)")
        }
        #expect(Set(TutorialFlags.legacyLessonIDs.keys)
            .isSubset(of: GameState.TutorialLesson.allCases.map(\.rawValue)))
        TutorialFlags.wipeGameFlags(in: defaults)
        #expect(TutorialFlags.legacyLessonIDs.keys.allSatisfy { !TutorialFlags.isLessonDone($0, in: defaults) })
    }

    @Test("borrar la partida se lleva las banderas de juego y deja las del dispositivo")
    func wipeKeepsDeviceFlags() {
        let defaults = scratch()
        TutorialFlags.setCoreCompleted(true, in: defaults)
        TutorialFlags.setTourPending(true, in: defaults)
        TutorialFlags.markLessonDone("upgrades", in: defaults)
        defaults.set(true, forKey: "ftue.merged")
        defaults.set(3, forKey: TutorialFlags.sessionsAfterCoreKey)
        defaults.set(["skins"], forKey: TutorialFlags.newTabsKey)
        defaults.set(true, forKey: TutorialFlags.knewOldBarKey)
        defaults.set(["en"], forKey: "AppleLanguages")
        defaults.set("en", forKey: "settings.language")
        defaults.set(false, forKey: "settings.notificationsEnabled")
        defaults.set(0.3, forKey: "settings.musicVolume")

        TutorialFlags.wipeGameFlags(in: defaults)

        #expect(!TutorialFlags.coreCompleted(in: defaults))
        #expect(!TutorialFlags.tourPending(in: defaults))
        #expect(!TutorialFlags.isLessonDone("upgrades", in: defaults))
        #expect(!defaults.bool(forKey: "ftue.merged"))
        #expect(defaults.object(forKey: TutorialFlags.sessionsAfterCoreKey) == nil)
        #expect(defaults.object(forKey: TutorialFlags.newTabsKey) == nil)
        #expect(!TutorialFlags.knewOldBar(in: defaults), "una partida nueva no conoció la barra vieja")
        #expect(defaults.integer(forKey: TutorialFlags.versionKey) == TutorialFlags.currentVersion,
                "una partida borrada no es un veterano: no vuelve a pedir el Tour")
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["en"])
        #expect(defaults.string(forKey: "settings.language") == "en")
        #expect(defaults.object(forKey: "settings.notificationsEnabled") as? Bool == false)
        #expect(defaults.double(forKey: "settings.musicVolume") == 0.3)
    }
}
