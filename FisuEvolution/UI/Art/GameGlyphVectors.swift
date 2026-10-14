import SwiftUI

/// Los vectoriales de los glifos que reemplazan a los SF Symbols (E14 T25): el
/// mismo idioma de `GameGlyph` —relleno de paleta, contorno ink, lienzo 100×100—
/// para los íconos de uso general (cerrar, volver, reintentar, persona, carrito…).
/// Se llega acá por `GameGlyphView`; ninguna pantalla los dibuja directo.

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

/// Los puntos de un arco, calculados a mano: no depende del sentido de `addArc`.
private func arcPoints(center: CGPoint, radius: CGFloat, from: Double, to: Double, steps: Int = 16) -> [CGPoint] {
    (0...steps).map { index in
        let degrees = from + (to - from) * Double(index) / Double(steps)
        let radians = degrees * .pi / 180
        return CGPoint(x: center.x + radius * CGFloat(cos(radians)), y: center.y + radius * CGFloat(sin(radians)))
    }
}

private extension Path {
    mutating func trace(_ points: [CGPoint], closed: Bool = false) {
        guard let first = points.first else { return }
        move(to: first)
        for point in points.dropFirst() { addLine(to: point) }
        if closed { closeSubpath() }
    }
}

/// Un trazo grueso de punta redonda: contorno ink y un alma clara (la del tilde).
private struct BoldLine: View {
    let shape: IconPath
    var width: CGFloat = 16
    var core: Color = Color("PaletteCream")

