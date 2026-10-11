import Foundation
import Testing
@testable import EconomyKit

@Suite("El ritmo de las lecciones")
struct TutorialPacingTests {
    @Test("al arrancar no hay nada que esperar")
    func freshPacingAllows() {
        #expect(TutorialPacing().mayStartLesson)
    }

    @Test("20 s entre el fin de una lección y la siguiente")
    func twentySecondsBetweenLessons() {
        var pacing = TutorialPacing()
        pacing.lessonEnded()
        pacing.tick(19.9)
        #expect(!pacing.mayStartLesson)
        pacing.tick(0.1)
        #expect(pacing.mayStartLesson)
    }

    @Test("un toque al tablero en el último segundo la frena: no se come taps")
    func aRecentBoardTouchHolds() {
        var pacing = TutorialPacing()
        pacing.boardTouched()
        pacing.tick(0.9)
        #expect(!pacing.mayStartLesson)
        pacing.tick(0.1)
        #expect(pacing.mayStartLesson)
    }

    @Test("las dos esperas se suman: manda la más larga")
    func bothWaitsApply() {
        var pacing = TutorialPacing()
        pacing.lessonEnded()
        pacing.tick(25)
        pacing.boardTouched()
        #expect(!pacing.mayStartLesson)
        pacing.tick(1)
        #expect(pacing.mayStartLesson)
    }
}
