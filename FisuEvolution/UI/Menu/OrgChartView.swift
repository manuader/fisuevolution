import SwiftUI

/// **Organigrama** — la cadena de mando de la torre (spec §10.1): vos arriba y,
/// abajo, los 43 tipos del juego ordenados por tier descendente y agrupados por
/// piso.
///
/// La pantalla tiene UNA obligación que no es de datos: **tiene que leerse como
/// un organigrama**, no como una lista más. Lo que la hace leerse así son los
/// conectores de tinta —el tronco vertical que baja de nodo en nodo— y la
/// **bifurcación**: los cuatro juniors y los cuatro seniors de carrera comparten
/// tier, así que se dibujan como hermanos en una fila, colgando de la misma
/// barra horizontal. Es el único lugar del juego donde la elección de carrera se
/// ve como lo que es: el árbol abriéndose en cuatro y volviéndose a juntar.
///
/// Lo que la vista **no** hace: no le pregunta nada al estado más allá de
/// `orgChartRows`, `prestigePreview` y `statsSnapshot`. Cada nodo viene con el
/// nombre, el retrato, el conteo, el piso y el "lo viste" ya resueltos.
struct OrgChartView: View {
    @Environment(GameState.self) private var gameState
    /// Cierra la HOJA entera. No puede ser `@Environment(\.dismiss)`: esta vista
    /// está empujada y ahí `dismiss` desapila (ver el docstring de `MenuView`).
    let close: () -> Void

