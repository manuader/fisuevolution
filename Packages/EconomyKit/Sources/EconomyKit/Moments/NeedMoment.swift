import Foundation

/// Un momento de necesidad natural (2.1 E15 F3, C1): el jugador ya está trabado o a punto de cobrar
/// algo, y ahí una oferta a cambio de un video le sirve de verdad. Los detecta `NeedDetector` leyendo
/// el estado del juego; nada los fabrica.
///
/// El orden de los casos es el de prioridad: cuando hay varios a la vez, manda el primero.
public enum NeedMoment: String, Codable, Sendable, CaseIterable {
    /// No hay lugar libre en el piso activo.
    case floorFull = "floor_full"
    /// La próxima contratación tarda más de N minutos de ingreso.
    case priceWall = "price_wall"
    /// El colchón gratis del tablero está listo y sin cobrar.
    case mattressReady = "mattress_ready"
    /// Volvió después de más de N minutos afuera.
    case backOffline = "back_offline"
}

/// La foto del estado que la app arma cada pocos segundos para preguntar por momentos.
public struct NeedSnapshot: Sendable, Equatable {
    public var freeSlots: Int
    public var nextHireCost: Double
    public var incomePerSecond: Double
    public var mattressReady: Bool
    /// Cuánto estuvo afuera; sólo en el primer snapshot de la vuelta, `nil` en los demás.
    public var secondsAwayOnReturn: Double?
    /// Con un pop-up, una hoja o el tutorial encima del tablero no hay momento.
    public var uiCoversBoard: Bool
    public var tutorialActive: Bool

    public init(
        freeSlots: Int,
        nextHireCost: Double,
        incomePerSecond: Double,
        mattressReady: Bool = false,
        secondsAwayOnReturn: Double? = nil,
        uiCoversBoard: Bool = false,
        tutorialActive: Bool = false
    ) {
        self.freeSlots = freeSlots
        self.nextHireCost = nextHireCost
        self.incomePerSecond = incomePerSecond
        self.mattressReady = mattressReady
        self.secondsAwayOnReturn = secondsAwayOnReturn
        self.uiCoversBoard = uiCoversBoard
        self.tutorialActive = tutorialActive
    }
}

/// Los umbrales de los detectores; llegan en la sección `thresholds` de la config `moments` (C3).
public struct NeedThresholds: Codable, Sendable, Equatable {
    /// La contratación es una pared de precio si tarda más que esto en minutos de ingreso.
    public var priceWallMinutes: Double
    /// La vuelta cuenta si estuvo afuera más que esto en minutos.
    public var backOfflineMinutes: Double

    public init(priceWallMinutes: Double, backOfflineMinutes: Double) {
        self.priceWallMinutes = priceWallMinutes
        self.backOfflineMinutes = backOfflineMinutes
    }

    /// Los de la semilla de `moments.json`.
    public static let seed = NeedThresholds(priceWallMinutes: 8, backOfflineMinutes: 120)
}
