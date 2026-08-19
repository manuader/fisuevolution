import SwiftUI

/// Marcos de panel VECTORIALES del rediseño v3 — los hermanos dibujados del
/// arte del atlas, para las pantallas que no tienen un marco de arte propio.
///
/// `panel_config` (la familia del menú) era un doble trazo pelado que no
/// hablaba el idioma de las referencias: acá se reemplaza por la madera de
/// `panel_store`, con los MISMOS tonos muestreados del PNG (madera
/// #C98F52→#A9713C, línea interna #2F1915, bisel #D3B788) y los tornillos en
/// las esquinas, sin el toldo — el toldo es de negocio, y el menú no vende
/// nada. El día que un `panel_menu` de arte exista en el atlas, entra por
/// `PanelBackground(art:)` sin tocar más que la vista que lo usa.
///
/// Reglas de la casa que también rigen acá: nada de identifiers en
/// contenedores, cero animación viva en reposo, y los ornamentos son
/// decoración (`accessibilityHidden`).

// MARK: - Tonos de la madera (muestreados de panel_store@3x)

private enum WoodTone {
    static let light = Color(red: 0.788, green: 0.561, blue: 0.322)   // #C98F52
    static let base = Color(red: 0.663, green: 0.443, blue: 0.235)    // #A9713C
    static let dark = Color(red: 0.184, green: 0.098, blue: 0.082)    // #2F1915
    static let bevel = Color(red: 0.827, green: 0.718, blue: 0.533)   // #D3B788
    static let screw = Color(red: 0.541, green: 0.353, blue: 0.188)   // #8A5A30
}

// MARK: - WoodPanelBackground

/// Fondo de pantalla con marco de madera dibujado: pergamino adentro (las dos
/// mismas capas que `PanelBackground`), banda de madera perimetral con bisel,
/// línea oscura y tornillos. Drop-in de `PanelBackground` para la familia del
/// menú.
struct WoodPanelBackground: View {
    /// Los dos materiales del juego: madera para casi todo, metal con remaches
    /// para la maquinaria (Mejoras y el Ascensor). El engranaje del arte viejo
    /// se retiró a pedido del dueño: leía "ajustes", no "mejoras".
    enum Material {
        case wood
        case metal
    }

    /// El margen que el CONTENIDO de la pantalla necesita para no pisar el
    /// marco: 22 de banda + 6 de aire hasta el bisel. Es el equivalente del
    /// `panelInset` que cada pantalla medía contra su PNG, ahora publicado por
    /// el componente porque acá la geometría es propia y no del arte.
    static let contentInset: CGFloat = 28

    /// El margen de la COLUMNA de tarjetas: el del contenido + el aire que las
    /// separa del bisel. Es UN número para las nueve hojas — el dueño pidió que
    /// el marco actúe de contenedor, y un contenedor con nueve márgenes
    /// distintos no es un sistema (2026-08-18; reemplaza a los `panelInset`
    /// medidos PNG por PNG contra el arte que se retiró).
    static let columnInset: CGFloat = 34

    /// Alto del toldo de los negocios. Publicado para quien necesite despejarlo.
    static let awningHeight: CGFloat = 40

    /// Ancho de la banda del marco.
    private static let band: CGFloat = 22

    var material: Material = .wood
    /// El toldo rayado de los negocios (FisuJobs, Pintas, Tienda, Regalos).
    /// Vectorial: el del arte 9-slice se estiraba con el ancho de pantalla y
    /// las franjas quedaban deformes — éste reparte SUS franjas al ancho real.
    var awning: Bool = false

    private static let wood = LinearGradient(
        colors: [WoodTone.light, WoodTone.base],
        startPoint: .top,
        endPoint: .bottom
    )

    private static let metal = LinearGradient(
        colors: [MetalTone.light, MetalTone.base],
        startPoint: .top,
        endPoint: .bottom
    )

    private var bandFill: LinearGradient { material == .wood ? Self.wood : Self.metal }
    private var lineTone: Color { material == .wood ? WoodTone.dark : MetalTone.dark }
    private var bevelTone: Color { material == .wood ? WoodTone.bevel : MetalTone.bevel }
    private var screwTone: Color { material == .wood ? WoodTone.screw : MetalTone.screw }

