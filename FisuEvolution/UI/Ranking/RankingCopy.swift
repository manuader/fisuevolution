import Foundation

/// Los textos del ranking que llevan datos. Los números van interpolados desde acá y nunca escritos
/// en el catálogo; el nombre del jugador no pasa por ninguna clave (se dibuja con `Text(verbatim:)`).
enum RankingCopy {
    /// Pasadas las 72 h la duración se da en días y horas.
    private static let daysFromHours = 72

    /// "45 min", "32 h 14 min" y, desde las 72 h, "3 d 4 h". Los segundos sobrantes se descartan.
    static func duration(_ seconds: Int, bundle: Bundle = .main, locale: Locale = .current) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = total % 3600 / 60
        func number(_ value: Int) -> String { value.formatted(.number.locale(locale)) }
        if hours >= daysFromHours {
            return String(
                format: text("ranking.duration.dh", bundle), locale: locale, number(hours / 24), number(hours % 24))
        }
        if hours > 0 {
            return String(format: text("ranking.duration.hm", bundle), locale: locale, number(hours), number(minutes))
        }
        return String(format: text("ranking.duration.m", bundle), locale: locale, number(minutes))
    }

    static func text(_ key: String, _ bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
