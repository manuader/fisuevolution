import EconomyKit
import Foundation

/// Lo que los momentos recuerdan de una partida mientras la app vive: la oferta a la vista, los topes, el
/// bandido, la sesión y la telemetría. `GameState.swift` no tiene lugar para esto (nadie lo toca en la
/// 2.1), así que vive acá y se engancha a la partida por referencia débil, como el servicio de
/// personalización. Nada de esto va al save.
@Observable @MainActor
final class MomentsRuntime {
    /// Cada cuánto el `tick` arma la foto y pregunta (no en cada cuadro).
    static let checkInterval: TimeInterval = 5
    /// `--uitest-moment <momento>` fuerza el momento (respetando el tablero tapado y el tutorial).
    static let momentArgument = "--uitest-moment"
    /// `--uitest-moment-arm <brazo>` fija el brazo: el bandido no elige, pero los topes, el segmento, el
    /// video y lo que se puede pagar mandan igual.
    static let armArgument = "--uitest-moment-arm"

    /// Lo que muestra la tarjeta (T6).
    var offer: MomentOffer?

    @ObservationIgnored var history = MomentHistory()
    @ObservationIgnored var bandit: ThompsonBandit?
    /// La `version` de la config con que se armó `bandit`: si cambia, vuelven los priors.
    @ObservationIgnored var banditVersion: String?
    @ObservationIgnored var rng = SplitMix64(seed: UInt64.random(in: .min ... .max))
    @ObservationIgnored var forcedMoment: NeedMoment?
    @ObservationIgnored var forcedArmId: String?
    /// Para los tests: el segmento que se usa en vez del del servicio.
    @ObservationIgnored var segmentOverride: PlayerSegment?
    @ObservationIgnored var sinceCheck: TimeInterval = 0
    /// El `sceneActiveSince` de la sesión en curso; si cambia, empezó otra.
    @ObservationIgnored var sessionMark: TimeInterval?
    @ObservationIgnored var sessionStarted = false
    /// La última foto con la escena en primer plano: de acá sale cuánto estuvo afuera.
    @ObservationIgnored var lastActiveAt: Date?
    /// Cuánto estuvo afuera, hasta la primera foto con el tablero a la vista de la vuelta.
    @ObservationIgnored var awayOnReturn: Double?
    @ObservationIgnored var exposedArms: Set<String> = []
    /// El momento de cada `site` que se ofreció, para el `ctx` del embudo: `completed` llega cuando la
    /// oferta ya se cobró y se fue.
    @ObservationIgnored var contexts: [String: NeedMoment] = [:]

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        forcedMoment = Self.value(after: Self.momentArgument, in: arguments).flatMap(NeedMoment.init(rawValue:))
        forcedArmId = Self.value(after: Self.armArgument, in: arguments)
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        return arguments.dropFirst(index + 1).first
    }
}

@MainActor
private enum MomentsAttachments {
    struct Entry {
        weak var owner: GameState?
        let runtime: MomentsRuntime
    }

    static var entries: [ObjectIdentifier: Entry] = [:]

    static func runtime(for owner: GameState) -> MomentsRuntime {
        let key = ObjectIdentifier(owner)
        if let entry = entries[key], entry.owner === owner { return entry.runtime }
        entries = entries.filter { $0.value.owner != nil }
        let runtime = MomentsRuntime()
        entries[key] = Entry(owner: owner, runtime: runtime)
        return runtime
    }
}

/// El momento justo en el juego (2.1 E15 F3 T5). Cada 5 s del `tick` arma la foto del estado real
/// (`NeedSnapshot`), pregunta si hay video en el bloque `gifts` y le pide al planificador qué sale. Nada
/// fabrica el momento: la foto sólo lee.
///
/// - **`base` no ve nada** (la compuerta cerrada, el interruptor apagado o sin sección `moments`): ni
///   foto, ni exposición, ni turno. Si el segmento vuelve a `base` con una oferta a la vista, se retira.
/// - **Una oferta a la vista por vez**, con «No, gracias». Aceptar paga exactamente el premio del brazo
///   por el punto único de premios (fuente `moment.<brazo>`) o encola «Fusionar todo»; la oferta se
///   borra ANTES de pagar: un segundo premio del mismo video no encuentra nada. Rechazar abre la espera
///   de ese momento.
/// - **El control** anota la exposición y gasta el turno, y no muestra nada.
/// - **Telemetría**: un `exposure` (`exp: "moments"`) por sesión y brazo; el embudo de la tarjeta con el
///   `ctx` del momento (`momentOfferFunnelReporter`).
extension GameState {
    static let momentsSectionKey = "moments"
    static let momentsExperimentId = "moments"

