import SwiftUI

/// Design system v2 — los componentes compartidos del rediseño estilo Cow
/// Evolution. Hablan el mismo idioma que `GameArt.swift`: crema `PaletteCream`,
/// contorno `PaletteInk` de 2-3 pt, tipografía `.rounded` pesada, sombra suave,
/// y **siempre** un fallback vectorial cuando el arte del atlas todavía no está
/// (`UIArt` devuelve `nil` y la pantalla se dibuja igual).
///
/// Reglas que no se negocian acá:
/// - Ningún contenedor lleva `accessibilityIdentifier` (trampa 9a-bis del
///   handoff: un identifier en un `HStack`/`VStack` pelado se propaga y **pisa**
///   el de sus hijos, dejando un solo elemento en el árbol de AX). El id va en
///   cada control real.
/// - Ninguna animación `repeatForever` incondicional: mantiene vivo el display
///   link de SwiftUI toda la sesión (precedente: `SpawnButtonView.swift:36-46`).
///   El bounce del tab es un pulso disparado por el toque.
/// - Toda animación de pulido se apaga con `accessibilityReduceMotion` (spec
///   §11.2), y apagada tiene que dejar la pantalla en su estado FINAL, no en el
///   inicial: una tarjeta que entra con `opacity 0` y espera un `onAppear` que
///   nunca anima se quedaría invisible para siempre.

// MARK: - Tokens

/// Tipografía y espaciados del rediseño. Existe para dejar de repetir
/// `Font.system(.title3, design: .rounded).weight(.heavy)` en cada vista y para
/// que un cambio de escala sea un solo diff.
enum Tokens {
    static let display = Font.system(.title, design: .rounded).weight(.black)
    static let title = Font.system(.title3, design: .rounded).weight(.heavy)
    static let body = Font.system(.subheadline, design: .rounded).weight(.bold)
    static let caption = Font.system(.caption, design: .rounded).weight(.semibold)
    /// El único token de **peso normal**, para texto largo de verdad: los
    /// documentos legales (T16), que son las dos únicas pantallas del juego con
    /// párrafos de corrido. Los otros cuatro son pesados porque etiquetan cosas
    /// —un número, un nombre, un botón— y ahí el peso es lo que las separa del
    /// fondo; trescientas líneas de términos en `.bold` no se leen, se miran.
    /// Sigue siendo `.rounded`, así que no se ve de otra app.
    static let prose = Font.system(.subheadline, design: .rounded)

    /// Escala de espaciado 4/8/12/16/24. Nada de literales sueltos en las vistas.
    static let s4: CGFloat = 4
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s24: CGFloat = 24
}

// MARK: - Tono hundido

extension Color {
    /// El borde tono-sobre-tono del rediseño v3: el mismo color, hundido. Las
    /// referencias no bordean con tinta —el verde lleva borde verde oscuro, el
    /// naranja borde ladrillo, el crema borde marrón— y este helper es lo que
    /// evita seis constantes sueltas que se irían separando.
    func deepened(_ amount: Double = 0.35) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let k = 1 - amount
        return Color(red: r * k, green: g * k, blue: b * k, opacity: a)
    }

    /// El compañero de `deepened`: el mismo color con luz, para el degradé de
    /// las pills (arriba claro, abajo el tono).
    func lifted(_ amount: Double = 0.22) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: r + (1 - r) * amount,
            green: g + (1 - g) * amount,
            blue: b + (1 - b) * amount,
            opacity: a
        )
    }
}

// MARK: - PillBackground

/// La cápsula 3D del v3, compartida por `PricePill` y `ActionPill`: relleno
/// con la luz arriba, labio de brillo interior y borde hundido del MISMO tono
/// (la referencia no bordea los botones con tinta: el verde lleva verde
/// oscuro, el naranja ladrillo). Vive como componente para que los dos botones
/// —y cualquier tercero— no puedan separarse.
struct PillBackground: View {
    let fill: Color
    /// Borde a medida (la pill crema de "no te alcanza" lo pide marrón); por
    /// defecto, el propio relleno hundido.
    var border: Color?

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [fill.lifted(), fill],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                // El labio de luz del borde superior — es lo que hace caramelo
                // al botón. Se desvanece hacia abajo con la máscara.
                Capsule()
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5)
                    .padding(2.5)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
            .overlay(Capsule().strokeBorder(border ?? fill.deepened(), lineWidth: 2.5))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}

// MARK: - GameCard

/// La tarjeta de fila universal: crema, radio 18, contorno marrón cálido y
/// sombra suave. Unifica `UpgradesView.cardBackground` y
/// `FloorMapView.rowBackground`.
///
/// - `highlighted(color)` sube el borde a 3 pt del color de acento, TIÑE el
///   relleno con él y agrega un halo (piso actual, mejora recomendada, pack
///   destacado, pinta puesta): la tarjeta elegida de la referencia es amarilla
///   entera, no crema con un bordecito.
/// - `locked` es la tarjeta GRIS de la referencia (aviso confidencial, pinta
///   por ganar): relleno y borde grises + desaturación del contenido, en vez
///   de `.disabled`, que baja la opacidad del texto hasta volverlo ilegible.
/// Materiales de tarjeta del v3, fuera del genérico para que los llamadores no
/// tengan que nombrar una especialización (`GameCard<EmptyView>.x`) y para que
/// los `let` existan UNA vez.
enum CardMaterials {
    /// El radio de TODAS las tarjetas del juego. Expuesto porque los platos y
    /// retratos que viven adentro derivan el suyo restándole aire, y un radio
    /// suelto por pantalla es lo que la regla visual del dueño prohíbe.
    static let cornerRadius: CGFloat = 18

    /// Los grises de la tarjeta bloqueada, compartidos con `StateBadge`: el
    /// mismo "no todavía" tiene que ser el mismo gris en los dos.
    static let lockedFill = Color(red: 0.906, green: 0.882, blue: 0.831)   // #E7E1D4
    static let lockedBorder = Color(red: 0.722, green: 0.690, blue: 0.627) // #B8B0A0
}

struct GameCard<Content: View>: View {
    enum Style {
        case normal
        case highlighted(Color)
        case locked
    }

