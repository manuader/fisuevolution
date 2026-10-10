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
    // MARK: Carga y HUD (observado)

    // ⚠️ Niveles de acceso: `GameState` vive partido en varios archivos
    // (`GameState+*.swift`) y este sólo guarda las propiedades almacenadas. En
    // Swift `private` alcanza al tipo y a sus extensiones **del mismo archivo**,
    // así que nada de lo que escribe una extensión puede ser `private(set)`.
    // Las proyecciones las escribe `+Projections` (y `phase`/`content`,
    // `+Bootstrap`); el resto lleva anotado quién lo escribe.
    var phase: Phase = .loading
    var coinsText = "0"
    var boardVersion = 0
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
    var spawnQuote: HireQuote?
    /// La lee `TutorialOverlay` (`Completion.earnedEnoughToHire`): es la única
    /// forma de preguntar "¿ya junta para el primer laburo?" sin que el tutorial
    /// tenga que cotizar por su cuenta.
    var canAffordSpawn = false
    /// La oferta del botón "contratar al mejor" de la pantalla principal, o
    /// `nil` cuando no hay nada contratable (y entonces el botón no se dibuja).
    ///
    /// Publicada y no computada —al revés que `jobRows`— porque es UNA fila y la
    /// dibuja la pantalla que está siempre en cámara: recalcularla en cada
    /// invalidación de SwiftUI cotizaría los 43 tipos a mano alzada, mientras
    /// que acá sale del flush de 8 Hz y escribe sólo si cambió.
    var quickHireOffer: QuickHireOffer?
    var unitCount = 0
    /// El tier más alto cuyo personaje ya se reveló: lo lee el marcador de UI
    /// `board.revealed`, que sobrevive a las celebraciones que apagan la UI.
    var revealedTierMarker = 1

    // MARK: Prestigio, mejoras y logros (observado)

    /// F7: reencarnación disponible = vas a ganar ≥1 ORO.
    var prestigeAvailable = false
    /// El botón de reencarnar EXISTE desde el piso configurado
    /// (`oro.prestigeTeaserFloorId`, hoy "lujo") aunque todavía no haya ORO
    /// por cobrar: muestra el progreso hacia el próximo en vez de la ganancia.
    var prestigeTeaser = false
    var oroText = "0"
    /// RF-16: el antes/después del multiplicador. Lo escribe `+Prestige`.
    var prestigePreview = PrestigePreview.empty
    var ownedSkins: [String] = []
    /// Hay una mejora PAGABLE en la pantalla de Mejoras (personaje, pasivo o
    /// permanente). Es la señal del gating de su lección: se calcula barato en
    /// `refreshProjections` cotizando costos crudos — NO sale de
    /// `characterUpgradeRows`, que arma textos localizados por fila y es cara.
    var canAffordAnyUpgrade = false
    /// Hay una mejora PERMANENTE (de ORO) pagable: la señal de la lección del
    /// primer ORO.
    var canAffordAnyOroUpgrade = false
    /// Cuántos pisos están desbloqueados. La lección del ascensor espera al
    /// segundo: con uno solo, el mapa es una lista de candados.
    var unlockedFloorsCount = 0
    /// Hay al menos un logro conseguido y sin cobrar. Es la resta de sets
    /// `unlockedAchievements − claimedAchievements` publicada acá porque
    /// `player` es `@ObservationIgnored`: la leen el badge del tab Menú, la
    /// tarjeta de Logros y el gating de su lección.
    var hasClaimableAchievements = false
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
    var hasPendingChests = false
    /// Un boost gratis desbloqueado y sin enfriamiento: prende el punto de Regalos.
    var hasReadyBoost = false
    /// Las pestañas de la barra que el jugador ya tiene (PLAN-v2 E3). Las escribe
    /// `+Tabs` desde `refreshProjections`, sólo si cambiaron.
    var unlockedTabs: Set<GameScreen> = [.jobs, .upgrades]
    /// Las que se abrieron en esta instalación y todavía no se miraron: llevan
    /// "¡Nuevo!". Las escribe `+Tabs`.
    var newTabs: Set<GameScreen> = []
    /// Con `false` la barra está entera (corridas de UI sin
    /// `--uitest-progressive-tabs`). Lo apaga `+Debug`.
    @ObservationIgnored var progressiveTabsEnabled = true
    /// Invalida la ficha cuando llega un entitlement, milestone o equipamiento.
    /// Lo escriben `+Store` (entitlements y equipar) y `+Debug`.
    var skinSelectionVersion = 0
    /// Se incrementa al comprar upgrades/activar boosts: las vistas que leen
    /// `player` directo lo observan para re-renderizar.
    /// Lo escriben `+Upgrades` (las dos compras) y `+Bonus` (boosts y shares).
    var effectsVersion = 0
    /// El logro recién conseguido que está en pantalla. Lo escribe
    /// `+Achievements`.
    var achievementToast: AchievementToast?
    /// Los que esperan turno. Abrir un piso puede cerrar tres logros a la vez y
    /// el banner dura 2,4 s: sin cola el jugador vería uno solo. Va
    /// `@ObservationIgnored` porque lo único que la UI mira es el de adelante.
    @ObservationIgnored var pendingAchievementToasts: [AchievementToast] = []

    // MARK: Torre (observado)

    /// Piso visible (ordinal 0-based). La escena lo consume vía boardVersion.
    /// Lo escriben `+Tower` (navegación) y `+Debug` (fixture de UI test).
    var visibleFloorOrdinal = 0
    /// Estado listo para la pill y las flechas de F7.2.
    var towerNavigation = TowerNavigation.empty
    /// El piso donde está la cámara, continuo. Lo publica la escena en el flush
    /// de 8 Hz y lo lee la luz de la botonera; se escribe sólo si se movió más de
    /// una centésima, así que con la cámara quieta no invalida nada.
    private(set) var cameraFloor: Double = 0
    /// La geometría del tablero para el marcador `board.layout` de los tests.
    private(set) var boardLayoutMarker = ""
    /// Income pasivo agregado de todos los pisos, aunque no estén en cámara.
    var towerIncomePerSecond = 0.0
    var towerIncomePerSecondText = "0"
    var visibleFloorIsUnlocked = false
    var towerNotice: TowerNotice?
    /// Hasta cuándo dura el Corralito, o `nil`. Lo escribe `+Projections` sólo
    /// cuando empieza o termina, nunca por segundo.
    var spendingFrozenUntil: TimeInterval?

    // MARK: Eventos y bonus

    /// Lo escribe `+Bonus`: el evento que arranca y el que vence.
    var activeEvent: EventManager.ActiveEvent?
    /// Lo escribe `+Actions`: el drop del merge y su descarte.
    var specialDrop: SpecialsConfig.Special?
    /// Lo escribe `+Bonus`: el daily que se reclama y su descarte.
    var dailyClaim: DailyRewardManager.Claim?
    /// La tarjeta de compartir abierta. Lo escribe `+Share`.
    var shareCardMoment: ShareMoment?
    /// El momento viral ofrecido como botón. Lo escribe `+Share`.
    var shareOffer: ShareMoment?
    /// El momento que espera una pausa para ofrecerse. Lo escribe `+Share`.
    @ObservationIgnored var pendingShareMoment: ShareMoment?
    /// Con `false` no se ofrece nada (corridas de UI sin `--uitest-share`).
    @ObservationIgnored var shareOffersEnabled = true
    /// Los bonus temporales corriendo, para los contadores del HUD.
    ///
    /// No llevan el tiempo restante adentro (ver `ActiveBonus`), así que este
    /// array sólo cambia cuando un bonus arranca o se muere: la cuenta
    /// regresiva no invalida SwiftUI. Lo arma `+Bonus`, lo escribe
    /// `refreshProjections`.
    var activeBonuses: [ActiveBonus] = []
    /// El scheduler de eventos vive entero en `+Bonus`.
    @ObservationIgnored var nextEventAt: TimeInterval = .infinity
    @ObservationIgnored var eventLastFired: [String: TimeInterval] = [:]

    // MARK: Popups y premios

    var careerPrompt: CareerPrompt?
    var characterSheet: CharacterSheet?
    /// La carta informativa de un special ACTIVO del tablero, reabierta por el
    /// jugador manteniendo apretado al personaje (pedido del dueño,
    /// 2026-08-21: poder volver a ver qué beneficio te está dando). No pasa
    /// por la cola de celebraciones: como la ficha, la pidió él.
    var specialInfo: SpecialsConfig.Special?
    var offlineReward: OfflineReward?
    /// Si el premio offline de ESTA vuelta ya se duplicó con un video. Se
    /// resetea en cada `applyOfflineProgressIfNeeded` que abre el popup, así
    /// que la oferta vuelve cada vez que volvés con ganancias — pero **una sola
    /// vez por vuelta**, o el mismo offline se cobraría diez veces.
    /// `@ObservationIgnored`: lo lee la hoja al abrirse, no un `body` que se
    /// recomponga.
    @ObservationIgnored var offlineRewardDoubled = false
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
    /// Si ya se cobró el cofre extra del cofre que se está mirando. Lo rearma
    /// `rearmExtraChestOffer()` en cada cofre abierto por otra vía.
    @ObservationIgnored var extraChestClaimed = false

    // MARK: Tutorial y FTUE

    var showTapHint = false
    var showMergeHint = false
    /// Espejo OBSERVABLE de las tres banderas del FTUE.
    ///
    /// `ftueTapped`/`ftueSpawned`/`ftueMerged` son `@ObservationIgnored` porque
    /// las escriben las acciones decenas de veces por segundo junto al resto del
    /// estado. El tutorial (RF-01) avanza **por acción y no por toque**, así que
    /// necesita verlas desde una vista: esto las publica una sola vez por
    /// `refreshProjections`, escribiendo sólo si cambiaron.
    var ftueMilestones = FTUEMilestones()
    /// Las tres banderas del FTUE las escribe `+Actions` y las lee `+Projections`
    /// en `refreshProjections`.
    @ObservationIgnored var ftueTapped = UserDefaults.standard.bool(forKey: "ftue.tapped")
    @ObservationIgnored var ftueSpawned = UserDefaults.standard.bool(forKey: "ftue.spawned")
    @ObservationIgnored var ftueMerged = UserDefaults.standard.bool(forKey: "ftue.merged")
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
    /// Desde que la cola quedó vacía por última vez se fue alguna celebración grande
    /// (`CelebrationKind.endsInNaturalBreak`): al vaciarse, la cola es un corte natural.
    @ObservationIgnored var bigCelebrationSinceIdle = false
    /// Algo que no vive en el juego tapa la pantalla o no se puede interrumpir: el
    /// viaje en ascensor o una compra en curso. La App lo cablea; un corte natural
    /// no cae mientras sea verdad.
    @ObservationIgnored var fullScreenUIActive: @MainActor () -> Bool = { false }
    /// El director de lecciones corre solo (en cada refresh) en la app real;
    /// bajo XCTest arranca apagado —el mismo criterio que el gate del bootstrap
    /// y la `SKTestSession` de StoreManager— y cada test lo prende explícito:
    /// los tests de wiring cuentan con que nada se encole solo.
    @ObservationIgnored var tutorialLessonsAutorun =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    /// La cinemática que pidió turno (E8b). La suelta `releasePayload`, que la anota vista.
    var cinematic: CinematicID?
    /// Bajo XCTest y `--uitest*` las cinemáticas no corren solas (patrón
    /// `tutorialLessonsAutorun`): una de 5 s en medio de un test ajeno le tapa la pantalla.
    @ObservationIgnored var cinematicsAutorun =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    /// Recorte resuelto para `tutorialBoardTarget`, en puntos de la VISTA.
    ///
    /// Lo publica `BoardScene` porque es la única que sabe dónde quedó parado el
    /// personaje después de deambular: el ancla lógica del slot ya no alcanza
    /// desde que el reconciliador conserva la posición deambulada.
    var boardSpotlight: CGRect?
    /// La lección contextual que está esperando turno o en pantalla, o `nil`.
    /// La escribe `+TutorialTips` (el director) y la suelta `releasePayload`.
    var tutorialTip: TutorialTip?

    // MARK: Celebraciones

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

    // MARK: Authoritative state

    /// Era `private(set)`. Lo mutan los seis dominios: cada acción del jugador
    /// escribe el estado autoritativo y ninguno vive ya en este archivo.
    @ObservationIgnored var player: PlayerState?
    /// La torre en memoria (pisos/slots). No se serializa: se reconstruye por
    /// reconciliación desde `run.units` en cada carga.
    /// Era `private(set)` por el mismo motivo que `player`.
    @ObservationIgnored var tower: TowerState?
    /// Lo que cambió el tablero sin el jugador, esperando su turno a la vista.
    /// Lo maneja `+BoardChanges`.
    @ObservationIgnored var pendingBoardChanges: [BoardChange] = []
    /// El que la escena está reproduciendo. Confirmarlo lo consume.
    @ObservationIgnored var inFlightBoardChange: BoardChange?
    var content: GameContent?
    @ObservationIgnored var debugTimeScale: Double = 1

    // MARK: Servicios y guardado

    /// La usan `+Actions`, `+Prestige`, `+Upgrades` y `+Bonus`.
    var economy: StandardEconomy?
    var repository: PlayerStateRepository?
    let injectedRepository: PlayerStateRepository?
    /// El guardado diferido de `scheduleSave`; `+Lifecycle` lo cancela al sellar,
    /// porque el guardado de la salida va por `sealTask`.
    @ObservationIgnored var saveTask: Task<Void, Never>?
    /// `beginBackgroundTask` detrás de un protocolo; lo usa `+Lifecycle`.
    @ObservationIgnored var backgroundTasks: (any BackgroundTaskRunning)?
    /// Las notificaciones locales (E11): las programa el sellado al irse y las
    /// borra la vuelta. `nil` en los tests que no las piden.
    @ObservationIgnored var notifications: NotificationsManager?
    /// El ranking de Dios (E12): lo enganchan `+Ranking` y los ganchos del ciclo de vida.
    @ObservationIgnored weak var ranking: RankingStore?
    /// El último trabajo con el manager, para que los tests lo esperen.
    @ObservationIgnored var notificationsTask: Task<Void, Never>?
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
    /// La restricción de la cola antes de que un forzado la retuviera (`nil` =
    /// no hay retención; el `Optional` de adentro es la restricción misma).
    @ObservationIgnored var restrictionBeforeAd: Set<CelebrationKind>??
    @ObservationIgnored var cloudSync: CloudSaveSync?

    init(repository: PlayerStateRepository? = nil) {
        self.injectedRepository = repository
    }

    func publishCameraFloor(_ value: Double) {
        let clamped = max(0, value)
        if abs(cameraFloor - clamped) > 0.01 { cameraFloor = clamped }
    }

    func publishBoardLayout(_ marker: String) {
        if boardLayoutMarker != marker { boardLayoutMarker = marker }
    }

    #if DEBUG
    /// Cambia las perillas de `economy.json` en vivo: el panel de debug y los
    /// tests (PLAN-v2 E2a). La torre no se toca, así que una config que mueva
    /// `floors[]` se rechaza.
    func replaceEconomy(_ config: EconomyConfig) {
        guard var content, config.floors == content.economy.floors else { return }
        content.economy = config
        self.content = content
        economy = StandardEconomy(config: config)
        effectsVersion += 1
        refreshProjections()
    }
    #endif
}
