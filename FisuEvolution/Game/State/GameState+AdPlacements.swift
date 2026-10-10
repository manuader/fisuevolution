import EconomyKit
import Foundation

/// Los dos videos de la unidad `daily` (PLAN-v2 E7, mapa de ubicaciones): el
/// diario ×2 y la carrera ×2. Opt-in, con el premio a la vista antes del video.
extension GameState {
    /// La clave de `meta.rewardedActivations`: cuándo se duplicó el último diario.
    static let dailyDoubleKey = "daily.x2"

    /// Si el diario de hoy ya se duplicó. El diario se cobra una vez por día,
    /// así que "hoy" alcanza para decir "este".
    func dailyRewardDoubled(now: Date = Date()) -> Bool {
        guard let last = player?.meta.rewardedActivations[Self.dailyDoubleKey] else { return false }
        return DailyRewardManager.dayString(for: Date(timeIntervalSince1970: last))
            == DailyRewardManager.dayString(for: now)
    }

    /// Sólo la plata se duplica: el special y el cofre del día 7 no.
    func canDoubleDailyReward(_ claim: DailyRewardManager.Claim, now: Date = Date()) -> Bool {
        claim.coinsGranted > 0 && !dailyRewardDoubled(now: now)
    }

    /// Terminó el video del ×2: se paga otra vez lo que el popup muestra (el
    /// diario ya se acreditó al aparecer, con el ×3 de la tienda si lo había).
    func doubleDailyReward(_ claim: DailyRewardManager.Claim, now: Date = Date()) {
        guard canDoubleDailyReward(claim, now: now), var player else { return }
        player.run.coins += claim.coinsGranted
        player.meta.lifetimeEarnings += claim.coinsGranted
        player.meta.rewardedActivations[Self.dailyDoubleKey] = now.timeIntervalSince1970
        player.meta.stats.videosWatchedEver += 1
        self.player = player
        audio?.play(.coin)
        refreshProjections()
        evaluateAchievements()
        scheduleSave()
    }

    /// Los minutos del premio de una vez de esa carrera (Juicio ganado, Obra
    /// social), o `nil` si su premio no es plata.
    func careerLumpMinutes(optionId: String) -> Double? {
        guard let minutes = content?.careers.careers.first(where: { $0.id == optionId })?.lumpMinutes,
              minutes > 0
        else { return nil }
        return minutes
    }

    /// Elegir carrera con el ×2 del video: lo de siempre, y el premio de una vez
    /// se paga otra vez con la misma cuenta. `chooseCareer` acredita antes del
    /// merge (E1 T12): las dos pagas caen en el mismo instante.
    func chooseCareerWithVideo(optionId: String) {
        let minutes = careerLumpMinutes(optionId: optionId)
        chooseCareer(optionId: optionId)
        guard var player else { return }
        player.meta.stats.videosWatchedEver += 1
        self.player = player
        if let minutes {
            grant(.coinsSeconds(minutes * 60), source: "career.x2.\(optionId)")
        }
        evaluateAchievements()
    }
}