    var style: Style = .normal
    /// Si el CONTENIDO se apaga junto con la tarjeta bloqueada. El default es
    /// el misterio (aviso confidencial, pinta por ganar: todo gris); Regalos lo
    /// apaga en `false` porque su referencia muestra el boost bloqueado con el
    /// arte a color sobre la tarjeta gris — la zanahoria se ve, lo que falta lo
    /// dice el badge.
    var contentDimsWhenLocked: Bool = true
    @ViewBuilder var content: () -> Content

    private var isLocked: Bool {
        if case .locked = style { return true }
        return false
    }

    private var accent: Color? {
        if case .highlighted(let color) = style { return color }
        return nil
    }

    var body: some View {
        content()
            .padding(Tokens.s12)
            .background(background)
            .saturation(isLocked && contentDimsWhenLocked ? 0.2 : 1)
            .opacity(isLocked ? 0.9 : 1)
    }

    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
        let border: Color = accent ?? (isLocked ? CardMaterials.lockedBorder : Color("PaletteBrown").opacity(0.55))
        return shape
            .fill(isLocked ? CardMaterials.lockedFill : Color("PaletteCream"))
            .overlay {
                // El teñido de la tarjeta destacada: el acento por encima del
                // crema, no en su lugar — así el amarillo de "este" y el verde
                // de "conviene" salen cálidos y el contenido sigue legible.
                if let accent {
                    shape.fill(accent.opacity(0.16))
                }
            }
            .overlay(shape.strokeBorder(border, lineWidth: accent == nil ? 2 : 3))
            .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
            .shadow(color: (accent ?? .clear).opacity(0.35), radius: 8)
    }
}

// MARK: - SectionHeader

/// Título de sección dentro de un panel: cinta naranja con las puntas en V y el
/// texto crema encima. Es el hermano "de sección" de `PanelTitleBanner`, que es
/// el título de la pantalla entera y va en crema.
///
/// ⚠️ La cinta es **vectorial y no** `ui_header_ribbon` en 9-slice, aunque la
/// clave esté integrada: el dibujo del PNG ocupa sólo la franja `y 71…120` de un
/// lienzo de 192² (37% de margen transparente arriba y abajo), y `nineSlice`
/// mide los capInsets sobre el lienzo COMPLETO —200 pt— así que un header de
/// ~40 pt de alto queda con insets más grandes que su propio alto y se deforma
/// hasta ser una mancha. Medido el 2026-08-14 renderizando el componente. El
/// vector copia la forma del PNG, así que si alguna vez se re-exporta recortado
/// el cambio es invisible.
struct SectionHeader: View {
    private let label: Text

    init(_ titleKey: LocalizedStringKey) {
        label = Text(titleKey)
    }

    /// Cinta con un texto **ya resuelto**. La necesita todo título que lleve
    /// adentro un nombre que sale del dato ("Pintas de El Fisura"): esa frase se
    /// arma con `String(localized: "clave \(nombre)")` en el estado, y volver a
    /// envolverla en un `LocalizedStringKey` la convertiría en una clave que el
    /// catálogo no tiene (trampa 5 del HANDOFF).
    init(verbatim text: String) {
        label = Text(verbatim: text)
    }

    var body: some View {
        HStack(spacing: Tokens.s8) {
            Sparkle()
            label
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteCream"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            Sparkle()
        }
        .padding(.horizontal, Tokens.s16)
        .padding(.vertical, Tokens.s8)
        .background { RibbonBackground() }
        // Aire para que las colas —que sobresalen de la banda— no queden
        // recortadas por el borde del scroll.
        .padding(.horizontal, 20)
    }
}

/// El destello crema que flanquea el texto de la cinta (los ✦ de la
/// referencia). Decoración pura.
private struct Sparkle: View {
    var body: some View {
        SparkleShape()
            .fill(Color("PaletteCream").opacity(0.9))
            .frame(width: 10, height: 10)
            .shadow(color: .black.opacity(0.2), radius: 0.5, y: 0.5)
            .accessibilityHidden(true)
    }
}

/// La cinta v3, en tres capas: colas caídas por detrás, pliegues oscuros donde
/// la banda las tapa, y la banda con la luz arriba. Todo derivado de
/// `PaletteOrange` vía `deepened`/`lifted`, así el naranja de la casa sigue
/// siendo UNO.
private struct RibbonBackground: View {
    private static let tailWidth: CGFloat = 30

    var body: some View {
        ZStack {
            tails
            band
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }

    private var band: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return shape
            .fill(
                LinearGradient(
                    colors: [Color("PaletteOrange").lifted(0.14), Color("PaletteOrange")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(shape.strokeBorder(Color("PaletteOrange").deepened(0.3), lineWidth: 2.5))
            // Los pliegues: el dobladillo oscuro que asoma bajo cada esquina,
            // donde la cola pasa por detrás de la banda.
            .overlay(alignment: .bottomLeading) { fold }
            .overlay(alignment: .bottomTrailing) { fold }
    }

    private var fold: some View {
        FoldTriangleShape()
            .fill(Color("PaletteOrange").deepened(0.55))
            .frame(width: 10, height: 7)
            .offset(y: 6)
    }

    private var tails: some View {
        HStack(spacing: 0) {
            tail.rotationEffect(.degrees(-6), anchor: .trailing)
            Spacer(minLength: 0)
            tail.scaleEffect(x: -1).rotationEffect(.degrees(6), anchor: .leading)
        }
        .padding(.horizontal, -Self.tailWidth + 12)
        .offset(y: 7)
    }

    /// Una cola: el mismo `RibbonShape` de siempre; la muesca interior queda
    /// escondida detrás de la banda, así que sólo se ve la V del extremo.
    private var tail: some View {
        RibbonShape()
            .fill(Color("PaletteOrange").deepened(0.18))
            .overlay(RibbonShape().strokeBorder(Color("PaletteOrange").deepened(0.45), lineWidth: 2))
            .frame(width: Self.tailWidth + 14, height: 30)
    }
}

/// Rombo de cuatro puntas (✦): las puntas en los ejes y los valles en las
/// diagonales.
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.3
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - outer))
        for index in 0..<4 {
            let innerAngle = Double(index) * .pi / 2 - .pi / 4
            let outerAngle = Double(index + 1) * .pi / 2 - .pi / 2
            path.addLine(to: CGPoint(
                x: center.x + CGFloat(cos(innerAngle)) * inner,
                y: center.y + CGFloat(sin(innerAngle)) * inner
            ))
            path.addLine(to: CGPoint(
                x: center.x + CGFloat(cos(outerAngle)) * outer,
                y: center.y + CGFloat(sin(outerAngle)) * outer
            ))
        }
        path.closeSubpath()
        return path
    }
}

