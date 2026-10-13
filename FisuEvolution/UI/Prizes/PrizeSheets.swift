import SwiftUI

/// La hoja de la ruleta suelta, aparte de `RootView`: con una hoja más en su
/// cadena el type-checker se rinde. El colchón ya es un popup (`GamePopups`).
struct PrizeSheets: ViewModifier {
    @Environment(GameState.self) private var gameState
    /// Re-publica `uiCoversBoard` cuando una de las dos se abre o se cierra
    /// (la cuenta de lo que tapa el tablero la lleva `RootView`).
    let syncCover: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: gameState.mattressPopup) { syncCover() }
            .onChange(of: gameState.wheelSheet) { syncCover() }
            .fisuSheet(item: wheelSheetBinding) { _ in
                NavigationStack {
                    WheelView(close: { gameState.closeWheel() })
                }
                .tint(Color("PaletteInk"))
                .fisuSheet()
            }
    }

    private var wheelSheetBinding: Binding<WheelSheet?> {
        Binding(
            get: { gameState.wheelSheet },
            set: { if $0 == nil { gameState.closeWheel() } }
        )
    }
}
