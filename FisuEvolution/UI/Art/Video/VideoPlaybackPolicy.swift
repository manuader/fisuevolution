import Foundation
import UIKit

/// Por qué un video se queda en póster. Pura: el observador de abajo la arma con el sistema.
struct VideoPlaybackPolicy: Equatable, Sendable {
    enum Reason: Hashable, Sendable {
        case reduceMotion, lowPower, thermal, background, videoAutoplayOff, forcedStill
    }

    private(set) var reasons: Set<Reason> = []

    static let allowAll = VideoPlaybackPolicy()

    func with(_ reason: Reason) -> VideoPlaybackPolicy {
        var policy = self
        policy.reasons.insert(reason)
        return policy
    }

    func contains(_ reason: Reason) -> Bool { reasons.contains(reason) }

    /// Loops y clips de una vez: cualquier razón los apaga.
    var allowsLoops: Bool { reasons.isEmpty }

    /// La cinemática es un momento del cuento, a pantalla completa y sola: la apagan sólo lo que
    /// pide el jugador (Reduce Motion, sin reproducción automática), el segundo plano y el póster forzado.
    var allowsCinematics: Bool {
        reasons.isDisjoint(with: [.reduceMotion, .videoAutoplayOff, .background, .forcedStill])
    }

    /// La del arranque: `forcedStill` bajo XCTest y bajo `--uitest*` sin `--uitest-video`.
    static var launch: VideoPlaybackPolicy {
        let info = ProcessInfo.processInfo
        return launch(arguments: info.arguments, environment: info.environment,
                      xctestLoaded: NSClassFromString("XCTestCase") != nil)
    }

    static func launch(arguments: [String], environment: [String: String],
                       xctestLoaded: Bool) -> VideoPlaybackPolicy {
        // Spike T10a: StoreKitTest (linkeado débil en DEBUG) carga XCTest, así que `xctestLoaded` da
        // verdadero en toda build Debug lanzada a mano y `--uitest-video` no alcanzaba: lo ignora.
        let underXCTest = (xctestLoaded && !arguments.contains("--uitest-video"))
            || environment["XCTestConfigurationFilePath"] != nil
        let underUITest = arguments.contains { $0.hasPrefix("--uitest") }
            && !arguments.contains("--uitest-video")
        return underXCTest || underUITest ? allowAll.with(.forcedStill) : allowAll
    }
}

/// Lee el sistema y empuja la política al pool: Reduce Motion, reproducción automática de video,
/// Modo de bajo consumo, térmica (`.serious` o peor) y segundo plano. Escucha las notificaciones
/// del sistema, nunca sondea con un `Timer`.
@MainActor
final class VideoPlaybackObserver {
    private var tasks: [Task<Void, Never>] = []
    private var inBackground = false

    func start(pool: VideoPlayerPool) {
        guard tasks.isEmpty else { return }
        inBackground = UIApplication.shared.applicationState == .background
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            UIAccessibility.videoAutoplayStatusDidChangeNotification,
            .NSProcessInfoPowerStateDidChange,
            ProcessInfo.thermalStateDidChangeNotification
        ]
        for name in names {
            tasks.append(Task { [weak self, weak pool] in
                for await _ in center.notifications(named: name).map({ _ in () }) {
                    guard let self, let pool else { return }
                    pool.update(policy: self.currentPolicy())
                }
            })
        }
        let lifecycle: [(Notification.Name, Bool)] = [
            (UIApplication.didEnterBackgroundNotification, true),
            (UIApplication.willEnterForegroundNotification, false)
        ]
        for (name, entersBackground) in lifecycle {
            tasks.append(Task { [weak self, weak pool] in
                for await _ in center.notifications(named: name).map({ _ in () }) {
                    guard let self, let pool else { return }
                    self.inBackground = entersBackground
                    pool.update(policy: self.currentPolicy())
                }
            })
        }
        pool.update(policy: currentPolicy())
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
    }

    private func currentPolicy() -> VideoPlaybackPolicy {
        var policy = VideoPlaybackPolicy.launch
        let info = ProcessInfo.processInfo
        if UIAccessibility.isReduceMotionEnabled { policy = policy.with(.reduceMotion) }
        if !UIAccessibility.isVideoAutoplayEnabled { policy = policy.with(.videoAutoplayOff) }
        if info.isLowPowerModeEnabled { policy = policy.with(.lowPower) }
        if info.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            policy = policy.with(.thermal)
        }
        if inBackground { policy = policy.with(.background) }
        return policy
    }
}
