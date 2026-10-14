import SwiftUI

/// La hoja de la ruleta suelta y la pantalla del Paquete de la Aduana, aparte
/// de `RootView`: con una hoja más en su cadena el type-checker se rinde. El
/// colchón ya es un popup (`GamePopups`).
struct PrizeSheets: ViewModifier {
    @Environment(GameState.self) private var gameState
    /// Re-publica `uiCoversBoard` cuando una de las dos se abre o se cierra
    /// (la cuenta de lo que tapa el tablero la lleva `RootView`).
    let syncCover: () -> Void

    func body(content: Content) -> some View {
        content
            .background(boardPackageMarker)
            .background(boardMattressMarker)
            .onChange(of: gameState.mattressPopup) { syncCover() }
            .onChange(of: gameState.wheelSheet) { syncCover() }
            .onChange(of: gameState.packagePopup) { syncCover() }
            .gamePopup(item: packagePopupBinding) { _ in
                PackagePopupView(onClose: { gameState.closePackagePopup() })
            }
            .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
                GeometryReader { geo in
                    PackageFlight(seal: anchors[.sidePackages].map { geo[$0] }, container: geo.size)
                }
            }
            .fisuSheet(item: wheelSheetBinding) { _ in
                NavigationStack {
                    WheelView(close: { gameState.closeWheel() })
                }
                .tint(Color("PaletteInk"))
                .fisuSheet()
            }
    }

    /// Dónde tocar la caja del tablero, para los UI tests (E14b B5): invisible y medible.
    private var boardPackageMarker: some View {
        Color.clear
            .accessibilityElement()
            .accessibilityIdentifier("board.package")
            .accessibilityValue(Text(verbatim: gameState.boardPackageMarker))
    }

    /// Dónde tocar el colchón del tablero, para los UI tests (E14b B6).
    private var boardMattressMarker: some View {
        Color.clear
            .accessibilityElement()
            .accessibilityIdentifier("board.mattress")
            .accessibilityValue(Text(verbatim: gameState.boardMattressMarker))
    }

    private var packagePopupBinding: Binding<PackagePopup?> {
        Binding(
            get: { gameState.packagePopup },
            set: { if $0 == nil { gameState.closePackagePopup() } }
        )
    }

    private var wheelSheetBinding: Binding<WheelSheet?> {
        Binding(
            get: { gameState.wheelSheet },
            set: { if $0 == nil { gameState.closeWheel() } }
        )
    }
}
