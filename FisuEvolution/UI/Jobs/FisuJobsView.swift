import SwiftUI

/// **FisuJobs** — la tienda de contratación por personaje (spec §5.1).
///
/// La parodia manda sobre la estética: es un **portal de empleo**. El logo con
/// el corte bicolor, las secciones que se llaman "Vacantes abiertas" y
/// "Búsquedas confidenciales", el retrato encuadrado como foto de CV y la barra
/// tachada de los avisos confidenciales existen para que la pantalla se lea como
/// un aviso clasificado y no como una lista de precios. Lo que se compra igual
/// es un personaje.
///
/// Lo que la vista **no** hace: no le pregunta nada al estado más allá de
/// `jobRows`. Cada `JobRow` viene con el nombre, el retrato, el ingreso, el
/// conteo, el precio y el estado ya resueltos, así que acá sólo se decide cómo
/// se dibuja cada estado.
struct FisuJobsView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    /// Margen lateral de la lista. **Medido sobre una captura**, no elegido: el
    /// marco de madera de `panel_store` tiene su poste entre los 23 y los 31 pt
    /// de cada borde, así que con los 16 pt de la escala de `Tokens` las tarjetas
    /// le pasaban por encima y el poste sólo asomaba en los huecos entre fila y
    /// fila. A 30 pt la columna entra adentro del marco y el arte del panel se
    /// lee entero. Es un valor con nombre y no un literal suelto justamente
    /// porque depende del arte: si `panel_store` se re-exporta, se vuelve a medir.
    private static let panelInset: CGFloat = 30

    var body: some View {
        // Las tres cosas que mueven una fila, leídas explícitamente para que la
        // hoja se invalide contra ELLAS (patrón `UpgradesView`): el precio y el
        // "podés pagarlo" salen de `coinsText`, el "piso lleno" de
        // `boardVersion` y el ingreso de `effectsVersion`. `player` es
        // `@ObservationIgnored`, así que el tick de 60 Hz —que lo escribe cada
        // frame— NO recompone esta pantalla por más que `jobRows` lo lea.
        let _ = gameState.coinsText
        let _ = gameState.boardVersion
        let _ = gameState.effectsVersion

        // ⚠️ UNA sola lectura por evaluación del body. `jobRows` cotiza los 43
        // tipos concretos de cero cada vez que se lee: leerlo dentro del
        // `ForEach` multiplicaría eso por 43.
        let rows = gameState.jobRows
        // El mejor que HOY podés pagar, destacado con el halo verde. Es el
        // foco de la pantalla —lo que el Animal Shop resuelve con la fila
        // grande— y sale gratis: las filas ya vienen ordenadas por tier
        // descendente dentro de lo contratable, así que el primero que se puede
        // pagar es el mejor que se puede pagar.
        let recommended = rows.first { $0.state == .hirable && $0.affordable }?.id

        NavigationStack {
            ScrollView {
                // ⚠️ `VStack` y no `LazyVStack`: las 43 tarjetas tienen que
                // existir en el árbol de accesibilidad sin scrollear (es lo que
                // ejercen `BottomMenuUITests`, `TutorialUITests` y
                // `BoardGestureUITests`, ninguno de los cuales scrollea). Los
                // retratos se decodifican una sola vez —`UIArt` cachea el
                // `UIImage`—, así que el costo de construirlas todas es el del
                // primer armado y no el de cada invalidación.
                VStack(spacing: Tokens.s12) {
                    ForEach(Self.groups(of: rows)) { group in
                        SectionHeader(group.section.titleKey)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Tokens.s8)
                        ForEach(group.rows) { row in
                            JobCard(row: row, recommended: row.id == recommended) {
                                gameState.hireCharacter(typeId: row.id)
                            }
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
            // quedaba una banda blanca cruzando el panel. Pintada de crema
            // empalma con la cabecera de abajo y las dos se leen como UNA sola
            // barra fija. No se fuerza `.visible`: en reposo sigue transparente y
            // el toldo del `panel_store` se ve entero, que es la mitad de la
            // gracia de la pantalla.
            .toolbarBackground(Color("PaletteCream"), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
    }

    // MARK: Cabecera

    /// El logo y la bajada, fijos arriba de la lista.
    ///
    /// ⚠️ **El fondo opaco no es decoración: sin él la cabecera no tapa nada.**
    /// Un `safeAreaInset` recorta el área segura pero el contenido del scroll
    /// sigue pasando POR DEBAJO, así que con la banda transparente las tarjetas
    /// desfilaban a través de la bajada y asomaban a los costados de la cápsula
    /// del logo. Es el mismo defecto que el HANDOFF §8 anota para "el título
    /// flotante de los paneles" —el de todas las hojas—, y acá se corta.
    ///
    /// La banda va de borde a borde y no recortada al ancho de la columna, aun
    /// sabiendo que así tapa los postes del marco en su franja: el fondo de la
    /// barra de navegación —que es de sistema— es full width y no se puede
    /// recortar, y una banda angosta debajo de una ancha da un escalón. Enteras
    /// y del mismo crema, las dos se leen como UNA cabecera fija.
    private var header: some View {
        VStack(spacing: Tokens.s4) {
            FisuJobsWordmark()
            Text("jobs.subtitle")
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Tokens.s24)
        }
        .padding(.top, 6)
        .padding(.bottom, Tokens.s12)
        .frame(maxWidth: .infinity)
        .background {
            Color("PaletteCream")
                .shadow(color: .black.opacity(0.14), radius: 5, y: 3)
        }
    }

    // MARK: Secciones

    /// Parte las filas —**ya ordenadas** por `jobRows`— en las tres secciones
    /// del portal, respetando el orden que trae el estado en vez de reordenar.
    ///
    /// Si algún día el criterio de orden cambiara y un grupo apareciera dos
    /// veces, esto dibuja su encabezado dos veces: es feo pero honesto. La
    /// alternativa —agrupar con `Dictionary(grouping:)`— perdería el orden por
    /// tier, que es la mitad del diseño de la pantalla.
    private static func groups(of rows: [JobRow]) -> [JobGroup] {
        var groups: [JobGroup] = []
        for row in rows {
            let section = JobSection(row.state)
            if var last = groups.last, last.section == section {
                last.rows.append(row)
                groups[groups.count - 1] = last
            } else {
                groups.append(JobGroup(section: section, rows: [row]))
            }
        }
        return groups
    }
}

// MARK: - Secciones del portal

/// Las tres secciones, en el orden en que `jobRows` las entrega.
private enum JobSection: Int {
    /// Lo que se puede comprar hoy — incluye el piso lleno, que es un problema
    /// de espacio y no de permiso.
    case open
    /// Visto, pero el piso no está abierto o el gate lo tapa.
    case closed
    /// Nunca visto en esta run: ni el nombre se muestra (RF-03).
    case confidential

    init(_ state: JobRow.State) {
        switch state {
        case .hirable, .floorFull: self = .open
        case .gated, .lockedFloor: self = .closed
        case .unseen: self = .confidential
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .open: "jobs.section.open"
        case .closed: "jobs.section.closed"
        case .confidential: "jobs.section.confidential"
        }
    }
}

private struct JobGroup: Identifiable {
    let section: JobSection
    var rows: [JobRow]
    var id: Int { section.rawValue }
}

// MARK: - Logo

/// El logo del portal: maletín + "Fisu" en tinta y "Jobs" en azul, dentro de la
/// misma cápsula crema con borde ink que usa `PanelTitleBanner`.
///
/// ⚠️ **No usa `PanelTitleBanner` aunque copie su cápsula**, y no es capricho:
/// el banner dibuja UN `Text` de un color, y el corte bicolor es justamente lo
/// que hace que esto se lea como un logo de portal de empleo y no como el título
/// de una hoja más. Poner además el banner dejaría la palabra "FisuJobs" escrita
/// dos veces a 60 pt de distancia. `jobs.title` sigue siendo la clave del
/// nombre: se usa como etiqueta de accesibilidad, porque un logo partido en dos
/// `Text` se lee "Fisu, Jobs" con VoiceOver.
private struct FisuJobsWordmark: View {
    var body: some View {
        HStack(spacing: Tokens.s8) {
            BriefcaseGlyph()
                .frame(width: 26, height: 26)
            HStack(spacing: 0) {
                Text(verbatim: "Fisu").foregroundStyle(Color("PaletteInk"))
                Text(verbatim: "Jobs").foregroundStyle(Color("PaletteBlue"))
            }
            .font(Tokens.display)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, Tokens.s8)
        .background(
            Capsule().fill(Color("PaletteCream"))
                .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("jobs.title"))
    }
}

/// Maletín del logo. Vive en el lienzo 100×100 de `GameIcons` para hablar el
/// mismo idioma que los iconos de la barra inferior (relleno plano de paleta +
/// contorno ink), en vez de traer un SF Symbol de otro dibujo.
private struct BriefcaseGlyph: View {
    var body: some View {
        IconCanvas {
            ZStack {
                // La manija va primero para que el cuerpo la tape por abajo y
                // quede saliendo de la tapa, no flotando encima.
                IconPath { path in
                    path.addRoundedRect(
                        in: CGRect(x: 33, y: 14, width: 34, height: 34),
                        cornerSize: CGSize(width: 10, height: 10)
                    )
                }
                .stroke(
                    IconSpec.ink,
                    style: StrokeStyle(lineWidth: IconSpec.stroke, lineCap: .round, lineJoin: .round)
                )
                IconPath { path in
                    path.addRoundedRect(
                        in: CGRect(x: 10, y: 36, width: 80, height: 52),
                        cornerSize: CGSize(width: 12, height: 12)
                    )
                }
                .inked(Color("PaletteOrange"))
                // El cierre: la franja clara que parte el maletín al medio.
                IconPath { path in
                    path.addRoundedRect(
                        in: CGRect(x: 42, y: 54, width: 16, height: 14),
                        cornerSize: CGSize(width: 4, height: 4)
                    )
                }
                .inked(Color("PaletteCream"), lineWidth: IconSpec.detail)
            }
        }
    }
}

// MARK: - Tarjeta

/// Una fila del portal. Dibuja los cinco estados de `JobRow.State` con la misma
/// anatomía —retrato, datos, y un slot a la derecha— para que la lista se lea
/// como una columna y no como cinco diseños distintos.
private struct JobCard: View {
    let row: JobRow
    /// El mejor que se puede pagar ahora: borde y halo verdes.
    let recommended: Bool
    let hire: () -> Void

    /// Ancho fijo del riel derecho. Sin él, el precio de "50" y el de "1,2M"
    /// dejan los datos de cada tarjeta arrancando en una columna distinta y la
    /// lista se ve desalineada de arriba abajo.
    ///
    /// 96 y no más: es el `minWidth` del `PricePill` (92) más el aire justo para
    /// que no toque el borde. Cada punto de más acá es un punto menos para el
    /// nombre, que es la columna que sufre — medido: con el riel en 108, "Chofer
    /// de App" se partía en dos renglones sin necesidad.
    private static let railWidth: CGFloat = 96

    private var isUnseen: Bool { row.state == .unseen }

    /// Los tres tonos de tarjeta.
    ///
    /// ⚠️ Existe porque `GameCard.Style` está **anidado en un tipo genérico**:
    /// `GameCard<A>.Style` y `GameCard<B>.Style` son tipos distintos, así que el
    /// estilo no se puede guardar en una propiedad con anotación de tipo sin
    /// nombrar el contenido. Se elige el tono acá y el `switch` se hace en el
    /// punto donde el contenido ya está fijado.
    private enum Tone {
        case plain
        case recommended
        case locked
    }

    private var tone: Tone {
        switch row.state {
        case .hirable: recommended ? .recommended : .plain
        // Piso lleno NO es una tarjeta bloqueada: el personaje está disponible y
        // lo único que falta es hacer lugar fusionando. Desaturarla lo mandaría
        // al mismo cajón visual que un piso que todavía no existe.
        case .floorFull: .plain
        case .gated, .lockedFloor, .unseen: .locked
        }
    }

    var body: some View {
        Group {
            switch tone {
            case .plain: GameCard(style: .normal) { content }
            case .recommended: GameCard(style: .highlighted(Color("PaletteGreen"))) { content }
            case .locked: GameCard(style: .locked) { content }
            }
        }
        // ⚠️ El elemento de estado va en una capa VACÍA y **detrás** (patrón
        // `board.units` en `RootView` y del retrato de `UpgradesView`). Si el
        // trío `children: .ignore` + id + value se pusiera sobre la tarjeta
        // entera, se tragaría al `PricePill`: un elemento de accesibilidad que
        // CONTIENE un control lo borra del árbol y `jobs.hire.<id>` dejaría de
        // existir (trampa 9a). Atrás, el botón queda por delante y los dos se
        // ven: la fila informa, el botón cobra.
        .background {
            Color.clear
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("jobs.row.\(row.id)")
                .accessibilityLabel(Text(verbatim: axLabel))
                .accessibilityValue(Text(verbatim: axValue))
                .allowsHitTesting(false)
        }
    }

    /// La anatomía común a los cinco estados: retrato, datos y riel derecho.
    ///
    /// El ancho de la columna de datos sale de un `maxWidth: .infinity` y **no**
    /// de un `Spacer` entre ella y el riel: el `Spacer` sumaba sus dos espaciados
    /// del `HStack` a los suyos y se comía 20 pt que el nombre necesita.
    private var content: some View {
        HStack(spacing: Tokens.s12) {
            JobPortrait(faceKey: row.faceKey, asSilhouette: isUnseen)
            info
                .frame(maxWidth: .infinity, alignment: .leading)
            rail
        }
    }

    // MARK: Columna de datos

    @ViewBuilder private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            // ⚠️ **Dos renglones y no uno.** Con `lineLimit(1)` el nombre se
            // encoge hasta el `minimumScaleFactor` y **después trunca**: en la
            // captura, "Empleado de Fast Food" —el más largo del catálogo, el
            // mismo que pinea `UpgradesFaceUITests`— salía "Empleado de Fas…",
            // que no nombra a nadie. Para que entrara en un renglón hacía falta
            // bajar la escala a ~0,5 y dejarlo a 10 pt al lado de nombres de 20:
            // partirlo en dos es lo que conserva el cuerpo tipográfico. Las filas
            // con nombre largo quedan un renglón más altas, y en un portal de
            // avisos eso se lee como un aviso más largo, no como un error.
            Text(verbatim: row.displayName)
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            if isUnseen {
                // El renglón tachado del aviso confidencial: ocupa el lugar del
                // ingreso sin decir cuánto rinde. **La proyección trae el dato**
                // —`incomeText` está resuelto igual—; no dibujarlo es la
                // decisión: una tarjeta misteriosa que publica su rendimiento
                // deja de ser misteriosa y le regala al jugador la pista de qué
                // tan lejos está el próximo salto.
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color("PaletteInk").opacity(0.35))
                    .frame(width: 96, height: 9)
                    .padding(.vertical, 3)
            } else {
                Text(verbatim: row.incomeText)
                    .font(Tokens.body)
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk").opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            if !isUnseen {
                HStack(spacing: 6) {
                    floorTag
                    Text("jobs.hired_count \(String(row.hiredCount))")
                        .font(Tokens.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color("PaletteInk").opacity(0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    /// El piso destino, como el campo "ubicación" de un aviso.
    private var floorTag: some View {
        HStack(spacing: 3) {
            Image(systemName: "mappin")
                .font(.system(size: 9, weight: .bold))
            Text(TowerNaming.floorNameKey(for: row.floorID))
                .font(Tokens.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color("PaletteInk"))
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color("PaletteYellow").opacity(0.55))
                .overlay(Capsule().strokeBorder(Color("PaletteInk").opacity(0.55), lineWidth: 1.5))
        )
    }

    // MARK: Riel derecho

    @ViewBuilder private var rail: some View {
        Group {
            if case .hirable = row.state {
                // El id lleva el typeId porque con 43 filas todos los botones
                // dicen un monto y varios dicen el MISMO monto: sin esto no hay
                // test de UI que pueda apretar UNO. Es un `String` y no una
                // clave de localización, así que interpolarlo es correcto (la
                // trampa 5 es de `LocalizedStringKey`). Mismo patrón que
                // `store.buy.<productId>` en `StoreView`.
                PricePill(
                    text: row.costText,
                    currency: .coins,
                    affordable: row.affordable,
                    identifier: "jobs.hire.\(row.id)",
                    action: hire
                )
            } else if let stateText {
                JobStateBadge(text: stateText, locked: row.state != .floorFull)
            }
        }
        .frame(width: Self.railWidth, alignment: .trailing)
    }

    // MARK: Textos derivados

    /// El mensaje del estado, ya resuelto a `String` **una sola vez**: lo dibuja
    /// el badge y lo lee el valor de accesibilidad, así que no pueden divergir.
    ///
    /// ⚠️ Los payloads de `gated` y `lockedFloor` son el NOMBRE del piso ya
    /// resuelto, no una clave (lo avisa el docstring de `JobRow`). Se interpolan
    /// como ARGUMENTO dentro de una clave propia —`jobs.state.gated %@`—, que es
    /// lo único que el catálogo resuelve; envolverlos en `LocalizedStringKey`
    /// sería la trampa 5.
    private var stateText: String? {
        switch row.state {
        case .hirable: nil
        case .floorFull: String(localized: "jobs.state.full")
        case .gated(let aboveFloorName): String(localized: "jobs.state.gated \(aboveFloorName)")
        case .lockedFloor(let floorName): String(localized: "jobs.state.locked \(floorName)")
        case .unseen: String(localized: "jobs.state.unseen")
        }
    }

    private var axLabel: String {
        guard !isUnseen else { return row.displayName }
        return [
            row.displayName,
            row.incomeText,
            String(localized: "jobs.hired_count \(String(row.hiredCount))")
        ].joined(separator: ", ")
    }

    /// El valor de la fila es **lo que cuesta o por qué no se puede**.
    ///
    /// Para una fila contratable es el precio pelado, y ahí está la gracia para
    /// los tests: el precio crece con cada compra (growth del piso), así que
    /// leer este valor antes y después de contratar prueba que la curva se
    /// movió — **sin asertar sobre texto traducido**, que es la trampa 6 (el
    /// runner corre la app en inglés).
    private var axValue: String { stateText ?? row.costText }
}

// MARK: - Retrato

/// El retrato, encuadrado como la foto de un CV: plato tenue, esquinas
/// redondeadas y borde ink.
///
/// La silueta de tinta plena para lo nunca visto es la misma de la ficha de
/// personaje (`CharacterSheetView`): `renderingMode(.template)` sobre el mismo
/// PNG. Y el fallback cuando la clave no está en el manifest es un CV sin foto,
/// que en este contexto es exactamente lo que corresponde.
private struct JobPortrait: View {
    let faceKey: String
    let asSilhouette: Bool

    private static let side: CGFloat = 72

    var body: some View {
        Color.clear
            .frame(width: Self.side, height: Self.side)
            .overlay { face.padding(3) }
            .background(Color("PaletteYellow").opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color("PaletteInk"), lineWidth: 2)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder private var face: some View {
        if let image = UIArt.image(faceKey) {
            if asSilhouette {
                image
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Color("PaletteInk"))
            } else {
                image.resizable().scaledToFit()
            }
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(12)
                .foregroundStyle(Color("PaletteInk").opacity(asSilhouette ? 1 : 0.35))
        }
    }
}

// MARK: - Badge de estado

/// Lo que ocupa el lugar del precio cuando la fila no es una oferta. Cápsula
/// crema con borde ink; `locked` le suma el candado y apaga el texto.
///
/// El texto llega ya resuelto (`String`) y no como clave: los mensajes de
/// `gated`/`locked` llevan adentro el nombre del piso, que el estado interpola.
private struct JobStateBadge: View {
    let text: String
    let locked: Bool

    var body: some View {
        HStack(spacing: 4) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .black))
            }
            Text(verbatim: text)
                .font(Tokens.caption)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
        }
        .foregroundStyle(Color("PaletteInk").opacity(locked ? 0.75 : 1))
        .padding(.horizontal, Tokens.s8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(locked ? Color("PaletteInk").opacity(0.07) : Color("PaletteOrange").opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color("PaletteInk").opacity(locked ? 0.35 : 0.8), lineWidth: 2)
                )
        )
    }
}
