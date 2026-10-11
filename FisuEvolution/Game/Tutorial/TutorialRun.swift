import Foundation

/// Lo que el tutorial está mostrando ahora: un guion, en qué paso va y contra qué foto se
/// mide. Pura: el director (`GameState+Tutorial`) la mueve; la UI sólo la lee.
struct TutorialRun: Equatable {
    enum Script: Equatable {
        case core
        /// El id de la lección (`TutorialLesson.rawValue`, o el de una tarjeta).
        case lesson(String)
        case tour
        case replay
    }

    let script: Script
    let steps: [TutorialStep]
    private(set) var index = 0
    private(set) var baseline: TutorialProbe
    var events: Set<TutorialEvent> = []
    /// El candado del paso actual ya se abrió. Se publica una vez por paso (no por frame).
    var unlocked = false
    /// Cuántas veces el vigilante del núcleo (180 s) volvió a mostrar este paso sin que se cumpliera.
    /// Sólo lo lee la UI, para mostrarlo más insistente; vuelve a cero con cada paso nuevo.
    private(set) var nudges = 0

    init(script: Script, steps: [TutorialStep], probe: TutorialProbe) {
        self.script = script
        self.steps = steps
        self.baseline = probe
    }

    var step: TutorialStep? { steps.indices.contains(index) ? steps[index] : nil }
    var isFinished: Bool { index >= steps.count }
    /// El Tour y el repaso señalan y explican, sin exigir acciones: el estado es arbitrario.
    var isDemo: Bool { script == .tour || script == .replay }

    var lessonID: String? {
        if case .lesson(let id) = script { return id }
        return nil
    }

    func isStepSatisfied(probe: TutorialProbe) -> Bool {
        guard let signal = step?.signal else { return false }
        return signal.isSatisfied(baseline: baseline, now: probe, events: events, lesson: lessonID)
    }

    /// Retomar: un milestone absoluto del núcleo cumple los pasos que lo preceden. Quien ya
    /// contrató no tiene por qué abrir FisuJobs a "abrir FisuJobs" (`screenOpened` no persiste).
    func isNextStepDone(probe: TutorialProbe) -> Bool {
        guard steps.indices.contains(index + 1), let signal = steps[index + 1].signal, signal.isAbsolute else { return false }
        return signal.isSatisfied(baseline: baseline, now: probe, events: events, lesson: lessonID)
    }

    mutating func advance(probe: TutorialProbe) {
        index += 1
        baseline = probe
        events.removeAll()
        unlocked = false
        nudges = 0
    }

    /// El vigilante vuelve a mostrar el paso en vez de saltarlo: no toca la foto ni las señales.
    mutating func insist() {
        nudges += 1
    }

    /// El paso que sigue vive fuera del tablero (una hoja): saltearlo por tiempo lo dejaría
    /// invisible y `rewindToBoard` lo devolvería acá, sin fin.
    var nextStepLeavesTheBoard: Bool {
        guard steps.indices.contains(index + 1) else { return false }
        let surface = steps[index + 1].surface
        return surface != .board && surface != .embedded
    }

    /// Un paso que vive en una hoja no tiene sentido con la hoja cerrada: vuelve al último
    /// paso de tablero (el que la abre). Devuelve si rebobinó.
    mutating func rewindToBoard(probe: TutorialProbe) -> Bool {
        guard let step, step.surface != .board, step.surface != .embedded,
              let board = steps[..<index].lastIndex(where: { $0.surface == .board }) else { return false }
        index = board
        baseline = probe
        events.removeAll()
        unlocked = false
        nudges = 0
        return true
    }
}
