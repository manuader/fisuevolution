import Foundation

/// Qué hacer con las banderas del tutorial la primera vez que arranca la 2.0 (PLAN-v2 E9).
///
/// Pura: la app lee `UserDefaults` y le pasa lo que encontró; lo que devuelve es lo que se
/// escribe. Un veterano es quien **tiene save y no tiene versión**: recibe el Tour, y lo que la
/// v1 ya le enseñaba se da por visto (lo nuevo se le enseña en su primera ocurrencia).
public enum TutorialMigration {
    public struct Input: Sendable, Equatable {
        public var hasSave: Bool
        public var storedVersion: Int?
        public var legacyCoreDone: Bool
        public var legacyLessonsDone: Set<String>

        public init(hasSave: Bool, storedVersion: Int?, legacyCoreDone: Bool, legacyLessonsDone: Set<String>) {
            self.hasSave = hasSave
            self.storedVersion = storedVersion
            self.legacyCoreDone = legacyCoreDone
            self.legacyLessonsDone = legacyLessonsDone
        }
    }

    public struct Plan: Sendable, Equatable {
        public var coreCompleted: Bool
        public var tourPending: Bool
        public var lessonsDone: Set<String>
        public var version: Int

        public init(coreCompleted: Bool, tourPending: Bool, lessonsDone: Set<String>, version: Int) {
            self.coreCompleted = coreCompleted
            self.tourPending = tourPending
            self.lessonsDone = lessonsDone
            self.version = version
        }
    }

    /// `nil` = ya está migrado. `veteranKnownLessons` son las lecciones de mecánicas que la v1
    /// ya tenía (las declara la app: `TutorialLesson.introducedIn == .v1`).
    public static func plan(_ input: Input, currentVersion: Int, veteranKnownLessons: Set<String>) -> Plan? {
        guard input.storedVersion == nil else { return nil }
        guard input.hasSave else {
            return Plan(coreCompleted: false, tourPending: false, lessonsDone: [], version: currentVersion)
        }
        guard input.legacyCoreDone else {
            return Plan(coreCompleted: false, tourPending: false,
                        lessonsDone: input.legacyLessonsDone, version: currentVersion)
        }
        return Plan(coreCompleted: true, tourPending: true,
                    lessonsDone: input.legacyLessonsDone.union(veteranKnownLessons),
                    version: currentVersion)
    }
}