/// El triángulo del pliegue, apuntando hacia abajo.
struct FoldTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Cinta con las puntas cortadas en V, como el `ui_header_ribbon` del atlas.
struct RibbonShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        let notch = min(16, rect.width * 0.12)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> RibbonShape {
        RibbonShape(inset: inset + amount)
    }
}

// MARK: - ProgressBar

/// Barra de progreso: pista crema, relleno teñido y contorno ink. `labelText` va
/// centrado sobre la barra — texto ya formateado por quien la usa (3/10,
/// 240/1000).
///
/// ⚠️ Igual que `SectionHeader`, **no** usa `ui_progress_bar` en 9-slice: el PNG
/// tiene el mismo problema medido (la barra ocupa `y 71…119` de 192, 37% de
/// margen transparente arriba y abajo), y a 20 pt de alto los capInsets la
/// aplastan hasta que el contorno negro desaparece.
///
/// ⚠️ **Publica etiqueta Y valor.** El valor solo ("Nivel 3 / 20", "34%") deja un
/// elemento que VoiceOver anuncia sin decir de QUÉ es el número; la etiqueta dice
/// qué mide y el valor cuánto va, que es el reparto que espera el lector. Quien
/// necesite una etiqueta más específica la pisa desde afuera con
/// `.accessibilityLabel` —el modificador de más afuera gana—, y quien no quiera
/// que la barra hable la tapa entera (lo hace `AchievementsView`, donde el
/// progreso ya viaja en el resumen de la fila).
struct ProgressBar: View {
    let progress: Double
    let tint: Color
    var labelText: String?

    /// El progreso llega de divisiones que pueden dar `NaN` (un logro con
    /// objetivo 0) o pasarse de 1 (contador que siguió corriendo). La barra se
    /// defiende sola en vez de confiar en cada llamador.
    var clampedProgress: Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color("PaletteInk").opacity(0.12))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * clampedProgress)
                if let labelText {
                    Text(verbatim: labelText)
                        .font(Tokens.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, Tokens.s8)
                        .frame(width: geo.size.width)
                }
            }
            .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2.5))
        }
        .frame(height: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("progress.ax.label"))
        .accessibilityValue(Text(verbatim: labelText ?? "\(Int(clampedProgress * 100))%"))
    }
}

// MARK: - StaggeredAppearance

/// La aparición escalonada de las tarjetas de un panel (spec §11.2): cada fila
/// entra con un desfase de 30 ms contra la anterior, así el contenido "cae" de
/// arriba abajo en vez de aparecer de golpe.
///
/// Vive acá y no en cada pantalla porque las cuatro listas largas del juego
/// —FisuJobs, Mejoras, Regalos y la tienda— tienen que cascadear IGUAL: dos
/// ritmos distintos se leen como dos juegos (regla visual del dueño).
///
/// ⚠️ **El tope de 8 filas no es cosmético.** FisuJobs dibuja 43 tarjetas: sin
/// tope, la última entraría a 1,3 s de abierta la hoja y la pantalla se leería
/// rota. Con el tope, todo lo que está fuera de la primera pantalla comparte el
/// desfase máximo (210 ms) y ya está adentro antes de que nadie llegue a
/// scrollear.
///
/// ⚠️ **La bandera vive en la MISMA vista que anima, con su propio `onAppear`**
/// (trampa 9 del HANDOFF: una animación cuyo `@State` cambió antes de que la
/// vista exista no arranca nunca). Y con Reduce Motion la tarjeta arranca
/// **visible**, sin depender de que el `onAppear` corra: el estado apagado es el
/// final, no el inicial.
struct StaggeredAppearance: ViewModifier {
    /// Posición de la tarjeta contando desde arriba del panel, secciones
    /// incluidas. No es el índice dentro de su sección: la cascada es del PANEL.
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// Cuántas filas escalonan antes de que el desfase se congele.
    static let staggeredRows = 8
    /// El desfase por fila (spec §11.2).
    static let step: TimeInterval = 0.03

    /// El retraso de la fila `index`, ya topeado. Expuesto —y testeado— porque es
    /// la única parte de esta animación que se puede assertar sin renderizar.
    static func delay(forIndex index: Int) -> TimeInterval {
        Double(min(max(index, 0), staggeredRows - 1)) * step
    }

    /// Con Reduce Motion no hay estado intermedio: la tarjeta ya está puesta.
    private var visible: Bool { reduceMotion || appeared }

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            // `offset` y no `padding`: no toca el layout, así que la columna no
            // se reacomoda mientras las tarjetas entran.
            .offset(y: visible ? 0 : 14)
            .onAppear {
                guard !reduceMotion, !appeared else { return }
                withAnimation(.snappy(duration: 0.28).delay(Self.delay(forIndex: index))) {
                    appeared = true
                }
            }
    }
}

extension View {
    /// Entrada escalonada de una tarjeta de panel. `index` es su posición desde
    /// arriba del panel (ver `StaggeredAppearance`).
    func staggeredAppearance(index: Int) -> some View {
        modifier(StaggeredAppearance(index: index))
    }
}

// MARK: - PricePill

/// El botón de precio estilo "cinta" de Cow Evolution: moneda + monto ya
/// formateado (`CoinFormatter`) sobre una cápsula verde.
///
/// Sin saldo **no** se usa `.disabled`: el dimming del sistema deja el texto
/// ilegible (ver `SpawnButtonView.swift:25-33`). El botón queda tappable —la
/// acción falla sola si no alcanza— y el estado se comunica con el relleno
/// crema, el texto ink y una leve desaturación.
///
/// Y como el botón se puede tocar sin que alcance, el "no" hay que decirlo:
/// tocarlo sin saldo lo hace **temblar** 0,3 s (spec §11.2). Es un pulso de
/// keyframes disparado por el toque —ni timer ni `repeatForever`—, así que en
/// reposo no hay ninguna animación viva.
///
/// ⚠️ **Lo que dice en voz alta se arma entre los dos**: el componente pone el
/// monto CON su moneda (el glifo de la moneda es un dibujo y VoiceOver no lo ve,
/// así que "1,2K" a secas no decía en qué se paga) y el llamador pone el
/// `accessibilityPurpose`, que es lo único que él sabe: QUÉ compra este precio.
/// Sin propósito, media pantalla de botones dice sólo un número y en el rotor no
/// se distingue cuál es cuál. Se compone acá adentro —y no con un
/// `.accessibilityLabel` afuera— justamente para que la moneda no se pueda
/// perder al escribir el llamador.
struct PricePill: View {
    enum Currency {
        case coins
        case oro
        /// Plata de verdad (IAP). El texto lo pone StoreKit (`displayPrice`) y el
        /// glifo es un carrito y **no** una moneda del juego: con la moneda
        /// puesta, "USD 1,99" se lee como si costara monedas.
        case money
    }

