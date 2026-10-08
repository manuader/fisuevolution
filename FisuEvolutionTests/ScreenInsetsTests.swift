import CoreGraphics
import Observation
import Testing
@testable import FisuEvolution

/// Las safe areas de la pantalla, observables (PLAN-v2 E3). La sonda que las
/// lee de la ventana se mide en el spike S4 y en `ScreenInsetsUITests`; acá se
/// pinea el contrato del objeto.
@Suite("ScreenInsets")
@MainActor
struct ScreenInsetsTests {
    /// `withObservationTracking` pide un `@Sendable` y bajo concurrencia
    /// estricta un `var` capturado no compila (patrón de `QuickHireOfferTests`).
    private final class PublishFlag: @unchecked Sendable {
        var published = false
    }

    @Test("arranca con los insets de un teléfono con notch, para no saltar en el primer frame")
    func startsWithNotchDefaults() {
        let insets = ScreenInsets()
        #expect(insets.top == 44)
        #expect(insets.bottom == 34)
    }

    @Test("publica sólo cuando el valor cambia")
    func publishesOnlyOnChange() {
        let insets = ScreenInsets()
        insets.update(top: 62, bottom: 34)

        let quiet = PublishFlag()
        withObservationTracking { _ = insets.top; _ = insets.bottom } onChange: { quiet.published = true }
        insets.update(top: 62, bottom: 34)
        #expect(!quiet.published, "la sonda corre en cada layout: repetir el valor no puede invalidar")

        let moved = PublishFlag()
        withObservationTracking { _ = insets.top; _ = insets.bottom } onChange: { moved.published = true }
        insets.update(top: 0, bottom: 0)
        #expect(moved.published)
    }

    @Test("el aire contra el bezel sólo entra cuando el inset es chico",
          arguments: [(0, 12), (34, 0), (12, 0), (5, 7)] as [(CGFloat, CGFloat)])
    func floorGap(inset: CGFloat, expected: CGFloat) {
        #expect(ScreenInsets.floorGap(minimum: 12, inset: inset) == expected)
    }

    @Test("la columna del chrome es más ancha que cualquier iPhone")
    func playColumnNeverTouchesAPhone() {
        #expect(PlayColumn.maxWidth > PlayLayout.phoneMaxWidth)
        #expect(PlayColumn.tutorialCardMaxWidth > PlayLayout.phoneMaxWidth)
    }
}
