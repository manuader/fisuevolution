import EconomyKit
import SwiftUI

/// Los diez popups del juego, presentados en el contenedor único (E14 C15):
/// centrados sobre el juego atenuado, nunca como hoja desde abajo. Aparte de
/// `GameBoardView`: con una hoja más en su cadena el type-checker se rinde.
///
/// La cola de celebraciones decide de quién es el turno (`gameState.showing`);
/// este modifier sólo dibuja.
struct GamePopups: ViewModifier {
    @Environment(GameState.self) private var gameState
    @Binding var showPrestige: Bool

    func body(content: Content) -> some View {
        content
            .gamePopup(item: careerPromptBinding) { prompt in
                CareerChoiceView(prompt: prompt)
            }
            .gamePopup(item: skinAwardBinding, onDismiss: { gameState.celebrationFinished(.skinAward) }) { award in
                SkinAwardView(award: award, onClose: { gameState.skinAward = nil })
            }
            .gamePopup(item: offlineRewardBinding, onDismiss: {
                // Con el ×2 en pantalla (paso 2, E14b B29) la cola y el corte esperan a que se resuelva.
                gameState.whenRewardDoubleResolved {
                    gameState.celebrationFinished(.offlineEarnings)
                    // El jugador acaba de cobrar lo de la noche y todavía no volvió al
                    // juego: un corte natural. El que duplicó con video tiene la gracia
                    // de 90 s de la política.
                    gameState.scheduleNaturalBreak(.offlinePopupDismissed)
                }
            }) { reward in
                OfflineEarningsView(reward: reward, onClose: { gameState.dismissOfflineReward() })
            }
            .gamePopup(isPresented: $showPrestige) {
                PrestigeView(onClose: { showPrestige = false })
            }
            .gamePopup(item: specialDropBinding) { special in
                SpecialDropView(special: special)
            }
            .gamePopup(item: visitorPopupBinding, onDismiss: { gameState.visitorPopupDismissed() }) { _ in
                VisitorPopupView()
            }
            .gamePopup(item: eventPopupBinding) { popup in
                EventPopupView(eventId: popup.eventId)
            }
            .gamePopup(item: mattressPopupBinding) { _ in
                MattressPopupView(onClose: { gameState.closeMattressPopup() })
            }
            .gamePopup(item: shareCardBinding) { moment in
                ShareCardSheet(moment: moment)
            }
            .gamePopup(item: dailyClaimBinding) { wrapped in
                DailyRewardView(claim: wrapped.claim, onClose: { gameState.dismissDailyClaim() })
            }
    }

    // La cola de celebraciones es el único árbitro: se muestra **si es su turno**
    // y el payload sigue viviendo donde siempre.

    private var careerPromptBinding: Binding<GameState.CareerPrompt?> {
        Binding(
            get: { gameState.showing == .careerChoice ? gameState.careerPrompt : nil },
            set: { gameState.careerPrompt = $0 }
        )
    }

    private var skinAwardBinding: Binding<GameState.SkinAward?> {
        Binding(
            get: { gameState.showing == .skinAward ? gameState.skinAward : nil },
            set: { gameState.skinAward = $0 }
        )
    }

    private var offlineRewardBinding: Binding<GameState.OfflineReward?> {
        Binding(
            get: { gameState.showing == .offlineEarnings ? gameState.offlineReward : nil },
            set: { gameState.offlineReward = $0 }
        )
    }

    private var visitorPopupBinding: Binding<VisitorPopup?> {
        Binding(
            get: { gameState.visitorPopup },
            set: { if $0 == nil { gameState.closeVisitorPopup() } }
        )
    }

    private var eventPopupBinding: Binding<EventPopup?> {
        Binding(
            get: { gameState.eventPopup },
            set: { if $0 == nil { gameState.closeEventPopup() } }
        )
    }

    private var specialDropBinding: Binding<SpecialsConfig.Special?> {
        Binding(
            get: { gameState.showing == .specialDrop ? gameState.specialDrop : nil },
            set: { if $0 == nil { gameState.dismissSpecialDrop() } }
        )
    }

    private var mattressPopupBinding: Binding<MattressPopup?> {
        Binding(
            get: { gameState.mattressPopup },
            set: { if $0 == nil { gameState.closeMattressPopup() } }
        )
    }

    private var shareCardBinding: Binding<ShareMoment?> {
        Binding(
            get: { gameState.shareCardMoment },
            set: { if $0 == nil { gameState.dismissShareCard() } }
        )
    }

    private var dailyClaimBinding: Binding<IdentifiedClaim?> {
        Binding(
            get: {
                guard gameState.showing == .dailyReward, let claim = gameState.dailyClaim else { return nil }
                return IdentifiedClaim(claim: claim)
            },
            set: { if $0 == nil { gameState.dismissDailyClaim() } }
        )
    }

    /// `DailyRewardManager.Claim` no es `Identifiable`; wrapper para `gamePopup(item:)`.
    private struct IdentifiedClaim: Identifiable {
        let id = UUID()
        let claim: DailyRewardManager.Claim
    }
}
