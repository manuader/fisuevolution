import SwiftUI

/// El globo del tutorial: pose del Fisura + texto + progreso, en la gramática
/// v3 entera — pergamino con su luz, borde tono-sobre-tono, dots caramelo — y
/// con el retrato GRANDE pisando el borde de la tarjeta, como componen las
/// referencias.
///
/// Es horizontal y compacto —y no el Fisura de 300×380 con el globo arriba que
/// había antes— porque tiene que convivir con el recorte sin taparlo.
///
/// No hay "Saltar" (PLAN-v2 §2: el tutorial no se saltea). Un paso de explicar
/// lleva su `TutorialConfirmButton`, que espera el candado; uno de acción no
/// lleva botón: avanza haciéndolo. "Terminar repaso" (`onEnd`) existe sólo en
/// el repaso pedido desde Ajustes (E9b).
struct TutorialCard: View {
    let step: TutorialStep
    let index: Int
    let total: Int
    let unlocked: Bool
    let lockProgress: () -> Double
    let confirmKey: String
    let onConfirm: () -> Void
    var onEnd: (() -> Void)?
    /// La versión de coach-mark de las hojas: retrato chico y sin puntos de progreso.
    var compact = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                portrait
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(step.textKey))
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !compact || onEnd != nil {
                        HStack(spacing: 10) {
                            if !compact { dots }
                            Spacer(minLength: 8)
                            if let onEnd { endButton(onEnd) }
                        }
                    }
                }
            }
            if step.clockKind == .explain {
                TutorialConfirmButton(
                    titleKey: LocalizedStringKey(confirmKey),
                    identifier: confirmKey,
                    unlocked: unlocked,
                    progress: lockProgress,
                    action: onConfirm
                )
                // Aire propio además del `spacing` del VStack: pegado a los
                // dots y al borde de la tarjeta el botón se leía embutido
                // (corrección del dueño sobre captura, 2026-08-21).
                .padding(.top, Tokens.s8)
                .padding(.bottom, Tokens.s4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // Materiales v3: pergamino con su luz —claridad arriba, sombra
            // cálida abajo, la receta de `PanelCard` a escala de tarjeta— y
            // borde tono-sobre-tono. Conserva la sombra grande porque flota
            // sobre el scrim oscuro, donde ese peso es lo que la despega.
            parchment
        )
    }

    private var parchment: some View {
        let shape = RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
        return shape
            .fill(Color("PaletteParchment"))
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            .clear,
                            Color("PaletteBrown").opacity(0.10),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(0.55), lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
    }

    /// Sólo poses del Fisura, y GRANDE: la pose pisa el borde superior de la
    /// tarjeta (el `offset` sobresale sin mover el layout — la tarjeta no
    /// recorta). Sin atlas se cae a las otras poses sanas, y si no hay ninguna
    /// el globo habla solo: el SF Symbol de persona gris murió con la regla
    /// "sólo fotos del Fisura".
    @ViewBuilder private var portrait: some View {
        if let art = UIArt.image(step.pose) ?? UIArt.image("fisura_wave") ?? UIArt.image("fisura_celebrate") {
            art.resizable()
                .scaledToFit()
                .frame(width: compact ? 54 : 96, height: compact ? 66 : 112)
                .offset(y: compact ? 0 : -12)
                .accessibilityHidden(true)
        }
    }

    /// "Terminar repaso" (E9b): vive DENTRO del globo, chico y apagado, donde
    /// vivía el viejo "Saltar".
    private func endButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("tutorial.replay.end")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Color("PaletteInk").opacity(0.55))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color("PaletteInk").opacity(0.09)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tutorial.replay.end")
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                // El activo es una pill caramelo en miniatura: relleno con luz
                // y borde hundido del mismo tono (v3), no un chip plano.
                Capsule()
                    .fill(
                        i == index
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color("PaletteOrange").lifted(), Color("PaletteOrange")],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            : AnyShapeStyle(Color("PaletteInk").opacity(0.18))
                    )
                    .overlay {
                        if i == index {
                            Capsule().strokeBorder(Color("PaletteOrange").deepened(), lineWidth: 1.5)
                        }
                    }
                    .frame(width: i == index ? 20 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("tutorial.progress.label"))
        .accessibilityValue(Text(verbatim: "\(index + 1)/\(total)"))
    }
}

/// "Entendido" (o "¡Vamos!" en el cierre): se llena durante el candado y recién
/// ahí confirma. Nunca se deshabilita: con el candado puesto, tiembla. Con
/// Reduce Motion el relleno salta de a 0,5 s y no tiembla.
struct TutorialConfirmButton: View {
    let titleKey: LocalizedStringKey
    let identifier: String
    let unlocked: Bool
    let progress: () -> Double
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes = 0

    var body: some View {
        let still = reduceMotion
        return Button {
            if unlocked { action() } else { shakes += 1 }
        } label: {
            // Con el candado abierto el relleno ya está lleno: el reloj se pausa y no
            // redibuja a 30 Hz mientras el jugador lee.
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 30, paused: unlocked)) { _ in
                let fill = unlocked ? 1 : min(max(progress(), 0), 1)
                Text(titleKey)
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                PillBackground(fill: Color("PaletteGreen").opacity(0.45))
                                PillBackground(fill: Color("PaletteGreen"))
                                    .frame(width: max(proxy.size.height, proxy.size.width * fill))
                                    .opacity(fill > 0 ? 1 : 0)
                            }
                        }
                    }
                    .contentShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .keyframeAnimator(initialValue: 0.0, trigger: shakes) { content, x in
            content.offset(x: still ? 0 : x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-8, duration: 0.06)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(-4, duration: 0.06)
                LinearKeyframe(0, duration: 0.06)
            }
        }
        .accessibilityIdentifier(identifier)
        .accessibilityValue(Text(verbatim: unlocked ? "unlocked" : "locked"))
    }
}
