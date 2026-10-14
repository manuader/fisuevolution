import EconomyKit
import SwiftUI

/// La card de un personaje que nunca viste (E14 C24): el personaje grande con
/// su skin, sus rayos detrás, su nombre en la cinta y, abajo, «¡Compartir!»
/// (con el bonus bien a la vista) o «Seguir». Es lo único que bloquea el juego
/// mientras está abierta: el velo del contenedor se come los toques.
///
/// Los primeros personajes salen en minutos (`newCharacterCardCanShare`): su
/// card trae sólo «¡Genial!».
struct NewCharacterCardView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let moment: ShareMoment
    @State private var artwork = ShareArtwork.empty
    @State private var showActivity = false
    @State private var arrived = false

    private var canShare: Bool { gameState.newCharacterCardCanShare(moment) }

    private var type: CharacterType? {
        switch moment {
        case .newCharacter(let type), .god(let type): type
        default: nil
        }
    }

    private var isGod: Bool {
        if case .god = moment { return true }
        return false
    }

    private var name: String { type?.localizedName ?? "" }

    var body: some View {
        PopupContainer(verbatim: name.uppercased(), ribbonTint: Color("PaletteGreen")) {
            hero
            phrase
            if canShare {
                BonusPlaque(minutes: gameState.shareRewardMinutesText)
            }
        } actions: {
            if canShare {
                GameButton("share.action", role: .free, medallion: .glyph(.gift), identifier: "share.offer") {
                    showActivity = true
                }
                GameButton("share.continue", role: .neutral, identifier: "share.card.continue") {
                    gameState.finishNewCharacterCard(shared: false)
                }
            } else {
                GameButton("share.great", role: .free, identifier: "share.card.continue") {
                    gameState.finishNewCharacterCard(shared: false)
                }
            }
        }
        .task {
            artwork = ShareArt.artwork(for: moment, in: gameState)
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.35)) {
                arrived = true
            }
        }
        .shareActivity(isPresented: $showActivity, moment: moment, artwork: artwork) { completed in
            showActivity = false
            // Cancelada, la card sigue ahí: puede probar de nuevo o seguir.
            if completed { gameState.finishNewCharacterCard(shared: true) }
        }
    }

    /// El personaje con los rayos detrás; entra con un resorte (estático: es la
    /// imagen del PNG, sin video, C22).
    private var hero: some View {
        ZStack {
            RewardRays()
            portrait
                .frame(width: Self.portraitSide, height: Self.portraitSide)
                .scaleEffect(arrived ? 1 : 0.5)
                .opacity(arrived ? 1 : 0)
        }
        .frame(width: Self.portraitSide * 1.5, height: Self.portraitSide * 1.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: name))
    }

    static let portraitSide: CGFloat = 150

    @ViewBuilder
    private var portrait: some View {
        if let image = artwork.portrait {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .colorMultiply(artwork.portraitTint ?? .white)
                .shadow(color: .black.opacity(0.22), radius: 6, y: 4)
        } else {
            MarkDisc(mark: String(name.prefix(1)).uppercased(), fill: Color("PaletteYellow"))
        }
    }

    private var phrase: some View {
        Group {
            if isGod {
                Text("share.newcharacter.god")
            } else {
                Text("share.newcharacter.phrase \(name)")
            }
        }
        .font(Tokens.body)
        .foregroundStyle(Color("PaletteInk").opacity(0.8))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("share.card.phrase")
    }
}

/// El bonus de compartir, a la vista: la moneda y «+N min».
private struct BonusPlaque: View {
    let minutes: String

    var body: some View {
        HStack(spacing: Tokens.s8) {
            GameGlyphView(glyph: .coin, size: 28)
            Text("share.bonus \(minutes)")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(Color("PaletteInk"))
        }
        .padding(.horizontal, Tokens.s16)
        .padding(.vertical, Tokens.s8)
        .background(
            RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                .fill(Color("PaletteYellow").opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                .strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("share.card.bonus")
    }
}

/// La card de personaje nuevo como `ViewModifier`: `RootView.body` y la cadena
/// de `GamePopups` están al límite del type-checker. Toma el turno de la cola
/// (`showing == .newCharacter`), nunca antes.
struct NewCharacterCardPopup: ViewModifier {
    @Environment(GameState.self) private var gameState

    func body(content: Content) -> some View {
        content.gamePopup(item: binding) { moment in
            NewCharacterCardView(moment: moment)
        }
    }

    private var binding: Binding<ShareMoment?> {
        Binding(
            get: { gameState.showing == .newCharacter ? gameState.newCharacterCard : nil },
            set: { if $0 == nil { gameState.finishNewCharacterCard(shared: false) } }
        )
    }
}
