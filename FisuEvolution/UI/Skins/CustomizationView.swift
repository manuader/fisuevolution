import EconomyKit
import StoreKit
import SwiftUI

/// **Pintas** — el Customization Shop (spec §7): la pantalla donde se le cambia
/// la ropa a cada personaje.
///
/// La pantalla es **dos listas encastradas**: arriba el carrusel de caras —a
/// quién estás vistiendo— y abajo la grilla de sus apariencias. Esa es toda la
/// navegación: no hay pestañas, no hay filtros y no hay una tercera pantalla
/// para confirmar nada. Tocás una cara, ves sus pintas, tocás una y se la pone.
///
/// Lo que la vista **no** hace: no le pregunta al catálogo de skins ni al save.
/// Cada `SkinCatalogRow` viene con el nombre, la textura y el estado —incluida
/// la condición de desbloqueo YA traducida— resueltos por
/// `skinCatalogRows(forCharacterType:)`. Lo único que la vista resuelve por su
/// cuenta es el **precio**, que sale de StoreKit y no puede vivir en el estado.
///
/// Es hermana de `FisuJobsView` a propósito: mismo panel de tienda, misma
/// cabecera crema opaca, mismas `GameCard`, mismo `PricePill`, mismo
/// `StateBadge` y el mismo patrón de fila accesible (la tarjeta informa, el
/// botón cobra). Son los dos negocios del juego.
struct CustomizationView: View {
    @Environment(GameState.self) private var gameState
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// A quién estamos vistiendo. `nil` = "el que la pantalla elija", que es
    /// `defaultSkinnableType`: el de tier más alto que viste EN ESTA RUN.
    ///
    /// No se guarda entre aperturas, así que ese default es lo que el jugador
    /// ve cada vez que abre la hoja — y por eso no puede salir de la unión a
    /// secas. La lista incluye a los personajes de los que tenés una pinta sin
    /// haberlos visto, y ésos ordenan ARRIBA de los tuyos: abrir ahí sería
    /// aterrizar en un desconocido. Lo decide el estado, no esta vista.
    @State private var selectedTypeID: String?

    /// Margen lateral de la columna: el del marco vectorial, publicado por el
    /// componente. Un solo número para las nueve hojas — el marco es el
    /// contenedor y las tarjetas viven ADENTRO (pedido del dueño, 2026-08-18;
    /// antes eran cuatro insets medidos PNG por PNG contra el arte 9-slice,
    /// que además se deformaba al estirarse).
    private static let panelInset: CGFloat = WoodPanelBackground.columnInset

    /// Lado de la carita del carrusel y ancho de su celda (la celda es más ancha
    /// porque abajo va el nombre, que casi siempre es más largo que la cara).
    private static let faceSide: CGFloat = 62
    private static let faceCellWidth: CGFloat = 82

