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
                ActionPill(titleKey: "recovery.confirm.no", systemImage: "arrow.uturn.backward",
                           tint: Color("PaletteBrown"), identifier: "recovery.confirm.no") {
                    confirmingStartOver = false
                }
                ActionPill(titleKey: "recovery.confirm.yes", systemImage: "sparkles",
                           tint: Color("PalettePink"), identifier: "recovery.confirm.yes") {
                    perform { await gameState.startOverFromRecovery() }
                }
            }
        } else {
            HStack(spacing: Tokens.s12) {
                ActionPill(titleKey: "recovery.retry", systemImage: "arrow.clockwise",
                           identifier: "recovery.retry") {
                    perform { await gameState.retryLoad() }
                }
                ActionPill(titleKey: "recovery.start_over", systemImage: "sparkles",
                           tint: Color("PaletteOrange"), identifier: "recovery.start_over") {
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
