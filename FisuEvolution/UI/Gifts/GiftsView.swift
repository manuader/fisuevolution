import SwiftUI

/// **Regalos** — todo lo que el juego te da sin cobrarte (spec §9), en un solo
/// panel y en tres secciones: la **racha diaria**, los **boosts** gratis con
/// cooldown y los **videos**.
///
/// Reemplaza a `BonusView`, que era una `List` de sistema con dos secciones. Lo
/// que cambió es el idioma visual —`GameCard`, `SectionHeader`, `ActionPill`,
/// `StateBadge`, `Tokens`, el marco `panel_reward` medido— y que ahora la
/// pantalla **muestra el calendario**, que antes sólo existía como popup del día
/// que te tocaba. Los identifiers de los controles son los mismos que ejercen
/// `BonusHUDUITests`.
///
/// ⚠️ **El calendario no tiene botón de reclamar, y es a propósito.** El daily se
/// cobra solo (bootstrap y vuelta a foreground, `GameState.swift:436` y `604`);
/// un segundo camino de claim desde acá abriría la carrera que el spec descarta.
/// La tira informa: qué llevás cobrado y qué viene.
///
/// ⚠️ **Un solo timer de 1 Hz para toda la pantalla** (patrón `ActiveBonusBar`).
/// Los cooldowns NO viajan en ninguna proyección publicada: `boostRows` y
/// `rewardRows` se computan al leerse, así que basta con que `now` avance una vez
/// por segundo para que las tres secciones se recalculen juntas.
struct GiftsView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    let adsProvider: any AdsProvider

    /// Qué video se está mirando ahora (su fila muestra el spinner en lugar del
    /// botón). `nil` = ninguno.
    @State private var watchingRewardId: String?
    /// Lo que pagó el cofre del Asado, si se activó en esta visita.
    @State private var chestAmount: Double?
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Margen lateral del contenido. **Medido sobre el arte**, con el mismo
    /// método que `FisuJobsView` (30 pt contra `panel_store`), `UpgradesView`
    /// (40 contra `panel_upgrades`) y `FloorMapView` (36 contra `panel_dialog`):
    /// el 9-slice dibuja los bordes a tamaño natural, así que el píxel `x` del
    /// PNG cae en `x / (anchoPx / 200)` puntos del destino. Sondeando
    /// `panel_reward@3x.png` (640², escala 3,2) en su franja recta, el marco es
    /// **doble**: trazo de tinta de 30,6 a 32,8 pt, un hueco claro, y una segunda
    /// línea de 35,9 a 37,8. Recién a 38 pt la columna entra adentro de las dos.
    /// Con menos, las tarjetas —crema opaco— pintan por encima del marco y el
    /// arte del panel se ve cortado. Si `panel_reward` se re-exporta, se vuelve
    /// a medir.
    private static let panelInset: CGFloat = 38

    var body: some View {
        // `effectsVersion` sube al activar un boost o acreditar un video: es lo
        // que hace que la fila pase de botón a cuenta regresiva sin cerrar la
        // hoja. `now` avanza una vez por segundo y es lo que hace tictaquear las
        // tres secciones. Los dos se leen explícitamente para que el body dependa
        // de ELLOS y no de `PlayerState`, que la UI nunca observa.
        let _ = gameState.effectsVersion
        let _ = now

        // ⚠️ UNA lectura por evaluación del body: las tres proyecciones se
        // computan de cero cada vez que se leen (los seis boosts consultan el
        // cooldown, los cuatro videos también). Leerlas adentro del `ForEach` las
        // multiplicaría por su cantidad de filas.
        let days = gameState.dailyCalendar
        let boosts = gameState.boostRows
        let rewards = gameState.rewardRows

        NavigationStack {
            ScrollView {
                // `VStack` y no `LazyVStack`: son 11 tarjetas contadas y tienen
                // que existir en el árbol de accesibilidad sin scrollear. La fila
                // del video que ejerce `BonusHUDUITests` vive abajo de los seis
                // boosts, y con la lista perezosa de `BonusView` el test tenía
                // que deslizar hasta cuatro veces para encontrarla.
                VStack(spacing: Tokens.s12) {
                    section("gifts.section.daily")
                    DailyStrip(days: days)

                    section("gifts.section.boosts")
                    ForEach(boosts) { row in
                        BoostCard(row: row) { chestAmount = gameState.activateBoost(id: row.id) }
                    }
                    if let chestAmount {
                        chestBanner(chestAmount)
                    }

                    section("gifts.section.videos")
                    ForEach(rewards) { row in
                        VideoCard(row: row, isWatching: watchingRewardId == row.id) {
                            watch(rewardId: row.id)
                        }
                    }
                }
                .padding(.horizontal, Self.panelInset)
                .padding(.top, Tokens.s4)
                .padding(.bottom, Tokens.s24)
            }
            .background { PanelBackground(art: "panel_reward") }
            .safeAreaInset(edge: .top) { header }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            // La barra de navegación aparece recién al scrollear y de fábrica lo
            // hace con el material blanco del sistema: contra el marco del panel
            // quedaba una banda blanca cruzándolo. Pintada de crema empalma con
            // la cabecera de abajo y las dos se leen como UNA barra fija (mismo
            // criterio que `FisuJobsView`, `UpgradesView` y `FloorMapView`).
            .toolbarBackground(Color("PaletteCream"), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
            .onReceive(timer) { now = $0 }
        }
    }

    // MARK: Cabecera

    /// El moño y el título, fijos arriba de la lista.
    ///
    /// ⚠️ **El fondo crema opaco no es decoración.** Un `safeAreaInset` recorta el
    /// área segura pero el contenido del scroll sigue pasando POR DEBAJO: con la
    /// banda transparente las tarjetas desfilan a través del título. Es el
    /// defecto que el HANDOFF §8 anota para "el título flotante de los paneles" y
    /// acá se corta igual que en las otras cuatro pantallas.
    private var header: some View {
        HStack(spacing: Tokens.s8) {
            // El mismo moño del tab que abre esta hoja: el viaje de un lado al
            // otro se lee como uno solo. Es decoración —el título ya dice
            // "Regalos"—, así que se esconde de VoiceOver.
            GameIcon(artKey: "ui_tab_gifts", size: 34) { VectorTabGiftsIcon() }
                .accessibilityHidden(true)
            PanelTitleBanner(titleKey: "gifts.title")
        }
        .padding(.horizontal, Self.panelInset)
        .padding(.top, 6)
        .padding(.bottom, Tokens.s12)
        .frame(maxWidth: .infinity)
        .background {
            Color("PaletteCream")
                .shadow(color: .black.opacity(0.14), radius: 5, y: 3)
        }
    }

    private func section(_ titleKey: LocalizedStringKey) -> some View {
        SectionHeader(titleKey)
            .frame(maxWidth: .infinity)
            .padding(.top, Tokens.s8)
    }

    /// Lo que pagó el cofre del Asado. Aparece bajo los boosts y se queda hasta
    /// cerrar la hoja: es un premio de una vez y el jugador tiene que poder
    /// volver a mirarlo.
    private func chestBanner(_ amount: Double) -> some View {
        let text = String(localized: "gifts.chest \(CoinFormatter.string(from: amount))")
        return GameCard(style: .highlighted(Color("PaletteYellow"))) {
            HStack(spacing: Tokens.s8) {
                CoinIcon(size: 26)
                Text(verbatim: text)
                    .font(Tokens.title)
                    .monospacedDigit()
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
    }

    // MARK: El video

    /// El mismo flujo que tenía `BonusView`: se pide el video, y si el jugador se
    /// lo bancó entero, el estado acredita el premio.
    ///
    /// El guard reemplaza al `.disabled` que tenía el botón: el design system no
    /// deshabilita controles —el dimming del sistema deja el texto ilegible— así
    /// que el botón sigue tappable y el segundo toque no hace nada.
    private func watch(rewardId: String) {
        guard watchingRewardId == nil, adsProvider.isRewardedReady else { return }
        watchingRewardId = rewardId
        Task {
            let earned = await adsProvider.showRewarded()
            if earned {
                gameState.applyRewardedReward(rewardId: rewardId)
            }
            watchingRewardId = nil
        }
    }
}

// MARK: - Formato de los cooldowns

/// El reloj de las dos secciones. Vive suelto y no en cada tarjeta porque los
/// boosts y los videos tienen que contar IGUAL: son cuentas regresivas de la
/// misma pantalla, y dos formatos distintos se leen como dos relojes distintos.
private enum Cooldown {
    /// "4h 0m", "12m 3s", "8s".
    static func text(_ remaining: TimeInterval) -> String {
        let total = Int(remaining.rounded(.up))
        if total >= 3600 { return "\(total / 3600)h \(total % 3600 / 60)m" }
        if total >= 60 { return "\(total / 60)m \(total % 60)s" }
        return "\(total)s"
    }

    /// Cuánto del cooldown ya pasó, 0…1. El aro **se llena hacia el momento en
    /// que vuelve a estar disponible** (al revés que el de `ActiveBonusBar`, que
    /// se vacía mientras el bonus se consume): acá lo que se espera es que se
    /// complete.
    static func progress(remaining: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0 else { return 1 }
        return min(1, max(0, 1 - remaining / total))
    }
}

// MARK: - La tira del calendario

/// Los siete días del ciclo, en una tira. Cobrados con tilde, el que está en
/// juego resaltado en amarillo —el mismo acento que marca el piso actual en el
/// ascensor— y el séptimo con el moño del cofre.
///
/// No hay botón de reclamar: ver el ⚠️ de `GiftsView`.
private struct DailyStrip: View {
    let days: [GameState.DailyDayRow]

    var body: some View {
        GameCard(style: .normal) {
            VStack(spacing: Tokens.s8) {
                HStack(spacing: Tokens.s4) {
                    ForEach(days) { day in
                        DayCell(day: day)
                    }
                }
                // Por qué no hay botón, dicho en la pantalla y no sólo en el
                // código: sin esta línea, "el día 3 está resaltado y no puedo
                // tocarlo" se lee como un bug.
                Text("gifts.daily.note")
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Una casilla del calendario. **No es un control** —el claim es automático—, así
/// que se colapsa en un solo elemento de estado con su identifier: la casilla no
/// contiene ningún botón que un elemento contenedor pudiera borrar del árbol
/// (trampa 9a), y colapsarla es lo que la vuelve UNA parada de VoiceOver en vez
/// de tres textos sueltos.
private struct DayCell: View {
    let day: GameState.DailyDayRow

    private var fill: Color {
        if day.isToday { return Color("PaletteYellow") }
        if day.isClaimed { return Color("PaletteCream") }
        return Color("PaletteInk").opacity(0.06)
    }

    private var stateKey: LocalizedStringKey {
        if day.isClaimed { return "gifts.daily.state.claimed" }
        if day.isToday { return "gifts.daily.state.today" }
        return "gifts.daily.state.pending"
    }

    var body: some View {
        VStack(spacing: 2) {
            // El número del día. `verbatim` porque es un dígito y no una frase:
            // meterlo en un `LocalizedStringKey` armaría la clave "%lld"
            // (trampa 5). Mismo criterio que el botón de piso del ascensor.
            Text(verbatim: "\(day.id)")
                .font(Tokens.caption)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk").opacity(day.isClaimed || day.isToday ? 1 : 0.55))
                // Siete casillas se reparten ~40 pt cada una en un iPhone 16 Pro
                // y ~36 en el más angosto: con el cuerpo de texto grande de
                // Dynamic Type el dígito no entra y se trunca a nada. Se encoge,
                // como todo lo demás de la pantalla.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            glyph
                .frame(width: 20, height: 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.s8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            Color("PaletteInk").opacity(day.isToday || day.isClaimed ? 1 : 0.35),
                            lineWidth: day.isToday ? 3 : 2
                        )
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("gifts.daily.day\(day.id)")
        // El nombre del día ("Día 3: Quincena Chica") ya es la mitad del chiste;
        // para el séptimo se agrega el cofre, que es lo ÚNICO que lo distingue
        // en pantalla y se perdería al colapsar la casilla.
        .accessibilityLabel(
            day.isChest
                ? Text(LocalizedStringKey(day.titleKey)) + Text(verbatim: ", ") + Text("gifts.daily.chest")
                : Text(LocalizedStringKey(day.titleKey))
        )
        .accessibilityValue(Text(stateKey))
    }

    /// Qué se ve adentro de la casilla: el tilde si ya se cobró, el moño en el
    /// día del cofre, y la moneda en los demás.
    @ViewBuilder private var glyph: some View {
        if day.isClaimed {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color("PaletteGreen"))
                .shadow(color: Color("PaletteInk").opacity(0.5), radius: 0.5)
        } else if day.isChest {
            GameIcon(artKey: "ui_tab_gifts", size: 20) { VectorTabGiftsIcon() }
        } else {
            CoinIcon(size: 18)
                .opacity(day.isToday ? 1 : 0.6)
        }
    }
}

// MARK: - La fila de boost

/// Un boost: su arte, qué hace, el chiste, y a la derecha el botón, la cuenta
/// regresiva o el candado con el piso que lo abre.
///
/// Los tres identifiers —`bonus.activate.<id>`, `bonus.cooldown.<id>` y
/// `bonus.locked.<id>`— vienen de `BonusView` y los ejerce `BonusHUDUITests`:
/// cambiarlos rompe el test que prueba que el contador queda en el HUD.
private struct BoostCard: View {
    let row: GameState.BoostRow
    let activate: () -> Void

    /// Ancho fijo del riel derecho, por lo mismo que en `FisuJobsView`: sin él,
    /// "Activar" y "12m 3s" dejan la columna de datos arrancando en un lugar
    /// distinto en cada fila y la lista se ve desalineada de arriba abajo.
    private static let railWidth: CGFloat = 96

    private var isCooling: Bool { row.isUnlocked && row.cooldownRemaining > 0 }

    var body: some View {
        Group {
            // El boost que todavía no está se ve, pero apagado: es la zanahoria.
            if row.isUnlocked {
                GameCard(style: .normal) { content }
            } else {
                GameCard(style: .locked) { content }
            }
        }
        // ⚠️ El elemento de estado va en una capa VACÍA y **detrás** (patrón T8):
        // si el trío `children: .ignore` + id + label se pusiera sobre la tarjeta
        // entera, se tragaría al botón —un elemento de accesibilidad que CONTIENE
        // un control lo borra del árbol (trampa 9a)— y `bonus.activate.<id>`
        // dejaría de existir. Atrás, el botón queda por delante y los dos se ven:
        // la fila informa, el riel actúa.
        .background {
            Color.clear
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("gifts.row.\(row.id)")
                .accessibilityLabel(Text(verbatim: axLabel))
                .allowsHitTesting(false)
        }
    }

    /// ⚠️ **El chiste va a lo ancho de la tarjeta y no en la columna del medio**,
    /// y no es una decisión de gusto: medido contra una captura, la columna que
    /// queda entre el plato y el riel son **126 pt** (los mismos que en
    /// `FisuJobsView`), y ahí adentro los seis flavors se cortaban TODOS con
    /// puntos suspensivos — "…the crew delivers: hiring is…", "…y gana be…".
    /// FisuJobs no trunca nunca, y una fila que corta el remate del chiste se lee
    /// como una pantalla a medio terminar. A lo ancho son ~330 pt y entran.
    ///
    /// El precio son ~15 pt más de alto por fila. Se paga: es el mismo criterio
    /// con el que FisuJobs acepta que un nombre largo le sume un renglón a su
    /// tarjeta ("se lee como un aviso más largo, no como un error").
    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Tokens.s12) {
                BoostGlyph(
                    iconKey: row.iconKey,
                    progress: isCooling
                        ? Cooldown.progress(remaining: row.cooldownRemaining, total: row.cooldownTotal)
                        : nil
                )
                info
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Todo lo que dice esta columna ya lo dice `axLabel`, que es
                    // el resumen de la fila. Sin esto se anuncia dos veces y
                    // encima partido en tres paradas.
                    .accessibilityHidden(true)
                rail
            }
            Text(verbatim: row.flavorText)
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteInk").opacity(0.6))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: row.displayName)
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: row.effectText)
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk").opacity(0.9))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// El riel derecho: los tres estados del boost, siempre en el mismo lugar y
    /// con el mismo ancho.
    ///
    /// Los badges **no** se esconden de VoiceOver —a diferencia de `FisuJobsView`,
    /// donde el badge repite el valor de la fila—: acá el resumen de la fila NO
    /// lleva el estado, así que este es el único lugar donde "está en cooldown" o
    /// "se abre en el callejón" se dice. Son dos paradas por fila: la que informa
    /// y la que actúa (o la que explica por qué no se puede).
    @ViewBuilder private var rail: some View {
        Group {
            if !row.isUnlocked {
                StateBadge(
                    text: String(localized: "bonus.locked \(row.unlockFloorName ?? "")"),
                    systemImage: "lock.fill",
                    muted: true
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("bonus.locked.\(row.id)")
            } else if row.cooldownRemaining > 0 {
                StateBadge(
                    text: Cooldown.text(row.cooldownRemaining),
                    systemImage: "clock.fill",
                    muted: true
                )
                .monospacedDigit()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("bonus.cooldown.\(row.id)")
            } else {
                ActionPill(
                    titleKey: "bonus.activate",
                    systemImage: "bolt.fill",
                    tint: Color("PaletteOrange"),
                    identifier: "bonus.activate.\(row.id)",
                    // "Activar" a secas es lo que dicen los seis botones: sin el
                    // nombre, VoiceOver no distingue cuál se está por apretar.
                    accessibilityLabel: Text("bonus.activate") + Text(verbatim: ", \(row.displayName)"),
                    action: activate
                )
            }
        }
        .frame(width: Self.railWidth, alignment: .trailing)
    }

    /// Lo que VoiceOver anuncia como nombre de la fila: los tres renglones que
    /// quedaron tapados, en el orden en que se leen.
    private var axLabel: String {
        [row.displayName, row.effectText, row.flavorText].joined(separator: ", ")
    }
}

/// El arte del boost en su plato, con el aro del cooldown alrededor.
///
/// El plato copia el encuadre del retrato de `FisuJobsView` —plato amarillo
/// tenue, esquinas redondeadas, borde ink— para que las dos pantallas se lean
/// como el mismo juego. El aro sigue el contorno del plato en vez de ser un
/// círculo: un círculo alrededor de un cuadrado redondeado queda flotando.
private struct BoostGlyph: View {
    let iconKey: String
    /// Cuánto del cooldown ya pasó (0…1), o `nil` si el boost está disponible.
    let progress: Double?

    private static let side: CGFloat = 56
    private static let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        Color.clear
            .frame(width: Self.side, height: Self.side)
            .overlay { glyph.padding(6).opacity(progress == nil ? 1 : 0.45) }
            .background(Color("PaletteYellow").opacity(0.35))
            .clipShape(Self.shape)
            .overlay(Self.shape.strokeBorder(Color("PaletteInk"), lineWidth: 2))
            .overlay {
                if let progress {
                    Self.shape
                        .trim(from: 0, to: progress)
                        .stroke(Color("PaletteBlue"), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        // Sin animación: el aro se mueve una vez por segundo con
                        // el timer de la pantalla, y un tween encima de un salto
                        // de 1/1800 no se ve.
                        .padding(1.75)
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder private var glyph: some View {
        if let image = UIArt.image(iconKey) {
            image.resizable().scaledToFit()
        } else {
            // Un boost sin su arte en el atlas sigue teniendo fila: el manifest
            // cae a placeholder, no a nada (mismo criterio que `ActiveBonusBar`).
            Image(systemName: "bolt.fill")
                .resizable()
                .scaledToFit()
                .padding(8)
                .foregroundStyle(Color("PaletteOrange"))
        }
    }
}

// MARK: - La fila de video

/// Un video: qué te da, y a la derecha el botón de play o cuánto falta para que
/// vuelva a ofrecerse. `ads.watch.<id>` y `ads.cooldown.<id>` vienen de
/// `BonusView` y los ejerce `BonusHUDUITests`.
private struct VideoCard: View {
    let row: GameState.RewardRow
    let isWatching: Bool
    let watch: () -> Void

    private static let railWidth: CGFloat = 96

    var body: some View {
        GameCard(style: .normal) {
            HStack(spacing: Tokens.s12) {
                ScreenGlyph(
                    progress: row.cooldownRemaining > 0
                        ? Cooldown.progress(remaining: row.cooldownRemaining, total: row.cooldownTotal)
                        : nil
                )
                info
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
                rail
            }
        }
        .background {
            Color.clear
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("gifts.row.\(row.id)")
                .accessibilityLabel(Text(verbatim: axLabel))
                .allowsHitTesting(false)
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(row.titleKey))
                .font(Tokens.title)
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            // Lo que la fila NO decía hasta la T13: qué te da exactamente. El
            // número sale del config, no de la copy (ver `rewardText`).
            Text(verbatim: row.rewardText)
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk").opacity(0.9))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var rail: some View {
        Group {
            if row.cooldownRemaining > 0 {
                StateBadge(
                    text: Cooldown.text(row.cooldownRemaining),
                    systemImage: "clock.fill",
                    muted: true
                )
                .monospacedDigit()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("ads.cooldown.\(row.id)")
            } else if isWatching {
                // Mientras corre el video la fila no ofrece nada: el botón se va
                // y queda el spinner. Es lo que reemplaza al `.disabled`, que
                // dejaba el texto ilegible.
                ProgressView()
                    .tint(Color("PaletteInk"))
            } else {
                ActionPill(
                    titleKey: "ads.watch",
                    systemImage: "play.fill",
                    tint: Color("PaletteGreen"),
                    identifier: "ads.watch.\(row.id)",
                    accessibilityLabel: Text("ads.watch")
                        + Text(verbatim: ", \(GameState.localized(row.titleKey))"),
                    action: watch
                )
            }
        }
        .frame(width: Self.railWidth, alignment: .trailing)
    }

    private var axLabel: String {
        [GameState.localized(row.titleKey), row.rewardText].joined(separator: ", ")
    }
}

/// La "pantalla" del video: el mismo plato que el arte de los boosts, con el
/// triángulo de play adentro, para que las dos secciones tengan el mismo ritmo.
private struct ScreenGlyph: View {
    let progress: Double?

    private static let side: CGFloat = 56
    private static let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        Color.clear
            .frame(width: Self.side, height: Self.side)
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color("PaletteInk").opacity(progress == nil ? 0.8 : 0.35))
            }
            .background(Color("PaletteBlue").opacity(0.28))
            .clipShape(Self.shape)
            .overlay(Self.shape.strokeBorder(Color("PaletteInk"), lineWidth: 2))
            .overlay {
                if let progress {
                    Self.shape
                        .trim(from: 0, to: progress)
                        .stroke(Color("PaletteBlue"), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .padding(1.75)
                }
            }
            .accessibilityHidden(true)
    }
}
