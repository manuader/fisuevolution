import Foundation
import Observation

/// El estado de UN botón de "mirá un video" (PLAN-v2 E13 ítem 1): lo que hace
/// que responda al primer toque y que tres toques sean un solo video.
///
/// Vive aparte de la vista para poder probarse con un proveedor guionado: la
/// regla "un solo `Task` vivo por botón" es lógica, no pintura.
///
/// - `idle`: el botón ofrece el video.
/// - `busy`: desde el primer toque y hasta que el video termine —cargando o ya
///   en pantalla—. Los toques siguientes se ignoran.
/// - `unavailable`: no hubo inventario a tiempo (el proveedor espera hasta 8 s).
///   La UI dice "No hay videos ahora, probá en un rato" un rato y vuelve a
///   `idle`; el botón sigue tappable por si el jugador quiere reintentar.
///
/// ⚠️ El premio se entrega SÓLO en `onRewarded`, o sea cuando el video pagó. Un
/// aviso de "no hay videos" o un video cerrado a la mitad no gastan nada: el
/// enfriamiento lo cobra quien entrega el premio.
@Observable @MainActor
final class RewardedOffer {
    enum Phase: Equatable, Sendable {
        case idle
        case busy
        case unavailable
    }

    private(set) var phase: Phase = .idle

    @ObservationIgnored private let messageDuration: Duration
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var fade: Task<Void, Never>?

    init(messageDuration: Duration = .seconds(4)) {
        self.messageDuration = messageDuration
    }

    /// Arranca el video. `false` si ya había uno vivo: el toque se ignora.
    @discardableResult
    func tap(
        ads: any AdsProvider,
        placement: RewardedPlacement,
        onRewarded: @escaping () -> Void
    ) -> Bool {
        guard task == nil else { return false }
        fade?.cancel()
        phase = .busy
        task = Task {
            let earned = await ads.showRewarded(for: placement)
            let presented = ads.lastRewardedPresented
            task = nil
            if earned {
                phase = .idle
                onRewarded()
            } else if presented {
                // Lo cerró a la mitad: se presentó y no pagó. No hay nada que
                // avisar, el jugador estaba mirando.
                phase = .idle
            } else {
                showUnavailable()
            }
        }
        return true
    }

    /// Espera a que termine el video en curso (los tests).
    func settle() async {
        await task?.value
    }

    private func showUnavailable() {
        phase = .unavailable
        fade = Task {
            try? await Task.sleep(for: messageDuration)
            guard !Task.isCancelled, phase == .unavailable else { return }
            phase = .idle
        }
    }
}
