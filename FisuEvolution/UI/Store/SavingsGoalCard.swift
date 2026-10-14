import SwiftUI

/// La cabecera de las dos pestañas de blue de Mejoras: el saldo grande con su
/// ícono y el «+» que lleva a la Tienda a comprar más (el único puente hacia la
/// plata real, y sólo si el jugador lo toca).
struct BlueBalanceHeader: View {
    let text: String
    let onStore: () -> Void

    var body: some View {
        HStack(spacing: Tokens.s8) {
            BlueBalancePill(text: text)
            Button(action: onStore) {
                Text(verbatim: "+")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 0, y: 1.5)
                    .frame(width: 44, height: 44)
                    .background(PillBackground(fill: Color("PaletteGreen"), cornerRadius: 22))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("upgrades.blue.plus")
            .accessibilityLabel(Text("upgrades.blue.plus.ax"))
        }
    }
}

/// «Tu meta» (C29): la próxima permanente recomendada, con la barra del ahorro.
/// Cuando alcanza, la barra se vuelve el botón «¡Comprar!». Un solo cobro por
/// toque: el cerrojo corta el segundo, el botón nunca se apaga.
struct SavingsGoalCard: View {
    @Environment(GameState.self) private var gameState
    let goal: SavingsGoal

    @State private var latch = PurchaseLatch()

    private static let latchSeconds = 0.6

    var body: some View {
        let copy = gameState.permanentOfferCopy(goal.offer)
        GameCard(style: .highlighted(Color("PaletteBlue"))) {
            VStack(alignment: .leading, spacing: Tokens.s8) {
                HStack {
                    Text("upgrades.goal.title")
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                    Spacer(minLength: Tokens.s8)
                    Button { gameState.cycleSavingsGoal() } label: {
                        Text("upgrades.goal.change")
                            .font(Tokens.caption)
                            .underline()
                            .foregroundStyle(Color("PaletteInk").opacity(0.75))
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("upgrades.goal.change")
                }
                HStack(spacing: Tokens.s12) {
                    icon(copy?.iconKey)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: copy?.name ?? goal.offer.id)
                            .font(Tokens.title)
                            .foregroundStyle(Color("PaletteInk"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(verbatim: copy?.effect ?? "")
                            .font(Tokens.body)
                            .monospacedDigit()
                            .foregroundStyle(Color("PaletteBlue"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if goal.isReady {
                    GameButton(
                        "upgrades.goal.buy", role: .free, medallion: .glyph(.blue), fullWidth: true,
                        identifier: "upgrades.goal.buy",
                        accessibilityLabel: Text("upgrades.goal.buy.ax \(copy?.name ?? goal.offer.id)")
                    ) {
                        buy()
                    }
                } else {
                    ProgressBar(
                        progress: goal.progress,
                        tint: Color("PaletteBlue"),
                        labelText: String(localized: "upgrades.goal.saving \(String(goal.saved)) \(String(goal.offer.price))")
                    )
                    .accessibilityIdentifier("upgrades.goal.bar")
                }
            }
        }
    }

    private func buy() {
        guard latch.claim() else { return }
        gameState.buyPermanentOffer(goal.offer)
        Task {
            try? await Task.sleep(for: .seconds(Self.latchSeconds))
            latch.release()
        }
    }

    private func icon(_ key: String?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Color.clear
            .frame(width: 48, height: 48)
            .overlay {
                GameGlyphView(glyph: .art(key ?? ""), size: 36)
            }
            .background(Color("PaletteYellow").opacity(0.3))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
            .accessibilityHidden(true)
    }
}
