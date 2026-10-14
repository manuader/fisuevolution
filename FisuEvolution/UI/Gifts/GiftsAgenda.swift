import Foundation

/// El orden de Regalos por estado (E14 C29): lo que se puede cobrar ya arriba,
/// lo que corre con reloj después y lo que todavía no se puede al final. Es
/// una cuenta pura sobre las proyecciones que la pantalla ya lee, para poder
/// probarla sin dibujar nada.
///
/// Dentro de «listo» manda el valor: cofre sin abrir, giros de la Ruleta,
/// boosts y por último los videos. «Pronto» va del reloj más corto al más
/// largo.
struct GiftsAgenda: Equatable {
    enum Entry: Identifiable, Equatable {
        case chest(count: Int)
        case wheel(WheelAvailability, readyIn: TimeInterval?)
        case boost(GameState.BoostRow)
        case video(GameState.RewardRow)

        var id: String {
            switch self {
            case .chest: "chest"
            case .wheel: "wheel"
            case .boost(let row): row.id
            case .video(let row): row.id
            }
        }

        /// Cuánto falta para que se pueda cobrar, si corre con reloj.
        var waitSeconds: TimeInterval? {
            switch self {
            case .chest: nil
            case .wheel(_, let readyIn): readyIn
            case .boost(let row): row.cooldownRemaining
            case .video(let row): row.cooldownRemaining
            }
        }
    }

    /// Lo que se cobra ya, el más valioso primero.
    let ready: [Entry]
    /// Lo que corre con reloj, el que antes vuelve primero.
    let soon: [Entry]
    /// Lo que todavía no se puede y no tiene reloj: un piso por subir, un
    /// video que hoy no se ofrece.
    let later: [Entry]

    /// La tarjeta grande de arriba.
    var hero: Entry? { ready.first }
    /// El resto de lo listo, en filas.
    var rest: [Entry] { Array(ready.dropFirst()) }

    init(
        chests: Int, canOpenChest: Bool,
        wheel: WheelAvailability, wheelReadyIn: TimeInterval?,
        boosts: [GameState.BoostRow], videos: [GameState.RewardRow]
    ) {
        var ready: [Entry] = []
        var waiting: [Entry] = []
        var later: [Entry] = []

        if chests > 0 {
            if canOpenChest { ready.append(.chest(count: chests)) } else { later.append(.chest(count: chests)) }
        }

        let wheelEntry = Entry.wheel(wheel, readyIn: wheelReadyIn)
        if wheel.hasFreeSpin {
            ready.append(wheelEntry)
        } else if wheelReadyIn != nil {
            waiting.append(wheelEntry)
        } else {
            later.append(wheelEntry)
        }

        var readyVideos: [Entry] = []
        for row in boosts {
            if !row.isUnlocked {
                later.append(.boost(row))
            } else if row.cooldownRemaining > 0 {
                waiting.append(.boost(row))
            } else {
                ready.append(.boost(row))
            }
        }
        for row in videos {
            if row.cooldownRemaining > 0 {
                waiting.append(.video(row))
            } else if row.unavailableReason != nil {
                later.append(.video(row))
            } else {
                readyVideos.append(.video(row))
            }
        }

        self.ready = ready + readyVideos
        self.soon = waiting.enumerated()
            .sorted { ($0.element.waitSeconds ?? .infinity, $0.offset) < ($1.element.waitSeconds ?? .infinity, $1.offset) }
            .map(\.element)
        self.later = later
    }
}
