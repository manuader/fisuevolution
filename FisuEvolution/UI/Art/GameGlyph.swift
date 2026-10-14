import SwiftUI

/// Los íconos de uso general del juego (E14 C19): ningún control visible lleva
/// un SF Symbol. Cada glifo es una **cadena de claves** del atlas —la nueva de
/// E14 primero y, mientras no esté integrada, una hermana que ya existe— y al
/// final un vectorial dibujado de la casa. Cuando T3 integra el arte, la clave
/// entra sola y el glifo cambia sin tocar código.
enum GameGlyph: Equatable, Sendable {
    case video
    case clock
    case lock
    case check
    case coin
    /// El dólar blue (C8). Hasta que entre `ui_dolar_blue`, el ORO de siempre.
    case blue
    case gift
    case chest
    case wheel
    case package
    case offerMoving
    case offerWelcome
    case offerRebirth
    // Los de uso general que reemplazan a los SF Symbols (T25): dibujados,
    // sin clave de atlas hasta que el arte los integre.
    case close
    case cart
    case trophy
    case pencil
    case chevron
    case person
    case people
    case shirt
    case bell
    case bolt
    case question
    case warning
    case retry
    case undo
    case arrowRight
    case arrowUp
    case arrowDown
    case crown
    case pin
    case offline
    case noVideo
    case photo
    case document
    case sparkle
    case checkbox(checked: Bool)
    /// Cualquier otra clave del atlas, con la estrella de la casa de respaldo.
    case art(String)

    /// Las claves en orden de preferencia: la primera integrada gana.
    var artKeys: [String] {
        switch self {
        case .video: ["ui_icon_video"]
        case .clock: ["ui_icon_clock"]
        case .lock: ["ui_icon_lock"]
        case .check: ["ui_icon_check"]
        case .coin: ["ui_coin"]
        case .blue: ["ui_dolar_blue", "ui_oro"]
        case .gift: ["ui_gift_bow"]
        case .chest: ["ui_chest_closed"]
        case .wheel: ["wheel_icon"]
        case .package: ["pickup_package_full"]
        case .offerMoving: ["ui_offer_mudanza", "ui_gift_bow"]
        case .offerWelcome: ["ui_offer_bienvenida", "ui_gift_bow"]
        case .offerRebirth: ["ui_offer_renacer", "ui_gift_bow"]
        case .art(let key): [key]
        case .close, .cart, .trophy, .pencil, .chevron, .person, .people, .shirt, .bell, .bolt, .question,
             .warning, .retry, .undo, .arrowRight, .arrowUp, .arrowDown, .crown, .pin, .offline, .noVideo,
             .photo, .document, .sparkle, .checkbox:
            []
        }
    }

    /// La primera clave de la cadena que el atlas tiene, o `nil` (va el vector).
    @MainActor
    var resolvedArtKey: String? {
        artKeys.first { UIArt.uiImage($0) != nil }
    }
}

/// Los tonos de función que no tienen color de catálogo. El rojo es el de
/// `ui_badge` (muestreado del PNG): el mismo rojo del "hay algo" es el del video.
enum GameTint {
    static let alert = Color(red: 227 / 255, green: 58 / 255, blue: 51 / 255)
}

/// Dibuja un `GameGlyph`: el PNG si la cadena tiene uno integrado, si no el
/// vectorial. Decoración: lo que significa lo dice el control que lo lleva.
struct GameGlyphView: View {
    let glyph: GameGlyph
    var size: CGFloat = 26

