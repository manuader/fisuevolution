import EconomyKit
import Foundation

/// El paso 2 de una recompensa gratis (E14b B29, D17): ya se cobró con «¡Dale!» y ahora sale, centrado,
/// «¿Lo duplicás?» con la misma recompensa, «×2 con video» y «No, gracias».
///
/// `site` es el id de accesibilidad del botón del video y el lugar del embudo de ofertas (E15): estable
/// por fuente. Los que hay (inventario en `.superpowers/sdd/e14b/task-b29-inventario.md`):
///
/// | `site` | Fuente |
/// |---|---|
/// | `double.visit.<guion>` | regalo, chisme o reto ganado de un visitante (`double.visit.ministro_subsidio`) |
/// | `double.offline` | lo que juntó mientras no estabas |
/// | `double.daily` | el diario (sólo la plata) |
/// | `double.career` | el premio de una vez de la carrera |
/// | `double.wheel` | el giro gratis de la Ruleta (su «repetir premio») |
/// | `double.mattress` | el colchón de regalo (D4) |
/// | `double.achievement` | la plata o el blue de un logro |
/// | `double.event.<evento>` | la plata de un evento (el Aguinaldo) |
struct RewardDouble: Identifiable {
    /// Lo que se paga otra vez si el video se premia: exactamente lo del paso 1, una sola vez.
    enum Payout: Equatable {
        /// La plata ya cotizada y los premios que se cuentan, otra vez por el punto único de premios.
        case grant(coins: Double, rewards: [RewardSpec], source: String)
        case offline(GameState.OfflineReward)
        case daily(DailyRewardManager.Claim)
    }

    /// Dónde se dibuja: sobre el tablero, adentro de la hoja de la Ruleta o adentro del Menú (logros).
    enum Host: Equatable {
        case board, wheel, menu
    }

    let id = UUID()
    let site: String
    let placement: RewardedPlacement
    let host: Host
    let payout: Payout
    /// Lo que muestra el pop-up: la misma recompensa del paso 1.
    let shownCoins: Double
    let shownRewards: [RewardSpec]
    /// Lo que espera a que el paso 2 se resuelva (la cola de celebraciones, un corte natural).
    var followUps: [@MainActor () -> Void] = []
}
