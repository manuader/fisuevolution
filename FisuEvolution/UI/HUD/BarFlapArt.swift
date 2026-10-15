import SwiftUI

// Las piezas dibujadas de la barra de abajo (E14b B28, diseño B «Etiqueta y
// billete»): la etiqueta de Contratar, el billete de Reencarnar y la carpeta
// del plato del medio. Todo son Shapes de SwiftUI —cero SF Symbols—; el único
// arte de afuera es el que ya vive en `ui.atlas`.

// MARK: - Reloj de los aleteos

/// Dispara un pulso cada `interval` segundos para que los `keyframeAnimator`
/// de la barra se muevan de vez en cuando. No es un `repeatForever`: en reposo
/// no hay animación viva y el display link no queda corriendo toda la sesión.
/// Con `active` apagado (Reduce Motion, botón sin plata) no corre nada.
struct PulseClock<Content: View>: View {
    let interval: Double
    let active: Bool
    var delay: Double = 0
    @ViewBuilder let content: (Int) -> Content
    @State private var tick = 0

    var body: some View {
        content(tick)
            .task(id: active) {
                guard active else { return }
                try? await Task.sleep(for: .seconds(delay))
                while !Task.isCancelled {
                    tick += 1
                    try? await Task.sleep(for: .seconds(interval))
                }
            }
    }
}

// MARK: - Texto con contorno

/// Blanco con contorno ink, como los rótulos de los botones del arte. SwiftUI
/// no contornea texto: se apilan copias ink corridas atrás del blanco.
struct InkOutlinedText: View {
    let text: Text
    var width: CGFloat = 1.6

    var body: some View {
        ZStack {
            ForEach(Array(Self.offsets.enumerated()), id: \.offset) { _, offset in
                text.foregroundStyle(Color("PaletteInk"))
                    .offset(x: offset.width * width, y: offset.height * width)
            }
            text.foregroundStyle(.white)
        }
    }

    private static let offsets: [CGSize] = [
        CGSize(width: -1, height: 0), CGSize(width: 1, height: 0),
        CGSize(width: 0, height: -1), CGSize(width: 0, height: 1),
        CGSize(width: -0.7, height: -0.7), CGSize(width: 0.7, height: -0.7),
        CGSize(width: -0.7, height: 0.7), CGSize(width: 0.7, height: 0.7),
    ]
}

// MARK: - La etiqueta

/// La etiqueta de precio: rectángulo con la punta cortada a la izquierda, donde
/// va el ojal.
struct PriceTagShape: InsettableShape {
    var inset: CGFloat = 0
    /// Cuánto entra la punta desde el borde izquierdo.
    static let notch: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        var path = Path()
        path.move(to: CGPoint(x: box.minX + Self.notch, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX + Self.notch, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX, y: box.midY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> PriceTagShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

/// El piolín: un arco marrón que sale del ojal hacia arriba a la izquierda.
private struct TagString: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                          control: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.maxY))
        return path
    }
}

/// El cuerpo de la etiqueta de Contratar: verde con contorno ink, costura
/// punteada crema, ojal y piolín. `tint` es nil cuando no alcanza la plata.
struct PriceTagBody: View {
    let tint: Color?

