import Foundation
import Testing
@testable import FisuEvolution

/// Ningún texto visible vive fuera del catálogo (PLAN-v2 E14b B16, punto 4).
///
/// Lee las FUENTES con `#filePath`, como `SheetPresentationGuardTests`, y revisa
/// las llamadas que dibujan o dicen un texto:
/// - **Las que localizan** (`Text("…")`, `Label`, `Button`, `Toggle`, `GameButton`,
///   `PopupContainer`, `.navigationTitle`, `.accessibilityLabel`/`Hint`,
///   `LocalizedStringKey("…")`, `String(localized: "…")`, `localized("…")` y los
///   argumentos `titleKey:`/`messageKey:`/…): el literal tiene que ser una clave
///   del catálogo. Un castellano escrito a mano ahí es el bug: en inglés se ve en
///   castellano. Los literales sin una sola letra (números, signos, emojis) no son
///   texto y pasan.
/// - **Las que NO localizan** (`Text(verbatim: "…")`): no puede llevar una palabra.
///   Los nombres propios de la marca están en `brandWords`.
///
/// Lo que no se revisa, a conciencia: el panel de debug y la galería de
/// componentes (sólo DEBUG), todo lo que está adentro de un `#if DEBUG` o de un
/// `#Preview`, y los comentarios.
///
/// ⚠️ Un componente nuevo cuyo primer argumento es una clave (`LocalizedStringKey`)
/// se suma a `keyedCalls`; si no, sus literales no se miran.
@Suite("Ningún texto visible fuera del catálogo")
struct VisibleLiteralsGuardTests {
    private static let appSources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "FisuEvolution")

    /// Sólo DEBUG: no llegan a un jugador.
    private static let debugOnlyFiles: Set<String> = ["DebugPanelView.swift", "ComponentGallery.swift"]

    /// Nombres propios de la marca que se dibujan sin traducir.
    private static let brandWords: Set<String> = ["Fisu", "Jobs", "FisuJobs", "FISU", "EVOLUTION", "FISU EVOLUTION"]

    /// Ocupa el lugar de cada `\(…)` de un literal y de cada `%@`/`%lld` de una clave.
    private static let marker: Character = "\u{1}"

    private static let placeholderPattern = #"%(\d+\$)?[-+#0]*\d*(?:\.\d+)?(?:lld|llu|ld|lu|lf|d|i|u|f|@)"#

    private static let keyedCalls = [
        #"(?:\b(?:Text|Label|Button|Toggle|Picker|Section|Menu|Link|TextField|GameButton|PopupContainer|SectionHeader|LocalizedStringKey)|\.navigationTitle|\.accessibilityLabel|\.accessibilityHint)\(\s*""#,
        #"(?:String\(localized:|\blocalized\()\s*""#,
        #"\b(?:titleKey|messageKey|labelKey|hintKey|confirmTitleKey|cancelTitleKey|statusKey|stateKey|errorKey|textKey|bodyKey|subtitleKey):\s*""#,
    ]

    private static let verbatimCall = #"\bText\(verbatim:\s*""#

    // MARK: - Los tres tests

    @Test("todo texto que se localiza es una clave del catálogo")
    func everyLocalizedLiteralIsACatalogKey() throws {
        let keys = try Self.normalizedKeys()
        var found: [String] = []
        for (file, source) in try Self.sources() {
            for hit in try Self.occurrences(inSource: source) where hit.localizes && Self.isUnlocalized(hit.literal, keys: keys) {
                found.append("\(file):\(hit.line): \(Self.shown(hit.literal))")
            }
        }
        #expect(found.isEmpty, "\(found.count) textos visibles fuera del catálogo (pasalos a una clave con es y en):\n\(found.joined(separator: "\n"))")
    }

    @Test("ningún Text(verbatim:) lleva una palabra: sólo números, signos y la marca")
    func verbatimTextCarriesNoWords() throws {
        var found: [String] = []
        for (file, source) in try Self.sources() {
            for hit in try Self.occurrences(inSource: source) where !hit.localizes && Self.hasWord(hit.literal) && !Self.brandWords.contains(hit.literal) {
                found.append("\(file):\(hit.line): \(Self.shown(hit.literal))")
            }
        }
        #expect(found.isEmpty, "\(found.count) palabras sin traducir en Text(verbatim:) (clave nueva, o a brandWords si es la marca):\n\(found.joined(separator: "\n"))")
    }

    @Test("cada clave en uso está traducida a es y en, con los mismos placeholders")
    func everyKeyInUseIsTranslated() throws {
        let catalog = try LocalizationCompletenessTests.catalog("Localizable")
        let originalsByShape = Dictionary(grouping: catalog.strings.keys) { Self.normalized($0) }
        var problems: [String] = []
        for (file, source) in try Self.sources() {
            for hit in try Self.occurrences(inSource: source) where hit.localizes {
                for key in originalsByShape[hit.literal] ?? [] {
                    problems += LocalizationCompletenessTests.problems(of: key, in: catalog).map { "\(file):\(hit.line): \($0)" }
                }
            }
        }
        #expect(problems.isEmpty, "\(problems.count) problemas:\n\(problems.joined(separator: "\n"))")
    }

    @Test("el lector marca un castellano a mano y deja pasar claves, números y comentarios")
    func scannerFlagsWhatItShould() throws {
        let keys: Set<String> = ["gifts.title", "jobs.step \(Self.marker)", "siderail.toggle.ax"]
        let source = """
        struct Demo: View {
            var body: some View {
                Text("gifts.title")
                Text("Hola, jefe")
                Text("jobs.step \\(percent)")
                Text("\\(count)")
                Text("12 %")
                Text(verbatim: "Cerrar")
                Text(verbatim: "×\\(count)")
                Text(verbatim: "Fisu")
                // Text("Esto es un comentario")
                Button("Comprar") {}
                GameButton("Aceptar", role: .free) {}
                let a = String(localized: "gifts.title")
                .accessibilityLabel(Text("siderail.\\(kind).ax"))
            }
        }
        #if DEBUG
        Text("Sólo en debug")
        #endif
        #Preview { Text("Una vista previa") }
        """
        let hits = try Self.occurrences(inSource: source)
        let unlocalized = hits.filter { $0.localizes && Self.isUnlocalized($0.literal, keys: keys) }.map(\.literal)
        #expect(unlocalized == ["Hola, jefe", "Comprar", "Aceptar"], "\(unlocalized)")
        let words = hits.filter { !$0.localizes && Self.hasWord($0.literal) && !Self.brandWords.contains($0.literal) }.map(\.literal)
        #expect(words == ["Cerrar"], "\(words)")
    }

    // MARK: - El lector

    struct Occurrence {
        let line: Int
        /// El contenido del literal, con cada interpolación reemplazada por `marker`.
        let literal: String
        /// `true` si la llamada localiza; `false` para `Text(verbatim:)`.
        let localizes: Bool
    }

    /// Las fuentes del juego que le tocan al guardia, por nombre de archivo.
    private static func sources() throws -> [(String, String)] {
        var result: [(String, String)] = []
        let files = FileManager.default.enumerator(at: appSources, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift", !debugOnlyFiles.contains(url.lastPathComponent) else { continue }
            result.append((url.lastPathComponent, try String(contentsOf: url, encoding: .utf8)))
        }
        return result.sorted { $0.0 < $1.0 }
    }

    /// Todos los literales que están en las llamadas que importan, fuera de DEBUG,
    /// de las vistas previas y de los comentarios.
    static func occurrences(inSource text: String) throws -> [Occurrence] {
        let keyedRules = try keyedCalls.map { try Regex($0) }
        let verbatimRule = try Regex(verbatimCall)
        var hits: [Occurrence] = []
        var debugDepth = 0
        var inPreview = false
        for (index, raw) in text.components(separatedBy: "\n").enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if DEBUG") { debugDepth += 1; continue }
            if trimmed.hasPrefix("#if") {
                if debugDepth > 0 { debugDepth += 1 }
                continue
            }
            if trimmed.hasPrefix("#else"), debugDepth == 1 { debugDepth = 0; continue }
            if trimmed.hasPrefix("#endif") {
                if debugDepth > 0 { debugDepth -= 1 }
                continue
            }
            if debugDepth > 0 { continue }
            if trimmed.hasPrefix("#Preview") {
                // Una vista previa de una línea abre y cierra en la misma.
                inPreview = raw.filter { $0 == "{" }.count != raw.filter { $0 == "}" }.count
                continue
            }
            if inPreview {
                if raw.hasPrefix("}") { inPreview = false }
                continue
            }
            let line = strippingComment(raw)
            let chars = Array(line)
            for (rules, localizes) in [(keyedRules, true), ([verbatimRule], false)] {
                for rule in rules {
                    for range in line.ranges(of: rule) {
                        let quote = line.distance(from: line.startIndex, to: range.upperBound) - 1
                        hits.append(Occurrence(line: index + 1, literal: readLiteral(chars, from: quote).text, localizes: localizes))
                    }
                }
            }
        }
        return hits
    }

    /// El literal que abre en `start` (`chars[start]` es la comilla), con cada
    /// `\(…)` —y los literales anidados que lleve adentro— reemplazado por `marker`.
    private static func readLiteral(_ chars: [Character], from start: Int) -> (text: String, end: Int) {
        var index = start + 1
        var text = ""
        while index < chars.count {
            let char = chars[index]
            if char == "\\", index + 1 < chars.count {
                if chars[index + 1] == "(" {
                    var depth = 1
                    index += 2
                    while index < chars.count, depth > 0 {
                        if chars[index] == "\"" {
                            index = readLiteral(chars, from: index).end
                            continue
                        }
                        if chars[index] == "(" { depth += 1 } else if chars[index] == ")" { depth -= 1 }
                        index += 1
                    }
                    text.append(marker)
                    continue
                }
                text.append(char)
                text.append(chars[index + 1])
                index += 2
                continue
            }
            if char == "\"" { return (text, index + 1) }
            text.append(char)
            index += 1
        }
        return (text, index)
    }

    /// La línea sin su comentario final (un `//` adentro de un literal no cuenta).
    private static func strippingComment(_ line: String) -> String {
        let chars = Array(line)
        var inString = false
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if inString {
                if char == "\\" {
                    index += 2
                    continue
                }
                if char == "\"" { inString = false }
            } else if char == "\"" {
                inString = true
            } else if char == "/", index + 1 < chars.count, chars[index + 1] == "/" {
                return String(chars[..<index])
            }
            index += 1
        }
        return line
    }

    // MARK: - El catálogo

    /// Una clave con sus `%@`/`%lld` reemplazados por `marker`: así se compara con un literal interpolado.
    static func normalized(_ key: String) -> String {
        guard let placeholder = try? Regex(placeholderPattern) else { return key }
        return key.replacing(placeholder, with: String(marker))
    }

    private static func normalizedKeys() throws -> Set<String> {
        let catalog = try LocalizationCompletenessTests.catalog("Localizable")
        return Set(catalog.strings.keys.map { normalized($0) })
    }

    /// `true` si el literal es texto (tiene una letra) y no es una clave. Una clave
    /// armada en runtime (`siderail.\(kind).ax`) pasa si alguna del catálogo encaja.
    static func isUnlocalized(_ literal: String, keys: Set<String>) -> Bool {
        guard literal.contains(where: \.isLetter) else { return false }
        if keys.contains(literal) { return false }
        guard literal.contains(marker) else { return true }
        let pieces = literal.split(separator: marker, omittingEmptySubsequences: false).map { escaped(String($0)) }
        guard let shape = try? Regex(pieces.joined(separator: "[^ ]+")) else { return true }
        return !keys.contains { $0.wholeMatch(of: shape) != nil }
    }

    private static func escaped(_ piece: String) -> String {
        piece.map { $0.isLetter || $0.isNumber || $0 == "_" || $0 == " " ? String($0) : "\\\($0)" }.joined()
    }

    /// El literal como se lee en la fuente, para el mensaje del test.
    private static func shown(_ literal: String) -> String {
        let readable = literal.replacingOccurrences(of: String(marker), with: "(…)")
        return "«" + readable + "»"
    }

    /// `true` si el texto trae una palabra: dos letras seguidas.
    static func hasWord(_ text: String) -> Bool {
        var run = 0
        for char in text {
            run = char.isLetter ? run + 1 : 0
            if run >= 2 { return true }
        }
        return false
    }
}
