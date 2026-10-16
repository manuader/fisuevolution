import Foundation

/// Lo que paga un brazo del momento (2.1 E15 F3, C3). Sólo premios que el juego ya da: plata en segundos de
/// producción (`RewardSpec.coinsSeconds`, por el punto único `grant`) y «Fusionar todo» (el video de la
/// columna, `BoardChange.Origin.rewardedMergeAll`), que no es un `RewardSpec` sino un plan de tablero.
///
/// En el JSON es el mismo objeto de `RewardSpec` (`{"kind": "coinsSeconds", "seconds": 300}`) o
/// `{"kind": "mergeAll"}`.
public enum MomentReward: Sendable, Equatable, Hashable {
    case grant(RewardSpec)
    case mergeAll

    /// El `kind` de «Fusionar todo» en el JSON.
    public static let mergeAllKind = "mergeAll"

    /// Los segundos de plata que da, o `nil` si no es plata.
    public var coinsSeconds: Double? {
        guard case .grant(.coinsSeconds(let seconds)) = self else { return nil }
        return seconds
    }
}

extension MomentReward: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
    }

    public init(from decoder: Decoder) throws {
        let kind = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .kind)
        self = kind == Self.mergeAllKind ? .mergeAll : .grant(try RewardSpec(from: decoder))
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .grant(let spec):
            try spec.encode(to: encoder)
        case .mergeAll:
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.mergeAllKind, forKey: .kind)
        }
    }
}

/// `moments.json` (sección `moments` de la config remota, 2.1 E15 F3, C3): los umbrales de los detectores,
/// los topes de frecuencia y los brazos del bandido con sus priors.
///
/// Los topes viven en el código (`Caps.hard`, `maxRewardSeconds`): lo remoto puede ser más prudente, nunca
/// más insistente ni más generoso, y un valor fuera de tope invalida el archivo entero (no se recorta).
/// `base` nunca ve una oferta del momento: no puede figurar en el archivo y el planificador lo corta igual.
public struct MomentsConfig: Codable, Sendable, Equatable {
    /// La recompensa de plata más grande de un brazo, en segundos de producción. **Provisorio hasta la
    /// calibración (F2-T5)**, que lo fija con el simulador en el peor caso.
    public static let maxRewardSeconds: Double = 600

    /// El `moment` del brazo de control: vale para cualquier momento.
    public static let anyMoment = "*"

    /// La frecuencia de las ofertas. Cuenta cada vez que el planificador gasta un turno: una oferta a la
    /// vista o el control (que no muestra nada, pero ocupa el lugar de una oferta para poder compararse).
    public struct Caps: Codable, Sendable, Equatable {
        /// Turnos como mucho en una hora corrida.
        public var maxPerHour: Int
        /// Segundos como mínimo entre dos turnos.
        public var minSecondsBetween: Double
        /// Después de un «No, gracias», segundos sin volver a ofrecer en ese momento.
        public var cooldownAfterDeclineSeconds: Double
        /// Turnos como mucho en una sesión.
        public var maxPerSession: Int

        public init(maxPerHour: Int, minSecondsBetween: Double, cooldownAfterDeclineSeconds: Double, maxPerSession: Int) {
            self.maxPerHour = maxPerHour
            self.minSecondsBetween = minSecondsBetween
            self.cooldownAfterDeclineSeconds = cooldownAfterDeclineSeconds
            self.maxPerSession = maxPerSession
        }

        /// Los topes del código: `maxPerHour` y `maxPerSession` como mucho estos; las esperas como poco éstas.
        public static let hard = Caps(maxPerHour: 4, minSecondsBetween: 300, cooldownAfterDeclineSeconds: 600, maxPerSession: 8)

        /// Los de la semilla de `moments.json`.
        public static let seed = Caps(maxPerHour: 3, minSecondsBetween: 600, cooldownAfterDeclineSeconds: 1200, maxPerSession: 6)

