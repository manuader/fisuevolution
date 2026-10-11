import EconomyKit
import Foundation

/// Las banderas del tutorial en `UserDefaults` (PLAN-v2 E9). Es el único lugar que las nombra:
/// nadie más escribe `fisuTutorialDone` ni `tutorial.v2.*` a mano.
///
/// Son de la **partida** (se van con `--uitest-reset` y con "Resetear partida"); las del
/// dispositivo —idioma, audio, avisos, UMP, ATT— no pasan por acá.
enum TutorialFlags {
    static let currentVersion = 1
    static let versionKey = "tutorial.v2.version"
    static let completedKey = "tutorial.v2.completed"
    static let tourPendingKey = "tutorial.v2.tourPending"
    /// La de la v1. Sólo la lee la migración.
    static let legacyCompletedKey = "fisuTutorialDone"
    static let lessonPrefix = "tutorial.lesson."
    static let milestoneKeys = ["ftue.tapped", "ftue.spawned", "ftue.merged"]
    static let sessionsAfterCoreKey = "tutorial.sessionsAfterPhase"
    /// El "¡Nuevo!" de las pestañas (E3a T9, `GameState.newTabsKey`): una partida nueva las
    /// vuelve a cerrar, así que sus "¡Nuevo!" también se van.
    static let newTabsKey = "tabs.new"

    static func lessonKey(_ id: String) -> String { lessonPrefix + id }

    static func coreCompleted(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: completedKey)
    }

    static func setCoreCompleted(_ done: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(done, forKey: completedKey)
    }

    static func tourPending(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: tourPendingKey)
    }

    static func setTourPending(_ pending: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(pending, forKey: tourPendingKey)
    }

    static func isLessonDone(_ id: String, in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: lessonKey(id))
    }

    static func markLessonDone(_ id: String, in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: lessonKey(id))
    }

    /// Deja la instalación en la versión de hoy (sin Tour pendiente).
    static func markCurrent(in defaults: UserDefaults = .standard) {
        defaults.set(currentVersion, forKey: versionKey)
    }

    /// Una partida nueva de verdad: el núcleo vuelve, las lecciones también, y no es un
    /// veterano (la versión queda puesta).
    static func wipeGameFlags(in defaults: UserDefaults = .standard) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(lessonPrefix) {
            defaults.removeObject(forKey: key)
        }
        for key in milestoneKeys { defaults.set(false, forKey: key) }
        defaults.removeObject(forKey: sessionsAfterCoreKey)
        defaults.removeObject(forKey: newTabsKey)
        defaults.removeObject(forKey: legacyCompletedKey)
        setCoreCompleted(false, in: defaults)
        setTourPending(false, in: defaults)
        markCurrent(in: defaults)
    }

    /// Corre una vez por instalación, en el bootstrap.
    @discardableResult
    static func migrate(hasSave: Bool, veteranKnownLessons: Set<String>,
                        in defaults: UserDefaults = .standard) -> TutorialMigration.Plan? {
        let legacyLessons = Set(defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(lessonPrefix) && defaults.bool(forKey: $0) }
            .map { String($0.dropFirst(lessonPrefix.count)) })
        let input = TutorialMigration.Input(
            hasSave: hasSave,
            storedVersion: defaults.object(forKey: versionKey) as? Int,
            legacyCoreDone: defaults.bool(forKey: legacyCompletedKey),
            legacyLessonsDone: legacyLessons
        )
        guard let plan = TutorialMigration.plan(input, currentVersion: currentVersion,
                                                veteranKnownLessons: veteranKnownLessons) else { return nil }
        setCoreCompleted(plan.coreCompleted, in: defaults)
        setTourPending(plan.tourPending, in: defaults)
        for id in plan.lessonsDone { markLessonDone(id, in: defaults) }
        defaults.set(plan.version, forKey: versionKey)
        defaults.removeObject(forKey: legacyCompletedKey)
        return plan
    }
}
