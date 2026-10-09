import EconomyKit
import Foundation
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("Fusionar todo: el contador")
@MainActor
struct MergeAllComboNodeTests {
    private func link(_ index: Int, of count: Int) -> BoardChange.Chain {
        BoardChange.Chain(id: UUID(), index: index, count: count)
    }

    @Test("el primer eslabón no muestra nada; del segundo en adelante, ×N")
    func countsFromTheSecondLink() {
        let combo = MergeAllComboNode(reduceMotion: true)
        combo.show(link: link(0, of: 4))
        #expect(combo.text == nil)
        #expect(combo.alpha == 0)
        combo.show(link: link(1, of: 4))
        #expect(combo.text == "×2")
        combo.show(link: link(3, of: 4))
        #expect(combo.text == "×4")
    }

    @Test("con movimiento, cada eslabón late; con Reduce Motion, no")
    func pulsesOnlyWithMotion() {
        let lively = MergeAllComboNode(reduceMotion: false)
        lively.show(link: link(1, of: 3))
        #expect(lively.action(forKey: MergeAllComboNode.pulseKey) != nil)
        let calm = MergeAllComboNode(reduceMotion: true)
        calm.show(link: link(1, of: 3))
        #expect(calm.action(forKey: MergeAllComboNode.pulseKey) == nil)
    }

    @Test("el anuncio dice cuántas fusiones hubo, con el número del dato")
    func announcementCarriesTheCount() {
        #expect(MergeAllComboNode.announcement(merges: 7).contains("7"))
    }

    @Test("una cadena que nunca mostró el contador completa en el acto")
    func finishWithoutShowingCompletesAtOnce() {
        let combo = MergeAllComboNode(reduceMotion: false)
        var done = false
        combo.finish { done = true }
        #expect(done)
    }
}
