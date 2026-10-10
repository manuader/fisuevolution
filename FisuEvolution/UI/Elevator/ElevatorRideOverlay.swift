import EconomyKit
import SwiftUI

/// La capa del ascensor, por encima de `RootView` (la monta `FisuEvolutionApp`): el viaje en
/// cabina y, desde E13b T8, la placa colgante. Fuera del viaje y con la placa cerrada no
/// existe en el árbol: no come toques ni AX, y no crea nada con efectos.
struct ElevatorRideOverlay: View {
    @Environment(ElevatorRide.self) private var ride
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if ride.isKeypadOpen {
                ElevatorKeypadLayer(ride: ride, gameState: gameState)
                    .transition(reduceMotion ? .opacity
                        : .scale(scale: 0.05, anchor: .top).combined(with: .opacity))
            }
            if ride.phase != .idle, let plan = ride.plan {
                ElevatorRideView(ride: ride, plan: plan, art: ElevatorCabinArt.shared)
                    .accessibilityAddTraits(.isModal)
                    .transition(.opacity)
            }
        }
        .suspendsVideoPool(ride.phase != .idle, reason: .elevatorRide)
        .animation(.easeOut(duration: 0.2), value: ride.phase == .idle)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.35),
                   value: ride.isKeypadOpen)
        // Una celebración que toma el turno (una hoja, el cofre) recoge la placa. Si llega en pleno
        // viaje, el viaje termina: las hojas se presentan por encima de esta capa y taparían la
        // cabina a la mitad.
        .onChange(of: gameState.showing) { old, showing in
            // Sólo cuando una celebración que cubre toma el turno: la lección de la propia placa
            // (`.tutorialTip`) y los avisos chicos no la cierran.
            guard old == nil, showing?.coversElevator == true else { return }
            ride.closeKeypad()
            ride.skip()
        }
        .onChange(of: ride.isKeypadOpen) { _, isOpen in
            if isOpen {
                ElevatorCabinWarmup.shared.prepare()
            } else if ride.phase == .idle {
                ElevatorCabinWarmup.shared.release()
            }
        }
    }
}

extension CelebrationKind {
    /// Las que se presentan como hoja o tapan todo el tablero: con ellas la placa y la cabina sobran.
    var coversElevator: Bool {
        switch self {
        case .offlineEarnings, .dailyReward, .careerChoice, .skinAward, .specialDrop, .chestOpening, .boardCelebration, .cinematic: true
        case .visitorEncounter, .achievements, .towerNotice, .tutorialTip: false
        }
    }
}

/// La placa colgada del ícono del HUD y la capa que la recoge al tocar afuera.
private struct ElevatorKeypadLayer: View {
    let ride: ElevatorRide
    let gameState: GameState

    /// La barra de abajo y el aire que la placa le deja.
    private static var bottomReserve: CGFloat { GameTabBar.barHeight + GameTabBar.bottomFloor + 16 }

    var body: some View {
        GeometryReader { proxy in
            let model = ElevatorKeypadModel(map: gameState.floorMap, visibleOrdinal: gameState.visibleFloorOrdinal)
            let origin = proxy.frame(in: .global).origin
            let anchor = ride.keypadAnchor.offsetBy(dx: -origin.x, dy: -origin.y)
            let top = anchor.maxY + 2
            let side = ElevatorKeypadLayout.buttonSide(
                count: model.floors.count, availableHeight: proxy.size.height - top - Self.bottomReserve)
            let width = ElevatorKeypadLayout.plateSize(count: model.floors.count, buttonSide: side).width
            let left = min(max(anchor.midX - width / 2, Tokens.s8), proxy.size.width - width - Tokens.s8)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { ride.closeKeypad() }
                    .accessibilityHidden(true)
                ElevatorKeypad(model: model, buttonSide: side) { id in
                    guard let floor = model.floors.first(where: { $0.id == id }) else { return }
                    ride.select(ordinal: floor.ordinal)
                }
                .offset(x: left, y: top)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { ride.closeKeypad() }
    }
}

extension AudioManager {
    /// El motor es un ambiente (-18 dB, con fundido al cortar): el viaje lo arranca y lo para.
    func play(_ cue: ElevatorRide.Cue) {
        switch cue.sound {
        case .oneShot(let sfx, let gain?): play(sfx, gain: gain)
        case .oneShot(let sfx, nil): play(sfx)
        case .startLoop(let sfx): startAmbient(sfx)
        case .stopLoop(let sfx): stopAmbient(sfx)
        }
    }
}