        /// Estos topes llevados adentro de los del código. El planificador los usa así aunque le llegue una
        /// config sin validar.
        public var withinHard: Caps {
            Caps(
                maxPerHour: min(max(maxPerHour, 0), Self.hard.maxPerHour),
                minSecondsBetween: minSecondsBetween.isFinite ? max(minSecondsBetween, Self.hard.minSecondsBetween) : Self.hard.minSecondsBetween,
                cooldownAfterDeclineSeconds: cooldownAfterDeclineSeconds.isFinite
                    ? max(cooldownAfterDeclineSeconds, Self.hard.cooldownAfterDeclineSeconds)
                    : Self.hard.cooldownAfterDeclineSeconds,
                maxPerSession: min(max(maxPerSession, 0), Self.hard.maxPerSession)
            )
        }
    }

    /// Un brazo: una oferta posible para un momento y unos segmentos, con su prior `Beta(α, β)`.
    public struct Arm: Codable, Sendable, Equatable {
        public var id: String
        /// `NeedMoment.rawValue`, o `"*"` en el control.
        public var moment: String
        /// `nil` sólo en el control, que no paga nada.
        public var reward: MomentReward?
        public var alpha: Double
        public var beta: Double
        /// `PlayerSegment.rawValue` de los segmentos que lo pueden ver; el control no los usa.
        public var segments: [String]
        public var control: Bool

        public init(
            id: String,
            moment: String,
            reward: MomentReward? = nil,
            alpha: Double = 1,
            beta: Double = 1,
            segments: [String] = [],
            control: Bool = false
        ) {
            self.id = id
            self.moment = moment
            self.reward = reward
            self.alpha = alpha
            self.beta = beta
            self.segments = segments
            self.control = control
        }

        private enum CodingKeys: String, CodingKey {
            case id, moment, reward, alpha, beta, segments, control
        }

        /// Los segmentos se leen como texto (no como `PlayerSegment`, que lee lo desconocido como `base`):
        /// un segmento desconocido tiene que invalidar el archivo, no colarse.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            moment = try container.decode(String.self, forKey: .moment)
            reward = try container.decodeIfPresent(MomentReward.self, forKey: .reward)
            alpha = try container.decodeIfPresent(Double.self, forKey: .alpha) ?? 1
            beta = try container.decodeIfPresent(Double.self, forKey: .beta) ?? 1
            segments = try container.decodeIfPresent([String].self, forKey: .segments) ?? []
            control = try container.decodeIfPresent(Bool.self, forKey: .control) ?? false
        }

        /// El momento del brazo; `nil` en el control (o si el texto no es un momento).
        public var needMoment: NeedMoment? {
            NeedMoment(rawValue: moment)
        }

