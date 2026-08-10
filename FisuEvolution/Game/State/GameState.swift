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

    /// Skin recién ganada por milestone. Se publica una sola vez por skin (el
    /// crédito en MetaState es idempotente) para que la UI celebre sin volver a
    /// consultar el catálogo ni el estado.
    struct SkinAward: Identifiable, Equatable {
        let id: String
        let characterType: CharacterType
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

    /// Qué ofrece el botón de contratar parado en el piso visible.
    ///
    /// Es UNA proyección y no tres booleanos porque el botón dibuja título y
    /// detalle por separado y los dos tienen que contar la misma historia: con
    /// booleanos ordenados había que repetir el mismo if/else en dos lugares y
    /// mantenerlos sincronizados a mano.
    enum HireOffer: Equatable {
        /// La contratación cae en el piso que estás mirando.
        case here
        /// El gate cerró el piso visible, así que cae en el de abajo (§ el botón
        /// no queda muerto en la frontera). El id es el del piso de destino.
        case floorBelow(floorID: String)
        /// El piso donde caería no tiene lugar. `belowFloorID` viene seteado sólo
        /// cuando ese piso lleno es el de abajo y no el que estás mirando.
        case full(belowFloorID: String?)
        /// El piso visible todavía no está abierto: es el preview con candado.
        case floorLocked
        /// El gate cerró y tampoco hay piso de abajo donde caer.
        case unavailable
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
    private(set) var coinsText = "0"
    private(set) var boardVersion = 0
    /// Cotización del tier base del piso donde CAE la contratación (F7 §3.3):
    /// el visible, o el de abajo cuando el gate cerró el visible. Lleva su
    /// `floorOrdinal`, así que `buySpawn` contrata donde corresponde sin
    /// recalcular nada.
    private(set) var spawnQuote: HireQuote?
    private(set) var canAffordSpawn = false
    private(set) var unitCount = 0
    /// F7: reencarnación disponible = vas a ganar ≥1 ORO.
    private(set) var prestigeAvailable = false
    private(set) var oroText = "0"
    /// RF-16: el antes/después del multiplicador. Lo escribe `+Prestige`.
    var prestigePreview = PrestigePreview.empty
    private(set) var ownedSkins: [String] = []
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
    private(set) var showSpawnHint = false
    private(set) var showMergeHint = false
    /// Espejo OBSERVABLE de las tres banderas del FTUE.
    ///
    /// `ftueTapped`/`ftueSpawned`/`ftueMerged` son `@ObservationIgnored` porque
    /// las escriben las acciones decenas de veces por segundo junto al resto del
    /// estado. El tutorial (RF-01) avanza **por acción y no por toque**, así que
    /// necesita verlas desde una vista: esto las publica una sola vez por
    /// `refreshProjections`, escribiendo sólo si cambiaron.
    private(set) var ftueMilestones = FTUEMilestones()
    /// Qué quiere iluminar el tutorial en el TABLERO, o nil si el paso actual no
    /// es de tablero. Lo escribe el overlay; lo lee el frame loop de la escena.
    @ObservationIgnored var tutorialBoardTarget: TutorialBoardTarget?
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
    /// Qué puede hacer el botón de contratar desde el piso visible.
    private(set) var hireOffer: HireOffer = .floorLocked
    var towerNotice: TowerNotice?
    /// Se incrementa al comprar upgrades/activar boosts: las vistas que leen
    /// `player` directo lo observan para re-renderizar.
    /// Lo escriben `+Upgrades` (las dos compras) y `+Bonus` (boosts y shares).
    var effectsVersion = 0
    var careerPrompt: CareerPrompt?
    var characterSheet: CharacterSheet?
    var offlineReward: OfflineReward?
    var skinAward: SkinAward?

    // MARK: Authoritative state

    /// Un merge que abre piso dispara una cadena de celebraciones en la escena.
    /// Mientras corre, las superficies de SwiftUI esperan su turno: si el sheet
    /// de skin apareciera en el instante del merge taparía el vuelo, el reveal y
    /// la celebración del piso —los tres a la vez, que es el bug que esto
    /// arregla—.
    /// Lo escribe `+Actions`: el merge que asciende abre la cadena.
    @ObservationIgnored var celebrationChainActive = false
    @ObservationIgnored private var pendingSkinAward: SkinAward?
    /// Lo escribe `+Actions` cuando el ascenso destraba un piso nuevo.
    @ObservationIgnored var pendingHireUnlockedFloorID: String?

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
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// Lo consumen `+Actions` (crítico/dorado y el drop de special) y `+Bonus`.
    @ObservationIgnored var rng = SystemRandomNumberGenerator()
    /// Los usan `+Actions` (merge/tap) y `+Prestige`.
    @ObservationIgnored var gameCenter: GameCenterManager?
    /// Los usan `+Actions`, `+Prestige` y `+Upgrades`.
    @ObservationIgnored var haptics: HapticsManager?
    /// Los usan `+Actions`, `+Prestige` y `+Bonus`.
    @ObservationIgnored var audio: AudioManager?
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

    func attachAudio(_ manager: AudioManager) {
        audio = manager
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

            let repository = injectedRepository ?? PlayerStateRepository(
                persistence: PersistenceController(),
                snapshotURL: PlayerStateRepository.defaultSnapshotURL()
            )
            self.repository = repository

            // Infra de UI tests: estado limpio y determinístico por launch argument.
            var forceNewGame = false
            #if DEBUG
            forceNewGame = ProcessInfo.processInfo.arguments.contains("--uitest-reset")
            applyTutorialLaunchArguments(forceNewGame: forceNewGame)
            #endif

            if content.flags.cloudKitEnabled {
                cloudSync = CloudSaveSync()
            }

            var isFreshInstall = false
            if !forceNewGame, let saved = await repository.load() {
                var resolved = saved
                if let cloudSync, let remote = try? await cloudSync.fetch() {
                    resolved = SaveConflictResolver.resolve(local: saved, remote: remote)
                }
                player = resolved
                Log.lifecycle.info("save loaded: prestige \(resolved.meta.prestigeLevel), maxTier \(resolved.run.maxTierReached)")
            } else {
                isFreshInstall = true
                let fresh = PlayerState.newGame(
                    startTypeId: content.tiers.baseType.id,
                    startFloorId: content.floorTable[0].id,
                    offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
                    critChanceBase: content.economy.critChanceBase,
                    now: Date().timeIntervalSince1970
                )
                player = fresh
                await repository.save(fresh)
                Log.lifecycle.info("new game started")
            }

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
            // RF-16: el ORO va con la raíz de lifetime/3M, así que llegar al
            // prestigio jugando no es automatizable. El fixture lo acredita.
            if ProcessInfo.processInfo.arguments.contains("--uitest-prestige") {
                giveLifetimeEarningsForTesting(300_000_000)
            }
            // El primer Fisura cuesta 50 y un tap rinde 1: llegar a contratar
            // jugando son ~50 toques sobre un personaje que deambula. El fixture
            // acredita la plata para que el test del tutorial mida el TUTORIAL y
            // no la puntería del runner.
            if ProcessInfo.processInfo.arguments.contains("--uitest-coins") {
                debugGrantCoins()
            }
            // El long-press sobre SpriteKit no es determinista en el runner: para
            // el smoke de la ficha alcanza con abrirla sobre la primera unidad.
            if ProcessInfo.processInfo.arguments.contains("--uitest-open-sheet"),
               let slot = visiblePlacements.first?.slot {
                presentCharacterSheet(cellIndex: slot)
            }
            #endif
            applyOfflineProgressIfNeeded()
            // El primer launch de una cuenta nueva no reclama daily: el jugador
            // todavía no jugó y el popup compite con el tutorial (FTUE).
            if !isFreshInstall {
                claimDailyIfAvailable()
            } else if var player {
                player.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
                self.player = player
            }
            scheduleNextEvent(from: Date().timeIntervalSince1970)
            refreshProjections()
            phase = .ready
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
    }

    /// Milestones no dependen de la escena: cualquier unlock/reencarnación que
    /// actualice el estado de torre acredita una vez en MetaState. StoreKit usa
    /// `ownedSkins` aparte y por eso esta unión nunca borra una compra.
    private func awardEligibleMilestoneSkins() {
        guard let content, var player else { return }
        let newlyUnlocked = SkinMilestones.newlyUnlocked(state: player, config: content.skins)
        guard !newlyUnlocked.isEmpty else { return }
        player.meta.milestoneSkins = Array(Set(player.meta.milestoneSkins).union(newlyUnlocked)).sorted()
        self.player = player
        skinSelectionVersion &+= 1
        Log.economy.info("skin milestones awarded: \(newlyUnlocked)")

        // Se celebra UNA: encadenar popups interrumpe el loop, y el crédito ya
        // quedó hecho para todas. La ficha muestra el resto.
        if let first = newlyUnlocked.sorted().first,
           let entry = content.skins.entry(id: first),
           let type = content.tiers.type(id: entry.characterType) {
            let award = SkinAward(id: first, characterType: type)
            if celebrationChainActive {
                pendingSkinAward = award
            } else {
                skinAward = award
            }
        }
    }

    /// La escena terminó de reproducir la cadena del ascenso (vuelo → reveal →
    /// piso nuevo). Recién ahora SwiftUI puede poner su parte arriba.
    func celebrationsDidFinish() {
        celebrationChainActive = false
        if let award = pendingSkinAward {
            pendingSkinAward = nil
            skinAward = award
            return  // el toast espera a que el jugador cierre el sheet
        }
        flushPendingHireNotice()
    }

    /// El sheet de skin se cerró (por botón o por gesto).
    func skinAwardDismissed() {
        flushPendingHireNotice()
    }

    private func flushPendingHireNotice() {
        guard let floorID = pendingHireUnlockedFloorID else { return }
        pendingHireUnlockedFloorID = nil
        towerNotice = TowerNotice(kind: .hireUnlocked(floorID: floorID))
    }

    // MARK: Frame loop (called by BoardScene)

    /// Passive income tick. Mutates only non-observed state — zero SwiftUI work.
    func tick(delta: TimeInterval) {
        guard let content, var player else { return }
        IncomeTicker.tick(
            state: &player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            delta: delta * debugTimeScale,
            now: Date().timeIntervalSince1970
        )
        self.player = player
    }

    /// 8 Hz projection flush driven by the scene's frame counter. Also prunes
    /// expired modifiers and fires scheduled events.
    func flushHUD() {
        let now = Date().timeIntervalSince1970
        if var player {
            let pruned = ModifierMath.prune(&player, now: now)
            if pruned {
                self.player = player
                scheduleSave()
            }
        }
        fireEventIfDue(now: now)
        refreshProjections()
    }

    // MARK: Lifecycle (offline + immediate save)

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .background, .inactive:
            guard var player else { return }
            player.meta.lastSeenTimestamp = Date().timeIntervalSince1970
            self.player = player
            saveTask?.cancel()
            Task { await persistNow() }
        case .active:
            guard phase == .ready else { return }
            applyOfflineProgressIfNeeded()
            claimDailyIfAvailable()
            refreshProjections()
        @unknown default:
            break
        }
    }

    /// La llama también `+Debug`, para simular una vuelta después de N horas.
    func applyOfflineProgressIfNeeded() {
        guard let content, var player else { return }
        let credited = OfflineCalculator.apply(
            state: &player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            now: Date().timeIntervalSince1970
        )
        self.player = player
        if credited > 0 {
            offlineReward = OfflineReward(amount: credited)
            // Plata que cae de golpe: suena como tal, igual que un tap dorado.
            audio?.play(.coin)
            Log.economy.info("offline earnings credited: \(credited)")
        }
    }

    // MARK: Internals

    /// El piso donde cae la contratación: el visible, salvo que el gate lo haya
    /// cerrado y haya que bajar uno. `nil` si desde acá no se contrata en ningún
    /// lado (piso visible todavía cerrado).
    /// La llaman `+Actions` (contratar) y `+Debug` (cotizar el regalo de coins).
    func hireTargetOrdinal(player: PlayerState) -> Int? {
        guard let content else { return nil }
        return TowerActions.hireTargetFloor(
            visibleOrdinal: visibleFloorOrdinal,
            unlockedFloors: player.run.unlockedFloors,
            floorTable: content.floorTable
        )
    }

    /// La llaman `+Actions` (contratar) y `+Debug`.
    func currentQuote(player: PlayerState, floorOrdinal: Int) -> HireQuote? {
        guard let economy, let content else { return nil }
        let prestigeDiscount = content.prestigeUnlocks.cumulativeSpawnDiscount(atPrestigeLevel: player.meta.prestigeLevel)
        return TowerActions.hireQuote(
            floorOrdinal: floorOrdinal,
            state: player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            economy: economy,
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
        let offer: HireOffer
        switch (target, targetFull) {
        case (nil, _):
            offer = floorUnlocked ? .unavailable : .floorLocked
        case (let ordinal?, true):
            offer = .full(belowFloorID: ordinal == visibleFloorOrdinal ? nil : content.floorTable[ordinal].id)
        case (let ordinal?, false):
            offer = ordinal == visibleFloorOrdinal ? .here : .floorBelow(floorID: content.floorTable[ordinal].id)
        }
        if hireOffer != offer { hireOffer = offer }

        let affordable = target != nil && !targetFull
            && (quote.map { player.run.coins >= $0.cost } ?? false)
        if canAffordSpawn != affordable { canAffordSpawn = affordable }

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

        let oro = String(player.meta.oro)
        if oroText != oro { oroText = oro }

        refreshPrestigePreview()

        let skins = Array(player.meta.allOwnedSkins).sorted()
        if ownedSkins != skins { ownedSkins = skins }

        let bonuses = makeActiveBonuses(player: player, content: content)
        if activeBonuses != bonuses { activeBonuses = bonuses }

        let tapHint = !ftueTapped
        if showTapHint != tapHint { showTapHint = tapHint }
        let spawnHint = ftueTapped && !ftueSpawned && (spawnQuote.map { player.run.coins >= $0.cost } ?? false)
        if showSpawnHint != spawnHint { showSpawnHint = spawnHint }
        var pairExists = false
        if !ftueMerged && ftueSpawned {
            pairExists = player.run.units.values.contains { $0 >= 2 }
        }
        let mergeHint = ftueSpawned && !ftueMerged && pairExists
        if showMergeHint != mergeHint { showMergeHint = mergeHint }

        let milestones = FTUEMilestones(tapped: ftueTapped, spawned: ftueSpawned, merged: ftueMerged)
        if ftueMilestones != milestones { ftueMilestones = milestones }
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

    func persistNow() async {
        guard let repository, let player else { return }
        await repository.save(player)
        if let cloudSync {
            await cloudSync.push(player)
        }
    }
}
