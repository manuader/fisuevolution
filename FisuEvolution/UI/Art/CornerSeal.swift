import SwiftUI

/// El sello de las esquinas (E14 C9/C19): estrella dentada del color de la
/// casa, disco crema con el ícono del premio y, debajo, una cinta con el reloj o
/// el conteo. Es la familia de los sellos de premios (izquierda) y del sello de
/// oferta (derecha, reemplaza al chip): tocarlo abre su pantalla de premio.
///
/// El estado manda la cara (C29): listo lleva el «!» que late, en curso el
/// reloj en la cinta, bloqueado va gris y hecho lleva el tilde.
struct CornerSeal: View {
    /// Lo que dice la cinta de abajo, ya formateado por el llamador.
    enum Caption: Equatable {
        /// Un reloj ("12:04"): lleva el ícono del reloj.
        case timer(String)
        /// Un conteo o una palabra corta ("×3", "¡Abrir!").
        case text(String)

        var text: String {
            switch self {
            case .timer(let text), .text(let text): text
            }
        }

        var glyph: GameGlyph? {
            if case .timer = self { return .clock }
            return nil
        }
    }

    let glyph: GameGlyph
    var tint: Color = Color("PaletteOrange")
    let state: ProgressState
    var caption: Caption?
    var side: CGFloat = CornerSeal.defaultSide
    let identifier: String
    /// Qué es el sello ("Paquete de la Aduana"); el estado y la cinta se suman solos.
    let accessibilityLabel: Text
    let action: () -> Void

    static let defaultSide: CGFloat = 60

    /// El lado tocable: nunca por debajo de 44 pt (D14), aunque el dibujo sea chico.
    static func hitSide(for side: CGFloat) -> CGFloat { max(side, 44) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: -Tokens.s8) {
                medal
                if let caption {
                    CaptionRibbon(caption: caption, maxWidth: side * 1.25)
                }
            }
            .frame(minWidth: Self.hitSide(for: side), minHeight: Self.hitSide(for: side))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(spokenValue)
    }

    private var spokenValue: Text {
        let state = Text(self.state.spokenKey)
        guard let caption else { return state }
        return state + Text(verbatim: ", \(caption.text)")
    }

    private var medal: some View {
        ZStack {
            SealBurst().fill(tint.deepened(0.45))
            SealBurst()
                .fill(LinearGradient(stops: [
                    .init(color: tint.lifted(0.3), location: 0),
                    .init(color: tint.lifted(0.3), location: 0.5),
                    .init(color: tint, location: 0.5),
                    .init(color: tint, location: 1)
                ], startPoint: .top, endPoint: .bottom))
                .padding(side * 0.06)
            Circle()
                .fill(Color("PaletteCream"))
                .overlay(Circle().strokeBorder(tint.deepened(0.45), lineWidth: 2.5))
                .frame(width: side * 0.66, height: side * 0.66)
            GameGlyphView(glyph: glyph, size: side * 0.56)
        }
        .frame(width: side, height: side)
        .saturation(state == .locked ? 0 : 1)
        .opacity(state == .locked ? 0.75 : 1)
        .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
        .overlay(alignment: .topTrailing) {
            switch state {
            case .ready: ReadyBang(size: side * 0.36).offset(x: 3, y: -3)
            case .done: GameGlyphView(glyph: .check, size: side * 0.36).offset(x: 3, y: -3)
            case .running, .locked: EmptyView()
            }
        }
    }
}

/// La cinta crema del sello, con el reloj si es un temporizador.
private struct CaptionRibbon: View {
    let caption: CornerSeal.Caption
    let maxWidth: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            if let glyph = caption.glyph {
                GameGlyphView(glyph: glyph, size: 13)
            }
            Text(verbatim: caption.text)
                .font(Tokens.caption)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(maxWidth: maxWidth)
        .fixedSize(horizontal: true, vertical: false)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color("PaletteCream"))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color("PaletteBrown"), lineWidth: 2)
                )
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// La estrella dentada del sello: `points` puntas alternando dos radios.
struct SealBurst: Shape {
    var points = 16
    /// El radio de los valles, como fracción del de las puntas.
    var innerRatio: CGFloat = 0.86

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let count = max(points, 3) * 2
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                                y: center.y + radius * CGFloat(sin(angle)))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
