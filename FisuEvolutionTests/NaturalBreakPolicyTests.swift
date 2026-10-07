import Foundation
import Testing
@testable import FisuEvolution

/// La política de los anuncios forzados de la 2.0 (PLAN-v2 §2 y E7), regla por
/// regla. La política es pura y el reloj se inyecta: cada test arma el instante
/// exacto que quiere probar, y del lado de "no mostrar" se asserta **qué regla**
/// bloqueó, no sólo que no se mostró nada.
@Suite("Política de cortes naturales")
struct NaturalBreakPolicyTests {

    /// El instante de arranque de todos los tests.
    private static let t0 = Date(timeIntervalSince1970: 1_000_000)
    private static let policy = NaturalBreakPolicy.default.with(appOpenEnabled: true)

    /// Un contexto donde todo está listo y nada bloquea.
    private static let clear = NaturalBreakContext(readyFormats: Set(ForcedAdFormat.allCases))

    /// Una sesión que arrancó hace mucho (la gracia de arranque ya pasó) y
    /// que viene de una ausencia larga.
    private static func settledSession(secondsAway: TimeInterval? = 3600) -> AdsSession {
        AdsSession(startedAt: t0.addingTimeInterval(-10_000), secondsAway: secondsAway)
    }

    /// Un veterano: varias sesiones, sin anuncios recientes.
    private static func veteran() -> AdsPacingState {
        var pacing = AdsPacingState()
        pacing.sessionNumber = 5
        return pacing
    }

    private static func decide(
        _ naturalBreak: NaturalBreak,
        policy: NaturalBreakPolicy = Self.policy,
        context: NaturalBreakContext = Self.clear,
        pacing: AdsPacingState = Self.veteran(),
        session: AdsSession = Self.settledSession(),
        at now: Date = Self.t0
    ) -> NaturalBreakDecision {
        policy.decide(naturalBreak, context: context, pacing: pacing, session: session, now: now)
    }

    /// Los cortes de los intersticiales: todos menos la vuelta del background.
    static let alternatingBreaks: [NaturalBreak] = [
        .sheetClosed, .celebrationsDrained, .reincarnation, .offlinePopupDismissed,
    ]

    // MARK: - Lo que apaga todo, en todos los cortes

    @Test("remove_ads apaga los tres forzados en todos los cortes", arguments: NaturalBreak.allCases)
    func removeAdsSkipsEveryBreak(naturalBreak: NaturalBreak) {
        var context = Self.clear
        context.removedAds = true
        #expect(Self.decide(naturalBreak, context: context) == .skip(.removedAds))
    }

    @Test("nunca en el tutorial", arguments: NaturalBreak.allCases)
    func neverDuringTheTutorial(naturalBreak: NaturalBreak) {
        var context = Self.clear
        context.tutorialActive = true
        #expect(Self.decide(naturalBreak, context: context) == .skip(.tutorial))
    }

    @Test("nunca con una hoja abierta", arguments: NaturalBreak.allCases)
    func neverWithASheetOpen(naturalBreak: NaturalBreak) {
        var context = Self.clear
        context.sheetOpen = true
        #expect(Self.decide(naturalBreak, context: context) == .skip(.sheetOpen))
    }

    @Test("nunca encima de una celebración", arguments: NaturalBreak.allCases)
    func neverOverACelebration(naturalBreak: NaturalBreak) {
        var context = Self.clear
        context.celebrationActive = true
        #expect(Self.decide(naturalBreak, context: context) == .skip(.celebration))
    }

    @Test("nunca con otro anuncio en pantalla", arguments: NaturalBreak.allCases)
    func neverOverAnotherAd(naturalBreak: NaturalBreak) {
        var context = Self.clear
        context.adOnScreen = true
        #expect(Self.decide(naturalBreak, context: context) == .skip(.adOnScreen))
    }

    // MARK: - ≥ 2 min entre forzados, con un reloj único

    @Test("dos forzados quedan a ≥ 2 min, y el borde exacto ya vale", arguments: NaturalBreak.allCases)
    func twoMinutesBetweenForced(naturalBreak: NaturalBreak) {
        var pacing = Self.veteran()
        pacing.lastFullScreenAt = Self.t0
        #expect(Self.decide(naturalBreak, pacing: pacing, at: Self.t0.addingTimeInterval(119)) == .skip(.tooSoonAfterForced))
        #expect(Self.decide(naturalBreak, pacing: pacing, at: Self.t0.addingTimeInterval(120)).format != nil)
    }

