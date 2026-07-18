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

    private var repository: PlayerStateRepository?
    private let injectedRepository: PlayerStateRepository?

    /// F1 replaces this raw value with `CoinFormatter` output throttled to 8 Hz.
    var coins: Double { player?.coins ?? 0 }

    init(repository: PlayerStateRepository? = nil) {
        self.injectedRepository = repository
    }

    /// Loads bundled content, then the save (or starts a new game). Called once from
    /// the app's root `.task`.
    func bootstrap() async {
        do {
            let content = try GameContentLoader.load(from: .main)
            self.content = content

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
}