    var body: some View {
        Group {
            if let key = glyph.resolvedArtKey, let image = UIArt.image(key) {
                image.resizable().scaledToFit()
            } else {
                GlyphVector(glyph: glyph)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Los vectoriales de respaldo

/// El respaldo dibujado de cada glifo, en el lienzo 100×100 de `GameIcons`.
private struct GlyphVector: View {
    let glyph: GameGlyph

    var body: some View {
        IconCanvas {
            switch glyph {
            case .video: VideoVector()
            case .clock: ClockVector()
            case .lock: LockVector()
            case .check: CheckVector()
            case .coin: MarkDisc(mark: "$", fill: Color("PaletteYellow"))
            case .blue: BlueNoteVector()
            case .gift, .offerMoving, .offerWelcome, .offerRebirth: VectorTabGiftsIcon()
            case .chest: MarkDisc(mark: "?", fill: Color("PaletteOrange"))
            case .wheel: MarkDisc(mark: "★", fill: Color("PalettePink"))
            case .package: MarkDisc(mark: "?", fill: Color("PaletteBrown").lifted(0.3))
            case .sparkle, .art: StarVector()
            case .noVideo: NoVideoVector()
            default: ExtraGlyphVector(glyph: glyph)
            }
        }
    }
}

/// El play rojo de "mirá un video" (`ui_icon_video`).
struct VideoVector: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .inked(GameTint.alert)
                .frame(width: 84, height: 66)
            IconPath { path in
                path.move(to: CGPoint(x: 41, y: 33))
                path.addLine(to: CGPoint(x: 67, y: 50))
                path.addLine(to: CGPoint(x: 41, y: 67))
                path.closeSubpath()
            }
            .inked(.white, lineWidth: IconSpec.detail)
        }
    }
}

/// El reloj (`ui_icon_clock`): esfera crema y las dos agujas.
private struct ClockVector: View {
    var body: some View {
        ZStack {
            Circle().inked(Color("PaletteCream")).frame(width: 80, height: 80)
            IconPath { path in
                path.move(to: CGPoint(x: 50, y: 50))
                path.addLine(to: CGPoint(x: 50, y: 28))
                path.move(to: CGPoint(x: 50, y: 50))
                path.addLine(to: CGPoint(x: 65, y: 58))
            }
            .stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            Circle().fill(IconSpec.ink).frame(width: 10, height: 10)
        }
    }
}

/// El candado (`ui_icon_lock`): arco grueso y cuerpo amarillo.
private struct LockVector: View {
    var body: some View {
        ZStack {
            IconPath { path in
                path.move(to: CGPoint(x: 32, y: 48))
                path.addLine(to: CGPoint(x: 32, y: 34))
                path.addArc(center: CGPoint(x: 50, y: 34), radius: 18,
                            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                path.addLine(to: CGPoint(x: 68, y: 48))
            }
            .stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 11, lineCap: .round))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .inked(Color("PaletteYellow"))
                .frame(width: 62, height: 44)
                .offset(y: 18)
            Circle().fill(IconSpec.ink).frame(width: 10, height: 10).offset(y: 16)
        }
    }
}

/// El listo (`ui_icon_check`): disco verde con el tilde crema.
private struct CheckVector: View {
    var body: some View {
        let tick = IconPath { path in
            path.move(to: CGPoint(x: 30, y: 52))
            path.addLine(to: CGPoint(x: 44, y: 66))
            path.addLine(to: CGPoint(x: 70, y: 36))
        }
        ZStack {
            Circle().inked(Color("PaletteGreen")).frame(width: 84, height: 84)
            tick.stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
            tick.stroke(Color("PaletteCream"), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
        }
    }
}

/// El billete celeste del dólar blue, mientras no haya `ui_dolar_blue` ni ORO.
private struct BlueNoteVector: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .inked(Color("PaletteBlue").lifted(0.25))
                .frame(width: 88, height: 54)
            Circle().inked(Color("PaletteCream"), lineWidth: IconSpec.detail).frame(width: 36, height: 36)
            Text(verbatim: "$")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(IconSpec.ink)
        }
    }
}

/// La estrella de la casa: el respaldo de una clave que todavía no existe.
struct StarVector: View {
    var body: some View {
        SparkleShape().inked(Color("PaletteYellow")).frame(width: 86, height: 86)
    }
}

/// Un disco teñido con una marca corta: el respaldo genérico de un premio.
struct MarkDisc: View {
    let mark: String
    let fill: Color

    var body: some View {
        ZStack {
            Circle().inked(fill).frame(width: 86, height: 86)
            Text(verbatim: mark)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Color("PaletteCream"))
                .shadow(color: IconSpec.ink.opacity(0.8), radius: 0, x: 0, y: 3)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(width: 70)
        }
    }
}
