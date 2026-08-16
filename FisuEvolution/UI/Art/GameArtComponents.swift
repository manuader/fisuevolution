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

// MARK: - GameCard

/// La tarjeta de fila universal: crema, radio 14, contorno ink y sombra suave.
/// Unifica `UpgradesView.cardBackground` y `FloorMapView.rowBackground`.
///
/// - `highlighted(color)` sube el borde a 3 pt del color de acento y le agrega
///   un halo del mismo color (piso actual, mejora recomendada, pack destacado).
/// - `locked` desatura el conjunto —contenido incluido— en vez de usar
///   `.disabled`, que baja la opacidad del texto hasta volverlo ilegible.
struct GameCard<Content: View>: View {
    enum Style {
        case normal
        case highlighted(Color)
        case locked
    }

    var style: Style = .normal
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
            .saturation(isLocked ? 0.2 : 1)
            .opacity(isLocked ? 0.78 : 1)
    }

    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let border: Color = accent ?? Color("PaletteInk").opacity(isLocked ? 0.3 : 1)
        return shape
            .fill(Color("PaletteCream"))
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
        label
            .font(Tokens.title)
            .foregroundStyle(Color("PaletteCream"))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            .padding(.horizontal, Tokens.s24)
            .padding(.vertical, Tokens.s8)
            .background {
                RibbonShape()
                    .fill(Color("PaletteOrange"))
                    .overlay(RibbonShape().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            }
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
            .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 2.5))
        }
        .frame(height: 20)
        .accessibilityElement(children: .ignore)
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
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake = 0

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
                Capsule()
                    .fill(affordable ? Color("PaletteGreen") : Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            )
            .saturation(affordable ? 1 : 0.7)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
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
    let titleKey: LocalizedStringKey
    let systemImage: String
    var tint: Color = Color("PaletteGreen")
    let identifier: String
    /// Etiqueta hablada. El título solo ("Ponérsela") no dice de QUÉ, y en una
    /// grilla de tres tarjetas hay tres botones que dicen lo mismo.
    var accessibilityLabel: Text?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                Text(titleKey)
                    .font(Tokens.body)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
            .padding(.horizontal, Tokens.s12)
            .padding(.vertical, Tokens.s8)
            .frame(minWidth: 92)
            .background(
                Capsule()
                    .fill(tint)
                    .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel ?? Text(titleKey))
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
/// identifier ni traits: **no es un control**, y quien lo usa lo tapa de
/// VoiceOver porque su texto ya viaja en el valor de la fila.
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
                    .font(.system(size: 10, weight: .black))
            }
            Text(verbatim: text)
                .font(Tokens.caption)
                .multilineTextAlignment(textAlignment)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
        }
        .foregroundStyle(Color("PaletteInk").opacity(muted ? 0.75 : 1))
        .padding(.horizontal, Tokens.s8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(muted ? Color("PaletteInk").opacity(0.07) : Color("PaletteOrange").opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color("PaletteInk").opacity(muted ? 0.35 : 0.8), lineWidth: 2)
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
                    .overlay(Capsule().strokeBorder(Color("PaletteInk").opacity(dimmed ? 0.4 : 1), lineWidth: 2))
            }
            .opacity(dimmed ? 0.8 : 1)
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
    let tint: Color
    let labelKey: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            glyph
                .frame(width: size * 0.52, height: size * 0.52)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color("PaletteCream"))
                        .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(LocalizedStringKey(labelKey)))
    }

    @ViewBuilder private var glyph: some View {
        if let artKey, let image = UIArt.image(artKey) {
            image.resizable().scaledToFit()
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
}

/// Un tab: la pantalla que abre, su icono ya type-borrado, el label de AX y si
/// va destacado (los extremos, como la vaca y el cuaderno de Cow Evolution).
struct GameTabItem: Identifiable {
    let screen: GameScreen
    let icon: AnyView
    let labelKey: String
    let identifier: String
    let prominent: Bool

    var id: String { screen.rawValue }

    init(screen: GameScreen,
         icon: AnyView,
         labelKey: String,
         identifier: String,
         prominent: Bool = false) {
        self.screen = screen
        self.icon = icon
        self.labelKey = labelKey
        self.identifier = identifier
        self.prominent = prominent
    }
}

/// Barra inferior de pantallas. No guarda selección —cada tab abre su hoja— así
/// que el estado "activo" es el destaque de los extremos más el pulso del toque.
///
/// ⚠️ El `HStack` NO lleva identifier: cada botón lleva el suyo (trampa 9a-bis).
struct GameTabBar: View {
    let items: [GameTabItem]
    let selection: (GameScreen) -> Void

    var body: some View {
        HStack(spacing: Tokens.s4) {
            ForEach(items) { item in
                GameTabButton(item: item) { selection(item.screen) }
            }
        }
        .padding(.horizontal, Tokens.s8)
        .padding(.vertical, Tokens.s8)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color("PaletteCream"))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color("PaletteInk"), lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        )
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

    private var side: CGFloat { item.prominent ? 56 : 48 }
    private var iconSide: CGFloat { item.prominent ? 34 : 28 }

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
