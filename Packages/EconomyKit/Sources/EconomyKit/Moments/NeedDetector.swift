import Foundation

/// Los detectores de necesidad natural (2.1 E15 F3, C1). Puros: leen la foto del estado y nunca la
/// cambian; ninguno empuja al jugador hacia un momento.
public enum NeedDetector {
    /// Los momentos presentes en la foto, en orden de prioridad (el de `NeedMoment.allCases`). Con algo
    /// encima del tablero o el tutorial activo no hay ninguno.
    public static func moments(_ snapshot: NeedSnapshot, thresholds: NeedThresholds) -> [NeedMoment] {
        guard !snapshot.uiCoversBoard, !snapshot.tutorialActive else { return [] }
        return NeedMoment.allCases.filter { isPresent($0, in: snapshot, thresholds: thresholds) }
    }

    private static func isPresent(
        _ moment: NeedMoment,
        in snapshot: NeedSnapshot,
        thresholds: NeedThresholds
    ) -> Bool {
        switch moment {
        case .floorFull:
            return snapshot.freeSlots <= 0
        case .priceWall:
            return isPriceWall(cost: snapshot.nextHireCost, income: snapshot.incomePerSecond,
                               minutes: thresholds.priceWallMinutes)
        case .mattressReady:
            return snapshot.mattressReady
        case .backOffline:
            guard let away = snapshot.secondsAwayOnReturn, away.isFinite else { return false }
            return away > thresholds.backOfflineMinutes * 60
        }
    }

    /// Sin ingreso, cualquier costo es una pared (la espera es infinita); sin costo, nunca. No divide
    /// por cero: compara el costo contra lo que entra en el umbral.
    private static func isPriceWall(cost: Double, income: Double, minutes: Double) -> Bool {
        guard cost > 0 else { return false }
        guard income.isFinite, income > 0 else { return true }
        return cost > income * minutes * 60
    }
}
