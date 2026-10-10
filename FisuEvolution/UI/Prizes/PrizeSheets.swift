import SwiftUI

/// Las dos hojas de los premios (el colchón y la ruleta suelta), aparte de
/// `RootView`: con una hoja más en su cadena el type-checker se rinde.
struct PrizeSheets: ViewModifier {
    @Environment(GameState.self) private var gameState
    /// Re-publica `uiCoversBoard` cuando una de las dos se abre o se cierra
    /// (la cuenta de lo que tapa el tablero la lleva `RootView`).
    let syncCover: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: gameState.mattressPopup) { syncCover() }
            .onChange(of: gameState.wheelSheet) { syncCover() }
            .fisuSheet(item: mattressPopupBinding) { _ in
                MattressPopupView()
            }
            .fisuSheet(item: wheelSheetBinding) { _ in
                NavigationStack {
                    WheelView(close: { gameState.closeWheel() })
                }
                .tint(Color("PaletteInk"))
                .fisuSheet()
            }
    }

    private var mattressPopupBinding: Binding<MattressPopup?> {
        Binding(
            get: { gameState.mattressPopup },
            set: { if $0 == nil { gameState.closeMattressPopup() } }
        )
    }

    private var wheelSheetBinding: Binding<WheelSheet?> {
        Binding(
            get: { gameState.wheelSheet },
            set: { if $0 == nil { gameState.closeWheel() } }
        )
    }
}
