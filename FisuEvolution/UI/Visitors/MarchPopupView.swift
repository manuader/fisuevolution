import EconomyKit
import SwiftUI

/// Los dos popups de la Marcha del Puntero (E14b B25), en el contenedor de la casa y aparte de
/// `GamePopups` (con un eslabón más en su cadena el type-checker se rinde).
struct MarchPopups: ViewModifier {
    @Environment(GameState.self) private var gameState

    func body(content: Content) -> some View {
        content
            .gamePopup(item: binding) { popup in
                MarchPopupView(kind: popup)
            }
    }

    /// Sin Marcha en el save no hay nada que mostrar, aunque quede el pedido colgado (`advanceMarch`
    /// lo limpia en el próximo tick).
    private var binding: Binding<MarchPopup?> {
        Binding(
            get: { gameState.march == nil ? nil : gameState.marchPopup },
            set: { if $0 == nil { gameState.closeMarchStatus() } }
        )
    }
}

/// El estado (al tocar el chip): la cara del Puntero, «Marcha 137/420», la barra de toques y el
/// reloj. El final: su festejo y «Cobrar» (el vuelo de B13 y después el ×2 de B29), o su línea de
/// derrota y «Entendido». El final no se cierra sin resolverse: la X hace lo mismo que el botón.
struct MarchPopupView: View {
    let kind: MarchPopup
    @Environment(GameState.self) private var gameState
    @State private var now = Date().timeIntervalSince1970
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private static let portraitSide: CGFloat = 96

    var body: some View {
        if let march = gameState.march, let content = gameState.content,
           let script = content.visitors.script(id: march.scriptId),
           let visitor = content.visitors.visitor(id: script.visitor) {
            let resolved = kind == .result && march.outcome != nil
            PopupContainer(
                verbatim: VisitCopy.name(of: visitor), ribbonTint: Color("PaletteBlue"),
                onClose: {
                    if resolved { _ = gameState.settleMarch() } else { gameState.closeMarchStatus() }
                },
                closeIdentifier: resolved ? "marcha.result.close" : "marcha.status.close"
            ) {
                AnimatedArtView(clip: .portrait(visitor.id), role: .popup) {
                    VisitorFace(visitorId: visitor.id, side: Self.portraitSide)
                }
                .frame(width: Self.portraitSide, height: Self.portraitSide)
                if resolved {
                    line(VisitCopy.marchLine(for: script, won: march.outcome == .won))
                        .accessibilityIdentifier(march.outcome == .won ? "marcha.result.won" : "marcha.result.lost")
                    if march.outcome == .won {
                        RewardArt(kind: .blue)
                            .frame(width: 56, height: 56)
                            .accessibilityHidden(true)
                    }
                } else {
                    status(march)
                }
            } actions: {
                if resolved {
                    if march.outcome == .won {
                        GameButton("marcha.claim", role: .blue, identifier: "marcha.result.claim") {
                            _ = gameState.settleMarch()
                        }
                    } else {
                        GameButton("marcha.ok", role: .neutral, medallion: .none, identifier: "marcha.result.ok") {
                            _ = gameState.settleMarch()
                        }
                    }
                }
            }
            .onReceive(timer) { _ in now = Date().timeIntervalSince1970 }
        }
    }

    @ViewBuilder
    private func status(_ march: MarchState) -> some View {
        VStack(spacing: Tokens.s8) {
            Text("marcha.chip \(String(march.taps)) \(String(march.goal))")
                .font(.system(size: 22, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
            ProgressView(value: march.progress)
                .tint(Color("PaletteBlue"))
                .frame(maxWidth: 220)
            Text("marcha.status.remaining \(MarchClock.text(march.remaining(at: now)))")
                .font(Tokens.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
            Text("marcha.status.hint")
                .font(Tokens.prose)
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("marcha.status")
    }

    /// El globo del Puntero, con la cola hacia el retrato (como el del visitante).
    private func line(_ text: String) -> some View {
        Text(verbatim: text)
            .font(Tokens.prose)
            .foregroundStyle(Color("PaletteInk"))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Tokens.s12)
            .padding(.top, BubbleGeometry.tailHeight)
            .background(
                BubbleShape(tailFraction: 0.5)
                    .rotation(.degrees(180))
                    .fill(Color("PaletteCream"))
                    .overlay(BubbleShape(tailFraction: 0.5).rotation(.degrees(180))
                        .stroke(Color("PaletteInk"), lineWidth: 2))
            )
    }
}
