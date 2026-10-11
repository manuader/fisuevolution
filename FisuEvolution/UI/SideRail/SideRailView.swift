import SwiftUI

/// La geometría de la columna plegable: la de la botonera del ascensor,
/// espejada contra el borde izquierdo.
enum SideRailLayout {
    /// "Premios" mide lo que el ícono del ascensor del HUD.
    static let restSide: CGFloat = 44
    static let button: CGFloat = 30
    static let glyph: CGFloat = 20
    /// Una celda: el botón y, debajo, su reloj en LED ("12:05").
    static let cellWidth: CGFloat = 36
    static let spacing: CGFloat = 6
    /// Contra el borde, como la botonera contra el suyo.
    static let edgeInset: CGFloat = Tokens.s12
    static let gapAboveBottomBar: CGFloat = 10
    /// 3 s y no los 2 de la botonera: lo pidió el dueño para ésta.
    static var collapseDelay: Duration {
        #if DEBUG
        // Los UI tests miden los marcos de los cuatro botones, y consultarlos lleva más que 3 s.
        if ProcessInfo.processInfo.arguments.contains("--uitest-rail-hold") { return .seconds(60) }
        #endif
        return .seconds(3)
    }
}

/// La columna lateral plegable (PLAN-v2 §2; opción C del dueño). En reposo, un
/// solo botón "Premios" con el "!" sumado; al tocarlo se despliega la persiana
/// con la Ruleta, El Colchón, los Paquetes y Fusionar todo, que se recoge sola a
/// los 3 s sin uso o al tocar uno. Lee `sideRail` y toca por
/// `sideRailTapped(_:)`: no decide nada.
///
/// ⚠️ Ni la persiana ni la tarjeta del video prenden `uiCoversBoard`: los
/// videos piden el tablero libre (`canOffer*`) y se taparían a sí mismos.
struct SideRailView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// La tarjeta del video abierta. Vive afuera: el toque en el tablero la cierra.
    @Binding var offer: SideRailKind?
    @State private var expanded = false
    /// Cada toque reinicia la cuenta de los 3 s (el mecanismo de la botonera).
    @State private var activity = 0

    var body: some View {
        Group {
            if gameState.sideRail.isVisible {
                column(gameState.sideRail)
            }
        }
        .onChange(of: gameState.sideRail.isVisible) { _, visible in
            guard !visible else { return }
            fold()
        }
        .onChange(of: gameState.celebrationHidesUI) { _, hides in
            if hides { fold() }
        }
    }

    private func column(_ rail: SideRailState) -> some View {
        VStack(alignment: .leading, spacing: Tokens.s4) {
            if expanded {
                shutter(rail)
                    .transition(reduceMotion
                        ? .opacity
                        : .scale(scale: 0.2, anchor: .bottomLeading).combined(with: .opacity))
            }
            restButton(rail)
                .overlay(alignment: .bottomLeading) {
                    // Con la persiana recogida, la tarjeta sale al lado de "Premios".
                    if let offer {
                        SideRailOfferCard(kind: offer) { self.offer = nil }
                            .fixedSize()
                            .offset(x: SideRailLayout.restSide + Tokens.s12)
                            .transition(.opacity)
                    }
                }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35), value: expanded)
        .animation(.easeInOut(duration: 0.2), value: offer)
        .task(id: activity) {
            guard expanded else { return }
            try? await Task.sleep(for: SideRailLayout.collapseDelay)
            guard !Task.isCancelled else { return }
            expanded = false
        }
    }

    private func fold() {
        expanded = false
        offer = nil
    }

    // MARK: "Premios", en reposo

    private func restButton(_ rail: SideRailState) -> some View {
        Button {
            offer = nil
            if expanded { expanded = false } else { unfold() }
        } label: {
            GameIcon(artKey: "siderail_prizes", size: 28) { VectorTabGiftsIcon() }
                .frame(width: SideRailLayout.restSide, height: SideRailLayout.restSide)
                .background(MetalPlate(cornerRadius: 12))
                .overlay(alignment: .topTrailing) {
                    if rail.readyCount > 0 {
                        SideRailBadge(text: String(rail.readyCount))
                            .offset(x: 6, y: -6)
                    }
                }
                .modifier(ReadyPulse(active: rail.readyCount > 0 && !expanded && !reduceMotion))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tutorialAnchor(.sideRail)
        .modifier(RestingLessonAnchors(active: !expanded))
        .accessibilityIdentifier("siderail.toggle")
        .accessibilityLabel(Text("siderail.toggle.ax"))
        .accessibilityValue(Text(verbatim: String(rail.readyCount)))
    }

    // MARK: La persiana

    private func shutter(_ rail: SideRailState) -> some View {
        let rows = stride(from: 0, to: rail.items.count, by: 2).map {
            Array(rail.items[$0 ..< min($0 + 2, rail.items.count)])
        }
        // `Grid` y no `LazyVGrid`, por lo mismo que la botonera: la perezosa se
        // lleva puestos los identifiers.
        return Grid(horizontalSpacing: SideRailLayout.spacing, verticalSpacing: SideRailLayout.spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { item in
                        SideRailButton(item: item) { tapped(item.kind) }
                    }
                }
            }
        }
        .padding(Tokens.s8)
        .background(MetalPlate(cornerRadius: 14))
    }

    private func unfold() {
        expanded = true
        activity &+= 1
    }

    /// Si abre algo u ofrece un video, la persiana se recoge (la tarjeta sale al
    /// lado de "Premios"); si no había nada, el botón tiembla y la persiana se
    /// queda 3 s más.
    private func tapped(_ kind: SideRailKind) -> Bool {
        switch gameState.sideRailTapped(kind) {
        case .acted:
            expanded = false
            offer = nil
            return true
        case .offer:
            expanded = false
            offer = kind
            return true
        case .refused:
            activity &+= 1
            return false
        }
    }
}

