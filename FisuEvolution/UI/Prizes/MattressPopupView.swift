import EconomyKit
import SwiftUI

/// En qué momento está el colchón. El premio se acredita al llegar el resultado
/// (`opening`); el clip de apertura sólo demora mostrarlo.
enum MattressStage: Equatable {
    case waiting, opening, revealed

    init(hasOutcome: Bool, revealed: Bool) {
        self = switch (hasOutcome, revealed) {
        case (false, _): .waiting
        case (true, false): .opening
        case (true, true): .revealed
        }
    }
}

/// Los toques que abren el colchón (E14 C4 «durante»): cada uno lo sacude y el
/// tercero lo descose. Con Reduce Motion alcanza un toque. Puro, para pinearlo.
struct MattressOpening: Equatable {
    static let tapsToOpen = 3

    private(set) var taps = 0
    /// El clip de la sacudida corre (el toque acaba de pasar).
    private(set) var shaking = false

    var isOpen: Bool { taps >= Self.tapsToOpen }

    mutating func tap(reduceMotion: Bool) {
        guard !isOpen else { return }
        taps = reduceMotion ? Self.tapsToOpen : taps + 1
        shaking = !isOpen
    }

    mutating func shakeEnded() { shaking = false }

    /// El clip que corresponde ahora: respira, salta con el toque o se abre.
    var clipID: String {
        if isOpen { return "colchon_abre" }
        return shaking ? "colchon_sacude" : "colchon_espera"
    }
}

/// El Colchón (PLAN-v2 E5, E14 C4/C27, E14b B6). Desde la columna: lo que puede haber
/// adentro, en imágenes, y el botón del video; al terminar el video el popup se cierra y el
/// colchón cae al tablero. Abierto en el tablero: lo que salió, grande y con rayos, y «otro
/// colchón» con un segundo video, que se abre acá tocándolo tres veces (sacude, sacude, se descose).
/// Vive en el `PopupContainer` de la casa (E14 C15).
struct MattressPopupView: View {
    @Environment(GameState.self) private var gameState
    /// Cierra el popup (lo pone quien lo presenta).
    let onClose: () -> Void
    /// Un video del colchón está en curso: el popup no se cierra bajo el anuncio.
    @State private var watching = false
    /// El clip de apertura terminó (o la política lo dejó quieto): ya se ve lo que salió.
    @State private var revealed = false
    @State private var opening = MattressOpening()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func close() {
        if !watching { onClose() }
    }

    var body: some View {
        let outcome = gameState.mattressPopup?.outcome
        // Abierto en el tablero, la animación ya se vio allá: el premio sale directo (E14b B6).
        let stage = MattressStage(hasOutcome: outcome != nil,
                                  revealed: revealed || gameState.mattressPopup?.openedOnBoard == true)
        PopupContainer("mattress.title", ribbonTint: Color("PaletteOrange"), onClose: close) {
            if stage == .opening {
                tapTheMattress
            } else if let outcome {
                result(outcome)
            } else {
                before
            }
        } actions: {
            if stage != .opening {
                if let outcome {
                    // Apilados: «Otro colchón con un video» no entra en media fila (visto en el SE).
                    VStack(spacing: Tokens.s8) {
                        if outcome.extraOpensLeft > 0 {
                            extraButton
                        }
                        GameButton("mattress.collect", role: .free, identifier: "mattress.collect", action: close)
                    }
                } else if gameState.mattressPopup?.extraOnly == true {
                    extraButton
                } else {
                    RewardedOfferButton(title: String(localized: "mattress.open"), identifier: "mattress.open",
                                        placement: .treasure, isBusy: $watching, gameRole: .video) {
                        gameState.mattressVideoWatched()
                    }
                }
            }
        }
    }

    /// Antes: todo lo que puede haber adentro, y la tabla con sus chances.
    @ViewBuilder private var before: some View {
        PopupHero(artKey: "rw_mattress_hero", fallback: .mattressTreasure)
        if gameState.mattressPopup?.extraOnly != true {
            Text("mattress.pitch")
                .font(Tokens.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("PaletteInk"))
        }
        PrizePileHero()
        OddsDisclosureView(titleKey: "mattress.odds.title", rows: oddsRows, identifier: "mattress.odds")
    }

    /// Durante: el colchón es el botón.
    private var tapTheMattress: some View {
        VStack(spacing: Tokens.s8) {
            Text("mattress.tap")
                .font(Tokens.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("PaletteInk"))
            Button(action: tapMattress) {
                AnimatedArtView(clip: .object(opening.clipID), role: .popup, playback: playback) {
                    GameIcon(artKey: "pickup_mattress", size: Self.mattressSide) { MattressGlyph() }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mattress.tap")
            .accessibilityLabel(Text("mattress.tap"))
            .accessibilityValue(Text(verbatim: String(opening.taps)))
        }
        .task(id: opening.taps) {
            // Quien no toca no se queda trabado: el premio ya es suyo.
            try? await Task.sleep(for: .seconds(Self.idleSeconds))
            if !Task.isCancelled { tapMattress() }
        }
    }

    private static let mattressSide: CGFloat = 180
    private static let idleSeconds = 2.0

    private var playback: ArtPlayback {
        if opening.isOpen { return .once { revealed = true } }
        return opening.shaking ? .once { opening.shakeEnded() } : .loop
    }

    private func tapMattress() {
        guard !opening.isOpen else { return }
        opening.tap(reduceMotion: reduceMotion)
        gameState.playHaptic(opening.isOpen ? .rarity : .merge)
    }

    private var extraButton: some View {
        RewardedOfferButton(title: String(localized: "mattress.extra"), identifier: "mattress.extra",
                            placement: .treasure, isBusy: $watching, gameRole: .video) {
            revealed = false
            opening = MattressOpening()
            gameState.extraMattressVideoWatched()
        }
    }

    private func result(_ outcome: MattressOutcome) -> some View {
        let text = outcome.coins > 0
            ? "+\(CoinFormatter.string(from: outcome.coins))"
            : outcome.rewards.map(RewardCopy.title).joined(separator: " + ")
        let kind = outcome.coins > 0 ? RewardKind.coins : outcome.rewards.first.flatMap { RewardKind($0) } ?? .mattressTreasure
        return PrizeReveal(kind: kind, text: text)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("mattress.result")
            .accessibilityValue(Text(verbatim: outcome.prizeId))
    }

    private var oddsRows: [OddsDisclosureView.Row] {
        guard let treasures = gameState.content?.treasures else { return [] }
        return zip(treasures.prizes, treasures.odds).map { prize, odds in
            OddsDisclosureView.Row(
                id: prize.id,
                title: prize.rewards.map(RewardCopy.title).joined(separator: " + "),
                symbol: prize.rewards.first.map(RewardCopy.symbol) ?? "gift.fill",
                probability: odds.probability,
                kind: prize.rewards.first.flatMap { RewardKind($0) } ?? .mattressTreasure
            )
        }
    }
}
