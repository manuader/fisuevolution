import SwiftUI

/// El contenedor único de popup de E14 (C15), estilo Cow Evolution: una
/// tarjeta **centrada** con el marco de la casa (`PanelCard`), la cinta del
/// título y la X arriba a la derecha **adentro** del marco. Afuera,
/// transparente (el velo lo pone quien presenta, `gamePopup`); adentro,
/// pergamino liso.
///
/// El ritmo (C15.4): arriba el título, al centro lo que el llamador ponga
/// (ilustración grande, una línea de texto) y abajo los botones, lado a lado si
/// son dos o menos y apilados si son más. Los botones quedan **fijos** debajo:
/// si el contenido no entra en el alto máximo —la zona segura menos un margen—
/// scrollea el contenido, nunca la tarjeta ni los botones.
///
/// ⚠️ El contenido se mide con `ViewThatFits`: al cruzar el umbral (otro tamaño
/// de texto, contenido que crece) se recrea y pierde su `@State` interno. El
/// estado del popup vive en quien lo presenta, no adentro del contenido.
struct PopupContainer<Content: View, Actions: View>: View {
    private let title: Text?
    private let ribbonTint: Color
    private let material: WoodPanelBackground.Material
    private let onClose: (() -> Void)?
    private let closeIdentifier: String
    private let content: Content
    private let actions: Actions

    init(
        _ titleKey: LocalizedStringKey?, ribbonTint: Color = Color("PaletteOrange"),
        material: WoodPanelBackground.Material = .wood, onClose: (() -> Void)? = nil,
        closeIdentifier: String = "sheet.close",
        @ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions
    ) {
        self.title = titleKey.map { Text($0) }
        self.ribbonTint = ribbonTint
        self.material = material
        self.onClose = onClose
        self.closeIdentifier = closeIdentifier
        self.content = content()
        self.actions = actions()
    }

    /// Un título ya resuelto (el nombre de un visitante).
    init(
        verbatim title: String, ribbonTint: Color = Color("PaletteOrange"),
        material: WoodPanelBackground.Material = .wood, onClose: (() -> Void)? = nil,
        closeIdentifier: String = "sheet.close",
        @ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions
    ) {
        self.title = Text(verbatim: title)
        self.ribbonTint = ribbonTint
        self.material = material
        self.onClose = onClose
        self.closeIdentifier = closeIdentifier
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        GeometryReader { geo in
            card
                .frame(width: PopupMetrics.cardWidth(available: geo.size.width))
                .frame(maxHeight: PopupMetrics.maxCardHeight(available: geo.size.height))
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        // El gesto Z de VoiceOver cierra como la X (el velo no es un elemento).
        .accessibilityAction(.escape) { onClose?() }
    }

    private var card: some View {
        PanelCard(material: material) {
            VStack(spacing: Tokens.s12) {
                header
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                ViewThatFits(in: .vertical) {
                    scrollableContent(scrolls: false)
                    ScrollView { scrollableContent(scrolls: true) }
                        .scrollBounceBehavior(.basedOnSize)
                        .scrollIndicators(.automatic)
                }
                PopupActions { actions }
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
        }
    }

    private func scrollableContent(scrolls: Bool) -> some View {
        VStack(spacing: Tokens.s12) { content }
            .frame(maxWidth: .infinity)
            .padding(.vertical, scrolls ? Tokens.s4 : 0)
    }

    /// La cinta centrada y la X a la derecha, en el MISMO renglón y adentro del
    /// marco: un hueco espejo del ancho de la X a la izquierda mantiene la
    /// cinta en el centro óptico.
    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: onClose == nil ? 0 : PopupMetrics.closeSide, height: 1)
            Group {
                if let title {
                    PopupRibbon(title: title, tint: ribbonTint)
                }
            }
            .frame(maxWidth: .infinity)
            if let onClose {
                PopupCloseButton(identifier: closeIdentifier, action: onClose)
            }
        }
        .padding(.top, -Tokens.s8)
        .padding(.horizontal, -Tokens.s8)
    }
}

extension PopupContainer where Actions == EmptyView {
    /// Un popup sin botones abajo (el contenido trae los suyos o se cierra con la X).
    init(
        _ titleKey: LocalizedStringKey?, ribbonTint: Color = Color("PaletteOrange"),
        material: WoodPanelBackground.Material = .wood, onClose: (() -> Void)? = nil,
        closeIdentifier: String = "sheet.close", @ViewBuilder content: () -> Content
    ) {
        self.init(titleKey, ribbonTint: ribbonTint, material: material, onClose: onClose,
                  closeIdentifier: closeIdentifier, content: content, actions: { EmptyView() })
    }
}

// MARK: - Medidas

/// Las medidas del contenedor, puras para poder testearlas.
enum PopupMetrics {
    /// El aire mínimo entre la tarjeta y el borde de la zona segura.
    static let screenMargin: CGFloat = 16
    /// Más ancho se lee como hoja, no como popup (iPad).
    static let maxCardWidth: CGFloat = 460
    /// La X: 44 pt de toque (D14).
    static let closeSide: CGFloat = 44
    /// Hasta dos botones van lado a lado; con más, apilados (C15.4).
    static let maxSideBySideActions = 2

