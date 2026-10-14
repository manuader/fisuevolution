import EconomyKit
import SwiftUI

/// Cómo se acomoda un gajo: cuánto mide el dibujo del premio y a qué altura
/// del radio va él y su número. Puro, para pinearlo en un test.
enum WheelSliceLayout {
    /// El dibujo del premio, en fracción del radio.
    static let artSide = 0.30
    /// A qué distancia del centro va el dibujo.
    static let artRadius = 0.52
    /// A qué distancia va el número ("30 min", "×2").
    static let labelRadius = 0.80
    /// El gajo más angosto de la rueda no puede ser menor que su dibujo.
    static func artFits(slices: Int) -> Bool {
        guard slices > 0 else { return false }
        let chord = 2 * artRadius * sin(Double.pi / Double(slices))
        return chord >= artSide
    }

    /// Qué imagen lleva el gajo de un premio (E14 C4: cada gajo con su arte).
    static func kind(of reward: RewardSpec) -> RewardKind { RewardKind(reward) ?? .gift }
}

/// Los gajos de la rueda, con la imagen de su premio y el número al costado,
/// rotados como una sola pieza (`rotation` en grados, sentido horario). El aro,
/// las luces y el puntero son del video (`ruleta_espera`), que va debajo; esto
/// es el disco que gira encima.
struct WheelCanvas: View {
    let segments: [WheelConfig.Segment]
    let rotation: Double

    static let palette = ["PaletteYellow", "PaletteGreen", "PaletteOrange", "PaletteBlue", "PalettePink"]

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side / 2
            ZStack {
                Canvas { context, size in
                    let radius = min(size.width, size.height) / 2
                    context.translateBy(x: size.width / 2, y: size.height / 2)
                    for (index, arc) in WheelGeometry.arcs(count: segments.count).enumerated() {
                        var wedge = Path()
                        wedge.move(to: .zero)
                        wedge.addArc(center: .zero, radius: radius,
                                     startAngle: .degrees(arc.start - 90), endAngle: .degrees(arc.end - 90),
                                     clockwise: false)
                        wedge.closeSubpath()
                        context.fill(wedge, with: .color(Color(Self.palette[index % Self.palette.count])))
                        context.stroke(wedge, with: .color(Color("PaletteInk").opacity(0.55)), lineWidth: 1.5)
                    }
                    let edge = Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
                    context.stroke(edge, with: .color(Color("PaletteInk")), lineWidth: 2)
                    let hub = Path(ellipseIn: CGRect(x: -radius * 0.12, y: -radius * 0.12,
                                                     width: radius * 0.24, height: radius * 0.24))
                    context.fill(hub, with: .color(Color("PaletteCream")))
                    context.stroke(hub, with: .color(Color("PaletteInk")), lineWidth: 2)
                }
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    slice(segment, arc: WheelGeometry.arcs(count: segments.count)[index], radius: radius)
                }
            }
            .frame(width: side, height: side)
            .drawingGroup()
            .rotationEffect(.degrees(rotation))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }

    private func slice(_ segment: WheelConfig.Segment, arc: WheelGeometry.Arc, radius: CGFloat) -> some View {
        ZStack {
            RewardArt(kind: WheelSliceLayout.kind(of: segment.reward))
                .frame(width: radius * WheelSliceLayout.artSide, height: radius * WheelSliceLayout.artSide)
                .offset(y: -radius * WheelSliceLayout.artRadius)
            if let text = RewardCopy.slice(segment.reward) {
                Text(verbatim: text)
                    .font(.system(size: radius * 0.10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(1)
                    .fixedSize()
                    .offset(y: -radius * WheelSliceLayout.labelRadius)
            }
        }
        .frame(width: radius * 2, height: radius * 2)
        .rotationEffect(.degrees(arc.mid))
    }
}

/// La ruleta en chiquito, para tarjetas y chips, mientras no llegue `wheel_icon` (E8).
struct WheelGlyph: View {
    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            context.translateBy(x: size.width / 2, y: size.height / 2)
            for (index, arc) in WheelGeometry.arcs(count: 8).enumerated() {
                var wedge = Path()
                wedge.move(to: .zero)
                wedge.addArc(center: .zero, radius: radius * 0.9,
                             startAngle: .degrees(arc.start - 90), endAngle: .degrees(arc.end - 90), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(Color(WheelCanvas.palette[index % WheelCanvas.palette.count])))
            }
            let rim = Path(ellipseIn: CGRect(x: -radius * 0.9, y: -radius * 0.9, width: radius * 1.8, height: radius * 1.8))
            context.stroke(rim, with: .color(Color("PaletteInk")), lineWidth: max(1.5, radius * 0.1))
        }
        .accessibilityHidden(true)
    }
}
