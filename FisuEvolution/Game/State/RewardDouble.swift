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
/// | `double.mattress` | el colchón gratis del tablero (B31) |
/// | `double.achievement` | la plata o el blue de un logro |
/// | `double.event.<evento>` | la plata de un evento (el Aguinaldo) |
struct RewardDouble: Identifiable {
    /// Lo que se paga otra vez si el video se premia, una sola vez: lo del paso 1 (la plata, por el ×N de
    /// `multiplier`).
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
    /// El ×N del video (2.1 E15 F2): el de la palanca del segmento para esta fuente, fijado al ofrecer.
    /// Con la base, ×2: el número de la 2.0.
    var multiplier = SegmentLevers.Levers.baseVideoRewardMultiplier
    /// Lo que espera a que el paso 2 se resuelva (la cola de celebraciones, un corte natural).
    var followUps: [@MainActor () -> Void] = []
    /// El video del «×2» está cargando o en pantalla: desde el toque hasta que el anuncio vuelve, con premio
    /// o sin él (y su gracia para el premio tardío). Mientras tanto nada lo rechaza: AdMob presenta encima
    /// de la hoja y SwiftUI puede dar la hoja por cerrada, pero el video visto se cobra.
    var isWatching = false
    /// Un «No, gracias» (o el cierre de la hoja) que llegó con el video en curso: se aplica si el anuncio
    /// vuelve sin premio.
    var declinePending = false

    /// La plata que paga el video y que muestra el pop-up: `shownCoins × (multiplier − 1)`. Con ×2 es,
    /// bit a bit, la del paso 1. Lo que no es plata se paga una vez más con cualquier ×N.
    var extraCoins: Double { shownCoins * (multiplier - 1) }

    /// El ×N no es el de la 2.0: el botón y el título lo dicen.
    var isBoosted: Bool { multiplier != SegmentLevers.Levers.baseVideoRewardMultiplier }
}
