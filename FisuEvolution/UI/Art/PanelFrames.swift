import SwiftUI

/// Marcos de panel VECTORIALES del rediseño v3 — los hermanos dibujados del
/// arte del atlas, para las pantallas que no tienen un marco de arte propio.
///
/// `panel_config` (la familia del menú) era un doble trazo pelado que no
/// hablaba el idioma de las referencias: acá se reemplaza por la madera de
/// `panel_store`, con los MISMOS tonos muestreados del PNG (madera
/// #C98F52→#A9713C, línea interna #2F1915, bisel #D3B788) y los tornillos en
/// las esquinas, sin el toldo — el toldo es de negocio, y el menú no vende
/// nada. (`panel_menu` de arte existe en el atlas como reserva, pero un marco
/// 9-slice full-screen devolvería el estiramiento que esta familia mató.)
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

    /// Desde dónde arranca la cabecera de una hoja contenida, medido desde el
    /// TOPE del panel (la hoja ignora la safe area de arriba, así el número no
    /// depende del alto de la barra de navegación): despeja el toldo entero
    /// —festón que desborda su banda y sombra incluidos— o la banda con su
    /// bisel cuando no hay negocio.
    static func headerTopInset(awning: Bool) -> CGFloat { awning ? 88 : 60 }

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
        // El panel es una PIEZA con esquinas redondeadas, no un empapelado:
        // recortado acá, el pergamino no asoma por afuera de la banda cuando la
        // hoja flota sobre el juego (fondo de presentación transparente). El
        // sangrado contra los bordes ya no lo decide el componente: lo decide
        // la hoja (`panelSheet`), que es quien sabe hasta dónde debe llegar.
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
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

// MARK: - Hoja contenida

/// La hoja CONTENIDA por su marco (pedido del dueño, 2026-08-18): la cabecera
/// vive ADENTRO del pergamino —debajo del toldo, sin banda opaca que tape los
/// postes— y el scroll es una región recortada que se funde contra la banda
/// inferior, que queda A LA VISTA porque el panel respeta el borde de abajo.
/// El "desfile por detrás del título" que las bandas opacas cortaban muere acá
/// de raíz: el scroll arranca DEBAJO de la cabecera y no puede pasarle por
/// atrás, así que la banda, la barra de navegación crema y sus escalones
/// quedaron sin trabajo.
///
/// Se aplica sobre el `ScrollView` de la hoja, y la hoja se presenta con
/// `.presentationBackground(.clear)`: el panel flota sobre el juego atenuado,
/// como los popups — que es como componen las referencias.
private struct PanelSheetLayout<Header: View, Ornament: View>: ViewModifier {
    let material: WoodPanelBackground.Material
    let awning: Bool
    let header: Header
    /// Decoración apoyada sobre el marco (el moño de Regalos). Se dibuja en el
    /// plano del FONDO, detrás del contenido, anclada al tope del panel.
    let ornament: Ornament

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            header
                .frame(maxWidth: .infinity)
                .padding(.horizontal, WoodPanelBackground.columnInset)
                .padding(.top, WoodPanelBackground.headerTopInset(awning: awning))
                .padding(.bottom, Tokens.s8)
            content
                .mask { edgeFade }
        }
        .padding(.bottom, WoodPanelBackground.contentInset)
        .background {
            ZStack(alignment: .top) {
                WoodPanelBackground(material: material, awning: awning)
                ornament
            }
            // La sombra del panel flotando sobre el juego: sin el material del
            // sheet del sistema, la profundidad la pone el propio panel.
            .shadow(color: .black.opacity(0.30), radius: 16, y: 6)
        }
        // Arriba el panel llega al borde del sheet (la barra de navegación
        // flota transparente sobre la banda); abajo NO: respeta la safe area,
        // que es lo que deja la banda inferior a la vista.
        .ignoresSafeArea(edges: .top)
    }

    /// El fundido que hace que las tarjetas SALGAN de adentro del panel en vez
    /// de cortarse contra una línea invisible: opaco en el medio, y disuelto en
    /// los últimos puntos contra la cabecera y contra la banda inferior.
    private var edgeFade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 12)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 18)
        }
    }
}

extension View {
    /// Enmarca el `ScrollView` de una hoja dentro del panel contenedor: la
    /// cabecera adentro del pergamino y el contenido recortado contra el marco.
    func panelSheet(
        material: WoodPanelBackground.Material = .wood,
        awning: Bool = false,
        @ViewBuilder header: () -> some View
    ) -> some View {
        modifier(PanelSheetLayout(
            material: material,
            awning: awning,
            header: header(),
            ornament: EmptyView()
        ))
    }

    /// Variante con decoración apoyada sobre el marco (el moño de Regalos).
    func panelSheet(
        material: WoodPanelBackground.Material = .wood,
        awning: Bool = false,
        @ViewBuilder header: () -> some View,
        @ViewBuilder ornament: () -> some View
    ) -> some View {
        modifier(PanelSheetLayout(
            material: material,
            awning: awning,
            header: header(),
            ornament: ornament()
        ))
    }
}

