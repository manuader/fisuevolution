import EconomyKit
import Foundation
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// De dónde saca el servicio la config de personalización: `PersonalizationConfigLoader` en la app,
/// uno de mentira en los tests.
protocol PersonalizationConfigSource: Actor {
    var isEnabled: Bool { get }
    func current() -> PersonalizationConfig
    @discardableResult
    func refresh(force: Bool) async -> PersonalizationConfigLoader.RefreshOutcome
}

extension PersonalizationConfigLoader: PersonalizationConfigSource {}

/// El A/B reglas contra modelo (2.1 E15 F6), sección `player_value_ab` de la config. Sin ella, o sin
/// un modelo válido en `player_value_model`, no hay A/B: todos con las reglas y sin `exposure`.
struct PlayerValueExperiment: Decodable, Sendable, Equatable, PersonalizationSection {
    static let sectionKey = "player_value_ab"
    static let modelSectionKey = "player_value_model"
    /// El `exp` del evento `exposure`.
    static let experimentId = "vej"
    static let maxSaltLength = 32

    struct Invalid: Error {}

    /// Cambiarla rebaraja a todos (`ExperimentBucket`).
    var salt: String
    /// Porcentaje de instalaciones en el brazo modelo, 0…100.
    var split: Int

    func validate() throws {
        guard !salt.isEmpty, salt.count <= Self.maxSaltLength, (0...ExperimentBucket.bucketCount).contains(split) else {
            throw Invalid()
        }
    }
}

/// El modelo de F6 llega como una sección más; su `validate()` vive en EconomyKit.
extension TreeEnsemble: PersonalizationSection {}

/// El segmento de cada jugador, calculado en el teléfono (2.1 E15 F1 T5). **Nada lo consume
/// todavía**: lo leen F2, F3 y F5 por `GameState.segment` y `GameState.playerValue`.
///
/// - **Una vez por día.** Al empezar cada sesión, con la compuerta abierta, recalcula si pasó un día
///   de calendario, si cambió la versión de las tablas o si cambió la variante (el brazo del A/B);
///   si no, usa el último cálculo. El segmento anterior entra como `previous`: histéresis y un
///   escalón por día como mucho.
/// - **La compuerta manda** (`PersonalizationGate`). Cerrada, el segmento es `base` y no sale
///   ningún evento, **sin borrar** el último cálculo: si vuelve el consentimiento, no arranca de
///   cero. `--uitest-segment <s>` fuerza el segmento y saltea todo.
/// - **Telemetría.** Un `segment` cuando el segmento calculado es distinto del último informado (o
///   nunca se informó); con el A/B prendido, un `exposure` por sesión y brazo. Los dos pasan,
///   además, por la compuerta de la telemetría de F0.
/// - **Nunca bloquea el arranque**: la red, el disco del aparato y el Keychain van en tareas
///   encadenadas, en orden.
@Observable @MainActor
final class PersonalizationService {
    typealias DeviceLookup = @Sendable () async -> (storefront: String?, model: String?)
    typealias InstallIdLookup = @Sendable () async -> String

    /// El segmento que vive el jugador ahora mismo.
    private(set) var segment: PlayerSegment = .base
    /// El último cálculo, aunque la compuerta esté cerrada (lo muestra el panel de debug).
    private(set) var lastEstimate: PlayerValueEstimate?
    /// La compuerta con que se resolvió el segmento por última vez.
    private(set) var gate: PersonalizationGate
    /// La config con que se calculó; `.empty` mientras la compuerta no abrió. F2/F3 sacan de acá su
    /// sección.
    private(set) var config: PersonalizationConfig = .empty

    #if DEBUG
    /// El que fuerza el panel de debug, sin tocar el cálculo ni la telemetría.
    private(set) var debugForcedSegment: PlayerSegment?

    func debugForce(_ forced: PlayerSegment?) {
        debugForcedSegment = forced
        segment = resolvedSegment()
    }
    #endif

    @ObservationIgnored private let source: any PersonalizationConfigSource
    @ObservationIgnored private let store: PersonalizationStore
    @ObservationIgnored private let device: DeviceLookup
    @ObservationIgnored private let installId: InstallIdLookup
    @ObservationIgnored private let consentAllows: @MainActor () -> Bool
    @ObservationIgnored private let underAgeSignal: @MainActor () -> Bool
    @ObservationIgnored private let arguments: [String]
    @ObservationIgnored private let isDebug: Bool
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let calendar: Calendar