    /// El reloj es UNO para los tres formatos: un app open al volver cierra la
    /// ventana para el intersticial del popup offline que viene detrás.
    @Test("nunca dos formatos en el mismo corte: tras un app open, el popup offline no muestra nada")
    func neverTwoFormatsInTheSameBreak() {
        let policy = Self.policy
        let pacing = Self.veteran()
        let atReturn = Self.decide(.returnFromBackground, pacing: pacing)
        #expect(atReturn == .show(.appOpen))

        let afterAppOpen = policy.recording(.appOpen, in: pacing, at: Self.t0)
        let offline = Self.decide(.offlinePopupDismissed, pacing: afterAppOpen, at: Self.t0.addingTimeInterval(20))
        #expect(offline == .skip(.tooSoonAfterForced))
    }

    @Test("una decisión es a lo sumo UN formato", arguments: NaturalBreak.allCases)
    func aDecisionIsAtMostOneFormat(naturalBreak: NaturalBreak) {
        // Es una propiedad del tipo (`.show` lleva un solo formato); el test
        // fija que el corte de vuelta, con los tres listos, elige uno solo y
        // es el app open.
        let decision = Self.decide(naturalBreak)
        let expected: ForcedAdFormat = naturalBreak == .returnFromBackground ? .appOpen : .interstitial
        #expect(decision == .show(expected))
    }

    // MARK: - Gracias

    @Test("90 s de gracia después de un video con premio", arguments: NaturalBreak.allCases)
    func ninetySecondsAfterARewardedVideo(naturalBreak: NaturalBreak) {
        var context = Self.clear
        context.lastRewardedAt = Self.t0
        #expect(Self.decide(naturalBreak, context: context, at: Self.t0.addingTimeInterval(89)) == .skip(.rewardedGrace))
        #expect(Self.decide(naturalBreak, context: context, at: Self.t0.addingTimeInterval(90)).format != nil)
    }

    @Test("la gracia de arranque frena los intersticiales", arguments: alternatingBreaks)
    func launchGraceHoldsTheInterstitials(naturalBreak: NaturalBreak) {
        let session = AdsSession(startedAt: Self.t0, secondsAway: nil)
        #expect(Self.decide(naturalBreak, session: session, at: Self.t0.addingTimeInterval(179)) == .skip(.launchGrace))
        #expect(Self.decide(naturalBreak, session: session, at: Self.t0.addingTimeInterval(180)) == .show(.interstitial))
    }

    /// El app open no mira la gracia de arranque: su momento es justamente
    /// el instante de la vuelta.
    @Test("la gracia de arranque no frena al app open")
    func launchGraceDoesNotHoldAppOpen() {
        let session = AdsSession(startedAt: Self.t0, secondsAway: 600)
        #expect(Self.decide(.returnFromBackground, session: session, at: Self.t0) == .show(.appOpen))
    }

    // MARK: - Alternancia

    @Test("común y pausa publicitaria se alternan")
    func interstitialsAlternate() {
        var pacing = Self.veteran()
        var now = Self.t0
        var shown: [ForcedAdFormat] = []
        for _ in 0..<4 {
            let format = Self.decide(.sheetClosed, pacing: pacing, at: now).format
            guard let format else {
                Issue.record("no mostró nada")
                return
            }
            shown.append(format)
            pacing = Self.policy.recording(format, in: pacing, at: now)
            now = now.addingTimeInterval(121)
        }
        #expect(shown == [.interstitial, .rewardedInterstitial, .interstitial, .rewardedInterstitial])
    }

    @Test("el patrón de alternancia sale de la config: dos comunes por pausa")
    func alternationPatternComesFromConfig() {
        var policy = Self.policy
        policy.alternation = [.interstitial, .interstitial, .rewardedInterstitial]
        var pacing = Self.veteran()
        var now = Self.t0
        var shown: [ForcedAdFormat] = []
        for _ in 0..<4 {
            guard let format = Self.decide(.reincarnation, policy: policy, pacing: pacing, at: now).format else {
                Issue.record("no mostró nada")
                return
            }
            shown.append(format)
            pacing = policy.recording(format, in: pacing, at: now)
            now = now.addingTimeInterval(121)
        }
        #expect(shown == [.interstitial, .interstitial, .rewardedInterstitial, .interstitial])
    }

