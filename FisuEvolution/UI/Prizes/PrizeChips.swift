import SwiftUI

/// Los paquetes que esperan, tocables desde arriba: cuántos, y "LLENO" si
/// ninguno entra (el paquete se queda: PLAN-v2 §2).
struct PackageChip: View {
    let count: Int
    let blocked: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes = 0

    var body: some View {
        Button {
            if blocked, !reduceMotion { shakes += 1 }
            action()
        } label: {
            HStack(spacing: 6) {
                GameIcon(artKey: "pickup_package", size: 30) { PackageGlyph() }
                Text(verbatim: blocked ? String(localized: "prize.package.full") : "×\(count)")
                    .font(Tokens.body)
                    .monospacedDigit()
                    .foregroundStyle(blocked ? Color("PaletteOrange") : Color("PaletteInk"))
            }
            .prizeChipBackground()
        }
        .buttonStyle(.plain)
        .chipShake(shakes)
        .accessibilityIdentifier("prize.chip.package")
        .tutorialAnchor(.sidePackages)
        // Dos `Text` y no un ternario adentro de uno: con el ternario, Swift elige
        // el `init` de `String` y la clave se lee cruda.
        .accessibilityLabel(blocked ? Text("prize.package.full.ax") : Text("prize.package.ax \(String(count))"))
        .accessibilityValue(Text(verbatim: blocked ? "full" : String(count)))
    }
}

/// El colchón esperando, con su "!" que late.
struct MattressChip: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                GameIcon(artKey: "pickup_mattress", size: 30) { MattressGlyph() }
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color("PaletteOrange"))
                    .scaleEffect(pulse && !reduceMotion ? 1.15 : 1)
            }
            .prizeChipBackground()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("prize.chip.mattress")
        .accessibilityLabel(Text("prize.mattress.ax"))
        .tutorialAnchor(.sideMattress)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// La caja de la Aduana dibujada, mientras no llegue `pickup_package` (E8).
struct PackageGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color("PaletteBrown"))
            Rectangle().fill(Color("PaletteYellow")).frame(width: 5)
            Rectangle().fill(Color("PaletteYellow")).frame(height: 5)
            RoundedRectangle(cornerRadius: 4).strokeBorder(Color("PaletteInk"), lineWidth: 1.5)
        }
        .padding(3)
        .accessibilityHidden(true)
    }
}

/// El colchón dibujado, mientras no llegue `pickup_mattress` (E8).
struct MattressGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color("PaletteBlue").opacity(0.8))
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Color("PaletteCream")).frame(width: 4, height: 4)
                }
            }
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color("PaletteInk"), lineWidth: 1.5)
        }
        .aspectRatio(1.6, contentMode: .fit)
        .padding(2)
        .accessibilityHidden(true)
    }
}

private extension View {
    /// La cápsula de los chips del escenario (la misma que el del visitante, E4b).
    func prizeChipBackground() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            )
            .contentShape(Capsule())
    }

    /// Un "no" con la cabeza: el paquete trabado tiembla al tocarlo.
    func chipShake(_ trigger: Int) -> some View {
        modifier(ChipShake(trigger: trigger))
    }
}

private struct ChipShake: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-6, duration: 0.06)
                CubicKeyframe(6, duration: 0.06)
                CubicKeyframe(-4, duration: 0.06)
                CubicKeyframe(0, duration: 0.06)
            }
        }
    }
}