    let text: String
    let currency: Currency
    let affordable: Bool
    let identifier: String
    /// **Qué** compra este precio, ya resuelto por el llamador ("Contratar a El
    /// Fisura", "Comprar Pack de Arranque"). El componente le pega el monto y la
    /// moneda detrás; sin él la parada dice sólo el número.
    var accessibilityPurpose: Text?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake = 0

    /// El monto con su moneda dicha con todas las letras.
    ///
    /// ⚠️ `.money` va **verbatim**: `displayPrice` lo escribe StoreKit y ya trae
    /// la moneda del jugador ("USD 1,99"), así que agregarle una palabra la diría
    /// dos veces. Expuesto —no privado— porque es lo único de esta etiqueta que
    /// se puede assertar sin renderizar, y el test que lo lee es también el que
    /// atrapa la clave que no llegó al catálogo.
    var spokenAmount: String {
        switch currency {
        case .coins: String(localized: "price.ax.coins \(text)")
        case .oro: String(localized: "price.ax.oro \(text)")
        case .money: text
        }
    }

    /// La parada completa: propósito (si lo hay) y monto.
    private var spokenLabel: Text {
        guard let accessibilityPurpose else { return Text(verbatim: spokenAmount) }
        return accessibilityPurpose + Text(verbatim: ", \(spokenAmount)")
    }

    var body: some View {
        Button {
            // El temblor es lo que reemplaza al `.disabled`: dice "no te alcanza"
            // sin apagar el botón. Se dispara ANTES de la acción —que en el caso
            // caro no va a hacer nada— y sólo cuando el precio no está a tiro.
            if !affordable, !reduceMotion { shake += 1 }
            action()
        } label: {
            HStack(spacing: 6) {
                switch currency {
                case .coins: CoinIcon(size: 20)
                case .oro: OroIcon(size: 20)
                case .money:
                    Image(systemName: "cart.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(affordable ? .white : Color("PaletteInk"))
                        .frame(width: 20, height: 20)
                }
                Text(verbatim: text)
                    .font(Tokens.body)
                    .monospacedDigit()
                    .foregroundStyle(affordable ? .white : Color("PaletteInk"))
                    .shadow(color: .black.opacity(affordable ? 0.45 : 0), radius: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, Tokens.s12)
            .padding(.vertical, Tokens.s8)
            .frame(minWidth: 92)
            .background(
                // Verde caramelo cuando alcanza; la píldora crema con borde
                // marrón de la referencia cuando no.
                PillBackground(
                    fill: affordable ? Color("PaletteGreen") : Color("PaletteCream"),
                    border: affordable ? nil : Color("PaletteBrown").opacity(0.6)
                )
            )
            .saturation(affordable ? 1 : 0.7)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(spokenLabel)
        // ±4 pt, cuatro tramos, 0,3 s en total. Va **último** para que el
        // identifier quede pegado al botón y no a un contenedor de más
        // (trampa 9a-bis): `offset` no crea un elemento de accesibilidad.
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
}

// MARK: - ActionPill

/// El hermano de `PricePill` para las acciones que **no cuestan plata**
/// ("Ponérsela"): misma cápsula, mismo alto, mismo contorno ink, con un glifo en
/// vez de la moneda.
///
/// Existe como componente y no como una cápsula local porque es el tercer papel
/// del mismo lenguaje y los tres tienen que verse hermanos: `PricePill` cobra,
/// `ActionPill` hace, y `StateBadge` sólo informa (y por eso es el único que no
/// es un botón). Sin él, cada pantalla nueva se dibuja su propio botón verde y a
/// la tercera ya no son el mismo juego.
///
/// Como `PricePill`, **nunca** usa `.disabled`: una acción que no corresponde no
/// se dibuja.
struct ActionPill: View {
    let title: Text
    let systemImage: String
    var tint: Color = Color("PaletteGreen")
    let identifier: String
    /// Etiqueta hablada. El título solo ("Ponérsela") no dice de QUÉ, y en una
    /// grilla de tres tarjetas hay tres botones que dicen lo mismo.
    var accessibilityLabel: Text?
    let action: () -> Void

    init(
        titleKey: LocalizedStringKey, systemImage: String, tint: Color = Color("PaletteGreen"),
        identifier: String, accessibilityLabel: Text? = nil, action: @escaping () -> Void
    ) {
        self.init(title: Text(titleKey), systemImage: systemImage, tint: tint, identifier: identifier,
                  accessibilityLabel: accessibilityLabel, action: action)
    }

    /// Un título que ya viene resuelto: el nombre de un visitante, un monto
    /// interpolado por `VisitCopy`.
    init(
        verbatim title: String, systemImage: String, tint: Color = Color("PaletteGreen"),
        identifier: String, accessibilityLabel: Text? = nil, action: @escaping () -> Void
    ) {
        self.init(title: Text(verbatim: title), systemImage: systemImage, tint: tint, identifier: identifier,
                  accessibilityLabel: accessibilityLabel, action: action)
    }

    private init(
        title: Text, systemImage: String, tint: Color, identifier: String,
        accessibilityLabel: Text?, action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.identifier = identifier
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                title
                    .font(Tokens.body)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
            .padding(.horizontal, Tokens.s12)
            .padding(.vertical, Tokens.s8)
            .frame(minWidth: 92)
            .background(PillBackground(fill: tint))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

// MARK: - PagerChevronButton

/// Las flechas ‹ › de un paginador de la casa (la ficha, el menú deslizable):
/// plato crema con borde marrón. Sin vuelta en los extremos: el llamador pone
/// `.disabled` y la cara lo dibuja leyendo `isEnabled`, sin el atenuado del
/// sistema (que deja el glifo ilegible).
struct PagerChevronButton: View {
    enum Direction {
        case previous
        case next
    }

    let direction: Direction
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PagerChevronLabel(systemName: direction == .previous ? "chevron.left" : "chevron.right")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(labelKey))
    }

    /// Escritas enteras: armar la clave por interpolación no la resuelve (trampa 5).
    private var labelKey: LocalizedStringKey {
        switch direction {
        case .previous: "pager.previous.ax"
        case .next: "pager.next.ax"
        }
    }
}

private struct PagerChevronLabel: View {
    let systemName: String
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(Color("PaletteInk").opacity(isEnabled ? 1 : 0.3))
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(Color("PaletteCream"))
                    .overlay(
                        Circle().strokeBorder(
                            Color("PaletteBrown").opacity(isEnabled ? 0.7 : 0.3),
                            lineWidth: 2
                        )
                    )
            )
            .contentShape(Circle())
    }
}

// MARK: - StateBadge

/// Lo que ocupa el lugar del botón cuando la fila **no ofrece una acción**:
/// cápsula con un glifo opcional y un texto corto. `muted` la apaga (crema
/// translúcido, contorno tenue, candado) para "no se puede"; sin apagar va en
/// naranja, para "acá pasa algo".
///
/// El texto llega ya resuelto (`String`) y no como clave: los mensajes que
/// muestra llevan adentro un nombre de piso o de personaje que el estado
/// interpola.
///
/// ⚠️ Nació privado en `FisuJobsView` (T8) y se mudó acá al segundo llamador
/// (T11): es el badge de estado del juego, y dos copias con dibujos que se van
/// separando es exactamente lo que la regla visual del dueño prohíbe. No lleva
/// identifier ni traits: **no es un control**.
///
/// ⚠️ **Y no hay un solo trato con VoiceOver: hay dos, y los elige el
/// llamador** según cómo navegue SU pantalla.
/// - `.accessibilityHidden(true)` donde la fila es **una** parada y su valor ya
///   dice este mismo estado: repetirlo sería decirlo dos veces (FisuJobs, la
///   tienda, Pintas, Logros — el patrón T8: tapar la info, nunca el control).
/// - `.accessibilityElement(children: .combine)` + identifier donde la pantalla
///   navega **por paradas** y este badge es el único lugar donde el estado
///   existe (Regalos, Mejoras). El `combine` no es decoración: sin él el glifo
///   queda como una parada muda al lado del texto.
///
/// Taparlo "por las dudas" en una pantalla del segundo grupo borra el estado del
/// árbol y nadie se entera hasta que alguien lo escucha.
struct StateBadge: View {
    let text: String
    /// Glifo a la izquierda (`lock.fill`, `checkmark.circle.fill`), o `nil`.
    var systemImage: String?
    /// Cómo se parte un texto de dos renglones. Nació en el riel derecho de
    /// FisuJobs —donde `.trailing` es lo que alinea el badge con el borde de la
    /// tarjeta— y por eso ese es el default; adentro de una tarjeta centrada, el
    /// llamador pide `.center` o el renglón corto queda pegado a la derecha.
    var textAlignment: TextAlignment = .trailing
    let muted: Bool

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .black))
            }
            Text(verbatim: text)
                .font(Tokens.caption)
                .multilineTextAlignment(textAlignment)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
        }
        .foregroundStyle(Color("PaletteInk").opacity(muted ? 0.6 : 1))
        .padding(.horizontal, Tokens.s8 + 2)
        .padding(.vertical, 6)
        .background(
            // Cápsula y no rectángulo: los badges de la referencia son
            // píldoras ("Wearing it", "No details", "Unlocks at Corporate").
            // muted comparte los grises de `GameCard.locked` — el mismo "no
            // todavía" es el mismo gris en la tarjeta y en su badge — y el
            // resto va en el naranja teñido con su borde hundido, como los
            // materiales v3 de las pills.
            Capsule()
                .fill(muted ? CardMaterials.lockedFill : Color("PaletteOrange").opacity(0.22))
                .overlay(
                    Capsule().strokeBorder(
                        muted ? CardMaterials.lockedBorder : Color("PaletteOrange").deepened(0.25).opacity(0.75),
                        lineWidth: 2
                    )
                )
        )
    }
}

