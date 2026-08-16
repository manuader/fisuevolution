import StoreKit
import SwiftUI

/// **La tienda** (spec §8, bible §4.4): lo único que se paga con plata de
/// verdad. Packs de plata y de ORO, quitar los anuncios y las dos skins pagas.
///
/// La pantalla es una **vidriera**, no una lista de precios: arriba la oferta de
/// bienvenida como tarjeta destacada —lo que el Animal Shop resuelve con la fila
/// grande—, después el banner de quitar los anuncios y recién ahí las góndolas de
/// packs, cada fila con su icono y con **lo que te da** calculado contra la
/// partida. Las skins van con preview, porque nadie compra lo que no puede ver.
///
/// Es hermana de `FisuJobsView` y de `CustomizationView` a propósito: mismo
/// `panel_store` con el mismo margen medido, misma cabecera crema opaca, mismas
/// `GameCard`, mismo `PricePill` y el mismo patrón de fila accesible (la tarjeta
/// informa, el botón cobra). Son los tres negocios del juego.
///
/// Dos reglas que no se negocian acá:
/// - **El precio sale SIEMPRE de `product.displayPrice`.** Es la tienda del
///   jugador la que decide la moneda y el monto; escribir "USD 2,99" en el
///   catálogo de strings es rechazo de App Review y encima miente en 40 países.
/// - **Restaurar compras se ve sin scrollear.** Por eso vive en la cabecera fija
///   y no al final de la lista: también es requisito de App Review.
///
/// La tienda **vende** skins; equiparlas es potestad de Pintas y de la ficha de
/// personaje (§3.10), que son las únicas superficies que saben a qué tipo
/// aplicarlas. Acá sólo se cobra y se apunta a dónde se usan.
struct StoreView: View {
    @Environment(StoreManager.self) private var store
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    /// Margen lateral de la columna. **Medido sobre el arte** en la T8 y
    /// reusado por Pintas en la T11: el poste de madera de `panel_store` va de 21
    /// a 32 pt, así que a 30 la columna entra adentro del marco y el toldo se lee
    /// entero. Las tres pantallas del mismo panel quedan alineadas al mismo
    /// punto; si `panel_store` se re-exporta, se vuelve a medir.
    private static let panelInset: CGFloat = 30

