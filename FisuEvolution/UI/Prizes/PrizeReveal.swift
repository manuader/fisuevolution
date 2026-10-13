import SwiftUI

/// El «después» de toda pantalla de premio (E14 C4): el premio ganado grande,
/// con sus rayos detrás, un pop de partículas al aparecer y el monto o la
/// duración debajo. El botón de cobrar lo pone quien lo muestra.
struct PrizeReveal: View {
    let kind: RewardKind
    /// El monto o lo que se ganó, ya resuelto.
    let text: String
    var size: CGFloat = 96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false

    var body: some View {
        VStack(spacing: Tokens.s4) {
            ZStack {
                RewardIllustration(kind: kind, size: size)
                    .scaleEffect(popped ? 1 : 0.4)
                PrizePop()
            }
            Text(verbatim: text)
                .font(Tokens.display)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { popped = true; return }
            withAnimation(.spring(duration: 0.45, bounce: 0.45)) { popped = true }
        }
    }
}

/// Las chispas del pop: salen del centro, se abren y se apagan. No ocupan
/// lugar (son `offset`), y con Reduce Motion no hay nada que mover.
struct PrizePop: View {
    static let count = 14
    private static let colors = ["PaletteYellow", "PaletteOrange", "PalettePink", "PaletteBlue", "PaletteGreen"]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst = false

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<Self.count, id: \.self) { index in
                    spark(index)
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.9)) { burst = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func spark(_ index: Int) -> some View {
        let angle = Double(index) / Double(Self.count) * 2 * .pi + Double(index % 3) * 0.18
        let distance = 64 + CGFloat(index % 4) * 14
        return Circle()
            .fill(Color(Self.colors[index % Self.colors.count]))
            .overlay(Circle().strokeBorder(Color("PaletteInk").opacity(0.6), lineWidth: 1))
            .frame(width: 9, height: 9)
            .scaleEffect(burst ? 0.3 : 1)
            .offset(x: burst ? CGFloat(cos(angle)) * distance : 0, y: burst ? CGFloat(sin(angle)) * distance : 0)
            .opacity(burst ? 0 : 1)
    }
}