    /// Si la pausa no tiene inventario, sale el común y el turno de la pausa
    /// espera: la próxima vez que haya, sale ella.
    @Test("sin inventario para el que le toca sale el otro, y el turno no se pierde")
    func aMissingTurnFallsBackWithoutLosingTheTurn() {
        var pacing = Self.veteran()
        pacing = Self.policy.recording(.interstitial, in: pacing, at: Self.t0)  // le toca la pausa
        var context = Self.clear
        context.readyFormats = [.interstitial]
        let later = Self.t0.addingTimeInterval(121)

        #expect(Self.decide(.sheetClosed, context: context, pacing: pacing, at: later) == .show(.interstitial))
        pacing = Self.policy.recording(.interstitial, in: pacing, at: later)

        let evenLater = later.addingTimeInterval(121)
        #expect(Self.decide(.sheetClosed, pacing: pacing, at: evenLater) == .show(.rewardedInterstitial))
    }

    @Test("con un formato apagado por el interruptor, sale siempre el otro")
    func aSwitchedOffFormatNeverShows() {
        var policy = Self.policy
        policy.enabledFormats = [.interstitial, .appOpen]
        var pacing = Self.veteran()
        pacing = policy.recording(.interstitial, in: pacing, at: Self.t0)  // le tocaría la pausa
        #expect(Self.decide(.sheetClosed, policy: policy, pacing: pacing, at: Self.t0.addingTimeInterval(121)) == .show(.interstitial))
    }

    @Test("con los dos intersticiales apagados o sin inventario, no hay nada que mostrar")
    func nothingAvailable() {
        var context = Self.clear
        context.readyFormats = [.appOpen]
        #expect(Self.decide(.sheetClosed, context: context) == .skip(.nothingAvailable))
    }

    @Test("un turno guardado con un patrón remoto más largo no rompe nada")
    func aStaleAlternationIndexIsNormalized() {
        var pacing = Self.veteran()
        pacing.alternationIndex = 7
        // 7 % 2 == 1 → le toca la pausa.
        #expect(Self.decide(.sheetClosed, pacing: pacing) == .show(.rewardedInterstitial))
    }

    // MARK: - App open

    @Test("el app open sale SÓLO al volver del background", arguments: alternatingBreaks)
    func appOpenOnlyOnReturn(naturalBreak: NaturalBreak) {
        var context = Self.clear
        context.readyFormats = [.appOpen]
        #expect(Self.decide(naturalBreak, context: context) == .skip(.nothingAvailable))
    }

    @Test("al volver del background sólo puede salir el app open")
    func returnNeverShowsAnInterstitial() {
        var context = Self.clear
        context.readyFormats = [.interstitial, .rewardedInterstitial]
        #expect(Self.decide(.returnFromBackground, context: context) == .skip(.nothingAvailable))
    }

    @Test("el app open pide ≥ 180 s afuera")
    func appOpenNeedsThreeMinutesAway() {
        #expect(Self.decide(.returnFromBackground, session: Self.settledSession(secondsAway: 179)) == .skip(.shortAbsence))
        #expect(Self.decide(.returnFromBackground, session: Self.settledSession(secondsAway: 180)) == .show(.appOpen))
    }

    @Test("como máximo un app open cada 20 min")
    func atMostOneAppOpenEveryTwentyMinutes() {
        let pacing = Self.policy.recording(.appOpen, in: Self.veteran(), at: Self.t0)
        #expect(Self.decide(.returnFromBackground, pacing: pacing, at: Self.t0.addingTimeInterval(1199)) == .skip(.appOpenTooSoon))
        #expect(Self.decide(.returnFromBackground, pacing: pacing, at: Self.t0.addingTimeInterval(1200)) == .show(.appOpen))
    }

    /// Un intersticial no gasta el cupo del app open (sí cierra la ventana de
    /// 2 min, que es otra regla).
    @Test("un intersticial no cuenta para el cupo de 20 min del app open")
    func anInterstitialDoesNotSpendTheAppOpenQuota() {
        var pacing = Self.policy.recording(.appOpen, in: Self.veteran(), at: Self.t0)
        pacing = Self.policy.recording(.interstitial, in: pacing, at: Self.t0.addingTimeInterval(1100))
        #expect(Self.decide(.returnFromBackground, pacing: pacing, at: Self.t0.addingTimeInterval(1230)) == .show(.appOpen))
    }

    @Test("el app open arranca en la 2ª sesión")
    func appOpenFromTheSecondSession() {
        var pacing = AdsPacingState()
        pacing.sessionNumber = 1
        #expect(Self.decide(.returnFromBackground, pacing: pacing) == .skip(.earlySession))
        pacing.sessionNumber = 2
        #expect(Self.decide(.returnFromBackground, pacing: pacing) == .show(.appOpen))
    }

