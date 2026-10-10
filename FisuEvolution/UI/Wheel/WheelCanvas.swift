import EconomyKit
import SwiftUI

/// La rueda dibujada: rebanadas iguales alternando los colores de la casa, el
/// ícono y el número de cada premio, el aro y el centro. `rotation` en grados,
/// sentido horario.
struct WheelCanvas: View {
    let segments: [WheelConfig.Segment]
    let rotation: Double

    static let palette = ["PaletteYellow", "PaletteGreen", "PaletteOrange", "PaletteBlue", "PalettePink"]

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: .degrees(rotation))
            for (index, arc) in WheelGeometry.arcs(count: segments.count).enumerated() {
                var wedge = Path()
                wedge.move(to: .zero)
                wedge.addArc(center: .zero, radius: radius * 0.92,
                             startAngle: .degrees(arc.start - 90), endAngle: .degrees(arc.end - 90), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(Color(Self.palette[index % Self.palette.count])))
                context.stroke(wedge, with: .color(Color("PaletteInk").opacity(0.55)), lineWidth: 1.5)

                var label = context
                label.rotate(by: .degrees(arc.mid))
                let reward = segments[index].reward
                var icon = label.resolve(Image(systemName: RewardCopy.symbol(reward)))
                icon.shading = .color(Color("PaletteInk"))
                let iconSide = radius * 0.16
                label.draw(icon, in: CGRect(x: -iconSide / 2, y: -radius * 0.70 - iconSide / 2,
                                            width: iconSide, height: iconSide))
                if let text = RewardCopy.slice(reward) {
                    label.draw(
                        Text(verbatim: text)
                            .font(.system(size: radius * 0.10, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color("PaletteInk")),
                        at: CGPoint(x: 0, y: -radius * 0.47)
                    )
                }
            }
            let rim = Path(ellipseIn: CGRect(x: -radius * 0.96, y: -radius * 0.96, width: radius * 1.92, height: radius * 1.92))
            context.stroke(rim, with: .color(Color("PaletteBrown")), lineWidth: radius * 0.08)
            let hub = Path(ellipseIn: CGRect(x: -radius * 0.14, y: -radius * 0.14, width: radius * 0.28, height: radius * 0.28))
            context.fill(hub, with: .color(Color("PaletteCream")))
            context.stroke(hub, with: .color(Color("PaletteInk")), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }
}

/// El puntero de arriba.
struct WheelPointer: View {
    var body: some View {
        PointerShape()
            .fill(Color("PaletteOrange"))
            .overlay(PointerShape().stroke(Color("PaletteInk"), lineWidth: 2))
            .accessibilityHidden(true)
    }

    private struct PointerShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
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
