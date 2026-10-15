import SwiftUI

/// El globo de texto de quien está en escena, **arriba de todo** (E14b B19, D13): del HUD, las
/// esquinas, los chips y los avisos. Sólo los pop-ups modales y el tutorial van más arriba (se
/// montan después). Antes vivía en SpriteKit, y cualquier vista de SwiftUI lo tapaba: el panel de
/// arriba y la pastilla del prestigio le cortaban el texto (`capturas-e14b/20.jpg`).
///
/// Sigue la cabeza que publica la escena (`StageBubbleFeed`) y se acomoda con `StageBubbleLayout`:
/// entero en la pantalla y, cuando se puede, sin tapar el HUD. Lo que tapa el tablero entero y se
/// monta ANTES que esta capa (el cofre, la cinemática, la pausa publicitaria, la tarjeta del ranking,
/// el reveal) lo esconde: el globo es del tablero. Los pop-ups y las hojas van después, encima.
///
/// Es un `ViewModifier` porque `RootView.body` está al límite del type-checker. Mide el borde de
/// abajo del HUD con el ancla que el HUD ya publica (`.hudBar`), como `NoticesLayer`. Les pasa el
/// feed a las esquinas (`\.stageBubbleFeed`), que le anotan sus marcos: el visitante camina y el
/// globo se acomoda sin tocarlos (E14b B20). El globo sigue la cabeza mientras camina: la escena
/// la republica cada medio punto.
struct StageBubbleLayer: ViewModifier {
    let feed: StageBubbleFeed?
    /// Algo de `RootView` que esta capa no puede ver tapa el tablero (la tarjeta del ranking).
    var hidden = false
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.environment(\.stageBubbleFeed, feed).overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            GeometryReader { proxy in
                let hudBottom = anchors[.hudBar].map { proxy[$0].maxY }
                ZStack(alignment: .topLeading) {
                    if let bubble = visibleBubble {
                        let placement = StageBubbleLayout.place(bubble, screen: proxy.size,
                                                                safeTop: proxy.safeAreaInsets.top, hudBottom: hudBottom,
                                                                corners: feed?.cornerFrames ?? [])
                        StageBubbleView(bubble: bubble, placement: placement) { feed?.tap() }
                            .id(Self.identity(of: bubble))
                            .transition(popTransition(for: placement))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .animation(.easeOut(duration: StageController.bubblePopDuration), value: visibleBubble.map(Self.identity))
            }
            .ignoresSafeArea()
        }
    }

    /// El globo que se ve: el de la escena, salvo que algo tape el tablero entero.
    private var visibleBubble: StageBubble? {
        guard let bubble = feed?.bubble, !hidden, !gameState.celebrationHidesUI,
              gameState.adBreakOffer == nil, gameState.showing != .chestOpening, gameState.showing != .cinematic
        else { return nil }
        return bubble
    }

    /// Una frase nueva es un globo nuevo: hace el "pop" desde la boca otra vez.
    private static func identity(of bubble: StageBubble) -> String {
        bubble.visitId.uuidString + bubble.text
    }

    private func popTransition(for placement: StageBubbleLayout.Placement) -> AnyTransition {
        guard !reduceMotion, placement.frame.width > 0 else { return .opacity }
        let anchor = UnitPoint(x: placement.tailX / placement.frame.width, y: 1)
        return .scale(scale: 0.6, anchor: anchor).combined(with: .opacity)
    }
}

/// El globo: el mismo dibujo que el de los pop-ups (`BubbleShape`), con la cola hacia la cabeza.
private struct StageBubbleView: View {
    let bubble: StageBubble
    let placement: StageBubbleLayout.Placement
    let onTap: () -> Void

    var body: some View {
        let frame = placement.frame
        let tail = frame.width > 0 ? placement.tailX / frame.width : 0.5
        let textHeight = max(0, frame.height - StageBubbleLayout.padding * 2 - BubbleGeometry.tailHeight)
        Text(verbatim: bubble.text)
            .font(.custom(StageBubbleLayout.fontName, fixedSize: StageBubbleLayout.fontSize))
            .foregroundStyle(Color("PaletteInk"))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
            .frame(width: placement.textWidth, height: textHeight)
            .padding(StageBubbleLayout.padding)
            .padding(.bottom, BubbleGeometry.tailHeight)
            .frame(width: frame.width, height: frame.height)
            .background {
                BubbleShape(tailFraction: tail)
                    .fill(Color("PaletteCream"))
                    .overlay(BubbleShape(tailFraction: tail).stroke(Color("PaletteInk"), lineWidth: 2))
            }
            .contentShape(BubbleShape(tailFraction: tail))
            .onTapGesture(perform: onTap)
            .allowsHitTesting(bubble.tappable)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: bubble.text))
            .accessibilityAddTraits(bubble.tappable ? .isButton : [])
            .accessibilityIdentifier("stage.bubble")
            .offset(x: frame.minX, y: frame.minY)
    }
}

extension EnvironmentValues {
    /// El feed del globo del visitante, para que las esquinas le anoten sus marcos (E14b B20).
    @Entry var stageBubbleFeed: StageBubbleFeed? = nil
}
