import Foundation
import Observation
import UIKit

/// Los tiempos de un viaje en cabina (PLAN-v2 E13, ítem 13). Puro: lo pinea `ElevatorRideTests`.
struct ElevatorRidePlan: Equatable {
    enum Direction: Equatable { case up, down }

    static let budget: Duration = .seconds(3)
    static let closeDuration: Duration = .milliseconds(750)
    static let openDuration: Duration = .milliseconds(650)
    static let travelBase: Duration = .milliseconds(500)
    static let travelPerFloor: Duration = .milliseconds(150)
    static let fadeDuration: Duration = .milliseconds(300)

    let origin: Int
    let destination: Int
    let close: Duration
    let travel: Duration
    let open: Duration
    /// Reduce Motion: puertas y fondos se funden, nada se desliza ni vibra.
    let fades: Bool

    init?(origin: Int, destination: Int, reduceMotion: Bool, instant: Bool, slowdown: Int = 1) {
        guard origin != destination else { return nil }
        self.origin = origin
        self.destination = destination
        fades = reduceMotion
        let times: (close: Duration, travel: Duration, open: Duration)
        if instant {
            times = (.zero, .zero, .zero)
        } else if reduceMotion {
            times = (Self.fadeDuration, Self.fadeDuration, Self.fadeDuration)
        } else {
            let wanted = Self.travelBase + Self.travelPerFloor * abs(destination - origin)
            times = (Self.closeDuration, min(wanted, Self.budget - Self.closeDuration - Self.openDuration),
                     Self.openDuration)
        }
        let factor = max(slowdown, 1)
        close = times.close * factor
        travel = times.travel * factor
        open = times.open * factor
    }

    var total: Duration { close + travel + open }
    var direction: Direction { destination > origin ? .up : .down }

    /// Los pisos que pasan por la ventana, en el orden en que pasan, puntas incluidas.
    var passingOrdinals: [Int] {
        origin < destination ? Array(origin...destination) : Array((destination...origin).reversed())
    }

    /// Dónde va la tira (ordinal continuo) a una fracción del tramo de viaje. Arranca y frena suave:
    /// los pisos del medio pasan más rápido.
    func position(atTravelProgress progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        let eased = t * t * (3 - 2 * t)
        return Double(origin) + Double(destination - origin) * eased
    }
}

/// El director del ascensor: la placa colgante y el viaje en cabina. Lo crea `FisuEvolutionApp`
/// y lo leen el HUD, el mapa y `ElevatorRideOverlay`.
@Observable @MainActor
final class ElevatorRide {
    enum Phase: Equatable { case idle, closing, traveling, opening }

    /// Los bordes que suenan. `ElevatorRideOverlay` los traduce a `AudioManager.SFX`.
    enum Cue: Equatable { case keypadOpen, keypadClose, button, doorsClose, motorStart, motorStop, cable, ding, doorsOpen }

    struct Hooks {
        var visibleOrdinal: @MainActor () -> Int
        var isUnlocked: @MainActor (Int) -> Bool
        var jump: @MainActor (Int) -> Void
        var cue: @MainActor (Cue) -> Void
        var sleep: @MainActor (Duration) async -> Void
        var reduceMotion: @MainActor () -> Bool
        var instant: Bool
        /// Sólo para UI tests: estira el viaje para poder saltearlo sin carrera.
        var slowdown = 1
    }

