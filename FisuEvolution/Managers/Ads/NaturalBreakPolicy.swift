import Foundation

/// Los momentos en que el juego se detiene solo y un anuncio forzado no le
/// interrumpe nada al jugador (PLAN-v2, E7). Son los ÚNICOS lugares donde un
/// formato forzado puede caer: reemplazan al "cerrar una hoja" de la 1.x.
enum NaturalBreak: String, Sendable, CaseIterable {
    /// Se cerró una hoja y el jugador vuelve al tablero.
    case sheetClosed
    /// Terminó la última celebración en cola (ascenso, cofre, premio).
    case celebrationsDrained
    /// Terminó una reencarnación: la pausa más natural del juego.
    case reincarnation
    /// Se cerró el popup de ganancias offline.
    case offlinePopupDismissed
    /// La app volvió del background. Es el único corte del app open, y el
    /// app open es lo único que puede caer acá.
    case returnFromBackground
}

/// Lo que el juego sabe en el instante del corte. Lo arma quien cablea
/// (`GameState` + `AdsCoordinator`); la política no lee nada por su cuenta.
struct NaturalBreakContext: Sendable, Equatable {
    /// El jugador compró `remove_ads` (o el starter).
    var removedAds = false
    var tutorialActive = false
    /// Hay una hoja tapando el tablero.
    var sheetOpen = false
    /// Hay una celebración con el turno.
    var celebrationActive = false
    /// Ya hay un anuncio en pantalla (`AdsCoordinator.isPresentingFullScreen`).
    var adOnScreen = false
    /// Cuándo se cerró el último video con premio
    /// (`AdsCoordinator.lastRewardedAt`).
    var lastRewardedAt: Date?
    /// Los formatos con inventario cargado y fresco.
    var readyFormats: Set<ForcedAdFormat> = []
}

/// La sesión en curso. No se persiste: muere con el proceso.
struct AdsSession: Sendable, Equatable {
    /// Cuándo arrancó la app o volvió del background.
    var startedAt: Date
    /// Cuánto estuvo afuera en la última vuelta del background; `nil` en un
    /// arranque en frío, que nunca es una vuelta.
    var secondsAway: TimeInterval?
}

/// Lo que sobrevive entre arranques. Lo guarda `AdsPacingStore`.
struct AdsPacingState: Codable, Sendable, Equatable {
    /// Cuántos arranques en frío hubo, contando el actual. El primero es 1.
    var sessionNumber = 0
    /// El último formato forzado, **cualquiera de los tres**. Es uno solo a
    /// propósito: un app open seguido de un intersticial son dos anuncios
    /// pegados aunque sean de formatos distintos.
    var lastFullScreenAt: Date?
    /// El último app open, para su "como máximo 1 cada 20 min".
    var lastAppOpenAt: Date?
    /// A quién le toca en la alternancia (índice en `alternation`).
    var alternationIndex = 0

    init() {}

    /// Las claves faltantes caen al valor de arranque: un estado guardado por
    /// una versión anterior no puede romper la decodificación y resetear la
    /// alternancia de todos.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionNumber = try container.decodeIfPresent(Int.self, forKey: .sessionNumber) ?? 0
        lastFullScreenAt = try container.decodeIfPresent(Date.self, forKey: .lastFullScreenAt)
        lastAppOpenAt = try container.decodeIfPresent(Date.self, forKey: .lastAppOpenAt)
        alternationIndex = try container.decodeIfPresent(Int.self, forKey: .alternationIndex) ?? 0
    }
}

/// Por qué un corte natural no muestra nada. Existe para que los tests
/// prueben que bloqueó **la regla correcta**, no sólo que no mostró.
enum NaturalBreakSkip: Sendable, Equatable {
    case removedAds
    case adOnScreen
    case tutorial
    case sheetOpen
    case celebration
    /// Pasó menos de `minSecondsBetweenForced` desde el último forzado.
    case tooSoonAfterForced
    /// Pasó menos de `graceSecondsAfterRewarded` desde el último video.
    case rewardedGrace
    /// Pasó menos de `graceSecondsAfterLaunch` desde el arranque o la vuelta.
    case launchGrace
    /// App open antes de la sesión mínima (incluye el primer arranque).
    case earlySession
    /// App open con una ausencia corta, o sin ausencia (arranque en frío).
    case shortAbsence
    /// App open antes de que pasen `appOpenMinSecondsBetween` del anterior.
    case appOpenTooSoon
    /// Le tocaba algo, pero está apagado o sin inventario.
    case nothingAvailable
}

enum NaturalBreakDecision: Sendable, Equatable {
    case show(ForcedAdFormat)
    case skip(NaturalBreakSkip)

    var format: ForcedAdFormat? {
        if case .show(let format) = self { return format }
        return nil
    }
}

