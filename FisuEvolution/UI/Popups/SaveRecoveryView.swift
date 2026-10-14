import SwiftUI

/// "No pudimos leer tu partida": el save existe pero no decodifica. Reintentar o
/// empezar de nuevo; en ningún caso se borra la copia. La confirmación es un
/// segundo estado de la misma tarjeta, no una alerta del sistema.
struct SaveRecoveryView: View {
    @Environment(GameState.self) private var gameState
    @State private var confirmingStartOver = false
    @State private var isWorking = false

    var body: some View {
        ZStack {
            Color("PaletteCream").ignoresSafeArea()
            PanelCard {
                VStack(spacing: Tokens.s16) {
                    PanelTitleBanner(titleKey: confirmingStartOver ? "recovery.confirm.title" : "recovery.title")
                    GameIcon(artKey: "ui_save_rescate", size: 124) {
                        IconCanvas { MarkDisc(mark: "!", fill: GameTint.alert) }
                    }
                    .accessibilityHidden(true)
                    Text(confirmingStartOver ? "recovery.confirm.body" : "recovery.body")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    actions
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, Tokens.s16)
        }
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("recovery.screen")
        )
    }

    @ViewBuilder private var actions: some View {
        if isWorking {
            ProgressView().tint(Color("PaletteInk"))
        } else if confirmingStartOver {
            HStack(spacing: Tokens.s12) {
                GameButton("recovery.confirm.no", role: .neutral, medallion: .glyph(.undo), fullWidth: true,
                           identifier: "recovery.confirm.no") {
                    confirmingStartOver = false
                }
                GameButton("recovery.confirm.yes", role: .coins, medallion: .glyph(.sparkle), fullWidth: true,
                           identifier: "recovery.confirm.yes") {
                    perform { await gameState.startOverFromRecovery() }
                }
            }
        } else {
            HStack(spacing: Tokens.s12) {
                GameButton("recovery.retry", role: .free, medallion: .glyph(.retry), fullWidth: true,
                           identifier: "recovery.retry") {
                    perform { await gameState.retryLoad() }
                }
                GameButton("recovery.start_over", role: .coins, medallion: .glyph(.sparkle), fullWidth: true,
                           identifier: "recovery.start_over") {
                    confirmingStartOver = true
                }
            }
        }
    }

    private func perform(_ work: @escaping @MainActor () async -> Void) {
        isWorking = true
        Task {
            await work()
            isWorking = false
        }
    }
}
