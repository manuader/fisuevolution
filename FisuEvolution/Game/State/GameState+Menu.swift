import Foundation

/// La sesión del menú deslizable (PLAN-v2 E3): una hoja con las pestañas como
/// páginas. Abrir o deslizar a una pestaña cuenta como abrirla; la pausa natural
/// es cerrar la sesión entera, y sólo ahí se pide el intersticial.
extension GameState {
    func menuDidOpen(at screen: GameScreen) {
        tutorialTipHandled(opening: screen)
    }

    func menuPageChanged(to screen: GameScreen) {
        tutorialTipHandled(opening: screen)
    }

    func menuDidClose() async {
        await showInterstitialIfAppropriate()
    }
}
