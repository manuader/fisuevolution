import SwiftUI

/// Lo que dibuja la placa colgante, resuelto y puro (PLAN-v2 E13, ítem 13).
struct ElevatorKeypadModel: Equatable {
    struct Floor: Identifiable, Equatable {
        let id: String
        let ordinal: Int
        let isCurrent: Bool
        var number: Int { ordinal + 1 }
    }

    static let maxButtons = 10

    /// De arriba abajo, sólo los abiertos.
    let floors: [Floor]

    /// `map` viene de Dios para abajo (`GameState.floorMap`).
    init(map: [FloorMapEntry], visibleOrdinal: Int) {
        floors = map.filter(\.isUnlocked).prefix(Self.maxButtons).map {
            Floor(id: $0.id, ordinal: $0.ordinal, isCurrent: $0.ordinal == visibleOrdinal)
        }
    }
}

enum ElevatorKeypadLayout {
    static let maxButtonSide: CGFloat = 46
    static let minButtonSide: CGFloat = 34
    static let spacing: CGFloat = 8
    static let platePadding: CGFloat = 12
    static let springHeight: CGFloat = 24

    static func buttonSide(count: Int, availableHeight: CGFloat) -> CGFloat {
        guard count > 0 else { return maxButtonSide }
        let room = availableHeight - springHeight - platePadding * 2 - spacing * CGFloat(count - 1)
        return min(maxButtonSide, max(minButtonSide, (room / CGFloat(count)).rounded(.down)))
    }

    static func plateSize(count: Int, buttonSide: CGFloat) -> CGSize {
        CGSize(width: buttonSide + platePadding * 2,
               height: CGFloat(count) * buttonSide + CGFloat(max(0, count - 1)) * spacing + platePadding * 2)
    }
}

/// Los tonos del LED del ascensor: la cabina (T5) y la columna de premios (E7b-b T3) los comparten.
enum ElevatorLED {
    static let screen = Color(red: 0.11, green: 0.10, blue: 0.09)
    static let lit = Color(red: 1.0, green: 0.64, blue: 0.18)
}

// MARK: - La placa

/// La placa de acero que cuelga de un resorte: una columna, un botón redondo por piso abierto.
struct ElevatorKeypad: View {
    let model: ElevatorKeypadModel
    let buttonSide: CGFloat
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            GameIcon(artKey: "ui_elevator_spring", size: ElevatorKeypadLayout.springHeight) {
                SpringCoil()
            }
            VStack(spacing: ElevatorKeypadLayout.spacing) {
                ForEach(model.floors) { floor in
                    ElevatorKeypadButton(floor: floor, side: buttonSide) { onSelect(floor.id) }
                }
            }
            .padding(ElevatorKeypadLayout.platePadding)
            .background(MetalPlate(cornerRadius: 16))
            .background {
                Color.clear
                    .accessibilityElement()
                    .accessibilityIdentifier("hud.elevator.keypad")
                    .accessibilityLabel(Text("elevator.keypad.ax"))
                    .accessibilityValue(Text(verbatim: String(model.floors.count)))
            }
        }
    }
}

/// El botón de un piso: el número y nada más; el actual brilla amarillo con su destello.
struct ElevatorKeypadButton: View {
    let floor: ElevatorKeypadModel.Floor
    let side: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(face)
                Circle().strokeBorder(MetalTone.dark, lineWidth: 3)
                Circle().strokeBorder(MetalTone.bevel.opacity(0.9), lineWidth: 1).padding(3)
                Text(verbatim: String(floor.number))
                    .font(.system(size: side * 0.48, weight: .black, design: .rounded))
                    .foregroundStyle(Color("PaletteInk"))
            }
            .frame(width: side, height: side)
            .shadow(color: floor.isCurrent ? Color("PaletteYellow").opacity(0.9) : .black.opacity(0.2),
                    radius: floor.isCurrent ? 8 : 2, y: floor.isCurrent ? 0 : 1)
            .overlay(alignment: .leading) {
                if floor.isCurrent { Sparkle().offset(x: -side * 0.42) }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hud.elevator.keypad.floor.\(floor.id)")
        .accessibilityLabel(Text("elevator.floor.ax \(String(floor.number)) \(TowerNaming.displayName(for: floor.id, isUnlocked: true))"))
        .accessibilityValue(floor.isCurrent ? Text("elevator.floor.current") : Text(verbatim: ""))
    }

    private var face: LinearGradient {
        floor.isCurrent
            ? LinearGradient(colors: [Color("PaletteYellow"), Color("PaletteOrange")], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [.white, Color("PaletteCream")], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Piezas

/// El resorte: cinco espiras aplastadas, del metal claro al oscuro.
private struct SpringCoil: View {
    private let coils = 5

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<coils, id: \.self) { index in
                let t = Double(index) / Double(coils - 1)
                Ellipse()
                    .fill(LinearGradient(colors: [MetalTone.light, MetalTone.dark.opacity(0.4 + 0.6 * t)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Ellipse().strokeBorder(Color("PaletteInk"), lineWidth: 1.5))
                    .frame(width: 22, height: ElevatorKeypadLayout.springHeight / CGFloat(coils) + 2)
                    .padding(.bottom, -2)
            }
        }
        .frame(height: ElevatorKeypadLayout.springHeight)
        .accessibilityHidden(true)
    }
}

/// Tres trazos cortos en abanico a la izquierda del botón actual; pulsa una sola vez al aparecer.
private struct Sparkle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        let rays = ZStack {
            ForEach([-28.0, 0, 28], id: \.self) { angle in
                Capsule()
                    .fill(Color("PaletteYellow"))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 1))
                    .frame(width: 9, height: 3.5)
                    .offset(x: -9)
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
        .onAppear { appeared = true }

        if reduceMotion {
            rays
        } else {
            rays.keyframeAnimator(initialValue: 1.0, trigger: appeared) { view, scale in
                view.scaleEffect(scale, anchor: .trailing)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1.35, duration: 0.18)
                    CubicKeyframe(1.0, duration: 0.25)
                }
            }
        }
    }
}

#Preview("2 pisos") {
    KeypadPreview(count: 2)
}

#Preview("10 pisos") {
    KeypadPreview(count: 10)
}

private struct KeypadPreview: View {
    let count: Int

    var body: some View {
        let ids = ["god_realm", "galaxy", "solar", "mars", "moon", "island", "luxury", "corporate", "urban", "alley"]
        let map = ids.suffix(count).enumerated().map { index, id in
            FloorMapEntry(id: id, ordinal: count - 1 - index, backgroundKey: "bg_\(id)",
                          occupied: 0, capacity: 10, isUnlocked: true, isVisible: false)
        }
        let model = ElevatorKeypadModel(map: map, visibleOrdinal: max(0, count - 2))
        let side = ElevatorKeypadLayout.buttonSide(count: count, availableHeight: 480)
        ElevatorKeypad(model: model, buttonSide: side) { _ in }
            .padding()
            .background(Color("PaletteBlue"))
    }
}
