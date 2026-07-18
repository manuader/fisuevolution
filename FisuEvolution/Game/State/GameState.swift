import EconomyKit
import Foundation
import Observation

/// The single source of truth shared by SwiftUI (HUD, popups) and SpriteKit (board).
/// SwiftUI observes it; the board scene reads and mutates it through methods here.
/// Everything is MainActor — per-frame work stays inside SpriteKit (see F2 tick design).
@Observable @MainActor
final class GameState {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var content: GameContent?
    private(set) var player: PlayerState?
    /// Bumped whenever board composition changes; the scene compares it per frame
    /// and relayouts only on change (no Observation plumbing inside SpriteKit).
    private(set) var boardVersion = 0

    private var economy: StandardEconomy?
    private var repository: PlayerStateRepository?
    private let injectedRepository: PlayerStateRepository?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    var coins: Double { player?.coins ?? 0 }
    var coinsText: String { CoinFormatter.string(from: coins) }

    /// What the spawn shop offers right now (progressive-spawn quote).
    var spawnQuote: SpawnQuote? {
        guard let economy, let content, let player else { return nil }
        return economy.spawnQuote(state: player, tiers: content.tiers)
    }

    var canAffordSpawn: Bool {
        guard let spawnQuote, let player else { return false }
        return player.coins >= spawnQuote.cost
    }

    init(repository: PlayerStateRepository? = nil) {
        self.injectedRepository = repository
    }

    /// Loads bundled content, then the save (or starts a new game). Called once from
    /// the app's root `.task`.
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

    /// Bible §2.3 rule 1 — tap a character, earn coins. Returns the gain for the
    /// scene's feedback (bounce + floating label); nil if the cell is empty.
    @discardableResult
    func registerTap(cellIndex: Int) -> Double? {
        guard let economy, let content, var player = player,
              let placement = player.board.first(where: { $0.cellIndex == cellIndex }),
              let type = content.tiers.type(id: placement.typeId)
        else { return nil }

        let gain = economy.applyTap(type: type, state: &player)
        self.player = player
        scheduleSave()
        return gain
    }

    /// Bible §2.3 rule 4 (con spawn progresivo) — buy the quoted unit.
    func buySpawn() {
        guard let economy, let content, var player = player,
              let quote = economy.spawnQuote(state: player, tiers: content.tiers)
        else { return }
        do {
            try economy.applySpawn(quote: quote, state: &player, boardCapacity: content.economy.board.cellCount)
            self.player = player
            boardVersion += 1
            scheduleSave()
        } catch {
            Log.economy.info("spawn rejected: \(error)")
        }
    }

    /// Debounced autosave: mutations schedule a save 2s out; rapid taps collapse
    /// into one write. F2 adds the immediate save on background transition.
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