    /// Segundos que la PANTALLA lleva esperando a StoreKit.
    ///
    /// Es un cronómetro de la vista y no un dato del estado —ni mucho menos de
    /// una proyección, donde el tiempo restante nunca va— por la misma razón que
    /// los cooldowns de `BonusView`: sólo existe mientras la hoja está abierta y
    /// nadie más lo necesita. Sirve para que una carga que se eterniza gane el
    /// botón de reintento aunque el manager todavía no haya cortado.
    @State private var waitedSeconds = 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                // ⚠️ `VStack` y no `LazyVStack`: son diez productos, los tres
                // tests de UI que miran esta pantalla no scrollean, y la grilla
                // perezosa además rompe el podado de accesibilidad de las
                // tarjetas (medido en la T11). El costo es el del primer armado.
                VStack(spacing: Tokens.s12) {
                    if let message = store.lastErrorMessage {
                        errorBanner(message)
                    }
                    switch store.loadState {
                    case .idle, .loading:
                        loadingCard
                    case .failed:
                        unavailableCard
                    case .loaded:
                        // `Product.products(for:)` no falla cuando un id no
                        // resuelve: lo omite. Con StoreKit caído devuelve la
                        // lista vacía y `loadState` queda en `.loaded`, así que
                        // el hueco hay que nombrarlo acá o no lo nombra nadie.
                        if store.products.isEmpty {
                            unavailableCard
                        } else {
                            shelves
                        }
                    }
                }
                .padding(.horizontal, Self.panelInset)
                .padding(.top, Tokens.s4)
                .padding(.bottom, Tokens.s24)
            }
            .background { PanelBackground(art: "panel_store") }
            .safeAreaInset(edge: .top) { header }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            // La barra de navegación aparece recién al scrollear, y de fábrica lo
            // hace con el material blanco del sistema: contra el marco de madera
            // quedaba una banda blanca cruzando el panel. Pintada de crema empalma
            // con la cabecera de abajo y las dos se leen como UNA barra fija
            // (mismo criterio que `FisuJobsView` y `CustomizationView`).
            .toolbarBackground(Color("PaletteCream"), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
            .onReceive(tick) { _ in
                let waiting = store.loadState == .loading || store.loadState == .idle
                waitedSeconds = waiting ? waitedSeconds + 1 : 0
            }
        }
    }

    // MARK: Cabecera

    /// Título, bajada y restaurar compras, fijos arriba de la vidriera.
    ///
    /// ⚠️ **El fondo crema opaco no es decoración.** Un `safeAreaInset` recorta el
    /// área segura pero el contenido del scroll sigue pasando POR DEBAJO: sin la
    /// banda opaca las tarjetas desfilan a través del título. Es el defecto que el
    /// HANDOFF §8 anota para "el título flotante de los paneles" y que la T8 cortó
    /// en FisuJobs; acá se hereda el arreglo entero, banda de borde a borde
    /// incluida (una banda angosta debajo del fondo full-width de la barra de
    /// navegación deja un escalón).
    private var header: some View {
        VStack(spacing: Tokens.s8) {
            HStack(spacing: Tokens.s8) {
                // El mismo glifo que el tab que abre esta hoja, para que el viaje
                // de un lado al otro se lea como uno solo. Es decoración —el
                // título ya lo dice— así que no queda como parada muda.
                GameIcon(artKey: "ui_tab_shop", size: 34) { VectorTabShopIcon() }
                    .accessibilityHidden(true)
                PanelTitleBanner(titleKey: "store.title")
            }
            Text("store.subtitle")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Tokens.s24)
            // ⚠️ Restaurar vive ACÁ y no al final de la lista: App Review pide
            // que se vea sin scrollear, y en la cabecera fija se ve siempre. Va
            // en azul y no en el verde de las compras porque no cobra nada: en
            // esta pantalla el verde es plata que sale.
            ActionPill(
                titleKey: "store.restore",
                systemImage: "arrow.clockwise",
                tint: Color("PaletteBlue"),
                identifier: "store.restore"
            ) {
                Task { await store.restore() }
            }
        }
        .padding(.top, 6)
        .padding(.bottom, Tokens.s8)
        .frame(maxWidth: .infinity)
        .background {
            Color("PaletteCream")
                .shadow(color: .black.opacity(0.14), radius: 5, y: 3)
        }
    }

    // MARK: Vidriera

    /// Las góndolas, en el orden de venta del catálogo.
    ///
    /// Sólo se dibuja la sección que tiene productos: evita cintas colgadas sobre
    /// un hueco cuando StoreKit devolvió menos de los declarados.
    @ViewBuilder private var shelves: some View {
        let featured = products(.starterPack)
        let removeAds = products(.removeAds)
        if !featured.isEmpty || !removeAds.isEmpty {
            // Las dos van juntas —y no cada una con su cinta— porque se agrupan
            // por lo que ENTREGAN: el combo es `nonConsumable` igual que quitar
            // los ads, y las dos son mejoras de la partida entera.
            shelfHeader("store.section.general")
            ForEach(featured) { card($0, format: .featured, glyph: .bundle) }
            ForEach(removeAds) { card($0, format: .row, glyph: .removeAds) }
        }
        shelf("store.section.coins", products(.coins), glyph: .coins)
        shelf("store.section.oro", products(.oro), glyph: .oro)
        let skins = products(.skin)
        if !skins.isEmpty {
            shelfHeader("store.section.skins")
            ForEach(skins) { product in
                card(product, format: .row, glyph: .skin(skinPreview(for: product.id)))
            }
        }
    }

    @ViewBuilder
    private func shelf(
        _ titleKey: LocalizedStringKey,
        _ products: [Product],
        glyph: StoreProductCard.Glyph
    ) -> some View {
        if !products.isEmpty {
            shelfHeader(titleKey)
            ForEach(products) { card($0, format: .row, glyph: glyph) }
        }
    }

    private func shelfHeader(_ titleKey: LocalizedStringKey) -> some View {
        SectionHeader(titleKey)
            .frame(maxWidth: .infinity)
            .padding(.top, Tokens.s8)
    }

    /// Una tarjeta de producto, con todo lo que la vista sabe y el modelo no: el
    /// monto del pack —que sale calculado contra la partida— y si ya está
    /// comprado.
    private func card(
        _ product: Product,
        format: StoreProductCard.Format,
        glyph: StoreProductCard.Glyph
    ) -> some View {
        let entry = store.entry(for: product.id)
        return StoreProductCard(
            product: product,
            format: format,
            glyph: glyph,
            // La línea de arriba es el número concreto y sale calculado contra
            // la partida (la plata de un pack depende de dónde estás parado); la
            // de abajo es el color, que lo pone el `.storekit`. `nil` para lo que
            // no es pack: repetir la descripción sería una segunda fuente.
            reward: entry.flatMap(gameState.packRewardText),
            // Sólo el combo lleva la escarapela: es la única oferta de la
            // pantalla y destacar dos cosas es no destacar ninguna.
            tagline: format == .featured ? String(localized: "store.featured") : nil,
            // Un consumible nunca queda "comprado", así que siempre cae en el
            // botón: se vuelve a vender.
            purchased: store.isPurchased(product.id),
            // Una skin comprada no se equipa acá (§3.10): la fila lo dice.
            hint: entry?.entitlement == .skin ? String(localized: "store.skin.equip-hint") : nil,
            purchasing: store.isPurchasing
        ) {
            Task { await store.purchase(product) }
        }
    }

    // MARK: Carga y caída

    /// Mientras StoreKit contesta.
    ///
    /// Pasado el plazo la tarjeta gana el reintento. El manager corta solo a los
    /// mismos segundos —desde el fix del timeout—, así que esto es el cinturón
    /// del tirante: si la hoja se abrió con una carga ya en vuelo, el jugador no
    /// se queda mirando un spinner sin salida.
    private var loadingCard: some View {
        GameCard(style: .normal) {
            VStack(spacing: Tokens.s8) {
                ProgressView()
                    .tint(Color("PaletteInk"))
                Text("loading.title")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk").opacity(0.8))
                if waitedSeconds >= patience {
                    retryPill
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Lo que ve el jugador cuando la tienda no tiene nada que ofrecerle, sea
    /// porque la carga falló, porque venció el plazo o porque volvió vacía.
    ///
    /// Lleva el reintento adentro: `start()` es idempotente —corta con su guarda
    /// de `updatesTask`— y no vuelve a pedir los productos, así que cerrar y
    /// reabrir el carrito no arregla nada por sí solo. El botón llama a
    /// `loadProducts()` directo, que sí reintenta.
    private var unavailableCard: some View {
        GameCard(style: .normal) {
            VStack(spacing: Tokens.s8) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Color("PaletteOrange"))
                    .accessibilityHidden(true)
                Text("store.error.load")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    // Ya lo dice el resumen de la tarjeta.
                    .accessibilityHidden(true)
                retryPill
            }
            .padding(.vertical, Tokens.s4)
            .frame(maxWidth: .infinity)
        }
        // ⚠️ El identifier va en una capa VACÍA y detrás, no sobre la tarjeta:
        // un elemento de accesibilidad que CONTIENE un control lo borra del árbol
        // (trampa 9a), y `store.retry` —que es lo único accionable de este
        // estado— dejaría de existir justo cuando más falta hace.
        .background {
            Color.clear
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("store.unavailable")
                .accessibilityLabel(Text("store.error.load"))
                .allowsHitTesting(false)
        }
    }

    private var retryPill: some View {
        ActionPill(
            titleKey: "store.retry",
            systemImage: "arrow.clockwise",
            tint: Color("PaletteOrange"),
            identifier: "store.retry"
        ) {
            Task { await store.loadProducts() }
        }
    }

    /// La paciencia de la pantalla sale del plazo del manager en vez de ser su
    /// propio número: así no pueden divergir, y bajarle el timeout al manager
    /// (los tests lo hacen) no deja a la vista esperando de más.
    private var patience: Int {
        max(1, Int(store.loadTimeout.components.seconds))
    }

    /// El error de una compra o de un restore. Va arriba de todo y no al final:
    /// es la respuesta a lo que el jugador acaba de tocar.
    private func errorBanner(_ message: String) -> some View {
        GameCard(style: .normal) {
            HStack(spacing: Tokens.s8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color("PalettePink"))
                    .accessibilityHidden(true)
                Text(verbatim: message)
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Datos

    /// Los productos de un entitlement, en el orden del catálogo (que es el que
    /// `StoreManager` ya dejó puesto).
    private func products(_ entitlement: ProductCatalog.Entry.Entitlement) -> [Product] {
        store.products.filter { store.entry(for: $0.id)?.entitlement == entitlement }
    }

    /// El preview de una skin paga: la textura del catálogo, buscada por el mismo
    /// camino que Pintas (producto → skin → personaje → atlas), porque el arte de
    /// una skin vive en el atlas de SU personaje.
    ///
    /// Mismo criterio que el tablero y la ficha (`PlaceholderRenderer`): una skin
    /// cuyo arte todavía no existe cae al retrato BASE del personaje y no a un
    /// placeholder roto — el catálogo puede shippear antes que el arte.
    private func skinPreview(for productID: String) -> Image? {
        guard let skinID = store.skinId(for: productID),
              let content = gameState.content,
              let entry = content.skins.entry(id: skinID),
              let asset = content.manifest.characters[entry.characterType]
        else { return nil }
        if let key = entry.textureKey, let art = UIArt.characterImage(atlas: asset.atlas, key: key) {
            return art
        }
        return UIArt.characterImage(atlas: asset.atlas, key: asset.key)
    }
}

// MARK: - Tarjeta de producto

/// Una tarjeta de la vidriera. Los dos formatos —la oferta destacada y la fila de
/// góndola— comparten anatomía (plato, datos y un slot para el precio) para que
/// la pantalla se lea como una columna y no como dos diseños distintos.
private struct StoreProductCard: View {
    /// La oferta ocupa el ancho y pone su precio abajo, centrado, como el cartel
    /// de una promoción; las demás son una fila con el precio en el riel derecho,
    /// igual que FisuJobs.
    enum Format {
        case featured
        case row
    }

    /// Qué se dibuja en el plato de la izquierda.
    ///
    /// Es un enum y no una vista type-borrada para que el dibujo de cada icono
    /// viva acá adentro: con `AnyView` cada llamador arma su propio plato y a la
    /// tercera ya no son el mismo juego.
    enum Glyph {
        case coins
        case oro
        case removeAds
        /// El combo de bienvenida.
        case bundle
        /// La pinta que se vende, si su arte existe.
        case skin(Image?)
    }

    let product: Product
    let format: Format
    let glyph: Glyph
    /// Qué te da el pack, ya calculado y formateado, o `nil` si no es pack.
    let reward: String?
    /// La escarapela de la oferta ("Oferta de bienvenida"), o `nil`.
    let tagline: String?
    let purchased: Bool
    /// Aclaración de la fila cuando ya está comprada (dónde se usa lo que
    /// compraste). Sólo las skins la llevan.
    let hint: String?
    /// Hay una compra en vuelo.
    let purchasing: Bool
    let buy: () -> Void

    /// Lado del plato. **Medido contra FisuJobs sobre la captura**: con 56 pt los
    /// iconos de la tienda se veían de otro juego que los retratos de 72 del
    /// portal —dos pantallas del mismo `panel_store`, una al lado de la otra, con
    /// la columna izquierda de distinto peso—. A 64 la góndola pesa lo mismo sin
    /// comerle ancho a la columna de datos, que acá lleva un renglón más que allá
    /// (nombre + lo que da + descripción). El de la oferta es más grande porque
    /// es la tarjeta que tiene que frenar el pulgar.
    private var plateSide: CGFloat { format == .featured ? 80 : 64 }

    var body: some View {
        Group {
            switch format {
            // Amarillo: el acento de "este" en todo el juego (el piso actual del
            // ascensor, la cara elegida del carrusel, la pinta puesta).
            case .featured: GameCard(style: .highlighted(Color("PaletteYellow"))) { content }
            case .row: GameCard(style: .normal) { content }
            }
        }
        // ⚠️ El elemento de estado va en una capa VACÍA y **detrás** (patrón T8):
        // si el trío `children: .ignore` + id + value se pusiera sobre la tarjeta
        // entera se tragaría al botón —un elemento de accesibilidad que CONTIENE
        // un control lo borra del árbol (trampa 9a)— y `store.buy.<id>` dejaría
        // de existir. Atrás, el botón queda por delante y los dos se ven: la
        // tarjeta informa, el botón cobra.
        //
        // ⚠️⚠️ Y por eso el `children: .ignore` NO alcanza solo: ignora a los
        // hijos DE ESTA CAPA (que no tiene), no a la tarjeta, que es su HERMANA
        // en el `ZStack` del `.background`. El silenciado de verdad vive sobre el
        // nombre, la descripción y el badge.
        .background {
            Color.clear
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("store.row.\(product.id)")
                // `displayName` y `description` los pone StoreKit: son texto ya
                // resuelto, no claves (trampa 5).
                .accessibilityLabel(Text(verbatim: product.displayName))
                .accessibilityValue(Text(verbatim: axValue))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder private var content: some View {
        switch format {
        case .featured:
            VStack(spacing: Tokens.s12) {
                HStack(spacing: Tokens.s12) {
                    plate
                    info
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // El precio de la oferta va abajo y a lo ancho: es el botón que
                // la tarjeta existe para que se toque.
                rail.frame(maxWidth: .infinity)
            }
        case .row:
            HStack(spacing: Tokens.s12) {
                plate
                info
                    .frame(maxWidth: .infinity, alignment: .leading)
                rail
            }
        }
    }

    // MARK: Plato

    /// El icono, encuadrado como el retrato de FisuJobs y el preview de Pintas:
    /// plato amarillo tenue, esquinas redondeadas y borde ink. La tienda no
    /// inventa un encuadre propio.
    private var plate: some View {
        Color.clear
            .frame(width: plateSide, height: plateSide)
            .overlay { art.padding(6) }
            .background(Color("PaletteYellow").opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color("PaletteInk"), lineWidth: 2)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder private var art: some View {
        switch glyph {
        case .coins:
            CoinIcon(size: plateSide)
        case .oro:
            OroIcon(size: plateSide)
        case .bundle:
            GameIcon(artKey: "ui_money", size: plateSide) { CoinIcon(size: plateSide) }
        case .removeAds:
            // El glifo del video tachado y no un cartel genérico: los anuncios
            // que el juego tiene HOY son los rewarded de Regalos, y la tienda no
            // promete más de lo que hay.
            Image(systemName: "play.slash.fill")
                .resizable()
                .scaledToFit()
                .padding(4)
                .foregroundStyle(Color("PaletteInk").opacity(0.8))
        case .skin(let preview):
            if let preview {
                preview.resizable().scaledToFit()
            } else {
                Image(systemName: "tshirt.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .foregroundStyle(Color("PaletteInk").opacity(0.35))
            }
        }
    }

    // MARK: Columna de datos

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let tagline {
                StateBadge(text: tagline, systemImage: "star.fill", muted: false)
                    // Ya viaja en el valor de la tarjeta.
                    .accessibilityHidden(true)
            }
            Text(verbatim: product.displayName)
                .font(format == .featured ? Tokens.title : Tokens.body)
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                // Es el nombre de la tarjeta: ya lo dice el resumen.
                .accessibilityHidden(true)
            if let reward {
                // ⚠️ Esta línea **no** se tapa de VoiceOver, a diferencia del
                // resto de la columna: es el único dato que no está en ningún
                // otro lado (el monto sale calculado contra la partida, no del
                // `.storekit`), y su identifier es lo que pinea `StoreUITests`.
                // Queda como segunda parada de la tarjeta, y dice algo nuevo.
                Text(verbatim: reward)
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteGreen"))
                    // ⚠️ **Tres renglones y no dos.** Medido sobre la captura: la
                    // columna de datos de una fila mide ~127 pt (el plato y el
                    // precio se llevan el resto), y con dos renglones la línea
                    // del ORO salía "Gives you 250 ORO to spend on perman…". Es
                    // el mismo defecto que la T8 cortó en los nombres de
                    // FisuJobs: truncar JUSTO la línea que dice qué estás
                    // comprando. Una fila más alta se lee como una fila más
                    // alta; un puntito suspensivo se lee como que falta algo.
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("store.reward.\(product.id)")
            }
            // La descripción es la del `.storekit` y también entra entera: con
            // dos renglones, "Dios con delantal chamuscado y pinza de a…" dejaba
            // el chiste por la mitad, que es la única razón por la que ese texto
            // existe.
            Text(verbatim: product.description)
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.65))
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
    }

    // MARK: Riel del precio

    @ViewBuilder private var rail: some View {
        if purchased {
            VStack(alignment: .trailing, spacing: 4) {
                StateBadge(
                    text: String(localized: "store.purchased"),
                    systemImage: "checkmark.circle.fill",
                    textAlignment: format == .featured ? .center : .trailing,
                    muted: false
                )
                if let hint {
                    Text(verbatim: hint)
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.6))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }
            // Todo lo que dice este riel ya viaja en el valor de la tarjeta.
            .accessibilityHidden(true)
        } else {
            PricePill(
                // ⚠️ **Siempre `displayPrice`**: la moneda y el monto los decide
                // la tienda del jugador.
                text: product.displayPrice,
                // El carrito y no la moneda del juego: con una moneda puesta,
                // "USD 1,99" se lee como si costara plata de la partida.
                currency: .money,
                affordable: true,
                // El id lleva el id del producto porque con diez filas los
                // botones se leen todos "USD 2,99": sin esto no hay test de UI
                // que pueda apretar UNO. Es un `String` y no una clave de
                // localización, así que interpolarlo es correcto (la trampa 5 es
                // de `LocalizedStringKey`).
                identifier: "store.buy.\(product.id)",
                action: buy
            )
            // Una compra en vuelo levanta la hoja de pago del sistema por
            // encima de todo, así que el dimming del `.disabled` no lo ve nadie:
            // acá sólo evita que un segundo toque encole otra compra. (Es el
            // único `.disabled` que la gramática admite sobre un `PricePill`: la
            // regla prohíbe usarlo para "no te alcanza", que es otra cosa.)
            .disabled(purchasing)
        }
    }

    /// El valor de la tarjeta es **su estado o de qué se trata**, igual que en
    /// FisuJobs y en Pintas. El precio no va: es el label del botón, que ya es su
    /// propia parada.
    private var axValue: String {
        if purchased {
            return [String(localized: "store.purchased"), hint]
                .compactMap { $0 }
                .joined(separator: ", ")
        }
        return [tagline, product.description]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
