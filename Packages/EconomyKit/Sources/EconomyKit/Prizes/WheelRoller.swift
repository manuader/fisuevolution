import Foundation

/// Con qué se paga un giro.
public enum WheelSpinSource: String, Sendable, Equatable, CaseIterable {
    /// Uno regalado: no pide nada.
    case bonus
    /// Uno de los diarios por video.
    case video
    /// Uno pagado con blue: gasta el mismo cupo diario que el video (apagado
    /// donde la tienda no lo permite: lo decide la app).
    case blue
}

/// Los cupos y el sorteo de la ruleta. El estado que recibe ya está pasado al
/// día de hoy (`WheelState.rolledOver`).
///
/// Hay un solo cupo por día (E14b D11): `videoSpinsPerDay`, que la mejora
/// permanente de la tienda agranda. Un giro por video o con blue lo gasta; los
/// regalados no. Con el cupo en cero no se gira ni con video ni con blue.
public enum WheelRoller {
    public static func spinsLeft(_ source: WheelSpinSource, state: WheelState, config: WheelConfig) -> Int {
        switch source {
        case .bonus: max(0, state.bonusSpins)
        case .video: dailySpinsLeft(state: state, config: config)
        case .blue: config.blueSpinsPerDay > 0 ? dailySpinsLeft(state: state, config: config) : 0
        }
    }

    /// Lo que queda hoy del cupo único, lo gaste un video o el blue.
    public static func dailySpinsLeft(state: WheelState, config: WheelConfig) -> Int {
        max(0, config.videoSpinsPerDay - state.dailySpinsUsed)
    }

    /// Gasta un giro de esa fuente. Sin cupo, no toca nada y devuelve `false`.
    @discardableResult
    public static func consume(_ source: WheelSpinSource, state: inout WheelState, config: WheelConfig) -> Bool {
        guard spinsLeft(source, state: state, config: config) > 0 else { return false }
        switch source {
        case .bonus: state.bonusSpins -= 1
        case .video: state.videoSpinsUsed += 1
        case .blue: state.blueSpinsUsed += 1
        }
        return true
    }

    /// El índice ganador dentro de `segments` (la tabla efectiva).
    public static func roll<R: RandomNumberGenerator>(_ segments: [WheelConfig.Segment], using rng: inout R) -> Int? {
        WeightedDraw.index(weights: segments.map { Double($0.weight) }, using: &rng)
    }
}
