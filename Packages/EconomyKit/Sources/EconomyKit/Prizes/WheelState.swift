import Foundation

/// La ruleta en `meta.engagement`: el día calendario de los cupos, lo usado
/// hoy, los giros regalados y el premio que todavía se puede repetir.
public struct WheelState: Codable, Sendable, Equatable {
    /// "yyyy-MM-dd" en el huso del dispositivo, como el diario.
    public var day: String?
    public var videoSpinsUsed: Int
    public var oroSpinsUsed: Int
    /// Giros que alguien regaló (el Conductor, un visitante, una oferta). No
    /// piden video y no vencen con el día.
    public var bonusSpins: Int
    /// El último premio, mientras se pueda repetir con un video.
    public var repeatableSegmentId: String?

    public static let initial = WheelState()

    public init(
        day: String? = nil,
        videoSpinsUsed: Int = 0,
        oroSpinsUsed: Int = 0,
        bonusSpins: Int = 0,
        repeatableSegmentId: String? = nil
    ) {
        self.day = day
        self.videoSpinsUsed = videoSpinsUsed
        self.oroSpinsUsed = oroSpinsUsed
        self.bonusSpins = bonusSpins
        self.repeatableSegmentId = repeatableSegmentId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decodeIfPresent(String.self, forKey: .day)
        videoSpinsUsed = try container.decodeIfPresent(Int.self, forKey: .videoSpinsUsed) ?? 0
        oroSpinsUsed = try container.decodeIfPresent(Int.self, forKey: .oroSpinsUsed) ?? 0
        bonusSpins = try container.decodeIfPresent(Int.self, forKey: .bonusSpins) ?? 0
        repeatableSegmentId = try container.decodeIfPresent(String.self, forKey: .repeatableSegmentId)
    }

    /// El mismo estado pasado a `today`: en otro día los cupos vuelven a cero
    /// y el "repetir" se pierde; los regalados se quedan.
    public func rolledOver(to today: String) -> WheelState {
        guard day != today else { return self }
        return WheelState(day: today, bonusSpins: bonusSpins)
    }

    /// Dos dispositivos el mismo día no duplican el cupo: se queda lo más
    /// usado. Lo regalado y el "repetir" viajan con el ganador.
    public static func resolve(winner: WheelState, loser: WheelState) -> WheelState {
        guard winner.day != nil, winner.day == loser.day else { return winner }
        var resolved = winner
        resolved.videoSpinsUsed = max(winner.videoSpinsUsed, loser.videoSpinsUsed)
        resolved.oroSpinsUsed = max(winner.oroSpinsUsed, loser.oroSpinsUsed)
        return resolved
    }
}
