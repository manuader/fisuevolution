import EconomyKit
import Foundation
import Observation
import SwiftUI

/// The single source of truth shared by SwiftUI (HUD, popups) and SpriteKit (board).
///
/// Architecture (bible §4.1 + Docs/concurrency-conventions.md):
/// - `player` is the authoritative state but `@ObservationIgnored`: the income tick
///   mutates it every frame and MUST NOT invalidate SwiftUI.
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
        let sourceCell: Int
        let targetCell: Int
    }

    struct PassivePrompt: Identifiable, Equatable {
        let id = UUID()
        let type: CharacterType
        let instanceCount: Int
        let isUnlocked: Bool
        let canAfford: Bool
    }

    struct OfflineReward: Identifiable, Equatable {
        let id = UUID()
        let amount: Double
    }

    enum DropResolution {
        case merged(targetCell: Int)
        case moved
        case careerPending
        case snapBack
    }

    // MARK: Observed projections (UI)

    private(set) var phase: Phase = .loading
    private(set) var coinsText = "0"
    private(set) var boardVersion = 0
    private(set) var spawnQuote: SpawnQuote?
    private(set) var canAffordSpawn = false
    private(set) var unitCount = 0
    private(set) var prestigeAvailable = false
    private(set) var soulPointsText = "0"
    var careerPrompt: CareerPrompt?
    var passivePrompt: PassivePrompt?
    var offlineReward: OfflineReward?

    // MARK: Authoritative state

    @ObservationIgnored private(set) var player: PlayerState?
    private(set) var content: GameContent?
    @ObservationIgnored var debugTimeScale: Double = 1

    private var economy: StandardEconomy?
    private var repository: PlayerStateRepository?
    private let injectedRepository: PlayerStateRepository?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(repository: PlayerStateRepository? = nil) {
        self.injectedRepository = repository
    }

    // MARK: Bootstrap

    func bootstrap() async {
        do {
            let content = try GameContentLoader.load(from: .main)
            self.content = content
            self.economy = StandardEconomy(config: content.economy)

            let repository = injectedRepository ?? PlayerStateRepository(
                persistence: PersistenceController(),
                snapshotURL: PlayerStateRepository.defaultSnapshotURL()
            )
            self.repository = repository

            if let saved = await repository.load() {
                player = saved
                Log.lifecycle.info("save loaded: prestige \(saved.prestigeLevel), maxTier \(saved.maxTierReached)")
            } else {
                let fresh = PlayerState.newGame(
                    startTypeId: content.tiers.baseType.id,
                    offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
                    critChanceBase: content.economy.critChanceBase,
                    now: Date().timeIntervalSince1970
                )
                player = fresh
                await repository.save(fresh)
                Log.lifecycle.info("new game started")
            }

            applyOfflineProgressIfNeeded()
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

    // MARK: Frame loop (called by BoardScene)

    /// Passive income tick. Mutates only non-observed state — zero SwiftUI work.
    func tick(delta: TimeInterval) {
        guard let content, var player else { return }
        IncomeTicker.tick(state: &player, tiers: content.tiers, delta: delta * debugTimeScale)
        self.player = player
    }

    /// 8 Hz projection flush driven by the scene's frame counter.
    func flushHUD() {
        refreshProjections()
    }

    // MARK: Player actions

    @discardableResult
    func registerTap(cellIndex: Int) -> Double? {
        guard let economy, let content, var player = player,
              let placement = player.board.first(where: { $0.cellIndex == cellIndex }),
              let type = content.tiers.type(id: placement.typeId)
        else { return nil }

        let gain = economy.applyTap(type: type, state: &player)
        self.player = player
        refreshProjections()
        scheduleSave()
        return gain
    }

    func buySpawn() {
        guard let economy, let content, var player = player,
              let quote = currentQuote(player: player)
        else { return }
        do {
            try economy.applySpawn(quote: quote, state: &player, boardCapacity: content.economy.board.cellCount)
            self.player = player
            bumpBoard()
            scheduleSave()
        } catch {
            Log.economy.info("spawn rejected: \(error)")
        }
    }

    /// Resolves a drag-drop from the scene (bible §2.3 regla 2 + choice node T9).
    func handleDrop(fromCell: Int, toCell: Int) -> DropResolution {
        guard let content, var player = player, fromCell != toCell,
              let source = player.board.first(where: { $0.cellIndex == fromCell })
        else { return .snapBack }

        guard let target = player.board.first(where: { $0.cellIndex == toCell }) else {
            if BoardActions.moveUnit(fromCell: fromCell, toCell: toCell, state: &player) {
                self.player = player
                bumpBoard()
                scheduleSave()
                return .moved
            }
            return .snapBack
        }

        switch MergeRules.evaluate(
            sourceTypeId: source.typeId,
            targetTypeId: target.typeId,
            chosenCareerPath: player.chosenCareerPath,
            tiers: content.tiers
        ) {
        case .merged(let newTypeId):
            BoardActions.applyMerge(sourceCell: fromCell, targetCell: toCell, newTypeId: newTypeId, state: &player, tiers: content.tiers)
            self.player = player
            bumpBoard()
            scheduleSave()
            return .merged(targetCell: toCell)
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
        guard let prompt = careerPrompt, let content, var player = player else { return }
        player.chosenCareerPath = MergeRules.careerPath(fromOptionId: optionId)

        guard let source = player.board.first(where: { $0.cellIndex == prompt.sourceCell }),
              let target = player.board.first(where: { $0.cellIndex == prompt.targetCell }),
              case .merged(let newTypeId) = MergeRules.evaluate(
                  sourceTypeId: source.typeId,
                  targetTypeId: target.typeId,
                  chosenCareerPath: player.chosenCareerPath,
                  tiers: content.tiers
              )
        else {
            self.player = player
            careerPrompt = nil
            refreshProjections()
            return
        }

        BoardActions.applyMerge(
            sourceCell: prompt.sourceCell,
            targetCell: prompt.targetCell,
            newTypeId: newTypeId,
            state: &player,
            tiers: content.tiers
        )
        self.player = player
        careerPrompt = nil
        bumpBoard()
        scheduleSave()
    }

    /// Long-press on a unit → passive unlock prompt for its type (§2.3 regla 3).
    func presentPassivePrompt(cellIndex: Int) {
        guard let content, let player,
              let placement = player.board.first(where: { $0.cellIndex == cellIndex }),
              let type = content.tiers.type(id: placement.typeId)
        else { return }
        passivePrompt = PassivePrompt(
            type: type,
            instanceCount: player.board.count(where: { $0.typeId == type.id }),
            isUnlocked: player.passiveUnlocked[type.id] == true,
            canAfford: player.coins >= type.passiveUnlockCost
        )
    }

    func unlockPassive(typeId: String) {
        guard let economy, let content, var player = player else { return }
        do {
            try economy.applyPassiveUnlock(typeId: typeId, state: &player, tiers: content.tiers)
            self.player = player
            passivePrompt = nil
            refreshProjections()
            scheduleSave()
        } catch {
            Log.economy.info("passive unlock rejected: \(error)")
        }
    }

    var prestigeSoulPointsGained: Int {
        guard let economy, let player else { return 0 }
        return PrestigeCalculator.soulPointsGained(state: player, economy: economy)
    }

    func confirmPrestige() {
        guard let economy, let content, var player = player,
              PrestigeCalculator.canPrestige(state: player, tiers: content.tiers)
        else { return }
        PrestigeCalculator.applyPrestige(
            state: &player,
            economy: economy,
            tiers: content.tiers,
            now: Date().timeIntervalSince1970
        )
        self.player = player
        bumpBoard()
        Task { await persistNow() }
        Log.economy.info("prestige applied: level \(player.prestigeLevel), soulPoints \(player.soulPoints)")
    }

    // MARK: Lifecycle (offline + immediate save)

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .background, .inactive:
            guard var player else { return }
            player.lastSeenTimestamp = Date().timeIntervalSince1970
            self.player = player
            saveTask?.cancel()
            Task { await persistNow() }
        case .active:
            guard phase == .ready else { return }
            applyOfflineProgressIfNeeded()
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
        player.coins += grant
        player.lifetimeEarnings += grant
        self.player = player
        refreshProjections()
    }

    /// Coloca un par del tier máximo alcanzado para poder testear la escalera.
    func debugGrantPair() {
        guard let content, var player else { return }
        let tier = player.maxTierReached
        guard let type = content.tiers.concreteTypes.first(where: { candidate in
            candidate.tier == tier && (player.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        }) ?? content.tiers.concreteTypes.first(where: { $0.tier == tier }) else { return }

        let occupied = Set(player.board.map(\.cellIndex))
        let capacity = content.economy.board.cellCount
        let free = (0..<capacity).filter { !occupied.contains($0) }.prefix(2)
        guard free.count == 2 else { return }
        for cell in free {
            player.board.append(BoardPlacement(cellIndex: cell, typeId: type.id))
        }
        self.player = player
        bumpBoard()
    }

    /// Salta la escalera para playtesting (ej. probar la elección de carrera en T9).
    func debugSetMaxTier(_ tier: Int) {
        guard var player, let content else { return }
        player.maxTierReached = min(max(1, tier), content.tiers.maxTier)
        self.player = player
        refreshProjections()
    }

    func debugSimulateOffline(hours: Double) {
        guard var player else { return }
        player.lastSeenTimestamp -= hours * 3600
        self.player = player
        applyOfflineProgressIfNeeded()
        refreshProjections()
    }

    func debugResetSave() {
        guard let content else { return }
        player = PlayerState.newGame(
            startTypeId: content.tiers.baseType.id,
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: content.economy.critChanceBase,
            now: Date().timeIntervalSince1970
        )
        debugTimeScale = 1
        bumpBoard()
        Task { await persistNow() }
    }
    #endif

    // MARK: Internals

    private func currentQuote(player: PlayerState) -> SpawnQuote? {
        guard let economy, let content else { return nil }
        let discount = content.prestigeUnlocks.cumulativeSpawnDiscount(atPrestigeLevel: player.prestigeLevel)
        return economy.spawnQuote(state: player, tiers: content.tiers, costMultiplier: 1 - discount)
    }

    private func bumpBoard() {
        boardVersion += 1
        refreshProjections()
    }

    /// Updates observed properties, writing only on real change so SwiftUI never
    /// invalidates spuriously.
    private func refreshProjections() {
        guard let content, let player else { return }

        let newCoins = CoinFormatter.string(from: player.coins)
        if coinsText != newCoins { coinsText = newCoins }

        let quote = currentQuote(player: player)
        if spawnQuote != quote { spawnQuote = quote }

        let affordable = quote.map { player.coins >= $0.cost } ?? false
        if canAffordSpawn != affordable { canAffordSpawn = affordable }

        if unitCount != player.board.count { unitCount = player.board.count }

        let prestige = PrestigeCalculator.canPrestige(state: player, tiers: content.tiers)
        if prestigeAvailable != prestige { prestigeAvailable = prestige }

        let souls = String(player.soulPoints)
        if soulPointsText != souls { soulPointsText = souls }
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
    }
}
