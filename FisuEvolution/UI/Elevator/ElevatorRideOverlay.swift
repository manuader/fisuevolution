import SwiftUI

/// La capa del ascensor, por encima de `RootView` (la monta `FisuEvolutionApp`): el viaje en
/// cabina y, desde E13b T8, la placa colgante. Fuera del viaje y con la placa cerrada no
/// existe en el árbol: no come toques ni AX, y no crea nada con efectos.
struct ElevatorRideOverlay: View {
    @Environment(ElevatorRide.self) private var ride

    var body: some View {
        ZStack {
            if ride.phase != .idle, let plan = ride.plan {
                ElevatorRideView(ride: ride, plan: plan, art: ElevatorCabinArt.shared)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: ride.phase == .idle)
        .onChange(of: ride.isKeypadOpen) { _, isOpen in
            if isOpen {
                ElevatorCabinWarmup.shared.prepare()
            } else if ride.phase == .idle {
                ElevatorCabinWarmup.shared.release()
            }
        }
    }
}

extension AudioManager {
    /// El motor del ascensor sale del sintetizador ~8 dB más fuerte que el resto: se baja al tocarlo.
    private static let elevatorMotorGain: Float = 0.4

    func play(_ cue: ElevatorRide.Cue) {
        switch cue {
        case .keypadOpen, .keypadClose: play(.elevatorSpring)
        case .button: play(.elevatorClick)
        case .doorsClose, .doorsOpen: play(.elevatorDoors)
        case .motorStart: play(.elevatorMotor, gain: Self.elevatorMotorGain)
        case .motorStop: stop(.elevatorMotor)
        case .ding: play(.elevatorDing)
        }
    }
}
