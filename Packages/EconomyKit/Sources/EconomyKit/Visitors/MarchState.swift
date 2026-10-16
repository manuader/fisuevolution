import Foundation

/// La Marcha del Puntero (E14b B25, D16): el reto de toques de una ventana larga. A diferencia del
/// reto del escenario (que corre con el juego activo y vive en memoria), éste corre con el reloj de
/// PARED y vive en el save: sigue con la app cerrada y, al volver, se resuelve. Cuenta en cualquier
/// piso; sólo los toques a mano que dan monedas (los cuenta la app).
public struct MarchState: Codable, Sendable, Equatable {
    public enum Outcome: String, Codable, Sendable {
        case won, lost
    }

    public let scriptId: String
    /// Fecha de pared (segundos desde 1970) en que se aceptó y en que vence.
    public let startedAt: Double
    public let endsAt: Double
    public let goal: Int
    /// La plata (ya cotizada al aceptar) y lo demás que paga si se llega.
    public let coins: Double
    public let rewards: [RewardSpec]
    public var taps: Int
    /// `nil` mientras corre. Resuelta, espera a que el jugador la cierre (`VisitorScheduler.settleMarch`):
    /// así un cierre de la app entre llegar y cobrar no pierde el premio.
    public var outcome: Outcome?

    public init(
        scriptId: String, startedAt: Double, endsAt: Double, goal: Int, coins: Double,
        rewards: [RewardSpec], taps: Int = 0, outcome: Outcome? = nil
    ) {
        self.scriptId = scriptId
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.goal = goal
        self.coins = coins
        self.rewards = rewards
        self.taps = taps
        self.outcome = outcome
    }

    public var isRunning: Bool { outcome == nil }

    /// Lo que falta, con piso en 0.
    public func remaining(at now: Double) -> Double {
        max(0, endsAt - now)
    }

    /// Toques sobre la meta, con tope en 1.
    public var progress: Double {
        min(1, Double(taps) / Double(max(goal, 1)))
    }
}

extension VisitorScheduler {
    /// El jugador aceptó: arranca la Marcha con el reloj de pared. Una sola a la vez.
    @discardableResult
    public static func beginMarch(
        _ state: inout VisitorsState, scriptId: String, terms: ChallengeTerms, now: Double
    ) -> Bool {
        guard state.march == nil, terms.taps > 0, terms.windowSeconds > 0 else { return false }
        state.march = MarchState(scriptId: scriptId, startedAt: now, endsAt: now + terms.windowSeconds,
                                 goal: terms.taps, coins: terms.coins, rewards: terms.rewards)
        return true
    }

    /// Un toque a mano. Sólo cuenta con la Marcha corriendo y dentro de su ventana; el que llega a la
    /// meta la gana. Devuelve si este toque la ganó.
    @discardableResult
    public static func noteMarchTap(_ state: inout VisitorsState, now: Double) -> Bool {
        guard var march = state.march, march.isRunning, now >= march.startedAt, now < march.endsAt else { return false }
        march.taps += 1
        if march.taps >= march.goal { march.outcome = .won }
        state.march = march
        return march.outcome == .won
    }

    /// Con el reloj de pared: la que venció sin llegar queda perdida. Lo llama la app en cada tick y
    /// al volver; devuelve el resultado pendiente de cerrar, si hay.
    @discardableResult
    public static func resolveMarch(_ state: inout VisitorsState, now: Double) -> MarchState.Outcome? {
        guard var march = state.march else { return nil }
        if march.isRunning, now >= march.endsAt {
            march.outcome = .lost
            state.march = march
        }
        return march.outcome
    }

    /// El jugador cerró el resultado: la Marcha sale del save y se devuelve tal como quedó. Paga una
    /// sola vez: la segunda no encuentra nada, y otro dispositivo tampoco (`lastSettledMarchStartedAt`).
    /// Mientras corre, no se cierra.
    public static func settleMarch(_ state: inout VisitorsState) -> MarchState? {
        guard let march = state.march, march.outcome != nil else { return nil }
        state.march = nil
        state.lastSettledMarchStartedAt = march.startedAt
        return march
    }
}
