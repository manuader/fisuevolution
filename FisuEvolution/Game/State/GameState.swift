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

    private(set) var phase: Phase = .loading
    private(set) var coinsText = "0"
    private(set) var boardVersion = 0
    /// Cotización de contratación del PISO VISIBLE (tier base del piso — F7 §3.3).
    private(set) var spawnQuote: HireQuote?
    private(set) var canAffordSpawn = false
    private(set) var unitCount = 0
    /// F7: reencarnación disponible = vas a ganar ≥1 ORO.
    private(set) var prestigeAvailable = false
    private(set) var oroText = "0"
    private(set) var ownedSkins: [String] = []
    /// Invalida la ficha cuando llega un entitlement, milestone o equipamiento.
    private(set) var skinSelectionVersion = 0
    private(set) var activeEvent: EventManager.ActiveEvent?
    private(set) var specialDrop: SpecialsConfig.Special?
    private(set) var dailyClaim: DailyRewardManager.Claim?
    private(set) var shareCardSubject: CharacterType?
    private(set) var showTapHint = false
    private(set) var showSpawnHint = false
    private(set) var showMergeHint = false
    /// Piso visible (ordinal 0-based). La escena lo consume vía boardVersion.
    private(set) var visibleFloorOrdinal = 0
    /// Estado listo para la pill y las flechas de F7.2.
    private(set) var towerNavigation = TowerNavigation.empty
    /// Income pasivo agregado de todos los pisos, aunque no estén en cámara.
    private(set) var towerIncomePerSecond = 0.0
    private(set) var towerIncomePerSecondText = "0"
    private(set) var visibleFloorIsFull = false
    private(set) var visibleFloorIsUnlocked = false
    /// El piso está abierto pero todavía no habilita contratar: falta
    /// desbloquear el de arriba. El callejón nunca entra acá.
    private(set) var visibleFloorAllowsHiring = false
    var towerNotice: TowerNotice?
    /// Se incrementa al comprar upgrades/activar boosts: las vistas que leen
    /// `player` directo lo observan para re-renderizar.
    private(set) var effectsVersion = 0
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
    @ObservationIgnored private var celebrationChainActive = false
    @ObservationIgnored private var pendingSkinAward: SkinAward?
    @ObservationIgnored private var pendingHireUnlockedFloorID: String?

    @ObservationIgnored private(set) var player: PlayerState?
    /// La torre en memoria (pisos/slots). No se serializa: se reconstruye por
    /// reconciliación desde `run.units` en cada carga.
    @ObservationIgnored private(set) var tower: TowerState?
    private(set) var content: GameContent?
    @ObservationIgnored var debugTimeScale: Double = 1

    private var economy: StandardEconomy?
    private var repository: PlayerStateRepository?
    private let injectedRepository: PlayerStateRepository?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var gameCenter: GameCenterManager?
    @ObservationIgnored private var haptics: HapticsManager?
    @ObservationIgnored private var audio: AudioManager?
    @ObservationIgnored private var ftueTapped = UserDefaults.standard.bool(forKey: "ftue.tapped")
    @ObservationIgnored private var ftueSpawned = UserDefaults.standard.bool(forKey: "ftue.spawned")
    @ObservationIgnored private var ftueMerged = UserDefaults.standard.bool(forKey: "ftue.merged")
    @ObservationIgnored private var cloudSync: CloudSaveSync?
    @ObservationIgnored private var nextEventAt: TimeInterval = .infinity
    @ObservationIgnored private var eventLastFired: [String: TimeInterval] = [:]

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

    // MARK: Tower accessors (scene + views)

    var floorTable: FloorTable? { content?.floorTable }

    var visibleFloorDef: FloorDef? {
        content.map { $0.floorTable[visibleFloorOrdinal] }
    }

    /// Specials anclados al piso visible (⚠️5: no ocupan slot ni se mergean —
    /// quedan de decorado en el piso donde cayeron). Un special sin ancla (o con
    /// un ancla de una config vieja) simplemente no se dibuja.
    var visibleFloorSpecials: [SpecialsConfig.Special] {
        guard let content, let player, let floorID = visibleFloorDef?.id else { return [] }
        return content.specials.specials.filter {
            player.meta.ownedSpecials.contains($0.id) && player.meta.specialAnchors[$0.id] == floorID
        }
    }

    /// Placements del piso visible (la escena solo dibuja este piso en F7.1).
    var visiblePlacements: [TowerPlacement] {
        tower?.placements(onFloor: visibleFloorOrdinal) ?? []
    }

    var visibleFloorOccupancy: (occupied: Int, capacity: Int) {
        guard let tower, tower.floors.indices.contains(visibleFloorOrdinal) else { return (0, 0) }
        let floor = tower.floors[visibleFloorOrdinal]
        return (floor.occupiedCount, floor.def.capacity)
    }

    /// Cambia el piso visible dentro de los abiertos y permite asomarse a uno
    /// bloqueado. Así se ve la meta siguiente sin poder contratar ni saltar más.
    func setVisibleFloor(_ ordinal: Int) {
        guard let content, let player else { return }
        let unlockedOrdinals = content.floorTable.floors.enumerated()
            .filter { player.run.unlockedFloors.contains($0.element.id) }
            .map(\.offset)
        guard let maxUnlocked = unlockedOrdinals.max() else { return }
        let maxVisible = min(maxUnlocked + 1, content.floorTable.floors.count - 1)
        let clamped = min(max(0, ordinal), maxVisible)
        guard clamped != visibleFloorOrdinal else { return }
        visibleFloorOrdinal = clamped
        bumpBoard()
    }

    /// Navega exactamente un piso en la torre. El límite superior es la vista
    /// previa del próximo piso bloqueado, para que SpriteKit no anime más allá.
    @discardableResult
    func moveVisibleFloor(by direction: Int) -> Bool {
        guard direction == -1 || direction == 1 else { return false }
        let previous = visibleFloorOrdinal
        setVisibleFloor(previous + direction)
        return visibleFloorOrdinal != previous
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
    private func reconcileTower() {
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
    private func resyncTower() {
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

    private func updateMaxFloorStat() {
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

    // MARK: Player actions

    struct TapResult {
        let gain: Double
        let isCrit: Bool
        let isGolden: Bool
    }

    /// Tap con rolls de crítico (× critMultiplier) y golden touch (×10).
    /// `cellIndex` = slot del piso visible. Nil si el slot está vacío.
    @discardableResult
    func registerTap(cellIndex: Int) -> TapResult? {
        guard let economy, let content, var player = player,
              let typeId = tower?.typeId(floorOrdinal: visibleFloorOrdinal, slot: cellIndex),
              let type = content.tiers.type(id: typeId)
        else { return nil }

        var gain = economy.applyTap(
            type: type,
            state: &player,
            floorTable: content.floorTable,
            now: Date().timeIntervalSince1970
        )
        let isCrit = Double.random(in: 0..<1, using: &rng) < player.meta.derivedEffects.critChance
        let isGolden = Double.random(in: 0..<1, using: &rng) < player.meta.derivedEffects.goldenChance
        var bonusFactor = 1.0
        if isCrit { bonusFactor *= content.economy.critMultiplier }
        if isGolden { bonusFactor *= 10 }
        if bonusFactor > 1 {
            let extra = gain * (bonusFactor - 1)
            player.run.coins += extra
            player.meta.lifetimeEarnings += extra
            gain += extra
        }
        self.player = player
        if !ftueTapped {
            ftueTapped = true
            UserDefaults.standard.set(true, forKey: "ftue.tapped")
        }
        audio?.play(isCrit || isGolden ? .coin : .tap)
        refreshProjections()
        scheduleSave()
        return TapResult(gain: gain, isCrit: isCrit, isGolden: isGolden)
    }

    /// Contrata el tier base del piso visible (F7 §3.3).
    func buySpawn() {
        guard let content, var player = player, var tower,
              let quote = currentQuote(player: player)
        else { return }
        do {
            _ = try TowerActions.hire(
                quote: quote,
                state: &player,
                tower: &tower,
                floorTable: content.floorTable
            )
            self.player = player
            self.tower = tower
            if !ftueSpawned {
                ftueSpawned = true
                UserDefaults.standard.set(true, forKey: "ftue.spawned")
            }
            haptics?.play(.purchase)
            audio?.play(.buy)
            bumpBoard()
            scheduleSave()
        } catch {
            if case TowerError.floorFull = error {
                towerNotice = TowerNotice(kind: .floorFull)
            }
            haptics?.play(.error)
            Log.economy.info("hire rejected: \(error)")
        }
    }

    /// Resolves a drag-drop from the scene (slots del piso visible; F7 §3.4:
    /// si el resultado pertenece a un piso superior, asciende — piso destino
    /// lleno bloquea el merge).
    func handleDrop(fromCell: Int, toCell: Int) -> DropResolution {
        guard let content, var player = player, var tower, fromCell != toCell,
              let sourceType = tower.typeId(floorOrdinal: visibleFloorOrdinal, slot: fromCell)
        else { return .snapBack }

        guard let targetType = tower.typeId(floorOrdinal: visibleFloorOrdinal, slot: toCell) else {
            if TowerActions.move(floorOrdinal: visibleFloorOrdinal, fromSlot: fromCell, toSlot: toCell, tower: &tower) {
                self.tower = tower
                bumpBoard()
                return .moved
            }
            return .snapBack
        }

        switch MergeRules.evaluate(
            sourceTypeId: sourceType,
            targetTypeId: targetType,
            chosenCareerPath: player.run.chosenCareerPath,
            tiers: content.tiers
        ) {
        case .merged(let newTypeId):
            let tierBefore = player.run.maxTierReached
            // `applyMerge` muta `unlockedFloors`: hay que fotografiarlo antes
            // para saber qué destrabó el ascenso.
            let unlockedBefore = player.run.unlockedFloors
            do {
                let result = try TowerActions.applyMerge(
                    floorOrdinal: visibleFloorOrdinal,
                    sourceSlot: fromCell,
                    targetSlot: toCell,
                    newTypeId: newTypeId,
                    state: &player,
                    tower: &tower,
                    tiers: content.tiers,
                    floorTable: content.floorTable
                )
                let evolvedTo = player.run.maxTierReached > tierBefore ? content.tiers.type(id: newTypeId) : nil
                self.player = player
                self.tower = tower
                // El sheet de skin y el toast esperan a que la escena termine su
                // cadena. Marcarlo ANTES de `updateMaxFloorStat()`, que es quien
                // acredita la skin de milestone.
                if case .promoted = result {
                    celebrationChainActive = true
                    let newlyHireable = TowerActions.newlyHireableFloors(
                        unlockedBefore: unlockedBefore,
                        unlockedAfter: player.run.unlockedFloors,
                        floorTable: content.floorTable
                    )
                    // El más bajo: es el que el jugador va a querer rellenar.
                    if let ordinal = newlyHireable.first {
                        pendingHireUnlockedFloorID = content.floorTable[ordinal].id
                    }
                }
                if !ftueMerged {
                    ftueMerged = true
                    UserDefaults.standard.set(true, forKey: "ftue.merged")
                }
                audio?.play(evolvedTo != nil ? .evolution : .merge)
                reportMergeMilestones()
                rollSpecialDrop()
                updateMaxFloorStat()
                bumpBoard()
                scheduleSave()
                switch result {
                case .stayed(_, let slot, _):
                    return .merged(
                        targetCell: slot,
                        evolvedTo: evolvedTo,
                        promotedType: nil,
                        promotedToFloor: nil,
                        unlockedFloorId: nil
                    )
                case .promoted(let toFloor, _, _, let unlockedFloorId):
                    return .merged(
                        targetCell: toCell,
                        evolvedTo: evolvedTo,
                        promotedType: content.tiers.type(id: newTypeId),
                        promotedToFloor: toFloor,
                        unlockedFloorId: unlockedFloorId
                    )
                case .requiresCareerChoice:
                    return .snapBack  // unreachable: MergeRules ya resolvió
                }
            } catch TowerError.destinationFloorFull(let floorID) {
                towerNotice = TowerNotice(kind: .destinationFloorFull(floorID: floorID))
                haptics?.play(.error)
                Log.economy.info("merge blocked: destination floor full")
                return .snapBack
            } catch {
                Log.economy.info("merge rejected: \(error)")
                return .snapBack
            }
        case .requiresCareerChoice(let options):
            careerPrompt = CareerPrompt(
                options: options.compactMap { content.tiers.type(id: $0) },
                sourceCell: fromCell,
                targetCell: toCell
            )
            return .careerPending
        case .invalid:
            return .snapBack
        }
    }

    /// Completes the deferred T9 merge after the player picks a career. The choice
    /// persists until the next reincarnation (bible §1).
    func chooseCareer(optionId: String) {
        guard let prompt = careerPrompt, let content, var player = player, var tower else { return }
        player.run.chosenCareerPath = MergeRules.careerPath(fromOptionId: optionId)

        guard let sourceType = tower.typeId(floorOrdinal: visibleFloorOrdinal, slot: prompt.sourceCell),
              let targetType = tower.typeId(floorOrdinal: visibleFloorOrdinal, slot: prompt.targetCell),
              case .merged(let newTypeId) = MergeRules.evaluate(
                  sourceTypeId: sourceType,
                  targetTypeId: targetType,
                  chosenCareerPath: player.run.chosenCareerPath,
                  tiers: content.tiers
              )
        else {
            self.player = player
            careerPrompt = nil
            refreshProjections()
            return
        }

        do {
            _ = try TowerActions.applyMerge(
                floorOrdinal: visibleFloorOrdinal,
                sourceSlot: prompt.sourceCell,
                targetSlot: prompt.targetCell,
                newTypeId: newTypeId,
                state: &player,
                tower: &tower,
                tiers: content.tiers,
                floorTable: content.floorTable
            )
        } catch {
            Log.economy.info("career merge rejected: \(error)")
        }
        self.player = player
        self.tower = tower
        careerPrompt = nil
        reportMergeMilestones()
        rollSpecialDrop()
        updateMaxFloorStat()
        bumpBoard()
        scheduleSave()
    }

    func dismissTowerNotice(id: UUID) {
        guard towerNotice?.id == id else { return }
        towerNotice = nil
    }

    private func reportMergeMilestones() {
        guard let player else { return }
        gameCenter?.report(.firstMerge)
        gameCenter?.report(.reachedTier(player.run.maxTierReached))
        gameCenter?.report(.scoreUpdate(lifetimeEarnings: player.meta.lifetimeEarnings, maxTier: player.run.maxTierReached))
    }

    private func rollSpecialDrop() {
        guard let economy, let content, var player else { return }
        if let dropped = SpecialDropManager.rollOnMerge(
            state: &player,
            config: content.specials,
            upgrades: content.upgradesConfig,
            viral: content.viral,
            economy: economy,
            rng: &rng
        ) {
            // Anclaje visual: el special queda en el piso donde cayó (⚠️5).
            if let floorId = visibleFloorDef?.id {
                player.meta.specialAnchors[dropped.id] = floorId
            }
            self.player = player
            specialDrop = dropped
            haptics?.play(.rarity)
            audio?.play(.rare)
            Log.economy.info("special dropped: \(dropped.id)")
        }
    }

    func dismissSpecialDrop() {
        specialDrop = nil
    }

    /// Long-press on a unit → ficha por personaje (§2.3 regla 3).
    /// `cellIndex` = slot del piso visible.
    func presentCharacterSheet(cellIndex: Int) {
        guard let content, let player, let tower,
              let typeId = tower.typeId(floorOrdinal: visibleFloorOrdinal, slot: cellIndex),
              let type = content.tiers.type(id: typeId)
        else { return }
        characterSheet = CharacterSheet(
            type: type,
            cellIndex: cellIndex,
            instanceCount: player.run.units[type.id] ?? 0,
            isUnlocked: player.run.passiveUnlocked[type.id] == true,
            canAfford: player.run.coins >= type.passiveUnlockCost,
            canDismiss: player.run.totalUnits > 1
        )
    }

    /// "Dejar de contratar": saca la unidad del slot y libera el espacio.
    func dismissCharacter(atCell cell: Int) {
        guard var player, var tower else { return }
        guard TowerActions.removeUnit(floorOrdinal: visibleFloorOrdinal, slot: cell, state: &player, tower: &tower) else { return }
        self.player = player
        self.tower = tower
        characterSheet = nil
        playHaptic(.merge)
        bumpBoard()
        scheduleSave()
    }

    func unlockPassive(typeId: String) {
        guard let economy, let content, var player = player else { return }
        do {
            try economy.applyPassiveUnlock(typeId: typeId, state: &player, tiers: content.tiers)
            self.player = player
            haptics?.play(.purchase)
            characterSheet = nil
            refreshProjections()
            scheduleSave()
        } catch {
            haptics?.play(.error)
            Log.economy.info("passive unlock rejected: \(error)")
        }
    }

    // MARK: Reencarnación (F7: gate por ORO)

    /// ORO que ganarías reencarnando ahora.
    var prestigeOroGained: Int {
        guard let economy, let player else { return 0 }
        return PrestigeCalculator.oroGained(state: player, economy: economy)
    }

    func confirmPrestige() {
        guard let economy, let content, var player = player,
              PrestigeCalculator.canReincarnate(state: player, economy: economy)
        else { return }
        PrestigeCalculator.applyReincarnation(
            state: &player,
            economy: economy,
            tiers: content.tiers,
            floorTable: content.floorTable,
            now: Date().timeIntervalSince1970
        )
        self.player = player
        reconcileTower()
        audio?.play(.prestige)
        haptics?.play(.rarity)
        gameCenter?.report(.firstPrestige)
        bumpBoard()
        Task { await persistNow() }
        Log.economy.info("reincarnated: level \(player.meta.prestigeLevel), oro \(player.meta.oro)")
    }

    // MARK: Store (F4)

    /// StoreKit es la fuente de verdad; acá solo se cachea en el save.
    /// Las skins de milestone viven aparte (`meta.milestoneSkins`) y NO se pisan.
    func applyStoreEntitlements(removedAds: Bool, ownedSkins: [String]) {
        guard var player else { return }
        guard player.meta.removedAds != removedAds || player.meta.ownedSkins != ownedSkins else { return }
        player.meta.removedAds = removedAds
        player.meta.ownedSkins = ownedSkins
        let owned = player.meta.allOwnedSkins
        player.meta.activeSkinByType = player.meta.activeSkinByType.filter { owned.contains($0.value) }
        self.player = player
        skinSelectionVersion &+= 1
        bumpBoard()
        scheduleSave()
    }

    /// Skin actualmente equipada en la ficha de un tipo. La ausencia es la
    /// apariencia base: no se persiste un ID artificial para poder sumar skins
    /// data-driven sin migrar saves.
    func activeSkinID(forCharacterType typeID: String) -> String? {
        guard let player else { return nil }
        return player.meta.activeSkinByType[typeID]
    }

    func skinOptions(forCharacterType typeID: String) -> [SkinsConfig.Entry] {
        content?.skins.entries(forCharacterType: typeID) ?? []
    }

    func ownsSkin(_ skinID: String) -> Bool {
        player?.meta.allOwnedSkins.contains(skinID) == true
    }

    /// Equipa una skin en UN personaje. Valida tanto la pertenencia de la skin
    /// al catálogo como la propiedad del jugador; StoreKit nunca puede inyectar
    /// una apariencia que `skins.json` no declare para esa ficha.
    func equipSkin(id skinID: String?, forCharacterType typeID: String) {
        guard let content, var player,
              content.tiers.type(id: typeID) != nil
        else { return }
        if let skinID {
            guard player.meta.allOwnedSkins.contains(skinID),
                  content.skins.entries(forCharacterType: typeID).contains(where: { $0.id == skinID })
            else { return }
            player.meta.activeSkinByType[typeID] = skinID
        } else {
            player.meta.activeSkinByType.removeValue(forKey: typeID)
        }
        self.player = player
        skinSelectionVersion &+= 1
        bumpBoard()
        scheduleSave()
    }

    // MARK: Rewarded ads (F4 — efectos del bible §4.4)

    func applyRewardedReward(_ reward: RewardedAdsConfig.Reward) {
        guard var player else { return }
        let now = Date().timeIntervalSince1970
        switch reward.effectType {
        case .incomeMultiplier:
            guard let magnitude = reward.magnitude, let duration = reward.durationSeconds else { return }
            player.run.activeModifiers.append(ActiveModifier(
                effect: .incomeMultiplier,
                magnitude: magnitude,
                expiresAt: now + duration,
                sourceKey: "rewarded.\(reward.id)"
            ))
            self.player = player
            refreshProjections()
            scheduleSave()
        case .instantMerge:
            performInstantMerge()
        case .rareUnit:
            grantRareUnit()
        }
        Log.economy.info("rewarded effect applied: \(reward.id)")
    }

    /// Merge gratis del par más alto disponible (saltea pares que pidan carrera).
    private func performInstantMerge() {
        guard var player, var tower, let content else { return }
        // Buscar el par de mayor tier en TODA la torre.
        let candidates: [(floorOrdinal: Int, slots: [Int], typeId: String, tier: Int)] = tower.floors.indices.flatMap { ordinal in
            var slotsByType: [String: [Int]] = [:]
            for placement in tower.placements(onFloor: ordinal) {
                slotsByType[placement.typeId, default: []].append(placement.slot)
            }
            return slotsByType.compactMap { typeId, slots -> (floorOrdinal: Int, slots: [Int], typeId: String, tier: Int)? in
                guard slots.count >= 2, let type = content.tiers.type(id: typeId) else { return nil }
                return (floorOrdinal: ordinal, slots: slots, typeId: typeId, tier: type.tier)
            }
        }.sorted { $0.tier > $1.tier }

        for candidate in candidates {
            guard case .merged(let newTypeId) = MergeRules.evaluate(
                sourceTypeId: candidate.typeId,
                targetTypeId: candidate.typeId,
                chosenCareerPath: player.run.chosenCareerPath,
                tiers: content.tiers
            ) else { continue }
            do {
                _ = try TowerActions.applyMerge(
                    floorOrdinal: candidate.floorOrdinal,
                    sourceSlot: candidate.slots[0],
                    targetSlot: candidate.slots[1],
                    newTypeId: newTypeId,
                    state: &player,
                    tower: &tower,
                    tiers: content.tiers,
                    floorTable: content.floorTable
                )
                self.player = player
                self.tower = tower
                updateMaxFloorStat()
                bumpBoard()
                scheduleSave()
                return
            } catch {
                continue  // piso destino lleno: probar el siguiente par
            }
        }
    }

    /// F4: "spawn rare" — dropea una unidad del tier máximo en su piso.
    private func grantRareUnit() {
        guard var player, var tower, let content else { return }
        let tier = player.run.maxTierReached
        guard let type = content.tiers.concreteTypes.first(where: { candidate in
            candidate.tier == tier && (player.run.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        }) ?? content.tiers.concreteTypes.first(where: { $0.tier == tier }) else { return }
        let ordinal = content.floorTable.ordinal(forTier: type.tier)
        guard let slot = tower.floors[ordinal].firstFreeSlot() else { return }
        tower.floors[ordinal].slots[slot] = type.id
        player.run.units[type.id, default: 0] += 1
        self.player = player
        self.tower = tower
        bumpBoard()
        scheduleSave()
    }

    // MARK: Upgrades (F5 — las 7 líneas; pasan a ORO en F7.4)

    func upgradeLevel(of lineId: String) -> Int {
        player?.meta.oroUpgradeLevels[lineId] ?? 0
    }

    func upgradeCost(of line: UpgradesConfig.Line) -> Double {
        UpgradeManager.cost(of: line, level: upgradeLevel(of: line.id))
    }

    /// Tipos que el jugador conoce en esta vida (o ya mejoró) para la pestaña
    /// Personajes. La UI recibe el catálogo filtrado, no inspecciona el save.
    var characterUpgradeTypes: [CharacterType] {
        guard let content, let player else { return [] }
        return content.tiers.concreteTypes
            .filter { (player.run.units[$0.id] ?? 0) > 0 || (player.run.charUpgradeLevels[$0.id] ?? 0) > 0 }
            .sorted { $0.tier < $1.tier }
    }

    func characterUpgradeLevel(of typeID: String) -> Int {
        player?.run.charUpgradeLevels[typeID] ?? 0
    }

    func characterUpgradeCost(of type: CharacterType) -> Double? {
        guard let economy, let player, let content else { return nil }
        return CharUpgrades.nextLevelCost(type: type, levels: player.run.charUpgradeLevels, config: content.economy, economy: economy)
    }

    func buyCharacterUpgrade(typeID: String) {
        guard let economy, let content, var player,
              let type = content.tiers.type(id: typeID)
        else { return }
        do {
            try CharUpgrades.purchase(type: type, state: &player, config: content.economy, economy: economy)
            self.player = player
            haptics?.play(.purchase)
            effectsVersion += 1
            refreshProjections()
            scheduleSave()
        } catch {
            haptics?.play(.error)
            Log.economy.info("character upgrade rejected: \(error)")
        }
    }

    func buyUpgrade(lineId: String) {
        guard let economy, let content, var player = player else { return }
        do {
            try UpgradeManager.purchase(
                lineId: lineId,
                state: &player,
                config: content.upgradesConfig,
                specials: content.specials,
                viral: content.viral,
                economy: economy
            )
            self.player = player
            haptics?.play(.purchase)
            effectsVersion += 1
            refreshProjections()
            scheduleSave()
        } catch {
            haptics?.play(.error)
            Log.economy.info("upgrade rejected: \(error)")
        }
    }

    // MARK: Boosts (F5 — bible §1)

    func boostCooldownRemaining(_ boost: BoostsConfig.Boost) -> TimeInterval {
        guard let player else { return .infinity }
        return BoostManager.cooldownRemaining(of: boost, state: player, now: Date().timeIntervalSince1970)
    }

    /// Devuelve las coins del cofre si el boost era el Asado.
    @discardableResult
    func activateBoost(id: String) -> Double? {
        guard let economy, let content, var player = player else { return nil }
        do {
            let chest = try BoostManager.activate(
                boostId: id,
                state: &player,
                config: content.boosts,
                upgrades: content.upgradesConfig,
                specials: content.specials,
                viral: content.viral,
                tiers: content.tiers,
                economy: economy,
                now: Date().timeIntervalSince1970
            )
            self.player = player
            effectsVersion += 1
            refreshProjections()
            scheduleSave()
            return chest
        } catch {
            Log.economy.info("boost rejected: \(error)")
            return nil
        }
    }

    // MARK: Eventos (F5 — bible §1)

    private func scheduleNextEvent(from now: TimeInterval) {
        guard let content else { return }
        let jitter = Double.random(in: 0..<max(content.events.intervalJitterSeconds, 1), using: &rng)
        nextEventAt = now + content.events.baseIntervalSeconds + jitter
    }

    private func fireEventIfDue(now: TimeInterval) {
        guard let economy, let content, var player else { return }
        if let active = activeEvent, now >= active.endsAt {
            activeEvent = nil
        }
        guard now >= nextEventAt else { return }
        scheduleNextEvent(from: now)
        guard let roll = EventManager.fireRandomEvent(
            state: &player,
            config: content.events,
            tiers: content.tiers,
            floorTable: content.floorTable,
            economy: economy,
            now: now,
            lastFired: eventLastFired,
            rng: &rng
        ) else { return }
        self.player = player
        // Si el evento regaló una unidad, colocarla en su piso (si hay lugar).
        if let grantedTypeId = roll.grantedUnitTypeId {
            placeGrantedUnit(typeId: grantedTypeId)
        }
        // instantEvolution mutó run.units directamente: re-sincronizar la torre.
        if roll.unitsChanged {
            resyncTower()
        }
        eventLastFired[roll.event.id] = now
        activeEvent = roll.active
        audio?.play(.event)
        bumpBoard()
        scheduleSave()
        Log.economy.info("event fired: \(roll.event.id)")
    }

    /// Coloca una unidad regalada (evento) en el piso de su tier; si el piso está
    /// lleno, el regalo se pierde con log (sin bloquear el evento).
    private func placeGrantedUnit(typeId: String) {
        guard var player, var tower, let content,
              let type = content.tiers.type(id: typeId) else { return }
        let ordinal = content.floorTable.ordinal(forTier: type.tier)
        guard let slot = tower.floors[ordinal].firstFreeSlot() else {
            Log.economy.info("granted unit skipped (floor full): \(typeId)")
            return
        }
        tower.floors[ordinal].slots[slot] = typeId
        player.run.units[typeId, default: 0] += 1
        player.run.maxTierReached = max(player.run.maxTierReached, type.tier)
        self.player = player
        self.tower = tower
        updateMaxFloorStat()
    }

    // MARK: Daily + shares (F5)

    private func claimDailyIfAvailable() {
        guard let economy, let content, var player else { return }
        if let claim = DailyRewardManager.claimIfAvailable(
            state: &player,
            config: content.dailyRewards,
            specials: content.specials,
            upgrades: content.upgradesConfig,
            viral: content.viral,
            economy: economy,
            today: Date(),
            rng: &rng
        ) {
            self.player = player
            dailyClaim = claim
            audio?.play(.daily)
            refreshProjections()
            scheduleSave()
        }
    }

    func dismissDailyClaim() {
        dailyClaim = nil
    }

    /// La escena ofrece el share card al terminar el reveal de evolución.
    func offerShareCard(for type: CharacterType) {
        shareCardSubject = type
    }

    func dismissShareCard() {
        shareCardSubject = nil
    }

    /// Referral local (bible §8): compartir da un boost permanente chico, capeado.
    func registerShareCompleted() {
        guard let economy, let content, var player = player else { return }
        guard player.meta.sharesCompleted < content.viral.maxShares else { return }
        player.meta.sharesCompleted += 1
        UpgradeManager.recomputeDerivedEffects(
            state: &player,
            config: content.upgradesConfig,
            specials: content.specials,
            viral: content.viral,
            economy: economy
        )
        self.player = player
        effectsVersion += 1
        scheduleSave()
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

    private func applyOfflineProgressIfNeeded() {
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
            Log.economy.info("offline earnings credited: \(credited)")
        }
    }

    // MARK: Debug helpers

    #if DEBUG
    func debugGrantCoins() {
        guard var player else { return }
        let grant = max(1_000_000, (currentQuote(player: player)?.cost ?? 0) * 100)
        player.run.coins += grant
        player.meta.lifetimeEarnings += grant
        self.player = player
        refreshProjections()
    }

    /// Coloca un par del tier máximo alcanzado para poder testear la escalera.
    func debugGrantPair() {
        guard let content, var player, var tower else { return }
        let tier = player.run.maxTierReached
        guard let type = content.tiers.concreteTypes.first(where: { candidate in
            candidate.tier == tier && (player.run.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        }) ?? content.tiers.concreteTypes.first(where: { $0.tier == tier }) else { return }

        let ordinal = content.floorTable.ordinal(forTier: type.tier)
        guard let slotA = tower.floors[ordinal].firstFreeSlot() else { return }
        tower.floors[ordinal].slots[slotA] = type.id
        guard let slotB = tower.floors[ordinal].firstFreeSlot() else {
            tower.floors[ordinal].slots[slotA] = nil
            return
        }
        tower.floors[ordinal].slots[slotB] = type.id
        player.run.units[type.id, default: 0] += 2
        if !player.run.unlockedFloors.contains(content.floorTable[ordinal].id) {
            player.run.unlockedFloors.append(content.floorTable[ordinal].id)
        }
        self.player = player
        self.tower = tower
        bumpBoard()
    }

    /// Salta la escalera para playtesting (ej. probar la elección de carrera en T9).
    func debugSetMaxTier(_ tier: Int) {
        guard var player, let content else { return }
        player.run.maxTierReached = min(max(1, tier), content.tiers.maxTier)
        self.player = player
        refreshProjections()
    }

    /// Fixture de UI test: desbloquea pisos por la tabla data-driven, sin tocar
    /// el binario Release ni depender de un save preexistente en el simulador.
    func debugUnlockFloors(throughTier tier: Int) {
        guard var player, let content else { return }
        let highestOrdinal = content.floorTable.ordinal(forTier: tier)
        player.run.unlockedFloors = content.floorTable.floors.prefix(highestOrdinal + 1).map(\.id)
        self.player = player
        visibleFloorOrdinal = 0
        refreshProjections()
    }

    func debugSimulateOffline(hours: Double) {
        guard var player else { return }
        player.meta.lastSeenTimestamp -= hours * 3600
        self.player = player
        applyOfflineProgressIfNeeded()
        refreshProjections()
    }

    func debugResetSave() {
        guard let content else { return }
        player = PlayerState.newGame(
            startTypeId: content.tiers.baseType.id,
            startFloorId: content.floorTable[0].id,
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: content.economy.critChanceBase,
            now: Date().timeIntervalSince1970
        )
        debugTimeScale = 1
        reconcileTower()
        bumpBoard()
        Task { await persistNow() }
    }
    #endif

    // MARK: Internals

    private func currentQuote(player: PlayerState) -> HireQuote? {
        guard let economy, let content else { return nil }
        let prestigeDiscount = content.prestigeUnlocks.cumulativeSpawnDiscount(atPrestigeLevel: player.meta.prestigeLevel)
        return TowerActions.hireQuote(
            floorOrdinal: visibleFloorOrdinal,
            state: player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            economy: economy,
            costMultiplier: 1 - prestigeDiscount,
            now: Date().timeIntervalSince1970
        )
    }

    private func bumpBoard() {
        boardVersion += 1
        refreshProjections()
    }

    /// Updates observed properties, writing only on real change so SwiftUI never
    /// invalidates spuriously.
    private func refreshProjections() {
        guard let content, let player else { return }

        let newCoins = CoinFormatter.string(from: player.run.coins)
        if coinsText != newCoins { coinsText = newCoins }

        let quote = currentQuote(player: player)
        if spawnQuote != quote { spawnQuote = quote }

        // Piso visible lleno o bloqueado ⇒ no se puede contratar.
        let floorFull = visibleFloorOccupancy.occupied >= max(visibleFloorOccupancy.capacity, 1)
        let floorUnlocked = visibleFloorDef.map { player.run.unlockedFloors.contains($0.id) } ?? false
        let allowsHiring = TowerActions.canHire(
            floorOrdinal: visibleFloorOrdinal,
            unlockedFloors: player.run.unlockedFloors,
            floorTable: content.floorTable
        )
        if visibleFloorIsFull != floorFull { visibleFloorIsFull = floorFull }
        if visibleFloorIsUnlocked != floorUnlocked { visibleFloorIsUnlocked = floorUnlocked }
        if visibleFloorAllowsHiring != allowsHiring { visibleFloorAllowsHiring = allowsHiring }
        let affordable = (quote.map { player.run.coins >= $0.cost } ?? false)
            && !floorFull && floorUnlocked && allowsHiring
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

        let skins = Array(player.meta.allOwnedSkins).sorted()
        if ownedSkins != skins { ownedSkins = skins }

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

    private func scheduleSave() {
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