    var body: some View {
        ZStack {
            Color("PaletteParchment")
            LinearGradient(
                colors: [
                    Color.white.opacity(0.35),
                    .clear,
                    Color("PaletteBrown").opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            frame
        }
        .ignoresSafeArea()
    }

    private var frame: some View {
        GeometryReader { geo in
            let outer = RoundedRectangle(cornerRadius: 34, style: .continuous)
            let inner = RoundedRectangle(cornerRadius: 18, style: .continuous)
            ZStack(alignment: .top) {
                // El toldo va primero en z: sus puntas se meten POR DETRÁS de
                // la banda del marco y no hay costura que disimular.
                if awning {
                    AwningBand()
                        .frame(height: Self.awningHeight)
                        .padding(.horizontal, Self.band - 6)
                        .padding(.top, Self.band - 2)
                }
                // La banda del marco, del borde hacia adentro.
                outer.strokeBorder(bandFill, lineWidth: Self.band)
                // La línea oscura donde el marco encuentra el pergamino
                // (ocupa los últimos 3 pt de la banda).
                inner
                    .strokeBorder(lineTone, lineWidth: 3)
                    .padding(Self.band - 3)
                // El bisel de luz, ya sobre el pergamino.
                inner
                    .strokeBorder(bevelTone.opacity(0.9), lineWidth: 2)
                    .padding(Self.band)
                // El contorno ink de afuera de todo, como el arte.
                outer.strokeBorder(Color("PaletteInk").opacity(0.9), lineWidth: 3)
                screws(in: geo.size)
            }
        }
        .ignoresSafeArea()
    }

    /// Los cuatro tornillos, apoyados sobre la banda en cada esquina.
    private func screws(in size: CGSize) -> some View {
        let inset: CGFloat = 24
        let positions = [
            CGPoint(x: inset, y: inset),
            CGPoint(x: size.width - inset, y: inset),
            CGPoint(x: inset, y: size.height - inset),
            CGPoint(x: size.width - inset, y: size.height - inset)
        ]
        return ForEach(Array(positions.enumerated()), id: \.offset) { _, point in
            PanelScrew(fill: screwTone, line: lineTone)
                .position(point)
        }
    }
}

/// Un tornillo del marco: plato con borde oscuro y la ranura en diagonal.
/// En metal es un remache: mismo dibujo, tonos fríos.
private struct PanelScrew: View {
    let fill: Color
    let line: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(line, lineWidth: 2))
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(line)
                .frame(width: 7, height: 1.8)
                .rotationEffect(.degrees(45))
        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }
}

// MARK: - Tonos del metal (fríos, hermanos de los del arte panel_upgrades)

private enum MetalTone {
    static let light = Color(red: 0.784, green: 0.820, blue: 0.824)   // #C8D1D2
    static let base = Color(red: 0.624, green: 0.667, blue: 0.671)    // #9FAAAB
    static let dark = Color(red: 0.157, green: 0.180, blue: 0.188)    // #282E30
    static let bevel = Color(red: 0.882, green: 0.910, blue: 0.914)   // #E1E8E9
    static let screw = Color(red: 0.529, green: 0.573, blue: 0.580)   // #879294
}

// MARK: - AwningBand

/// El toldo rayado de los negocios, dibujado: franjas rojas y crema con el
/// festón de semicírculos abajo y su contorno ink. A diferencia del toldo del
/// arte —que el 9-slice estiraba junto con el resto del marco— éste reparte
/// SUS franjas sobre el ancho real de la pantalla, así que nunca se deforma.
private struct AwningBand: View {
    /// Impar, para que las dos puntas sean rojas como en el arte del atlas.
    private static let stripes = 7

    private static let red = Color(red: 0.851, green: 0.365, blue: 0.278)     // #D95D47
    private static let cream = Color(red: 0.973, green: 0.945, blue: 0.898)   // #F8F1E5

