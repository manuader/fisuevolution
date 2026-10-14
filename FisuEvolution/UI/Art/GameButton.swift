import SwiftUI

/// El botón de la casa de E14 (C19): cuerpo con volumen —cara clara arriba,
/// labio oscuro abajo, contorno grueso tono sobre tono— y un **medallón** crema
/// a la izquierda con el ícono del juego (`GameGlyph`, nunca un SF Symbol). El
/// color dice la función, no el gusto de cada pantalla. Reemplaza, pantalla por
/// pantalla (T11–T25), a `PricePill` y al botón de `RewardedOfferButton`
/// (la cápsula `ActionPill` ya no existe).
///
/// Como `PricePill`, nunca usa `.disabled`: `available: false` lo pone crema,
/// lo hace temblar al tocarlo y la acción corre igual (el estado decide).
struct GameButton: View {
    /// La función del botón, que elige el color (C19).
    enum Role: CaseIterable {
        /// Verde: gratis o cobrar.
        case free
        /// Naranja: cuesta plata del juego.
        case coins
        /// Celeste: cuesta dólar blue.
        case blue
        /// Rojo: mirá un video.
        case video
        /// Crema: lo secundario ("No, gracias", "Después").
        case neutral

        var fill: Color {
            switch self {
            case .free: Color("PaletteGreen")
            case .coins: Color("PaletteOrange")
            case .blue: Color("PaletteBlue")
            case .video: GameTint.alert
            case .neutral: Color("PaletteCream")
            }
        }

        /// El ícono que lleva si el llamador no pide otro.
        var defaultMedallion: GameGlyph? {
            switch self {
            case .free: .check
            case .coins: .coin
            case .blue: .blue
            case .video: .video
            case .neutral: nil
            }
        }

        var titleColor: Color { self == .neutral ? Color("PaletteInk") : .white }
    }

    enum Size {
        /// El botón principal de un popup o una fila destacada.
        case regular
        /// El de una fila de lista; nunca baja de 44 pt (D14).
        case compact

        var minHeight: CGFloat { self == .regular ? 52 : 44 }
        var medallionSide: CGFloat { self == .regular ? 36 : 30 }
        var font: Font { self == .regular ? Tokens.title : Tokens.body }
    }

    /// Qué va en el medallón: el de la función, otro glifo o ninguno.
    enum Medallion: Equatable {
        case automatic
        case glyph(GameGlyph)
        case none
    }

    private let title: Text
    private let role: Role
    private let medallion: Medallion
    private let size: Size
    private let fullWidth: Bool
    private let available: Bool
    private let strikeText: String?
    private let identifier: String
    private let accessibilityLabel: Text?
    private let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// El pie de un `PopupContainer` lo prende: ahí todos los botones reparten el ancho.
    @Environment(\.gameButtonFillsWidth) private var fillsWidthFromContainer
    @State private var shake = 0

    private var fillsWidth: Bool { fullWidth || fillsWidthFromContainer }

    init(
        _ titleKey: LocalizedStringKey, role: Role, medallion: Medallion = .automatic, size: Size = .regular,
        fullWidth: Bool = false, available: Bool = true, strikeText: String? = nil,
        identifier: String, accessibilityLabel: Text? = nil, action: @escaping () -> Void
    ) {
        self.init(title: Text(titleKey), role: role, medallion: medallion, size: size, fullWidth: fullWidth,
                  available: available, strikeText: strikeText, identifier: identifier,
                  accessibilityLabel: accessibilityLabel, action: action)
    }

    /// Un título ya resuelto: un monto (`CoinFormatter`), un precio de StoreKit,
    /// una frase interpolada.
    init(
        verbatim title: String, role: Role, medallion: Medallion = .automatic, size: Size = .regular,
        fullWidth: Bool = false, available: Bool = true, strikeText: String? = nil,
        identifier: String, accessibilityLabel: Text? = nil, action: @escaping () -> Void
    ) {
        self.init(title: Text(verbatim: title), role: role, medallion: medallion, size: size, fullWidth: fullWidth,
                  available: available, strikeText: strikeText, identifier: identifier,
                  accessibilityLabel: accessibilityLabel, action: action)
    }

