import Foundation

/// Cuándo aparece una pestaña de la barra (PLAN-v2 E3). Basta con una de sus
/// condiciones.
enum TabUnlockCondition: String, Codable, Sendable {
    case always
    /// Terminó la fase obligatoria del tutorial.
    case tutorialCore
    /// Tiene al menos una pinta.
    case firstSkin
    /// Recibió al menos un cofre.
    case firstChest
    /// Volvió a abrir el juego después de la sesión del tutorial.
    case secondSession
}

/// Lo que el jugador hizo, resuelto por `GameState+Tabs` desde el save y las
/// banderas del tutorial.
struct TabUnlockSignals: Equatable, Sendable {
    var tutorialCoreDone: Bool
    var ownsAnySkin: Bool
    var hasReceivedChest: Bool
    /// Arranques con la fase obligatoria ya hecha (`tutorial.sessionsAfterPhase`).
    var sessionsAfterCore: Int
}

/// `tabs.json`: qué abre cada pestaña.
struct TabsConfig: Codable, Sendable, Equatable {
    struct Tab: Codable, Sendable, Equatable {
        let id: String
        let unlockWhen: [TabUnlockCondition]

        var screen: GameScreen? { GameScreen(rawValue: id) }
    }

    let schemaVersion: Int
    let tabs: [Tab]

    /// Cada pestaña exactamente una vez, cada una con al menos una condición, y
    /// Contratar siempre abierta: sin ella no hay juego.
    func validate() throws {
        let screens = tabs.compactMap(\.screen)
        guard screens.count == tabs.count, Set(screens) == Set(GameScreen.barOrder),
              screens.count == GameScreen.barOrder.count else {
            throw GameError.contentInvalid(file: "tabs.json", reason: "tiene que nombrar las cinco pestañas de la barra una vez")
        }
        if let empty = tabs.first(where: { $0.unlockWhen.isEmpty }) {
            throw GameError.contentInvalid(file: "tabs.json", reason: "\(empty.id) no tiene condición")
        }
        guard tabs.first(where: { $0.screen == GameScreen.centerTab })?.unlockWhen.contains(.always) == true else {
            throw GameError.contentInvalid(file: "tabs.json", reason: "Contratar tiene que estar siempre abierta")
        }
    }

    /// Las que abren desde el arranque: esas nunca llevan "¡Nuevo!".
    var alwaysOpen: Set<GameScreen> {
        Set(tabs.filter { $0.unlockWhen.contains(.always) }.compactMap(\.screen))
    }
}

enum TabUnlockRules {
    static func unlocked(config: TabsConfig, signals: TabUnlockSignals) -> Set<GameScreen> {
        Set(config.tabs.filter { $0.unlockWhen.contains { isMet($0, signals) } }.compactMap(\.screen))
    }

    static func isMet(_ condition: TabUnlockCondition, _ signals: TabUnlockSignals) -> Bool {
        switch condition {
        case .always: true
        case .tutorialCore: signals.tutorialCoreDone
        case .firstSkin: signals.ownsAnySkin
        case .firstChest: signals.hasReceivedChest
        case .secondSession: signals.sessionsAfterCore >= 1
        }
    }
}
