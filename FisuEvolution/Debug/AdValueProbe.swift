import EconomyKit
import SwiftUI

/// La sonda del ledger de impresiones para los UI tests (E15): con `--uitest-ad-value-probe`, un
/// elemento invisible pero accesible, `ads.ledger.count`, cuyo valor es el total de impresiones
/// anotadas en el save. Sin el argumento (y siempre en Release) no agrega nada.
///
/// Se refresca con un `TimelineView` y no por observación: `GameState.player` es
/// `@ObservationIgnored`, así que leerlo en un `body` no lo vuelve a dibujar cuando cambia.
struct AdValueProbe: ViewModifier {
    @Environment(GameState.self) private var gameState

    private static let isEnabled: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--uitest-ad-value-probe")
        #else
        return false
        #endif
    }()

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            if Self.isEnabled {
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityIdentifier("ads.ledger.count")
                        .accessibilityValue(Text(verbatim: String(Self.impressionCount(gameState.player?.meta.adRevenue))))
                }
                .allowsHitTesting(false)
            }
        }
    }

    /// Todas las impresiones: las de la moneda del ledger, por formato, y las que llegaron en otra.
    static func impressionCount(_ ledger: AdRevenueLedger?) -> Int {
        guard let ledger else { return 0 }
        return AdFormat.allCases.reduce(ledger.foreignCurrencyCount) { $0 + ledger.stats($1).count }
    }
}
