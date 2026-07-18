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
    private(set) var ownedSkins: [String] = []
    private(set) var activeSkin: String?
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

            // Infra de UI tests: estado limpio y determinístico por launch argument.
            var forceNewGame = false
            #if DEBUG
            forceNewGame = ProcessInfo.processInfo.arguments.contains("--uitest-reset")
            #endif

            if !forceNewGame, let saved = await repository.load() {
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
        IncomeTicker.tick(
            state: &player,
            tiers: content.tiers,
            delta: delta * debugTimeScale,
            now: Date().timeIntervalSince1970
        )
        self.player = player
    }

    /// 8 Hz projection flush driven by the scene's frame counter. Also prunes
    /// expired modifiers (cheap; only mutates when something actually expired).
    func flushHUD() {
        if var player {
            let pruned = ModifierMath.prune(&player, now: Date().timeIntervalSince1970)
            if pruned {
                self.player = player
                scheduleSave()
            }
        }
        refreshProjections()
    }

    // MARK: Player actions

    @discardableResult
    func registerTap(cellIndex: Int) -> Double? {
        guard let economy, let content, var player = player,
              let placement = player.board.first(where: { $0.cellIndex == cellIndex }),
              let type = content.tiers.type(id: placement.typeId)
        else { return nil }

        let gain = economy.applyTap(type: type, state: &player, now: Date().timeIntervalSince1970)
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

    // MARK: Store (F4)

    /// StoreKit es la fuente de verdad; acá solo se cachea en el save.
    func applyStoreEntitlements(removedAds: Bool, ownedSkins: [String]) {
        guard var player else { return }
        guard player.removedAds != removedAds || player.ownedSkins != ownedSkins else { return }
        player.removedAds = removedAds
        player.ownedSkins = ownedSkins
        if let active = player.activeSkin, !ownedSkins.contains(active) {
            player.activeSkin = nil
        }
        self.player = player
        bumpBoard()
        scheduleSave()
    }

    func setActiveSkin(_ skinId: String?) {
        guard var player else { return }
        if let skinId, !player.ownedSkins.contains(skinId) { return }
        guard player.activeSkin != skinId else { return }
        player.activeSkin = skinId
        self.player = player
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
            player.activeModifiers.append(ActiveModifier(
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
        guard var player, let content else { return }
        var cellsByType: [String: [Int]] = [:]
        for placement in player.board {
            cellsByType[placement.typeId, default: []].append(placement.cellIndex)
        }
        let candidates = cellsByType
            .filter { $0.value.count >= 2 }
            .sorted { (content.tiers.type(id: $0.key)?.tier ?? 0) > (content.tiers.type(id: $1.key)?.tier ?? 0) }
        for (typeId, cells) in candidates {
            guard case .merged(let newTypeId) = MergeRules.evaluate(
                sourceTypeId: typeId,
                targetTypeId: typeId,
                chosenCareerPath: player.chosenCareerPath,
                tiers: content.tiers
            ) else { continue }
            BoardActions.applyMerge(sourceCell: cells[0], targetCell: cells[1], newTypeId: newTypeId, state: &player, tiers: content.tiers)
            self.player = player
            bumpBoard()
            scheduleSave()
            return
        }
    }

    /// F4: "spawn rare" autosuficiente — dropea una unidad del tier máximo.
    /// F5 lo recablea al drop real de special characters.
    private func grantRareUnit() {
        guard var player, let content else { return }
        let tier = player.maxTierReached
        guard let type = content.tiers.concreteTypes.first(where: { candidate in
            candidate.tier == tier && (player.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        }) ?? content.tiers.concreteTypes.first(where: { $0.tier == tier }) else { return }
        let occupied = Set(player.board.map(\.cellIndex))
        guard let free = (0..<content.economy.board.cellCount).first(where: { !occupied.contains($0) }) else { return }
        player.board.append(BoardPlacement(cellIndex: free, typeId: type.id))
        self.player = player
        bumpBoard()
        scheduleSave()
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
        return economy.spawnQuote(state: player, tiers: content.tiers, costMultiplier: 1 - discount, now: Date().timeIntervalSince1970)
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

        if ownedSkins != player.ownedSkins { ownedSkins = player.ownedSkins }
        if activeSkin != player.activeSkin { activeSkin = player.activeSkin }
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