    var body: some View {
        ZStack {
            shape.stroke(IconSpec.ink, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            shape.stroke(core, style: StrokeStyle(lineWidth: width - 7, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Despacha cada glifo nuevo a su dibujo.
struct ExtraGlyphVector: View {
    let glyph: GameGlyph

    var body: some View {
        switch glyph {
        case .close: CloseVector()
        case .cart: CartVector()
        case .trophy: TrophyVector()
        case .pencil: PencilVector()
        case .chevron: ChevronVector()
        case .person: PersonFigure(fill: Color("PaletteBlue").lifted(0.25))
        case .people: PeopleVector()
        case .shirt: ShirtVector()
        case .bell: BellVector()
        case .bolt: BoltVector()
        case .question: MarkDisc(mark: "?", fill: Color("PaletteOrange"))
        case .warning: WarningVector()
        case .retry: RetryVector()
        case .undo: RetryVector().scaleEffect(x: -1, y: 1)
        case .arrowRight: ArrowRightVector()
        case .arrowUp: TriangleVector()
        case .arrowDown: TriangleVector().rotationEffect(.degrees(180))
        case .crown: CrownVector()
        case .pin: PinVector()
        case .offline: OfflineVector()
        case .photo: PhotoVector()
        case .document: DocumentVector()
        case .checkbox(let checked): CheckboxVector(checked: checked)
        default: StarVector()
        }
    }
}

private struct CloseVector: View {
    var body: some View {
        ZStack {
            Circle().inked(GameTint.alert).frame(width: 84, height: 84)
            BoldLine(shape: IconPath { path in
                path.trace([pt(34, 34), pt(66, 66)])
                path.trace([pt(66, 34), pt(34, 66)])
            }, width: 15)
        }
    }
}

private struct CartVector: View {
    var body: some View {
        ZStack {
            IconPath { path in path.trace([pt(8, 22), pt(24, 22), pt(36, 64)]) }
                .stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            IconPath { path in path.trace([pt(26, 36), pt(90, 36), pt(80, 66), pt(36, 66)], closed: true) }
                .inked(Color("PaletteYellow"))
            Circle().fill(IconSpec.ink).frame(width: 15, height: 15).position(x: 42, y: 82)
            Circle().fill(IconSpec.ink).frame(width: 15, height: 15).position(x: 72, y: 82)
        }
        .frame(width: 100, height: 100)
    }
}

private struct TrophyVector: View {
    var body: some View {
        ZStack {
            Circle().stroke(IconSpec.ink, lineWidth: 8).frame(width: 28, height: 28).position(x: 22, y: 32)
            Circle().stroke(IconSpec.ink, lineWidth: 8).frame(width: 28, height: 28).position(x: 78, y: 32)
            IconPath { path in
                path.trace([pt(28, 14), pt(72, 14), pt(68, 42), pt(58, 56), pt(42, 56), pt(32, 42)], closed: true)
            }
            .inked(Color("PaletteYellow"))
            IconPath { path in path.trace([pt(44, 56), pt(56, 56), pt(56, 72), pt(44, 72)], closed: true) }
                .inked(Color("PaletteOrange"))
            IconPath { path in path.trace([pt(30, 72), pt(70, 72), pt(70, 88), pt(30, 88)], closed: true) }
                .inked(Color("PaletteOrange"))
        }
        .frame(width: 100, height: 100)
    }
}

private struct PencilVector: View {
    var body: some View {
        ZStack {
            IconPath { path in path.trace([pt(62, 12), pt(88, 38), pt(44, 82), pt(18, 56)], closed: true) }
                .inked(Color("PaletteYellow"))
            IconPath { path in path.trace([pt(18, 56), pt(44, 82), pt(10, 90)], closed: true) }
                .inked(Color("PaletteCream"))
        }
    }
}

private struct ChevronVector: View {
    var body: some View {
        BoldLine(shape: IconPath { path in path.trace([pt(36, 20), pt(66, 50), pt(36, 80)]) })
    }
}

/// Una persona de busto: cabeza y hombros.
private struct PersonFigure: View {
    let fill: Color

    var body: some View {
        ZStack {
            IconPath { path in
                path.move(to: pt(16, 90))
                path.addArc(center: pt(50, 90), radius: 34, startAngle: .degrees(180), endAngle: .degrees(0),
                            clockwise: false)
                path.closeSubpath()
            }
            .inked(fill)
            Circle().inked(fill).frame(width: 36, height: 36).position(x: 50, y: 34)
        }
        .frame(width: 100, height: 100)
    }
}

private struct PeopleVector: View {
    var body: some View {
        ZStack {
            PersonFigure(fill: Color("PaletteBlue").lifted(0.25)).scaleEffect(0.72).offset(x: -20, y: 6)
            PersonFigure(fill: Color("PaletteOrange").lifted(0.2)).scaleEffect(0.8).offset(x: 16, y: 4)
        }
    }
}

private struct ShirtVector: View {
    var body: some View {
        IconPath { path in
            path.trace([
                pt(34, 14), pt(42, 22), pt(58, 22), pt(66, 14), pt(92, 34), pt(80, 50), pt(70, 44),
                pt(70, 88), pt(30, 88), pt(30, 44), pt(20, 50), pt(8, 34)
            ], closed: true)
        }
        .inked(Color("PaletteBlue").lifted(0.15))
    }
}

private struct BellVector: View {
    var body: some View {
        ZStack {
            Circle().fill(IconSpec.ink).frame(width: 14, height: 14).position(x: 50, y: 14)
            IconPath { path in
                path.move(to: pt(12, 74))
                path.addLine(to: pt(22, 56))
                path.addLine(to: pt(22, 50))
                path.addArc(center: pt(50, 50), radius: 28, startAngle: .degrees(180), endAngle: .degrees(0),
                            clockwise: false)
                path.addLine(to: pt(78, 56))
                path.addLine(to: pt(88, 74))
                path.closeSubpath()
            }
            .inked(Color("PaletteYellow"))
            Circle().inked(Color("PaletteOrange")).frame(width: 20, height: 20).position(x: 50, y: 82)
        }
        .frame(width: 100, height: 100)
    }
}

private struct BoltVector: View {
    var body: some View {
        IconPath { path in
            path.trace([pt(58, 6), pt(24, 54), pt(46, 54), pt(40, 94), pt(78, 42), pt(54, 42)], closed: true)
        }
        .inked(Color("PaletteYellow"))
    }
}

private struct WarningVector: View {
    var body: some View {
        ZStack {
            IconPath { path in path.trace([pt(50, 10), pt(92, 84), pt(8, 84)], closed: true) }
                .inked(Color("PaletteYellow"))
            Text(verbatim: "!")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(IconSpec.ink)
                .position(x: 50, y: 62)
        }
        .frame(width: 100, height: 100)
    }
}

/// La flecha que da la vuelta: el reintentar. Vuelta en espejo para "deshacer".
private struct RetryVector: View {
    var body: some View {
        let arc = arcPoints(center: pt(50, 50), radius: 28, from: 40, to: 320, steps: 14)
        ZStack {
            BoldLine(shape: IconPath { path in path.trace(arc) }, width: 14)
            IconPath { path in path.trace([pt(82, 23), pt(83, 46), pt(60, 41)], closed: true) }
                .inked(Color("PaletteCream"))
        }
    }
}

private struct ArrowRightVector: View {
    var body: some View {
        BoldLine(shape: IconPath { path in
            path.trace([pt(14, 50), pt(84, 50)])
            path.trace([pt(56, 22), pt(84, 50), pt(56, 78)])
        })
    }
}

private struct TriangleVector: View {
    var body: some View {
        IconPath { path in path.trace([pt(50, 16), pt(86, 76), pt(14, 76)], closed: true) }
            .inked(Color("PaletteYellow"))
    }
}

private struct CrownVector: View {
    var body: some View {
        ZStack {
            IconPath { path in
                path.trace([pt(12, 76), pt(8, 32), pt(32, 52), pt(50, 20), pt(68, 52), pt(92, 32), pt(88, 76)],
                           closed: true)
            }
            .inked(Color("PaletteYellow"))
            IconPath { path in path.trace([pt(12, 76), pt(88, 76), pt(88, 90), pt(12, 90)], closed: true) }
                .inked(Color("PaletteOrange"))
        }
    }
}

private struct PinVector: View {
    var body: some View {
        ZStack {
            IconPath { path in
                path.move(to: pt(24, 42))
                path.addArc(center: pt(50, 42), radius: 26, startAngle: .degrees(180), endAngle: .degrees(0),
                            clockwise: false)
                path.addLine(to: pt(50, 92))
                path.closeSubpath()
            }
            .inked(GameTint.alert)
            Circle().inked(Color("PaletteCream"), lineWidth: IconSpec.detail)
                .frame(width: 24, height: 24).position(x: 50, y: 42)
        }
        .frame(width: 100, height: 100)
    }
}

/// El wifi tachado: "sin conexión".
private struct OfflineVector: View {
    var body: some View {
        ZStack {
            ForEach([14, 28, 42], id: \.self) { radius in
                IconPath { path in
                    path.trace(arcPoints(center: pt(50, 78), radius: CGFloat(radius), from: 220, to: 320))
                }
                .stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 9, lineCap: .round))
            }
            Circle().fill(IconSpec.ink).frame(width: 13, height: 13).position(x: 50, y: 80)
            BoldLine(shape: IconPath { path in path.trace([pt(18, 14), pt(84, 88)]) }, width: 13,
                     core: GameTint.alert)
        }
        .frame(width: 100, height: 100)
    }
}

/// El video tachado: "no hay video ahora".
struct NoVideoVector: View {
    var body: some View {
        ZStack {
            VideoVector().opacity(0.55)
            BoldLine(shape: IconPath { path in path.trace([pt(14, 14), pt(86, 86)]) }, width: 13)
        }
    }
}

private struct PhotoVector: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .inked(Color("PaletteCream")).frame(width: 88, height: 70)
            IconPath { path in
                path.trace([pt(16, 76), pt(38, 44), pt(54, 64), pt(66, 50), pt(84, 76)], closed: true)
            }
            .inked(Color("PaletteGreen"), lineWidth: IconSpec.detail)
            Circle().inked(Color("PaletteYellow"), lineWidth: IconSpec.detail)
                .frame(width: 16, height: 16).position(x: 70, y: 34)
        }
        .frame(width: 100, height: 100)
    }
}

private struct DocumentVector: View {
    var body: some View {
        ZStack {
            IconPath { path in
                path.trace([pt(24, 10), pt(60, 10), pt(78, 28), pt(78, 90), pt(24, 90)], closed: true)
            }
            .inked(Color("PaletteCream"))
            IconPath { path in
                path.trace([pt(36, 44), pt(66, 44)])
                path.trace([pt(36, 58), pt(66, 58)])
                path.trace([pt(36, 72), pt(56, 72)])
            }
            .stroke(IconSpec.ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
    }
}

private struct CheckboxVector: View {
    let checked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .inked(checked ? Color("PaletteGreen") : Color("PaletteCream"))
                .frame(width: 80, height: 80)
            if checked {
                BoldLine(shape: IconPath { path in path.trace([pt(28, 52), pt(44, 68), pt(72, 34)]) }, width: 14)
            }
        }
    }
}
