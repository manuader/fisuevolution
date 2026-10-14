import CoreGraphics
import Testing
@testable import FisuEvolution

@Suite("Los avisos: dónde caen")
struct NoticesLayoutTests {
    @Test("en el SE el aviso se baja bajo la primera tarjeta de la columna derecha; en el resto no se mueve")
    func compactScreensLowerTheNotice() {
        #expect(NoticesLayout.compactDrop(forWidth: 375) == NoticesLayout.compactDropHeight)
        #expect(NoticesLayout.compactDrop(forWidth: 320) == NoticesLayout.compactDropHeight)
        for width in [390, 393, 402, 430, 440, 744] as [CGFloat] {
            #expect(NoticesLayout.compactDrop(forWidth: width) == 0, "\(width)")
        }
        #expect(NoticesLayout.compactDropHeight >= SideRailLayout.touchWidth, "baja al menos una tarjeta de la columna")
    }
}
