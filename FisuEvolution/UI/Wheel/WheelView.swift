import EconomyKit
import SwiftUI

/// La Ruleta (PLAN-v2 E5, E14 C4/C26) en tres momentos. Antes: el marco con las
/// luces del video y los gajos con la imagen de su premio, el botón y la tabla
/// de probabilidades a la vista (Apple 3.1.1). Durante: se tira con un botón o
/// con un deslizón (el giro regalado) y frena con `wheel.json` `spinSeconds` y
/// un tic por rebanada. Después: las luces festejan (`ruleta_premio`) y el
/// premio ganado sale grande, con rayos y un pop. El premio lo decide el código
/// y ya se acreditó cuando la rueda arranca (`beginWheelSpin`); el video sólo
/// pone el marco.
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
    @State private var tickGate = WheelTickGate()
    /// Un giro se está resolviendo (con Reduce Motion no hay animación que lo
    /// trabe): corta el cobro de un segundo toque sin apagar los botones.
    @State private var latch = PurchaseLatch()
    @State private var videoBusy = false
    /// El clip de festejo corre (el giro terminó y falta que las luces acaben).
    @State private var celebrating = false
    /// Cómo se pagó el giro que está a la vista: sólo el gratis ofrece su ×2 al cobrar (E14b B29).
    @State private var resultSource: WheelSpinSource?

    private var resolving: Bool { latch.isLocked }

    /// Quien presenta la ruleta (PLAN-v2 §2).
    private static let hostVisitorId = "npc_conductor"
    private static let turns = 5

    var body: some View {
        let _ = gameState.effectsVersion
        let availability = gameState.wheelAvailability(storefrontAllows: storefrontAllows)
        let segments = spin?.outcome.segments ?? (result == nil ? gameState.wheelSegments : result?.segments ?? [])
        ScrollViewReader { proxy in
            content(segments: segments, availability: availability)
                // El premio sale debajo de la rueda: en una pantalla chica se baja a verlo.
                .onChange(of: result?.segment.id) { _, id in
                    guard id != nil, spin == nil else { return }
                    withAnimation { proxy.scrollTo(Self.resultAnchor, anchor: .center) }
                }
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
        // «Repetir premio» es el paso 2 de los giros gratis, adentro de la hoja.
        .modifier(RewardDoubleLayer(host: .wheel))
    }

    private static let resultAnchor = "wheel.result.card"

    private func content(segments: [WheelConfig.Segment], availability: WheelAvailability) -> some View {
        ScrollView {
            VStack(spacing: Tokens.s16) {
                host
                wheel(segments: segments, availability: availability)
                if let result, spin == nil {
                    resultCard(result).id(Self.resultAnchor)
                } else if availability.bonus > 0, spin == nil {
                    Text("wheel.hint")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .multilineTextAlignment(.center)
                }
                buttons(availability)
                PrizePileHero()
                OddsDisclosureView(titleKey: "wheel.odds.title", rows: oddsRows, identifier: "wheel.odds")
            }
            .padding(.horizontal, WoodPanelBackground.columnInset)
            .padding(.top, Tokens.s12)
            .padding(.bottom, Tokens.s24)
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

    private func wheel(segments: [WheelConfig.Segment], availability: WheelAvailability) -> some View {
        let clip = celebrating ? "ruleta_premio" : "ruleta_espera"
        let playback: ArtPlayback = celebrating ? .once { celebrating = false } : .loop
        return ZStack {
            Circle().fill(Color("PaletteCream"))
                .overlay(Circle().strokeBorder(Color("PaletteBrown"), lineWidth: 4))
                .frame(width: WheelStage.discDiameter + 8, height: WheelStage.discDiameter + 8)
                .offset(WheelStage.discOffset)
            AnimatedArtView(clip: .object(clip), role: .popup, playback: playback) {
                Color.clear.frame(width: WheelStage.clipSide, height: WheelStage.clipSide)
            }
            TimelineView(.animation(minimumInterval: nil, paused: spin == nil)) { context in
                WheelCanvas(segments: segments, rotation: spin?.rotation(at: context.date) ?? resting)
                    .frame(width: WheelStage.discDiameter, height: WheelStage.discDiameter)
                    .onChange(of: context.date) { _, date in advance(to: date) }
            }
            .offset(WheelStage.discOffset)
        }
        .frame(width: WheelStage.size.width, height: WheelStage.size.height)
        .clipped()
        .modifier(WheelStageFit())
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { drag in
                guard WheelStage.isSwipe(drag.translation), availability.bonus > 0 else { return }
                start(.bonus)
            }
        )
        .accessibilityElement()
        .accessibilityIdentifier("wheel.wheel")
        .accessibilityValue(Text(verbatim: spin == nil ? "idle" : "spinning"))
    }

    @ViewBuilder
    private func buttons(_ availability: WheelAvailability) -> some View {
        VStack(spacing: Tokens.s8) {
            if spin != nil || resolving {
                StateBadge(text: String(localized: "wheel.spinning"),
                           textAlignment: .center, muted: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("wheel.spinning")
            } else {
                if availability.bonus > 0 {
                    GameButton("wheel.spin.bonus", role: .free, medallion: .none, identifier: "wheel.spin.bonus") {
                        start(.bonus)
                    }
                } else if availability.videoLeft > 0 {
                    RewardedOfferButton(
                        title: RewardCopy.text("wheel.spin.video", String(availability.videoLeft)),
                        identifier: "wheel.spin.video",
                        placement: .wheel,
                        isBusy: $videoBusy,
                        gameRole: .video
                    ) { start(.video) }
                } else {
                    StateBadge(text: String(localized: "wheel.empty"),
                               textAlignment: .center, muted: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("wheel.empty")
                }
                // El cupo es uno solo (E14b D11): el blue dice lo mismo que el video
                // y, sin cupo, se va con él y queda el cartel de «no quedan giros».
                if availability.blueLeft > 0 {
                    GameButton(verbatim: RewardCopy.text("wheel.spin.blue", String(availability.blueCost),
                                                         String(availability.blueLeft)),
                               role: .blue, available: availability.canPayBlue,
                               identifier: "wheel.spin.blue", accessibilityLabel: Text("wheel.spin.blue.ax")) {
                        if availability.canPayBlue { start(.blue) }
                    }
                }
            }
        }
    }

    private func resultCard(_ outcome: WheelSpinOutcome) -> some View {
        let reward = outcome.segment.reward
        let text = outcome.coins > 0 ? "+\(CoinFormatter.string(from: outcome.coins))" : RewardCopy.title(reward)
        return GameCard {
            VStack(spacing: Tokens.s8) {
                Text("wheel.result.title")
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.7))
                PrizeReveal(kind: WheelSliceLayout.kind(of: reward), text: text)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("wheel.result")
                    .accessibilityValue(Text(verbatim: outcome.segment.id))
                GameButton("wheel.collect", role: .free, identifier: "wheel.collect") { collect(outcome) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var oddsRows: [OddsDisclosureView.Row] {
        zip(gameState.wheelSegments, gameState.wheelOdds).map { segment, odds in
            OddsDisclosureView.Row(
                id: segment.id, title: RewardCopy.title(segment.reward),
                symbol: RewardCopy.symbol(segment.reward), probability: odds.probability,
                kind: WheelSliceLayout.kind(of: segment.reward)
            )
        }
    }

    // MARK: El giro

    private func start(_ source: WheelSpinSource) {
        guard WheelSpinGate.allows(source, spinning: spin != nil, videoBusy: videoBusy),
              let outcome = gameState.beginWheelSpin(source, latch: &latch, storefrontAllows: storefrontAllows)
        else { return }
        result = nil
        resultSource = source
        let arcs = WheelGeometry.arcs(count: outcome.segments.count)
        let target = WheelGeometry.stopRotation(from: resting, arc: arcs[outcome.index], turns: Self.turns,
                                                landing: .random(in: 0...1))
        guard !reduceMotion else {
            resting = target.truncatingRemainder(dividingBy: 360)
            result = outcome
            celebrating = true
            releaseSoon()
            return
        }
        lastTick = resting
        spin = WheelSpinAnimation(outcome: outcome, from: resting, to: target, start: .now,
                                  duration: gameState.content?.wheel.spinSeconds ?? 0)
    }

    private func advance(to date: Date) {
        guard let spin else { return }
        let rotation = spin.rotation(at: date)
        if WheelGeometry.boundariesCrossed(from: lastTick, to: rotation, count: spin.outcome.segments.count) > 0,
           tickGate.allows(at: date.timeIntervalSinceReferenceDate) {
            gameState.playWheelTick()
        }
        lastTick = rotation
        guard spin.isFinished(at: date) else { return }
        resting = spin.to.truncatingRemainder(dividingBy: 360)
        result = spin.outcome
        celebrating = true
        self.spin = nil
        latch.release()
    }

    /// Sin animación que lo trabe (Reduce Motion), el candado se suelta tras un
    /// instante: el doble toque no gasta dos giros.
    private func releaseSoon() {
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            latch.release()
        }
    }

    /// Cobrar (paso 1) y, si el giro fue gratis, su ×2 con video (paso 2).
    private func collect(_ outcome: WheelSpinOutcome) {
        result = nil
        if let source = resultSource { gameState.offerWheelDouble(outcome, source: source) }
        resultSource = nil
    }
}

/// Quién puede tirar la rueda: nadie mientras gira, y mientras corre el video
/// del giro por video sólo el giro que ese video paga.
/// Un giro por video llega cuando el video ya se miró, pero `videoBusy` se
/// apaga recién en el próximo ciclo: no puede trabar el premio.
enum WheelSpinGate {
    static func allows(_ source: WheelSpinSource, spinning: Bool, videoBusy: Bool) -> Bool {
        !spinning && (source == .video || !videoBusy)
    }
}

/// El escenario de la Ruleta: el clip (512 px de lado) y el disco liso que
/// trae, medidos en el cuadro del video, pasados a puntos. Los gajos de
/// `WheelCanvas` se dibujan encima del disco, así que esto tiene que coincidir
/// con `ruleta_espera` / `ruleta_premio`.
enum WheelStage {
    /// Puntos por píxel del clip.
    static let scale: CGFloat = 0.78
    static let clipSide: CGFloat = 512 * scale
    /// El centro del disco liso en el cuadro del clip, y su radio (px).
    static let discCenter = CGPoint(x: 255, y: 262)
    static let discRadius: CGFloat = 128
    /// Lo que se ve del clip: el marco con el puntero y las luces, y el
    /// festejo; los bordes vacíos del cuadro no ocupan lugar.
    static let size = CGSize(width: 335, height: 322)

    static var discDiameter: CGFloat { discRadius * 2 * scale }
    /// Cuánto se corre el disco del centro del cuadro.
    static var discOffset: CGSize {
        CGSize(width: (discCenter.x - 256) * scale, height: (discCenter.y - 256) * scale)
    }

    /// El factor que entra el escenario en `available` puntos de ancho (nunca lo
    /// agranda): en el SE la columna de la hoja es más angosta que el marco y el
    /// escenario se cortaba por los costados.
    static func fitScale(availableWidth: CGFloat) -> CGFloat {
        guard availableWidth > 0 else { return 1 }
        return min(1, availableWidth / size.width)
    }

    /// Un deslizón lateral tira la ruleta; uno vertical es el scroll de la hoja.
    static func isSwipe(_ translation: CGSize) -> Bool {
        abs(translation.width) >= 60 && abs(translation.width) > abs(translation.height) * 1.5
    }
}

/// Achica el escenario de la Ruleta para que entre en el ancho que le da la
/// hoja, sin recortarlo: el marco ocupado se achica con él (el `.scaleEffect`
/// solo no cambia el layout y dejaría el hueco del tamaño original).
private struct WheelStageFit: ViewModifier {
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .frame(width: WheelStage.size.width * scale, height: WheelStage.size.height * scale)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                scale = WheelStage.fitScale(availableWidth: width)
            }
    }
}