    private init(
        title: Text, role: Role, medallion: Medallion, size: Size, fullWidth: Bool, available: Bool,
        strikeText: String?, identifier: String, accessibilityLabel: Text?, action: @escaping () -> Void
    ) {
        self.title = title
        self.role = role
        self.medallion = medallion
        self.size = size
        self.fullWidth = fullWidth
        self.available = available
        self.strikeText = strikeText
        self.identifier = identifier
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    /// El glifo que termina en el medallón. Expuesto para los tests.
    var medallionGlyph: GameGlyph? {
        switch medallion {
        case .automatic: role.defaultMedallion
        case .glyph(let glyph): glyph
        case .none: nil
        }
    }

    /// Sin saldo, el cuerpo pasa a crema: el "no te alcanza" de la casa.
    private var bodyRole: Role { available ? role : .neutral }

    var body: some View {
        Button {
            if !available, !reduceMotion { shake += 1 }
            action()
        } label: {
            label
        }
        .buttonStyle(GameButtonPress())
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(spokenLabel)
        .keyframeAnimator(initialValue: 0.0, trigger: shake) { view, dx in
            view.offset(x: dx)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-4, duration: 0.07)
                CubicKeyframe(4, duration: 0.08)
                CubicKeyframe(-3, duration: 0.08)
                CubicKeyframe(0, duration: 0.07)
            }
        }
    }

    private var spokenLabel: Text {
        let base = accessibilityLabel ?? title
        guard let strikeText else { return base }
        return base + Text(verbatim: ", ") + Text("price.ax.was \(strikeText)")
    }

    private var label: some View {
        HStack(spacing: Tokens.s8) {
            if let glyph = medallionGlyph {
                medallionView(glyph)
            }
            VStack(spacing: -2) {
                if let strikeText {
                    StrikePrice(text: strikeText,
                                color: bodyRole.titleColor.opacity(bodyRole == .neutral ? 0.6 : 0.8))
                }
                title
                    .font(size.font)
                    .monospacedDigit()
                    .foregroundStyle(bodyRole.titleColor)
                    .shadow(color: .black.opacity(bodyRole == .neutral ? 0 : 0.4), radius: 0, y: 1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .padding(.leading, medallionGlyph == nil ? Tokens.s16 : 6)
        .padding(.trailing, Tokens.s16)
        .frame(minWidth: fillsWidth ? 0 : 96, maxWidth: fillsWidth ? .infinity : nil, minHeight: size.minHeight - GameButtonMetrics.lip)
        .background(
            PillBackground(
                fill: bodyRole.fill,
                border: bodyRole == .neutral ? Color("PaletteBrown").opacity(0.75) : nil,
                cornerRadius: GameButtonMetrics.cornerRadius,
                lip: GameButtonMetrics.lip,
                splitFace: true,
                borderWidth: 3
            )
            .padding(.bottom, -GameButtonMetrics.lip)
        )
        // El labio se dibuja por debajo de la cara (padding negativo en el fondo)
        // y este padding le reserva su lugar: el alto total es `size.minHeight`.
        .padding(.bottom, GameButtonMetrics.lip)
        .saturation(available ? 1 : 0.7)
        .contentShape(Rectangle())
    }

    private func medallionView(_ glyph: GameGlyph) -> some View {
        let side = size.medallionSide
        let ring = bodyRole == .neutral ? Color("PaletteBrown") : bodyRole.fill.deepened()
        return GameGlyphView(glyph: glyph, size: side * 0.7)
            .frame(width: side, height: side)
            .background(
                Circle()
                    .fill(Color("PaletteCream"))
                    .overlay(Circle().strokeBorder(ring, lineWidth: 2.5))
            )
    }
}

extension EnvironmentValues {
    /// Los `GameButton` de adentro llenan el ancho que les den (el pie del popup).
    @Entry var gameButtonFillsWidth = false
}

enum GameButtonMetrics {
    static let cornerRadius: CGFloat = 16
    /// El labio de apoyo: lo que "hunde" el botón al tocarlo.
    static let lip: CGFloat = 4
}

/// El toque de la casa: el cuerpo baja sobre su labio, sin el atenuado del
/// sistema (que deja el texto blanco sobre color ilegible).
private struct GameButtonPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? GameButtonMetrics.lip / 2 : 0)
            .animation(.snappy(duration: 0.1), value: configuration.isPressed)
    }
}