    @ObservationIgnored private var player: @MainActor () -> PlayerState? = { nil }
    @ObservationIgnored private var recordEvent: @MainActor (TelemetryPayload) -> Void = { _ in }
    @ObservationIgnored private var cachedRecord: PersonalizationRecord?
    @ObservationIgnored private var isSessionOpen = false
    @ObservationIgnored private var refreshedOnce = false
    @ObservationIgnored private var exposedArms: Set<String> = []
    @ObservationIgnored private var tail: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init(
        source: any PersonalizationConfigSource,
        store: PersonalizationStore = PersonalizationStore(),
        device: @escaping DeviceLookup,
        installId: @escaping InstallIdLookup,
        consentAllows: @escaping @MainActor () -> Bool,
        underAgeSignal: @escaping @MainActor () -> Bool,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        isDebug: Bool = TelemetryService.isDebugBuild,
        now: @escaping @MainActor () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.source = source
        self.store = store
        self.device = device
        self.installId = installId
        self.consentAllows = consentAllows
        self.underAgeSignal = underAgeSignal
        self.arguments = arguments
        self.isDebug = isDebug
        self.now = now
        self.calendar = calendar
        gate = PersonalizationGate(
            remoteEnabled: false, consentAllows: false, underAgeSignal: false, arguments: arguments, isDebug: isDebug)
        segment = gate.segment(ruled: nil)
    }

    /// El de la app: la `RankingConfig` del ranking (bajo XCTest o `--uitest*` el cargador no
    /// pregunta y queda apagado). El consentimiento es el de `PersonalizationConsent`; la señal de
    /// menor, el tratamiento por edad del SDK de anuncios (`ageRestrictedTreatment`, el que
    /// reemplaza a `tagForUnderAgeOfConsent`/`tagForChildDirectedTreatment` en el SDK 13): la app
    /// no lo fija, así que hoy no hay señal; si algún día se fija, la personalización se cierra.
    static func live(config: RankingConfig?) -> PersonalizationService {
        let context = DeviceContext()
        return PersonalizationService(
            source: PersonalizationConfigLoader.live(config: config),
            device: {
                let snapshot = await context.snapshot()
                return (snapshot.storefront, snapshot.deviceModel)
            },
            installId: {
                await Task.detached(priority: .utility) { InstallIdentity.telemetry.installId() }.value
            },
            consentAllows: {
                let ump = ConsentInformation.shared
                return PersonalizationConsent.allows(
                    defaults: .standard,
                    umpCanRequestAds: ump.canRequestAds,
                    umpSaysNotRequired: ump.consentStatus == .notRequired
                )
            },
            underAgeSignal: {
                let treatment = MobileAds.shared.requestConfiguration.ageRestrictedTreatment
                return PersonalizationGate.underAgeSignal(
                    tagForUnderAgeOfConsent: treatment == .teen,
                    tagForChildDirectedTreatment: treatment == .child
                )
            }
        )
    }

    /// Lo que el último cálculo dice del jugador, sólo si es el que vive: con la compuerta abierta
    /// y sin segmento forzado. Si no, `nil` (el juego de la 2.0).
    var playerValue: PlayerValueEstimate? {
        guard gate.forcedSegment == nil, gate.isOpen else { return nil }
        return lastEstimate
    }

    // MARK: - El ciclo de vida

    /// Lo engancha `GameState.attachPersonalization`: de dónde leer la partida y por dónde mandar
    /// los eventos (la telemetría de la partida, con su compuerta).
    func attach(player: @escaping @MainActor () -> PlayerState?, record: @escaping @MainActor (TelemetryPayload) -> Void) {
        self.player = player
        recordEvent = record
    }

    /// Al arrancar: escucha el primer plano y el background y, si la app ya está en primer plano,
    /// abre la sesión (el `.active` del arranque llegó antes que los servicios).
    func start(inForeground: Bool) {
        observeScene()
        if inForeground {
            sceneDidBecomeActive()
        } else {
            chain { await $0.refreshAndEvaluate() }
        }
    }

    /// `.active`: abre la sesión (dos seguidas sin background en el medio son una) y recalcula.
    func sceneDidBecomeActive() {
        guard !isSessionOpen else { return }
        isSessionOpen = true
        exposedArms = []
        if let player = player() {
            updateRecord {
                $0.beginSession(at: now(), prestige: player.meta.prestigeLevel,
                                offersShown: PlayerValueInputsBuilder.offersShown(player.meta.offerFunnel))
            }
        }
        chain { await $0.refreshAndEvaluate() }
    }

    /// `.background`: cierra la sesión con su duración.
    func sceneDidEnterBackground() {
        guard isSessionOpen else { return }
        isSessionOpen = false
        updateRecord { $0.endSession(at: now()) }
    }

    /// Espera a que termine todo lo pedido hasta ahora. Para los tests.
    func settle() async {
        await tail?.value
    }

    // MARK: - Por dentro