    var body: some View {
        GeometryReader { geo in
            let stripeWidth = geo.size.width / CGFloat(Self.stripes)
            ZStack {
                HStack(spacing: 0) {
                    ForEach(0..<Self.stripes, id: \.self) { index in
                        (index.isMultiple(of: 2) ? Self.red : Self.cream)
                            .frame(width: stripeWidth)
                    }
                }
                .clipShape(AwningShape(scallops: Self.stripes))
                AwningShape(scallops: Self.stripes)
                    .stroke(Color("PaletteInk"), lineWidth: 3)
            }
            // La sombra que el festón tira sobre el pergamino: el toldo se lee
            // VOLANDO sobre el panel, no pegado.
            .shadow(color: .black.opacity(0.18), radius: 3, y: 3)
        }
        .accessibilityHidden(true)
    }
}

/// La silueta del toldo: techo recto y festón de semicírculos abajo, uno por
/// franja.
struct AwningShape: Shape {
    let scallops: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scallopWidth = rect.width / CGFloat(max(scallops, 1))
        let straightBottom = rect.maxY - scallopWidth * 0.28
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: straightBottom))
        for index in stride(from: scallops - 1, through: 0, by: -1) {
            let center = CGPoint(
                x: rect.minX + scallopWidth * (CGFloat(index) + 0.5),
                y: straightBottom
            )
            path.addArc(
                center: center,
                radius: scallopWidth * 0.5,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: false
            )
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - GiftBowOrnament

/// El moño rojo de la pantalla de Regalos, apoyado sobre el toldo del marco
/// como en la referencia. Vectorial mientras un `ui_gift_bow` de arte no
/// exista en el atlas.
struct GiftBowOrnament: View {
    static let defaultWidth: CGFloat = 150

    private static let red = Color(red: 0.851, green: 0.310, blue: 0.239)      // #D94F3D
    private static let deepRed = Color(red: 0.651, green: 0.204, blue: 0.157)  // #A63428

    var width: CGFloat = GiftBowOrnament.defaultWidth
    private var loopSize: CGSize { CGSize(width: width * 0.42, height: width * 0.30) }

    var body: some View {
        // El arte del atlas manda (batch 236, 2026-08-18); el vectorial queda
        // de fallback, como todo GameIcon. El PNG se encaja en el MISMO
        // footprint que dibuja el vector, así el offset que lo apoya sobre el
        // toldo en Regalos no depende de cuál de los dos esté.
        Group {
            if let art = UIArt.image("ui_gift_bow") {
                art
                    .resizable()
                    .scaledToFit()
            } else {
                vectorBow
            }
        }
        .frame(width: width, height: width * 0.46)
        .accessibilityHidden(true)
    }

    private var vectorBow: some View {
        ZStack {
            // Las colas, por detrás de todo, cayendo en V hacia afuera.
            tail(angle: 24)
            tail(angle: -24)
            // Las dos lazadas.
            loop(rotation: -26, offsetX: -width * 0.21)
            loop(rotation: 26, offsetX: width * 0.21)
            // El nudo, por delante.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Self.red)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color("PaletteInk"), lineWidth: 3)
                )
                .frame(width: width * 0.20, height: width * 0.17)
        }
    }

    private func loop(rotation: Double, offsetX: CGFloat) -> some View {
        Ellipse()
            .fill(Self.red)
            .overlay(
                // El hueco interior de la lazada, hundido.
                Ellipse()
                    .fill(Self.deepRed)
                    .scaleEffect(0.55)
                    .offset(x: -offsetX * 0.25)
            )
            .overlay(Ellipse().strokeBorder(Color("PaletteInk"), lineWidth: 3))
            .frame(width: loopSize.width, height: loopSize.height)
            .rotationEffect(.degrees(rotation))
            .offset(x: offsetX)
    }

    private func tail(angle: Double) -> some View {
        BowTailShape()
            .fill(Self.red)
            .overlay(BowTailShape().stroke(Color("PaletteInk"), lineWidth: 3))
            .frame(width: width * 0.22, height: width * 0.30)
            .rotationEffect(.degrees(angle), anchor: .top)
            .offset(x: angle > 0 ? width * 0.13 : -width * 0.13, y: width * 0.13)
    }
}

/// La cola del moño: un banderín que se ensancha hacia abajo y termina en una
/// muesca en V, como las puntas del `RibbonShape`.
struct BowTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch = rect.height * 0.22
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.28, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.28, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