// MARK: - RowDivider

/// La línea entre dos filas de una `GameCard`.
///
/// No es `Divider()`: el separador del sistema es un gris frío que en una
/// tarjeta crema con contorno ink se lee como de otra app. Nació privado en
/// `StatsView` (T15) y se mudó acá al segundo llamador (Ajustes, T16) por la
/// misma razón que `StateBadge`: dos copias de la misma línea se separan a la
/// tercera pantalla.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color("PaletteInk").opacity(0.12))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - CountBadge

/// Badge "×N" para el organigrama y los contadores por tipo: cápsula crema con
/// borde ink. `dimmed` es el estado "no tenés ninguno": se apaga, no desaparece.
///
/// ⚠️ No usa `ui_badge`: ese PNG es un **círculo rojo de alerta** (con su
/// colita), no una cápsula de conteo — sirve para el puntito de "hay regalos",
/// no para un "×12" que tiene que poder crecer a lo ancho.
struct CountBadge: View {
    let count: Int
    let dimmed: Bool

    /// Expuesto para tests: el signo es `×` (el mismo que usan las filas de
    /// mejora), no una "x" de teclado.
    var text: String { "×\(count)" }

    var body: some View {
        Text(verbatim: text)
            .font(Tokens.caption)
            .monospacedDigit()
            .foregroundStyle(Color("PaletteInk").opacity(dimmed ? 0.45 : 1))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, Tokens.s8)
            .padding(.vertical, 3)
            .frame(minWidth: 32)
            .background {
                Capsule()
                    .fill(Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(dimmed ? 0.35 : 0.7), lineWidth: 2))
            }
            .opacity(dimmed ? 0.8 : 1)
    }
}


/// El puntito rojo de "hay algo para cobrar": `ui_badge` del atlas (el círculo
/// de alerta con su colita, ya recortado al bbox del alfa) con fallback
/// vectorial en el rojo muestreado del PNG.
///
/// ⚠️ Va SIEMPRE como `.overlay` del plato o la tarjeta que avisa — nunca un
/// hijo del layout (la barra inferior va 374 ≤ 375 pt en SE y no hay margen
/// para un solo punto más) ni un elemento de AX propio (trampa 9a): el aviso
/// viaja en el `accessibilityValue` del control que lo lleva.
struct NotificationBadge: View {
    var size: CGFloat = 20

