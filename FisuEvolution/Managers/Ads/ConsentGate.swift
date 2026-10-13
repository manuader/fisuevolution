import Foundation

/// La señal entre el consentimiento (UMP → ATT) y la intro de una partida nueva.
///
/// La intro espera a que el flujo de permisos termine para que ningún diálogo caiga encima del
/// video. El tope existe para la red colgada, no para cortarle la lectura al jugador: corre sólo
/// mientras NO hay un diálogo en pantalla (`dialogAppeared`). Vencido el tope —o si no hace falta
/// esperar (`skipWaiting`)— la intro sigue sin el consentimiento, que desde ahí cede el paso a los
/// momentos tranquilos (`mustYieldToCalm`).
@MainActor
final class ConsentGate {
    enum Outcome: Equatable {
        case resolved
        case gaveUp
    }

    static let defaultCap: Duration = .seconds(10)
    static let defaultTick: Duration = .milliseconds(100)

    private(set) var isResolved = false
    private(set) var isDialogOnScreen = false
    /// La intro ya no espera: el consentimiento que siga tiene que esperar un momento tranquilo.
    private(set) var mustYieldToCalm = false

    private let cap: Duration
    private let tick: Duration
    private let sleep: @MainActor (Duration) async -> Void

    init(
        cap: Duration = ConsentGate.defaultCap,
        tick: Duration = ConsentGate.defaultTick,
        sleep: @escaping @MainActor (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.cap = cap
        self.tick = tick
        self.sleep = sleep
    }

    func dialogAppeared() { isDialogOnScreen = true }

    func dialogDismissed() { isDialogOnScreen = false }

    func resolve() {
        isResolved = true
        isDialogOnScreen = false
    }

    /// Quien ya respondió (o no tiene qué responder) no hace esperar a la intro.
    func skipWaiting() {
        if !isResolved { mustYieldToCalm = true }
    }

    /// Vuelve cuando el consentimiento terminó, o cuando el tope vence sin ningún diálogo en
    /// pantalla. El tiempo se cuenta en pasos de `tick` para que los tests lo inyecten sin esperar.
    func wait() async -> Outcome {
        var elapsed = Duration.zero
        while !isResolved, !Task.isCancelled {
            if mustYieldToCalm { return .gaveUp }
            if !isDialogOnScreen {
                if elapsed >= cap {
                    mustYieldToCalm = true
                    return .gaveUp
                }
                elapsed += tick
            }
            await sleep(tick)
        }
        return isResolved ? .resolved : .gaveUp
    }

    /// Para el consentimiento que sigue después de que la intro arrancó: espera un momento
    /// tranquilo. Si la intro no esperó nada, no hay nada que ceder.
    func waitForCalm(_ isCalm: @MainActor () -> Bool) async {
        guard mustYieldToCalm else { return }
        while !isCalm(), !Task.isCancelled { await sleep(tick) }
    }
}
