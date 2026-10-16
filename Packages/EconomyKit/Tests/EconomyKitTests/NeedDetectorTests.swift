import Foundation
import Testing
@testable import EconomyKit

/// Los detectores de necesidad natural (2.1 E15 F3 T1): leen la foto del estado y dicen qué momentos
/// hay, en orden de prioridad; con algo encima del tablero, ninguno.
@Suite("Los momentos de necesidad natural")
struct NeedDetectorTests {
    let thresholds = NeedThresholds(priceWallMinutes: 8, backOfflineMinutes: 120)

    /// Un estado tranquilo: hay lugar, la contratación sale en un minuto, nada para cobrar.
    private func calm(
        freeSlots: Int = 3,
        nextHireCost: Double = 60,
        incomePerSecond: Double = 1,
        mattressReady: Bool = false,
        secondsAwayOnReturn: Double? = nil,
        uiCoversBoard: Bool = false,
        tutorialActive: Bool = false
    ) -> NeedSnapshot {
        NeedSnapshot(freeSlots: freeSlots, nextHireCost: nextHireCost, incomePerSecond: incomePerSecond,
                     mattressReady: mattressReady, secondsAwayOnReturn: secondsAwayOnReturn,
                     uiCoversBoard: uiCoversBoard, tutorialActive: tutorialActive)
    }

    @Test("un estado tranquilo no tiene momentos")
    func calmHasNone() {
        #expect(NeedDetector.moments(calm(), thresholds: thresholds).isEmpty)
    }

    @Test("el piso sin lugares libres es un momento; con uno libre, no")
    func floorFull() {
        #expect(NeedDetector.moments(calm(freeSlots: 0), thresholds: thresholds) == [.floorFull])
        #expect(NeedDetector.moments(calm(freeSlots: 1), thresholds: thresholds).isEmpty)
    }

    @Test("9 minutos de ingreso con umbral de 8 es pared de precio; 7, no")
    func priceWall() {
        let nine = calm(nextHireCost: 9 * 60 * 10, incomePerSecond: 10)
        let seven = calm(nextHireCost: 7 * 60 * 10, incomePerSecond: 10)
        #expect(NeedDetector.moments(nine, thresholds: thresholds) == [.priceWall])
        #expect(NeedDetector.moments(seven, thresholds: thresholds).isEmpty)
    }

    @Test("justo en el umbral todavía no es pared: tiene que tardar más")
    func priceWallAtThresholdIsNot() {
        let eight = calm(nextHireCost: 8 * 60 * 10, incomePerSecond: 10)
        #expect(NeedDetector.moments(eight, thresholds: thresholds).isEmpty)
    }

    @Test("sin ingreso es pared sólo si la contratación cuesta algo, y no divide por cero")
    func priceWallWithoutIncome() {
        #expect(NeedDetector.moments(calm(nextHireCost: 1, incomePerSecond: 0), thresholds: thresholds)
                == [.priceWall])
        #expect(NeedDetector.moments(calm(nextHireCost: 0, incomePerSecond: 0), thresholds: thresholds)
                .isEmpty)
        #expect(NeedDetector.moments(calm(nextHireCost: 50, incomePerSecond: -3), thresholds: thresholds)
                == [.priceWall], "un ingreso negativo cuenta como cero")
    }

    @Test("el colchón listo y sin cobrar es un momento")
    func mattressReady() {
        #expect(NeedDetector.moments(calm(mattressReady: true), thresholds: thresholds) == [.mattressReady])
    }

    @Test("una vuelta de 3 h con umbral de 2 h es momento; una de 1 h, no")
    func backOffline() {
        #expect(NeedDetector.moments(calm(secondsAwayOnReturn: 3 * 3600), thresholds: thresholds)
                == [.backOffline])
        #expect(NeedDetector.moments(calm(secondsAwayOnReturn: 3600), thresholds: thresholds).isEmpty)
    }

    @Test("la vuelta sólo cuenta en la foto de la vuelta: sin el dato, no hay momento")
    func backOfflineOnlyOnReturnSnapshot() {
        #expect(NeedDetector.moments(calm(secondsAwayOnReturn: nil), thresholds: thresholds).isEmpty)
    }

    @Test("con algo encima del tablero o el tutorial activo no hay ningún momento")
    func coveredBoardHasNone() {
        let everything = calm(freeSlots: 0, nextHireCost: 1_000_000, incomePerSecond: 1,
                              mattressReady: true, secondsAwayOnReturn: 10 * 3600)
        var covered = everything
        covered.uiCoversBoard = true
        var tutorial = everything
        tutorial.tutorialActive = true
        #expect(NeedDetector.moments(covered, thresholds: thresholds).isEmpty)
        #expect(NeedDetector.moments(tutorial, thresholds: thresholds).isEmpty)
    }

    @Test("con todos a la vez salen en el orden de prioridad, siempre el mismo")
    func stablePriorityOrder() {
        let everything = calm(freeSlots: 0, nextHireCost: 1_000_000, incomePerSecond: 1,
                              mattressReady: true, secondsAwayOnReturn: 10 * 3600)
        let expected: [NeedMoment] = [.floorFull, .priceWall, .mattressReady, .backOffline]
        #expect(expected == NeedMoment.allCases)
        for _ in 0..<5 {
            #expect(NeedDetector.moments(everything, thresholds: thresholds) == expected)
        }
    }

    @Test("los detectores no cambian la foto")
    func detectorsArePure() {
        let snapshot = calm(freeSlots: 0, mattressReady: true)
        let copy = snapshot
        _ = NeedDetector.moments(snapshot, thresholds: thresholds)
        #expect(snapshot == copy)
    }

    @Test("los valores crudos del momento son los de la config y el embudo")
    func rawValues() {
        #expect(NeedMoment.allCases.map(\.rawValue)
                == ["floor_full", "price_wall", "mattress_ready", "back_offline"])
    }
}
