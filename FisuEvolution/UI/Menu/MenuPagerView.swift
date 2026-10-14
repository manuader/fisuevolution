import SwiftUI

/// Dónde está una página del paginador y cómo moverse (PLAN-v2 E3). `nil` fuera
/// del paginador y en las vistas empujadas del Menú: ahí la vista se enmarca sola.
struct MenuPagerContext {
    let index: Int
    let count: Int
    let go: @MainActor (Int) -> Void
    /// El Menú avisa que tiene un destino empujado (Ajustes, Legales): con eso el
    /// paginador se bloquea y el gesto de "volver" es del `NavigationStack`.
    let lock: @MainActor (Bool) -> Void
}

private struct MenuPagerContextKey: EnvironmentKey {
    static var defaultValue: MenuPagerContext? { nil }
}

extension EnvironmentValues {
    var menuPager: MenuPagerContext? {
        get { self[MenuPagerContextKey.self] }
        set { self[MenuPagerContextKey.self] = newValue }
    }
}

/// Lo que cambia de una pestaña a otra en el marco fijo del paginador. Cada página
/// lo publica por preferencia (`panelSheet`); el paginador dibuja el de la que
/// quedó asentada. El moño no entra en la igualdad: viaja con el índice.
struct MenuPageChrome: Equatable {
    var awning: Bool
    var material: WoodPanelBackground.Material
    var headerHeight: CGFloat
    /// El alto del cartel del título (primera fila de la cabecera): a esa altura
    /// van las flechas, no al centro de toda la cabecera.
    var titleHeight: CGFloat
    var ornament: AnyView

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.awning == rhs.awning && lhs.material == rhs.material
            && lhs.headerHeight == rhs.headerHeight && lhs.titleHeight == rhs.titleHeight
    }
}

/// El alto del cartel del título, publicado por el propio cartel (`pagerTitleSlot`).
struct MenuTitleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Lo que hace el cartel del título (o el logo) de una página del menú: deja a
/// los lados el hueco de las flechas del paginador y publica su alto. Sólo el
/// título cede ancho; lo que va debajo (las pestañas) usa todo el de la columna.
private struct PagerTitleSlot: ViewModifier {
    @Environment(\.menuPager) private var pager
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, (pager?.count ?? 0) > 1 ? MenuPagerView.chevronSlot : 0)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .preference(key: MenuTitleHeightKey.self, value: height)
    }
}

extension View {
    /// Aplicar al cartel del título de una página del menú deslizable.
    func pagerTitleSlot() -> some View {
        modifier(PagerTitleSlot())
    }
}

struct MenuPageChromeKey: PreferenceKey {
    static var defaultValue: [Int: MenuPageChrome] { [:] }