    private func observeScene() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sceneDidBecomeActive() }
            },
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sceneDidEnterBackground() }
            },
        ]
    }

    private func chain(_ work: @escaping @MainActor @Sendable (PersonalizationService) async -> Void) {
        let previous = tail
        tail = Task { [self] in
            await previous?.value
            await work(self)
        }
    }

    /// Pregunta el interruptor (al arrancar siempre; después, el cargador decide si ya toca) y
    /// resuelve el segmento.
    private func refreshAndEvaluate() async {
        let force = !refreshedOnce
        refreshedOnce = true
        await source.refresh(force: force)
        await evaluate()
    }

    private func evaluate() async {
        // Perezosa: con el interruptor apagado (bajo tests, hasta el lanzamiento) ni se mira el
        // consentimiento ni el SDK de anuncios; con cualquiera de los dos en contra, la compuerta
        // ya está cerrada.
        let remoteEnabled = await source.isEnabled
        var consent = false
        var underAge = false
        if remoteEnabled {
            consent = consentAllows()
            if consent { underAge = underAgeSignal() }
        }
        gate = PersonalizationGate(
            remoteEnabled: remoteEnabled,
            consentAllows: consent,
            underAgeSignal: underAge,
            arguments: arguments,
            isDebug: isDebug
        )
        lastEstimate = record.computation?.estimate
        guard gate.forcedSegment == nil, gate.isOpen else {
            segment = resolvedSegment()
            return
        }

        config = await source.current()
        guard let tables = config.section("player_value", as: PlayerValueTables.self), let player = player() else {
            lastEstimate = nil
            segment = resolvedSegment()
            return
        }
        let experiment = await activeExperiment()
        let variant = experiment.map { $0.arm == .model ? "model:\($0.model.version)" : "rules" } ?? "rules"
        let at = now()

        if needsComputation(tables: tables, variant: variant, at: at) {
            let context = await device()
            let inputs = PlayerValueInputsBuilder.inputs(
                player: player, storefront: context.storefront, deviceModel: context.model,
                sessions: record.sessions, now: at)
            let previous = record.computation?.segment
            let estimate = experiment?.arm == .model
                ? PlayerValue.evaluate(inputs, tables: tables, model: experiment?.model, previous: previous)
                : PlayerValue.evaluate(inputs, tables: tables, previous: previous)
            let src = estimate.source == .model ? Self.src(for: experiment?.model) : "rules"
            updateRecord { $0.computation = .init(estimate, src: src, variant: variant, computedAt: at) }
        }

        lastEstimate = record.computation?.estimate
        segment = resolvedSegment()
        reportSegment()
        if let experiment { expose(experiment) }
    }

    private func needsComputation(tables: PlayerValueTables, variant: String, at date: Date) -> Bool {
        guard let computation = record.computation else { return true }
        return !calendar.isDate(computation.computedAt, inSameDayAs: date)
            || computation.tablesVersion != tables.version
            || computation.variant != variant
    }

    private func resolvedSegment() -> PlayerSegment {
        #if DEBUG
        if let debugForcedSegment { return debugForcedSegment }
        #endif
        return gate.segment(ruled: lastEstimate?.segment)
    }

    /// `segment` sólo si el calculado no es el último informado.
    private func reportSegment() {
        guard let computation = record.computation, computation.segment != record.reportedSegment else { return }
        recordEvent(.segment(id: computation.segment, ver: computation.tablesVersion, src: computation.src))
        updateRecord { $0.reportedSegment = computation.segment }
    }

    // MARK: - El A/B de F6

    private struct ActiveExperiment {
        let arm: ExperimentBucket.Arm
        let model: TreeEnsemble
    }

    /// El brazo de esta instalación, si el A/B está prendido: sección `player_value_ab` válida y un
    /// modelo válido cuyas features existen.
    private func activeExperiment() async -> ActiveExperiment? {
        guard let experiment = config.section(PlayerValueExperiment.sectionKey, as: PlayerValueExperiment.self),
              let model = config.section(PlayerValueExperiment.modelSectionKey, as: TreeEnsemble.self),
              PlayerValueFeatures.supports(model) else { return nil }
        let id = await installId()
        let bucket = ExperimentBucket.bucket(installId: id, salt: experiment.salt)
        return ActiveExperiment(arm: ExperimentBucket.arm(bucket: bucket, split: experiment.split), model: model)
    }

    /// Una vez por sesión y brazo.
    private func expose(_ experiment: ActiveExperiment) {
        guard exposedArms.insert(experiment.arm.rawValue).inserted else { return }
        recordEvent(.exposure(exp: PlayerValueExperiment.experimentId, arm: experiment.arm.rawValue,
                              ver: experiment.model.version))
    }

    /// El `src` de un cálculo con modelo: `tree-<v>` (la versión del formato ya empieza así).
    static func src(for model: TreeEnsemble?) -> String {
        guard let version = model?.version else { return "rules" }
        return version.hasPrefix("tree-") ? version : "tree-\(version)"
    }

    // MARK: - El registro

    private var record: PersonalizationRecord {
        if let cachedRecord { return cachedRecord }
        let loaded = store.load()
        cachedRecord = loaded
        return loaded
    }

    private func updateRecord(_ change: (inout PersonalizationRecord) -> Void) {
        var updated = record
        change(&updated)
        guard updated != record else { return }
        cachedRecord = updated
        store.save(updated)
    }
}