    var body: some View {
        GameIcon(artKey: "ui_badge", size: size) {
            Circle()
                .fill(Color(red: 227 / 255, green: 58 / 255, blue: 51 / 255))
                .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 2))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - IconButton

/// Botón circular de icono (52×52 por defecto): base crema con borde ink y el
/// glifo adentro. Generaliza `HUDView.hudIconButton` — el arte del atlas manda y
/// el `fallback` (un icono vectorial o un SF Symbol) entra sólo si la clave no
/// está integrada. `artKey` es opcional porque hay botones que hoy sólo tienen
/// vectorial.
struct IconButton: View {
    let artKey: String?
    let fallback: () -> AnyView
    var size: CGFloat = 52
    /// Si el glifo lleva su plato circular crema detrás. El HUD rediseñado lo
    /// apaga (decisión del dueño 2026-08-18): los dos accesos de la barra
    /// superior son el dibujo pelado y grande, sin aro que lo achique.
    var showsPlate: Bool = true
    /// Qué fracción del plato ocupa el glifo. El default es el histórico —el
    /// dibujo flotando con aire crema alrededor— y existe justamente para que
    /// los llamadores que no lo piden no cambien de cara. El HUD rediseñado sube
    /// a 0,66 por lo mismo que los tabs de abajo crecieron: el dibujo tiene que
    /// ser el que manda, no el plato que lo enmarca. Con el aire de fábrica, a
    /// esa escala el plato se lee más que el icono que lleva adentro.
    var glyphScale: CGFloat = 0.52
    /// Ancho del botón como fracción del alto (`size`). Con 1 el botón es el
    /// cuadrado histórico y el arte conserva su proporción; con otro valor el
    /// glifo se ESTIRA deliberadamente a ese ancho — es lo que pidió el dueño
    /// para el ascensor del HUD (2026-08-18): el arte de la cabina es angosto
    /// y lo quiere más ancho, no más chico dentro de un cuadrado más grande.
    var glyphAspect: CGFloat = 1
    let tint: Color
    let labelKey: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            glyph
                .frame(width: size * glyphAspect * (showsPlate ? glyphScale : 1),
                       height: size * (showsPlate ? glyphScale : 1))
                .frame(width: size * glyphAspect, height: size)
                .background {
                    if showsPlate {
                        Circle()
                            .fill(Color("PaletteCream"))
                            .overlay(Circle().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2.5))
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(LocalizedStringKey(labelKey)))
    }

    @ViewBuilder private var glyph: some View {
        if let artKey, let image = UIArt.image(artKey) {
            if glyphAspect == 1 {
                image.resizable().scaledToFit()
            } else {
                // Estirado al marco pedido: es la mitad del contrato de
                // `glyphAspect` — sin esto, `scaledToFit` devolvería el dibujo
                // angosto centrado en un botón ancho.
                image.resizable()
            }
        } else {
            // El tint pinta los fallbacks monocromos (SF Symbols); los iconos
            // vectoriales traen sus propios rellenos de paleta y lo ignoran.
            fallback().foregroundStyle(tint)
        }
    }
}

// MARK: - GameIcon

/// Glifo del juego: el PNG del atlas si la clave está integrada, si no el
/// vectorial. Es el punto exacto donde el batch de iconos entra **sin tocar
/// código** — basta con que `assets_manifest.json` tenga la clave.
struct GameIcon<Vector: View>: View {
    let artKey: String
    var size: CGFloat = 30
    @ViewBuilder var vector: () -> Vector