    var momentsRuntime: MomentsRuntime {
        MomentsAttachments.runtime(for: self)
    }

    /// La oferta que la tarjeta muestra, o `nil`.
    var momentOffer: MomentOffer? {
        momentsRuntime.offer
    }

    /// La plata que paga la oferta a la vista si se cobra ahora (la misma cuenta que `grant`), o `nil` si
    /// no es plata.
    var momentOfferCoins: Double? {
        guard let seconds = momentOffer?.reward.coinsSeconds, let content, let economy, let player else { return nil }
        return Self.coinReward(seconds: seconds, player: player, content: content, economy: economy)
    }

    /// La sección `moments` que vale: la de la config remota (validada, todo o nada); con el segmento
    /// forzado (UI tests, el panel de debug), la semilla del bundle. Sin ninguna, no hay momentos.
    var momentsConfig: MomentsConfig? {
        guard let service = personalization else { return nil }
        if let remote = service.config.section(Self.momentsSectionKey, as: MomentsConfig.self) { return remote }
        return Self.isSegmentForced(service) ? Self.bundledMomentsConfig : nil
    }

    // MARK: - El tick

    /// La llama el `tick` con el `delta` de la economía sin el time-warp: junta 5 s y recién ahí mira.
    func advanceMoments(delta: TimeInterval) {
        guard delta.isFinite, delta > 0 else { return }
        let runtime = momentsRuntime
        runtime.sinceCheck += delta
        guard runtime.sinceCheck >= MomentsRuntime.checkInterval else { return }
        runtime.sinceCheck = 0
        evaluateMoments()
    }

    /// Una pasada: la sesión, la foto, el planificador y, si sale algo, la oferta o el control.
    func evaluateMoments(now: Date = Date()) {
        let runtime = momentsRuntime
        noteMomentSession(runtime)
        defer { runtime.lastActiveAt = now }

        let segment = runtime.segmentOverride ?? self.segment
        guard segment != .base, let config = momentsConfig else {
            withdrawMomentOffer(runtime, now: now)
            return
        }
        guard runtime.offer == nil else { return }

        let snapshot = momentSnapshot(now: now)
        let boardInView = !snapshot.uiCoversBoard && !snapshot.tutorialActive
        var moments = NeedDetector.moments(snapshot, thresholds: config.thresholds)
        if let forced = runtime.forcedMoment { moments = boardInView ? [forced] : [] }
        if boardInView { runtime.awayOnReturn = nil }

        let decision = decideMoment(
            moments: moments, segment: segment, adReady: ads?.isRewardedReady(for: MomentOffer.placement) == true,
            config: config, now: now, runtime: runtime
        )
        runtime.history.record(decision, at: now)
        switch decision {
        case .none:
            return
        case .control(let armId, _):
            exposeMomentArm(armId, config: config, runtime: runtime)
        case let .offer(armId, moment, reward):
            let offer = MomentOffer(armId: armId, moment: moment, reward: reward, configVersion: config.version)
            runtime.offer = offer
            runtime.contexts[offer.site] = moment
            exposeMomentArm(armId, config: config, runtime: runtime)
            Log.ads.info("moment offer: \(armId) at \(moment.rawValue)")
        }
    }

    /// La foto del estado real. Sólo lee: el piso que se está mirando, cuánto le falta para la próxima
    /// contratación del atajo, el ingreso de la torre, el colchón del tablero y la vuelta.
    func momentSnapshot(now: Date) -> NeedSnapshot {
        NeedSnapshot(
            freeSlots: momentFreeSlots,
            nextHireCost: momentHireShortfall,
            incomePerSecond: towerIncomePerSecond,
            mattressReady: mattressOnBoard,
            secondsAwayOnReturn: momentsRuntime.awayOnReturn,
            uiCoversBoard: momentBoardCovered,
            tutorialActive: tutorialPhaseActive
        )
    }

