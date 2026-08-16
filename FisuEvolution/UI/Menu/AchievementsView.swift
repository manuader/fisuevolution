import SwiftUI

/// **Logros** — los 39 del catálogo (spec §10.3), con su trofeo, su progreso y
/// el botón de cobrar.
///
/// ⚠️ **El orden de la pantalla NO es el del catálogo, y esa es la decisión de
/// diseño.** La pantalla tiene gameplay —cobrar es un acto del jugador— así que
/// lo primero que tiene que verse es **lo que hay para cobrar**; después lo que
/// está en camino, con lo más cerca arriba; y al final lo ya cobrado, que es
/// historial. Con el orden del catálogo, un logro conseguido y sin cobrar puede
/// caer en la fila 31 y no lo ve nadie: el toast dura 2,4 s y es todo el aviso
/// que hay. Los empates dentro de cada sección respetan el orden del catálogo
/// (el `sorted` de Swift no es estable, así que el índice va como desempate
/// explícito).
///
/// Lo que la vista no hace: no mide progreso ni resuelve claves. `titleText`,
/// `descText` y `rewardText` llegan resueltos desde `achievementRows` — armar
/// `LocalizedStringKey("ach.\(id).title")` acá sería la trampa 5 del HANDOFF.
struct AchievementsView: View {
    @Environment(GameState.self) private var gameState
    /// Cierra la HOJA entera (ver el docstring de `MenuView`: acá `dismiss`
    /// desapilaría en vez de cerrar).
    let close: () -> Void

    var body: some View {
        // `effectsVersion` sube al cobrar un logro: es lo que hace que la fila
        // pase de "Cobrar" a "Cobrado" y salte a la última sección sin cerrar la
        // pantalla. `boardVersion` cubre lo que se consigue jugando de fondo.
        let _ = gameState.effectsVersion
        let _ = gameState.boardVersion

        // ⚠️ UNA lectura por evaluación del body: `achievementRows` mide los 39
        // gatillos de cero cada vez que se lee.
        let groups = Self.groups(of: gameState.achievementRows)
        let claimed = groups.first { $0.kind == .claimed }?.rows.count ?? 0
        let total = groups.reduce(0) { $0 + $1.rows.count }

        ScrollView {
            // ⚠️ `VStack` y no `LazyVStack`: las 39 filas tienen que existir en
            // el árbol de accesibilidad sin scrollear. La T11 midió que con la
            // lista perezosa el `accessibilityHidden` de lo que todavía no se
            // dibujó no se aplica y los identifiers se pierden, y `MenuUITests`
            // cobra un logro sin deslizar.
            VStack(spacing: Tokens.s12) {
                ForEach(groups) { group in
                    SectionHeader(group.kind.titleKey)
                        .padding(.top, Tokens.s4)
                    ForEach(group.rows) { row in
                        AchievementCard(row: row) { gameState.claimAchievement(id: row.id) }
                    }
                }
            }
            .padding(.horizontal, MenuView.panelInset)
            .padding(.top, Tokens.s4)
            .padding(.bottom, Tokens.s24)
        }
        .background { PanelBackground(art: "panel_config") }
        .safeAreaInset(edge: .top) { header(claimed: claimed, total: total) }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color("PaletteCream"), for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ArtCloseButton(action: close) }
        }
    }

    // MARK: Cabecera

    /// El título y el marcador, fijos arriba de la lista. Fondo crema OPACO: sin
    /// él las tarjetas desfilan por detrás del título.
    private func header(claimed: Int, total: Int) -> some View {
        // ⚠️ El contador se arma como `String` ANTES de entrar en la clave. Con
        // `Text("ach.header.count \(claimed)/\(total)")`, `LocalizedStringKey`
        // interpola los dos `Int` como `%lld` y busca la clave
        // `ach.header.count %lld/%lld`, que no existe: en pantalla se leería el
        // formato crudo. Es la trampa 5 del HANDOFF, que ya mordió dos veces.
        let countText = "\(claimed)/\(total)"
        return VStack(spacing: Tokens.s4) {
            PanelTitleBanner(titleKey: "ach.screen.title")
            Text("ach.header.count \(countText)")
                .font(Tokens.caption)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk").opacity(0.75))
                .lineLimit(1)
        }
        .padding(.top, 6)
        .padding(.bottom, Tokens.s8)
        .frame(maxWidth: .infinity)
        .background {
            Color("PaletteCream")
                .shadow(color: .black.opacity(0.14), radius: 5, y: 3)
        }
    }

    // MARK: Secciones

    private enum SectionKind: Int {
        case claimable
        case pending
        case claimed

        var titleKey: LocalizedStringKey {
            switch self {
            case .claimable: "ach.section.claimable"
            case .pending: "ach.section.pending"
            case .claimed: "ach.section.claimed"
            }
        }
    }

    /// No se llama `Section` a propósito: adentro de una vista, ese nombre
    /// sombrea a `SwiftUI.Section` y el próximo que quiera una de verdad va a
    /// pelearse con el compilador sin entender por qué.
    private struct AchievementGroup: Identifiable {
        let kind: SectionKind
        let rows: [AchievementRow]
        var id: Int { kind.rawValue }
    }

    /// Reparte las 39 filas en las tres secciones y ordena cada una.
    ///
    /// Una sección vacía **no se dibuja**: al principio no hay nada cobrado y un
    /// encabezado "Ya los cobraste" sin nada debajo se lee como un error.
    private static func groups(of rows: [AchievementRow]) -> [AchievementGroup] {
        let indexed = Array(rows.enumerated())
        let claimable = indexed.filter { $0.element.state == .unlocked }.map(\.element)
        let claimed = indexed.filter { $0.element.state == .claimed }.map(\.element)
        // Lo más cerca de conseguirse, arriba. El índice del catálogo desempata
        // porque `sorted` no es estable y hay decenas de logros clavados en 0.
        let pending = indexed
            .filter { $0.element.state == .locked }
            .sorted { lhs, rhs in
                lhs.element.progress == rhs.element.progress
                    ? lhs.offset < rhs.offset
                    : lhs.element.progress > rhs.element.progress
            }
            .map(\.element)

        return [
            AchievementGroup(kind: .claimable, rows: claimable),
            AchievementGroup(kind: .pending, rows: pending),
            AchievementGroup(kind: .claimed, rows: claimed)
        ]
        .filter { !$0.rows.isEmpty }
    }
}

