import EconomyKit
import SwiftUI

/// La sonda del ledger de impresiones para los UI tests (E15): con `--uitest-ad-value-probe`, un
/// elemento invisible pero accesible, `ads.ledger.count`, cuyo valor es el total de impresiones
/// anotadas en el save; y el embudo de ofertas (E15 T3), `ads.funnel.<site>.<etapa>` con su contador,
/// uno por lugar que ya anotó algo. Sin el argumento (y siempre en Release) no agrega nada.
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
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(width: 1, height: 1)
                            .accessibilityElement()
                            .accessibilityIdentifier("ads.ledger.count")
                            .accessibilityValue(Text(verbatim: String(Self.impressionCount(gameState.player?.meta.adRevenue))))
                        ForEach(Self.funnelEntries(gameState.player?.meta.offerFunnel)) { entry in
                            Color.clear
                                .frame(width: 1, height: 1)
                                .accessibilityElement()
                                .accessibilityIdentifier(entry.id)
                                .accessibilityValue(Text(verbatim: String(entry.count)))
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    struct FunnelEntry: Identifiable, Equatable {
        let id: String
        let count: Int
    }

    /// Una entrada por lugar y etapa: `ads.funnel.<site>.<etapa>` y su contador.
    static func funnelEntries(_ funnel: OfferFunnel?) -> [FunnelEntry] {
        guard let funnel else { return [] }
        return funnel.sites.keys.sorted().flatMap { site in
            OfferStage.allCases.map { stage in
                FunnelEntry(id: "ads.funnel.\(site).\(stage.rawValue)", count: funnel.counts(site: site)[stage])
            }
        }
    }

    /// Todas las impresiones: las de la moneda del ledger, por formato, y las que llegaron en otra.
    static func impressionCount(_ ledger: AdRevenueLedger?) -> Int {
        guard let ledger else { return 0 }
        return AdFormat.allCases.reduce(ledger.foreignCurrencyCount) { $0 + ledger.stats($1).count }
    }
}
