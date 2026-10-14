import SwiftUI

/// Se ganó un paquete (E14 C28): su ilustración vuela del centro de la pantalla
/// —donde estaba el popup que lo dio— hasta el sello de Paquetes de la columna
/// de premios, y el sello recibe un pulso. Si el sello todavía no existe (la
/// columna lo dibuja con su propio reloj) espera un poco; si no aparece, no hay
/// vuelo y queda el aviso de arriba. Con Reduce Motion no vuela.
struct PackageFlight: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// El marco del sello de Paquetes, en este espacio; `nil` si no está dibujado.
    let seal: CGRect?
    let container: CGSize

    @State private var sealFrame: CGRect?
    @State private var flying = false
    @State private var launched = false
    @State private var pulsing = false

    static let artSide: CGFloat = 96
    private static let seconds = 0.7

    var body: some View {
        ZStack {
            if flying, let target = sealFrame {
                RewardArt(kind: .package)
                    .frame(width: Self.artSide, height: Self.artSide)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    .scaleEffect(launched ? 0.4 : 1.1)
                    .position(launched ? CGPoint(x: target.midX, y: target.midY) : CGPoint(x: container.width / 2, y: container.height / 2))
            }
            if pulsing, let target = sealFrame {
                SealBurst()
                    .stroke(Color("PaletteYellow"), lineWidth: 4)
                    .frame(width: target.width, height: target.width)
                    .scaleEffect(pulsing ? 1.35 : 1)
                    .opacity(pulsing ? 0 : 1)
                    .position(x: target.midX, y: target.midY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: seal, initial: true) { _, frame in sealFrame = frame ?? sealFrame }
        .onChange(of: gameState.packageWin) { _, win in
            guard win != nil, !reduceMotion else { return }
            Task { await fly() }
        }
    }

    private func fly() async {
        for _ in 0..<10 where sealFrame == nil { try? await Task.sleep(for: .milliseconds(150)) }
        guard sealFrame != nil else { return }
        launched = false
        flying = true
        try? await Task.sleep(for: .milliseconds(50))
        withAnimation(.easeIn(duration: Self.seconds)) { launched = true }
        try? await Task.sleep(for: .seconds(Self.seconds))
        flying = false
        launched = false
        pulsing = false
        withAnimation(.easeOut(duration: 0.5)) { pulsing = true }
        try? await Task.sleep(for: .milliseconds(500))
        pulsing = false
    }
}
