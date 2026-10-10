import Foundation
import Testing
@testable import FisuEvolution

/// `sfx_error` venía en el bundle desde el primer día y no lo disparaba ningún
/// call site: cinco acciones —contratar sin plata, mergear a un piso lleno,
/// comprar un pasivo, una mejora de personaje y una de ORO— vibraban y no
/// sonaban. Este test es el que impide que vuelva a pasar: si alguien agrega un
/// caso al enum y no lo cablea, falla acá y no en una queja de playtest.
///
/// ⚠️ **Cómo cuenta, y por qué así.** Parsea el ARGUMENTO de cada
/// `audio?.play(...)` hasta su paréntesis de cierre, en vez de buscar el nombre
/// pegado al paréntesis. La primera versión de este test buscaba
/// `"audio?.play(.tap)"` literal y daba cuatro huérfanos falsos: `.tap`,
/// `.coin`, `.merge` y `.evolution` ya estaban cableados desde F5 dentro de
/// ternarios —`audio?.play(isCrit || isGolden ? .coin : .tap)`—, que esa
/// búsqueda no encuentra.
@Suite struct AudioWiringTests {
    /// Los casos de `AudioManager.SFX`. Van escritos a mano a propósito: el
    /// test tiene que fallar cuando el enum crece y el cableado no.
    private static let declaredCases = [
        "tap", "merge", "evolution", "coin", "buy",
        "error", "rare", "prestige", "daily",
        "chestShakeA", "chestShakeB", "revealWhoosh",
        "mergeAllDone", "wheelTick",
    ]

    /// Los efectos sintetizados que todavía no tienen call site, con la tarea
    /// que los cablea. Al cablearse, la tarea mueve el caso a `declaredCases`.
    private static let pendingWiring: [String: String] = [
        "packageRattle": "E5b T3", "packageTapeRip": "E5b T3", "packageBurst": "E5b T3",
        "mattressSqueak": "E5b T2", "mattressRip": "E5b T2", "cashBurst": "E5b T2",
        "visitorArrive": "E4b T3", "talkBlip": "E4b T3",
        "shopShimmer": "E6a T8",
    ]

    /// Los acentos de evento suenan por `AudioManager.accent(forEvent:)`, cuyo
    /// resultado el parser no ve como caso: cubierto = el mapa los devuelve y
    /// `GameState+Bonus` dispara el acento (ver `eventAccentsAreFired`). `event`
    /// queda como el de un evento sin acento propio.
    private static let eventAccents = [
        "event",
        "eventPlanPlatita", "eventStartup", "eventDevaluacion", "eventBlanqueo",
        "eventMercadoPago", "eventAlien", "eventCorralito", "eventAguinaldo",
    ]

    /// Los del ascensor suenan desde `UI/HUD` y `UI/Elevator` (E13b), no desde
    /// una acción de `GameState`.
    private static let elevatorCases = [
        "elevatorDing", "elevatorSpring", "elevatorClick", "elevatorDoors", "elevatorMotor", "elevatorCable",
    ]

    /// Las acciones de `GameState` más los popups: las sacudidas del cofre
    /// suenan desde la coreografía de `ChestOpeningView`, no desde una acción.
    private static func gameStateSources() throws -> String {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FisuEvolutionTests
            .deletingLastPathComponent()   // repo
        var sources: [String] = []
        for folder in ["FisuEvolution/Game/State", "FisuEvolution/UI/Popups"] {
            let root = repo.appendingPathComponent(folder)
            let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            sources += try files
                .filter { $0.pathExtension == "swift" }
                .map { try String(contentsOf: $0, encoding: .utf8) }
        }
        return sources.joined(separator: "\n")
    }

    /// El texto de cada argumento de `<receiver>?.play(...)`, balanceando
    /// paréntesis para que un ternario entre entero.
    private static func playArguments(receiver: String, in sources: String) -> [String] {
        let needle = "\(receiver)?.play("
        var arguments: [String] = []
        var cursor = sources.startIndex
        while let call = sources.range(of: needle, range: cursor..<sources.endIndex) {
            var depth = 1
            var index = call.upperBound
            var argument = ""
            while index < sources.endIndex {
                let character = sources[index]
                if character == "(" {
                    depth += 1
                } else if character == ")" {
                    depth -= 1
                    if depth == 0 { break }
                }
                argument.append(character)
                index = sources.index(after: index)
            }
            arguments.append(argument)
            cursor = index < sources.endIndex ? sources.index(after: index) : sources.endIndex
        }
        return arguments
    }