    /// Un arranque en frío no es una vuelta: no tiene ausencia medida.
    @Test("un arranque en frío nunca muestra app open")
    func aColdLaunchIsNeverAReturn() {
        #expect(Self.decide(.returnFromBackground, session: Self.settledSession(secondsAway: nil)) == .skip(.shortAbsence))
    }

    @Test("el app open con su interruptor apagado no sale (el default, hasta que exista la unidad)")
    func appOpenSwitchedOffByDefault() {
        #expect(Self.decide(.returnFromBackground, policy: .default) == .skip(.nothingAvailable))
    }

    // MARK: - El reloj

    @Test("un reloj que fue para atrás más allá de la ventana no traba los anuncios")
    func aClockThatWentBackDoesNotBlockForever() {
        var pacing = Self.veteran()
        pacing.lastFullScreenAt = Self.t0.addingTimeInterval(86_400)  // "mañana"
        #expect(Self.decide(.sheetClosed, pacing: pacing) == .show(.interstitial))
        // Un salto chico para atrás sí sigue frenando.
        pacing.lastFullScreenAt = Self.t0.addingTimeInterval(60)
        #expect(Self.decide(.sheetClosed, pacing: pacing) == .skip(.tooSoonAfterForced))
    }

    // MARK: - Los valores salen de la config remota

    @Test("los valores salen de la config remota")
    func valuesComeFromTheRemoteConfig() throws {
        let url = try #require(Bundle.main.url(forResource: "ads", withExtension: "json"))
        let config = try AdsRemoteConfig.decodeValidated(Data(contentsOf: url), publisherID: AdsRemoteConfig.ownPublisherID)
        let policy = NaturalBreakPolicy(config: config)

        // El default de código es el mismo que el respaldo embarcado.
        #expect(policy == .default)
        #expect(policy.minSecondsBetweenForced == 120)
        #expect(policy.graceSecondsAfterRewarded == 90)
        #expect(policy.appOpenMinSecondsAway == 180)
        #expect(policy.appOpenMinSecondsBetween == 1200)
        #expect(policy.appOpenMinSessionNumber == 2)
        #expect(policy.alternation == [.interstitial, .rewardedInterstitial])
        #expect(!policy.enabledFormats.contains(.appOpen))
    }

    @Test("una cadencia remota más larga se respeta")
    func aLongerRemoteCadenceIsHonored() {
        var policy = Self.policy
        policy.minSecondsBetweenForced = 300
        var pacing = Self.veteran()
        pacing.lastFullScreenAt = Self.t0
        #expect(Self.decide(.sheetClosed, policy: policy, pacing: pacing, at: Self.t0.addingTimeInterval(299)) == .skip(.tooSoonAfterForced))
        #expect(Self.decide(.sheetClosed, policy: policy, pacing: pacing, at: Self.t0.addingTimeInterval(300)) == .show(.interstitial))
    }
}

/// El estado que sobrevive entre arranques y el pacer que lo maneja.
@Suite("Pacer de anuncios forzados", .serialized)
@MainActor
struct ForcedAdsPacerTests {

    @Test("cada arranque en frío suma una sesión, y queda guardada")
    func eachColdLaunchCountsASession() {
        let scratch = ScratchPacingDefaults()
        defer { scratch.clear() }

        let first = ForcedAdsPacer(store: scratch.store)
        #expect(first.pacing.sessionNumber == 1)
        let second = ForcedAdsPacer(store: scratch.store)
        #expect(second.pacing.sessionNumber == 2)
    }

    /// El primer arranque nunca tiene app open, ni siquiera si el jugador se
    /// va diez minutos y vuelve.
    @Test("en la primera sesión no hay app open aunque el jugador vuelva tras 10 min")
    func noAppOpenDuringTheFirstSession() {
        let scratch = ScratchPacingDefaults()
        defer { scratch.clear() }
        let clock = TestClock()
        let pacer = ForcedAdsPacer(policy: NaturalBreakPolicy.default.with(appOpenEnabled: true),
                                   store: scratch.store, now: clock.read)

        pacer.didEnterBackground()
        clock.advance(by: 600)
        pacer.didReturnFromBackground()

        let context = NaturalBreakContext(readyFormats: [.appOpen])
        #expect(pacer.decide(.returnFromBackground, context: context) == .skip(.earlySession))
    }

