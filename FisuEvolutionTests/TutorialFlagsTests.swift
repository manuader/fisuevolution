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
        #expect(TutorialFlags.isLessonDone("store", in: defaults))
        #expect(TutorialFlags.isLessonDone("upgrades", in: defaults))
        #expect(defaults.integer(forKey: TutorialFlags.versionKey) == TutorialFlags.currentVersion)
        #expect(defaults.object(forKey: TutorialFlags.legacyCompletedKey) == nil, "la bandera vieja se va")
        #expect(TutorialFlags.migrate(hasSave: true, veteranKnownLessons: [], in: defaults) == nil,
                "la segunda vez no hace nada")
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
        #expect(defaults.integer(forKey: TutorialFlags.versionKey) == TutorialFlags.currentVersion,
                "una partida borrada no es un veterano: no vuelve a pedir el Tour")
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["en"])
        #expect(defaults.string(forKey: "settings.language") == "en")
        #expect(defaults.object(forKey: "settings.notificationsEnabled") as? Bool == false)
        #expect(defaults.double(forKey: "settings.musicVolume") == 0.3)
    }
}
