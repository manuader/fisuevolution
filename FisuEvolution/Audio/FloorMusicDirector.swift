import Foundation

/// Qué tema de piso suena y cómo se pasa al siguiente (PLAN-v2 §5, "Música
/// por piso"). Es la parte pura del crossfade: no toca AVFoundation, decide
/// los pasos y `AudioManager` los ejecuta. Así lo que importa —cada piso con
/// su tema, el mismo piso no re-dispara, un scroll rápido no apila
/// fundidos— se prueba sin parlantes.
///
/// Nunca hay más de dos voces: la que manda (`lead`, que suena o está
/// entrando) y la que se va (`tail`). Un tercer tema en medio de un fundido
/// corta a la que se estaba yendo, que a esa altura es la más baja de las dos.
struct FloorMusicDirector: Equatable {
    static let crossfade: TimeInterval = 1.5

    /// Un fundido de salida en curso. El turno distingue dos salidas del
    /// mismo tema: si el jugador vuelve al piso y se vuelve a ir, el aviso de
    /// fin del primer fundido no puede cortar el segundo por la mitad.
    struct Exit: Equatable {
        let track: String
        let turn: Int
    }

    enum Step: Equatable {
        /// Cargar el tema y hacerlo entrar desde silencio.
        case fadeIn(String)
        /// Devolverle el volumen a un tema que se estaba yendo, sin recargarlo.
        case restore(String)
        /// Bajarlo a cero en un fundido entero y avisar al terminar.
        case fadeOut(Exit)
        /// Sacarlo ya: es el tercero en discordia de un cambio rápido.
        case cut(String)
    }

    private(set) var lead: String?
    private(set) var tail: Exit?
    private var turns = 0

    /// Las voces vivas, la que manda primero. Nunca más de dos.
    var voices: [String] { [lead, tail?.track].compactMap { $0 } }

    /// El tema de cada piso sale del id de `economy.json`: `music_<id>_loop`,
    /// el mismo nombre que escribe `Tools/audio-synth/generate_audio.py`.
    static func track(forFloor floorID: String) -> String {
        "music_\(floorID)_loop"
    }

    mutating func show(floor floorID: String) -> [Step] {
        show(track: Self.track(forFloor: floorID))
    }

    mutating func show(track: String) -> [Step] {
        guard track != lead else { return [] }
        var steps: [Step] = []
        // Volver al piso que se estaba yendo da vuelta el fundido: el tema
        // sigue cargado y sube desde donde haya quedado.
        let returning = tail?.track == track
        if let tail, !returning {
            steps.append(.cut(tail.track))
        }
        tail = nil
        if let lead {
            turns += 1
            let exit = Exit(track: lead, turn: turns)
            tail = exit
            steps.append(.fadeOut(exit))
        }
        steps.append(returning ? .restore(track) : .fadeIn(track))
        lead = track
        return steps
    }

    /// Terminó el fundido de salida `exit`. Devuelve si hay que parar ese
    /// tema: no, si mientras tanto volvió a mandar o ya lo cortó otro cambio.
    mutating func exitFinished(_ exit: Exit) -> Bool {
        guard tail == exit else { return false }
        tail = nil
        return true
    }
}