    static func reduce(value: inout [Int: MenuPageChrome], nextValue: () -> [Int: MenuPageChrome]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// El menú deslizable (PLAN-v2 E3, E14 C13): UNA hoja con las pestañas
/// desbloqueadas como páginas, en el orden de la barra, y UN solo marco quieto
/// (madera, toldo, X, flechas y puntos). Cada página conserva su `NavigationStack`
/// pero aporta sólo título y cuerpo, que deslizan por adentro del pergamino,
/// recortados por el borde interior del marco. Afuera no hay nada: el sheet es
/// transparente.
///
/// Se montan la página actual y sus dos vecinas: las vecinas se arman en reposo
/// (poco después de abrir, con su arte ya calentado en background) para que el
/// deslizado no pague el armado en el primer cuadro del gesto. La X de cada
/// página ya no vive en su barra de navegación (el panel la oculta; la X es del
/// paginador), así que las vecinas, tapadas de accesibilidad, no duplican
/// `sheet.close`. El arranque en la página pedida va por `ScrollViewReader`:
/// `scrollPosition(id:)` no aplica el valor inicial.
struct MenuPagerView: View {
    let pages: [GameScreen]
    let adsProvider: AdsCoordinator
    let onStore: () -> Void
    let onPageChange: (GameScreen) -> Void
    @State private var current: GameScreen?
    /// La última página que el scroll fijó. `current` pasa por `nil` mientras el
    /// scroll se resuelve; montar según él desmontaría la página que se está mirando
    /// (y perdería su estado).
    @State private var shown: GameScreen
    @State private var locked = false
    @State private var chromes: [Int: MenuPageChrome] = [:]
    @Environment(\.dismiss) private var dismiss
    @Environment(GameState.self) private var gameState
    @State private var phase: ScrollPhase = .idle
    /// La página más cercana al offset: la que queda cuando el scroll se asienta.
    @State private var nearest: Int?
    /// El scroll se movió de verdad desde la última página asentada: el arranque
    /// programático (`scrollTo(start)`) parte del offset 0 y no es una página vista.
    @State private var scrolled = false
    /// Las vecinas ya se armaron en reposo (después del arranque): el deslizado
    /// no paga el armado de una página en el primer cuadro del gesto.
    @State private var neighborsReady = false
    private let start: GameScreen

    init(pages: [GameScreen], start: GameScreen, adsProvider: AdsCoordinator,
         onStore: @escaping () -> Void = {}, onPageChange: @escaping (GameScreen) -> Void) {
        self.pages = pages
        self.adsProvider = adsProvider
        self.onStore = onStore
        self.onPageChange = onPageChange
        let first = pages.isEmpty ? start : pages[Self.startIndex(of: start, in: pages)]
        self.start = first
        _current = State(initialValue: first)
        _shown = State(initialValue: first)
    }

    /// El hueco que cada página deja a los lados del título para las flechas
    /// (34 del botón + 8 de aire).
    static let chevronSlot: CGFloat = 42

    /// El borde interior del marco: la banda de madera termina acá y empieza el
    /// pergamino por el que desliza el contenido.
    private static let innerInset: CGFloat = 22

    static func startIndex(of screen: GameScreen, in pages: [GameScreen]) -> Int {
        pages.firstIndex(of: screen) ?? 0
    }

    /// La página actual y las dos vecinas: lo que hace falta para que el deslizado
    /// no muestre un hueco.
    static func isMounted(index: Int, current: Int) -> Bool {
        abs(index - current) <= 1
    }

    private var currentIndex: Int {
        pages.firstIndex(of: shown) ?? 0
    }

    var body: some View {
        let _ = PagerProbe.hit("pager.body shown=\(shown) phase=\(phase)")
        ZStack(alignment: .topTrailing) {
            ZStack {
                if !locked { frame }
                pager
                    .mask { pergamino }
                if !locked, pages.count > 1 { chevrons }
            }
            .ignoresSafeArea(edges: .top)
            .frame(maxWidth: SheetColumn.maxWidth)
            if !locked {
                ArtCloseButton { dismiss() }
                    .padding(.trailing, Tokens.s16)
            }
        }
        .onPreferenceChange(MenuPageChromeKey.self) { merge(chromes: $0) }
        .task { await prepareNeighbors() }
        .fisuSheet()
    }

    /// El marco quieto: madera, toldo y moño de la pestaña asentada (con fundido
    /// cruzado al cambiar) y los puntos sobre la banda de abajo.
    private var frame: some View {
        let chrome = chromes[currentIndex]
        return ZStack(alignment: .top) {
            WoodPanelBackground(material: chrome?.material ?? .wood, awning: chrome?.awning ?? false)
            if let ornament = chrome?.ornament {
                ornament
                    .id(currentIndex)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if pages.count > 1 {
                PagerDots(index: currentIndex, count: pages.count)
                    .padding(.bottom, PagerDots.bandInset)
            }
        }
        // La sombra del panel flotando sobre el juego: sin el material del
        // sheet del sistema, la profundidad la pone el propio panel.
        .shadow(color: .black.opacity(0.30), radius: 16, y: 6)
    }

    /// Por dónde se ve el deslizado: el interior del marco. Con un destino
    /// empujado, nada: esa vista trae su marco entero.
    @ViewBuilder private var pergamino: some View {
        if locked {
            Rectangle()
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .padding(Self.innerInset)
        }
    }

    /// Las flechas ‹ › en el renglón del título, fijas: el título de cada página
    /// pasa por entre las dos.
    private var chevrons: some View {
        let chrome = chromes[currentIndex]
        return HStack(spacing: 0) {
            PagerChevronButton(direction: .previous, identifier: "menu.pager.previous") {
                go(to: currentIndex - 1)
            }
            .disabled(currentIndex == 0)
            Spacer(minLength: 0)
            PagerChevronButton(direction: .next, identifier: "menu.pager.next") {
                go(to: currentIndex + 1)
            }
            .disabled(currentIndex >= pages.count - 1)
        }
        .padding(.horizontal, WoodPanelBackground.columnInset)
        .frame(height: max(chrome?.titleHeight ?? 0, 34))
        .padding(.top, WoodPanelBackground.headerTopInset(awning: chrome?.awning ?? false))
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var pager: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                // HStack y no Lazy: son a lo sumo siete páginas y las lejanas son un
                // `Color.clear`; con Lazy la vecina se armaba recién al empezar el gesto.
                HStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.element) { index, page in
                        slot(page, index: index)
                            .containerRelativeFrame(.horizontal)
                            .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)
            .scrollDisabled(locked)
            .onScrollPhaseChange { _, newPhase in
                phase = newPhase
                settleIfQuiet()
            }
            .onScrollGeometryChange(for: Int.self) { geometry in
                Self.pageIndex(offset: geometry.contentOffset.x, width: geometry.containerSize.width)
            } action: { _, index in
                nearest = index
                if phase != .idle { scrolled = true }
                settleIfQuiet()
            }
            .onAppear { proxy.scrollTo(start, anchor: .leading) }
        }
        .onChange(of: current) { _, page in
            guard let page, phase == .idle else { return }
            settle(on: page)
        }
    }

    /// La página que el scroll tiene a la vista. `scrollPosition(id:)` a veces no
    /// reporta el id al asentarse (el scroll queda en la página 0 y `current` no
    /// cambia): el offset del scroll es la fuente que no falla.
    static func pageIndex(offset: CGFloat, width: CGFloat) -> Int {
        guard width > 0 else { return 0 }
        return Int((offset / width).rounded())
    }

    /// La página que cuenta como vista: sólo cuando el scroll queda quieto, nunca
    /// mientras el dedo arrastra o el paginado todavía desliza (un arrastre que
    /// vuelve atrás no vio la página de al lado).
    static func settledPage(phase: ScrollPhase, scrolled: Bool, nearest: Int?, pages: [GameScreen],
                            shown: GameScreen) -> GameScreen? {
        guard phase == .idle, scrolled, let nearest, pages.indices.contains(nearest), pages[nearest] != shown else { return nil }
        return pages[nearest]
    }

    private func settleIfQuiet() {
        guard let page = Self.settledPage(phase: phase, scrolled: scrolled, nearest: nearest, pages: pages, shown: shown)
        else {
            if phase == .idle { scrolled = false }
            return
        }
        settle(on: page)
    }

    private func settle(on page: GameScreen) {
        scrolled = false
        guard page != shown else { return }
        withAnimation(.easeInOut(duration: 0.25)) { shown = page }
        onPageChange(page)
    }

    @ViewBuilder private func slot(_ page: GameScreen, index: Int) -> some View {
        let isCurrent = index == currentIndex
        let nearby = Self.isMounted(index: index, current: currentIndex)
        PagerSlot(
            page: page,
            index: index,
            count: pages.count,
            mounted: isCurrent || ((neighborsReady || phase != .idle) && nearby),
            isCurrent: isCurrent,
            adsProvider: adsProvider,
            onStore: onStore,
            go: { go(to: $0) },
            lock: { locked = $0 }
        )
        .equatable()
    }

    /// Las preferencias que no cambian nada no deben invalidar al paginador: cada
    /// invalidación recorría las páginas montadas.
    private func merge(chromes incoming: [Int: MenuPageChrome]) {
        let merged = chromes.merging(incoming) { _, new in new }
        guard merged != chromes else { return }
        chromes = merged
    }

    /// Calienta el arte de las páginas vecinas fuera del hilo principal y, con el
    /// arranque ya asentado, las deja armadas en reposo.
    private func prepareNeighbors() async {
        warmArt()
        try? await Task.sleep(for: .milliseconds(400))
        neighborsReady = true
    }

    private func warmArt() {
        var atlases: Set<String> = ["ui"]
        if pages.contains(.skins) || pages.contains(.store),
           let characters = gameState.content?.manifest.characters {
            atlases.formUnion(characters.values.map(\.atlas))
        }
        UIArt.warmAtlases(atlases)
    }

    private func go(to index: Int) {
        guard pages.indices.contains(index) else { return }
        withAnimation(.snappy) { current = pages[index] }
    }
}

/// Una ranura del paginador. Es `Equatable` a propósito: el paginador se
/// invalida con cada cambio de fase del scroll y de preferencia, y sin esto cada
/// invalidación reconstruía el cuerpo de todas las páginas montadas (los
/// cierres que recibe nunca son iguales entre sí). Lo que cambia de verdad
/// —la página, su índice, si está armada o si es la actual— sí entra en la
/// igualdad; el entorno (el estado del juego) invalida la página por su cuenta.
private struct PagerSlot: View, Equatable {
    let page: GameScreen
    let index: Int
    let count: Int
    let mounted: Bool
    let isCurrent: Bool
    let adsProvider: AdsCoordinator
    let onStore: () -> Void
    let go: @MainActor (Int) -> Void
    let lock: @MainActor (Bool) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.page == rhs.page && lhs.index == rhs.index && lhs.count == rhs.count
            && lhs.mounted == rhs.mounted && lhs.isCurrent == rhs.isCurrent
    }