    var body: some View {
        // Las dos cosas que mueven esta pantalla: **ganar o equipar una pinta**
        // (`skinSelectionVersion`, que bumpean `equipSkin` y las cinco vías que
        // acreditan una) y conocer un personaje nuevo mientras la hoja está
        // abierta (`boardVersion`). Son también las dos mitades de
        // `skinnableTypes`, que se computa al leerse: por eso alcanza con
        // leerlas acá y no hace falta publicarla. `player` es
        // `@ObservationIgnored`, así que el tick de 60 Hz no la recompone.
        let _ = gameState.skinSelectionVersion
        let _ = gameState.boardVersion

        // ⚠️ UNA lectura por evaluación del body de cada una: las tres recorren
        // el catálogo entero de tipos.
        let allTypes = orderedTypes
        let skinnable = gameState.skinnableTypes
        let skinnableIDs = Set(skinnable.map(\.id))
        let selected = selection(among: skinnable)

        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.s12) {
                    if let selected {
                        // La cinta dice a quién estás vistiendo. Es el eco del
                        // marco amarillo de la cara elegida: el carrusel puede
                        // quedar scrolleado lejos y la grilla tiene que poder
                        // leerse sola.
                        SectionHeader(verbatim: String(localized: "skins.grid.title \(selected.localizedName)"))
                            .padding(.top, Tokens.s8)
                        grid(for: selected)
                    }
                }
                .padding(.horizontal, Self.panelInset)
                .padding(.bottom, Tokens.s24)
            }
            .panelSheet(awning: true) {
                header(allTypes: allTypes, skinnableIDs: skinnableIDs, selectedID: selected?.id)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
    }

    // MARK: Cabecera

    /// Título + carrusel de caras, ADENTRO del pergamino, debajo del toldo.
    ///
    /// Sin banda opaca: el `panelSheet` recorta la grilla por debajo de la
    /// cabecera, y la banda crema de borde a borde tapaba el toldo y los postes
    /// (2026-08-18). El carrusel también queda contenido: su scroll horizontal
    /// se recorta al ancho de la columna, como todo lo demás.
    private func header(allTypes: [CharacterType], skinnableIDs: Set<String>, selectedID: String?) -> some View {
        VStack(spacing: Tokens.s8) {
            // El mismo glifo que el tab que abre esta hoja, ADENTRO de la
            // cápsula del título (composición de las referencias). El banner ya
            // lo tapa de VoiceOver: es decoración, el título lo dice.
            PanelTitleBanner(
                titleKey: "skins.title",
                icon: AnyView(GameIcon(artKey: "ui_tab_skins", size: 26) { VectorTabSkinsIcon() })
            )
            characterStrip(allTypes: allTypes, skinnableIDs: skinnableIDs, selectedID: selectedID)
        }
    }

    /// El carrusel de caras: el catálogo entero en orden de evolución, y en
    /// silueta lo que todavía no se puede vestir.
    ///
    /// ⚠️ `HStack` y no `LazyHStack`: los 43 tipos tienen que existir en el árbol
    /// de accesibilidad sin scrollear (es lo que ejerce `CustomizationUITests`,
    /// que no desliza el carrusel), y `UIArt` cachea los `UIImage`, así que el
    /// costo es el del primer armado y no el de cada invalidación — el mismo
    /// razonamiento que las 43 tarjetas de `FisuJobsView`.
    private func characterStrip(allTypes: [CharacterType], skinnableIDs: Set<String>, selectedID: String?) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.s8) {
                    ForEach(allTypes, id: \.id) { type in
                        if skinnableIDs.contains(type.id) {
                            Button {
                                selectedTypeID = type.id
                            } label: {
                                faceTile(type: type, selected: type.id == selectedID, unknown: false)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("skins.character.\(type.id)")
                            // El nombre ya viene traducido de `tier.name.<id>`, así
                            // que va verbatim: como clave se buscaría de nuevo.
                            .accessibilityLabel(Text(verbatim: type.localizedName))
                            .accessibilityAddTraits(type.id == selectedID ? [.isSelected] : [])
                        } else {
                            // Todavía desconocido —ni visto en esta run ni con una
                            // pinta suya en la colección—: silueta y "???", sin
                            // botón (RF-03, no espoilear la cadena de evolución).
                            //
                            // ⚠️ Y **tapado de VoiceOver a propósito**: no es
                            // seleccionable y no dice nada más que "hay más por
                            // descubrir". Sin esto, entre las caras que sí se pueden
                            // tocar quedarían hasta 35 paradas seguidas que se
                            // anuncian todas igual, y el carrusel se vuelve
                            // inservible con lector de pantalla.
                            faceTile(type: type, selected: false, unknown: true)
                                .accessibilityHidden(true)
                        }
                    }
                }
                // El margen lateral de la columna ya lo pone la cabecera del
                // `panelSheet`; acá sólo el aire para que el marco de la cara
                // elegida y su sombra no queden cortados por el borde del scroll.
                .padding(.horizontal, Tokens.s4)
                .padding(.vertical, 4)
            }
            // **El marco amarillo tiene que estar EN PANTALLA.** El carrusel son 43
            // celdas de 82 pt y en un iPhone entran cuatro y media, así que la cara
            // elegida cae fuera del cuadro apenas pasa la quinta — y el jugador
            // abre una pantalla que dice a quién está vistiendo con una tira donde
            // no hay nada resaltado.
            //
            // Antes se toleraba porque el aterrizaje era el tier más alto VISTO y
            // la cinta de abajo lo nombraba igual. Con la unión, los personajes de
            // los que tenés pinta sin haberlos visto ordenan ARRIBA de los tuyos,
            // así que hasta el aterrizaje correcto puede quedar en la celda 8 con
            // el scroll en 0: el desfase dejó de ser el caso raro.
            //
            // `initial: true` porque la primera evaluación YA trae la selección
            // resuelta (`selection(among:)` no espera a ningún `onAppear`), y
            // `.center` porque el carrusel se navega mirando a los costados: pegar
            // la cara elegida a un borde esconde la mitad de sus vecinas.
            .onChange(of: selectedID, initial: true) { _, id in
                guard let id else { return }
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    /// Una cara del carrusel: retrato encuadrado + nombre debajo.
    ///
    /// La elegida lleva **marco y halo amarillos**, el mismo acento con el que el
    /// ascensor marca el piso donde estás parado y `GameCard(.highlighted)` marca
    /// lo destacado: en todo el juego, amarillo = "este".
    private func faceTile(type: CharacterType, selected: Bool, unknown: Bool) -> some View {
        VStack(spacing: 3) {
            Color.clear
                .frame(width: Self.faceSide, height: Self.faceSide)
                .overlay { face(for: type, unknown: unknown).padding(3) }
                .background(Color("PaletteYellow").opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            selected ? Color("PaletteYellow") : Color("PaletteBrown").opacity(unknown ? 0.35 : 0.7),
                            lineWidth: selected ? 3 : 2
                        )
                )
                .shadow(color: Color("PaletteYellow").opacity(selected ? 0.55 : 0), radius: 7)
            Text(verbatim: unknown ? "???" : type.localizedName)
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(unknown ? 0.45 : (selected ? 1 : 0.75)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: Self.faceCellWidth)
        .contentShape(Rectangle())
    }

    /// La carita del manifest (`<id>_face`), en silueta de tinta mientras el
    /// personaje sea desconocido — la misma silueta que usan FisuJobs y la ficha.
    @ViewBuilder private func face(for type: CharacterType, unknown: Bool) -> some View {
        if let image = UIArt.image("\(type.id)_face") {
            if unknown {
                image.resizable().renderingMode(.template).scaledToFit()
                    .foregroundStyle(Color("PaletteInk"))
            } else {
                image.resizable().scaledToFit()
            }
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(10)
                .foregroundStyle(Color("PaletteInk").opacity(unknown ? 1 : 0.35))
        }
    }

    // MARK: Grilla

    /// Las pintas del personaje elegido, en dos columnas.
    ///
    /// Dos y no una: una skin se elige **mirándola**, así que la tarjeta es un
    /// preview grande con el nombre debajo, y dos previews grandes entran a lo
    /// ancho. Ningún personaje del catálogo tiene hoy más de dos skins, así que
    /// la grilla entra entera sin scrollear.
    ///
    /// ⚠️ Filas de a dos a mano y **no** `LazyVGrid`: la grilla perezosa
    /// materializa cada celda por su cuenta y ahí el `accessibilityHidden` de la
    /// tarjeta deja de podar —medido el 2026-08-15 volcando el árbol: con
    /// `LazyVGrid`, el nombre y el badge de cada tarjeta seguían siendo elementos
    /// sueltos al lado del resumen de la fila, o sea el defecto que la T8 arregló
    /// en FisuJobs—. Con `VStack`/`HStack` la tarjeta vuelve a ser UNA parada.
    /// De paso, el `alignment: .top` + el `fixedSize` vertical le dan a las dos
    /// tarjetas de una fila la MISMA altura, que la grilla perezosa tampoco hacía.
    private func grid(for type: CharacterType) -> some View {
        let rows = gameState.skinCatalogRows(forCharacterType: type.id)
        let asset = gameState.content?.manifest.characters[type.id]
        return VStack(spacing: Tokens.s12) {
            ForEach(Self.pairs(of: rows)) { pair in
                HStack(alignment: .top, spacing: Tokens.s12) {
                    card(pair.left, asset: asset, type: type)
                    if let right = pair.right {
                        card(right, asset: asset, type: type)
                    } else {
                        // La media fila de un catálogo impar: sin esto, la última
                        // tarjeta sola se estira a lo ancho de las dos columnas.
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func card(_ row: SkinCatalogRow, asset: AssetsManifest.CharacterAsset?, type: CharacterType) -> some View {
        SkinCard(
            row: row,
            atlas: asset?.atlas,
            baseKey: asset?.key,
            price: price(for: row),
            oroBalance: gameState.player?.meta.oro ?? 0,
            equip: { equip(row, on: type.id) },
            buy: { buy(row) },
            buyWithOro: { gameState.buySkinWithOro(skinID: row.id) }
        )
        // La manito sobre la pinta sin estrenar, SOLO hasta que el jugador se
        // ponga la primera (corrección del dueño, 2026-08-21: donde haya que
        // hacer click, se ve el click). Con `anySkinEverEquipped` la guía
        // muere para siempre: el gesto ya está aprendido.
        .overlay(alignment: .bottomTrailing) {
            if case .owned = row.state, !gameState.anySkinEverEquipped {
                TapHereHand(size: 34)
                    .padding([.bottom, .trailing], Tokens.s12)
            }
        }
    }

    /// Las filas de a pares, conservando el orden del catálogo.
    private static func pairs(of rows: [SkinCatalogRow]) -> [SkinRowPair] {
        stride(from: 0, to: rows.count, by: 2).map { index in
            SkinRowPair(left: rows[index], right: index + 1 < rows.count ? rows[index + 1] : nil)
        }
    }

    // MARK: Acciones

    /// El precio REAL de la tienda del jugador, o `nil` si el producto no cargó
    /// (StoreKit caído, sin red, o la app corriendo sin configuración de tienda).
    /// La tarjeta se dibuja igual: sin precio no hay botón de compra y en su
    /// lugar queda el candado genérico.
    private func price(for row: SkinCatalogRow) -> String? {
        guard case .purchasable(let productID) = row.state else { return nil }
        return store.products.first { $0.id == productID }?.displayPrice
    }

    private func equip(_ row: SkinCatalogRow, on typeID: String) {
        // La base no es una skin: se vuelve a ella con `nil`.
        gameState.equipSkin(
            id: row.id == GameState.baseSkinRowID ? nil : row.id,
            forCharacterType: typeID
        )
    }

    private func buy(_ row: SkinCatalogRow) {
        guard case .purchasable(let productID) = row.state,
              let product = store.products.first(where: { $0.id == productID })
        else { return }
        Task { await store.purchase(product) }
    }

    // MARK: Selección

    /// El catálogo entero en orden de evolución. El desempate por id mantiene el
    /// orden estable entre dos lecturas cuando cuatro carreras comparten tier.
    private var orderedTypes: [CharacterType] {
        (gameState.content?.tiers.concreteTypes ?? [])
            .sorted { ($0.tier, $0.id) < ($1.tier, $1.id) }
    }

    /// A quién vestimos: el que el jugador eligió si sigue siendo válido, y si
    /// no el aterrizaje por defecto. Se resuelve en cada evaluación —y no en un
    /// `onAppear`— para que la pantalla nunca quede en blanco mientras el
    /// `@State` se pone al día.
    ///
    /// ⚠️ El default **no** es `skinnable.first`: es
    /// `defaultSkinnableType(among:)`, que es lo último que el jugador VIO y no
    /// lo más alto de la lista. El porqué está en el estado, que es donde vive
    /// la regla.
    private func selection(among skinnable: [CharacterType]) -> CharacterType? {
        if let selectedTypeID, let match = skinnable.first(where: { $0.id == selectedTypeID }) {
            return match
        }
        return gameState.defaultSkinnableType(among: skinnable)
    }
}

// MARK: - Tarjeta

/// Dos tarjetas de una fila de la grilla (la segunda falta cuando el catálogo
/// del personaje es impar).
private struct SkinRowPair: Identifiable {
    let left: SkinCatalogRow
    let right: SkinCatalogRow?
    var id: String { left.id }
}

/// Una pinta. Los cuatro estados comparten la misma anatomía —preview, nombre y
/// un slot abajo— para que la grilla se lea como una vitrina y no como cuatro
/// diseños distintos.
private struct SkinCard: View {
    let row: SkinCatalogRow
    /// Atlas y clave BASE del personaje: de acá sale el preview de la apariencia
    /// original, y también el respaldo de una skin cuyo arte todavía no exista.
    let atlas: String?
    let baseKey: String?
    /// `displayPrice` de StoreKit, sólo para las que están a la venta.
    let price: String?
    let oroBalance: Int
    let equip: () -> Void
    let buy: () -> Void
    let buyWithOro: () -> Void

    private static let previewSide: CGFloat = 104

    /// Los tres tonos de tarjeta.
    ///
    /// ⚠️ Existe porque `GameCard.Style` está **anidado en un tipo genérico**:
    /// `GameCard<A>.Style` y `GameCard<B>.Style` son tipos distintos, así que el
    /// estilo no se puede guardar en una propiedad con anotación de tipo sin
    /// nombrar el contenido. Se elige el tono acá y el `switch` se hace donde el
    /// contenido ya está fijado (mismo patrón que `FisuJobsView` y `FloorMapView`).
    private enum Tone {
        case plain
        case equipped
        case locked
    }

    private var tone: Tone {
        switch row.state {
        case .equipped: .equipped
        case .owned: .plain
        // Una skin a la venta **no** es una tarjeta apagada: es mercadería, y se
        // muestra a todo color, con precio o sin él.
        //
        // ⚠️ Antes se apagaba cuando el producto no había cargado, y eso **mentía**:
        // que StoreKit no haya contestado todavía —sin red, o la app corriendo sin
        // configuración de tienda— no dice nada sobre la skin. La tarjeta gris con
        // candado afirmaba "esto no se vende" y encima se transformaba sola cuando
        // los productos llegaban. El estado del catálogo manda sobre el de la red:
        // si es mercadería se ve como mercadería, y lo que falta —el precio— lo
        // dice el badge de abajo.
        case .purchasable, .oroPurchasable: .plain
        case .milestoneLocked: .locked
        }
    }

    var body: some View {
        Group {
            switch tone {
            // La puesta lleva marco y halo amarillos, el acento de "este" en todo
            // el juego (el piso actual del ascensor, la cara elegida del
            // carrusel).
            case .equipped: GameCard(style: .highlighted(Color("PaletteYellow"))) { content }
            case .plain: GameCard(style: .normal) { content }
            case .locked: GameCard(style: .locked) { content }
            }
        }
        // ⚠️ El elemento de estado va en una capa VACÍA y **detrás** (patrón T8):
        // si el trío `children: .ignore` + id + value se pusiera sobre la tarjeta
        // entera se tragaría al botón —un elemento de accesibilidad que CONTIENE
        // un control lo borra del árbol (trampa 9a)— y `skins.equip.<id>` dejaría
        // de existir. Atrás, el botón queda por delante y los dos se ven: la
        // tarjeta informa, el botón hace.
        //
        // ⚠️⚠️ Y por eso el `children: .ignore` NO alcanza solo: ignora a los
        // hijos DE ESTA CAPA (que no tiene), no a la tarjeta, que es su HERMANA
        // en el `ZStack` del `.background`. El silenciado de verdad vive en el
        // preview, el nombre y el badge de `content`.
        .background {
            Color.clear
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("skins.row.\(row.id)")
                .accessibilityLabel(Text(verbatim: row.displayName))
                .accessibilityValue(Text(verbatim: axValue))
                .allowsHitTesting(false)
        }
    }

    /// ⚠️ El `maxHeight: .infinity` no es decoración: sin él, dos tarjetas de la
    /// misma fila con distinto contenido (una con botón, otra con badge) quedan
    /// de alturas distintas y la grilla se ve escalonada. Con la tarjeta estirada
    /// a la altura de la fila y el `Spacer` empujando, el control de las dos cae
    /// a la misma línea. **Medido sobre la captura**: antes, 188 pt contra 200.
    private var content: some View {
        VStack(spacing: Tokens.s8) {
            info
                // Todo lo que dice esta columna ya lo dice el resumen de la
                // tarjeta. Va tapado ENTERO y en un contenedor —y no `Text` por
                // `Text`—: es la forma que la T8 midió que funciona en
                // `FisuJobsView`.
                .accessibilityHidden(true)
            control
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var info: some View {
        VStack(spacing: Tokens.s8) {
            preview
            Text(verbatim: row.displayName)
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// El preview: la textura de la skin encuadrada como una foto.
    ///
    /// Una skin de milestone que todavía no ganaste se muestra en **silueta de
    /// tinta** (spec §3.10: el personaje misterioso) — enseñar el arte a color
    /// regalaría la sorpresa del premio. Las que están a la venta **no** van en
    /// silueta: son mercadería, y nadie compra lo que no puede ver.
    private var preview: some View {
        Color.clear
            .frame(width: Self.previewSide, height: Self.previewSide)
            .overlay { art.padding(4) }
            .background(Color("PaletteYellow").opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
            )
    }

    @ViewBuilder private var art: some View {
        if let image = previewImage {
            if isSilhouette {
                image.resizable().renderingMode(.template).scaledToFit()
                    .foregroundStyle(Color("PaletteInk"))
            } else {
                image.resizable().scaledToFit()
            }
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(18)
                .foregroundStyle(Color("PaletteInk").opacity(isSilhouette ? 1 : 0.35))
        }
    }

    /// Mismo criterio que el tablero y la ficha (`PlaceholderRenderer`): una skin
    /// catalogada cuyo arte todavía no existe cae al retrato BASE y no a un
    /// placeholder roto — el catálogo puede shippear antes que el arte.
    private var previewImage: Image? {
        guard let atlas else { return nil }
        if let textureKey = row.textureKey,
           let skinImage = UIArt.characterImage(atlas: atlas, key: textureKey) {
            return skinImage
        }
        guard let baseKey else { return nil }
        return UIArt.characterImage(atlas: atlas, key: baseKey)
    }

    /// Todo lo que no tenés se ve en silueta, también lo que está a la venta.
    ///
    /// Antes sólo la de milestone se ocultaba y la paga se enseñaba a color, que
    /// es regalar justo lo que se quiere vender: las de material se compran por
    /// bundle, así que ver una sola ya saca las ganas de pagar por las 43. La
    /// tienda sí las muestra a color — ahí el arte es el argumento de venta; acá
    /// el argumento es la expectativa.
    private var isSilhouette: Bool {
        switch row.state {
        case .equipped, .owned: false
        case .milestoneLocked, .purchasable, .oroPurchasable: true
        }
    }

    /// El slot de abajo: el único control de la tarjeta, o el badge que explica
    /// por qué no hay ninguno.
    @ViewBuilder private var control: some View {
        switch row.state {
        case .equipped:
            StateBadge(
                text: String(localized: "skins.equipped"),
                systemImage: "checkmark.circle.fill",
                textAlignment: .center,
                muted: false
            )
            .accessibilityHidden(true)
        case .owned:
            ActionPill(
                titleKey: "skins.equip",
                systemImage: "tshirt.fill",
                // El id lleva el id de la skin porque en la grilla todos los
                // botones dicen "Ponérsela": sin esto no hay test de UI que pueda
                // apretar UNO. Es un `String` y no una clave de localización, así
                // que interpolarlo es correcto (la trampa 5 es de
                // `LocalizedStringKey`).
                identifier: "skins.equip.\(row.id)",
                // "Ponérsela" ×3 en la misma grilla no distingue nada: el label
                // hablado nombra la pinta.
                accessibilityLabel: Text("skins.equip.ax \(row.displayName)"),
                action: equip
            )
        case .milestoneLocked(let conditionText):
            StateBadge(text: conditionText, systemImage: "lock.fill", textAlignment: .center, muted: true)
                .accessibilityHidden(true)
        case .oroPurchasable(let price):
            PricePill(
                text: String(price),
                currency: .oro,
                affordable: oroBalance >= price,
                identifier: "skins.buyOro.\(row.id)",
                accessibilityPurpose: Text("skins.buy.ax \(row.displayName)"),
                action: buyWithOro
            )
        case .purchasable(let productID):
            if let price {
                VStack(spacing: Tokens.s4) {
                    purchasePill(price: price, productID: productID)
                    packCaption
                }
            } else {
                // El precio todavía no llegó (StoreKit sin contestar, sin red, o
                // la app corriendo sin configuración de tienda).
                //
                // ⚠️ **Sin candado a propósito.** El candado es el glifo de "no
                // podés", y acá sí podés: lo que falta es el precio, no el
                // permiso. Ponerlo era la mitad de la mentira que este badge
                // arregla; la otra mitad era el texto de "no está a la venta".
                StateBadge(
                    text: String(localized: "skins.price.unavailable"),
                    textAlignment: .center,
                    muted: true
                )
                .accessibilityHidden(true)
            }
        }
    }

    private func purchasePill(price: String, productID: String) -> some View {
        // Mismo namespace que la tienda (`store.buy.<productId>`): es la
        // misma compra por el mismo camino, y los tests de la tienda
        // buscan ese identifier.
        PricePill(
            text: price,
            currency: .money,
            affordable: true,
            identifier: "store.buy.\(productID)",
            // El nombre de la pinta va por el propósito del componente y
            // no por un `.accessibilityLabel` de afuera: pisar la etiqueta
            // entera se llevaba puesto el precio, y en una grilla de tres
            // cápsulas iguales el botón tiene que decir las dos cosas
            // —qué pinta y cuánto sale—. La misma cápsula, en la tienda,
            // dice lo mismo.
            accessibilityPurpose: Text("skins.buy.ax \(row.displayName)"),
            action: buy
        )
    }

    private var packCaptionText: String? {
        row.packSize.map { String(localized: "skins.pack.caption \($0)") }
    }

    @ViewBuilder private var packCaption: some View {
        if let packCaptionText {
            Text(verbatim: packCaptionText)
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.65))
                .accessibilityHidden(true)
        }
    }

    /// El valor de la tarjeta es **su estado o lo que cuesta**, igual que en
    /// FisuJobs. Es lo que leen los tests: el runner corre la app en inglés
    /// (trampa 6), así que comparan el valor de dos tarjetas entre sí en vez de
    /// asertar sobre texto traducido.
    private var axValue: String {
        switch row.state {
        case .equipped: String(localized: "skins.equipped")
        case .owned: String(localized: "skins.owned")
        case .milestoneLocked(let conditionText): conditionText
        // Sin precio, el valor dice que falta el precio — no que la skin no se
        // venda. Es el mismo texto que muestra el badge, por la misma razón.
        case .oroPurchasable(let price): String(price)
        case .purchasable:
            [price ?? String(localized: "skins.price.unavailable"), packCaptionText]
                .compactMap { $0 }
                .joined(separator: ". ")
        }
    }
}
