import Foundation

/// Un motivo para volver que el juego avisa con una notificación local (PLAN-v2
/// E11). El `rawValue` es el id de `notifications.json` y arma las claves de
/// texto `notif.<id>.title/.body`.
///
/// Cada épica que suma un motivo agrega su caso, su entrada en el catálogo y sus
/// textos: el validador y `LocalizationCompletenessTests` no dejan olvidar
/// ninguno de los tres.
public enum NotificationKind: String, CaseIterable, Sendable {
    /// La caja fuerte se llenó: el tope offline.
    case vaultFull = "vault_full"
    /// El premio diario está sin cobrar.
    case dailyReady = "daily_ready"
    /// Días sin entrar, una sola vez por ausencia.
    case comeback
    /// La ruleta tiene giros nuevos (E5).
    case wheelReady = "wheel_ready"
}

/// Espejo Codable de `notifications.json`: el catálogo y las reglas del
/// planificador. Todo número de las reglas vive acá y no en Swift.
public struct NotificationsConfig: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public let id: String

        public init(id: String) {
            self.id = id
        }

        public var kind: NotificationKind? { NotificationKind(rawValue: id) }
    }

    /// Lo que cae adentro se corre al final. Cruza la medianoche cuando
    /// `startHour > endHour` (22 → 9).
    public struct QuietHours: Codable, Sendable, Equatable {
        public let startHour: Int
        public let endHour: Int

        public init(startHour: Int, endHour: Int) {
            self.startHour = startHour
            self.endHour = endHour
        }

        public func contains(hour: Int) -> Bool {
            startHour > endHour
                ? hour >= startHour || hour < endHour
                : hour >= startHour && hour < endHour
        }
    }

    /// La tarjeta que pide el permiso completo: cuántas veces se ofrece y cada cuánto.
    public struct PermissionCard: Codable, Sendable, Equatable {
        public let maxOffers: Int
        public let retryAfterHours: Double

        public init(maxOffers: Int, retryAfterHours: Double) {
            self.maxOffers = maxOffers
            self.retryAfterHours = retryAfterHours
        }
    }

    public let schemaVersion: Int
    /// El orden es la prioridad: con más motivos que `maxPerAbsence` se quedan
    /// los primeros. Es también el orden de las filas de Ajustes.
    public let notifications: [Entry]
    public let quietHours: QuietHours
    public let minSpacingHours: Double
    public let maxPerAbsence: Int
    public let dailyReadyHour: Int
    public let comebackAfterHours: Double
    public let permissionCard: PermissionCard

    public init(
        schemaVersion: Int,
        notifications: [Entry],
        quietHours: QuietHours,
        minSpacingHours: Double,
        maxPerAbsence: Int,
        dailyReadyHour: Int,
        comebackAfterHours: Double,
        permissionCard: PermissionCard
    ) {
        self.schemaVersion = schemaVersion
        self.notifications = notifications
        self.quietHours = quietHours
        self.minSpacingHours = minSpacingHours
        self.maxPerAbsence = maxPerAbsence
        self.dailyReadyHour = dailyReadyHour
        self.comebackAfterHours = comebackAfterHours
        self.permissionCard = permissionCard
    }

    public var kinds: [NotificationKind] { notifications.compactMap(\.kind) }

    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case duplicateID(String)
        case unknownID(String)
        case missingKind(NotificationKind)
        case hourOutOfRange(field: String, hour: Int)
        case emptyQuietHours
        case dailyHourIsQuiet(Int)
        case notPositive(field: String)

        public var description: String {
            switch self {
            case .duplicateID(let id): "el id \(id) está dos veces"
            case .unknownID(let id): "el id \(id) no es un NotificationKind"
            case .missingKind(let kind): "falta la entrada de \(kind.rawValue)"
            case .hourOutOfRange(let field, let hour): "\(field) = \(hour) no es una hora (0–23)"
            case .emptyQuietHours: "el horario silencioso empieza y termina a la misma hora"
            case .dailyHourIsQuiet(let hour): "el aviso del diario (\(hour) h) cae en el horario silencioso"
            case .notPositive(let field): "\(field) tiene que ser mayor que cero"
            }
        }
    }

    /// Lo llama `GameContentLoader` al arrancar: un catálogo mal armado es un
    /// aviso que nunca suena, y nadie se entera.
    public func validate() throws {
        var seen = Set<String>()
        for entry in notifications {
            guard seen.insert(entry.id).inserted else { throw ValidationError.duplicateID(entry.id) }
            guard entry.kind != nil else { throw ValidationError.unknownID(entry.id) }
        }
        if let missing = NotificationKind.allCases.first(where: { !seen.contains($0.rawValue) }) {
            throw ValidationError.missingKind(missing)
        }
        let hours = [
            ("quietHours.startHour", quietHours.startHour),
            ("quietHours.endHour", quietHours.endHour),
            ("dailyReadyHour", dailyReadyHour),
        ]
        if let bad = hours.first(where: { !(0...23).contains($0.1) }) {
            throw ValidationError.hourOutOfRange(field: bad.0, hour: bad.1)
        }
        guard quietHours.startHour != quietHours.endHour else { throw ValidationError.emptyQuietHours }
        guard !quietHours.contains(hour: dailyReadyHour) else {
            throw ValidationError.dailyHourIsQuiet(dailyReadyHour)
        }
        let amounts = [
            ("minSpacingHours", minSpacingHours),
            ("maxPerAbsence", Double(maxPerAbsence)),
            ("comebackAfterHours", comebackAfterHours),
            ("permissionCard.maxOffers", Double(permissionCard.maxOffers)),
            ("permissionCard.retryAfterHours", permissionCard.retryAfterHours),
        ]
        if let bad = amounts.first(where: { $0.1 <= 0 }) {
            throw ValidationError.notPositive(field: bad.0)
        }
    }
}