/// **La política de los anuncios forzados de la 2.0, pura**: recibe el corte,
/// lo que pasa en el juego, lo persistido, la sesión y la hora, y contesta qué
/// mostrar. No lee relojes, ni disco, ni el SDK. Todo lo que decide está en
/// sus argumentos, y por eso se puede probar regla por regla.
///
/// Las reglas (PLAN-v2 §2 y E7):
///
/// - **Sólo en cortes naturales**, y nunca en el tutorial, con una hoja
///   abierta, con una celebración o con otro anuncio en pantalla.
/// - **≥ 2 min entre forzados**, con un `lastFullScreenAt` único entre los
///   tres formatos. Eso es también lo que impide dos formatos en el mismo
///   corte: el primero que se muestra cierra la ventana para el segundo.
/// - **90 s de gracia después de un video con premio**: quien acaba de mirar
///   un video por elección propia no se come otro de arranque.
/// - **Intersticial común y pausa publicitaria alternados**, con el turno
///   persistido. Si al que le toca no puede (apagado o sin inventario), sale
///   el otro y el turno **no** avanza: la alternancia es un orden, no un
///   castigo por quedarse sin inventario.
/// - **App open sólo al volver del background**, con ≥ 180 s afuera, como
///   máximo 1 cada 20 min, desde la 2ª sesión y nunca en el primer arranque.
/// - **`remove_ads` apaga los tres.** Los videos con premio no pasan por acá.
///
/// Los números salen de la config remota (`init(config:)`), con `default`
/// como respaldo.
struct NaturalBreakPolicy: Sendable, Equatable {
    var minSecondsBetweenForced: TimeInterval
    var graceSecondsAfterLaunch: TimeInterval
    var graceSecondsAfterRewarded: TimeInterval
    var alternation: [ForcedAdFormat]
    var appOpenMinSecondsAway: TimeInterval
    var appOpenMinSecondsBetween: TimeInterval
    var appOpenMinSessionNumber: Int
    /// Los formatos con el interruptor prendido.
    var enabledFormats: Set<ForcedAdFormat>

    /// Los mismos valores que el `ads.json` embarcado; un test los mantiene
    /// sincronizados.
    static let `default` = NaturalBreakPolicy(
        minSecondsBetweenForced: 120,
        graceSecondsAfterLaunch: 180,
        graceSecondsAfterRewarded: 90,
        alternation: [.interstitial, .rewardedInterstitial],
        appOpenMinSecondsAway: 180,
        appOpenMinSecondsBetween: 20 * 60,
        appOpenMinSessionNumber: 2,
        // El app open tiene unidad y el dueño lo prendió (gate de AdMob, 2026-10-08).
        enabledFormats: [.interstitial, .rewardedInterstitial, .appOpen]
    )

    init(
        minSecondsBetweenForced: TimeInterval,
        graceSecondsAfterLaunch: TimeInterval,
        graceSecondsAfterRewarded: TimeInterval,
        alternation: [ForcedAdFormat],
        appOpenMinSecondsAway: TimeInterval,
        appOpenMinSecondsBetween: TimeInterval,
        appOpenMinSessionNumber: Int,
        enabledFormats: Set<ForcedAdFormat>
    ) {
        self.minSecondsBetweenForced = minSecondsBetweenForced
        self.graceSecondsAfterLaunch = graceSecondsAfterLaunch
        self.graceSecondsAfterRewarded = graceSecondsAfterRewarded
        self.alternation = alternation
        self.appOpenMinSecondsAway = appOpenMinSecondsAway
        self.appOpenMinSecondsBetween = appOpenMinSecondsBetween
        self.appOpenMinSessionNumber = appOpenMinSessionNumber
        self.enabledFormats = enabledFormats
    }

    /// Los valores de una config remota ya validada.
    init(config: AdsRemoteConfig) {
        self.init(
            minSecondsBetweenForced: config.cadence.minSecondsBetweenForced,
            graceSecondsAfterLaunch: config.cadence.graceSecondsAfterLaunch,
            graceSecondsAfterRewarded: config.cadence.graceSecondsAfterRewarded,
            alternation: config.alternation,
            appOpenMinSecondsAway: config.appOpen.minSecondsAway,
            appOpenMinSecondsBetween: config.appOpen.minSecondsBetween,
            appOpenMinSessionNumber: config.appOpen.minSessionNumber,
            enabledFormats: Set(ForcedAdFormat.allCases.filter(config.switches.isOn))
        )
    }

    // MARK: - La decisión