    var body: some View {
        let _ = PagerProbe.hit("slot.body \(page) mounted=\(mounted) current=\(isCurrent)")
        Group {
            if mounted {
                MenuPage(screen: page, adsProvider: adsProvider, onStore: onStore)
                    .environment(\.menuPager, MenuPagerContext(index: index, count: count, go: go, lock: lock))
            } else {
                Color.clear
            }
        }
        .accessibilityHidden(!isCurrent)
        .allowsHitTesting(isCurrent)
    }
}

/// Una pestaña como página: la misma vista de siempre.
struct MenuPage: View {
    let screen: GameScreen
    let adsProvider: AdsCoordinator
    let onStore: () -> Void

    var body: some View {
        page.tutorialSheetCoach(.page(screen))
    }

    @ViewBuilder private var page: some View {
        switch screen {
        case .jobs: FisuJobsView()
        case .upgrades: UpgradesView(onStore: onStore)
        case .skins: CustomizationView()
        case .gifts: GiftsView(adsProvider: adsProvider)
        case .store: StoreView()
        case .menu: MenuView()
        case .ranking: RankingPage(onStore: onStore)
        }
    }
}

/// La pestaña Ranking: el store y el estado de la partida rankeada salen del entorno.
private struct RankingPage: View {
    @Environment(GameState.self) private var gameState
    @Environment(RankingStore.self) private var store
    let onStore: () -> Void

    var body: some View {
        RankingView(store: store, state: gameState.rankingState, onStore: onStore)
    }
}

/// Los puntos del paginador, sobre la banda de madera: la página actual es una
/// cápsula caramelo. Es un marcador para los tests ("2/6"), no un control.
struct PagerDots: View {
    /// Dónde van, contados desde el borde de abajo del panel: centrados en la banda.
    static let bandInset: CGFloat = 7

    let index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { dot in
                if dot == index {
                    PillBackground(fill: Color("PaletteOrange"))
                        .frame(width: 18, height: 8)
                } else {
                    Capsule()
                        .fill(Color("PaletteCream").opacity(0.75))
                        .overlay(Capsule().strokeBorder(Color("PaletteInk").opacity(0.45), lineWidth: 1))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .tutorialAnchor(.menuPager)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("menu.pager.dots")
        .accessibilityValue(Text(verbatim: "\(index + 1)/\(count)"))
    }
}
