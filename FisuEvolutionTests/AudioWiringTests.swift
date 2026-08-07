import Foundation
import Testing

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
    /// Los diez casos de `AudioManager.SFX`. Van escritos a mano a propósito: el
    /// test tiene que fallar cuando el enum crece y el cableado no.
    private static let declaredCases = [
        "tap", "merge", "evolution", "coin", "buy",
        "error", "rare", "prestige", "event", "daily",
    ]

    private static func gameStateSources() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FisuEvolutionTests
            .deletingLastPathComponent()   // repo
            .appendingPathComponent("FisuEvolution/Game/State")
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        return try files
            .filter { $0.pathExtension == "swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
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

    @Test("los diez SFX declarados tienen al menos un call site")
    func everySFXIsFired() throws {
        let sources = try Self.gameStateSources()
        let fired = Self.playArguments(receiver: "audio", in: sources)
            .reduce(into: Set<String>()) { $0.formUnion(Self.enumCases(in: $1)) }
        let orphans = Self.declaredCases.filter { !fired.contains($0) }
        #expect(orphans.isEmpty, "SFX declarados que no dispara nadie: \(orphans)")
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