    var body: some View {
        // Las dos cosas que mueven el organigrama, leídas explícitamente para que
        // la pantalla se invalide contra ELLAS: contratar y fusionar mueven los
        // ×N (`boardVersion`) y reencarnar mueve el multiplicador del jefe
        // (`effectsVersion`). `player` es `@ObservationIgnored`, así que el tick
        // de 60 Hz no recompone esto.
        let _ = gameState.boardVersion
        let _ = gameState.effectsVersion

        // ⚠️ UNA lectura por evaluación del body: `orgChartRows` cotiza los 43
        // tipos de cero cada vez que se lee. Leerlo adentro del `ForEach` lo
        // multiplicaría por 43.
        //
        // ⚠️ El nivel de prestigio sale de `prestigeLevelText` y **no** de
        // `statsSnapshot`: la foto entera arrastra `towerIncomePerSecondText`,
        // que se mueve solo mientras la torre produce, y con eso los 43 nodos se
        // rearmarían cada vez que el income abreviado cambia de dígito.
        let floors = Self.groups(of: gameState.orgChartRows)
        let multiplier = gameState.prestigePreview.multiplierBeforeText
        let prestigeLevel = gameState.prestigeLevelText

        ScrollView {
            // `VStack` y no `LazyVStack`: los 43 nodos tienen que existir en el
            // árbol de accesibilidad sin scrollear (la T11 midió que la lista
            // perezosa se lleva puestos los identifiers de lo que todavía no se
            // dibujó). Los retratos se decodifican una sola vez —`UIArt` cachea
            // el `UIImage`—, así que el costo es el del primer armado.
            VStack(spacing: 0) {
                BossCard(multiplierText: multiplier, prestigeLevelText: prestigeLevel)
                ForEach(floors) { floor in
                    Connector()
                    SectionHeader(verbatim: TowerNaming.floorName(for: floor.floorID))
                        .padding(.bottom, Tokens.s4)
                    ForEach(floor.tiers) { group in
                        if group.rows.count == 1, let row = group.rows.first {
                            Connector()
                            NodeCard(row: row)
                        } else {
                            ForkConnector(columns: group.rows.count)
                            HStack(alignment: .top, spacing: Tokens.s8) {
                                ForEach(group.rows) { row in
                                    SiblingNodeCard(row: row)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, MenuView.panelInset)
            .padding(.top, Tokens.s4)
            .padding(.bottom, Tokens.s24)
        }
        .background { PanelBackground(art: "panel_config") }
        .safeAreaInset(edge: .top) { header }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color("PaletteCream"), for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ArtCloseButton(action: close) }
        }
    }

    // MARK: Cabecera

    /// El título, fijo arriba de la cadena. Fondo crema OPACO por lo mismo que
    /// en las otras cinco hojas: sin él los nodos desfilan por detrás del título.
    private var header: some View {
        PanelTitleBanner(titleKey: "orgchart.title")
            .padding(.top, 6)
            .padding(.bottom, Tokens.s8)
            .frame(maxWidth: .infinity)
            .background {
                Color("PaletteCream")
                    .shadow(color: .black.opacity(0.14), radius: 5, y: 3)
            }
    }

    // MARK: Agrupado

    /// Un piso con sus tiers; un tier con sus hermanos.
    private struct FloorGroup: Identifiable {
        let floorID: String
        var tiers: [TierGroup]
        var id: String { floorID }
    }

    private struct TierGroup: Identifiable {
        let tier: Int
        var rows: [OrgChartRow]
        var id: Int { tier }
    }

    /// Parte las filas —**ya ordenadas** por `orgChartRows`— en pisos y tiers,
    /// respetando el orden que trae el estado en vez de reordenar (mismo
    /// criterio que `FisuJobsView.groups`).
    ///
    /// Agrupa por RACHA y no con `Dictionary(grouping:)`: el orden por tier
    /// descendente es la mitad del diseño de la pantalla y un diccionario lo
    /// pierde. Si algún día el criterio cambiara y un piso apareciera dos veces,
    /// esto dibuja su encabezado dos veces: es feo pero honesto.
    private static func groups(of rows: [OrgChartRow]) -> [FloorGroup] {
        var floors: [FloorGroup] = []
        for row in rows {
            if var floor = floors.last, floor.floorID == row.floorID {
                if var tier = floor.tiers.last, tier.tier == row.tier {
                    tier.rows.append(row)
                    floor.tiers[floor.tiers.count - 1] = tier
                } else {
                    floor.tiers.append(TierGroup(tier: row.tier, rows: [row]))
                }
                floors[floors.count - 1] = floor
            } else {
                floors.append(FloorGroup(floorID: row.floorID, tiers: [TierGroup(tier: row.tier, rows: [row])]))
            }
        }
        return floors
    }
}

// MARK: - Conectores

/// El tramo de tronco entre dos nodos: 2 pt de tinta, centrado.
private struct Connector: View {
    var height: CGFloat = 14

    var body: some View {
        Rectangle()
            .fill(Color("PaletteInk").opacity(0.7))
            .frame(width: 2, height: height)
            .accessibilityHidden(true)
    }
}

/// La bifurcación: tronco, barra horizontal y una patita por hermano.
///
/// La barra arranca en el CENTRO de la primera columna y termina en el de la
/// última, que es como se dibuja un organigrama de verdad; una barra de borde a
/// borde asomaría por fuera de las tarjetas de los extremos. Se consigue sin
/// `GeometryReader` partiendo la fila en `2 × columnas` celdas iguales y dejando
/// transparentes la primera y la última: cada celda mide media columna, así que
/// los extremos transparentes son exactamente los dos medios sobrantes.
private struct ForkConnector: View {
    let columns: Int

    var body: some View {
        VStack(spacing: 0) {
            Connector(height: 10)
            HStack(spacing: 0) {
                ForEach(0..<(columns * 2), id: \.self) { index in
                    Rectangle()
                        .fill(index == 0 || index == columns * 2 - 1
                              ? Color.clear
                              : Color("PaletteInk").opacity(0.7))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 0) {
                ForEach(0..<columns, id: \.self) { _ in
                    Connector(height: 10)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - El Jefe

/// La tarjeta del jugador, arriba de todo: el único nodo del organigrama que no
/// sale de `tiers.json`.
///
/// Va en amarillo destacado y con corona porque es **el ancla de la lectura**:
/// sin una cabeza distinta del resto, la pantalla vuelve a ser una lista de
/// personajes ordenada al revés. Lo que muestra son las dos cosas que el jugador
/// aporta a la torre y que ningún empleado tiene: el multiplicador global y
/// cuántas veces reencarnó.
private struct BossCard: View {
    let multiplierText: String
    let prestigeLevelText: String

    var body: some View {
        GameCard(style: .highlighted(Color("PaletteYellow"))) {
            HStack(spacing: Tokens.s12) {
                crown
                VStack(alignment: .leading, spacing: 2) {
                    Text("orgchart.boss.title")
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("orgchart.boss.subtitle")
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 3) {
                    stat("orgchart.boss.multiplier", "×" + multiplierText)
                    stat("orgchart.boss.prestige", prestigeLevelText)
                }
            }
            // Todo lo de adentro ya viaja en el resumen de abajo; sin taparlo,
            // la tarjeta serían cinco paradas de VoiceOver diciendo lo mismo.
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("orgchart.boss")
        .accessibilityLabel(Text("orgchart.boss.title"))
        .accessibilityValue(Text(verbatim: "×\(multiplierText)"))
    }

    /// La corona. Es un SF Symbol y no un icono del atlas porque no hay ninguno
    /// que diga "el jefe": el mismo criterio que el `mappin` del piso en
    /// `FisuJobsView`. El plato es el de `JobPortrait` para que el jefe se lea
    /// como un retrato más de la misma columna.
    private var crown: some View {
        Color.clear
            .frame(width: 56, height: 56)
            .overlay {
                Image(systemName: "crown.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Color("PaletteYellow"))
                    .shadow(color: Color("PaletteInk").opacity(0.9), radius: 0.5)
            }
            .background(Color("PaletteYellow").opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color("PaletteInk"), lineWidth: 2)
            )
    }

    private func stat(_ titleKey: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(titleKey)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color("PaletteInk").opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(verbatim: value)
                .font(Tokens.body)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - Nodos

/// Cómo se dibuja un nodo según lo que sabés de él. Los tres estados existen
/// porque decir "no lo tenés" y "no sabés que existe" con el mismo gris borraría
/// justamente lo que el organigrama muestra: hasta dónde llegaste.
private enum NodeTone {
    /// Visto y con gente adentro.
    case staffed
    /// Visto, pero hoy no tenés ninguno. Se apaga; no desaparece.
    case empty
    /// Nunca visto en esta run: silueta y "???" (RF-03, no espoilear la cadena).
    case unknown

    init(_ row: OrgChartRow) {
        if !row.seen { self = .unknown } else if row.count == 0 { self = .empty } else { self = .staffed }
    }

    var isDim: Bool { self != .staffed }
}

/// Un nodo solo en su tier: la fila ancha del tronco.
private struct NodeCard: View {
    let row: OrgChartRow

    private var tone: NodeTone { NodeTone(row) }

    var body: some View {
        Group {
            if tone.isDim {
                GameCard(style: .locked) { content }
            } else {
                GameCard(style: .normal) { content }
            }
        }
        // ⚠️ Acá el elemento de estado va **sobre** la tarjeta y no en una capa
        // de fondo como en `FisuJobsView`: la diferencia es que un nodo del
        // organigrama **no tiene ningún control adentro**. El truco de la capa
        // trasera existe para no tragarse un botón (trampa 9a); sin botón, poner
        // el elemento arriba con `children: .ignore` deja UNA parada limpia y se
        // ahorra tapar a mano cada texto.
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("orgchart.node.\(row.id)")
        .accessibilityLabel(Text(verbatim: OrgChartNodeText.label(row)))
        .accessibilityValue(Text(verbatim: OrgChartNodeText.value(row)))
    }

    private var content: some View {
        HStack(spacing: Tokens.s12) {
            NodePortrait(faceKey: row.faceKey, side: 52, asSilhouette: tone == .unknown)
            Text(verbatim: row.displayName)
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            CountBadge(count: row.count, dimmed: tone.isDim)
        }
    }
}

/// Uno de los hermanos de un tier bifurcado (los cuatro juniors, los cuatro
/// seniors). Es vertical y compacto porque van cuatro por renglón: con la
/// anatomía ancha del tronco, cada columna quedaría en ~78 pt y el nombre no
/// entraría ni al 50% de escala.
private struct SiblingNodeCard: View {
    let row: OrgChartRow

    private var tone: NodeTone { NodeTone(row) }

    var body: some View {
        Group {
            if tone.isDim {
                GameCard(style: .locked) { content }
            } else {
                GameCard(style: .normal) { content }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("orgchart.node.\(row.id)")
        .accessibilityLabel(Text(verbatim: OrgChartNodeText.label(row)))
        .accessibilityValue(Text(verbatim: OrgChartNodeText.value(row)))
    }

    private var content: some View {
        VStack(spacing: 5) {
            NodePortrait(faceKey: row.faceKey, side: 42, asSilhouette: tone == .unknown)
            Text(verbatim: row.displayName)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity)
            CountBadge(count: row.count, dimmed: tone.isDim)
        }
    }
}

/// Los dos textos hablados de un nodo, en un solo lugar para que el ancho y el
/// compacto no puedan divergir.
private enum OrgChartNodeText {
    /// ⚠️ Para lo nunca visto **no** se usa `row.displayName`: es "???", que
    /// VoiceOver lee como puntuación (o directamente se come). En pantalla sigue
    /// diciendo "???" —el misterio es el diseño—; lo que cambia es cómo suena.
    /// Mismo criterio que `jobs.ax.confidential` en FisuJobs.
    static func label(_ row: OrgChartRow) -> String {
        row.seen ? row.displayName : String(localized: "orgchart.ax.unknown")
    }

    /// El valor de la fila es **cuántos tenés**, y sale del MISMO componente que
    /// lo dibuja: si el badge cambiara el signo, el valor lo acompañaría solo.
    ///
    /// Va `@MainActor` porque `CountBadge` conforma `View` y en Swift 6 eso le
    /// aisla todos los miembros; se llama desde el `body`, que ya está en el
    /// main actor, así que no cuesta un salto.
    @MainActor
    static func value(_ row: OrgChartRow) -> String {
        CountBadge(count: row.count, dimmed: false).text
    }
}

/// El retrato de un nodo, con el mismo encuadre que `JobPortrait` en FisuJobs:
/// plato amarillo tenue, esquinas redondeadas y borde ink. La silueta de tinta
/// plena para lo nunca visto es la misma de la ficha de personaje y del
/// Customization Shop: `renderingMode(.template)` sobre el mismo PNG.
private struct NodePortrait: View {
    let faceKey: String
    let side: CGFloat
    let asSilhouette: Bool

    var body: some View {
        Color.clear
            .frame(width: side, height: side)
            .overlay { face.padding(3) }
            .background(Color("PaletteYellow").opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color("PaletteInk"), lineWidth: 2)
            )
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
                .padding(side * 0.18)
                .foregroundStyle(Color("PaletteInk").opacity(asSilhouette ? 1 : 0.35))
        }
    }
}
