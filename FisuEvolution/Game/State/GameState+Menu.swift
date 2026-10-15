import Foundation

/// La sesión del menú deslizable (PLAN-v2 E3): una hoja con las pestañas como
/// páginas. Abrir o deslizar a una pestaña cuenta como abrirla; la pausa natural
/// es cerrar la sesión entera, y sólo ahí se pide el intersticial.
extension GameState {
    func menuDidOpen(at screen: GameScreen) {
        // La hoja se presenta justo después de esta llamada y `RootView` recién lo publica en el
        // frame siguiente: sin esto, un refresh en el medio daría el paso de la hoja por
        // abandonado (`openPage` se limpia y el núcleo rebobina) antes de que la hoja exista.
        uiCoversBoard = true
        tutorialTipHandled(opening: screen)
    }

    /// Deslizar hasta una pestaña nueva también le saca el "¡Nuevo!" (la barra
    /// ya lo hace al tocarla).
    func menuPageChanged(to screen: GameScreen) {
        tutorialTipHandled(opening: screen)
        tutorialSignal(.pagerMoved)
        markTabOpened(screen)
    }

    func menuDidClose() async {
        tutorialEngine.openPage = nil
        // El paso 2 de un logro que quedó abierto: cerrar el Menú es «No, gracias» (E14b B29).
        declineRewardDouble(host: .menu)
        await naturalBreak(.sheetClosed)
    }
}
