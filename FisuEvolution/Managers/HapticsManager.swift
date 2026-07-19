import CoreHaptics
import Foundation
import Observation
import UIKit

/// CoreHaptics con un pattern distinto por evento (skill: feedback háptico
/// diferenciado para merge/compra/error/evolución/rareza). Toggle en Settings
/// (accesibilidad: haptics opcionales). En Simulador es no-op silencioso.
@Observable @MainActor
final class HapticsManager {
    static let defaultsKey = "settings.hapticsEnabled"

    enum Pattern {
        case merge
        case purchase
        case error
        case evolution
        case rarity
    }

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.defaultsKey)
        }
    }

    @ObservationIgnored private var engine: CHHapticEngine?
    @ObservationIgnored private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.defaultsKey) as? Bool ?? true
    }

    func prepare() {
        guard supportsHaptics, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            // Callbacks legacy sin anotar → rebotar a MainActor (convención regla 3).
            engine.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    try? self?.engine?.start()
                }
            }
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
        } catch {
            Log.lifecycle.info("haptics unavailable: \(error.localizedDescription)")
        }
    }

    func play(_ pattern: Pattern) {
        guard isEnabled, supportsHaptics, let engine else { return }
        do {
            let hapticPattern = try makePattern(pattern)
            let player = try engine.makePlayer(with: hapticPattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            Log.lifecycle.debug("haptic play failed: \(error.localizedDescription)")
        }
    }

    private func makePattern(_ pattern: Pattern) throws -> CHHapticPattern {
        func transient(time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ],
                relativeTime: time
            )
        }

        let events: [CHHapticEvent] = switch pattern {
        case .merge:
            [transient(time: 0, intensity: 0.8, sharpness: 0.6)]
        case .purchase:
            [transient(time: 0, intensity: 0.55, sharpness: 0.4),
             transient(time: 0.09, intensity: 0.7, sharpness: 0.5)]
        case .error:
            [CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15),
                ],
                relativeTime: 0,
                duration: 0.25
            )]
        case .evolution:
            [CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                ],
                relativeTime: 0,
                duration: 0.4
            ),
             transient(time: 0.42, intensity: 1.0, sharpness: 1.0)]
        case .rarity:
            [transient(time: 0, intensity: 0.6, sharpness: 0.9),
             transient(time: 0.12, intensity: 0.8, sharpness: 0.9),
             transient(time: 0.24, intensity: 1.0, sharpness: 1.0)]
        }

        return try CHHapticPattern(events: events, parameters: [])
    }
}