        /// Si este brazo (que no es el control) sirve para `moment` y `segment`. `base` nunca.
        public func offers(_ moment: NeedMoment, to segment: PlayerSegment) -> Bool {
            !control && segment != .base && needMoment == moment && segments.contains(segment.rawValue)
        }
    }

    public var version: String
    public var thresholds: NeedThresholds
    public var caps: Caps
    /// En el orden del archivo: con muestras iguales el bandido se queda con el primero.
    public var arms: [Arm]

    public init(version: String, thresholds: NeedThresholds, caps: Caps, arms: [Arm]) {
        self.version = version
        self.thresholds = thresholds
        self.caps = caps
        self.arms = arms
    }

    /// El bandido con los priors del archivo. El que aprende en el teléfono (F3 T7) los toma de acá.
    public func bandit() -> ThompsonBandit {
        ThompsonBandit(arms: arms.map { BanditArm(id: $0.id, alpha: $0.alpha, beta: $0.beta, isControl: $0.control) })
    }

    public func arm(_ id: String) -> Arm? {
        arms.first { $0.id == id }
    }

    // MARK: - Validación

    public enum ValidationError: Error, Equatable {
        case emptyVersion
        case badThreshold(String)
        case capOutOfRange(String)
        case missingControl
        case multipleControls
        case emptyArmId
        case duplicateArm(String)
        case unknownMoment(arm: String, moment: String)
        case unknownSegment(arm: String, segment: String)
        /// `base` es el juego de la 2.0: no ve ofertas del momento.
        case baseSegment(arm: String)
        case noSegments(arm: String)
        case missingReward(arm: String)
        case controlWithReward(arm: String)
        /// Un premio que no es plata ni «Fusionar todo».
        case unsupportedReward(arm: String)
        case invalidReward(arm: String)
        /// Plata por encima de `maxRewardSeconds`.
        case rewardOutOfRange(arm: String)
        case badPrior(arm: String)
    }

    /// Todo o nada: un tope de más, un brazo raro o la falta del control invalidan el archivo entero.
    public func validate() throws {
        guard !version.trimmingCharacters(in: .whitespaces).isEmpty else { throw ValidationError.emptyVersion }
        try Self.validate(thresholds)
        try Self.validate(caps)
        var seen = Set<String>()
        for arm in arms {
            guard !arm.id.trimmingCharacters(in: .whitespaces).isEmpty else { throw ValidationError.emptyArmId }
            guard seen.insert(arm.id).inserted else { throw ValidationError.duplicateArm(arm.id) }
            try Self.validate(arm)
        }
        switch arms.filter(\.control).count {
        case 0: throw ValidationError.missingControl
        case 1: break
        default: throw ValidationError.multipleControls
        }
    }

    private static func validate(_ thresholds: NeedThresholds) throws {
        for (name, value) in [("priceWallMinutes", thresholds.priceWallMinutes),
                              ("backOfflineMinutes", thresholds.backOfflineMinutes)]
        where !(value > 0 && value.isFinite) {
            throw ValidationError.badThreshold(name)
        }
    }

    private static func validate(_ caps: Caps) throws {
        guard (0...Caps.hard.maxPerHour).contains(caps.maxPerHour) else {
            throw ValidationError.capOutOfRange("maxPerHour")
        }
        guard (0...Caps.hard.maxPerSession).contains(caps.maxPerSession) else {
            throw ValidationError.capOutOfRange("maxPerSession")
        }
        guard caps.minSecondsBetween.isFinite, caps.minSecondsBetween >= Caps.hard.minSecondsBetween else {
            throw ValidationError.capOutOfRange("minSecondsBetween")
        }
        guard caps.cooldownAfterDeclineSeconds.isFinite,
              caps.cooldownAfterDeclineSeconds >= Caps.hard.cooldownAfterDeclineSeconds else {
            throw ValidationError.capOutOfRange("cooldownAfterDeclineSeconds")
        }
    }

    private static func validate(_ arm: Arm) throws {
        guard arm.alpha > 0, arm.alpha.isFinite, arm.beta > 0, arm.beta.isFinite else {
            throw ValidationError.badPrior(arm: arm.id)
        }
        if arm.control {
            guard arm.moment == anyMoment else { throw ValidationError.unknownMoment(arm: arm.id, moment: arm.moment) }
            guard arm.reward == nil else { throw ValidationError.controlWithReward(arm: arm.id) }
            return
        }
        guard arm.needMoment != nil else { throw ValidationError.unknownMoment(arm: arm.id, moment: arm.moment) }
        guard !arm.segments.isEmpty else { throw ValidationError.noSegments(arm: arm.id) }
        for segment in arm.segments {
            guard let known = PlayerSegment(rawValue: segment) else {
                throw ValidationError.unknownSegment(arm: arm.id, segment: segment)
            }
            guard known != .base else { throw ValidationError.baseSegment(arm: arm.id) }
        }
        guard let reward = arm.reward else { throw ValidationError.missingReward(arm: arm.id) }
        try validate(reward, arm: arm.id)
    }

    private static func validate(_ reward: MomentReward, arm: String) throws {
        switch reward {
        case .mergeAll:
            return
        case .grant(let spec):
            guard case .coinsSeconds(let seconds) = spec else { throw ValidationError.unsupportedReward(arm: arm) }
            do {
                try spec.validate()
            } catch {
                throw ValidationError.invalidReward(arm: arm)
            }
            guard seconds <= maxRewardSeconds else { throw ValidationError.rewardOutOfRange(arm: arm) }
        }
    }
}
