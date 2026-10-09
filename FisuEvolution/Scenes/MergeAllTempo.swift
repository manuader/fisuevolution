import Foundation

/// El ritmo de "Fusionar todo": el primer par entra como cualquier cambio del
/// tablero y los siguientes se funden casi sin pausa, con un tono que sube.
struct MergeAllTempo: Equatable {
    /// `BoardScene.boardChangeBeat`: la pausa de un cambio suelto.
    static let firstBeat: TimeInterval = 0.35
    /// `BoardScene.flightMaxDuration` + 0,1: volver al piso de la cadena.
    static let travelLeadIn: TimeInterval = 1.0
    static let chainLeadIn: TimeInterval = 0.04
    static let chainBeat: TimeInterval = 0.12
    /// `BoardScene.assistedMergeSlide`.
    static let firstSlide: TimeInterval = 0.18
    static let chainSlide: TimeInterval = 0.14
    /// El "plin" sube un semitono por eslabón hasta una sexta (rate de AVAudioPlayer).
    static let semitone: Float = 1.059_463
    static let maxPitch: Float = 1.5

    let reduceMotion: Bool

    func leadIn(index: Int, travels: Bool) -> TimeInterval {
        if reduceMotion { return travels ? 0.2 : 0.05 }
        if travels { return Self.travelLeadIn }
        return index == 0 ? Self.firstBeat : Self.chainLeadIn
    }

    func beat(index: Int) -> TimeInterval {
        if reduceMotion { return 0.05 }
        return index == 0 ? Self.firstBeat : Self.chainBeat
    }

    func slide(index: Int) -> TimeInterval {
        if reduceMotion { return 0.01 }
        return index == 0 ? Self.firstSlide : Self.chainSlide
    }

    func pitch(index: Int) -> Float {
        min(Self.maxPitch, pow(Self.semitone, Float(max(0, index))))
    }

    /// Lo que tarda un eslabón sin reveal, sin viajar: el presupuesto.
    func linkDuration(index: Int) -> TimeInterval {
        leadIn(index: index, travels: false) + beat(index: index) + slide(index: index)
    }
}
