import EconomyKit
import SwiftUI

/// El popup de un visitante (PLAN-v2 E4): su retrato, su pedido en el globo de
/// la 2.0 y una opción por botón, en el `PopupContainer` de la casa (E14 C15).
/// Lo que da es verde; lo que cobra, naranja —o un botón crema si no alcanza o
/// hay corralito: nunca `.disabled`—; lo que pide video, `RewardedOfferButton`
/// en rojo, que entrega SÓLO si el video se premió. Los montos son los que se
/// cotizaron al llegar, los mismos del globo.
///
/// Al Vendedor, «No, gracias» lo ofende (C15): el popup pasa a su cara de
/// enojado con una frase y un «Chau», y recién ahí se va. La caminata de salida
/// es del escenario, no de este popup.
struct VisitorPopupView: View {
    @Environment(GameState.self) private var gameState
    private static let portraitSide: CGFloat = 112

    /// El vendedor ya oyó el «no»: muestra su enojo antes de irse.
    @State private var offended = false
    /// Cuál de las frases ofendidas dice; se sortea una vez al ofenderse.
    @State private var offendedLine = 1
    static let offendedLines = 3

    var body: some View {
        if let visit = gameState.stageVisit, let offer = visit.offer, let content = gameState.content,
           let script = content.visitors.script(id: offer.scriptId),
           let visitor = content.visitors.visitor(id: offer.visitorId) {
            let isVendor = Self.isVendor(script)
            PopupContainer(
                verbatim: VisitCopy.name(of: visitor), ribbonTint: Color("PaletteOrange"),
                onClose: { offended ? gameState.declineVisit() : gameState.closeVisitorPopup() }
            ) {
                if offended {
                    offendedContent(visitor: visitor)
                } else {
                    // El loop si existe y el pool lo deja; si no, la cara de siempre.
                    AnimatedArtView(clip: .portrait(visitor.id), role: .popup) {
                        VisitorFace(visitorId: visitor.id, side: Self.portraitSide)
                    }
                    .frame(width: Self.portraitSide, height: Self.portraitSide)
                    Text(verbatim: VisitCopy.ask(for: script, offer: offer, content: content))
                        .font(Tokens.prose)
                        .foregroundStyle(Color("PaletteInk"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Tokens.s12)
                        .padding(.top, BubbleGeometry.tailHeight)
                        .background(bubble)
                    if isVendor {
                        VendorCardsView(script: script, offer: offer)
                    }
                }
            } actions: {
                if offended {
                    GameButton("visit.offended.bye", role: .neutral, medallion: .none,
                               identifier: "visit.offended.bye") { gameState.declineVisit() }
                } else {
                    if !isVendor {
                        ForEach(offer.options) { option in
                            optionButton(option, script: script, content: content)
                        }
                    }
                    // E14 C5: a cualquiera se le puede decir que no.
                    GameButton("visit.option.decline", role: .neutral, medallion: .none,
                               identifier: "visit.option.decline") {
                        if isVendor {
                            offendedLine = Int.random(in: 1...Self.offendedLines)
                            offended = true
                        } else {
                            gameState.declineVisit()
                        }
                    }
                }
            }
            // Sin identifier en el contenedor: pisaría el de los botones (trampa 9a-bis).
            .inlineLesson(.visitorPopup)
        }
    }

    static func isVendor(_ script: VisitorsConfig.Script) -> Bool {
        if case .vendor = script.mechanic { return true }
        return false
    }

    /// El vendedor enojado: su arte de ofendido (o la cara de siempre si el
    /// pack no la trae) y su frase, sin penalidad de juego.
    @ViewBuilder
    private func offendedContent(visitor: VisitorsConfig.Visitor) -> some View {
        Group {
            if let manifest = gameState.content?.manifest, let key = manifest.npcs?[visitor.id + "_enojado"],
               let image = UIArt.characterImage(atlas: "npcs", key: key) {
                image.resizable().scaledToFit()
                    .frame(width: 140, height: 140)
            } else {
                VisitorFace(visitorId: visitor.id, side: Self.portraitSide)
            }
        }
        .accessibilityIdentifier("visit.offended.portrait")
        Text(verbatim: VisitCopy.text("visit.vendor.offended.\(offendedLine)"))
            .font(Tokens.prose)
            .foregroundStyle(Color("PaletteInk"))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Tokens.s12)
            .padding(.top, BubbleGeometry.tailHeight)
            .background(bubble)
    }

    /// La cola del globo apunta ARRIBA, al retrato: por eso la forma va rotada 180°.
    private var bubble: some View {
        BubbleShape(tailFraction: 0.5)
            .rotation(.degrees(180))
            .fill(Color("PaletteCream"))
            .overlay(BubbleShape(tailFraction: 0.5).rotation(.degrees(180))
                .stroke(Color("PaletteInk"), lineWidth: 2))
    }

    @ViewBuilder
    private func optionButton(_ option: VisitOption, script: VisitorsConfig.Script, content: GameContent) -> some View {
        let title = VisitCopy.optionTitle(option, script: script, content: content)
        let identifier = "visit.option.\(option.id)"
        if option.requiresVideo {
            RewardedOfferButton(title: title, identifier: identifier, placement: .visitor, gameRole: .video) {
                gameState.chooseVisitOption(option.id)
            }
        } else if option.cost > 0, !gameState.canAfford(option) {
            GameButton(verbatim: title, role: .coins, medallion: .glyph(.lock), available: false,
                       identifier: identifier) {}
        } else {
            GameButton(verbatim: title, role: option.cost > 0 ? .coins : .free, identifier: identifier) {
                gameState.chooseVisitOption(option.id)
            }
        }
    }
}
