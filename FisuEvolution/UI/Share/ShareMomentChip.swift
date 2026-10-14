import EconomyKit
import SwiftUI

/// La oferta chica de compartir un piso nuevo o una reencarnación (PLAN-v2 E3,
/// E14 C23): una tarjeta con la cara del momento —el personaje con su skin—,
/// su nombre, el bonus y «¡Compartir!», más su X. Sale arriba con los demás
/// avisos y se va sola a los 10 s. **Nunca es un popup**: no tapa el tablero ni
/// pide nada. El personaje nuevo no pasa por acá: tiene su propia card
/// bloqueante (`NewCharacterCardView`).
struct ShareMomentChip: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let moment: ShareMoment
    @State private var artwork = ShareArtwork.empty

    static let lifetime: Duration = .seconds(10)

    private var title: String {
        switch moment {
        case .newCharacter(let type), .god(let type): type.localizedName
        case .newFloor(let floorID): TowerNaming.floorName(for: floorID)
        case .reincarnation(let level): String(localized: "share.card.reincarnation.title \(String(level))")
        }
    }

    var body: some View {
        VStack(spacing: Tokens.s8) {
            HStack(spacing: Tokens.s12) {
                face
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: Tokens.s4) {
                        GameGlyphView(glyph: .coin, size: 20)
                        Text("share.bonus \(gameState.shareRewardMinutesText)")
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color("PaletteInk").opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PopupCloseButton(identifier: "share.offer.dismiss") { gameState.dismissShareOffer() }
            }
            GameButton("share.action", role: .free, medallion: .glyph(.gift), size: .compact,
                       fullWidth: true, identifier: "share.offer") {
                gameState.openShareCard()
            }
            .tutorialAnchor(.share)
        }
        .padding(Tokens.s12)
        .background {
            let shape = RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
            shape.fill(Color("PaletteCream"))
                .overlay(shape.strokeBorder(Color("PaletteInk"), lineWidth: 3))
                .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .task(id: moment.id) {
            artwork = ShareArt.artwork(for: moment, in: gameState)
            try? await Task.sleep(for: Self.lifetime)
            // Si el tutorial lo está señalando, se queda hasta que el jugador
            // decida.
            guard !Task.isCancelled, gameState.tutorialTip?.lesson != .share else { return }
            gameState.dismissShareOffer()
        }
    }

    /// La cara: el piso en miniatura con su personaje, o el personaje solo.
    private var face: some View {
        ZStack {
            Color("PaletteYellow").opacity(0.35)
            if let background = artwork.background {
                Image(uiImage: background).resizable().scaledToFill()
            }
            if let portrait = artwork.portrait {
                Image(uiImage: portrait)
                    .resizable()
                    .scaledToFit()
                    .colorMultiply(artwork.portraitTint ?? .white)
                    .padding(4)
            } else {
                MarkDisc(mark: String(title.prefix(1)).uppercased(), fill: Color("PaletteYellow"))
                    .padding(6)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
        )
        .accessibilityHidden(true)
    }
}

/// La oferta de compartir arriba, bajo el HUD y entre las dos columnas de las
/// esquinas (C20), como `NoticesLayer`: ahí es donde caen los avisos. Se
/// esconde mientras otra celebración tiene el turno —un logro, el aviso de la
/// torre—, así que nunca se apilan ni se tapan (D14). Es un `ViewModifier`
/// porque `RootView.body` está al límite del type-checker.
struct ShareOfferLayer: ViewModifier {
    @Environment(GameState.self) private var gameState

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            GeometryReader { proxy in
                let hudBottom = anchors[.hudBar].map { proxy[$0].maxY } ?? 0
                // La transición necesita que el PADRE abra la transacción.
                ZStack {
                    if let offer = gameState.shareOffer, gameState.showing == nil {
                        ShareMomentChip(moment: offer)
                    }
                }
                .animation(.spring(duration: 0.32), value: gameState.shareOffer?.id)
                .animation(.spring(duration: 0.32), value: gameState.showing == nil)
                .padding(.horizontal, NoticesLayout.sideInset)
                .padding(.top, hudBottom + Tokens.s8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}
