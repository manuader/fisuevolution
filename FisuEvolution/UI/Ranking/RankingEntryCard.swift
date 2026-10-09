import EconomyKit
import SwiftUI

/// La tarjeta de la llegada a Dios: el tiempo, el nombre y la entrada al ranking. Va como `.overlay`
/// de quien la presenta (el velo y el marco son los de `GameConfirmCard`); no decide cuándo salir:
/// la cierra quien la monta cuando el store suelta el `entryPrompt`.
struct RankingEntryCard: View {
    let prompt: EntryPrompt
    var nameError: NameError?
    var isSubmitting = false
    let onSubmit: (String) -> Void
    let onLater: () -> Void

    @State private var name: String

    init(
        prompt: EntryPrompt, nameError: NameError? = nil, isSubmitting: Bool = false,
        onSubmit: @escaping (String) -> Void, onLater: @escaping () -> Void
    ) {
        self.prompt = prompt
        self.nameError = nameError
        self.isSubmitting = isSubmitting
        self.onSubmit = onSubmit
        self.onLater = onLater
        _name = State(initialValue: NameRules.filterTyping(prompt.lastName ?? ""))
    }

    private var canSubmit: Bool {
        if case .success = NameRules.validate(name) { return !isSubmitting }
        return false
    }

    private var errorKey: LocalizedStringKey? {
        switch nameError {
        case .rejected?: "ranking.entry.rejected"
        case .invalid(.empty)?: "ranking.entry.error.empty"
        case .invalid(.tooLong)?: "ranking.entry.error.too_long"
        case .invalid(.forbidden)?: "ranking.entry.error.forbidden"
        case nil: nil
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            PanelCard {
                VStack(spacing: Tokens.s12) {
                    title
                    if prompt.underReview {
                        Text("ranking.entry.review")
                            .font(Tokens.caption)
                            .foregroundStyle(Color("PaletteInk").opacity(0.75))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("ranking.entry.prompt")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk").opacity(0.75))
                        .multilineTextAlignment(.center)
                    RankingNameField(text: $name) { if canSubmit { onSubmit(name) } }
                    if let errorKey {
                        Text(errorKey)
                            .font(Tokens.caption)
                            .foregroundStyle(Color("PalettePink").deepened(0.25))
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("ranking.entry.error")
                    }
                    if prompt.realSeconds == nil {
                        Text("ranking.entry.offline")
                            .font(Tokens.caption)
                            .foregroundStyle(Color("PaletteInk").opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ActionPill(
                        titleKey: "ranking.entry.submit", systemImage: "trophy.fill",
                        identifier: "ranking.entry.submit") { onSubmit(name) }
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.45)
                    Button(action: onLater) {
                        Text("ranking.entry.later")
                            .font(Tokens.body)
                            .foregroundStyle(Color("PaletteInk").opacity(0.75))
                            .padding(.vertical, Tokens.s8)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ranking.entry.later")
                }
            }
            .frame(maxWidth: 360)
            .padding(Tokens.s24)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }

    @ViewBuilder private var title: some View {
        Group {
            if let seconds = prompt.realSeconds {
                Text(verbatim: String(
                    format: RankingCopy.text("ranking.entry.title"), RankingCopy.duration(seconds)))
            } else {
                Text("ranking.entry.title.unsealed")
            }
        }
        .font(Tokens.title)
        .foregroundStyle(Color("PaletteInk"))
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("ranking.entry.card")
    }
}

#Preview("Normal") {
    RankingEntryCard(
        prompt: EntryPrompt(realSeconds: 116_040, underReview: false, lastName: "Fisu"),
        onSubmit: { _ in }, onLater: {})
}

#Preview("En revisión") {
    RankingEntryCard(
        prompt: EntryPrompt(realSeconds: 5_400, underReview: true, lastName: nil),
        onSubmit: { _ in }, onLater: {})
}

#Preview("Nombre rechazado") {
    RankingEntryCard(
        prompt: EntryPrompt(realSeconds: 116_040, underReview: false, lastName: "Fisu"),
        nameError: .rejected, onSubmit: { _ in }, onLater: {})
}

#Preview("Sin red") {
    RankingEntryCard(
        prompt: EntryPrompt(realSeconds: nil, underReview: false, lastName: nil),
        onSubmit: { _ in }, onLater: {})
}
