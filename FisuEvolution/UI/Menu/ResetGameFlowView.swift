import EconomyKit
import SwiftUI

/// "Resetear partida" (PLAN-v2 E9): tres pasos con números, y ningún botón deshabilitado: el
/// que no corresponde tiembla. Se empuja en la pila del menú, como los legales. El plan se arma
/// al entrar y vive en `@State`: lo que se muestra es lo que se ejecuta, y si la partida cambió
/// mientras tanto (`.stale`) se arma otro y se vuelve a mostrar.
struct ResetGameFlowView: View {
    enum ResetFlowStep { case summary, word, hold }

    /// Lo que la pantalla hace con cómo terminó `resetGame`.
    enum Reaction: Equatable {
        case leave
        case rearm
        case show(Notice)
    }

    enum Notice: Equatable {
        case stale
        case noBackup
        case writeFailed

        var messageKey: String {
            switch self {
            case .stale: "reset.notice.stale"
            case .noBackup: "reset.notice.no_backup"
            case .writeFailed: "reset.notice.write_failed"
            }
        }
    }

    let close: () -> Void

    @Environment(GameState.self) private var gameState
    @Environment(StoreManager.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plan: ResetPlan?
    @State private var step = ResetFlowStep.summary
    @State private var understood = false
    @State private var typed = ""
    @State private var holding = false
    @State private var holdFired = false
    @State private var running = false
    @State private var shakes = 0
    @State private var notice: Notice?
    @State private var askLeave = false

    static let holdSeconds: Double = 3

    static func matchesWord(_ typed: String, word: String) -> Bool {
        let clean = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && clean.compare(word, options: .caseInsensitive) == .orderedSame
    }

    /// Si el botón "Seguir" de `step` avanza. Cuando no, la pantalla tiembla en vez de apagarlo.
    static func canAdvance(from step: ResetFlowStep, understood: Bool, typed: String, word: String) -> Bool {
        switch step {
        case .summary: understood
        case .word: matchesWord(typed, word: word)
        case .hold: false
        }
    }

    static func reaction(to outcome: GameState.ResetOutcome) -> Reaction {
        switch outcome {
        case .done: .leave
        case .stale: .rearm
        case .noBackup: .show(.noBackup)
        case .writeFailed: .show(.writeFailed)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.s12) {
                if let notice {
                    StateBadge(text: String(localized: String.LocalizationValue(notice.messageKey)),
                               systemImage: "exclamationmark.triangle.fill", textAlignment: .center, muted: false)
                        .accessibilityIdentifier("reset.notice")
                }
                switch step {
                case .summary: summaryCard
                case .word: wordCard
                case .hold: holdCard
                }
            }
            .padding(.horizontal, MenuView.panelInset)
            .padding(.vertical, Tokens.s12)
        }
        .panelSheet { PanelTitleBanner(titleKey: "reset.title") }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ArtCloseButton(action: requestLeave) } }
        .navigationBarBackButtonHidden(running)
        .overlay {
            if askLeave {
                GameConfirmCard(
                    titleKey: "reset.leave.title",
                    message: Text("reset.leave.body"),
                    confirmTitleKey: "reset.leave.confirm",
                    confirmSystemImage: "arrow.uturn.backward",
                    confirmTint: Color("PaletteBlue"),
                    cancelTitleKey: "reset.leave.stay",
                    onConfirm: requestLeave,
                    onCancel: { askLeave = false }
                )
            }
        }
        .onAppear { plan = plan ?? gameState.resetPlan() }
        .onDisappear { plan = nil }
    }

    /// Irse a pedido del jugador. Con el reset corriendo no se puede: el resultado tiene que
    /// verse acá (un `.done` borraría la partida después de un «Tu partida queda como está»).
    /// No se deshabilita nada: tiembla.
    private func requestLeave() {
        guard !running else {
            shakes += 1
            return
        }
        leave()
    }

    private func leave() {
        plan = nil
        close()
    }

    // MARK: Paso 1: el resumen

    @ViewBuilder private var summaryCard: some View {
        if let summary = plan?.summary {
            GameCard(style: .normal) {
                VStack(alignment: .leading, spacing: Tokens.s8) {
                    Text("reset.summary.lost").font(Tokens.body.weight(.heavy))
                    row("reset.summary.prestige \(String(summary.prestigeLevel))")
                    row("reset.summary.units \(String(summary.unitsOnBoard))")
                    row("reset.summary.achievements \(String(summary.achievements))")
                    row("reset.summary.skins \(String(summary.skinsLost))")
                    row("reset.summary.triple")
                    RowDivider()
                    Text("reset.summary.kept").font(Tokens.body.weight(.heavy))
                    if summary.keepsRemoveAds { row("reset.summary.no_ads") }
                    row("reset.summary.iap_skins \(String(summary.keptSkins))")
                    RowDivider()
                    Text("reset.summary.oro \(summary.oroBalance.formatted()) \(summary.oroPurchased.formatted()) \(summary.oroEarned.formatted()) \(summary.oroKept.formatted())")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("reset.summary.oro")
                    row("reset.summary.refund")
                    understandToggle
                    nextButton()
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reset.summary")
        }
    }

    private func row(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Tokens.caption)
            .foregroundStyle(Color("PaletteInk").opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var understandToggle: some View {
        Button { understood.toggle() } label: {
            HStack(spacing: Tokens.s8) {
                Image(systemName: understood ? "checkmark.square.fill" : "square")
                    .foregroundStyle(understood ? Color("PalettePink") : Color("PaletteInk").opacity(0.5))
                Text("reset.understand").font(Tokens.body).foregroundStyle(Color("PaletteInk"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reset.understand")
        .accessibilityValue(Text(verbatim: understood ? "on" : "off"))
        .accessibilityAddTraits(.isToggle)
    }

    // MARK: Paso 2: la palabra

    private var wordCard: some View {
        GameCard(style: .normal) {
            VStack(alignment: .leading, spacing: Tokens.s8) {
                Text("reset.word.prompt \(String(localized: "reset.word"))").font(Tokens.body)
                TextField(String(localized: "reset.word"), text: $typed)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .padding(Tokens.s8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color("PaletteCream")))
                    .accessibilityIdentifier("reset.word")
                nextButton()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Paso 3: mantener 3 s

    private var holdCard: some View {
        GameCard(style: .normal) {
            VStack(spacing: Tokens.s12) {
                Text("reset.hold.prompt").font(Tokens.body).multilineTextAlignment(.center)
                ZStack {
                    Circle().stroke(Color("PalettePink").opacity(0.25), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: holding ? 1 : 0)
                        .stroke(Color("PalettePink"), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(holding ? .linear(duration: Self.holdSeconds) : .easeOut(duration: 0.2), value: holding)
                    Text("reset.hold").font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color("PalettePink"))
                }
                .frame(width: 140, height: 140)
                .contentShape(Circle())
                .modifier(Shake(trigger: shakes, reduceMotion: reduceMotion))
                .onLongPressGesture(minimumDuration: Self.holdSeconds) {
                    holdFired = true
                    Task { await execute() }
                } onPressingChanged: { pressing in
                    holding = pressing
                    if pressing {
                        holdFired = false
                    } else if !holdFired {
                        shakes += 1
                    }
                }
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text("reset.hold"))
                .accessibilityIdentifier("reset.hold")
                Button("reset.cancel") {
                    guard !running else {
                        shakes += 1
                        return
                    }
                    askLeave = true
                }
                    .font(Tokens.caption)
                    .accessibilityIdentifier("reset.cancel")
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Ejecutar

    private func execute() async {
        guard let plan, !running else { return }
        running = true
        defer { running = false }
        let outcome = await gameState.resetGame(plan, repushEntitlements: store.repushEntitlements)
        switch Self.reaction(to: outcome) {
        case .leave:
            Task { await store.retryUnfinished() }
            leave()
        case .rearm:
            self.plan = gameState.resetPlan()
            step = .summary
            understood = false
            typed = ""
            notice = .stale
        case .show(let reason):
            notice = reason
        }
    }

    // MARK: El botón que tiembla

    private func nextButton() -> some View {
        ActionPill(titleKey: "reset.next", systemImage: "arrow.right", tint: Color("PalettePink"),
                   identifier: "reset.next", action: advance)
            .modifier(Shake(trigger: shakes, reduceMotion: reduceMotion))
    }

    private func advance() {
        let word = String(localized: "reset.word")
        guard Self.canAdvance(from: step, understood: understood, typed: typed, word: word) else {
            shakes += 1
            return
        }
        notice = nil
        step = step == .summary ? .word : .hold
    }
}

/// El temblor de "falta algo": un golpe por disparo, nunca en bucle. Con Reduce Motion no se mueve.
private struct Shake: ViewModifier {
    let trigger: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, x in
            view.offset(x: reduceMotion ? 0 : x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-8, duration: 0.06)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(-4, duration: 0.06)
                LinearKeyframe(0, duration: 0.06)
            }
        }
    }
}
