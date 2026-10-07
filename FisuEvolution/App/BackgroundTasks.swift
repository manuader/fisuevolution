import UIKit

struct BackgroundTaskToken: Hashable, Sendable {
    let id = UUID()
}

/// `beginBackgroundTask` detrás de un protocolo: guardar al irse pide unos
/// segundos de vida, y los tests verifican que se pidan y se devuelvan.
@MainActor
protocol BackgroundTaskRunning: AnyObject {
    func begin(_ name: String) -> BackgroundTaskToken
    func end(_ token: BackgroundTaskToken)
}

@MainActor
final class UIKitBackgroundTasks: BackgroundTaskRunning {
    private var identifiers: [BackgroundTaskToken: UIBackgroundTaskIdentifier] = [:]

    func begin(_ name: String) -> BackgroundTaskToken {
        let token = BackgroundTaskToken()
        // El handler de expiración lo llama UIKit en main (documentado): regla 3.
        identifiers[token] = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated { self?.end(token) }
        }
        return token
    }

    func end(_ token: BackgroundTaskToken) {
        guard let identifier = identifiers.removeValue(forKey: token) else { return }
        UIApplication.shared.endBackgroundTask(identifier)
    }
}