    // MARK: - La tarjeta

    /// El video se premió: paga el premio del brazo, una sola vez. `false` si ya no había nada (otro premio
    /// del mismo video, una oferta vieja o una rechazada).
    @discardableResult
    func claimMomentOffer(id: UUID, now: Date = Date()) -> Bool {
        let runtime = momentsRuntime
        guard let offer = runtime.offer, offer.id == id else { return false }
        runtime.offer = nil
        payMomentReward(offer, now: now.timeIntervalSince1970)
        runtime.history.recordAccepted()
        noteMomentVideo()
        Log.economy.info("moment offer claimed: \(offer.site)")
        return true
    }

    /// «No, gracias» (o la tarjeta se cerró): no paga y abre la espera de ese momento. Con el video en
    /// curso no rechaza: queda anotado y se aplica si el anuncio vuelve sin premio.
    func declineMomentOffer(id: UUID, now: Date = Date()) {
        let runtime = momentsRuntime
        guard let offer = runtime.offer, offer.id == id else { return }
        if offer.isWatching {
            runtime.offer?.declinePending = true
            return
        }
        runtime.offer = nil
        runtime.history.recordDeclined(offer.moment, at: now)
    }

    /// El jugador tocó el video: desde acá y hasta que el anuncio vuelva, nada la retira.
    func beginMomentWatch(id: UUID) {
        guard momentsRuntime.offer?.id == id else { return }
        momentsRuntime.offer?.isWatching = true
    }

    /// El anuncio volvió. Con premio, `claimMomentOffer` ya pagó y no queda nada; sin premio, la oferta
    /// sigue a la vista, salvo que la hayan rechazado mientras se miraba.
    func endMomentWatch(id: UUID, now: Date = Date()) {
        let runtime = momentsRuntime
        guard let offer = runtime.offer, offer.id == id else { return }
        runtime.offer?.isWatching = false
        if offer.declinePending { declineMomentOffer(id: id, now: now) }
    }

    /// El embudo de la tarjeta: lo mismo que `offerFunnelReporter` más el `ctx` del momento. La tarjeta
    /// (T6) lo pone en el entorno de su `RewardedOfferButton`.
    var momentOfferFunnelReporter: OfferFunnelReporter {
        OfferFunnelReporter { [weak self] site, stage in self?.recordMomentOfferStage(stage, site: site) }
    }

    func recordMomentOfferStage(_ stage: OfferStage, site: String) {
        guard player != nil else { return }
        player?.meta.offerFunnel.record(stage, site: site)
        scheduleSave()
        telemetryOffer(stage, site: site, ctx: momentsRuntime.contexts[site])
    }

    // MARK: - Por dentro

