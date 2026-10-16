import Foundation

/// Dónde está parado un colchón del tablero (E14b B24): el piso que se miraba cuando cayó y su
/// lugar sobre la superficie de ese piso, en las mismas fracciones que una caja (`PackageBox.x`,
/// `PackageBox.y`). Sin piso o sin lugar todavía, se ubica al cargar.
public protocol MattressPlacement {
    var floor: Int? { get set }
    var x: Double? { get set }
    var y: Double? { get set }
    /// Está en el tablero y todavía no tiene piso ni lugar.
    var needsPlacement: Bool { get }
    /// Cae en el piso `floor`, en `spot`, si todavía no tiene lugar.
    mutating func land(onFloor floor: Int, at spot: PackageSpot)
}

public extension MattressPlacement {
    /// Su lugar en el piso, si ya tiene los dos ejes.
    var spot: PackageSpot? {
        guard let x, let y else { return nil }
        return PackageSpot(x: x, y: y)
    }

    /// Ya no está en el tablero, o su piso se cerró (una reencarnación): se olvida su lugar.
    mutating func clearPlacement() {
        floor = nil
        x = nil
        y = nil
    }
}

/// El colchón gratis del tablero (E14b B31, D20): cada tanto de reloj real cae uno, también con el
/// juego cerrado. Guarda uno solo: mientras espera sin abrir, el reloj no corre; al abrirlo arranca
/// de nuevo.
public struct FreeBoardMattress: Codable, Sendable, Equatable, MattressPlacement {
    /// Cuándo arrancó el reloj, en segundos de reloj real (desde 1970). `nil` = todavía no arrancó
    /// (una partida nueva o un save anterior a B31): arranca al cargar.
    public var clockStartedAt: Double?
    /// Hay uno en el tablero, sin abrir.
    public var waiting: Bool
    public var floor: Int?
    public var x: Double?
    public var y: Double?

    public init(clockStartedAt: Double? = nil, waiting: Bool = false, floor: Int? = nil, spot: PackageSpot? = nil) {
        self.clockStartedAt = clockStartedAt
        self.waiting = waiting
        self.floor = floor
        self.x = spot?.x
        self.y = spot?.y
    }

    /// El que espera todavía no tiene piso ni lugar: recién caído o de un save viejo.
    public var needsPlacement: Bool { waiting && (floor == nil || spot == nil) }

    /// Cae en el piso `floor`, en `spot`. Sólo el que espera tiene lugar, y uno que ya lo tiene se
    /// queda ahí, como una caja: mirar otro piso no lo mueve. Para reubicarlo (su piso se cerró) se
    /// olvida antes su lugar (`clearPlacement`).
    public mutating func land(onFloor floor: Int, at spot: PackageSpot) {
        guard needsPlacement else { return }
        self.floor = floor
        x = spot.x
        y = spot.y
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clockStartedAt = try container.decodeIfPresent(Double.self, forKey: .clockStartedAt)
        waiting = try container.decodeIfPresent(Bool.self, forKey: .waiting) ?? false
        floor = try container.decodeIfPresent(Int.self, forKey: .floor)
        x = try container.decodeIfPresent(Double.self, forKey: .x)
        y = try container.decodeIfPresent(Double.self, forKey: .y)
    }
}

/// El Colchón (vive en `meta.engagement`). El de la columna corre con un reloj de JUEGO ACTIVO que
/// sólo avanza sin uno en juego: no se acumula más de uno. El gratis del tablero (`freeBoard`) tiene
/// su propio reloj, de reloj real.
public struct TreasuresState: Codable, Sendable, Equatable, MattressPlacement {
    /// El recorrido del colchón de la columna (E14b B6, D3): aparece en la columna y pide un video
    /// (`waiting`); pagado, cae al tablero (`onBoard`); abierto, vuelve a `none`.
    public enum Phase: String, Codable, Sendable, Equatable {
        case none
        case waiting
        case onBoard
    }