/// Con la persiana recogida, las lecciones de los paquetes y del colchón
/// (E5b T5) señalan a "Premios": sus botones no están a la vista.
private struct RestingLessonAnchors: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content
                .tutorialAnchor(.sidePackages)
                .tutorialAnchor(.sideMattress)
        } else {
            content
        }
    }
}

/// Un botón de la persiana: redondo como los de la botonera, con el glifo, el
/// "!" (o el número) y, debajo, su reloj en el LED del ascensor.
struct SideRailButton: View {
    let item: SideRailItem
    /// `false` = no había nada que hacer: el botón tiembla.
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
            VStack(spacing: 3) {
                face
                led
            }
            .frame(width: SideRailLayout.cellWidth)
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
            .frame(width: SideRailLayout.glyph, height: SideRailLayout.glyph)
            .frame(width: SideRailLayout.button, height: SideRailLayout.button)
            .background(
                Circle()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.85), Color("PaletteCream")],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(Color("PaletteInk").opacity(0.85), lineWidth: 2))
            )
            .opacity(item.status == .idle ? 0.55 : 1)
            .overlay(alignment: .topTrailing) {
                if case .ready(let count) = item.status {
                    SideRailBadge(text: count.map { $0 > 9 ? "9+" : String($0) } ?? "!")
                        .scaleEffect(0.8)
                        .offset(x: 5, y: -5)
                }
            }
            .modifier(ReadyPulse(active: isReady && !reduceMotion))
    }

    /// El reloj, con los tonos del display del ascensor. Listo o apagado, la
    /// pantalla queda oscura: el "!" ya lo dice.
    private var led: some View {
        Group {
            switch item.status {
            case .waiting(let seconds):
                Text(verbatim: SideRailClock.text(seconds) { String(localized: "siderail.hours \(String($0))") })
            case .blocked: Text("prize.package.full")
            case .ready, .idle: Text(verbatim: " ")
            }
        }
        .font(.system(size: 9, weight: .heavy, design: .monospaced))
        .foregroundStyle(ElevatorLED.lit)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(width: SideRailLayout.cellWidth, height: 12)
        .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(ElevatorLED.screen))
        .accessibilityHidden(true)
    }
}

/// El "!" (o el número) naranja de la columna. El de "Premios" suma los avisos
/// de los cuatro.
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
private struct ReadyPulse: ViewModifier {
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

// MARK: - En la pantalla

/// La columna colgada del borde de arriba de la franja de abajo, contra el
/// borde izquierdo de la pantalla: el espejo de la botonera del ascensor.
/// Vive en un `ViewModifier` porque `RootView.body` está al límite del
/// type-checker.
struct SideRailMount: ViewModifier {
    @Binding var offer: SideRailKind?

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            SideRailView(offer: $offer)
                .fixedSize()
                .alignmentGuide(.top) { $0[.bottom] + SideRailLayout.gapAboveBottomBar }
                .padding(.leading, SideRailLayout.edgeInset)
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
