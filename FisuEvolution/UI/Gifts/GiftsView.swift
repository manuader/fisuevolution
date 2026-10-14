import SwiftUI

/// **Regalos** — todo lo que el juego te da sin cobrarte (spec §9), ordenado por
/// **estado** y no por catálogo (E14 C29): arriba «Para cobrar ahora» —una
/// tarjeta grande con lo más valioso que está listo y, debajo, el resto en
/// filas—, después «Pronto» con el reloj como protagonista, «Más adelante» con lo
/// que todavía no se puede, y al final la racha. El orden lo decide `GiftsAgenda`.
///
/// Si no hay nada para cobrar, la cabecera lo dice y muestra lo próximo con su
/// reloj: nunca una página vacía.
///
/// ⚠️ **El calendario no tiene botón de reclamar, y es a propósito.** El daily se
/// cobra solo (bootstrap y vuelta a foreground, `GameState.swift:436` y `604`);
/// un segundo camino de claim desde acá abriría la carrera que el spec descarta.
/// La tira informa: qué llevás cobrado y qué viene. Su explicación larga vive
/// detrás del «?».
///
/// ⚠️ **Un solo timer de 1 Hz para toda la pantalla** (patrón `ActiveBonusBar`).
/// Los cooldowns NO viajan en ninguna proyección publicada: `boostRows` y
/// `rewardRows` se computan al leerse, así que basta con que `now` avance una vez
/// por segundo para que las secciones se recalculen juntas —y para que una fila
/// pase de «Pronto» a «Para cobrar ahora» sola—. Es también lo que refresca el
/// cofre: `pendingChestCount` sale de `player`, que la UI no observa (el puntito
/// de la pestaña, que no tiene timer, va por la proyección `hasPendingChests`).
///
/// Los identifiers de los controles son los de siempre (`bonus.activate.<id>`,
/// `gifts.chest.open`, `ads.watch.<id>`…): los ejercen `BonusHUDUITests` y
/// `WheelUITests`, y no cambian de lugar al cambiar de sección.
struct GiftsView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.menuPager) private var pager
    let adsProvider: any AdsProvider

    /// Lo que pagó la picada del Asado, si se activó en esta visita.
    @State private var payoutAmount: Double?
    @State private var now = Date()
    /// La ruleta se empuja dentro de esta misma hoja (PLAN-v2 E5: "vive en Regalos").
    @State private var showWheel = false
    /// El popup de «cómo funciona la racha».
    @State private var showStreakHelp = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Hay anuncio cargado para saltear el cooldown de un boost. Se sondea una
    /// vez para toda la pantalla (ver `GiftEntryCard.adReady`).
    @State private var boostAdReady = false

    /// La pantalla de Regalos es la vidriera de los videos, así que al abrirla
    /// se piden las DOS precargas: un rewarded tarda 1-3 s y sin esto el primer
    /// toque del jugador cae sobre un botón sin inventario. (Si igual cae, el
    /// botón espera la carga: ver `RewardedOfferButton`.)
    ///
    /// El sondeo es sólo para el aviso de los boosts en cooldown: `AdsCoordinator`
    /// no es observable a propósito, así que la vista no se enteraría sola de
    /// que el inventario llegó.
    private func preloadVideos() async {
        adsProvider.preloadRewarded(for: .gifts)
        adsProvider.preloadRewarded(for: .boost)
        for _ in 0..<20 {
            if adsProvider.isRewardedReady(for: .boost) {
                boostAdReady = true
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    /// El video de un boost en cooldown pagó: se activa por anuncio y la oferta
    /// vuelve a mirar el inventario (el anuncio se consumió: hasta que llegue
    /// otro, las filas vuelven a mostrar el reloj en vez de una oferta que no
    /// se puede cumplir).
    private func boostWatched(boostId: String) {
        payoutAmount = gameState.activateBoostFromAd(id: boostId)
        boostAdReady = adsProvider.isRewardedReady(for: .boost)
    }

    /// Margen lateral de la columna: el del marco vectorial, publicado por el
    /// componente. Un solo número para las nueve hojas.
    private static let panelInset: CGFloat = WoodPanelBackground.columnInset

    var body: some View {
        // `effectsVersion` sube al activar un boost o acreditar un video: es lo
        // que hace que la fila cambie de sección sin cerrar la hoja. `now` avanza
        // una vez por segundo. Los dos se leen explícitamente para que el body
        // dependa de ELLOS y no de `PlayerState`, que la UI nunca observa.
        let _ = gameState.effectsVersion
        let clock = now.timeIntervalSince1970

        // ⚠️ UNA lectura por evaluación del body: las proyecciones se computan de
        // cero cada vez que se leen.
        let days = gameState.dailyCalendar
        let agenda = GiftsAgenda(
            chests: gameState.pendingChestCount,
            canOpenChest: gameState.canOpenChest,
            wheel: gameState.wheelAvailability(storefrontAllows: false),
            wheelReadyIn: gameState.wheelSpinsReadyAt(now: clock).map { max(0, $0 - clock) },
            boosts: gameState.boostRows,
            videos: gameState.rewardRows
        )
        let firstBoostId = (agenda.ready + agenda.soon + agenda.later).compactMap { entry -> String? in
            if case .boost(let row) = entry { row.id } else { nil }
        }.first

        NavigationStack {
            ScrollView {
                // `VStack` y no `LazyVStack`: son ~13 tarjetas y tienen que existir
                // en el árbol de accesibilidad sin scrollear (la fila del video que
                // ejerce `BonusHUDUITests` vive abajo de los boosts).
                VStack(spacing: Tokens.s12) {
                    readySection(agenda, firstBoostId: firstBoostId)
                    if let payoutAmount {
                        payoutBanner(payoutAmount)
                    }
                    cards(agenda.soon, mode: .soon, titleKey: "gifts.section.soon",
                          firstBoostId: firstBoostId, indexBase: agenda.ready.count + 1)
                    cards(agenda.later, mode: .later, titleKey: "gifts.section.later",
                          firstBoostId: firstBoostId, indexBase: agenda.ready.count + agenda.soon.count + 2)

                    section("gifts.section.daily")
                    DailyStrip(days: days) { showStreakHelp = true }
                        .staggeredAppearance(index: agenda.ready.count + agenda.soon.count + agenda.later.count + 3)
                }
                .padding(.horizontal, Self.panelInset)
                .padding(.top, Tokens.s12)
                .padding(.bottom, Tokens.s24)
            }
            .panelSheet(awning: true) {
                header
            } ornament: {
                // El moño de la referencia, apoyado sobre el TOLDO del marco.
                GiftBowOrnament()
                    .offset(y: 8)
                    .allowsHitTesting(false)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
            .navigationDestination(isPresented: $showWheel) {
                WheelView(close: { dismiss() })
                    // Empujada, la vista pierde el telón transparente de la hoja.
                    .clearNavigationBackdrop()
            }
            // La Ruleta empujada trae su marco: el paginador se suelta del suyo.
            .onChange(of: showWheel) { _, pushed in pager?.lock(pushed) }
            .onReceive(timer) { now = $0 }
            .task { await preloadVideos() }
            .gamePopup(isPresented: $showStreakHelp, dismissOnVeilTap: true) {
                StreakHelpPopup { showStreakHelp = false }
            }
        }
        .tint(Color("PaletteInk"))
    }

    // MARK: Secciones

    /// «Para cobrar ahora»: la tarjeta grande y el resto de lo listo. Sin nada
    /// listo, la cabecera dice que no hay y qué viene.
    @ViewBuilder
    private func readySection(_ agenda: GiftsAgenda, firstBoostId: String?) -> some View {
        if let hero = agenda.hero {
            section("gifts.section.ready")
            card(hero, mode: .hero, firstBoostId: firstBoostId, index: 0)
            ForEach(Array(agenda.rest.enumerated()), id: \.element.id) { offset, entry in
                card(entry, mode: .ready, firstBoostId: firstBoostId, index: offset + 1)
            }
        } else {
            NothingToCollectCard(next: agenda.soon.first)
                .staggeredAppearance(index: 0)
        }
    }

    @ViewBuilder
    private func cards(
        _ entries: [GiftsAgenda.Entry], mode: GiftEntryCard.Mode, titleKey: LocalizedStringKey,
        firstBoostId: String?, indexBase: Int
    ) -> some View {
        if !entries.isEmpty {
            section(titleKey)
            ForEach(Array(entries.enumerated()), id: \.element.id) { offset, entry in
                card(entry, mode: mode, firstBoostId: firstBoostId, index: indexBase + offset)
            }
        }
    }

    private func card(
        _ entry: GiftsAgenda.Entry, mode: GiftEntryCard.Mode, firstBoostId: String?, index: Int
    ) -> some View {
        GiftEntryCard(
            entry: entry,
            mode: mode,
            adReady: boostAdReady,
            openChest: openChest,
            openWheel: { showWheel = true },
            activateBoost: { payoutAmount = gameState.activateBoost(id: $0) },
            boostWatched: { boostWatched(boostId: $0) },
            videoRewarded: { gameState.applyRewardedReward(rewardId: $0) }
        )
        .tutorialAnchor(.giftsChest, when: entry.id == "chest")
        .tutorialAnchor(.giftsBoosts, when: entry.id == firstBoostId)
        .staggeredAppearance(index: index)
    }

    // MARK: Cabecera

    /// El título con su moño, ADENTRO del pergamino, debajo del toldo. Sin
    /// banda opaca: el `panelSheet` recorta el scroll por debajo de la
    /// cabecera, y la banda tapaba el toldo y los postes (2026-08-18).
    private var header: some View {
        // El mismo moño del tab que abre esta hoja, ADENTRO de la cápsula
        // del título. El banner ya lo tapa de VoiceOver: es decoración.
        PanelTitleBanner(
            titleKey: "gifts.title",
            icon: AnyView(GameIcon(artKey: "ui_tab_gifts", size: 26) { VectorTabGiftsIcon() })
        )
    }

    private func section(_ titleKey: LocalizedStringKey) -> some View {
        SectionHeader(titleKey)
            .frame(maxWidth: .infinity)
            .padding(.top, Tokens.s8)
    }

    /// Lo que pagó la picada del Asado. Aparece bajo lo listo y se queda hasta
    /// cerrar la hoja: es un premio de una vez y el jugador tiene que poder
    /// volver a mirarlo.
    private func payoutBanner(_ amount: Double) -> some View {
        let text = GameState.payoutText(amount)
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

    // MARK: El cofre

    /// Abre uno de los cofres que esperan.
    ///
    /// ⚠️ **Cierra la hoja, y no es una cortesía.** La animación del cofre vive
    /// en el `ZStack` de `RootView` y Regalos es un `.sheet`, que se presenta POR
    /// ENCIMA de la vista raíz: sin el `dismiss`, el cofre se abre debajo de esta
    /// pantalla —invisible, y sordo a los toques que la animación necesita para
    /// avanzar—. Y ahí no hay salida: `.chestOpening` no tiene timeout ni es
    /// salteable, así que la cola queda trabada con el HUD apagado.
    ///
    /// ⚠️ Lo único que hace además es gastar el cofre. **No toca `chestReward`
    /// ni `celebrationFinished`**: de cerrar la animación se ocupa
    /// `dismissChestReward()`, el único lugar donde el orden de esas dos líneas
    /// está escrito —y testeado— tal como el contrato lo exige.
    private func openChest() {
        dismiss()
        gameState.openChest()
    }
}

// MARK: - Formato de los cooldowns

/// El reloj de las secciones. Vive suelto y no en cada tarjeta porque los
/// boosts, los videos y la Ruleta tienen que contar IGUAL: son cuentas
/// regresivas de la misma pantalla, y dos formatos distintos se leen como dos
/// relojes distintos.
private enum Cooldown {
    /// "4h 0m", "12m 3s", "8s".
    static func text(_ remaining: TimeInterval) -> String {
        let total = Int(remaining.rounded(.up))
        if total >= 3600 { return "\(total / 3600)h \(total % 3600 / 60)m" }
        if total >= 60 { return "\(total / 60)m \(total % 60)s" }
        return "\(total)s"
    }

    /// Cuánto del cooldown ya pasó, 0…1. El aro **se llena hacia el momento en
    /// que vuelve a estar disponible**: acá lo que se espera es que se complete.
    static func progress(remaining: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0 else { return 1 }
        return min(1, max(0, 1 - remaining / total))
    }
}

// MARK: - Nada para cobrar

/// La cabecera cuando no hay nada listo: lo dice con humor y muestra lo próximo
/// con su reloj.
private struct NothingToCollectCard: View {
    let next: GiftsAgenda.Entry?

    var body: some View {
        GameCard(style: .normal) {
            HStack(spacing: Tokens.s12) {
                GameGlyphView(glyph: .clock, size: 44)
                    .padding(6)
                    .background(Color("PaletteYellow").opacity(0.35))
                    .clipShape(GiftPlate.shape)
                    .overlay(GiftPlate.shape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text("gifts.empty.title")
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(verbatim: line)
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk").opacity(0.75))
                        .lineLimit(3)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gifts.empty")
    }

    private var line: String {
        guard let next, let wait = next.waitSeconds else { return String(localized: "gifts.empty.later") }
        return String(localized: "gifts.empty.next \(Cooldown.text(wait)) \(GiftFacts.name(of: next))")
    }
}

// MARK: - Qué dice cada regalo

/// El texto de cada regalo, en un solo lugar para las tres presentaciones
/// (tarjeta grande, fila y fila con reloj).
@MainActor
private enum GiftFacts {
    /// El nombre ya resuelto.
    static func name(of entry: GiftsAgenda.Entry) -> String {
        switch entry {
        case .chest: String(localized: "daily.prize.chest")
        case .wheel: String(localized: "gifts.wheel.title")
        case .boost(let row): row.displayName
        case .video(let row): GameState.localized(row.titleKey)
        }
    }

    /// Una línea de lo que da (o por qué todavía no).
    static func detail(of entry: GiftsAgenda.Entry, mode: GiftEntryCard.Mode) -> String {
        switch entry {
        case .chest(let count):
            mode == .later
                ? String(localized: "gifts.chest.locked")
                : String(localized: "gifts.chest.count \(count)")
        case .wheel(let availability, _):
            if availability.bonus > 0 { RewardCopy.text("gifts.wheel.bonus", String(availability.bonus)) }
            else if availability.videoLeft > 0 { RewardCopy.text("gifts.wheel.left", String(availability.videoLeft)) }
            else if mode == .soon { String(localized: "gifts.wheel.back") }
            else { String(localized: "gifts.wheel.empty") }
        case .boost(let row):
            row.isUnlocked ? row.effectText : String(localized: "bonus.locked \(row.unlockFloorName ?? "")")
        case .video(let row):
            row.unavailableReason ?? row.rewardText
        }
    }

    /// El resumen hablado de la fila: lo que la pantalla muestra y el chiste
    /// del boost, que ya no ocupa lugar en pantalla.
    static func spoken(of entry: GiftsAgenda.Entry, mode: GiftEntryCard.Mode) -> String {
        var parts = [name(of: entry), detail(of: entry, mode: mode)]
        if case .boost(let row) = entry { parts.append(row.flavorText) }
        return parts.joined(separator: ", ")
    }

    static func art(of entry: GiftsAgenda.Entry) -> RewardKind? {
        switch entry {
        case .chest: .chest
        case .wheel: .wheelSpin
        case .boost, .video: nil
        }
    }
}

// MARK: - El plato del arte

/// El arte de un regalo en su plato, con el aro del cooldown alrededor si corre.
/// Copia el encuadre del retrato de `FisuJobsView` —plato amarillo tenue,
/// esquinas redondeadas, borde marrón— para que las pantallas se lean como el
/// mismo juego.
private struct GiftPlate: View {
    static let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    let entry: GiftsAgenda.Entry
    var side: CGFloat = 56
    /// Cuánto del cooldown ya pasó (0…1), o `nil` si no corre.
    var progress: Double?

    var body: some View {
        Color.clear
            .frame(width: side, height: side)
            .overlay { art.padding(6).opacity(progress == nil ? 1 : 0.55) }
            .background(Color("PaletteYellow").opacity(0.35))
            .clipShape(Self.shape)
            .overlay(Self.shape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
            .overlay {
                if let progress {
                    Self.shape
                        .trim(from: 0, to: progress)
                        .stroke(Color("PaletteBlue"), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        // Sin animación: el aro se mueve una vez por segundo con
                        // el timer de la pantalla.
                        .padding(1.75)
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder private var art: some View {
        switch entry {
        case .chest: RewardArt(kind: .chest)
        case .wheel: RewardArt(kind: .wheelSpin)
        case .video: GameGlyphView(glyph: .video, size: side * 0.6)
        case .boost(let row):
            if let image = UIArt.image(row.iconKey) {
                image.resizable().scaledToFit()
            } else {
                // Un boost sin su arte en el atlas sigue teniendo fila.
                RewardArt(kind: .incomeBoost)
            }
        }
    }
}

// MARK: - La tarjeta de un regalo

/// Un regalo en cualquiera de sus tres estados: **listo** (un botón de la casa;
/// el primero de la lista va en grande), **pronto** (el reloj) o **más adelante**
/// (gris, con lo que falta).
private struct GiftEntryCard: View {
    enum Mode: Equatable {
        /// La tarjeta destacada de arriba.
        case hero
        case ready
        case soon
        case later
    }

    let entry: GiftsAgenda.Entry
    let mode: Mode
    /// Hay anuncio cargado para saltear cooldowns. Lo sondea la PANTALLA una
    /// sola vez y se lo pasa a todas las filas.
    let adReady: Bool
    let openChest: () -> Void
    let openWheel: () -> Void
    let activateBoost: (String) -> Void
    let boostWatched: (String) -> Void
    let videoRewarded: (String) -> Void

    private var progress: Double? {
        switch entry {
        case .boost(let row) where mode == .soon:
            Cooldown.progress(remaining: row.cooldownRemaining, total: row.cooldownTotal)
        case .video(let row) where mode == .soon:
            Cooldown.progress(remaining: row.cooldownRemaining, total: row.cooldownTotal)
        default: nil
        }
    }

    var body: some View {
        Group {
            switch mode {
            case .hero: hero
            case .ready, .soon: GameCard(style: .normal) { row }
            case .later: GameCard(style: .locked, contentDimsWhenLocked: false) { row }
            }
        }
        // ⚠️ El resumen de la fila va en una capa VACÍA y **detrás** (patrón T8):
        // sobre la tarjeta entera se tragaría al botón —un elemento de
        // accesibilidad que CONTIENE un control lo borra del árbol (trampa 9a)—.
        .background {
            Color.clear
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(rowIdentifier)
                .accessibilityLabel(Text(verbatim: GiftFacts.spoken(of: entry, mode: mode)))
                .allowsHitTesting(false)
        }
    }

    private var rowIdentifier: String {
        if case .chest = entry { return "gifts.chest.row" }
        return "gifts.row.\(entry.id)"
    }

    // MARK: Tarjeta grande

    private var hero: some View {
        GameCard(style: .highlighted(Color("PaletteYellow"))) {
            VStack(spacing: Tokens.s12) {
                HStack(spacing: Tokens.s12) {
                    heroArt
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: GiftFacts.name(of: entry))
                            .font(Tokens.title)
                            .foregroundStyle(Color("PaletteInk"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text(verbatim: GiftFacts.detail(of: entry, mode: mode))
                            .font(Tokens.body)
                            .foregroundStyle(Color("PaletteInk").opacity(0.8))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
                }
                action(size: .regular)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder private var heroArt: some View {
        if let kind = GiftFacts.art(of: entry) {
            RewardIllustration(kind: kind, size: 64)
                .frame(width: 84, height: 84)
        } else {
            GiftPlate(entry: entry, side: 72)
        }
    }

    // MARK: Fila

    private var row: some View {
        HStack(spacing: Tokens.s12) {
            GiftPlate(entry: entry, progress: progress)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: GiftFacts.name(of: entry))
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(verbatim: GiftFacts.detail(of: entry, mode: mode))
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.7))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Todo lo que dice esta columna ya lo dice el resumen de la fila.
            .accessibilityHidden(true)
            trailing
        }
    }

    @ViewBuilder private var trailing: some View {
        switch mode {
        case .hero, .ready: action(size: .compact)
        case .soon: waiting
        case .later: lock
        }
    }

    // MARK: El botón

    @ViewBuilder
    private func action(size: GameButton.Size) -> some View {
        switch entry {
        case .chest:
            GameButton(
                "gifts.chest.open", role: .free, medallion: medallion(.chest, size), size: size,
                fullWidth: size == .regular, identifier: "gifts.chest.open",
                // "Abrir" a secas no dice qué se abre; el nombre del premio ya
                // existe y va en singular: abrir UNO.
                accessibilityLabel: Text("gifts.chest.open") + Text(verbatim: ", ") + Text("daily.prize.chest"),
                action: openChest
            )
        case .wheel:
            GameButton(
                "gifts.wheel.open", role: .free, medallion: medallion(.wheel, size), size: size,
                fullWidth: size == .regular, identifier: "gifts.wheel.open", action: openWheel
            )
        case .boost(let row):
            GameButton(
                "bonus.activate", role: .free, medallion: medallion(.art(row.iconKey), size), size: size,
                fullWidth: size == .regular, identifier: "bonus.activate.\(row.id)",
                // "Activar" a secas es lo que dicen todos los botones: sin el
                // nombre, VoiceOver no distingue cuál se está por apretar.
                accessibilityLabel: Text("bonus.activate") + Text(verbatim: ", \(row.displayName)"),
                action: { activateBoost(row.id) }
            )
        case .video(let row):
            // Mientras carga o corre el video el botón dice "Cargando video…" y
            // ignora los toques: es lo que reemplaza al `.disabled`.
            RewardedOfferButton(
                title: String(localized: "ads.watch"),
                identifier: "ads.watch.\(row.id)",
                placement: .gifts,
                accessibilityLabel: Text("ads.watch") + Text(verbatim: ", \(GameState.localized(row.titleKey))"),
                gameRole: .video,
                gameCompact: size == .compact,
                onRewarded: { videoRewarded(row.id) }
            )
        }
    }

    /// El medallón va en el botón grande; en el de la fila no, como el del video
    /// (`RewardedOfferButton.gameCompact`): los botones de una lista son parejos.
    private func medallion(_ glyph: GameGlyph, _ size: GameButton.Size) -> GameButton.Medallion {
        size == .regular ? .glyph(glyph) : .none
    }

    // MARK: Pronto y más adelante

    /// El reloj, protagonista de «Pronto». Un boost con el video de su ciclo sin
    /// usar (C32) ofrece saltear la espera si hay anuncio cargado; si no, el
    /// reloj sigue estando: es el único lugar donde se dice «está en cooldown».
    @ViewBuilder private var waiting: some View {
        switch entry {
        case .boost(let row) where adReady && row.offersAd:
            RewardedOfferButton(
                title: String(localized: "ads.offer.boost.now"),
                identifier: "bonus.ad.\(row.id)",
                placement: .boost,
                accessibilityLabel: Text("ads.offer.boost.now") + Text(verbatim: ", \(row.displayName)"),
                gameRole: .video,
                gameCompact: true,
                onRewarded: { boostWatched(row.id) }
            )
        case .boost(let row):
            clock(row.cooldownRemaining, identifier: "bonus.cooldown.\(row.id)")
        case .video(let row):
            clock(row.cooldownRemaining, identifier: "ads.cooldown.\(row.id)")
        case .wheel(_, let readyIn):
            if let readyIn { clock(readyIn, identifier: "gifts.wheel.soon") }
        case .chest:
            EmptyView()
        }
    }

    private func clock(_ remaining: TimeInterval, identifier: String) -> some View {
        HStack(spacing: Tokens.s4) {
            GameGlyphView(glyph: .clock, size: 22)
            Text(verbatim: Cooldown.text(remaining))
                .font(Tokens.title)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(verbatim: Cooldown.text(remaining)))
    }

    /// El candado de «Más adelante»: lo que falta lo dice la línea de la fila; el
    /// candado es el estado, y es lo que VoiceOver encuentra por su identifier.
    private var lock: some View {
        GameGlyphView(glyph: .lock, size: 28)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(lockIdentifier)
            .accessibilityLabel(Text(verbatim: GiftFacts.detail(of: entry, mode: .later)))
    }

    private var lockIdentifier: String {
        switch entry {
        case .chest: "gifts.chest.locked"
        case .wheel: "gifts.wheel.locked"
        case .boost(let row): "bonus.locked.\(row.id)"
        case .video(let row): "ads.unavailable.\(row.id)"
        }
    }
}

// MARK: - La racha

/// Los siete días del ciclo, en una tira. Cobrados con tilde, el que está en
/// juego resaltado en amarillo y el séptimo con el moño de la sorpresa. Arriba,
/// el día en un número grande y el «?» que abre la explicación.
///
/// No hay botón de reclamar: ver el ⚠️ de `GiftsView`.
private struct DailyStrip: View {
    let days: [GameState.DailyDayRow]
    let showHelp: () -> Void

    private var currentDay: Int {
        days.first(where: \.isToday)?.id ?? max(1, days.filter(\.isClaimed).count)
    }

    var body: some View {
        GameCard(style: .normal) {
            VStack(spacing: Tokens.s8) {
                HStack(spacing: Tokens.s12) {
                    GameIcon(artKey: "ui_daily_calendar", size: 44) { VectorCalendarIcon() }
                        .padding(6)
                        .background(Color("PaletteYellow").opacity(0.35))
                        .clipShape(GiftPlate.shape)
                        .overlay(GiftPlate.shape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                        .accessibilityHidden(true)
                    Text("gifts.daily.headline \(currentDay)")
                        .font(Tokens.title)
                        .monospacedDigit()
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HelpButton(action: showHelp)
                }
                HStack(spacing: Tokens.s4) {
                    ForEach(days) { day in
                        DayCell(day: day)
                    }
                }
            }
        }
    }
}

/// El «?» de la casa: un disco dibujado con su marca, con el área de toque de
/// 44 pt.
private struct HelpButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IconCanvas { MarkDisc(mark: "?", fill: Color("PaletteBlue")) }
                .frame(width: 30, height: 30)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("gifts.help.ax"))
        .accessibilityIdentifier("gifts.daily.help")
    }
}

/// La explicación de la racha: lo que antes eran tres renglones en la tarjeta.
private struct StreakHelpPopup: View {
    let close: () -> Void

    var body: some View {
        PopupContainer("gifts.section.daily", onClose: close, closeIdentifier: "gifts.help.close") {
            VStack(spacing: Tokens.s12) {
                RewardIllustration(kind: .gift, size: 72)
                Text("gifts.daily.note")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        } actions: {
            GameButton("gifts.help.ok", role: .neutral, identifier: "gifts.help.ok", action: close)
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
            // (trampa 5).
            Text(verbatim: "\(day.id)")
                .font(Tokens.caption)
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk").opacity(day.isClaimed || day.isToday ? 1 : 0.55))
                // Siete casillas se reparten ~36 pt cada una en el más angosto:
                // con Dynamic Type grande el dígito se encoge, como todo lo demás.
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
                            day.isToday
                                ? Color("PaletteYellow").deepened(0.25)
                                : Color("PaletteBrown").opacity(day.isClaimed ? 0.7 : 0.35),
                            lineWidth: day.isToday ? 3 : 2
                        )
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("gifts.daily.day\(day.id)")
        // El nombre del día ("Día 3: Quincena Chica") ya es la mitad del chiste;
        // para el séptimo se agrega la sorpresa, que es lo ÚNICO que lo distingue
        // en pantalla y se perdería al colapsar la casilla.
        .accessibilityLabel(
            day.isChest
                ? Text(LocalizedStringKey(day.titleKey)) + Text(verbatim: ", ") + Text("gifts.daily.surprise")
                : Text(LocalizedStringKey(day.titleKey))
        )
        .accessibilityValue(Text(stateKey))
    }

    /// Qué se ve adentro de la casilla: el tilde si ya se cobró, el moño en el
    /// día de la sorpresa, y la moneda en los demás.
    @ViewBuilder private var glyph: some View {
        if day.isClaimed {
            GameGlyphView(glyph: .check, size: 20)
        } else if day.isChest {
            GameIcon(artKey: "ui_tab_gifts", size: 20) { VectorTabGiftsIcon() }
        } else {
            CoinIcon(size: 18)
                .opacity(day.isToday ? 1 : 0.6)
        }
    }
}