    func decide(
        _ naturalBreak: NaturalBreak,
        context: NaturalBreakContext,
        pacing: AdsPacingState,
        session: AdsSession,
        now: Date
    ) -> NaturalBreakDecision {
        // Primero lo que apaga todo, sin mirar relojes.
        if context.removedAds { return .skip(.removedAds) }
        if context.adOnScreen { return .skip(.adOnScreen) }
        if context.tutorialActive { return .skip(.tutorial) }
        if context.sheetOpen { return .skip(.sheetOpen) }
        if context.celebrationActive { return .skip(.celebration) }

        // Después, los relojes comunes a los tres formatos.
        guard Self.hasElapsed(minSecondsBetweenForced, since: pacing.lastFullScreenAt, now: now) else {
            return .skip(.tooSoonAfterForced)
        }
        guard Self.hasElapsed(graceSecondsAfterRewarded, since: context.lastRewardedAt, now: now) else {
            return .skip(.rewardedGrace)
        }

        switch naturalBreak {
        case .returnFromBackground:
            return decideAppOpen(context: context, pacing: pacing, session: session, now: now)
        case .sheetClosed, .celebrationsDrained, .reincarnation, .offlinePopupDismissed:
            return decideAlternating(context: context, pacing: pacing, session: session, now: now)
        }
    }

    private func decideAppOpen(
        context: NaturalBreakContext,
        pacing: AdsPacingState,
        session: AdsSession,
        now: Date
    ) -> NaturalBreakDecision {
        guard pacing.sessionNumber >= appOpenMinSessionNumber else { return .skip(.earlySession) }
        guard let away = session.secondsAway, away >= appOpenMinSecondsAway else {
            return .skip(.shortAbsence)
        }
        guard Self.hasElapsed(appOpenMinSecondsBetween, since: pacing.lastAppOpenAt, now: now) else {
            return .skip(.appOpenTooSoon)
        }
        guard isAvailable(.appOpen, context: context) else { return .skip(.nothingAvailable) }
        return .show(.appOpen)
    }

    private func decideAlternating(
        context: NaturalBreakContext,
        pacing: AdsPacingState,
        session: AdsSession,
        now: Date
    ) -> NaturalBreakDecision {
        guard Self.hasElapsed(graceSecondsAfterLaunch, since: session.startedAt, now: now) else {
            return .skip(.launchGrace)
        }
        for format in turnOrder(pacing) where isAvailable(format, context: context) {
            return .show(format)
        }
        return .skip(.nothingAvailable)
    }

    // MARK: - El turno

    /// El formato al que le toca, y después los demás del patrón, sin
    /// repetir: es el orden en que se prueban.
    func turnOrder(_ pacing: AdsPacingState) -> [ForcedAdFormat] {
        guard !alternation.isEmpty else { return [] }
        let start = Self.normalized(pacing.alternationIndex, count: alternation.count)
        var order: [ForcedAdFormat] = []
        for offset in 0..<alternation.count {
            let format = alternation[(start + offset) % alternation.count]
            if !order.contains(format) { order.append(format) }
        }
        return order
    }

    /// El estado después de mostrar `format`. Lo llama quien cablea **cuando
    /// el anuncio se mostró de verdad**, no cuando se decidió.
    func recording(_ format: ForcedAdFormat, in pacing: AdsPacingState, at now: Date) -> AdsPacingState {
        var next = pacing
        next.lastFullScreenAt = now
        switch format {
        case .appOpen:
            next.lastAppOpenAt = now
        case .interstitial, .rewardedInterstitial:
            // Sólo avanza si salió el que tenía el turno: si salió el otro
            // por falta de inventario, el turno espera.
            guard !alternation.isEmpty else { break }
            let index = Self.normalized(pacing.alternationIndex, count: alternation.count)
            if alternation[index] == format {
                next.alternationIndex = (index + 1) % alternation.count
            }
        }
        return next
    }

    // MARK: - Utilidades

    private func isAvailable(_ format: ForcedAdFormat, context: NaturalBreakContext) -> Bool {
        enabledFormats.contains(format) && context.readyFormats.contains(format)
    }

    /// El índice guardado puede venir de un patrón remoto de otro largo.
    private static func normalized(_ index: Int, count: Int) -> Int {
        ((index % count) + count) % count
    }

    /// Si pasaron `seconds` desde `date`. Sin fecha, pasaron.
    ///
    /// ⚠️ Un reloj que fue para ATRÁS más allá de la ventana cuenta como "pasó":
    /// la fecha guardada quedó en el futuro y, si no, un jugador que corrigió
    /// la hora del teléfono no vería un anuncio forzado en días. Un salto
    /// chico hacia atrás sí sigue frenando, que es el caso que importa para
    /// no pegar dos anuncios.
    static func hasElapsed(_ seconds: TimeInterval, since date: Date?, now: Date) -> Bool {
        guard let date else { return true }
        let elapsed = now.timeIntervalSince(date)
        return elapsed >= seconds || elapsed < -seconds
    }
}
