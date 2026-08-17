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
    /// El margen que el CONTENIDO de la pantalla necesita para no pisar el
    /// marco: 22 de banda + 6 de aire hasta el bisel. Es el equivalente del
    /// `panelInset` que cada pantalla medía contra su PNG, ahora publicado por
    /// el componente porque acá la geometría es propia y no del arte.
    static let contentInset: CGFloat = 28

    /// Ancho de la banda de madera.
    private static let band: CGFloat = 22

    private static let wood = LinearGradient(
        colors: [WoodTone.light, WoodTone.base],
        startPoint: .top,
        endPoint: .bottom
    )

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
            ZStack {
                // La banda de madera, del borde hacia adentro.
                outer.strokeBorder(Self.wood, lineWidth: Self.band)
                // La línea oscura donde la madera encuentra el pergamino
                // (ocupa los últimos 3 pt de la banda).
                inner
                    .strokeBorder(WoodTone.dark, lineWidth: 3)
                    .padding(Self.band - 3)
                // El bisel de luz, ya sobre el pergamino.
                inner
                    .strokeBorder(WoodTone.bevel.opacity(0.9), lineWidth: 2)
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
            PanelScrew()
                .position(point)
        }
    }
}

/// Un tornillo del marco: plato con borde oscuro y la ranura en diagonal.
private struct PanelScrew: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(WoodTone.screw)
                .overlay(Circle().strokeBorder(WoodTone.dark, lineWidth: 2))
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(WoodTone.dark)
                .frame(width: 7, height: 1.8)
                .rotationEffect(.degrees(45))
        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
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
        .frame(width: width, height: width * 0.46)
        .accessibilityHidden(true)
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
