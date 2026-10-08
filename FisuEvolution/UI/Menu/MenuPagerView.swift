import SwiftUI

/// Dónde está una página del paginador y cómo moverse (PLAN-v2 E3). `nil` fuera
/// del paginador y en las vistas empujadas del Menú: ahí no hay flechas ni puntos.
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

/// El menú deslizable (PLAN-v2 E3): UNA hoja con las pestañas desbloqueadas como
/// páginas, en el orden de la barra. Cada página conserva su `NavigationStack`, su
/// marco y su X.
///
/// Se montan la página actual y sus vecinas; las ocultas no tienen AX ni toques,
/// así que `sheet.close` es uno solo en el árbol. El arranque en la página pedida
/// va por `ScrollViewReader`: `scrollPosition(id:)` no aplica el valor inicial.
struct MenuPagerView: View {
    let pages: [GameScreen]
    let adsProvider: AdsCoordinator
    let onPageChange: (GameScreen) -> Void
    @State private var current: GameScreen?
    @State private var locked = false
    private let start: GameScreen

    init(pages: [GameScreen], start: GameScreen, adsProvider: AdsCoordinator,
         onPageChange: @escaping (GameScreen) -> Void) {
        self.pages = pages
        self.adsProvider = adsProvider
        self.onPageChange = onPageChange
        let first = pages.isEmpty ? start : pages[Self.startIndex(of: start, in: pages)]
        self.start = first
        _current = State(initialValue: first)
    }

    static func startIndex(of screen: GameScreen, in pages: [GameScreen]) -> Int {
        pages.firstIndex(of: screen) ?? 0
    }

    /// La página actual y las dos vecinas: lo que hace falta para que el deslizado
    /// no muestre un hueco.
    static func isMounted(index: Int, current: Int) -> Bool {
        abs(index - current) <= 1
    }

    private var currentIndex: Int {
        current.flatMap { pages.firstIndex(of: $0) } ?? 0
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
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
            .onAppear { proxy.scrollTo(start, anchor: .leading) }
        }
        .onChange(of: current) { _, page in
            if let page { onPageChange(page) }
        }
    }

    @ViewBuilder private func slot(_ page: GameScreen, index: Int) -> some View {
        let isCurrent = index == currentIndex
        Group {
            if Self.isMounted(index: index, current: currentIndex) {
                MenuPage(screen: page, adsProvider: adsProvider)
                    .environment(\.menuPager, MenuPagerContext(
                        index: index,
                        count: pages.count,
                        go: { go(to: $0) },
                        lock: { locked = $0 }
                    ))
            } else {
                Color.clear
            }
        }
        .accessibilityHidden(!isCurrent)
        .allowsHitTesting(isCurrent)
    }

    private func go(to index: Int) {
        guard pages.indices.contains(index) else { return }
        withAnimation(.snappy) { current = pages[index] }
    }
}

/// Una pestaña como página: la misma vista de siempre.
struct MenuPage: View {
    let screen: GameScreen
    let adsProvider: AdsCoordinator

    var body: some View {
        switch screen {
        case .jobs: FisuJobsView()
        case .upgrades: UpgradesView()
        case .skins: CustomizationView()
        case .gifts: GiftsView(adsProvider: adsProvider)
        case .store: StoreView()
        case .menu: MenuView()
        }
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
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("menu.pager.dots")
        .accessibilityValue(Text(verbatim: "\(index + 1)/\(count)"))
    }
}