    /// Los casos de enum que menciona un argumento. Un `.foo` sólo cuenta si no
    /// viene pegado a un identificador, para no confundirlo con `player.meta`.
    private static func enumCases(in argument: String) -> Set<String> {
        var found: Set<String> = []
        let characters = Array(argument)
        var index = 0
        while index < characters.count {
            guard characters[index] == "." else {
                index += 1
                continue
            }
            let previous = index > 0 ? characters[index - 1] : " "
            let isMemberAccess = previous.isLetter || previous.isNumber
                || previous == "_" || previous == ")" || previous == "]"
            guard !isMemberAccess else {
                index += 1
                continue
            }
            var end = index + 1
            var name = ""
            while end < characters.count,
                  characters[end].isLetter || characters[end].isNumber || characters[end] == "_" {
                name.append(characters[end])
                end += 1
            }
            if !name.isEmpty { found.insert(name) }
            index = max(end, index + 1)
        }
        return found
    }

    @Test("los SFX declarados tienen al menos un call site")
    func everySFXIsFired() throws {
        let sources = try Self.gameStateSources()
        let fired = Self.playArguments(receiver: "audio", in: sources)
            .reduce(into: Set<String>()) { $0.formUnion(Self.enumCases(in: $1)) }
        let orphans = Self.declaredCases.filter { !fired.contains($0) }
        #expect(orphans.isEmpty, "SFX declarados que no dispara nadie: \(orphans)")
    }

    @Test("todo SFX está cableado o tiene dueño")
    func everySFXIsWiredOrOwned() {
        let known = Set(Self.declaredCases)
            .union(Self.pendingWiring.keys)
            .union(Self.elevatorCases)
            .union(Self.eventAccents)
        let cases = AudioManager.SFX.allCases.map { "\($0)" }
        let unowned = cases.filter { !known.contains($0) }
        #expect(unowned.isEmpty, "SFX sin cablear y sin dueño: \(unowned)")
        let ghosts = known.filter { !cases.contains($0) }
        #expect(ghosts.isEmpty, "casos declarados que ya no existen: \(ghosts)")
    }

    @Test("el evento que cae dispara su acento")
    func eventAccentsAreFired() throws {
        let sources = try Self.gameStateSources()
        let arguments = Self.playArguments(receiver: "audio", in: sources)
        #expect(arguments.contains { $0.contains("AudioManager.accent(forEvent:") })
        let ids = try Self.eventIds() + ["sin_acento"]
        let mapped = Set(ids.map { "\(AudioManager.accent(forEvent: $0))" })
        #expect(Set(Self.eventAccents).isSubset(of: mapped), "acentos sin evento que los pida")
    }

    private static func eventIds() throws -> [String] {
        try GameContentLoader.load(from: .main).events.events.map(\.id)
    }

    @Test("el parser cuenta un ternario como cableado, no como huérfano")
    func ternariesCountAsWired() {
        let sample = "audio?.play(isCrit || isGolden ? .coin : .tap)\nplayer.meta.oro += 1"
        let arguments = Self.playArguments(receiver: "audio", in: sample)
        #expect(arguments == ["isCrit || isGolden ? .coin : .tap"])
        // `meta` y `oro` son accesos a miembro: no son casos del enum.
        #expect(Self.enumCases(in: arguments[0]) == ["coin", "tap"])
    }

    @Test("ninguna acción vibra sin sonar")
    func hapticsAndAudioAgree() throws {
        let sources = try Self.gameStateSources()
        let hapticErrors = Self.playArguments(receiver: "haptics", in: sources)
            .filter { Self.enumCases(in: $0).contains("error") }
            .count
        let audioErrors = Self.playArguments(receiver: "audio", in: sources)
            .filter { Self.enumCases(in: $0).contains("error") }
            .count
        #expect(
            hapticErrors == audioErrors,
            "\(hapticErrors) hápticas de error contra \(audioErrors) sonidos"
        )
    }
}
