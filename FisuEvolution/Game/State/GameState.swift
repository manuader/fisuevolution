import EconomyKit
import Foundation
import Observation
import SwiftUI

/// The single source of truth shared by SwiftUI (HUD, popups) and SpriteKit (board).
///
/// Architecture (bible §4.1 + Docs/concurrency-conventions.md):
/// - `player` is the authoritative state but `@ObservationIgnored`: the income tick
///   mutates it every frame and MUST NOT invalidate SwiftUI.
/// - `tower` (F7) es el modelo de juego en memoria (pisos/slots); lo canónico del
///   save es `player.run.units` (por tipo) y `TowerReconciler` los reconcilia en
///   cada carga contra el mapeo `floors[]` vigente.
/// - SwiftUI observes cheap projections (`coinsText`, `spawnQuote`, prompts…) that
///   refresh on discrete events immediately and from the scene's 8 Hz flush.
/// - The scene reads `boardVersion` per frame and relayouts only on change.
@Observable @MainActor
final class GameState {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
        /// Hay un save pero no se pudo leer: no se juega ni se escribe nada hasta
        /// que el jugador reintente o empiece de nuevo.
        case recovery(UnreadableSave)
    }

    struct CareerPrompt: Identifiable, Equatable {
        let id = UUID()
        let options: [CharacterType]
        /// Slots del PISO VISIBLE (el merge diferido ocurre donde se arrastró).
        let sourceCell: Int
        let targetCell: Int
    }

    /// Modelo mínimo de la ficha abierta desde un personaje del tablero. Mantiene
    /// el slot para que despedir siga siendo una acción explícita y confirmable.
    struct CharacterSheet: Identifiable, Equatable {
        let id = UUID()
        let type: CharacterType
        /// Slot del piso visible.
        let cellIndex: Int
        let instanceCount: Int
        let isUnlocked: Bool
        let canAfford: Bool
        /// Se puede "dejar de contratar" si no es la última unidad de la torre.
        let canDismiss: Bool
    }

    struct OfflineReward: Identifiable, Equatable {
        let id = UUID()
        let amount: Double
    }

    /// Si el premio offline de ESTA vuelta ya se duplicó con un video. Se
    /// resetea en cada `applyOfflineProgressIfNeeded` que abre el popup, así
    /// que la oferta vuelve cada vez que volvés con ganancias — pero **una sola
    /// vez por vuelta**, o el mismo offline se cobraría diez veces.
    /// `@ObservationIgnored`: lo lee la hoja al abrirse, no un `body` que se
    /// recomponga.
    @ObservationIgnored var offlineRewardDoubled = false

    /// Si ya se cobró el cofre extra del cofre que se está mirando. Lo rearma
    /// `rearmExtraChestOffer()` en cada cofre abierto por otra vía.
    @ObservationIgnored var extraChestClaimed = false

    /// Skin recién ganada por milestone. Se publica una sola vez por skin (el
    /// crédito en MetaState es idempotente) para que la UI celebre sin volver a
    /// consultar el catálogo ni el estado.
    struct SkinAward: Identifiable, Equatable {
        let id: String
        let characterType: CharacterType
    }

    /// Lo que salió de un cofre recién abierto. El id es propio y no el de la
    /// pinta: el premio puede ser plata, y dos cofres seguidos que dan lo mismo
    /// tienen que ser dos presentaciones distintas para la vista.
    struct ChestReward: Identifiable, Equatable {
        let id = UUID().uuidString
        let outcome: ChestOutcome
        /// Cuánta plata pagó, cuando el premio es plata.
        ///
        /// Viaja acá y no adentro de `ChestOutcome` porque el sorteo no lo
        /// conoce: el monto sale de `passiveUnlockCost × factor`, que es
        /// economía del jugador y no del cofre. Y viaja porque la animación
        /// **apaga el HUD**: sin el número en el payload, la carta del premio de
        /// plata sería la única del juego que celebra sin decir cuánto.
        var coins: Double?
    }

    /// Proyección chica y estable para los controles de navegación de la torre.
    /// La UI no inspecciona `PlayerState` ni `TowerState`: recibe sólo el piso
    /// visible, su capacidad y los límites desbloqueados de la run actual.
    struct TowerNavigation: Equatable {
        let floorID: String
        let ordinal: Int
        let totalFloors: Int
        let occupied: Int
        let capacity: Int
        let canNavigateUp: Bool
        let canNavigateDown: Bool

        static let empty = TowerNavigation(
            floorID: "",
            ordinal: 0,
            totalFloors: 0,
            occupied: 0,
            capacity: 0,
            canNavigateUp: false,
            canNavigateDown: false
        )
    }

    /// Mensaje efímero que la escena o el HUD presenta sin conocer errores de
    /// EconomyKit. La lógica conserva el error tipado; la UI recibe intención.
    struct TowerNotice: Identifiable, Equatable {
        enum Kind: Equatable {
            case floorFull
            case destinationFloorFull(floorID: String)
            /// Un piso que antes no dejaba contratar ahora sí.
            case hireUnlocked(floorID: String)
        }

        let id = UUID()
        let kind: Kind
    }

    /// Los tres hitos del FTUE, como proyección `Equatable` para que publicarlos
    /// no invalide SwiftUI en cada `refreshProjections`.
    struct FTUEMilestones: Equatable {
        var tapped = false
        var spawned = false
        var merged = false
    }

    /// Qué pide iluminar el tutorial sobre el tablero.
    ///
    /// No se pide "el slot N": el slot lo resuelve la escena contra las
    /// unidades que hay de verdad, así que el recorte sigue cayendo bien
    /// aunque cambie el layout o el personaje se mueva.
    enum TutorialBoardTarget: Equatable {
        /// Cualquier unidad del piso visible (paso "tocá al Fisura").
        case anyUnit
        /// Una de un par mergeable, si existe (paso "arrastrá uno sobre otro").
        case mergePair
    }

    enum DropResolution {
        /// `evolvedTo` presente cuando el merge alcanzó un tier nuevo (reveal).
        /// `promotedToFloor` presente cuando el resultado ascendió de piso.
        case merged(
            targetCell: Int,
            evolvedTo: CharacterType?,
            promotedType: CharacterType?,
            promotedToFloor: Int?,
            unlockedFloorId: String?
        )
        case moved
        case careerPending
        case snapBack
    }

    // MARK: Observed projections (UI)

    // ⚠️ Niveles de acceso: `GameState` vive partido en siete archivos
    // (`GameState+*.swift`). En Swift `private` alcanza al tipo y a sus
    // extensiones **del mismo archivo**, así que todo lo que escribe un dominio
    // que se mudó tuvo que dejar de ser `private(set)`. Cada uno de esos lleva
    // anotado quién lo escribe; lo que sigue `private(set)` es lo que sólo
    // escribe este archivo (en la práctica, `refreshProjections`).

    private(set) var phase: Phase = .loading
    var isRecoveryPending: Bool {
        if case .recovery = phase { true } else { false }
    }
    private(set) var coinsText = "0"
    private(set) var boardVersion = 0
    /// Cotización del tier base del piso donde CAE la contratación (F7 §3.3):
    /// el visible, o el de abajo cuando el gate cerró el visible. Lleva su
    /// `floorOrdinal`, así que `buySpawn` contrata donde corresponde sin
    /// recalcular nada.
    ///
    /// ⚠️ **Ya no tiene consumidor de UI.** `SpawnButtonView` —el único que la
    /// dibujaba— murió con la barra inferior, y FisuJobs cotiza por TIPO
    /// (`jobRows` / `hireCharacter`, en `+Hiring`) y no por el tier base del
    /// piso visible. Sigue publicada porque de ella salen `canAffordSpawn` —que
    /// el tutorial usa para saber si ya te alcanza para contratar— y los tests
    /// de `GameLoopWiringTests` que pinean la curva de precio.
    private(set) var spawnQuote: HireQuote?
    /// La lee `TutorialOverlay` (`Completion.earnedEnoughToHire`): es la única
    /// forma de preguntar "¿ya junta para el primer laburo?" sin que el tutorial
    /// tenga que cotizar por su cuenta.
    private(set) var canAffordSpawn = false
    /// La oferta del botón "contratar al mejor" de la pantalla principal, o
    /// `nil` cuando no hay nada contratable (y entonces el botón no se dibuja).
    ///
    /// Publicada y no computada —al revés que `jobRows`— porque es UNA fila y la
    /// dibuja la pantalla que está siempre en cámara: recalcularla en cada
    /// invalidación de SwiftUI cotizaría los 43 tipos a mano alzada, mientras
    /// que acá sale del flush de 8 Hz y escribe sólo si cambió.
    private(set) var bestHire: BestHire?
    private(set) var unitCount = 0
    /// F7: reencarnación disponible = vas a ganar ≥1 ORO.
    private(set) var prestigeAvailable = false
    /// El botón de reencarnar EXISTE desde el piso configurado
    /// (`oro.prestigeTeaserFloorId`, hoy "lujo") aunque todavía no haya ORO
    /// por cobrar: muestra el progreso hacia el próximo en vez de la ganancia.
    private(set) var prestigeTeaser = false
    private(set) var oroText = "0"
    /// RF-16: el antes/después del multiplicador. Lo escribe `+Prestige`.
    var prestigePreview = PrestigePreview.empty
    private(set) var ownedSkins: [String] = []
    /// Hay una mejora PAGABLE en la pantalla de Mejoras (personaje, pasivo o
    /// permanente). Es la señal del gating de su lección: se calcula barato en
    /// `refreshProjections` cotizando costos crudos — NO sale de
    /// `characterUpgradeRows`, que arma textos localizados por fila y es cara.
    private(set) var canAffordAnyUpgrade = false
    /// Hay una mejora PERMANENTE (de ORO) pagable: la señal de la lección del
    /// primer ORO.
    private(set) var canAffordAnyOroUpgrade = false
    /// Cuántos pisos están desbloqueados. La lección del ascensor espera al
    /// segundo: con uno solo, el mapa es una lista de candados.
    private(set) var unlockedFloorsCount = 0
    /// Hay al menos un logro conseguido y sin cobrar. Es la resta de sets
    /// `unlockedAchievements − claimedAchievements` publicada acá porque
    /// `player` es `@ObservationIgnored`: la leen el badge del tab Menú, la
    /// tarjeta de Logros y el gating de su lección.
    private(set) var hasClaimableAchievements = false
    /// Hay al menos un cofre de pintas esperando que lo abran. Es
    /// `pendingChestCount > 0` publicado, y existe por lo MISMO que su vecino de
    /// arriba: `player` es `@ObservationIgnored`, así que la cuenta —computada al
    /// leerse, en `+Chests`— no invalida SwiftUI. La barra de abajo no tiene
    /// timer ni ninguna otra dependencia observable, así que sin esta proyección
    /// su puntito no aparecería hasta que otra cosa la despertara.
    ///
    /// ⚠️ La cuenta sigue siendo la fuente de verdad: `openChest()` cotiza contra
    /// ella y no contra esto, que se refresca a 8 Hz y llega tarde a las dos
    /// llamadas seguidas de `debugOpenChest()`.
    private(set) var hasPendingChests = false
    /// Invalida la ficha cuando llega un entitlement, milestone o equipamiento.
    /// Lo escriben `+Store` (entitlements y equipar) y `+Debug`.
    var skinSelectionVersion = 0
    /// Lo escribe `+Bonus`: el evento que arranca y el que vence.
    var activeEvent: EventManager.ActiveEvent?
    /// Lo escribe `+Actions`: el drop del merge y su descarte.
    var specialDrop: SpecialsConfig.Special?
    /// Lo escribe `+Bonus`: el daily que se reclama y su descarte.
    var dailyClaim: DailyRewardManager.Claim?
    /// Lo escribe `+Bonus`: la oferta de share card y su descarte.
    var shareCardSubject: CharacterType?
    /// Los bonus temporales corriendo, para los contadores del HUD.
    ///
    /// No llevan el tiempo restante adentro (ver `ActiveBonus`), así que este
    /// array sólo cambia cuando un bonus arranca o se muere: la cuenta
    /// regresiva no invalida SwiftUI. Lo arma `+Bonus`, lo escribe
    /// `refreshProjections`.
    private(set) var activeBonuses: [ActiveBonus] = []
    private(set) var showTapHint = false
    private(set) var showMergeHint = false
    /// Espejo OBSERVABLE de las tres banderas del FTUE.
    ///
    /// `ftueTapped`/`ftueSpawned`/`ftueMerged` son `@ObservationIgnored` porque
    /// las escriben las acciones decenas de veces por segundo junto al resto del
    /// estado. El tutorial (RF-01) avanza **por acción y no por toque**, así que
    /// necesita verlas desde una vista: esto las publica una sola vez por
    /// `refreshProjections`, escribiendo sólo si cambiaron.
    private(set) var ftueMilestones = FTUEMilestones()
    /// La fase obligatoria del tutorial está corriendo (RF-01: tap → contratar
    /// → fusionar → cierre). Mientras es `true`, la cola de celebraciones sólo
    /// promueve lo que el tutorial pide (`+Celebrations`, `beginTutorialPhase`)
    /// y las lecciones contextuales todavía no existen.
    ///
    /// La fuente es `fisuTutorialDone` en `UserDefaults` —la misma bandera del
    /// overlay—, leída UNA vez en el bootstrap: la cola no lee `AppStorage`, le
    /// llega como estado. La apaga `tutorialPhaseFinished()`, que llama el
    /// overlay al cerrar (por el botón del final o por "Saltar").
    ///
    /// Sin `private(set)` por lo mismo que `showing`: la escribe
    /// `+Celebrations`, que es otro archivo. Nadie más la toca.
    var tutorialPhaseActive = false
    /// Qué quiere iluminar el tutorial en el TABLERO, o nil si el paso actual no
    /// es de tablero. Lo escribe el overlay; lo lee el frame loop de la escena.
    @ObservationIgnored var tutorialBoardTarget: TutorialBoardTarget?
    /// Una hoja de la barra (o el popup de prestigio) está tapando el tablero.
    /// Lo escribe `RootView` —es estado de SU `@State`, invisible desde acá— y
    /// lo lee el director de lecciones: un coach-mark que señala la barra
    /// inferior no puede nacer debajo de una hoja abierta.
    @ObservationIgnored var uiCoversBoard = false
    /// El director de lecciones corre solo (en cada refresh) en la app real;
    /// bajo XCTest arranca apagado —el mismo criterio que el gate del bootstrap
    /// y la `SKTestSession` de StoreManager— y cada test lo prende explícito:
    /// los tests de wiring cuentan con que nada se encole solo.
    @ObservationIgnored var tutorialLessonsAutorun =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    /// Recorte resuelto para `tutorialBoardTarget`, en puntos de la VISTA.
    ///
    /// Lo publica `BoardScene` porque es la única que sabe dónde quedó parado el
    /// personaje después de deambular: el ancla lógica del slot ya no alcanza
    /// desde que el reconciliador conserva la posición deambulada.
    var boardSpotlight: CGRect?
    /// Piso visible (ordinal 0-based). La escena lo consume vía boardVersion.
    /// Lo escriben `+Tower` (navegación) y `+Debug` (fixture de UI test).
    var visibleFloorOrdinal = 0
    /// Estado listo para la pill y las flechas de F7.2.
    private(set) var towerNavigation = TowerNavigation.empty
    /// Income pasivo agregado de todos los pisos, aunque no estén en cámara.
    private(set) var towerIncomePerSecond = 0.0
    private(set) var towerIncomePerSecondText = "0"
    private(set) var visibleFloorIsUnlocked = false
    var towerNotice: TowerNotice?
    /// El logro recién conseguido que está en pantalla. Lo escribe
    /// `+Achievements`.
    var achievementToast: AchievementToast?
    /// Los que esperan turno. Abrir un piso puede cerrar tres logros a la vez y
    /// el banner dura 2,4 s: sin cola el jugador vería uno solo. Va
    /// `@ObservationIgnored` porque lo único que la UI mira es el de adelante.
    @ObservationIgnored var pendingAchievementToasts: [AchievementToast] = []
    /// Se incrementa al comprar upgrades/activar boosts: las vistas que leen
    /// `player` directo lo observan para re-renderizar.
    /// Lo escriben `+Upgrades` (las dos compras) y `+Bonus` (boosts y shares).
    var effectsVersion = 0
    var careerPrompt: CareerPrompt?
    var characterSheet: CharacterSheet?
    /// La carta informativa de un special ACTIVO del tablero, reabierta por el
    /// jugador manteniendo apretado al personaje (pedido del dueño,
    /// 2026-08-21: poder volver a ver qué beneficio te está dando). No pasa
    /// por la cola de celebraciones: como la ficha, la pidió él.
    var specialInfo: SpecialsConfig.Special?
    var offlineReward: OfflineReward?
    var skinAward: SkinAward?
    /// El premio del cofre que el jugador acaba de abrir. Lo escribe `+Chests`
    /// (`openChest`) y lo suelta el dismiss de su animación, como `skinAward`.
    ///
    /// ⚠️ **El dismiss tiene que ponerlo en `nil` ANTES de llamar a
    /// `celebrationFinished(.chestOpening)`**, con el patrón que `RootView` ya usa
    /// para el sheet de la skin: un `Binding` cuyo `set:` limpia el payload y un
    /// `onDismiss:` que cierra el turno.
    ///
    /// Si el payload sobrevive a su turno, `syncCelebrations` lo reencola en el
    /// mismo frame y **congela la cola entera**. No es "se reencola y molesta":
    /// `.chestOpening` no tiene `timeout` —el watchdog nunca lo vence— ni es
    /// salteable —el tap nunca lo saltea—, así que `showing` queda pegado para
    /// siempre y `celebrationHidesUI` en `true`. El HUD apagado, ninguna otra
    /// celebración pudiendo tomar el turno, y nada que lo destrabe salvo
    /// reiniciar la app.
    var chestReward: ChestReward?
    /// La lección contextual que está esperando turno o en pantalla, o `nil`.
    /// La escribe `+TutorialTips` (el director) y la suelta `releasePayload`.
    var tutorialTip: TutorialTip?

    /// Qué celebración tiene el turno. **Es la única fuente que miran las
    /// vistas** para decidir si les toca aparecer: los payloads siguen donde
    /// estaban, pero ahora se muestran de a uno.
    ///
    /// Sin `private(set)` por lo mismo que `player`: lo escribe `+Celebrations`,
    /// que es otro archivo. Nadie más lo toca.
    var showing: CelebrationKind?
    /// Durante la celebración a pantalla completa el resto de la UI se va a
    /// **opacidad 0**: el reveal ocupa el centro de la pantalla y nada tiene que
    /// competirle. Sólo esa celebración lo hace — un toast de logro de 4 s no
    /// justifica apagar la interfaz entera.
    ///
    /// Y dentro de esa celebración, sólo cuando hay **algo nuevo** que mostrar.
    /// El dueño lo pidió en dos frases, y son dos causas independientes:
    ///
    /// > "la animacion de personaje subiendo al siguiente piso debe esconder la ui
    /// > unicamente si es la primera vez que se desbloquea ese piso."
    /// > "la animacion de nuevo personaje si debe esconder la UI. siempre.
    /// > independientemente de si se desbloquea un piso nuevo o no."
    ///
    /// O sea: personaje nuevo **o** piso nuevo. El único caso que deja la interfaz
    /// en pantalla es el ascenso de un personaje ya conocido a un piso ya abierto
    /// —el que el jugador ve todo el tiempo una vez que la torre arrancó—, y ahí
    /// apagar el HUD sólo le esconde monedas y botones que está usando. La
    /// animación se reproduce igual en los tres casos: lo único condicional es
    /// esto.
    var celebrationHidesUI = false


    // MARK: Authoritative state

    /// La cola que hace que las celebraciones se reproduzcan de a una.
    /// Reemplazó a la cadena a mano (`celebrationChainActive` + dos campos
    /// `pending*`), que cubría un solo camino: el ascenso que abre piso.
    @ObservationIgnored var celebrations = CelebrationQueue()
    /// Si la celebración del tablero que tiene (o va a tener) el turno trae algo
    /// nuevo: un personaje que no se había visto, un piso que no estaba abierto,
    /// o las dos cosas. Es lo único que apaga la UI (ver `celebrationHidesUI`).
    ///
    /// Es un PAYLOAD, y por eso vive acá y no en la cola: `CelebrationQueue` es
    /// pura y guarda turnos, no contenidos, igual que `skinAward` o `dailyClaim`.
    /// Lo escribe `celebrateBoard` y lo suelta `releasePayload`, en
    /// `+Celebrations`.
    @ObservationIgnored var boardCelebrationShowsSomethingNew = false
    /// El evento cuyo banner ya tuvo su turno. Sin esto el banner se reencolaría
    /// para siempre: el evento sigue activo 30 s y el banner se cierra a los 6.
    @ObservationIgnored var announcedEventID: String?

    /// Era `private(set)`. Lo mutan los seis dominios: cada acción del jugador
    /// escribe el estado autoritativo y ninguno vive ya en este archivo.
    @ObservationIgnored var player: PlayerState?
    /// La torre en memoria (pisos/slots). No se serializa: se reconstruye por
    /// reconciliación desde `run.units` en cada carga.
    /// Era `private(set)` por el mismo motivo que `player`.
    @ObservationIgnored var tower: TowerState?
    private(set) var content: GameContent?
    @ObservationIgnored var debugTimeScale: Double = 1

    /// La usan `+Actions`, `+Prestige`, `+Upgrades` y `+Bonus`.
    var economy: StandardEconomy?
    private var repository: PlayerStateRepository?
    private let injectedRepository: PlayerStateRepository?
    /// El guardado diferido de `scheduleSave`; `+Lifecycle` lo cancela al sellar,
    /// porque el guardado de la salida va por `sealTask`.
    @ObservationIgnored var saveTask: Task<Void, Never>?
    /// `beginBackgroundTask` detrás de un protocolo; lo usa `+Lifecycle`.
    @ObservationIgnored var backgroundTasks: (any BackgroundTaskRunning)?
    /// Falso desde que la app deja `.active` hasta que vuelve: en ese tramo el
    /// tick no cobra (lo paga el offline), el flush no arma nada y el sello de la
    /// salida no se corre.
    @ObservationIgnored var isSceneActive = true
    /// El guardado de `seal(now:stamping:)`; los tests lo esperan.
    @ObservationIgnored var sealTask: Task<Void, Never>?
    @ObservationIgnored var lastHeartbeatAt: TimeInterval = 0
    static let heartbeatSeconds: TimeInterval = 15
    /// Lo consumen `+Actions` (crítico/dorado y el drop de special) y `+Bonus`.
    @ObservationIgnored var rng = SystemRandomNumberGenerator()
    /// Los usan `+Actions` (merge/tap) y `+Prestige`.
    @ObservationIgnored var gameCenter: GameCenterManager?
    /// Los usan `+Actions`, `+Prestige` y `+Upgrades`.
    @ObservationIgnored var haptics: HapticsManager?
    /// Los usan `+Actions`, `+Prestige` y `+Bonus`.
    @ObservationIgnored var audio: AudioManager?
    /// Los anuncios. `@ObservationIgnored` como los otros servicios: el estado
    /// del inventario de anuncios no dibuja nada.
    @ObservationIgnored var ads: AdsCoordinator?
    /// Las tres banderas del FTUE las escribe `+Actions` y las lee este archivo
    /// en `refreshProjections`.
    @ObservationIgnored var ftueTapped = UserDefaults.standard.bool(forKey: "ftue.tapped")
    @ObservationIgnored var ftueSpawned = UserDefaults.standard.bool(forKey: "ftue.spawned")
    @ObservationIgnored var ftueMerged = UserDefaults.standard.bool(forKey: "ftue.merged")
    @ObservationIgnored private var cloudSync: CloudSaveSync?
    /// El scheduler de eventos vive entero en `+Bonus`.
    @ObservationIgnored var nextEventAt: TimeInterval = .infinity
    @ObservationIgnored var eventLastFired: [String: TimeInterval] = [:]

    init(repository: PlayerStateRepository? = nil) {
        self.injectedRepository = repository
    }

    /// Servicios opcionales detrás de feature flags (Game Center, CloudKit).
    func attachGameCenter(_ manager: GameCenterManager) {
        gameCenter = manager
    }

    func attachHaptics(_ manager: HapticsManager) {
        haptics = manager
    }

    /// Los anuncios. Los usa `+Prestige` (interstitial post-reencarnación) y
    /// el cierre del popup de offline; nunca el frame loop.
    func attachAds(_ coordinator: AdsCoordinator) {
        ads = coordinator
    }

    /// Si ESTE instante es un buen momento para tapar la pantalla con un
    /// interstitial.
    ///
    /// El pedido del dueño fue "un anuncio cada 5 o 10 minutos de juego"; el
    /// reloj que cuenta eso vive en `AdsCoordinator`. Esta propiedad contesta la
    /// otra mitad —**dónde** se puede— y las cuatro condiciones son cada una un
    /// caso que se ve horrible si se saltea:
    ///
    /// - `phase == .ready`: no durante la carga.
    /// - `!uiCoversBoard`: no encima de una hoja abierta; sería un anuncio
    ///   sobre un panel que el jugador estaba leyendo.
    /// - `celebrations.current == nil`: no encima de un ascenso, un cofre o un
    ///   premio. Es el momento de más dopamina del juego y taparlo con
    ///   publicidad es la peor decisión posible.
    /// - `!tutorialPhaseActive`: nunca durante el tutorial. Un jugador que
    ///   todavía no entendió el juego y come un anuncio, desinstala.
    ///
    /// ⚠️ Que sea "buen momento" NO alcanza para mostrar nada: también tiene que
    /// tocarle por reloj. Las dos mitades se juntan en
    /// `showInterstitialIfArmed()`, y ninguna de las dos sirve sola.
    var isSafeMomentForInterstitial: Bool {
        phase == .ready
            && !uiCoversBoard
            && celebrations.current == nil
            && !tutorialPhaseActive
    }

    /// Pide un interstitial si le toca Y estamos en un buen momento. La llama la
    /// UI al volver al tablero desde una pantalla.
    func showInterstitialIfAppropriate() async {
        guard isSafeMomentForInterstitial else { return }
        await ads?.showInterstitialIfArmed()
    }

    func attachAudio(_ manager: AudioManager) {
        audio = manager
    }

    func attachBackgroundTasks(_ runner: any BackgroundTaskRunning) {
        backgroundTasks = runner
    }

    /// La escena pide feedback háptico sin conocer al manager.
    func playHaptic(_ pattern: HapticsManager.Pattern) {
        haptics?.play(pattern)
    }

    /// Un ascenso no es un merge más: la unidad se muda de piso. Se le da un
    /// acento propio para que se distinga del merge que se queda en el lugar.
    func playAscentFeedback() {
        haptics?.play(.evolution)
        audio?.play(.rare)
    }

    /// Abrir un piso es el hito grande del loop de la torre; lleva el acento más
    /// fuerte que tenemos, a la par de la reencarnación.
    func playFloorUnlockFeedback() {
        haptics?.play(.rarity)
        audio?.play(.prestige)
    }

    // MARK: Bootstrap

    func bootstrap() async {
        do {
            let content = try GameContentLoader.load(from: .main)
            self.content = content
            self.economy = StandardEconomy(config: content.economy)
            UIArt.configure(available: Set(content.manifest.ui.keys))

            let repository = self.repository ?? injectedRepository ?? PlayerStateRepository(
                persistence: PersistenceController(),
                snapshotURL: PlayerStateRepository.defaultSnapshotURL(),
                backups: SaveBackupStore(directory: SaveBackupStore.defaultDirectory())
            )
            self.repository = repository

            // Infra de UI tests: estado limpio y determinístico por launch argument.
            var forceNewGame = false
            #if DEBUG
            forceNewGame = ProcessInfo.processInfo.arguments.contains("--uitest-reset")
            applyLaunchArgumentDefaults(forceNewGame: forceNewGame)
            #endif

            if content.flags.cloudKitEnabled {
                cloudSync = CloudSaveSync()
            }

            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitest-unreadable-save") {
                await repository.debugWriteUnreadableSave()
            }
            #endif
            var loaded: SaveLoadResult = .empty
            if !forceNewGame {
                loaded = await repository.load()
            }
            let isFreshInstall: Bool
            switch loaded {
            case .loaded(let saved):
                var resolved = saved
                if let cloudSync, let remote = try? await cloudSync.fetch() {
                    resolved = SaveConflictResolver.resolve(local: saved, remote: remote)
                }
                player = resolved
                isFreshInstall = false
                Log.lifecycle.info("save loaded: prestige \(resolved.meta.prestigeLevel), maxTier \(resolved.run.maxTierReached)")
            case .empty:
                let fresh = newGame(content: content)
                player = fresh
                await repository.save(fresh)
                isFreshInstall = true
                Log.lifecycle.info("new game started")
            case .unreadable(let info):
                phase = .recovery(info)
                return
            }
            finishBootstrap(isFreshInstall: isFreshInstall)
        } catch let error as GameError {
            Log.lifecycle.critical("bootstrap failed: \(error.debugDetail)")
            assertionFailure(error.debugDetail)
            phase = .failed(error.localizedDescription)
        } catch {
            Log.lifecycle.critical("bootstrap failed: \(error)")
            assertionFailure("\(error)")
            phase = .failed(String(localized: "error.content.message"))
        }
    }

    private func newGame(content: GameContent) -> PlayerState {
        PlayerState.newGame(
            startTypeId: content.tiers.baseType.id,
            startFloorId: content.floorTable[0].id,
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: content.economy.critChanceBase,
            now: Date().timeIntervalSince1970
        )
    }

    func retryLoad() async {
        guard isRecoveryPending else { return }
        phase = .loading
        await bootstrap()
    }

    /// Empieza una partida nueva. La copia ilegible ya quedó en `SaveBackups/`; si al
    /// arrancar no se pudo escribir, se reintenta ahora que el snapshot todavía está.
    func startOverFromRecovery() async {
        guard isRecoveryPending, let content, let repository else { return }
        repository.keepSnapshotCopy()
        let fresh = newGame(content: content)
        player = fresh
        phase = .loading
        await repository.save(fresh)
        finishBootstrap(isFreshInstall: true)
    }

    /// Todo lo que va después de tener un `player`: la torre, los fixtures de DEBUG, el
    /// tutorial, offline y daily, y el paso a `.ready`. Lo comparten el arranque normal y
    /// `startOverFromRecovery`.
    private func finishBootstrap(isFreshInstall: Bool) {
        guard let content else { return }
        reconcileTower()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-unlock-tower") {
            debugUnlockFloors(throughTier: 5)
        }
        // RF-05: el menú de mejoras lista lo que el jugador VIO, no los pisos
        // que abrió, así que abrir la torre no alcanza para tener varias
        // filas en pantalla.
        if ProcessInfo.processInfo.arguments.contains("--uitest-seen-types") {
            // Hasta 8 y no hasta 6 para que entre "Empleado de Fast Food":
            // el nombre más largo del tramo, que es el que muestra si el
            // encabezado aguanta al lado de la carita grande.
            debugMarkTypesSeen(throughTier: 8)
        }
        // Las skins de milestone de los personajes que el jugador YA vio.
        // Ganarlas jugando pide abrir pisos o reencarnar, así que sin esta
        // puerta el Customization Shop no tiene una sola pinta que ponerse y
        // no hay forma de ejercer "Ponérsela". Va DESPUÉS de
        // `--uitest-seen-types` porque se apoya en lo que ese marcó.
        if ProcessInfo.processInfo.arguments.contains("--uitest-skins"), let player {
            let seen = player.run.seenTypes
            grantMilestoneSkinsForTests(
                content.skins.skins
                    .filter { $0.isMilestone && seen.contains($0.characterType) }
                    .map(\.id)
            )
        }
        // Y su opuesto: la pinta de alguien que el jugador NUNCA vio, que es
        // lo que un cofre reparte casi siempre. Va DESPUÉS del de arriba por
        // el mismo motivo —se apoya en `seenTypes`— y separado porque son
        // los dos lados del criterio de Pintas: uno deja las dos pantallas
        // listando lo mismo y el otro las separa.
        if ProcessInfo.processInfo.arguments.contains("--uitest-unseen-skin") {
            debugGrantUnseenChestSkin()
        }
        // El Fisura con el multiplicador al tope. Llegar jugando pide
        // comprar las 19 mejoras de la línea: sin esta puerta, el estado
        // "Al máximo" de la fila no se puede ni fotografiar ni ejercitar.
        if ProcessInfo.processInfo.arguments.contains("--uitest-char-upgrades-maxed"),
           var player {
            player.run.charUpgradeLevels["homeless"] = content.economy.charUpgrades.maxLevel
            self.player = player
        }
        // RF-16: el ORO va con la raíz de lifetime/divisor, así que llegar
        // al prestigio jugando no es automatizable. El fixture lo acredita —
        // derivado de la config y no un literal, que es lo que se rompía en
        // silencio cada vez que el balance movía el divisor.
        if ProcessInfo.processInfo.arguments.contains("--uitest-prestige") {
            giveEarningsForPrestigeTesting(oro: 9)
        }
        // El primer Fisura cuesta 25 y un tap rinde 1: llegar a contratar
        // jugando son ~25 toques sobre un personaje que deambula. El fixture
        // acredita la plata para que el test del tutorial mida el TUTORIAL y
        // no la puntería del runner.
        if ProcessInfo.processInfo.arguments.contains("--uitest-coins") {
            debugGrantCoins()
        }
        // La tira del calendario de Regalos con días ya cobrados atrás. Va
        // ANTES del claim automático de más abajo a propósito: en una partida
        // nueva ese claim no corre (FTUE) y sólo marca `lastClaimDay`, así que
        // el `cycleDay` que se pone acá es el que termina en pantalla.
        if ProcessInfo.processInfo.arguments.contains("--uitest-daily-streak") {
            debugSetDailyCycleDay(4)
        }
        // El popup de ganancias offline, con su oferta de duplicar por
        // video. El camino real pide cerrar la app y volver horas después
        // CON producción pasiva armada; una partida nueva produce 0/s y el
        // offline acredita cero, así que la hoja no aparecería. El fixture
        // entrega el estado final — el porqué está en
        // `debugPresentOfflineReward`.
        if ProcessInfo.processInfo.arguments.contains("--uitest-offline") {
            debugPresentOfflineReward(amount: 12_345)
        }
        // El primer special del catálogo, cayendo ya mismo: el drop real es
        // RNG sobre merges (la carta no se puede ni fotografiar ni
        // ejercitar sin suerte) y activarlo deja al personaje en el
        // tablero, que es lo que necesita el recap del mantener-apretado.
        if ProcessInfo.processInfo.arguments.contains("--uitest-special") {
            debugDropFirstSpecial()
        }
        // Un cofre abierto, con su animación esperando el primer toque. El
        // camino real pide dos pisos desbloqueados o un video con cooldown,
        // así que sin la puerta el smoke de la animación mediría la suerte.
        if ProcessInfo.processInfo.arguments.contains("--uitest-chest") {
            debugOpenChest()
        }
        // Tres logros conseguidos y sin cobrar: es la única forma de ver la
        // sección "Para cobrar" de la pantalla de Logros con algo adentro.
        // Va DESPUÉS de los otros fixtures a propósito —`--uitest-coins`
        // mueve `lifetimeEarnings` y cruza su propio logro— para que su
        // `evaluateAchievements()` acredite todo de una pasada.
        if ProcessInfo.processInfo.arguments.contains("--uitest-achievements") {
            debugSeedAchievements()
        }
        // El long-press sobre SpriteKit no es determinista en el runner: para
        // el smoke de la ficha alcanza con abrirla sobre la primera unidad.
        if ProcessInfo.processInfo.arguments.contains("--uitest-open-sheet"),
           let slot = visiblePlacements.first?.slot {
            presentCharacterSheet(cellIndex: slot)
        }
        // El fork de carrera, abierto.
        //
        // Es la pantalla más cara de alcanzar del juego: hay que llegar a T9
        // y fusionar el par, o sea horas de partida, y una vez elegida NO
        // vuelve a aparecer hasta la próxima reencarnación. Sin esta puerta
        // no se puede ni fotografiar ni ejercitar — y de hecho es la única
        // pantalla que quedó sin un solo test de UI, que es exactamente por
        // qué se hizo vieja sin que nadie lo notara.
        if ProcessInfo.processInfo.arguments.contains("--uitest-career") {
            debugPresentCareerChoice()
        }
        #endif
        // El tutorial entra a la cola ANTES de que nadie encole nada: el
        // offline, el daily del día 2 y los logros de un save viejo pasan
        // todos por `syncCelebrations`, y el gate tiene que estar puesto
        // primero o alguno toma el turno con el tutorial arriba (el
        // deadlock medido el 2026-08-21: sheet gateado que nunca se
        // presenta y cola congelada).
        //
        // Bajo XCTest no: el host de los unit tests arranca con los
        // defaults en cualquier estado y cada test arma su propio
        // escenario con `beginTutorialPhase()` (mismo criterio que
        // `StoreManager` con su `SKTestSession`).
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            if !UserDefaults.standard.bool(forKey: "fisuTutorialDone") {
                beginTutorialPhase()
            } else {
                // La lección de Tienda espera a la SEGUNDA sesión con la
                // fase hecha ("una vez, suave": nunca en el mismo arranque
                // en el que el jugador recién aprendió a jugar).
                let sessions = UserDefaults.standard.integer(forKey: Self.sessionsAfterPhaseKey)
                UserDefaults.standard.set(sessions + 1, forKey: Self.sessionsAfterPhaseKey)
            }
        }
        applyOfflineProgressIfNeeded()
        // El primer launch de una cuenta nueva no reclama daily: el jugador
        // todavía no jugó y el popup compite con el tutorial (FTUE).
        if !isFreshInstall {
            claimDailyIfAvailable()
        } else if var player {
            player.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
            self.player = player
        }
        #if DEBUG
        // El popup del premio del día, abierto. Va DESPUÉS del bloque de
        // arriba porque es justamente ese bloque el que lo hace imposible:
        // una partida nueva marca `lastClaimDay` en HOY para no pisar el
        // tutorial, y el daily se cobra una sola vez por día. Sin esta
        // puerta, la única pantalla que celebra la racha no se puede ni
        // fotografiar ni ejercitar sin cambiarle la fecha al simulador.
        // Combinado con `--uitest-daily-streak` muestra el día 4.
        if ProcessInfo.processInfo.arguments.contains("--uitest-daily-popup") {
            debugClaimDailyAgain()
        }
        #endif
        scheduleNextEvent(from: Date().timeIntervalSince1970)
        // Una sola pasada post-carga: un save escrito ANTES de que
        // existieran los logros llega con medio catálogo ya ganado, y sin
        // esto quedaría esperando a la próxima fusión para enterarse.
        // Corre con `phase == .loading`, así que acredita sin toastear.
        evaluateAchievements()
        refreshProjections()
        phase = .ready
    }

    /// Reconstruye la torre desde `run.units` contra el mapeo vigente. Corre en
    /// cada carga: un remapeo tier→piso entre versiones reacomoda la partida en
    /// vez de romperla (spec §3.1). Arranca mirando el piso más alto desbloqueado.
    /// La llaman `+Prestige` (reencarnar) y `+Debug` (resetear el save).
    func reconcileTower() {
        guard let content, var player else { return }
        let before = player.run.units
        let outcome = TowerReconciler.reconcile(
            run: &player.run,
            floorTable: content.floorTable,
            tiers: content.tiers
        )
        self.player = player
        self.tower = outcome.tower
        if outcome.autoMerged > 0 || !outcome.discarded.isEmpty {
            Log.lifecycle.info("tower reconciled: autoMerged \(outcome.autoMerged), discarded \(outcome.discarded)")
            scheduleSave()
        } else if before != player.run.units {
            scheduleSave()
        }
        let unlockedOrdinals = content.floorTable.floors.enumerated()
            .filter { player.run.unlockedFloors.contains($0.element.id) }
            .map(\.offset)
        visibleFloorOrdinal = unlockedOrdinals.max() ?? 0
        updateMaxFloorStat()
    }

    /// Re-sincroniza la torre desde `run.units` SIN mover el piso visible
    /// (para mutaciones fuera de TowerActions, ej. instantEvolution).
    /// La llama `+Bonus`, que es donde vive el evento que muta `run.units`.
    func resyncTower() {
        guard let content, var player else { return }
        let outcome = TowerReconciler.reconcile(
            run: &player.run,
            floorTable: content.floorTable,
            tiers: content.tiers
        )
        self.player = player
        self.tower = outcome.tower
        updateMaxFloorStat()
    }

    /// La llaman `+Actions` (merge y carrera) y `+Bonus` (merge instantáneo y
    /// la unidad regalada por un evento).
    func updateMaxFloorStat() {
        guard let content, var player else { return }
        let maxUnlocked = content.floorTable.floors.enumerated()
            .filter { player.run.unlockedFloors.contains($0.element.id) }
            .map(\.offset).max() ?? 0
        if maxUnlocked > player.meta.stats.maxFloorOrdinalEver {
            player.meta.stats.maxFloorOrdinalEver = maxUnlocked
            self.player = player
        }
        awardEligibleMilestoneSkins()
        // El cofre de la torre se cuelga del mismo embudo por el mismo motivo, y
        // se defiende solo de correr en cada merge con su propio contador.
        awardFloorChestsIfDue()
        // Este método ya es el embudo de merges, ascensos y pisos nuevos: los
        // logros de fusión, tier, piso, skins y specials cuelgan de acá y no de
        // seis call sites que habría que mantener sincronizados.
        evaluateAchievements()
    }

    /// Milestones no dependen de la escena: cualquier unlock/reencarnación que
    /// actualice el estado de torre acredita una vez en MetaState. StoreKit usa
    /// `ownedSkins` aparte y por eso esta unión nunca borra una compra.
    private func awardEligibleMilestoneSkins() {
        guard let content, var player else { return }
        // Las skins de oro no se venden: la única vía es tener las siete líneas
        // de mejora permanente en su tope. El flag se calcula acá, que es donde
        // vive `upgradesConfig`; EconomyKit no conoce `upgrades.json` y pasárselo
        // ya resuelto lo deja puro.
        let lineasDeOro = content.upgradesConfig.upgrades.filter { $0.currency == .oro }
        // `>=` y no `==`, y hay que decir exactamente qué regala.
        //
        // Un save v3 llega acá con los niveles ya reescalados por
        // `SaveMigrator.rescaleUpgradeLevelsForRebalance`. Ese reescalado es
        // PROPORCIONAL Y REDONDEADO, no exacto, y en los dos bordes se nota:
        // redondea PARA ARRIBA hasta el tope (`income`/`tap` 19 → 10 y `crit`
        // 24 → 10 quedan maxeados sin haberlo estado) y redondea A CERO abajo
        // (`crit` 1 → 0 borra el único nivel que el jugador tenía). Los dos
        // casos son de un solo nivel de distancia y se aceptan: la alternativa
        // —guardar el nivel viejo para poder deshacer— pide un bump de schema.
        // Lo que el `>=` sí deja pasar, y es más grande, es un save **v4
        // anterior al rebalance de pacing**: uno con `crit` entre 10 y 24 no
        // había maxeado esa línea —con la curva vieja (3 × 2,5ⁿ) llegar a crit 10 costaba
        // ~19.100 ORO de los 1,776e10 que valía la línea, el 0,0001 %— y desde
        // el rebalance cuenta como tope y se lleva las skins doradas.
        //
        // Ese agujero lo cerró el bump a v5: `SaveMigrator.migrateV4toV5`
        // reconoce esos saves por su huella —algún nivel POR ENCIMA del tope de
        // hoy, imposible en uno post-rebalance— y reescala **sólo las líneas que
        // se pasan del tope**, no el save entero (decisión del dueño,
        // 2026-08-26: normalizar todo le borraba al jugador los niveles que
        // compró DESPUÉS del rebalance). O sea que un save pre-rebalance llega
        // acá con sus otras líneas intactas, y el `>=` de abajo las mira tal
        // como quedaron. Lo que sigue sin cubrir es la línea parada
        // EXACTAMENTE en el tope nuevo: `crit 10/25` (no maxeado) y `crit 10/10`
        // (maxeado) son idénticos en disco. De quince valores por línea quedó
        // uno, y taparlo pediría un campo que los saves viejos no tienen.
        // Lo que NO se regala es el efecto: las dos derivaciones clampean.
        let todoAlMaximo = !lineasDeOro.isEmpty && lineasDeOro.allSatisfy {
            (player.meta.oroUpgradeLevels[$0.id] ?? 0) >= $0.maxLevel
        }
        let newlyUnlocked = SkinMilestones.newlyUnlocked(
            state: player, config: content.skins, allUpgradesMaxed: todoAlMaximo
        )
        guard !newlyUnlocked.isEmpty else { return }
        player.meta.milestoneSkins = Array(Set(player.meta.milestoneSkins).union(newlyUnlocked)).sorted()
        self.player = player
        skinSelectionVersion &+= 1
        Log.economy.info("skin milestones awarded: \(newlyUnlocked)")

        // Se celebra UNA: encadenar popups interrumpe el loop, y el crédito ya
        // quedó hecho para todas. La ficha muestra el resto.
        //
        // Ya no hace falta preguntar si hay una cadena corriendo: se asigna el
        // payload y la cola decide cuándo le toca. `.skinAward` tiene menos
        // prioridad que `.boardCelebration`, así que el ascenso que la otorgó se
        // ve entero antes que el sheet.
        if let first = newlyUnlocked.sorted().first,
           let entry = content.skins.entry(id: first),
           let type = content.tiers.type(id: entry.characterType) {
            skinAward = SkinAward(id: first, characterType: type)
            syncCelebrations()
        }
    }

    // MARK: Frame loop (called by BoardScene)

    /// Passive income tick. Mutates only non-observed state — zero SwiftUI work.
    func tick(delta: TimeInterval) {
        guard isSceneActive, let content, var player else { return }
        IncomeTicker.tick(
            state: &player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            delta: delta * debugTimeScale,
            now: Date().timeIntervalSince1970
        )
        self.player = player
        // El watchdog de la cola de celebraciones corre acá y no en un `Timer`
        // (regla 2 de concurrencia). `delta` sin `debugTimeScale`: el time-warp
        // acelera la economía, no el tiempo que el jugador tiene para mirar. Con el
        // mismo tope que la plata: el primer frame tras volver del background trae
        // todo el salto, y el watchdog no debe darlo todo por vencido.
        advanceCelebrations(delta: min(delta, IncomeTicker.deltaClampThreshold))
    }

    /// 8 Hz projection flush driven by the scene's frame counter. Also prunes
    /// expired modifiers and fires scheduled events.
    ///
    /// Con la escena inactiva sólo proyecta: el regreso del background pasa por
    /// `.inactive` con la escena ya dibujando, y podar buffs, disparar el evento
    /// vencido o armar el anuncio ahí se adelanta a lo que `.active` resuelve
    /// (el offline integra los buffs que vencieron afuera, el evento se corre y
    /// la gracia de sesión se reinicia).
    func flushHUD() {
        let now = Date().timeIntervalSince1970
        if isSceneActive {
            if var player {
                let pruned = ModifierMath.prune(&player, now: now)
                if pruned {
                    self.player = player
                    scheduleSave()
                }
            }
            fireEventIfDue(now: now)
            beatIfDue(now: now)
            // El reloj del interstitial vive acá y no en un `Timer` (regla 2 de
            // concurrencia). Sólo ARMA la bandera —tres restas de fechas, barato a
            // 8 Hz—; el disparo lo pide la UI en una pausa natural. El porqué de
            // esa separación está en `AdsCoordinator.isInterstitialArmed`.
            ads?.armIfDue()
        }
        refreshProjections()
    }

    // MARK: Internals

    /// El piso donde cae la contratación: el visible, salvo que la compuerta lo
    /// haya cerrado y haya que bajar (lo que haga falta, no un piso). `nil` si
    /// desde acá no se contrata en ningún lado (piso visible todavía cerrado).
    /// La llaman `+Actions` (contratar) y `+Debug` (cotizar el regalo de coins).
    func hireTargetOrdinal(player: PlayerState) -> Int? {
        guard let content else { return nil }
        return TowerActions.hireTargetFloor(
            visibleOrdinal: visibleFloorOrdinal,
            unlockedFloors: player.run.unlockedFloors,
            maxTierReached: player.run.maxTierReached,
            floorTable: content.floorTable,
            config: content.economy
        )
    }

    /// La llaman `+Actions` (contratar) y `+Debug`.
    func currentQuote(player: PlayerState, floorOrdinal: Int) -> HireQuote? {
        guard let content else { return nil }
        let prestigeDiscount = content.prestigeUnlocks.cumulativeSpawnDiscount(atPrestigeLevel: player.meta.prestigeLevel)
        return TowerActions.hireQuote(
            floorOrdinal: floorOrdinal,
            state: player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            costMultiplier: 1 - prestigeDiscount,
            now: Date().timeIntervalSince1970
        )
    }

    /// La llaman los seis dominios: cualquier cambio que la escena tenga que
    /// redibujar pasa por acá.
    func bumpBoard() {
        boardVersion += 1
        refreshProjections()
    }

    /// Updates observed properties, writing only on real change so SwiftUI never
    /// invalidates spuriously.
    /// La llaman `+Actions`, `+Upgrades`, `+Bonus` y `+Debug`.
    func refreshProjections() {
        guard let content, let player else { return }

        // Único enganche de la cola de celebraciones: acá pasa todo lo que puede
        // haber creado una. Colgarlo de una sola función es lo que hace que
        // ningún call site pueda olvidarse de encolar (mismo criterio que
        // `evaluateAchievements` con `phase`).
        syncCelebrations()

        let newCoins = CoinFormatter.string(from: player.run.coins)
        if coinsText != newCoins { coinsText = newCoins }

        let target = hireTargetOrdinal(player: player)
        // Sin destino igual cotizamos el piso visible: el botón sigue mostrando
        // qué se vende acá aunque no se pueda comprar todavía.
        let quote = currentQuote(player: player, floorOrdinal: target ?? visibleFloorOrdinal)
        if spawnQuote != quote { spawnQuote = quote }

        let floorUnlocked = visibleFloorDef.map { player.run.unlockedFloors.contains($0.id) } ?? false
        if visibleFloorIsUnlocked != floorUnlocked { visibleFloorIsUnlocked = floorUnlocked }

        let targetFull = target.map { ordinal in
            let occupancy = floorOccupancy(ordinal: ordinal)
            return occupancy.occupied >= max(occupancy.capacity, 1)
        } ?? false
        let affordable = target != nil && !targetFull
            && (quote.map { player.run.coins >= $0.cost } ?? false)
        if canAffordSpawn != affordable { canAffordSpawn = affordable }

        let newBestHire = computeBestHire()
        if bestHire != newBestHire { bestHire = newBestHire }

        let total = player.run.totalUnits
        if unitCount != total { unitCount = total }

        let navigation = makeTowerNavigation(content: content, player: player)
        if towerNavigation != navigation { towerNavigation = navigation }

        let towerIncome = IncomeTicker.passivePerSecond(
            state: player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            now: Date().timeIntervalSince1970
        )
        if towerIncomePerSecond != towerIncome { towerIncomePerSecond = towerIncome }
        // El formatter de monedas redondea los valores sub-unitarios a 0, pero
        // en una tasa eso escondería income real al comienzo de la partida.
        let incomeText = towerIncome > 0 && towerIncome < 1
            ? towerIncome.formatted(.number.precision(.fractionLength(1)))
            : CoinFormatter.string(from: towerIncome)
        if towerIncomePerSecondText != incomeText { towerIncomePerSecondText = incomeText }

        let canReincarnate = economy.map { PrestigeCalculator.canReincarnate(state: player, economy: $0) } ?? false
        if prestigeAvailable != canReincarnate { prestigeAvailable = canReincarnate }

        let teaser = economy.map { eco -> Bool in
            guard let floorId = eco.config.oro.prestigeTeaserFloorId,
                  let ordinal = content.floorTable.floors.firstIndex(where: { $0.id == floorId })
            else { return false }
            return player.run.unlockedFloors.count > ordinal
        } ?? false
        if prestigeTeaser != teaser { prestigeTeaser = teaser }

        let oro = String(player.meta.oro)
        if oroText != oro { oroText = oro }

        refreshPrestigePreview()

        let skins = Array(player.meta.allOwnedSkins).sorted()
        if ownedSkins != skins { ownedSkins = skins }

        let bonuses = makeActiveBonuses(player: player, content: content)
        if activeBonuses != bonuses { activeBonuses = bonuses }

        let tapHint = !ftueTapped
        if showTapHint != tapHint { showTapHint = tapHint }
        var pairExists = false
        if !ftueMerged && ftueSpawned {
            pairExists = player.run.units.values.contains { $0 >= 2 }
        }
        let mergeHint = ftueSpawned && !ftueMerged && pairExists
        if showMergeHint != mergeHint { showMergeHint = mergeHint }

        let milestones = FTUEMilestones(tapped: ftueTapped, spawned: ftueSpawned, merged: ftueMerged)
        if ftueMilestones != milestones { ftueMilestones = milestones }

        let affordsUpgrade = computeCanAffordAnyUpgrade(player: player, content: content)
        if canAffordAnyUpgrade != affordsUpgrade { canAffordAnyUpgrade = affordsUpgrade }

        let affordsOro = computeCanAffordAnyOroUpgrade(player: player, content: content)
        if canAffordAnyOroUpgrade != affordsOro { canAffordAnyOroUpgrade = affordsOro }

        let floors = player.run.unlockedFloors.count
        if unlockedFloorsCount != floors { unlockedFloorsCount = floors }

        let claimable = !player.meta.unlockedAchievements
            .subtracting(player.meta.claimedAchievements).isEmpty
        if hasClaimableAchievements != claimable { hasClaimableAchievements = claimable }

        // ⚠️ **`canOpenChest` y no `pendingChestCount > 0`**: desde la regla de
        // desbloqueo (2026-08-28) se puede tener cofres y no poder abrir ninguno,
        // y un puntito que el jugador NO puede apagar se queda prendido un piso
        // entero. Es el mismo punto que usan logros y daily: entrenarlo a que a
        // veces miente los apaga a los tres.
        //
        // El costo extra —armar el conjunto de personajes alcanzables— sólo se
        // paga cuando hay cofres esperando, porque `canOpenChest` cotiza primero
        // contra el contador. Sin cofres, esto sigue siendo la misma comparación
        // de antes.
        let cofres = canOpenChest
        if hasPendingChests != cofres { hasPendingChests = cofres }

        refreshTutorialTip()
    }

    private func makeTowerNavigation(content: GameContent, player: PlayerState) -> TowerNavigation {
        let floors = content.floorTable.floors
        guard floors.indices.contains(visibleFloorOrdinal) else { return .empty }
        let visible = floors[visibleFloorOrdinal]
        let occupancy = visibleFloorOccupancy
        let unlocked = Set(player.run.unlockedFloors)
        let maxUnlocked = floors.enumerated()
            .filter { unlocked.contains($0.element.id) }
            .map(\.offset)
            .max() ?? 0
        let maxVisible = min(maxUnlocked + 1, floors.count - 1)
        return TowerNavigation(
            floorID: visible.id,
            ordinal: visibleFloorOrdinal,
            totalFloors: floors.count,
            occupied: occupancy.occupied,
            capacity: occupancy.capacity,
            canNavigateUp: visibleFloorOrdinal < maxVisible,
            canNavigateDown: visibleFloorOrdinal > 0
        )
    }

    /// La llaman los seis dominios: toda mutación persistible pasa por acá.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.persistNow()
        }
    }

    func persistNow(includingCloud: Bool = true) async {
        guard !isRecoveryPending, let repository, let player else { return }
        await repository.save(player)
        if includingCloud, let cloudSync {
            await cloudSync.push(player)
        }
    }
}