    /// Bajo `--uitest*` el viaje dura 0 s, salvo que el test lo pida con `--uitest-elevator-ride`.
    static var isInstantForUITests: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains { $0.hasPrefix("--uitest") } && !arguments.contains("--uitest-elevator-ride")
        #else
        return false
        #endif
    }

    /// `--uitest-elevator-ride-slow`: el viaje dura ×5.
    static var uiTestSlowdown: Int {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--uitest-elevator-ride-slow") ? 5 : 1
        #else
        1
        #endif
    }

    private(set) var phase: Phase = .idle
    private(set) var plan: ElevatorRidePlan?
    private(set) var phaseStartedAt: ContinuousClock.Instant = .now
    private(set) var isKeypadOpen = false
    /// El frame global del ícono del ascensor del HUD: de ahí cuelga la placa.
    var keypadAnchor: CGRect = .zero

    @ObservationIgnored private var hooks: Hooks?
    @ObservationIgnored private var pendingFromMap: Int?
    @ObservationIgnored private var rideTask: Task<Void, Never>?
    @ObservationIgnored private var jumped = false

    func attach(_ hooks: Hooks) { self.hooks = hooks }

    func openKeypad() {
        guard phase == .idle, !isKeypadOpen else { return }
        isKeypadOpen = true
        hooks?.cue(.keypadOpen)
    }

    func closeKeypad() {
        guard isKeypadOpen else { return }
        isKeypadOpen = false
        hooks?.cue(.keypadClose)
    }

    /// Un botón de la placa.
    func select(ordinal: Int) {
        if isKeypadOpen {
            isKeypadOpen = false
            hooks?.cue(.button)
        }
        start(to: ordinal)
    }

    /// Una fila del mapa: el viaje arranca cuando el mapa termina de irse (`startPendingRide`).
    func requestFromMap(ordinal: Int) {
        guard phase == .idle else { return }
        pendingFromMap = ordinal
    }

    func startPendingRide() {
        guard let ordinal = pendingFromMap else { return }
        pendingFromMap = nil
        start(to: ordinal)
    }

    /// Tocar la pantalla durante el viaje: directo a la llegada.
    func skip() {
        guard phase != .idle, let plan else { return }
        rideTask?.cancel()
        rideTask = nil
        if !jumped { hooks?.jump(plan.destination) }
        if phase != .opening {
            hooks?.cue(.motorStop)
            hooks?.cue(.ding)
        }
        finish()
    }

    func waitUntilIdle() async { await rideTask?.value }

    private func start(to destination: Int) {
        guard phase == .idle, let hooks, hooks.isUnlocked(destination),
              let plan = ElevatorRidePlan(origin: hooks.visibleOrdinal(), destination: destination,
                                          reduceMotion: hooks.reduceMotion(), instant: hooks.instant,
                                          slowdown: hooks.slowdown)
        else { return }
        guard plan.total > .zero else {
            hooks.jump(destination)
            return
        }
        self.plan = plan
        jumped = false
        // La fase entra en el acto (no adentro del Task): un segundo pedido en el mismo cuadro
        // ya encuentra el viaje en curso, y la vista arranca a cerrar sin esperar un tick.
        enter(.closing)
        hooks.cue(.doorsClose)
        rideTask = Task { [weak self] in await self?.run(plan, hooks) }
    }

    private func run(_ plan: ElevatorRidePlan, _ hooks: Hooks) async {
        await hooks.sleep(plan.close)
        guard !Task.isCancelled else { return }
        enter(.traveling)
        hooks.jump(plan.destination)
        jumped = true
        hooks.cue(.motorStart)
        hooks.cue(.cable)
        await hooks.sleep(plan.travel)
        guard !Task.isCancelled else { return }
        hooks.cue(.motorStop)
        hooks.cue(.ding)
        enter(.opening)
        hooks.cue(.doorsOpen)
        await hooks.sleep(plan.open)
        guard !Task.isCancelled else { return }
        finish()
    }

    private func enter(_ next: Phase) {
        phase = next
        phaseStartedAt = .now
    }

    private func finish() {
        phase = .idle
        plan = nil
        rideTask = nil
    }
}

/// Qué suena en cada borde del viaje. Puro: lo traduce `AudioManager.play(_ cue:)` y lo pinea un test.
enum ElevatorSound: Equatable {
    case oneShot(AudioManager.SFX, AudioManager.Gain?)
    case startLoop(AudioManager.SFX)
    case stopLoop(AudioManager.SFX)

    var sfx: AudioManager.SFX {
        switch self {
        case .oneShot(let sfx, _), .startLoop(let sfx), .stopLoop(let sfx): sfx
        }
    }
}

extension ElevatorRide.Cue {
    static let all: [ElevatorRide.Cue] = [.keypadOpen, .keypadClose, .button, .doorsClose, .motorStart, .motorStop, .cable, .ding, .doorsOpen]

    var sound: ElevatorSound {
        switch self {
        case .keypadOpen, .keypadClose: .oneShot(.elevatorSpring, .action)
        case .button: .oneShot(.elevatorClick, .action)
        case .doorsClose, .doorsOpen: .oneShot(.elevatorDoors, .action)
        case .motorStart: .startLoop(.elevatorMotor)
        case .motorStop: .stopLoop(.elevatorMotor)
        case .cable: .oneShot(.elevatorCable, .action)
        case .ding: .oneShot(.elevatorDing, nil)
        }
    }
}
