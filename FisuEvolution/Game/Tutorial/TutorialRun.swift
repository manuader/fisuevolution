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

    mutating func advance(probe: TutorialProbe) {
        index += 1
        baseline = probe
        events.removeAll()
        unlocked = false
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
        return true
    }
}
