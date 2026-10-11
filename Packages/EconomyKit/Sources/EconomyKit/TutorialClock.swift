import Foundation

/// El reloj de UN paso del tutorial (PLAN-v2 E9). Lo avanza el tick del juego, nunca un
/// `Timer`: así el candado vive en el estado y los tests inyectan segundos.
///
/// - Explicar: "Entendido" se habilita a los 5 s fijos. No es salteable.
/// - Acción: avanza sólo con su señal; si en 3 min no llegó, el watchdog lo libera (sin premio).
public struct TutorialStepClock: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case explain
        case action
    }

    public static let explainLock: TimeInterval = 5
    public static let actionWatchdog: TimeInterval = 180

    public let kind: Kind
    public let lock: TimeInterval
    public private(set) var elapsed: TimeInterval = 0

    public init(kind: Kind, lock: TimeInterval = TutorialStepClock.explainLock) {
        self.kind = kind
        self.lock = lock
    }

    public mutating func tick(_ delta: TimeInterval) {
        elapsed += max(0, delta)
    }

    public var canConfirm: Bool {
        kind == .explain && elapsed >= lock
    }

    /// Lo que dibuja el relleno del botón: 0 → 1 durante el candado.
    public var lockProgress: Double {
        guard kind == .explain, lock > 0 else { return 1 }
        return min(1, elapsed / lock)
    }

    public var watchdogExpired: Bool {
        kind == .action && elapsed >= Self.actionWatchdog
    }
}

/// El ritmo de las lecciones (PLAN-v2 E9): una por vez, 20 s entre el fin de una y la
/// siguiente, y nunca con el dedo todavía en el tablero (una lección que nace en medio de una
/// ráfaga de toques se come el siguiente).
public struct TutorialPacing: Sendable, Equatable {
    public static let gapBetweenLessons: TimeInterval = 20
    public static let quietBoard: TimeInterval = 1

    public private(set) var sinceLessonEnded: TimeInterval = .infinity
    public private(set) var sinceBoardTouch: TimeInterval = .infinity

    public init() {}

    public mutating func tick(_ delta: TimeInterval) {
        let step = max(0, delta)
        sinceLessonEnded += step
        sinceBoardTouch += step
    }

    public mutating func lessonEnded() {
        sinceLessonEnded = 0
    }

    public mutating func boardTouched() {
        sinceBoardTouch = 0
    }

    public var mayStartLesson: Bool {
        sinceLessonEnded >= Self.gapBetweenLessons && sinceBoardTouch >= Self.quietBoard
    }
}
