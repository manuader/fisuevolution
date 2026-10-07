import EconomyKit

/// Las claves de texto de cada motivo de notificación (PLAN-v2 E11), armadas en
/// un solo lugar: el manager las usa para el aviso, Ajustes para su fila y
/// `LocalizationCompletenessTests` para exigir es + en en todas.
extension NotificationKind {
    var titleKey: String { "notif.\(rawValue).title" }
    var bodyKey: String { "notif.\(rawValue).body" }
    /// El identifier de la fila de Ajustes, que es también la clave de su título.
    var settingsKey: String { "settings.notifications.\(rawValue)" }
}