// MARK: - Tarjeta

/// Una fila de logro. Dibuja los tres estados con la misma anatomía —trofeo,
/// datos y un slot a la derecha— para que la lista se lea como una columna y no
/// como tres diseños distintos.
private struct AchievementCard: View {
    let row: AchievementRow
    let claim: () -> Void

    /// Ancho fijo del riel derecho, el mismo que FisuJobs: sin él, "Cobrar" y
    /// "Cobrado" dejan los datos de cada tarjeta arrancando en una columna
    /// distinta y la lista se ve desalineada de arriba abajo.
    private static let railWidth: CGFloat = 96

    /// El catálogo nombra el metal (`trophy_bronze`); la vista lo mapea al
    /// icono. Un metal que no exista cae a bronce en vez de dejar el hueco
    /// (mismo criterio que el toast en `RootView`).
    private var tier: VectorTrophyIcon.Tier {
        VectorTrophyIcon.Tier(rawValue: row.icon.replacingOccurrences(of: "trophy_", with: "")) ?? .bronze
    }

    var body: some View {
        Group {
            switch row.state {
            // Plata sobre la mesa: es lo único de la pantalla que pide una
            // acción, y el halo verde es el mismo que marca la mejor
            // contratación en FisuJobs.
            case .unlocked: GameCard(style: .highlighted(Color("PaletteGreen"))) { content }
            case .claimed: GameCard(style: .normal) { content }
            // Desaturado: es el estado "todavía no". Con 39 filas, que las
            // conseguidas se distingan de un vistazo vale más que el color de
            // los trofeos que no tenés.
            case .locked: GameCard(style: .locked) { content }
            }
        }
        // ⚠️ El elemento de estado va en una capa VACÍA y **detrás** (patrón
        // `jobs.row.<id>` en FisuJobs): la fila desbloqueada tiene un botón
        // adentro, y un elemento de accesibilidad que CONTIENE un control lo
        // borra del árbol — `ach.claim.<id>` dejaría de existir (trampa 9a).
        // Atrás, el botón queda por delante y los dos se ven: la fila informa,
        // el botón cobra.
        //
        // ⚠️⚠️ Y por eso el `children: .ignore` no alcanza solo: ignora a los
        // hijos DE ESTA CAPA, que no tiene ninguno. La tarjeta es su HERMANA en
        // el `ZStack` del `.background`, así que sus textos siguen siendo
        // elementos por derecho propio y hay que taparlos a mano (`content`).
        .background {
            Color.clear
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("ach.row.\(row.id)")
                .accessibilityLabel(Text(verbatim: axLabel))
                .accessibilityValue(Text(verbatim: Self.axValue(row.state)))
                .allowsHitTesting(false)
        }
    }