    private static let bundledMomentsConfig: MomentsConfig? = {
        guard let url = Bundle.main.url(forResource: "moments", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(MomentsConfig.self, from: data),
              (try? config.validate()) != nil else { return nil }
        return config
    }()

    private static func isSegmentForced(_ service: PersonalizationService) -> Bool {
        #if DEBUG
        if service.debugForcedSegment != nil { return true }
        #endif
        return service.gate.forcedSegment != nil
    }

    /// Una sesión nueva (otro `.active` después de un background): la cuenta de la sesión, las
    /// exposiciones y la oferta que había quedado a la vista vuelven a cero; se anota cuánto estuvo afuera.
    private func noteMomentSession(_ runtime: MomentsRuntime) {
        guard !runtime.sessionStarted || runtime.sessionMark != sceneActiveSince else { return }
        if runtime.sessionStarted, let since = sceneActiveSince, let last = runtime.lastActiveAt {
            runtime.awayOnReturn = max(0, since - last.timeIntervalSince1970)
        }
        runtime.sessionStarted = true
        runtime.sessionMark = sceneActiveSince
        runtime.history.startSession()
        runtime.exposedArms = []
        if runtime.offer?.isWatching != true { runtime.offer = nil }
    }

    /// Sin momentos (`base`, sin config): la oferta a la vista se va sin cobrar. Ante la duda, cuenta como
    /// un rechazo: se ofrece menos.
    private func withdrawMomentOffer(_ runtime: MomentsRuntime, now: Date) {
        guard let offer = runtime.offer, !offer.isWatching else { return }
        runtime.offer = nil
        runtime.history.recordDeclined(offer.moment, at: now)
    }

    /// El planificador con el bandido de la config (sus priors se reponen si cambia la versión). Con el
    /// brazo fijado por `--uitest-moment-arm`, un bandido de ese brazo solo: los topes y la elegibilidad
    /// siguen siendo los del planificador.
    private func decideMoment(
        moments: [NeedMoment],
        segment: PlayerSegment,
        adReady: Bool,
        config: MomentsConfig,
        now: Date,
        runtime: MomentsRuntime
    ) -> MomentDecision {
        if runtime.bandit == nil || runtime.banditVersion != config.version {
            runtime.bandit = config.bandit()
            runtime.banditVersion = config.version
        }
        var bandit = runtime.bandit ?? config.bandit()
        if let forced = runtime.forcedArmId {
            guard let arm = config.arm(forced) else { return .none }
            bandit = ThompsonBandit(arms: [BanditArm(id: arm.id, alpha: arm.alpha, beta: arm.beta, isControl: arm.control)])
        }
        return MomentOfferPlanner.next(
            moments: moments, segment: segment, adReady: adReady, history: runtime.history, now: now,
            config: config, bandit: bandit, rng: &runtime.rng, canPay: { self.canPayMoment($0) }
        )
    }

    /// Un premio que el juego no puede pagar ahora hace inelegible al brazo: «Fusionar todo» sin pares en
    /// el piso a la vista (o con una cadena ya encolada).
    private func canPayMoment(_ reward: MomentReward) -> Bool {
        switch reward {
        case .mergeAll: mergeAllPairsOnVisibleFloor() > 0
        case .grant(let spec): Self.grantableRewardKinds.contains(spec.kind) && coinsPerProductionSecond > 0
        }
    }

    /// El efecto primero: la plata por `grant` o los pares encolados. Si «Fusionar todo» ya no tiene nada
    /// que fusionar, el video compensa (un video nunca es en vano).
    private func payMomentReward(_ offer: MomentOffer, now: TimeInterval) {
        switch offer.reward {
        case .grant(let spec):
            let credited = grant(spec, source: offer.site, now: now)
            announceReward(spec, coins: credited)
        case .mergeAll:
            guard mergeAllPairsOnVisibleFloor() > 0,
                  enqueueMergeAll(onFloor: visibleFloorOrdinal, origin: .rewardedMergeAll) > 0 else {
                compensateRewardedVideo()
                return
            }
            refreshSideRail(now: now)
            scheduleSave()
        }
    }

    private func noteMomentVideo() {
        guard var player else { return }
        player.meta.stats.videosWatchedEver += 1
        self.player = player
        effectsVersion += 1
        evaluateAchievements()
        scheduleSave()
    }

    private func exposeMomentArm(_ armId: String, config: MomentsConfig, runtime: MomentsRuntime) {
        guard runtime.exposedArms.insert(armId).inserted else { return }
        telemetry?.record(.exposure(exp: Self.momentsExperimentId, arm: armId, ver: config.version))
    }

    /// Lo que tapa el tablero o lo ocupa: una hoja, un pop-up, una celebración, un anuncio, alguien
    /// entrando a escena o el paso 2 de un ×2. El tutorial va aparte (`tutorialActive`).
    private var momentBoardCovered: Bool {
        phase != .ready || isBoardBusy || celebrations.current != nil || ads?.isPresentingFullScreen == true
            || stageEntranceInProgress || rewardDouble != nil
    }

    /// Los lugares libres del piso que se está mirando; un piso cerrado no está lleno.
    private var momentFreeSlots: Int {
        guard let tower, let player, tower.floors.indices.contains(visibleFloorOrdinal) else { return 1 }
        let floor = tower.floors[visibleFloorOrdinal]
        guard player.run.unlockedFloors.contains(floor.def.id) else { return 1 }
        return floor.slots.count - floor.occupiedCount
    }

    /// Cuánto le falta para la contratación que ofrece el atajo: con la plata en mano no hay pared.
    private var momentHireShortfall: Double {
        guard let player, let typeId = quickHireOffer?.typeId,
              let cost = currentQuote(player: player, typeId: typeId)?.cost, cost.isFinite else { return 0 }
        return max(0, cost - player.run.coins)
    }
}
