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

    /// El texto del gancho, o `nil` si no hay nada que decir. `first` no lleva números.
    static func hook(_ hook: RankingBoardModel.Hook, bundle: Bundle = .main, locale: Locale = .current) -> String? {
        func time(_ seconds: Int) -> String { duration(seconds, bundle: bundle, locale: locale) }
        switch hook {
        case .none: return nil
        case .chase(let mine, let tenth):
            return String(format: text("ranking.hook.chase", bundle), locale: locale, time(mine), time(tenth))
        case .last(let mine, let last):
            return String(format: text("ranking.hook.last", bundle), locale: locale, time(mine), time(last))
        case .first: return text("ranking.hook.first", bundle)
        case .legacy: return text("ranking.hook.legacy", bundle)
        case .unregistered: return text("ranking.hook.unregistered", bundle)
        }
    }

    /// "jugado 28 h 3 min": el tiempo con la app abierta, que sólo se muestra.
    static func played(_ seconds: Int, bundle: Bundle = .main, locale: Locale = .current) -> String {
        String(format: text("ranking.row.played", bundle), locale: locale, duration(seconds, bundle: bundle, locale: locale))
    }

    /// El nombre tal cual lo mandó el jugador; sin nombre, "Anónimo". Nunca pasa por una clave.
    static func displayName(_ name: String?, bundle: Bundle = .main) -> String {
        name ?? text("ranking.anonymous", bundle)
    }

    /// "Actualizado a las 14:05 · sin conexión", en la hora local.
    static func stale(
        fetchedAt: TimeInterval, bundle: Bundle = .main, locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        let time = Date(timeIntervalSince1970: fetchedAt).formatted(style)
        return String(format: text("ranking.stale", bundle), locale: locale, time)
    }

    static func text(_ key: String, _ bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