    var body: some View {
        let fill = tint ?? Color(white: 0.78)
        ZStack(alignment: .leading) {
            PriceTagShape().fill(fill)
            PriceTagShape()
                .inset(by: 5)
                .stroke(Color("PaletteCream").opacity(0.85),
                        style: StrokeStyle(lineWidth: 1.6, lineJoin: .round, dash: [4, 3]))
                .padding(.leading, 4)
            PriceTagShape().strokeBorder(Color("PaletteInk"), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            Circle()
                .fill(Color("PaletteParchment"))
                .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 2))
                .frame(width: 8, height: 8)
                .padding(.leading, 5)
            TagString()
                .stroke(Color("PaletteBrown"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 12, height: 9)
                .offset(x: -3, y: -17)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - El billete

/// El billete de dólar blue: rectángulo con las cuatro esquinas comidas por un
/// cuarto de círculo.
struct BillShape: InsettableShape {
    var inset: CGFloat = 0
    static let cut: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        let c = Self.cut
        var path = Path()
        path.move(to: CGPoint(x: box.minX + c, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX - c, y: box.minY))
        path.addArc(center: CGPoint(x: box.maxX, y: box.minY), radius: c,
                    startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        path.addLine(to: CGPoint(x: box.maxX, y: box.maxY - c))
        path.addArc(center: CGPoint(x: box.maxX, y: box.maxY), radius: c,
                    startAngle: .degrees(270), endAngle: .degrees(180), clockwise: true)
        path.addLine(to: CGPoint(x: box.minX + c, y: box.maxY))
        path.addArc(center: CGPoint(x: box.minX, y: box.maxY), radius: c,
                    startAngle: .degrees(0), endAngle: .degrees(270), clockwise: true)
        path.addLine(to: CGPoint(x: box.minX, y: box.minY + c))
        path.addArc(center: CGPoint(x: box.minX, y: box.minY), radius: c,
                    startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> BillShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

/// El papel del billete: celeste con guarda de marco crema y óvalos concéntricos
/// de fondo (la guilloché de los billetes de verdad).
struct BillPaper: View {
    /// Cuando ya se puede reencarnar, el celeste brilla más.
    let glowing: Bool

    var body: some View {
        ZStack {
            BillShape().fill(Color("PaletteBlue"))
            BillShape().fill(LinearGradient(colors: [.white.opacity(glowing ? 0.5 : 0.32), .clear],
                                            startPoint: .top, endPoint: .bottom))
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.3, y: size.height * 0.5)
                for step in 1...5 {
                    let r = CGFloat(step) * 7
                    let oval = Path(ellipseIn: CGRect(x: center.x - r * 1.6, y: center.y - r,
                                                      width: r * 3.2, height: r * 2))
                    context.stroke(oval, with: .color(.white.opacity(0.2)), lineWidth: 1)
                }
            }
            .clipShape(BillShape())
            BillShape().inset(by: 5)
                .stroke(Color("PaletteCream").opacity(0.85), lineWidth: 1.6)
            BillShape().strokeBorder(Color("PaletteInk"), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// Un destello que titila: nace, brilla y se va. Quieto si no hay movimiento.
struct TwinkleView: View {
    let size: CGFloat
    let delay: Double
    let animated: Bool

    var body: some View {
        PulseClock(interval: 2.6, active: animated, delay: delay) { tick in
            SparkleShape()
                .fill(.white)
                .overlay(SparkleShape().stroke(Color("PaletteInk").opacity(0.5), lineWidth: 0.6))
                .frame(width: size, height: size)
                .keyframeAnimator(initialValue: animated ? 0.0 : 1.0, trigger: tick) { view, value in
                    view.scaleEffect(max(0.01, value)).opacity(value)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1.0, duration: 0.35)
                        CubicKeyframe(0.0, duration: 0.45)
                    }
                }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - La carpeta

/// El plato de Contratar: una carpeta de FisuJobs amarilla con su pestaña, un
/// legajo que asoma, la cara del Fisura en el círculo y el sello rosa. Se dibuja
/// en un cuadrado de `side` (el mismo que tenía el plato de arte).
struct FolderPlate<Face: View>: View {
    let side: CGFloat
    /// `true` mientras no hay Reduce Motion: la carpeta flota apenas.
    let floating: Bool
    @ViewBuilder let face: (CGFloat) -> Face

    var body: some View {
        PulseClock(interval: 3.4, active: floating) { tick in
            folder
                .keyframeAnimator(initialValue: 0.0, trigger: tick) { view, dy in
                    view.offset(y: dy)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-3, duration: 0.7)
                        CubicKeyframe(0, duration: 0.7)
                    }
                }
        }
    }

    private var folder: some View {
        let cuerpo = side * 0.74
        let ring = side * 0.5
        return ZStack(alignment: .bottom) {
            // La pestaña de la carpeta y el cuerpo de atrás.
            UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                .fill(Color("PaletteYellow").deepened(0.12))
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                    .strokeBorder(Color("PaletteInk"), lineWidth: 2.5))
                .frame(width: side * 0.5, height: side * 0.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, side * 0.06)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color("PaletteYellow").deepened(0.12))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color("PaletteInk"), lineWidth: 2.5))
                .frame(height: cuerpo)
            // El legajo que asoma.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color("PaletteCream"))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color("PaletteInk"), lineWidth: 2))
                .frame(width: side * 0.66, height: side * 0.3)
                .rotationEffect(.degrees(-4))
                .offset(y: -cuerpo * 0.62)
            // La tapa de adelante.
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [Color("PaletteYellow").opacity(0.7), Color("PaletteYellow")],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color("PaletteInk"), lineWidth: 3))
                .frame(height: cuerpo * 0.8)
            Circle()
                .fill(Color("PaletteCream"))
                .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 2.5))
                .overlay(face(ring * 0.9).clipShape(Circle()))
                .frame(width: ring, height: ring)
                .offset(y: -cuerpo * 0.14)
            Text(verbatim: "FisuJobs")
                .font(.system(size: max(7, side * 0.13), weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 3)
                .background(Color("PalettePink"), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color("PaletteInk"), lineWidth: 1.5))
                .rotationEffect(.degrees(12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 1)
                .padding(.bottom, cuerpo * 0.1)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}
