import SwiftUI

/// La geometría de la columna de sellos de la esquina de arriba a la izquierda.
enum SideRailLayout {
    /// El sello (C9: ~56 pt); el objetivo de toque lo agranda a `touchWidth`.
    static let seal: CGFloat = 56
    static let touchWidth: CGFloat = 62
    static let ribbonHeight: CGFloat = 19
    /// Cuánto se monta la cinta sobre el pie del sello.
    static let ribbonOverlap: CGFloat = 7
    /// Entre sello y sello: es lo único que se achica si el alto no alcanza.
    static let spacing: CGFloat = 4
    static let edgeInset: CGFloat = Tokens.s4
}

/// La columna de premios (PLAN-v2 E14 C9): siempre a la vista, uno debajo del
/// otro, bajo el HUD y pegada al borde izquierdo. Cada sello lleva debajo su
/// cinta de estado. Los que todavía no existen (nada que cobrar ni reloj que
/// mostrar) no se dibujan y entran con animación cuando aparecen (D8). Lee
/// `sideRail` y toca por `sideRailTapped(_:)`: no decide nada.
///
/// ⚠️ Ni los sellos ni la tarjeta del video prenden `uiCoversBoard`: los
/// videos piden el tablero libre (`canOffer*`) y se taparían a sí mismos.
struct SideRailView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// La tarjeta del video abierta. Vive afuera: el toque en el tablero la cierra.
    @Binding var offer: SideRailKind?

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.s8) {
            column
            if let offer {
                SideRailOfferCard(kind: offer) { self.offer = nil }
                    .id(offer)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: offer)
        .onChange(of: gameState.sideRail) { _, rail in
            offer = SideRailOffer.kept(offer, in: rail)
        }
        .onChange(of: gameState.celebrationHidesUI) { _, hides in
            if hides { offer = nil }
        }
    }

    private var column: some View {
        VStack(spacing: SideRailLayout.spacing) {
            ForEach(shown) { item in
                RailSeal(item: item) { tapped(item.kind) }
                    .transition(reduceMotion
                        ? .opacity
                        : .scale(scale: 0.3, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.25),
                   value: shown.map(\.kind))
        .tutorialAnchor(.sideRail, when: !shown.isEmpty)
    }

    /// Los sellos disponibles. El que una lección señala se queda aunque esté
    /// apagado: el ancla tiene que existir.
    private var shown: [SideRailItem] {
        gameState.sideRail.shownItems(lessonTarget: gameState.tutorialTip?.lesson.anchorTarget)
    }

    /// Si abre algo, la tarjeta del video se cierra; si ofrece un video, se
    /// abre al lado; si no había nada, el sello tiembla.
    private func tapped(_ kind: SideRailKind) -> Bool {
        gameState.sideRailOpened()
        switch gameState.sideRailTapped(kind) {
        case .acted:
            offer = nil
            return true
        case .offer:
            offer = kind
            return true
        case .refused:
            return false
        }
    }
}

extension SideRailState {
    /// Los sellos que se dibujan: los disponibles (D8). El que una lección
    /// señala se queda aunque esté apagado, porque el ancla tiene que existir.
    func shownItems(lessonTarget: TutorialTarget?) -> [SideRailItem] {
        guard isVisible else { return [] }
        return items.filter { $0.status != .idle || $0.kind.tutorialTarget == lessonTarget }
    }
}

/// Un sello de la columna: el arte grande con el "!" (o el número) y, debajo,
/// la cinta con su estado.
struct RailSeal: View {
    let item: SideRailItem
    /// `false` = no había nada que hacer: el sello tiembla.
    let tap: () -> Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes = 0

    private var isReady: Bool {
        if case .ready = item.status { return true }
        return false
    }

    var body: some View {
        Button {
            if !tap(), !reduceMotion { shakes += 1 }
        } label: {
            VStack(spacing: -SideRailLayout.ribbonOverlap) {
                face
                RailRibbon(status: item.status)
            }
            .frame(width: SideRailLayout.touchWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(RailShake(trigger: shakes))
        .tutorialAnchor(item.kind.tutorialTarget)
        .accessibilityIdentifier("siderail.\(item.kind.rawValue)")
        .accessibilityLabel(Text(LocalizedStringKey("siderail.\(item.kind.rawValue).ax")))
        .accessibilityValue(Text(verbatim: SideRailAX.value(item.status)))
    }

    private var face: some View {
        SideRailGlyph(kind: item.kind)
            .frame(width: SideRailLayout.seal, height: SideRailLayout.seal)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            .overlay(alignment: .topTrailing) {
                if case .ready(let count) = item.status {
                    SideRailBadge(text: count.map { $0 > 9 ? "9+" : String($0) } ?? "!")
                        .scaleEffect(0.85)
                        .offset(x: 3, y: -2)
                }
            }
            .modifier(ReadyPulse(active: isReady && !reduceMotion))
    }
}

/// La cinta de estado bajo el sello: «¡Listo!» cuando se puede usar, el reloj en
/// el LED del ascensor cuando falta, «Lleno» si no entra.
struct RailRibbon: View {
    let status: SideRailStatus

    var body: some View {
        content
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, Tokens.s4)
            .frame(width: SideRailLayout.seal + 2, height: SideRailLayout.ribbonHeight)
            .background(background)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var content: some View {
        switch status {
        case .ready:
            Text("siderail.ready").foregroundStyle(.white)
        case .blocked:
            Text("prize.package.full").foregroundStyle(.white)
        case .waiting(let seconds):
            Text(verbatim: SideRailClock.text(seconds) { String(localized: "siderail.hours \(String($0))") })
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(ElevatorLED.lit)
        case .idle:
            Text(verbatim: " ")
        }
    }

    @ViewBuilder private var background: some View {
        switch status {
        case .ready:
            PillBackground(fill: Color("PaletteGreen"), lip: 2)
        case .blocked:
            PillBackground(fill: Color("PaletteOrange"), lip: 2)
        case .waiting, .idle:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ElevatorLED.screen)
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color("PaletteBrown"), lineWidth: 2))
        }
    }
}

/// El "!" (o el número) naranja del sello.
struct SideRailBadge: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, 2)
            .background(
                Capsule()
                    .fill(Color("PaletteOrange"))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 2))
            )
            .accessibilityHidden(true)
    }
}

/// El latido de lo que está listo. Sólo mientras lo está y sin Reduce Motion:
/// nada de un `repeatForever` incondicional.
struct ReadyPulse: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([1.0, 1.08]) { view, scale in
                view.scaleEffect(scale)
            } animation: { _ in
                .easeInOut(duration: 0.7)
            }
        } else {
            content
        }
    }
}

/// Un "no" con la cabeza, como el paquete trabado de E5b.
private struct RailShake: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-5, duration: 0.06)
                CubicKeyframe(5, duration: 0.06)
                CubicKeyframe(-3, duration: 0.06)
                CubicKeyframe(0, duration: 0.06)
            }
        }
    }
}

/// Con la tarjeta de un video abierta, tocar el tablero la cierra (como el
/// selector del atajo). Sin tarjeta no existe: no atrapa ningún toque.
struct SideRailTapAway: ViewModifier {
    @Binding var offer: SideRailKind?

    func body(content: Content) -> some View {
        content.background {
            if offer != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { offer = nil }
                    .accessibilityHidden(true)
            }
        }
    }
}
