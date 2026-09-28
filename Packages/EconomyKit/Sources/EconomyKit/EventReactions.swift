import Foundation

/// Cómo reacciona un personaje del campo cuando cae un evento.
///
/// `indiferente` no es la ausencia de dato: es la respuesta más común, y a
/// propósito. Si los diez personajes del campo reaccionan a todo, es ruido y a
/// los dos eventos nadie lo mira; si reaccionan tres, el ojo va a esos tres y el
/// chiste se lee (`Docs/PROMPT-reacciones-de-campo.md` §2).
public enum Emote: String, Codable, Sendable, CaseIterable {
    case festeja
    case seAgarraLaCabeza = "se_agarra_la_cabeza"
    case seEncogeDeHombros = "se_encoge_de_hombros"
    case sonrisaTorcida = "sonrisa_torcida"
    case seEsconde = "se_esconde"
    case indiferente
}

public enum EventReactionsValidationError: Error, Equatable, CustomStringConvertible {
    /// Un evento de `events.json` sin fila en la tabla.
    case missingEvent(String)
    /// Una fila de la tabla para un evento que ya no existe.
    case unknownEvent(String)
    /// Un tipo de `tiers.json` sin reacción para este evento.
    case missingType(eventId: String, typeId: String)
    /// Una reacción de un tipo que ya no existe.
    case unknownType(eventId: String, typeId: String)

    public var description: String {
        switch self {
        case .missingEvent(let id): "el evento \(id) no tiene reacciones: regenerar la tabla"
        case .unknownEvent(let id): "reacciones de un evento que no existe: \(id)"
        case .missingType(let event, let type): "\(event) no dice cómo reacciona \(type): regenerar la tabla"
        case .unknownType(let event, let type): "\(event) tiene reacción de un tipo que no existe: \(type)"
        }
    }
}

/// La tabla evento × tipo → emote, generada fuera del juego y revisada a mano
/// (`Tools/event-reactions/`). El juego no decide nada: la lee.
public struct EventReactionsConfig: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    /// eventId → typeId → emote.
    public let reactions: [String: [String: Emote]]

    public init(schemaVersion: Int = 1, reactions: [String: [String: Emote]]) {
        self.schemaVersion = schemaVersion
        self.reactions = reactions
    }

    /// Total: lo que la tabla no dice es `indiferente`. En runtime nunca falta
    /// una celda —`validate` corre en el load—, pero un lookup que no puede
    /// fallar no obliga a nadie a decidir qué hacer si falla.
    public func emote(eventId: String, typeId: String) -> Emote {
        reactions[eventId]?[typeId] ?? .indiferente
    }

    /// Cobertura exacta en los dos sentidos. Es el anti-drift de la tabla: un
    /// evento o un tier nuevo sin regenerarla, o una fila huérfana de algo que
    /// se borró, frenan el arranque en vez de callarse. Los ids se recorren
    /// ordenados para que el error sea siempre el mismo.
    public func validate(eventIDs: Set<String>, typeIDs: Set<String>) throws {
        let tableEvents = Set(reactions.keys)
        if let missing = eventIDs.subtracting(tableEvents).sorted().first {
            throw EventReactionsValidationError.missingEvent(missing)
        }
        if let unknown = tableEvents.subtracting(eventIDs).sorted().first {
            throw EventReactionsValidationError.unknownEvent(unknown)
        }
        for eventId in eventIDs.sorted() {
            let rowTypes = Set(reactions[eventId].map { Array($0.keys) } ?? [])
            if let missing = typeIDs.subtracting(rowTypes).sorted().first {
                throw EventReactionsValidationError.missingType(eventId: eventId, typeId: missing)
            }
            if let unknown = rowTypes.subtracting(typeIDs).sorted().first {
                throw EventReactionsValidationError.unknownType(eventId: eventId, typeId: unknown)
            }
        }
    }
}

/// Decide quién reacciona, cuándo, y quién no. Puro: la escena sólo ejecuta.
public enum EventReactionPlanner {
    public struct Reaction: Equatable, Sendable {
        public let slot: Int
        public let emote: Emote
        /// Segundos a esperar antes de arrancar.
        public let delay: TimeInterval
    }

    /// Red de seguridad por si la tabla quedó habladora. La que manda es la
    /// tabla revisada; esto sólo evita que un error de contenido llene el campo.
    public static let defaultCap = 4
    /// Escalonado máximo entre el primero y el último en reaccionar. Sin él,
    /// cuatro personajes arrancando en el mismo frame se leen como coreografía y
    /// no como una multitud enterándose.
    public static let maxStagger: TimeInterval = 0.45

    /// - Parameters:
    ///   - onField: los personajes del piso a la vista, por slot.
    ///   - excluded: slots que otro gesto tiene tomados (el arrastrado, los
    ///     candidatos a fusión, el que ilumina el tutorial).
    public static func plan(
        eventId: String,
        onField: [(slot: Int, typeId: String)],
        excluded: Set<Int>,
        config: EventReactionsConfig,
        cap: Int = defaultCap
    ) -> [Reaction] {
        onField
            .filter { !excluded.contains($0.slot) }
            .sorted { $0.slot < $1.slot }
            .compactMap { unit -> Reaction? in
                let emote = config.emote(eventId: eventId, typeId: unit.typeId)
                guard emote != .indiferente else { return nil }
                return Reaction(slot: unit.slot, emote: emote, delay: stagger(slot: unit.slot))
            }
            .prefix(max(0, cap))
            .map { $0 }
    }

    /// Determinista por slot: el mismo campo reacciona igual cada vez, que es lo
    /// que permite pinearlo en un test y reproducirlo en un screenshot.
    static func stagger(slot: Int) -> TimeInterval {
        var hash = UInt64(bitPattern: Int64(slot)) &+ 0x9E37_79B9_7F4A_7C15
        hash = (hash ^ (hash >> 30)) &* 0xBF58_476D_1CE4_E5B9
        hash = (hash ^ (hash >> 27)) &* 0x94D0_49BB_1331_11EB
        hash ^= hash >> 31
        return Double(hash % 1_000) / 1_000 * maxStagger
    }
}
