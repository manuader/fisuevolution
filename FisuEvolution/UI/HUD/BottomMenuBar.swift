import SwiftUI

/// La barra inferior de las 6 pantallas (spec §4), espejo de la de Cow
/// Evolution: FisuJobs a la izquierda —la cara del Fisura, como la vaca— y el
/// Menú a la derecha —el cuaderno—, los dos destacados, con las cuatro
/// pantallas del medio en tamaño normal.
///
/// Reemplaza a `SpawnButtonView` (que era el único habitante de la franja de
/// abajo) y a la fila transitoria de cuatro botones del HUD: contratar dejó de
/// ser un botón y pasó a ser una PANTALLA, que es lo que hace falta para
/// comprar cualquier tipo y no sólo el tier base del piso visible.
///
/// No guarda selección: cada tab abre su hoja y vuelve. El estado de "qué hoja
/// está arriba" vive en `GameBoardView.activeScreen`, que es quien la presenta.
///
/// ⚠️ El `accessibilityIdentifier` va en cada botón y **nunca** en el
/// contenedor (trampa 9a-bis del handoff): de eso ya se ocupa `GameTabBar` con
/// `GameTabItem.identifier`. Lo único que hay que respetar acá es no envolver la
/// barra en nada que lleve identificador propio.
struct BottomMenuBar: View {
    /// Qué pantalla abrir. La barra no presenta nada: el `.sheet(item:)` único
    /// de las seis vive en `GameBoardView`.
    let select: (GameScreen) -> Void

    /// Para el puntito de logros cobrables del tab Menú
    /// (`hasClaimableAchievements`, publicada a 8 Hz escribiendo sólo si
    /// cambió: la barra no se recompone por nada más).
    @Environment(GameState.self) private var gameState

    var body: some View {
        GameTabBar(items: items, selection: select)
    }

    // MARK: - Los seis tabs

    private var items: [GameTabItem] {
        GameScreen.allCases.map { screen in
            GameTabItem(
                screen: screen,
                icon: icon(for: screen),
                labelKey: Self.labelKey(for: screen),
                identifier: screen.identifier,
                prominent: Self.isProminent(screen),
                // El circuito del puntito: nace acá con el primer logro
                // cobrable, sigue en la tarjeta de Logros adentro del Menú, y
                // muere al cobrar el último.
                showsBadge: screen == .menu && gameState.hasClaimableAchievements
            )
        }
    }

    /// Los extremos van destacados, como la vaca y el cuaderno del original: la
    /// pantalla donde se gasta la plata y la que guarda todo lo demás.
    private static func isProminent(_ screen: GameScreen) -> Bool {
        screen == .jobs || screen == .menu
    }

    /// ⚠️ Las claves de AX se escriben enteras y no por interpolación del
    /// `rawValue`: `hud.hire`/`hud.bonus`/`hud.settings` no se llaman como su
    /// caso del enum, y armar la clave con `"hud.\(screen.rawValue).label"`
    /// devolvería tres claves que el catálogo no tiene (trampa 5, segunda
    /// forma).
    private static func labelKey(for screen: GameScreen) -> String {
        switch screen {
        case .jobs: "hud.hire.label"
        case .upgrades: "hud.upgrades.label"
        case .skins: "hud.skins.label"
        case .gifts: "hud.bonus.label"
        case .store: "hud.store.label"
        case .menu: "hud.settings.label"
        }
    }

    // MARK: - Glifos

    /// Espejan a `GameTabButton.iconSide`, que es privado: el icono se dibuja a
    /// su propio tamaño y el botón lo enmarca en el mismo, así que si allá
    /// cambiaran quedarían centrados en el plato en vez de romperse.
    private static let iconSide: CGFloat = 48
    private static let prominentIconSide: CGFloat = 54

    /// El glifo de cada tab, ya type-borrado, **y con el ancla del tutorial
    /// puesta donde corresponde**.
    ///
    /// ⚠️ El ancla va en el ICONO y no en la barra: `GameTabItem` no expone el
    /// botón, y marcar el contenedor le daría al tutorial el frame de los seis
    /// tabs juntos —un recorte que abarca media pantalla y no enseña nada—. El
    /// icono está centrado en su plato y mide `iconSide`, así que el recorte
    /// —que `TutorialOverlay` infla 10 pt por lado— cae sobre el plato con un
    /// hilo de aire alrededor: 54+20 = 74 sobre los 62 de un tab destacado,
    /// 48+20 = 68 sobre los 56 de uno normal. Desde que el icono es el que
    /// manda, el recorte sobra 6 pt por lado en vez de faltar: sigue leyéndose
    /// como un halo del tab y no como un cuadrado suelto (verificado en
    /// captura), y como el label vive debajo del plato, el recorte no lo tapa.
    private func icon(for screen: GameScreen) -> AnyView {
        let side = Self.isProminent(screen) ? Self.prominentIconSide : Self.iconSide
        switch screen {
        case .jobs:
            // Sin `GameIcon`: FisuJobs es el único tab que NO tiene PNG propio
            // en el batch de iconos — es la cara del Fisura del atlas, y de
            // resolverla ya se ocupa el vectorial.
            return AnyView(
                VectorTabJobsIcon()
                    .frame(width: side, height: side)
                    .tutorialAnchor(.hire)
            )
        case .upgrades:
            return AnyView(
                GameIcon(artKey: "ui_tab_upgrades", size: side) { VectorTabUpgradesIcon() }
                    .tutorialAnchor(.upgrades)
            )
        case .skins:
            return AnyView(
                GameIcon(artKey: "ui_tab_skins", size: side) { VectorTabSkinsIcon() }
                    .tutorialAnchor(.skins)
            )
        case .gifts:
            return AnyView(
                GameIcon(artKey: "ui_tab_gifts", size: side) { VectorTabGiftsIcon() }
                    .tutorialAnchor(.gifts)
            )
        case .store:
            return AnyView(
                GameIcon(artKey: "ui_tab_shop", size: side) { VectorTabShopIcon() }
                    .tutorialAnchor(.store)
            )
        case .menu:
            return AnyView(
                GameIcon(artKey: "ui_tab_menu", size: side) { VectorTabMenuIcon() }
                    .tutorialAnchor(.menu)
            )
        }
    }
}
