import Foundation

/// Lo que decide el planificador en una foto (2.1 E15 F3, C4).
public enum MomentDecision: Sendable, Equatable {
    /// No sale nada: no hay momento, no hay video, el segmento es `base` o un tope lo frena.
    case none
    /// Salió el control: no se muestra nada, pero el turno cuenta (y la exposición se anota) para poder
    /// comparar contra las ofertas. Lleva el momento para el `ctx` del embudo.
    case control(armId: String, moment: NeedMoment)
    /// Una oferta a la vista: el brazo, el momento que la justifica y exactamente lo que paga.
    case offer(armId: String, moment: NeedMoment, reward: MomentReward)

    public var armId: String? {
        switch self {
        case .none: nil
        case .control(let id, _), .offer(let id, _, _): id
        }
    }
}

/// Lo que ya pasó con las ofertas del momento, para los topes de `MomentsConfig.Caps`. Vive en memoria
/// durante la sesión; `startSession()` arranca la cuenta de la sesión y deja la de la hora corrida.
///
/// Un turno es una oferta mostrada o un control. Con una oferta a la vista no sale otra hasta que se
/// acepta o se rechaza: una a la vista por vez.
public struct MomentHistory: Codable, Sendable, Equatable {
    /// Las horas de los turnos de la última hora (las más viejas se podan al anotar).
    public private(set) var turns: [Date]
    /// Turnos de esta sesión.
    public private(set) var sessionTurns: Int
    /// El último «No, gracias» de cada momento (`NeedMoment.rawValue`).
    public private(set) var lastDecline: [String: Date]
    /// Hay una oferta a la vista, sin aceptar ni rechazar.
    public private(set) var offerOpen: Bool

    public init() {
        turns = []
        sessionTurns = 0
        lastDecline = [:]
        offerOpen = false
    }

    /// Una sesión nueva: la cuenta de la sesión vuelve a cero y ninguna oferta queda a la vista. La hora
    /// corrida y los rechazos siguen contando.
    public mutating func startSession() {
        sessionTurns = 0
        offerOpen = false
    }

    /// Anota lo que decidió el planificador, a la hora en que se decidió. `.none` no gasta nada.
    public mutating func record(_ decision: MomentDecision, at now: Date) {
        switch decision {
        case .none:
            return
        case .control:
            break
        case .offer:
            offerOpen = true
        }
        turns.removeAll { now.timeIntervalSince($0) >= MomentOfferPlanner.hour }
        turns.append(now)
        sessionTurns += 1
    }

    /// El jugador aceptó la oferta a la vista (miró el video).
    public mutating func recordAccepted() {
        offerOpen = false
    }

    /// El jugador dijo «No, gracias» (o cerró la tarjeta): abre la espera de ese momento.
    public mutating func recordDeclined(_ moment: NeedMoment, at now: Date) {
        offerOpen = false
        lastDecline[moment.rawValue] = now
    }

    /// Turnos dentro de la hora corrida que termina en `now`. Uno con fecha futura (el reloj fue para atrás)
    /// cuenta: ante la duda, se ofrece menos.
    func turnsInLastHour(before now: Date) -> Int {
        turns.filter { now.timeIntervalSince($0) < MomentOfferPlanner.hour }.count
    }

    func isCoolingDown(_ moment: NeedMoment, now: Date, cooldown: TimeInterval) -> Bool {
        guard let declined = lastDecline[moment.rawValue] else { return false }
        return now.timeIntervalSince(declined) < cooldown
    }
}

/// El planificador del momento justo (2.1 E15 F3, C4). Puro: no fabrica momentos ni mira el estado del
/// juego; recibe los momentos que vio `NeedDetector` y decide si sale algo y qué.
///
/// La condición del video es sólo «hay uno cargado» (V4: sin MAX, no hay «anuncio caro cargado»); lo que
/// vale el jugador ya viene en su segmento (el promedio de su ledger).
public enum MomentOfferPlanner {
    static let hour: TimeInterval = 3600

    /// - Parameters:
    ///   - moments: los de `NeedDetector.moments`, en orden de prioridad.
    ///   - adReady: hay un video cargado. Sin video no sale nada ni se gasta frecuencia.
    ///   - canPay: si el juego puede pagar ese premio ahora (`mergeAll` sin nada para fusionar, no); un
    ///     brazo que no se puede pagar no es elegible.
    /// - Returns: la decisión; quien la muestra la anota en `history` con `record(_:at:)`.
    public static func next<R: RandomNumberGenerator>(
        moments: [NeedMoment],
        segment: PlayerSegment,
        adReady: Bool,
        history: MomentHistory,
        now: Date,
        config: MomentsConfig,
        bandit: ThompsonBandit,
        rng: inout R,
        canPay: (MomentReward) -> Bool = { _ in true }
    ) -> MomentDecision {
        guard segment != .base, adReady, !moments.isEmpty, !history.offerOpen else { return .none }
        let caps = config.caps.withinHard
        guard history.sessionTurns < caps.maxPerSession,
              history.turnsInLastHour(before: now) < caps.maxPerHour else { return .none }
        if let last = history.turns.last, now.timeIntervalSince(last) < caps.minSecondsBetween {
            return .none
        }
        guard let found = firstMomentWithOffers(
            moments, segment: segment, history: history, now: now, config: config, caps: caps, canPay: canPay
        ) else { return .none }
        let (moment, offers) = found
        guard let chosen = bandit.choose(eligible: offers.map(\.id), rng: &rng),
              let arm = config.arm(chosen) else { return .none }
        if arm.control {
            return .control(armId: arm.id, moment: moment)
        }
        guard let reward = arm.reward, offers.contains(where: { $0.id == arm.id }) else { return .none }
        return .offer(armId: arm.id, moment: moment, reward: reward)
    }

    /// El primer momento (en prioridad) que no está en espera por un rechazo y tiene al menos un brazo que
    /// se puede ofrecer y pagar. Sin brazos de oferta el control no sale solo: no habría con qué comparar.
    private static func firstMomentWithOffers(
        _ moments: [NeedMoment],
        segment: PlayerSegment,
        history: MomentHistory,
        now: Date,
        config: MomentsConfig,
        caps: MomentsConfig.Caps,
        canPay: (MomentReward) -> Bool
    ) -> (NeedMoment, [MomentsConfig.Arm])? {
        for moment in moments where !history.isCoolingDown(moment, now: now, cooldown: caps.cooldownAfterDeclineSeconds) {
            let offers = config.arms.filter { arm in
                guard arm.offers(moment, to: segment), let reward = arm.reward else { return false }
                return isWithinCaps(reward) && canPay(reward)
            }
            if !offers.isEmpty {
                return (moment, offers)
            }
        }
        return nil
    }

    /// La plata por encima del tope del código no sale aunque la config no se haya validado.
    private static func isWithinCaps(_ reward: MomentReward) -> Bool {
        switch reward {
        case .mergeAll: true
        case .grant(.coinsSeconds(let seconds)): seconds > 0 && seconds <= MomentsConfig.maxRewardSeconds
        case .grant: false
        }
    }
}