    private var content: some View {
        HStack(spacing: Tokens.s12) {
            GameIcon(artKey: tier.artKey, size: 42) { VectorTrophyIcon(tier: tier) }
                .accessibilityHidden(true)
            info
                .frame(maxWidth: .infinity, alignment: .leading)
                // Todo lo que dice esta columna ya lo dice `axLabel`, que es el
                // resumen de la fila. Sin esto se anuncia dos veces y encima
                // partido en cuatro paradas, ×39 filas.
                .accessibilityHidden(true)
            rail
        }
    }

    // MARK: Columna de datos

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: row.titleText)
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: row.descText)
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            if row.state == .locked {
                ProgressBar(progress: row.progress, tint: Color("PaletteOrange"), labelText: progressText)
                    .padding(.top, 2)
            }
            reward
        }
    }

    /// El premio, con el mismo glifo de trofeo chiquito para las tres filas: es
    /// el dato que convierte "un logro más" en "esto me paga".
    private var reward: some View {
        HStack(spacing: 4) {
            Image(systemName: "gift.fill")
                .font(.system(size: 10, weight: .black))
            Text(verbatim: row.rewardText)
                .font(Tokens.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(Color("PaletteInk").opacity(row.state == .locked ? 0.55 : 0.8))
    }

    /// "34%". Se redondea **hacia abajo** a propósito: con el redondeo normal, un
    /// logro al 99,6% muestra "100%" y sigue cerrado, que es la clase de
    /// contradicción que hace que el jugador deje de creerle a la barra.
    private var progressText: String {
        "\(Int((row.progress * 100).rounded(.down)))%"
    }

    // MARK: Riel derecho

    @ViewBuilder private var rail: some View {
        switch row.state {
        case .unlocked:
            // El id lleva el id del logro porque los 39 botones dicen lo mismo:
            // sin esto no hay test de UI que pueda apretar UNO. Es un `String` y
            // no una clave, así que interpolarlo es correcto (la trampa 5 es de
            // `LocalizedStringKey`). Mismo patrón que `jobs.hire.<id>`.
            ActionPill(
                titleKey: "ach.claim",
                systemImage: "hand.tap.fill",
                identifier: "ach.claim.\(row.id)",
                accessibilityLabel: Text(verbatim: "\(String(localized: "ach.claim")): \(row.titleText)"),
                action: claim
            )
            .frame(width: Self.railWidth, alignment: .trailing)
        case .claimed:
            // Dice exactamente lo que ya publica el valor de la fila, así que se
            // tapa — a diferencia del `ActionPill`, que es el control.
            StateBadge(
                text: String(localized: "ach.state.claimed"),
                systemImage: "checkmark.circle.fill",
                muted: true
            )
            .accessibilityHidden(true)
            .frame(width: Self.railWidth, alignment: .trailing)
        case .locked:
            // Sin riel: la barra de progreso se queda con el ancho y se lee de
            // lejos. Un badge de "bloqueado" repetido 30 veces sólo agregaría
            // ruido a lo que la barra ya dice.
            EmptyView()
        }
    }

    // MARK: Textos derivados

    /// Lo que VoiceOver anuncia como NOMBRE de la fila: el logro entero en una
    /// sola parada. Lleva el progreso sólo cuando hay barra, porque desde que
    /// `info` está tapada este resumen es el único lugar donde ese dato existe.
    private var axLabel: String {
        var parts = [row.titleText, row.descText]
        if row.state == .locked { parts.append(progressText) }
        parts.append(row.rewardText)
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// El valor de la fila es su ESTADO, y va sin traducir a propósito: es lo
    /// que asserta `MenuUITests` para comprobar que cobrar cambió algo, y el
    /// runner corre la app en inglés (trampa 6 del HANDOFF). Un valor traducido
    /// haría pasar el test por la razón equivocada.
    static func axValue(_ state: AchievementRow.State) -> String {
        switch state {
        case .locked: "locked"
        case .unlocked: "unlocked"
        case .claimed: "claimed"
        }
    }
}
