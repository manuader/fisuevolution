import Foundation

/// Guarda `AdsPacingState` entre arranques, en `UserDefaults`.
///
/// Es `UserDefaults` y no el save del jugador porque esto **no es progreso**:
/// un reset de partida no tiene por qué devolverle al jugador la gracia de la
/// primera sesión, y un save restaurado de iCloud no tiene por qué traer el
/// reloj de anuncios de otro teléfono.
struct AdsPacingStore {
    let defaults: UserDefaults
    let key: String

    init(defaults: UserDefaults = .standard, key: String = "ads.pacing") {
        self.defaults = defaults
        self.key = key
    }

    /// Lo guardado, o un estado de arranque si no hay nada o está roto.
    func load() -> AdsPacingState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(AdsPacingState.self, from: data)
        else { return AdsPacingState() }
        return state
    }

    func save(_ state: AdsPacingState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }
}

/// El dueño del estado de la política de cortes naturales: cuenta las
/// sesiones, mide cuánto estuvo afuera el jugador, pregunta a
/// `NaturalBreakPolicy` y persiste lo que se mostró. La política es pura; esto
/// es la mínima cantidad de estado alrededor para usarla.
///
/// Lo crea la App (`ForcedAdsSetup.makePacer`, uno por proceso: cada construcción
/// cuenta un arranque en frío) y lo consulta `GameState+Ads` en cada corte:
/// `decide(_:context:)` con el contexto armado desde el juego y desde
/// `AdsCoordinator`; si dice `.show`, se muestra y **después** se llama
/// `recordShown(_:)`. El ciclo de vida lo alimenta con `didEnterBackground()` y
/// `didReturnFromBackground()`; el app open (`.returnFromBackground`) lo decide
/// `GameState+Ads` al volver.
@MainActor
final class ForcedAdsPacer {
    private(set) var pacing: AdsPacingState
    private(set) var session: AdsSession
    /// Se puede reemplazar en caliente cuando llega una config remota nueva.
    var policy: NaturalBreakPolicy

    private let store: AdsPacingStore
    private let now: @Sendable () -> Date
    private var backgroundedAt: Date?

    /// Construirlo ES el arranque en frío: suma una sesión y la persiste.
    init(
        policy: NaturalBreakPolicy = .default,
        store: AdsPacingStore = AdsPacingStore(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        var pacing = store.load()
        pacing.sessionNumber += 1
        store.save(pacing)
        self.pacing = pacing
        self.policy = policy
        self.store = store
        self.now = now
        self.session = AdsSession(startedAt: now(), secondsAway: nil)
    }

    /// La app se fue a background (o quedó inactiva). Se queda con el primer
    /// instante: `.inactive` llega antes que `.background`, y la ausencia
    /// empieza en el primero.
    func didEnterBackground() {
        if backgroundedAt == nil { backgroundedAt = now() }
    }

    /// La app volvió. Reinicia la gracia de sesión —el tiempo afuera no es
    /// tiempo de juego— y anota cuánto estuvo afuera para el app open.
    func didReturnFromBackground() {
        let instant = now()
        let away = backgroundedAt.map { instant.timeIntervalSince($0) }
        backgroundedAt = nil
        session = AdsSession(startedAt: instant, secondsAway: away)
    }

    /// Si en la próxima vuelta podría salir un app open: prendido (el
    /// interruptor de `ads.json`) y desde la sesión mínima. Lo demás (la
    /// ausencia, el cupo) se sabe recién al volver.
    var couldShowAppOpenOnReturn: Bool {
        policy.enabledFormats.contains(.appOpen) && pacing.sessionNumber >= policy.appOpenMinSessionNumber
    }

    /// Qué mostrar en este corte, si algo. No cambia nada: decidir no es
    /// mostrar, y el anuncio puede no llegar a la pantalla.
    func decide(_ naturalBreak: NaturalBreak, context: NaturalBreakContext) -> NaturalBreakDecision {
        policy.decide(naturalBreak, context: context, pacing: pacing, session: session, now: now())
    }

    /// Un formato forzado se mostró: cierra la ventana de 2 min para todos,
    /// avanza la alternancia y lo persiste.
    func recordShown(_ format: ForcedAdFormat) {
        pacing = policy.recording(format, in: pacing, at: now())
        store.save(pacing)
    }
}
