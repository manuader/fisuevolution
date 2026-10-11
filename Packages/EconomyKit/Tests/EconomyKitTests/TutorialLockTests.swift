import Foundation
import Testing
@testable import EconomyKit

@Suite("El candado y el watchdog de un paso del tutorial")
struct TutorialLockTests {
    @Test("explicar: bloqueado a 4,9 s y libre a 5,0 s")
    func theLockOpensAtFiveSeconds() {
        var clock = TutorialStepClock(kind: .explain)
        clock.tick(4.9)
        #expect(!clock.canConfirm)
        #expect(clock.lockProgress < 1)
        var fresh = TutorialStepClock(kind: .explain)
        fresh.tick(5.0)
        #expect(fresh.canConfirm)
        #expect(fresh.lockProgress == 1)
    }

    @Test("el candado se cuenta de a pedacitos, como el tick")
    func theLockAddsUpTicks() {
        var clock = TutorialStepClock(kind: .explain)
        for _ in 0..<49 { clock.tick(0.1) }
        #expect(!clock.canConfirm, "4,9 s en 49 ticks")
        clock.tick(0.2)
        #expect(clock.canConfirm)
    }

    @Test("un delta negativo no hace retroceder el reloj")
    func negativeDeltasAreIgnored() {
        var clock = TutorialStepClock(kind: .explain)
        clock.tick(3)
        clock.tick(-10)
        #expect(clock.elapsed == 3)
    }

    @Test("un paso de acción nunca se confirma con el botón: sólo con su señal")
    func actionsNeverConfirm() {
        var clock = TutorialStepClock(kind: .action)
        clock.tick(60)
        #expect(!clock.canConfirm)
        #expect(clock.lockProgress == 1, "un paso de acción no dibuja candado")
    }

    @Test("el watchdog libera un paso de acción a los 180 s, y nunca uno de explicar")
    func theWatchdogFiresOnlyOnActions() {
        var action = TutorialStepClock(kind: .action)
        action.tick(179.9)
        #expect(!action.watchdogExpired)
        action.tick(0.1)
        #expect(action.watchdogExpired)
        var explain = TutorialStepClock(kind: .explain)
        explain.tick(1000)
        #expect(!explain.watchdogExpired)
    }

    @Test("los números son los del dueño")
    func theOwnersNumbers() {
        #expect(TutorialStepClock.explainLock == 5)
        #expect(TutorialStepClock.actionWatchdog == 180)
    }

    @Test("un candado corto (el fixture de UI) se respeta")
    func aShortLockForFixtures() {
        var clock = TutorialStepClock(kind: .explain, lock: 0.3)
        clock.tick(0.3)
        #expect(clock.canConfirm)
    }
}
