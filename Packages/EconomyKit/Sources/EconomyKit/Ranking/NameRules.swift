import Foundation

/// La regla del nombre del ranking. Pura y sin regex: la misma que aplica el servidor
/// (`name_rules.ts`), y las dos leen la tabla `supabase/tests/fixtures/name_rules_cases.json`.
///
/// Sólo se permiten escalares precompuestos, así que un escalar es un grafema y el conteo
/// coincide en Swift (`count`) y en JS (`[...s].length`).
public enum NameRules {
    public static let maxLength = 15

    public enum Rejection: String, Error, Sendable {
        case empty
        case tooLong = "too_long"
        case forbidden
    }

    /// Normaliza y valida. El orden importa: NFC, prohibidos (antes que el largo), espacios, vacío, largo.
    public static func validate(_ raw: String) -> Result<String, Rejection> {
        let composed = raw.precomposedStringWithCanonicalMapping
        guard composed.unicodeScalars.allSatisfy(isAllowed) else { return .failure(.forbidden) }
        let name = collapseSpaces(composed).trimmingSpaces()
        guard !name.isEmpty else { return .failure(.empty) }
        guard name.unicodeScalars.count <= maxLength else { return .failure(.tooLong) }
        return .success(name)
    }

    /// Lo que deja escribir el campo: NFC, sin prohibidos, sin espacios dobles y cortado en 15.
    /// No recorta los bordes: el jugador puede estar por escribir la segunda palabra.
    public static func filterTyping(_ raw: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: raw.precomposedStringWithCanonicalMapping.unicodeScalars.filter(isAllowed))
        let collapsed = collapseSpaces(String(scalars))
        var limited = String.UnicodeScalarView()
        limited.append(contentsOf: collapsed.unicodeScalars.prefix(maxLength))
        return String(limited)
    }

    public static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: true   // 0-9, A-Z, a-z (sólo ASCII)
        case 0x20, 0x2E, 0x2D, 0x5F: true                  // espacio . - _
        case 0xC0...0xD6, 0xD8...0xF6, 0xF8...0x24F: true  // Latin-1, Extended-A y -B (sin × ni ÷)
        case 0x1E00...0x1EFF: true                         // Latin Extended Additional
        default: false
        }
    }

    private static func collapseSpaces(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        var previousSpace = false
        for scalar in s.unicodeScalars {
            let isSpace = scalar == " "
            if isSpace && previousSpace { continue }
            out.append(scalar)
            previousSpace = isSpace
        }
        return String(out)
    }
}

private extension String {
    func trimmingSpaces() -> String { trimmingCharacters(in: CharacterSet(charactersIn: " ")) }
}
