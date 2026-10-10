import EconomyKit
import SwiftUI

/// La Ruleta (PLAN-v2 E5): la presenta el Conductor de TV, gira con un frenado
/// de `wheel.json` `spinSeconds` y un tic por rebanada, y la tabla de
/// probabilidades está a la vista, debajo (Apple 3.1.1). El premio ya se
/// acreditó cuando la rueda arranca (`spinWheel`).
///
/// Se empuja desde Regalos o se presenta sola (`GameState.wheelSheet`): quien
/// la muestra decide qué hace `close`.
struct WheelView: View {
    let close: () -> Void

    @Environment(GameState.self) private var gameState
    @Environment(AdsCoordinator.self) private var ads
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var storefrontAllows = false
    @State private var resting: Double = 0
    @State private var spin: WheelSpinAnimation?
    @State private var lastTick: Double = 0
    @State private var result: WheelSpinOutcome?

    /// Quien presenta la ruleta (PLAN-v2 §2).
    private static let hostVisitorId = "npc_conductor"
    private static let wheelSide: CGFloat = 300
    private static let turns = 5

    var body: some View {
        let _ = gameState.effectsVersion
        let availability = gameState.wheelAvailability(storefrontAllows: storefrontAllows)
        let segments = spin?.outcome.segments ?? result?.segments ?? gameState.wheelSegments
        ScrollView {
            VStack(spacing: Tokens.s16) {
                host
                wheel(segments: segments)
                if let result, spin == nil {
                    resultCard(result)
                }
                buttons(availability)
                OddsDisclosureView(titleKey: "wheel.odds.title", rows: oddsRows, identifier: "wheel.odds")
            }
            .padding(.horizontal, WoodPanelBackground.columnInset)
            .padding(.top, Tokens.s12)
            .padding(.bottom, Tokens.s24)
        }
        .panelSheet { PanelTitleBanner(titleKey: "wheel.title") }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ArtCloseButton(action: close) }
        }
        .task {
            ads.preloadRewarded(for: .wheel)
            storefrontAllows = await LootBoxGate.current()
        }
    }

    private var host: some View {
        HStack(spacing: Tokens.s12) {
            VisitorFace(visitorId: Self.hostVisitorId, side: 56)
            Text("wheel.host.line")
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk"))
                .padding(Tokens.s8)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Color("PaletteCream"))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                )
            Spacer(minLength: 0)
        }
    }

    private func wheel(segments: [WheelConfig.Segment]) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: spin == nil)) { context in
            WheelCanvas(segments: segments, rotation: spin?.rotation(at: context.date) ?? resting)
                .frame(width: Self.wheelSide, height: Self.wheelSide)
                .overlay(alignment: .top) {
                    WheelPointer()
                        .frame(width: 28, height: 34)
                        .offset(y: -10)
                }
                .onChange(of: context.date) { _, date in advance(to: date) }
        }
        .frame(height: Self.wheelSide + 12)
        .accessibilityElement()
        .accessibilityIdentifier("wheel.wheel")
        .accessibilityValue(Text(verbatim: spin == nil ? "idle" : "spinning"))
    }

    @ViewBuilder
    private func buttons(_ availability: WheelAvailability) -> some View {
        VStack(spacing: Tokens.s8) {
            if spin != nil {
                StateBadge(text: String(localized: "wheel.spinning"), systemImage: "hourglass",
                           textAlignment: .center, muted: true)
            } else {
                if availability.bonus > 0 {
                    ActionPill(titleKey: "wheel.spin.bonus", systemImage: "gift.fill",
                               tint: Color("PaletteGreen"), identifier: "wheel.spin.bonus") { start(.bonus) }
                } else if availability.videoLeft > 0 {
                    RewardedOfferButton(
                        title: RewardCopy.text("wheel.spin.video", String(availability.videoLeft)),
                        identifier: "wheel.spin.video",
                        placement: .wheel
                    ) { start(.video) }
                } else {
                    StateBadge(text: String(localized: "wheel.empty"), systemImage: "moon.zzz.fill",
                               textAlignment: .center, muted: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("wheel.empty")
                }
                if availability.oroLeft > 0 {
                    PricePill(text: String(availability.oroCost), currency: .oro, affordable: availability.canPayOro,
                              identifier: "wheel.spin.oro", accessibilityPurpose: Text("wheel.spin.oro.ax")) {
                        if availability.canPayOro { start(.oro) }
                    }
                }
                if availability.canRepeat, result != nil {
                    RewardedOfferButton(title: String(localized: "wheel.repeat"), identifier: "wheel.repeat",
                                        placement: .wheel) { repeatPrize() }
                }
            }
        }
    }

    private func resultCard(_ outcome: WheelSpinOutcome) -> some View {
        let reward = outcome.segment.reward
        let text = outcome.coins > 0 ? "+\(CoinFormatter.string(from: outcome.coins))" : RewardCopy.title(reward)
        return GameCard(style: .highlighted(Color("PaletteYellow"))) {
            HStack(spacing: Tokens.s8) {
                Image(systemName: RewardCopy.symbol(reward))
                    .font(.system(size: 26, weight: .heavy))
                VStack(alignment: .leading, spacing: 2) {
                    Text("wheel.result.title")
                        .font(Tokens.caption)
                    Text(verbatim: text)
                        .font(Tokens.title)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color("PaletteInk"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wheel.result")
        .accessibilityValue(Text(verbatim: outcome.segment.id))
    }

    private var oddsRows: [OddsDisclosureView.Row] {
        zip(gameState.wheelSegments, gameState.wheelOdds).map { segment, odds in
            OddsDisclosureView.Row(
                id: segment.id, title: RewardCopy.title(segment.reward),
                symbol: RewardCopy.symbol(segment.reward), probability: odds.probability
            )
        }
    }

    // MARK: El giro

    private func start(_ source: WheelSpinSource) {
        guard spin == nil, let outcome = gameState.spinWheel(source, storefrontAllows: storefrontAllows) else { return }
        result = nil
        let arcs = WheelGeometry.arcs(count: outcome.segments.count)
        let target = WheelGeometry.stopRotation(from: resting, arc: arcs[outcome.index], turns: Self.turns,
                                                landing: .random(in: 0...1))
        guard !reduceMotion else {
            resting = target.truncatingRemainder(dividingBy: 360)
            result = outcome
            return
        }
        lastTick = resting
        spin = WheelSpinAnimation(outcome: outcome, from: resting, to: target, start: .now,
                                  duration: gameState.content?.wheel.spinSeconds ?? 0)
    }

    private func advance(to date: Date) {
        guard let spin else { return }
        let rotation = spin.rotation(at: date)
        if WheelGeometry.boundariesCrossed(from: lastTick, to: rotation, count: spin.outcome.segments.count) > 0 {
            gameState.playWheelTick()
        }
        lastTick = rotation
        guard spin.isFinished(at: date) else { return }
        resting = spin.to.truncatingRemainder(dividingBy: 360)
        result = spin.outcome
        self.spin = nil
    }

    private func repeatPrize() {
        guard spin == nil, let outcome = gameState.repeatWheelPrize() else { return }
        result = outcome
    }
}
