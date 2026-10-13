import SwiftUI

/// Los cuatro estados de toda fila, sello o tarjeta del juego (E14 C29,
/// principio 4): los mismos colores y los mismos íconos en todas las pantallas.
/// El orden de una lista lo decide el estado —listo › en curso › bloqueado ›
/// hecho—, no el catálogo (principio 2).
enum ProgressState: CaseIterable, Comparable, Sendable {
    /// Para cobrar ya: verde, con el «!» que late.
    case ready
    /// Corre con reloj.
    case running
    /// Todavía no: gris, con lo que falta.
    case locked
    /// Cobrado o comprado al máximo: el tilde, al fondo.
    case done

    var glyph: GameGlyph? {
        switch self {
        case .ready: nil
        case .running: .clock
        case .locked: .lock
        case .done: .check
        }
    }

    var tint: Color {
        switch self {
        case .ready: Color("PaletteGreen")
        case .running: Color("PaletteOrange")
        case .locked: CardMaterials.lockedBorder
        case .done: Color("PaletteGreen")
        }
    }

    /// Cómo se viste la `GameCard` de la fila: `GameCard(style: state.cardStyle()) { … }`.
    func cardStyle<Content: View>() -> GameCard<Content>.Style {
        switch self {
        case .ready: .highlighted(Color("PaletteGreen"))
        case .running, .done: .normal
        case .locked: .locked
        }
    }

    /// Lo que VoiceOver dice del estado (principio 8).
    var spokenKey: LocalizedStringKey {
        switch self {
        case .ready: "state.ready.ax"
        case .running: "state.running.ax"
        case .locked: "state.locked.ax"
        case .done: "state.done.ax"
        }
    }
}

extension Sequence {
    /// Ordena por estado (estable: dentro de un estado, el orden de llegada).
    func sortedByProgress(_ state: (Element) -> ProgressState) -> [Element] {
        enumerated()
            .sorted { lhs, rhs in
                let (a, b) = (state(lhs.element), state(rhs.element))
                return a == b ? lhs.offset < rhs.offset : a < b
            }
            .map(\.element)
    }
}

/// La etiqueta del estado: el ícono custom y un texto corto ya resuelto
/// ("12 min", "Te faltan 40 blue", "Desde el piso 3", "¡Listo!"). Informa, no es
/// un control: la acción va en un `GameButton`.
struct StateTag: View {
    let state: ProgressState
    let text: String

    var body: some View {
        HStack(spacing: Tokens.s4) {
            if let glyph = state.glyph {
                GameGlyphView(glyph: glyph, size: 16)
            } else {
                ReadyBang(size: 16, beats: false)
            }
            Text(verbatim: text)
                .font(Tokens.caption)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Color("PaletteInk").opacity(state == .locked ? 0.7 : 1))
        .padding(.leading, 6)
        .padding(.trailing, Tokens.s8 + 2)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(fill)
                .overlay(Capsule().strokeBorder(border, lineWidth: 2))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(state.spokenKey) + Text(verbatim: ", \(text)"))
    }

    private var fill: Color {
        state == .locked ? CardMaterials.lockedFill : state.tint.opacity(0.2)
    }

    private var border: Color {
        state == .locked ? CardMaterials.lockedBorder : state.tint.deepened(0.25).opacity(0.8)
    }
}

/// El «!» rosa de "hay algo para cobrar" (C29). Late tres veces al aparecer y
/// se queda quieto: nada de `repeatForever` (vive en el tablero toda la sesión).
/// Con Reduce Motion, quieto desde el principio.
struct ReadyBang: View {
    var size: CGFloat = 20
    var beats = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trigger = 0

    var body: some View {
        Text(verbatim: "!")
            .font(.system(size: size * 0.68, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Color("PalettePink"))
                    .overlay(Circle().strokeBorder(.white, lineWidth: max(1.5, size * 0.11)))
            )
            .keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1.25, duration: 0.16)
                    CubicKeyframe(1.0, duration: 0.22)
                    CubicKeyframe(1.25, duration: 0.16)
                    CubicKeyframe(1.0, duration: 0.22)
                    CubicKeyframe(1.25, duration: 0.16)
                    CubicKeyframe(1.0, duration: 0.22)
                }
            }
            .onAppear {
                guard beats, !reduceMotion else { return }
                trigger += 1
            }
            .accessibilityHidden(true)
    }
}