    static func cardWidth(available: CGFloat) -> CGFloat {
        max(0, min(available - 2 * screenMargin, maxCardWidth))
    }

    /// El alto máximo: la zona segura menos el margen arriba y abajo.
    static func maxCardHeight(available: CGFloat) -> CGFloat {
        max(0, available - 2 * screenMargin)
    }

    static func stacksActions(count: Int) -> Bool {
        count > maxSideBySideActions
    }
}

// MARK: - Piezas

/// Los botones del pie: lado a lado repartiendo el ancho, o en columna.
private struct PopupActions<Actions: View>: View {
    @ViewBuilder let actions: Actions

    var body: some View {
        Group(subviews: actions) { subviews in
            if subviews.isEmpty {
                EmptyView()
            } else if PopupMetrics.stacksActions(count: subviews.count) {
                VStack(spacing: Tokens.s8) {
                    ForEach(subviews) { $0.frame(maxWidth: .infinity) }
                }
            } else {
                HStack(alignment: .top, spacing: Tokens.s8) {
                    ForEach(subviews) { $0.frame(maxWidth: .infinity) }
                }
            }
        }
        .environment(\.gameButtonFillsWidth, true)
    }
}

/// La cinta del título: la de las secciones (`SectionHeader`) en el tono que
/// pida el popup (naranja de la casa, verde de premio, celeste del blue).
private struct PopupRibbon: View {
    let title: Text

    let tint: Color

    var body: some View {
        title
            .font(Tokens.title)
            .foregroundStyle(Color("PaletteCream"))
            .shadow(color: .black.opacity(0.35), radius: 0, y: 1.5)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, Tokens.s16)
            .padding(.vertical, Tokens.s8)
            .background { PopupRibbonBackground(tint: tint) }
            .accessibilityAddTraits(.isHeader)
    }
}

private struct PopupRibbonBackground: View {
    let tint: Color

    var body: some View {
        let band = RoundedRectangle(cornerRadius: 8, style: .continuous)
        band
            .fill(LinearGradient(colors: [tint.lifted(0.14), tint], startPoint: .top, endPoint: .bottom))
            .overlay(band.strokeBorder(tint.deepened(0.3), lineWidth: 2.5))
            .background(band.fill(tint.deepened(0.3)).offset(y: 3))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
    }
}

/// La X del popup: `ui_btn_close` con su respaldo dibujado (C19: sin SF
/// Symbol), 44 pt de toque y adentro del marco.
struct PopupCloseButton: View {
    var identifier: String = "sheet.close"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GameIcon(artKey: "ui_btn_close", size: 36) { CloseVector() }
                .frame(width: PopupMetrics.closeSide, height: PopupMetrics.closeSide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text("store.close"))
    }
}

/// La X roja dibujada, hermana de `ui_btn_close`.
private struct CloseVector: View {
    var body: some View {
        IconCanvas {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .inked(GameTint.alert)
                    .frame(width: 86, height: 86)
                IconPath { path in
                    path.move(to: CGPoint(x: 34, y: 34))
                    path.addLine(to: CGPoint(x: 66, y: 66))
                    path.move(to: CGPoint(x: 66, y: 34))
                    path.addLine(to: CGPoint(x: 34, y: 66))
                }
                .stroke(Color("PaletteCream"), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            }
        }
    }
}

// MARK: - La presentación

extension View {
    /// Presenta un popup del juego **centrado sobre el juego atenuado** (C15),
    /// no como hoja desde abajo. Va en la vista que cubre la pantalla entera
    /// (la raíz del juego); el popup llena la zona segura y centra su tarjeta.
    /// `dismissOnVeilTap` cierra al tocar afuera (el default es no: las
    /// decisiones se toman con los botones). `onDismiss` corre cuando el popup
    /// se va, sea cual sea la causa (como el de `.sheet`).
    func gamePopup<Popup: View>(
        isPresented: Binding<Bool>,
        dismissOnVeilTap: Bool = false,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder popup: @escaping () -> Popup
    ) -> some View {
        modifier(GamePopupPresenter(isPresented: isPresented, dismissOnVeilTap: dismissOnVeilTap,
                                    onDismiss: onDismiss, popup: popup))
    }

    func gamePopup<Item: Identifiable, Popup: View>(
        item: Binding<Item?>,
        dismissOnVeilTap: Bool = false,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder popup: @escaping (Item) -> Popup
    ) -> some View {
        let shown = Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )
        return modifier(GamePopupPresenter(isPresented: shown, dismissOnVeilTap: dismissOnVeilTap,
                                           onDismiss: onDismiss) {
            if let value = item.wrappedValue { popup(value) }
        })
    }
}

private struct GamePopupPresenter<Popup: View>: ViewModifier {
    @Binding var isPresented: Bool
    let dismissOnVeilTap: Bool
    let onDismiss: (() -> Void)?
    @ViewBuilder let popup: () -> Popup

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                if isPresented {
                    Color.black.opacity(SheetPresentation.veilOpacity)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { if dismissOnVeilTap { isPresented = false } }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                    popup()
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.88).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .snappy(duration: 0.24), value: isPresented)
        }
        .onChange(of: isPresented) { was, now in
            if was, !now { onDismiss?() }
        }
    }
}
