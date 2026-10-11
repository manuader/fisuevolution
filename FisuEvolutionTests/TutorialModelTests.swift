import Foundation
import Testing
@testable import FisuEvolution

@Suite("El modelo del paso y de la corrida")
struct TutorialModelTests {
    private let base = TutorialProbe()

    @Test("las señales de contador miran el cambio desde el inicio del paso, no el total")
    func counterSignalsAreRelative() {
        var start = base
        start.merges = 7
        var now = start
        #expect(!TutorialSignal.merged.isSatisfied(baseline: start, now: now, events: [], lesson: nil),
                "siete fusiones de antes no cumplen el paso")
        now.merges = 8
        #expect(TutorialSignal.merged.isSatisfied(baseline: start, now: now, events: [], lesson: nil))
    }

    @Test("las del núcleo son absolutas: retomar a mitad de camino no rehace nada")
    func coreSignalsAreAbsolute() {
        var now = base
        now.ftueSpawned = true
        #expect(TutorialSignal.coreHired.isSatisfied(baseline: now, now: now, events: [], lesson: nil))
        now.ftueTapped = true
        #expect(!TutorialSignal.coreTappedAndAffordable.isSatisfied(baseline: now, now: now, events: [], lesson: nil),
                "tocó, pero todavía no le alcanza para contratar")
        now.canAffordSpawn = true
        #expect(TutorialSignal.coreTappedAndAffordable.isSatisfied(baseline: now, now: now, events: [], lesson: nil))
    }

    @Test("fijar y soltar miran el pin del atajo")
    func pinSignals() {
        var now = base
        #expect(!TutorialSignal.pinned.isSatisfied(baseline: base, now: now, events: [], lesson: nil))
        now.pinnedTypeId = "homeless"
        #expect(TutorialSignal.pinned.isSatisfied(baseline: base, now: now, events: [], lesson: nil))
        #expect(TutorialSignal.unpinned.isSatisfied(baseline: now, now: base, events: [], lesson: nil))
        #expect(!TutorialSignal.unpinned.isSatisfied(baseline: base, now: base, events: [], lesson: nil),
                "soltar pide haber tenido algo fijado al empezar el paso")
    }

    @Test("la acción firma es la de la lección que corre, no la de otra")
    func lessonActionIsScoped() {
        let events: Set<TutorialEvent> = [.lessonAction("elevator")]
        #expect(TutorialSignal.lessonAction.isSatisfied(baseline: base, now: base, events: events, lesson: "elevator"))
        #expect(!TutorialSignal.lessonAction.isSatisfied(baseline: base, now: base, events: events, lesson: "prestige"))
    }

    @Test("abrir una pantalla cumple sólo esa pantalla")
    func screenOpened() {
        let events: Set<TutorialEvent> = [.screenOpened(.upgrades)]
        #expect(TutorialSignal.screenOpened(.upgrades).isSatisfied(baseline: base, now: base, events: events, lesson: nil))
        #expect(!TutorialSignal.screenOpened(.gifts).isSatisfied(baseline: base, now: base, events: events, lesson: nil))
    }

    @Test("avanzar renueva la foto, borra los eventos y vuelve a cerrar el candado")
    func advancing() {
        var run = TutorialRun(script: .lesson("passive"), steps: [
            .act("passive.open", .screenOpened(.upgrades), text: "tutorial.passive.open", on: .upgrades),
            .explain("passive.done", text: "tutorial.passive.done", surface: .page(.upgrades)),
        ], probe: base)
        run.events.insert(.screenOpened(.upgrades))
        run.unlocked = true
        #expect(run.isStepSatisfied(probe: base))
        var later = base
        later.taps = 3
        run.advance(probe: later)
        #expect(run.index == 1)
        #expect(run.baseline == later)
        #expect(run.events.isEmpty)
        #expect(!run.unlocked)
        #expect(!run.isStepSatisfied(probe: later), "un paso de explicar se cumple con el botón, no solo")
        run.advance(probe: later)
        #expect(run.isFinished)
        #expect(run.step == nil)
    }

    @Test("con la hoja cerrada, un paso de hoja vuelve al último paso de tablero")
    func rewindingToTheBoard() {
        var run = TutorialRun(script: .lesson("upgrades"), steps: [
            .act("upgrades.open", .screenOpened(.upgrades), text: "tutorial.upgrades.open", on: .upgrades),
            .act("upgrades.buy", .upgradeBought, text: "tutorial.upgrades.buy", on: nil, surface: .page(.upgrades)),
        ], probe: base)
        run.advance(probe: base)
        let rewound = run.rewindToBoard(probe: base)
        #expect(rewound)
        #expect(run.index == 0)
        let again = run.rewindToBoard(probe: base)
        #expect(!again, "un paso de tablero no rebobina")
    }

    @Test("el Tour y el repaso son demostraciones")
    func demoScripts() {
        #expect(TutorialRun(script: .tour, steps: [], probe: base).isDemo)
        #expect(TutorialRun(script: .replay, steps: [], probe: base).isDemo)
        #expect(!TutorialRun(script: .core, steps: [], probe: base).isDemo)
    }
}
