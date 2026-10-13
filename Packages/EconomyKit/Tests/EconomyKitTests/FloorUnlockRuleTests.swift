import Foundation
import Testing
@testable import EconomyKit

@Suite("El desbloqueo de piso no se saltea (E14 C21, D6)")
struct FloorUnlockRuleTests {
    @Test("la primera vez de la cuenta: completo e insalteable")
    func firstEverIsFullAndUnskippable() {
        let engagement = EngagementState.initial
        let presentation = engagement.floorUnlockPresentation(floorID: "f2", life: 0)
        #expect(!presentation.skippable)
        #expect(!presentation.short)
    }

    @Test("la segunda vez en la misma vida: se puede saltear")
    func secondTimeInTheSameLifeIsSkippable() {
        var engagement = EngagementState.initial
        engagement.recordFloorUnlock(floorID: "f2", life: 0)
        let presentation = engagement.floorUnlockPresentation(floorID: "f2", life: 0)
        #expect(presentation.skippable)
        #expect(presentation.short)
    }

    @Test("otro piso de la misma vida sigue siendo su primera vez")
    func anotherFloorIsItsOwnFirstTime() {
        var engagement = EngagementState.initial
        engagement.recordFloorUnlock(floorID: "f2", life: 0)
        #expect(!engagement.floorUnlockPresentation(floorID: "f3", life: 0).skippable)
    }

    @Test("una vida nueva: corto pero insalteable una vez, y después salteable")
    func newLifeIsShortAndUnskippableOnce() {
        var engagement = EngagementState.initial
        engagement.recordFloorUnlock(floorID: "f2", life: 0)
        let reborn = engagement.floorUnlockPresentation(floorID: "f2", life: 1)
        #expect(!reborn.skippable)
        #expect(reborn.short)
        engagement.recordFloorUnlock(floorID: "f2", life: 1)
        #expect(engagement.floorUnlockPresentation(floorID: "f2", life: 1).skippable)
    }

    @Test("un save de antes, sin la clave, decodifica vacío; y lo anotado sobrevive la ida y vuelta")
    func codableRoundTripAndLegacy() throws {
        let legacy = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(legacy.floorUnlocksSeen.isEmpty)
        var engagement = EngagementState.initial
        engagement.recordFloorUnlock(floorID: "f2", life: 3)
        let back = try JSONDecoder().decode(EngagementState.self, from: JSONEncoder().encode(engagement))
        #expect(back.floorUnlocksSeen == ["f2": 3])
    }

    @Test("entre dispositivos gana la vida más reciente por piso")
    func resolveTakesTheLatestLife() {
        let a = EngagementState(floorUnlocksSeen: ["f2": 1])
        let b = EngagementState(floorUnlocksSeen: ["f2": 3, "f3": 0])
        #expect(EngagementState.resolve(winner: a, loser: b).floorUnlocksSeen == ["f2": 3, "f3": 0])
        #expect(EngagementState.resolve(winner: b, loser: a).floorUnlocksSeen == ["f2": 3, "f3": 0])
    }

    @Test("el ítem trabado ignora el toque aunque pase el piso; el resto de las celebraciones sigue salteable")
    func lockedItemIgnoresTapsButOthersStillSkip() {
        var locked = CelebrationQueue()
        locked.enqueue(.boardCelebration)
        locked.lockSkip(.boardCelebration)
        _ = locked.tick(CelebrationQueue.skipFloor + 1)
        for _ in 0..<10 {
            let skipped = locked.skip()
            #expect(!skipped)
        }
        #expect(locked.current == .boardCelebration)

        var plain = CelebrationQueue()
        plain.enqueue(.boardCelebration)
        _ = plain.tick(CelebrationQueue.skipFloor + 1)
        let plainSkipped = plain.skip()
        #expect(plainSkipped, "sin piso nuevo la del tablero se saltea como siempre")

        var notice = CelebrationQueue()
        notice.enqueue(.towerNotice)
        _ = notice.tick(CelebrationQueue.skipFloor + 1)
        let noticeSkipped = notice.skip()
        #expect(noticeSkipped)
    }

    @Test("el cerrojo no sobrevive al turno: ni al fin, ni al watchdog, y no cierra al ítem siguiente")
    func lockDoesNotOutliveTheTurn() {
        var queue = CelebrationQueue()
        queue.enqueue(.boardCelebration)
        queue.lockSkip(.boardCelebration)
        queue.enqueue(.towerNotice)
        queue.finish(.boardCelebration)
        #expect(queue.current == .towerNotice)
        #expect(!queue.isSkipLocked)
        _ = queue.tick(CelebrationQueue.skipFloor + 1)
        let nextSkipped = queue.skip()
        #expect(nextSkipped)

        var stuck = CelebrationQueue()
        stuck.enqueue(.boardCelebration)
        stuck.lockSkip(.boardCelebration)
        let released = stuck.tick(CelebrationKind.boardCelebration.timeout ?? 0)
        #expect(released == .boardCelebration)
        #expect(stuck.current == nil)
        #expect(!stuck.isSkipLocked)
    }

    @Test("trabar un ítem que no tiene el turno no hace nada")
    func lockingSomeoneElseIsANoOp() {
        var queue = CelebrationQueue()
        queue.enqueue(.towerNotice)
        queue.lockSkip(.boardCelebration)
        #expect(!queue.isSkipLocked)
    }
}
