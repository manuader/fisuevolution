import Foundation

/// Con qué se paga un giro.
public enum WheelSpinSource: String, Sendable, Equatable, CaseIterable {
    /// Uno regalado: no pide nada.
    case bonus
    /// Uno de los diarios por video.
    case video
    /// El extra con ORO (apagado donde la tienda no lo permite: lo decide la app).
    case oro
}

/// Los cupos y el sorteo de la ruleta. El estado que recibe ya está pasado al
/// día de hoy (`WheelState.rolledOver`).
public enum WheelRoller {
    public static func spinsLeft(_ source: WheelSpinSource, state: WheelState, config: WheelConfig) -> Int {
        switch source {
        case .bonus: max(0, state.bonusSpins)
        case .video: max(0, config.videoSpinsPerDay - state.videoSpinsUsed)
        case .oro: max(0, config.oroSpinsPerDay - state.oroSpinsUsed)
        }
    }

    /// Gasta un giro de esa fuente. Sin cupo, no toca nada y devuelve `false`.
    @discardableResult
    public static func consume(_ source: WheelSpinSource, state: inout WheelState, config: WheelConfig) -> Bool {
        guard spinsLeft(source, state: state, config: config) > 0 else { return false }
        switch source {
        case .bonus: state.bonusSpins -= 1
        case .video: state.videoSpinsUsed += 1
        case .oro: state.oroSpinsUsed += 1
        }
        return true
    }

    /// El índice ganador dentro de `segments` (la tabla efectiva).
    public static func roll<R: RandomNumberGenerator>(_ segments: [WheelConfig.Segment], using rng: inout R) -> Int? {
        WeightedDraw.index(weights: segments.map { Double($0.weight) }, using: &rng)
    }
}
