import SwiftUI

/// Lo que dibuja la botonera, resuelto y puro (lo pinea `ElevatorPanelModelTests`).
struct ElevatorPanelModel: Equatable {
    struct Floor: Identifiable, Equatable {
        let id: String
        /// 1 en el callejón: el número que se lee en el botón y en el display.
        let number: Int
        let isUnlocked: Bool
        /// Todos sus lugares ocupados: el piso "en marcha" (PLAN-v2 §2). La luz
        /// verde; E2a le cuelga el bonus de ingresos.
        let isStaffed: Bool
    }

    /// De arriba abajo, como se lee una botonera.
    let floors: [Floor]

    /// `map` viene de Dios para abajo (`GameState.floorMap`).
    init(map: [FloorMapEntry]) {
        floors = map.map { entry in
            Floor(
                id: entry.id,
                number: entry.ordinal + 1,
                isUnlocked: entry.isUnlocked,
                isStaffed: entry.isUnlocked && entry.capacity > 0 && entry.occupied >= entry.capacity
            )
        }
    }

    /// Cuánto brilla el botón de un piso con la cámara en `cameraFloor` (ordinal
    /// continuo): 1 en el piso, 0 a un piso o más. Así la luz viaja entre los
    /// botones siguiendo la cámara en vez de saltar.
    static func glow(forOrdinal ordinal: Int, cameraFloor: Double) -> Double {
        max(0, 1 - abs(cameraFloor - Double(ordinal)))
    }
}

/// La botonera del ascensor (PLAN-v2 §2 y E3): el cartel del piso en un display
/// LED sobre una placa de metal, y una persiana con un botón por piso.
///
/// En reposo sólo se ve el display. Se despliega al tocarlo o al cambiar de piso
/// y se recoge sola a los 2 s sin uso. ⚠️ Fuera de sus controles no toca nada:
/// el deslizamiento del tablero que arranca al lado de la botonera sigue siendo
/// del tablero (spike S6); uno que arranca sobre la placa es de la placa.
struct ElevatorPanel: View {
    @Environment(GameState.self) private var gameState
    @Environment(AudioManager.self) private var audio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    /// Cada toque o cambio de piso reinicia la cuenta de los 2 s.
    @State private var activity = 0

    /// Alto del display con su placa: la fila del HUD lo reserva para que el
    /// display nunca se encime con lo que va debajo.
    static let displayHeight: CGFloat = 44
    static let collapseDelay: Duration = .seconds(2)

    private static let ledScreen = Color(red: 0.11, green: 0.10, blue: 0.09)
    private static let ledLit = Color(red: 1.0, green: 0.64, blue: 0.18)

    /// Dónde está la luz: la cámara, que viaja entre pisos.
    private var lightPosition: Double { gameState.cameraFloor }

    var body: some View {
        let navigation = gameState.towerNavigation
        VStack(alignment: .trailing, spacing: Tokens.s4) {
            display(navigation)
            if expanded {
                shutter
                    .transition(reduceMotion
                        ? .opacity
                        : .scale(scale: 0.2, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35), value: expanded)
        .onChange(of: navigation.ordinal) { _, _ in unfold() }
        .task(id: activity) {
            guard expanded else { return }
            try? await Task.sleep(for: Self.collapseDelay)
            guard !Task.isCancelled else { return }
            expanded = false
        }
    }

    // MARK: El display

    private func display(_ navigation: GameState.TowerNavigation) -> some View {
        Button {
            if expanded { expanded = false } else { unfold() }
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: "\(navigation.ordinal + 1)")
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(navigation.ordinal)))
                Text(verbatim: "·")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                Text(verbatim: TowerNaming.floorName(for: navigation.floorID))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(Self.ledLit)
            .shadow(color: Self.ledLit.opacity(0.8), radius: 3)
            .padding(.horizontal, Tokens.s8)
            .frame(maxWidth: 146, minHeight: Self.displayHeight - 10)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Self.ledScreen))
            .padding(5)
            .background(MetalPlate(cornerRadius: 12))
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: navigation.ordinal)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hud.elevator.display")
        .accessibilityLabel(Text("elevator.display.label"))
        // El id crudo del piso, como `board.floor`: el runner corre en inglés.
        .accessibilityValue(Text(verbatim: navigation.floorID))
    }

    // MARK: La persiana

    private var shutter: some View {
        // Se re-evalúa con el tablero: una contratación o un merge cambian la
        // ocupación, y con ella la luz verde.
        let _ = gameState.boardVersion
        let model = ElevatorPanelModel(map: gameState.floorMap)
        let rows = stride(from: 0, to: model.floors.count, by: 2).map {
            Array(model.floors[$0 ..< min($0 + 2, model.floors.count)])
        }
        // `Grid` y no `LazyVGrid`: la perezosa se lleva puestos los identifiers
        // cuando el árbol de AX se arma antes de la celda (medido en la T11 del
        // rediseño, ver `MenuView`).
        return Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { floor in
                        ElevatorFloorButton(
                            floor: floor,
                            glow: ElevatorPanelModel.glow(forOrdinal: floor.number - 1, cameraFloor: lightPosition)
                        ) {
                            select(floor)
                        }
                    }
                }
            }
        }
        .padding(Tokens.s8)
        .background(MetalPlate(cornerRadius: 14))
        .animation(.linear(duration: 0.125), value: lightPosition)
    }

    private func unfold() {
        expanded = true
        activity &+= 1
    }

    private func select(_ floor: ElevatorPanelModel.Floor) {
        unfold()
        guard floor.isUnlocked else {
            gameState.playHaptic(.error)
            return
        }
        audio.play(.elevatorDing)
        gameState.jumpToFloor(ordinal: floor.number - 1)
    }
}

/// Un botón de la botonera: redondo, de metal, con el número (o el candado) y la
/// luz del piso donde está la cámara. El punto verde es "en marcha".
private struct ElevatorFloorButton: View {
    let floor: ElevatorPanelModel.Floor
    let glow: Double
    let action: () -> Void

    /// 30 pt (spike S6): con 34 la grilla de diez pisos se comía casi la mitad
    /// de la pantalla del SE desplegada.
    private static let side: CGFloat = 30

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.85), Color("PaletteCream")],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(Color("PaletteInk").opacity(0.85), lineWidth: 2))
                Circle()
                    .fill(Color(red: 1.0, green: 0.64, blue: 0.18))
                    .opacity(glow * 0.85)
                    .padding(3)
                if floor.isUnlocked {
                    Text(verbatim: "\(floor.number)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color("PaletteInk"))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color("PaletteInk").opacity(0.55))
                }
            }
            .overlay(alignment: .topTrailing) {
                if floor.isStaffed {
                    Circle()
                        .fill(Color("PaletteGreen"))
                        .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 1.5))
                        .frame(width: 10, height: 10)
                        .offset(x: 2, y: -2)
                }
            }
            .frame(width: Self.side, height: Self.side)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hud.elevator.floor.\(floor.id)")
        .accessibilityLabel(Text("elevator.floor.ax \(String(floor.number)) \(TowerNaming.floorName(for: floor.id))"))
        .accessibilityValue(floor.isUnlocked
            ? (floor.isStaffed ? Text("elevator.floor.staffed") : Text(verbatim: ""))
            : Text("elevator.floor.locked"))
    }
}
