import EconomyKit
import Foundation
import GameKit
import Observation

/// Game Center detrás de `feature_flags.gameCenterEnabled` (bible §4.5: "se codea
/// pero se activa al final"). F6 solo flipea el flag y registra los IDs de
/// `gamecenter.json` en App Store Connect. Con el flag apagado nada de esto corre.
@Observable @MainActor
final class GameCenterManager {
    /// Hito de gameplay que puede desbloquear achievements o subir scores.
    enum Milestone: Equatable {
        case firstMerge
        case reachedTier(Int)
        case firstPrestige
        case scoreUpdate(lifetimeEarnings: Double, maxTier: Int)
    }

    private(set) var isAuthenticated = false
    /// VC de login que Game Center pide presentar; RootView lo muestra si aparece.
    private(set) var pendingAuthViewController: UIViewController?

    private var config: GameCenterConfig?
    private var enabled = false
    @ObservationIgnored private var reportedAchievements: Set<String> = []
    @ObservationIgnored private var lastScoreSubmission: TimeInterval = 0

    func start(content: GameContent) {
        enabled = content.flags.gameCenterEnabled
        config = content.gameCenter
        guard enabled else {
            Log.lifecycle.info("Game Center disabled by feature flag")
            return
        }
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pendingAuthViewController = viewController
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if let error {
                    // Sin GC el juego sigue igual: graceful fallback, nunca bloquear.
                    Log.lifecycle.info("Game Center auth unavailable: \(error.localizedDescription)")
                }
            }
        }
    }

    func report(_ milestone: Milestone) {
        guard enabled, isAuthenticated, let config else { return }

        switch milestone {
        case .firstMerge:
            reportAchievements(config.achievements.filter { $0.trigger == "firstMerge" })
        case .reachedTier(let tier):
            reportAchievements(config.achievements.filter { $0.trigger == "reachTier" && ($0.tier ?? .max) <= tier })
        case .firstPrestige:
            reportAchievements(config.achievements.filter { $0.trigger == "firstPrestige" })
        case .scoreUpdate(let lifetimeEarnings, let maxTier):
            submitScores(lifetimeEarnings: lifetimeEarnings, maxTier: maxTier)
        }
    }

    private func reportAchievements(_ achievements: [GameCenterConfig.Achievement]) {
        let fresh = achievements.filter { !reportedAchievements.contains($0.id) }
        guard !fresh.isEmpty else { return }
        fresh.forEach { reportedAchievements.insert($0.id) }

        let gkAchievements = fresh.map { definition in
            let achievement = GKAchievement(identifier: definition.id)
            achievement.percentComplete = 100
            achievement.showsCompletionBanner = true
            return achievement
        }
        GKAchievement.report(gkAchievements) { error in
            if let error {
                Log.lifecycle.error("achievement report failed: \(error.localizedDescription)")
            }
        }
    }

    private func submitScores(lifetimeEarnings: Double, maxTier: Int) {
        // Throttle: los scores no necesitan subir más de una vez por minuto.
        let now = Date().timeIntervalSince1970
        guard now - lastScoreSubmission > 60 else { return }
        lastScoreSubmission = now

        guard let config else { return }
        let submissions: [(id: String, value: Int)] = config.leaderboards.compactMap { leaderboard in
            switch leaderboard.id {
            case "lb_lifetime_earnings":
                // Clamp obligatorio: Int64(Double) trapea en magnitudes idle.
                (leaderboard.id, Int(SaveConflictResolver.clampedScore(lifetimeEarnings)))
            case "lb_max_tier":
                (leaderboard.id, maxTier)
            default:
                nil
            }
        }
        for submission in submissions {
            GKLeaderboard.submitScore(
                submission.value,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [submission.id]
            ) { error in
                if let error {
                    Log.lifecycle.error("score submit failed (\(submission.id)): \(error.localizedDescription)")
                }
            }
        }
    }
}
