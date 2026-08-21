import SwiftUI

/// **Oficina central** — el menú del juego (spec §10): una grilla 2×2 de
/// tarjetas grandes que abre las cuatro pantallas "de gabinete" —Organigrama,
/// Estadísticas, Logros y Ajustes—, igual que el MENU de Cow Evolution.
///
/// Es la **única** de las seis hojas de la barra inferior que navega: las otras
/// cinco son una pantalla y se cierran. Por eso acá el `NavigationStack` no es
/// decorativo (en FisuJobs y compañía existe sólo para tener barra de
/// herramientas) sino el mecanismo de la pantalla, y las cuatro sub-vistas se
/// **empujan** en vez de presentarse como hojas nuevas: una hoja sobre otra hoja
/// apila dos marcos de madera y el jugador pierde de vista dónde está.
///
/// ⚠️ **La X de cerrar de las sub-vistas no puede salir de `@Environment(\.dismiss)`.**
/// Dentro de una vista empujada, `dismiss` **desapila** en lugar de cerrar la
/// hoja, así que `sheet.close` se comportaría como "atrás" — y hay un chevron al
/// lado que ya hace eso. El cierre viaja como closure desde acá, que es el único
/// lugar donde `dismiss` significa "cerrar el menú".
struct MenuView: View {
    @Environment(\.dismiss) private var dismiss

    /// Margen lateral del contenido de las CUATRO pantallas del menú. Desde el
    /// rediseño v3 el marco es `WoodPanelBackground` —geometría propia, no un
    /// PNG— así que el número ya no se mide contra un arte: lo publica el
    /// componente (28) y acá se le suman 6 de aire para que las tarjetas no
    /// apoyen contra el bisel. Da los mismos 34 que se medían contra
    /// `panel_config`, que es lo que mantiene idéntico el layout de las cinco
    /// pantallas que lo usan.
    static let panelInset: CGFloat = WoodPanelBackground.contentInset + 6

    /// A dónde va cada tarjeta. Es un enum y no cuatro `NavigationLink` con
    /// vistas inline para que el destino sea `Hashable` y la pila se pueda
    /// restaurar; además deja el `switch` en UN lugar.
    private enum Destination: Hashable {
        case orgChart
        case stats
        case achievements
        case settings
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Cuatro tarjetas contadas: `VStack` de dos filas y no
                // `LazyVGrid`. La grilla perezosa no aporta nada con cuatro
                // hijos y sí se lleva puestos los identifiers cuando el árbol de
                // accesibilidad se arma antes de que la celda exista (medido en
                // la T11).
                VStack(spacing: Tokens.s12) {
                    HStack(spacing: Tokens.s12) {
                        card(.orgChart, "menu.card.orgchart", identifier: "menu.card.orgchart") {
                            AnyView(VectorOrgchartIcon())
                        }
                        card(.stats, "menu.card.stats", identifier: "menu.card.stats") {
                            AnyView(VectorStatsIcon())
                        }
                    }
                    HStack(spacing: Tokens.s12) {
                        card(.achievements, "menu.card.achievements", identifier: "menu.card.achievements") {
                            AnyView(VectorTrophyIcon(tier: .gold))
                        }
                        card(.settings, "menu.card.settings", identifier: "menu.card.settings") {
                            AnyView(VectorSettingsIcon())
                        }
                    }
                }
                .padding(.horizontal, Self.panelInset)
                .padding(.top, Tokens.s12)
                .padding(.bottom, Tokens.s24)
            }
            .panelSheet { header }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
            .navigationDestination(for: Destination.self) { destination in
                Group {
                    switch destination {
                    case .orgChart: OrgChartView(close: { dismiss() })
                    case .stats: StatsView(close: { dismiss() })
                    case .achievements: AchievementsView(close: { dismiss() })
                    case .settings: SettingsView(close: { dismiss() })
                    }
                }
                // Empujada, la vista pierde el telón transparente de la hoja:
                // sin esto la franja de abajo se ve blanca y no el juego.
                .clearNavigationBackdrop()
            }
        }
        // El chevron de "atrás" es de sistema y de fábrica sale azul: contra el
        // crema y la tinta del resto del juego, es el único elemento que se ve
        // de otra app.
        .tint(Color("PaletteInk"))
    }

    // MARK: Cabecera

    /// El título y la bajada, ADENTRO del pergamino. Sin banda opaca: el
    /// `panelSheet` recorta la grilla por debajo de la cabecera, y la banda
    /// tapaba el marco (2026-08-18).
    private var header: some View {
        VStack(spacing: Tokens.s4) {
            // El mismo glifo que el tab que abre esta hoja, ADENTRO de la
            // cápsula del título — como Regalos, Pintas, Tienda y Mejoras. El
            // banner ya lo tapa de VoiceOver: es decoración, el título lo dice.
            PanelTitleBanner(
                titleKey: "menu.title",
                icon: AnyView(GameIcon(artKey: "ui_tab_menu", size: 26) { VectorTabMenuIcon() })
            )
            Text("menu.subtitle")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Tokens.s24)
        }
    }

    // MARK: Tarjetas

    /// Una tarjeta de la grilla: plato con el icono grande arriba y el nombre
    /// abajo, dentro de la `GameCard` de siempre.
    ///
    /// El icono entra por `GameIcon`, que es el punto donde el batch de arte de
    /// la T19 va a reemplazar el vectorial **sin tocar código**: alcanza con que
    /// `assets_manifest.json` tenga la clave `ui_menu_*`.
    private func card(
        _ destination: Destination,
        _ titleKey: LocalizedStringKey,
        identifier: String,
        @ViewBuilder icon: @escaping () -> AnyView
    ) -> some View {
        NavigationLink(value: destination) {
            GameCard(style: .normal) {
                VStack(spacing: Tokens.s12) {
                    // El dibujo pelado y GRANDE, sin plato circular (pedido del
                    // dueño, 2026-08-18): el aro achicaba el icono y a este
                    // tamaño el glifo se explica solo — mismo criterio que los
                    // dos accesos de la barra superior.
                    GameIcon(artKey: Self.artKey(for: destination), size: 84) { icon() }
                    Text(titleKey)
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                // Las cuatro tarjetas son el ÚNICO contenido de la pantalla: con
                // el alto natural quedaban chiquitas arriba de todo y media
                // pantalla vacía debajo. `minHeight` las hace ocupar el panel,
                // que es lo que las vuelve tarjetas de menú y no filas de lista.
                .frame(maxWidth: .infinity, minHeight: 158)
                .padding(.vertical, Tokens.s8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(titleKey))
    }

    /// La clave del atlas de cada icono. Los cuatro PNG todavía no existen
    /// —`UIArt` devuelve `nil` y se dibuja el vectorial—, pero la clave viaja
    /// puesta para que integrarlos sea un cambio de dato.
    private static func artKey(for destination: Destination) -> String {
        switch destination {
        case .orgChart: "ui_menu_orgchart"
        case .stats: "ui_menu_stats"
        case .achievements: "ui_menu_trophy"
        case .settings: "ui_menu_settings"
        }
    }
}