    var body: some View {
        Group {
            if let image = UIArt.image(artKey) {
                image.resizable().scaledToFit()
            } else {
                vector()
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - GameTabBar

/// Las 6 pantallas de la barra inferior. El orden de `allCases` **es** el orden
/// de los tabs (spec §4) y los tests lo pinean.
enum GameScreen: String, Identifiable, CaseIterable {
    case jobs
    case upgrades
    case skins
    case gifts
    case store
    case menu

    var id: String { rawValue }

    /// Identifier de accesibilidad del tab. `hud.upgrades`, `hud.bonus` y
    /// `hud.store` vienen pineados por los tests de UI que ya existen: cambiarlos
    /// los rompe.
    var identifier: String {
        switch self {
        case .jobs: "hud.hire"
        case .upgrades: "hud.upgrades"
        case .skins: "hud.skins"
        case .gifts: "hud.bonus"
        case .store: "hud.store"
        case .menu: "hud.settings"
        }
    }

    /// El orden de la barra de abajo y del paginador del menú (PLAN-v2 E3):
    /// Contratar al centro, dos y dos. La Tienda no está: la abre el + de la
    /// moneda (PLAN-v2 E13, ítem 14). NO es `allCases`, que conserva el orden
    /// histórico.
    static let barOrder: [GameScreen] = [.upgrades, .skins, .jobs, .gifts, .menu]

    /// La pestaña del centro, la más grande.
    static let centerTab: GameScreen = .jobs
}

/// Un tab: la pantalla que abre, su icono ya type-borrado, el label de AX y si
/// va destacado (Contratar, al centro, como la vaca de Cow Evolution).
struct GameTabItem: Identifiable {
    let screen: GameScreen
    let icon: AnyView
    let labelKey: String
    let identifier: String
    let prominent: Bool
    /// El puntito de "hay algo para cobrar" (hoy: logros, en el tab Menú).
    let showsBadge: Bool
    /// Se abrió hace poco y todavía no se miró: lleva "¡Nuevo!".
    let isNew: Bool

    var id: String { screen.rawValue }

    init(screen: GameScreen,
         icon: AnyView,
         labelKey: String,
         identifier: String,
         prominent: Bool = false,
         showsBadge: Bool = false,
         isNew: Bool = false) {
        self.isNew = isNew
        self.screen = screen
        self.icon = icon
        self.labelKey = labelKey
        self.identifier = identifier
        self.prominent = prominent
        self.showsBadge = showsBadge
    }
}

/// Barra inferior de pantallas. No guarda selección —cada tab abre su hoja— así
/// que el estado "activo" es el destaque de los extremos más el pulso del toque.
///
/// Dejó de ser una isla flotante: ahora es una franja de ancho completo fundida
/// con el borde de abajo, **gemela** del `topPanel` de `HUDView` arriba —mismo
/// crema, mismo contorno ink de 3 pt, mismas esquinas de 24, y en cada una el
/// trazo se ve sólo en la cara que da al tablero—. La isla gastaba tres márgenes
/// de pantalla en aire alrededor de una barra que igual vivía pegada al fondo, y
/// el crema recortado contra el tablero competía con las tarjetas del juego, que
/// usan la misma forma.
///
/// ⚠️ El `HStack` NO lleva identifier: cada botón lleva el suyo (trampa 9a-bis).
struct GameTabBar: View {
    let items: [GameTabItem]
    let selection: (GameScreen) -> Void

    /// Aire mínimo entre los nombres de los tabs y el borde FÍSICO de abajo.
    ///
    /// Es el mismo piso que `HUDView.minimumTopGap` y existe por lo mismo, en el
    /// otro borde: en un teléfono sin home indicator (SE) la safe area inferior
    /// es 0, así que el panel fundido —que llega hasta el borde— apoyaba los
    /// labels contra el bezel. Medido en un SE 3 antes del piso: la 'j' de
    /// "Mejoras" a **1,5 pt** del borde físico. Con home indicator el inset ya
    /// pone 34, el `max` devuelve 0 y el layout **no cambia en nada** —de ahí
    /// que `BoardScene.bottomInset` siga valiendo lo mismo—.
    private static let minimumBottomGap: CGFloat = 12
    private var bottomGap: CGFloat {
        ScreenInsets.floorGap(minimum: Self.minimumBottomGap, inset: ScreenInsets.shared.bottom)
    }

    /// Cuánto SUBE la barra por el piso de arriba, para lo que se apoye sobre
    /// ella (hoy: los dos toasts de `RootView`, que se posicionan contando desde
    /// la safe area y por lo tanto no ven el piso por su cuenta).
    @MainActor static var bottomFloor: CGFloat {
        ScreenInsets.floorGap(minimum: minimumBottomGap, inset: ScreenInsets.shared.bottom)
    }

    /// Aire arriba de los platos comunes, adentro del panel.
    static let topPadding: CGFloat = 6
    /// Plato de una pestaña común y el de Contratar.
    static let plateSide: CGFloat = 52
    static let centerPlateSide: CGFloat = 72
    /// El espacio entre pestañas: el literal 2 de la v1.
    static let spacing: CGFloat = 2

    /// Aire entre los platos y el piso de la barra, ahora que no hay rótulos.
    static let bottomPadding: CGFloat = 6
    /// Lugares por lado de Contratar: la barra es 2 + 1 + 2.
    static let slotsPerSide = 2

    enum Side { case leading, trailing }

    /// Los lugares de un lado de la barra, del borde al centro (`leading`) o del centro al borde
    /// (`trailing`). Las pestañas se pegan a Contratar: con una sola abierta, ocupa el lugar de al
    /// lado del centro (PLAN-v2 E13, ítem 14).
    static func slots(_ items: [GameTabItem], towardCenterFrom side: Side) -> [GameTabItem?] {
        let padding = [GameTabItem?](repeating: nil, count: max(0, slotsPerSide - items.count))
        let filled = items.prefix(slotsPerSide).map { Optional($0) }
        return side == .leading ? padding + filled : filled + padding
    }

    /// Alto del panel visible, sin la safe area ni el piso de abajo: 6 de aire +
    /// 52 de plato + 6 hasta el piso. Es lo que le tapa el tablero a la
    /// multitud (`BoardScene.bottomInset`): 20 pt menos que la v1 (84), que es lo
    /// que pidió la crítica de la barra (PLAN-v2 §2).
    static let panelHeight: CGFloat = 64
    /// Cuánto sobresale Contratar por encima del panel.
    static let centerRise: CGFloat = centerPlateSide - plateSide

    /// Alto del cuadro entero, con Contratar sobresaliendo. Sobre esto se apoya
    /// la pila de arriba —el atajo, el prestigio y los dos toasts de `RootView`—,
    /// así que conserva el nombre y el valor de la v1 (84) y esa pila no se
    /// mueve. `BoardScene.bottomInset` y el espejo de `AscentRenderingUITests`
    /// lo siguen leyendo.
    ///
    /// ⚠️ Aislado al main actor como todo el tipo: `GameTabBar` conforma `View`
    /// y la conformance aísla al struct entero y a sus statics. `BoardScene` lo
    /// lee sin problema porque `SKScene` también es `@MainActor`; un contexto
    /// `nonisolated` necesitaría `nonisolated static let`.
    static let barHeight: CGFloat = panelHeight + centerRise

    /// El ancho fijo de la columna de Contratar: su plato y un poco de aire para
    /// el nombre. Fijo, para que las dos zonas se repartan el resto por igual.
    static let centerColumnWidth: CGFloat = centerPlateSide + Tokens.s8

    /// El ancho mínimo de la barra. Las dos zonas miden lo mismo, así que manda
    /// la que tiene más pestañas.
    static func minimumWidth(tabsPerSide: Int) -> CGFloat {
        let zone = CGFloat(tabsPerSide) * plateSide + CGFloat(max(0, tabsPerSide - 1)) * spacing
        return Tokens.s8 * 2 + centerColumnWidth + zone * 2 + spacing * 2
    }

    var body: some View {
        let center = items.first { $0.screen == GameScreen.centerTab }
        let leading = Array(items.prefix { $0.screen != GameScreen.centerTab })
        let trailing = center == nil ? [] : Array(items.drop { $0.screen != GameScreen.centerTab }.dropFirst())
        // Alineados abajo: los nombres de las seis comparten renglón y la
        // diferencia de alto se va toda para arriba, que es donde sobresale
        // Contratar. Las dos zonas miden lo mismo, así que Contratar queda al
        // centro exacto tenga cuantas pestañas tenga cada lado.
        HStack(alignment: .bottom, spacing: Self.spacing) {
            zone(leading, side: .leading)
            if let center {
                GameTabButton(item: center) { selection(center.screen) }
                    // Ancho fijo: el botón se estira (`maxWidth: .infinity`) y,
                    // sin esto, se llevaría un tercio de la barra y la zona de
                    // tres pestañas no entraría en el SE.
                    .frame(width: Self.centerColumnWidth)
            }
            zone(trailing, side: .trailing)
        }
        .padding(.horizontal, Tokens.s8)
        .padding(.top, Self.topPadding)
        .padding(.bottom, Self.bottomPadding + bottomGap)
        .playColumn()
        .background(alignment: .bottom) {
            bottomPanel.padding(.top, Self.centerRise)
        }
    }

    private func zone(_ zoneItems: [GameTabItem], side: Side) -> some View {
        let slots = Self.slots(zoneItems, towardCenterFrom: side)
        return HStack(alignment: .bottom, spacing: Self.spacing) {
            ForEach(slots.indices, id: \.self) { index in
                if let item = slots[index] {
                    GameTabButton(item: item) { selection(item.screen) }
                        .frame(maxWidth: .infinity)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: Self.plateSide)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Panel crema fundido con el borde inferior.
    ///
    /// Redondea **sólo arriba**: abajo no hay esquina que mostrar (está fuera de
    /// pantalla) y curvarla dejaría dos muescas del tablero asomando en los
    /// vértices inferiores. El contorno ink sube por los costados hasta salirse
    /// de la pantalla —de eso se ocupan los paddings negativos— así que lo único
    /// que se ve del trazo es el borde de arriba, que es el que separa la barra
    /// del tablero; un panel fundido no puede tener una línea encerrándolo.
    ///
    /// El `ignoresSafeArea` es lo que lo estira por debajo del home indicator:
    /// sin él quedaba una lonja de tablero de 34 pt entre la barra y el borde
    /// físico, que es exactamente la isla que este rediseño vino a matar. En un
    /// teléfono sin notch (SE) el inset es 0 y no hay nada que estirar: el panel
    /// ya nace contra el borde y se ve igual.
    ///
    /// ⚠️ La sombra va hacia ARRIBA (`y: -2`), al revés que la de la isla: es la
    /// única cara que todavía da al tablero.
    private var bottomPanel: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous
        )
        // Al 90% la multitud apenas se adivina detrás de los tabs (pedido del
        // dueño, 2026-08-19; la superior va al 80%). El contorno ink queda
        // opaco: es el trazo, no el fondo.
        .fill(Color("PaletteCream").opacity(0.9))
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous
            )
            .strokeBorder(Color("PaletteInk"), lineWidth: 3)
            .padding(.horizontal, -3)
            .padding(.bottom, -3)
        )
        .shadow(color: .black.opacity(0.2), radius: 6, y: -2)
        .ignoresSafeArea(edges: .bottom)
    }
}

/// Un tab. El bounce es un **pulso** de keyframes disparado por el toque
/// (`trigger`), no un `repeatForever`: en reposo no hay animación viva y el
/// display link no queda corriendo toda la sesión.
private struct GameTabButton: View {
    let item: GameTabItem
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = 0

    /// Platos de 52 y 72 (Contratar) con iconos de 46 y 64, sin rótulos: el centro
    /// sobresale 20 pt. Las cinco entran en el SE con aire (`GameTabBar.minimumWidth`).
    private var side: CGFloat { item.prominent ? GameTabBar.centerPlateSide : GameTabBar.plateSide }
    private var iconSide: CGFloat { item.prominent ? 64 : 46 }

    var body: some View {
        Button {
            if !reduceMotion { bounce += 1 }
            action()
        } label: {
            ZStack {
                plate
                item.icon
                    .frame(width: iconSide, height: iconSide)
            }
            .frame(width: side, height: side)
            // `.overlay`, no un hijo: el badge no puede mover ni un punto
            // del layout (374 ≤ 375 en SE). Dentro del `keyframeAnimator`
            // a propósito: el puntito rebota con su tab.
            .overlay(alignment: .topTrailing) {
                if item.showsBadge {
                    NotificationBadge()
                        .offset(x: 5, y: -3)
                }
            }
            .overlay(alignment: .top) {
                if item.isNew {
                    NewTabBadge()
                        .offset(y: -12)
                }
            }
            .keyframeAnimator(initialValue: 1.0, trigger: bounce) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0.9, duration: 0.08)
                    SpringKeyframe(1.14, duration: 0.14, spring: .bouncy)
                    SpringKeyframe(1.0, duration: 0.22, spring: .bouncy)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.identifier)
        .accessibilityLabel(Text(LocalizedStringKey(item.labelKey)))
        // El badge avisa por acá (trampa 9a: jamás un elemento de AX adentro
        // del label de un botón). Vacío cuando no hay nada que cobrar.
        .accessibilityValue(accessibilityValue)
    }

    /// El puntito de cobrar y el "¡Nuevo!", dichos por el botón (trampa 9a:
    /// jamás un elemento de AX adentro del label).
    private var accessibilityValue: Text {
        switch (item.showsBadge, item.isNew) {
        case (true, true): Text("tab.new.ax") + Text(verbatim: ", ") + Text("badge.claimable.ax")
        case (false, true): Text("tab.new.ax")
        case (true, false): Text("badge.claimable.ax")
        case (false, false): Text(verbatim: "")
        }
    }

    /// El plato del tab. `ui_tab_active` para los destacados y `ui_tab_inactive`
    /// para el resto: no hay tab "seleccionado" (todos abren una hoja), así que
    /// el arte activo marca a los dos extremos.
    ///
    /// Acá el arte va **entero y estirado**, no en 9-slice: el destino es
    /// cuadrado igual que el PNG, así que no hay aspecto que corregir y un
    /// `resizable` liso respeta la forma de la pestaña (que tiene el hombro
    /// recortado arriba). Se dibuja a 1,45× del plato porque el dibujo ocupa
    /// ~68% de su lienzo: así lo que se VE mide `side`.
    @ViewBuilder private var plate: some View {
        if let art = UIArt.image(item.prominent ? "ui_tab_active" : "ui_tab_inactive") {
            art
                .resizable()
                .scaledToFit()
                .frame(width: side * 1.45, height: side * 1.45)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(item.prominent ? Color("PaletteYellow") : Color("PaletteCream"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color("PaletteInk"), lineWidth: item.prominent ? 3 : 2)
                )
        }
    }
}

/// El cartelito de una pestaña recién abierta: cápsula caramelo naranja con
/// "¡Nuevo!". Decoración: lo dice el valor de AX del botón.
private struct NewTabBadge: View {
    var body: some View {
        Text("tab.new.badge")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(PillBackground(fill: Color("PaletteOrange")))
            .fixedSize()
            .accessibilityHidden(true)
    }
}