    @Test("desde la 2ª sesión, volver tras 3 min muestra el app open")
    func appOpenOnTheSecondSession() {
        let scratch = ScratchPacingDefaults()
        defer { scratch.clear() }
        let clock = TestClock()
        let policy = NaturalBreakPolicy.default.with(appOpenEnabled: true)
        _ = ForcedAdsPacer(policy: policy, store: scratch.store, now: clock.read)
        let pacer = ForcedAdsPacer(policy: policy, store: scratch.store, now: clock.read)

        // `.inactive` y después `.background`: la ausencia cuenta desde el primero.
        pacer.didEnterBackground()
        clock.advance(by: 30)
        pacer.didEnterBackground()
        clock.advance(by: 150)
        pacer.didReturnFromBackground()

        let context = NaturalBreakContext(readyFormats: [.appOpen])
        #expect(pacer.session.secondsAway == 180)
        #expect(pacer.decide(.returnFromBackground, context: context) == .show(.appOpen))
    }

    @Test("volver del background reinicia la gracia de los intersticiales")
    func returningRestartsTheLaunchGrace() {
        let scratch = ScratchPacingDefaults()
        defer { scratch.clear() }
        let clock = TestClock()
        let pacer = ForcedAdsPacer(store: scratch.store, now: clock.read)
        let context = NaturalBreakContext(readyFormats: [.interstitial])

        clock.advance(by: 1000)
        #expect(pacer.decide(.sheetClosed, context: context) == .show(.interstitial))

        pacer.didEnterBackground()
        clock.advance(by: 3600)
        pacer.didReturnFromBackground()
        clock.advance(by: 60)
        #expect(pacer.decide(.sheetClosed, context: context) == .skip(.launchGrace))
    }

    @Test("la alternancia sobrevive a un reinicio de la app")
    func alternationSurvivesARelaunch() {
        let scratch = ScratchPacingDefaults()
        defer { scratch.clear() }
        let clock = TestClock()
        let context = NaturalBreakContext(readyFormats: [.interstitial, .rewardedInterstitial])

        let before = ForcedAdsPacer(store: scratch.store, now: clock.read)
        clock.advance(by: 1000)
        #expect(before.decide(.sheetClosed, context: context) == .show(.interstitial))
        before.recordShown(.interstitial)

        clock.advance(by: 1000)
        let after = ForcedAdsPacer(store: scratch.store, now: clock.read)
        clock.advance(by: 1000)
        #expect(after.decide(.sheetClosed, context: context) == .show(.rewardedInterstitial))
    }

    @Test("lo mostrado se guarda: reloj único, cupo del app open y turno")
    func recordShownPersists() throws {
        let scratch = ScratchPacingDefaults()
        defer { scratch.clear() }
        let clock = TestClock()
        let pacer = ForcedAdsPacer(store: scratch.store, now: clock.read)

        pacer.recordShown(.appOpen)
        let stored = scratch.store.load()
        #expect(stored.lastFullScreenAt == clock.read())
        #expect(stored.lastAppOpenAt == clock.read())
        #expect(stored.alternationIndex == 0)

        clock.advance(by: 500)
        pacer.recordShown(.interstitial)
        let next = scratch.store.load()
        #expect(next.lastFullScreenAt == clock.read())
        #expect(next.alternationIndex == 1)
    }

    @Test("un estado guardado roto o viejo arranca de cero sin romper")
    func aBrokenOrOldStateStartsClean() throws {
        let scratch = ScratchPacingDefaults()
        defer { scratch.clear() }

        scratch.defaults.set(Data("no es json".utf8), forKey: scratch.store.key)
        #expect(scratch.store.load() == AdsPacingState())

        // Un estado de una versión anterior, sin `alternationIndex`.
        scratch.defaults.set(Data(#"{"sessionNumber": 4}"#.utf8), forKey: scratch.store.key)
        let old = scratch.store.load()
        #expect(old.sessionNumber == 4)
        #expect(old.alternationIndex == 0)
    }
}

// MARK: - Andamio

extension NaturalBreakPolicy {
    /// El default con el app open prendido, para probar sus reglas. El
    /// default real lo trae apagado hasta que exista la unidad.
    func with(appOpenEnabled: Bool) -> NaturalBreakPolicy {
        var copy = self
        if appOpenEnabled { copy.enabledFormats.insert(.appOpen) } else { copy.enabledFormats.remove(.appOpen) }
        return copy
    }
}

/// Un dominio de `UserDefaults` descartable por test.
private struct ScratchPacingDefaults {
    let name = "ads-pacing-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: name) ?? .standard
    }

    var store: AdsPacingStore { AdsPacingStore(defaults: defaults) }

    func clear() {
        defaults.removePersistentDomain(forName: name)
    }
}