    /// Segundos de juego hasta el próximo. `nil` = nunca se programó.
    public var secondsUntilNext: Double?
    public var phase: Phase
    /// Los "otro colchón" que le quedan al último que se abrió. Se pierden
    /// cuando aparece uno nuevo.
    public var extraOpensLeft: Int
    /// El piso donde cayó el del tablero (E14b B24): el que se miraba cuando cayó. Ahí se queda,
    /// como las cajas. `nil` en la columna, o en un save anterior a B24 (se ubica al cargar).
    public var floor: Int?
    /// Dónde está parado sobre la superficie de ese piso, en las mismas fracciones que una caja
    /// (`PackageBox.x`, `PackageBox.y`).
    public var x: Double?
    public var y: Double?
    /// El colchón gratis del tablero (E14b B31), con su reloj aparte.
    public var freeBoard: FreeBoardMattress

    public static let initial = TreasuresState()

    public init(secondsUntilNext: Double? = nil, phase: Phase = .none, extraOpensLeft: Int = 0,
                floor: Int? = nil, spot: PackageSpot? = nil, freeBoard: FreeBoardMattress = FreeBoardMattress()) {
        self.secondsUntilNext = secondsUntilNext
        self.phase = phase
        self.extraOpensLeft = extraOpensLeft
        self.floor = floor
        self.x = spot?.x
        self.y = spot?.y
        self.freeBoard = freeBoard
    }

    /// Hay un colchón de la columna en juego, en la columna o en el tablero: su reloj no corre.
    public var isPresent: Bool { phase != .none }

    /// El del tablero todavía no tiene piso ni lugar: recién pagado o de un save viejo.
    public var needsPlacement: Bool { phase == .onBoard && (floor == nil || spot == nil) }

    /// Cae en el piso `floor`, en `spot` (E14b B24). Sólo el del tablero tiene lugar, y uno que ya lo
    /// tiene se queda ahí, como una caja: mirar otro piso no lo mueve. Para reubicarlo (su piso se
    /// cerró) se olvida antes su lugar (`clearPlacement`).
    public mutating func land(onFloor floor: Int, at spot: PackageSpot) {
        guard needsPlacement else { return }
        self.floor = floor
        x = spot.x
        y = spot.y
    }

    private enum CodingKeys: String, CodingKey {
        case secondsUntilNext, phase, extraOpensLeft, floor, x, y, freeBoard
        /// El de antes de B6: un colchón esperando en la columna.
        case waiting
        /// El de antes de B31: el del tablero había llegado de regalo (el «1 de cada 4», D4).
        case gifted
    }

    /// Un save anterior a B6 trae `waiting`: el que esperaba sigue esperando su video en la columna.
    /// Uno anterior a B31 no trae `freeBoard` (su reloj arranca al cargar); si tenía un colchón de
    /// regalo en el tablero (`gifted`), pasa a ser el gratis, en el mismo lugar.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        secondsUntilNext = try container.decodeIfPresent(Double.self, forKey: .secondsUntilNext)
        extraOpensLeft = try container.decodeIfPresent(Int.self, forKey: .extraOpensLeft) ?? 0
        floor = try container.decodeIfPresent(Int.self, forKey: .floor)
        x = try container.decodeIfPresent(Double.self, forKey: .x)
        y = try container.decodeIfPresent(Double.self, forKey: .y)
        freeBoard = try container.decodeIfPresent(FreeBoardMattress.self, forKey: .freeBoard) ?? FreeBoardMattress()
        if let phase = (try? container.decodeIfPresent(Phase.self, forKey: .phase)) ?? nil {
            self.phase = phase
        } else {
            let legacyWaiting = try container.decodeIfPresent(Bool.self, forKey: .waiting) ?? false
            phase = legacyWaiting ? .waiting : .none
        }
        let legacyGift = try container.decodeIfPresent(Bool.self, forKey: .gifted) ?? false
        if legacyGift, phase == .onBoard, !freeBoard.waiting {
            freeBoard.waiting = true
            freeBoard.floor = floor
            freeBoard.x = x
            freeBoard.y = y
            phase = .none
            clearPlacement()
        }
    }

    /// Escribe también `waiting` para que una versión anterior a B6 que lea este save siga viendo
    /// el colchón en juego (y lo ofrezca con video).
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(secondsUntilNext, forKey: .secondsUntilNext)
        try container.encode(phase, forKey: .phase)
        try container.encode(extraOpensLeft, forKey: .extraOpensLeft)
        try container.encodeIfPresent(floor, forKey: .floor)
        try container.encodeIfPresent(x, forKey: .x)
        try container.encodeIfPresent(y, forKey: .y)
        try container.encode(freeBoard, forKey: .freeBoard)
        try container.encode(isPresent, forKey: .waiting)
    }
}