// MARK: - Telón de las vistas empujadas

/// El telón transparente de una vista EMPUJADA en el `NavigationStack` del
/// menú. Las hojas flotan sobre el juego atenuado porque se presentan con
/// `.presentationBackground(.clear)` — pero al empujar, UIKit le pinta
/// `systemBackground` al hosting controller del destino, y la franja que el
/// panel deja a la vista (abajo, respetando la safe area) pasa de mostrar el
/// juego a un blanco pelado (medido: gris 240 donde las demás hojas muestran
/// el juego). Las cinco pantallas empujadas —las cuatro del menú y los
/// legales— eran las únicas de la app que no flotaban.
///
/// En iOS 18 esto lo dice la API; en 17 el placement `.navigation` no existe,
/// así que una sonda UIKit limpia el fondo del view controller del destino.
extension View {
    /// Aplicar sobre el CONTENIDO de un `navigationDestination`.
    @ViewBuilder
    func clearNavigationBackdrop() -> some View {
        if #available(iOS 18.0, *) {
            containerBackground(.clear, for: .navigation)
        } else {
            background(LegacyClearNavigationBackdrop())
        }
    }
}

/// La sonda de iOS 17: sube por la cadena de responders hasta el PRIMER view
/// controller —el hosting del destino empujado, dueño del `systemBackground`—
/// y le limpia el fondo. No sigue más arriba: el navigation controller y la
/// hoja ya son transparentes, y tocarlos sería pintar de más.
private struct LegacyClearNavigationBackdrop: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeView { ProbeView() }
    func updateUIView(_ view: ProbeView, context: Context) {}

    final class ProbeView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var responder: UIResponder? = next
            while let current = responder {
                if let controller = current as? UIViewController {
                    controller.view.backgroundColor = .clear
                    return
                }
                responder = current.next
            }
        }
    }
}

// MARK: - PanelCard

/// El tablón en escala de TARJETA: el mismo lenguaje del marco de las hojas
/// —pergamino con luz, banda de madera con bisel, línea oscura, contorno ink
/// y tornillos— para los popups. Reemplaza a los marcos de arte 9-slice
/// (`panel_reward`, `panel_career`, `panel_prestige`, `panel_dialog`): eran
/// CUATRO estéticas distintas conviviendo con el tablón vectorial, y encima
/// cada una pedía insets medidos contra su PNG (pedido del dueño, 2026-08-18:
/// una sola familia visual, el fondo contiene y nada se superpone).
///
/// La banda es más finita que la del tablón (14 contra 22): a escala de popup
/// la banda llena domina la tarjeta en vez de enmarcarla.
struct PanelCard<Content: View>: View {
    private static var band: CGFloat { 14 }
    /// El margen que el contenido necesita para no pisar el marco: banda + aire.
    static var contentInset: CGFloat { 28 }

    var material: WoodPanelBackground.Material = .wood
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Self.contentInset)
            .background { frame }
    }

    private var frame: some View {
        GeometryReader { geo in
            let outer = RoundedRectangle(cornerRadius: 26, style: .continuous)
            let inner = RoundedRectangle(cornerRadius: 16, style: .continuous)
            let wood = material == .wood
            let bandFill = LinearGradient(
                colors: wood ? [WoodTone.light, WoodTone.base] : [MetalTone.light, MetalTone.base],
                startPoint: .top,
                endPoint: .bottom
            )
            let line = wood ? WoodTone.dark : MetalTone.dark
            let bevel = wood ? WoodTone.bevel : MetalTone.bevel
            let screw = wood ? WoodTone.screw : MetalTone.screw
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
                outer.strokeBorder(bandFill, lineWidth: Self.band)
                inner
                    .strokeBorder(line, lineWidth: 2.5)
                    .padding(Self.band - 2.5)
                inner
                    .strokeBorder(bevel.opacity(0.9), lineWidth: 2)
                    .padding(Self.band)
                outer.strokeBorder(Color("PaletteInk").opacity(0.9), lineWidth: 3)
                ForEach(0..<4, id: \.self) { corner in
                    PanelScrew(fill: screw, line: line, diameter: 10)
                        .position(
                            x: corner.isMultiple(of: 2) ? 15 : geo.size.width - 15,
                            y: corner < 2 ? 15 : geo.size.height - 15
                        )
                }
            }
            .clipShape(outer)
            // La sombra del popup flotando sobre el juego atenuado, hermana de
            // la del tablón de las hojas.
            .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
        }
    }
}

/// Un tornillo del marco: plato con borde oscuro y la ranura en diagonal.
/// En metal es un remache: mismo dibujo, tonos fríos.
private struct PanelScrew: View {
    let fill: Color
    let line: Color
    /// 12 en el tablón de las hojas; `PanelCard` lo baja a 10.
    var diameter: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(line, lineWidth: 2))
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(line)
                .frame(width: diameter * 0.58, height: 1.8)
                .rotationEffect(.degrees(45))
        }
        .frame(width: diameter, height: diameter)
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
