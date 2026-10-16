import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import FisuEvolution

/// Lo que la etiqueta del atajo muestra del personaje (E14b B33): la cara y el
/// nombre de la oferta, y que el cambio de oferta los cambia. El botón dibuja lo
/// que dice `QuickHireTagContent`, que sale de la oferta y de nada más.
@Suite("La etiqueta del atajo: cara y nombre de la oferta", .serialized)
@MainActor
struct QuickHireTagContentTests {
    private func giveCoins(_ amount: Double, to gameState: GameState) throws {
        var player = try #require(gameState.player)
        player.run.coins = amount
        gameState.player = player
    }

    /// Dos pisos abiertos, todo visto y plata de sobra (el escenario de `QuickHireOfferTests`).
    private func twoFloorsScenario() async throws -> GameState {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 13)
        gameState.debugMarkTypesSeen(throughTier: 12)
        gameState.debugSetMaxTier(18)
        try giveCoins(2_500_000_000_000, to: gameState)
        gameState.refreshProjections()
        return gameState
    }

    @Test("la cara y el nombre son los de la oferta, el nombre en mayúsculas")
    func contentIsTheOffers() async throws {
        let gameState = await makeGameState()
        gameState.refreshProjections()
        let offer = try #require(gameState.quickHireOffer)
        let content = QuickHireTagContent(offer: offer)
        #expect(content.faceKey == offer.faceKey)
        #expect(content.faceKey == "homeless_face")
        #expect(content.name == offer.displayName.uppercased())
        #expect(!content.name.isEmpty)
    }

    @Test("al cambiar de piso con «el primero del piso», la cara y el nombre cambian")
    func contentFollowsTheFloor() async throws {
        let gameState = try await twoFloorsScenario()
        gameState.setQuickHire(mode: .floorBase)
        let first = QuickHireTagContent(offer: try #require(gameState.quickHireOffer))
        #expect(first.faceKey == "homeless_face")

        gameState.setVisibleFloor(1)
        let player = try #require(gameState.player)
        let secondBase = try #require(gameState.currentQuote(player: player, floorOrdinal: 1)).type.id
        let second = QuickHireTagContent(offer: try #require(gameState.quickHireOffer))
        #expect(second.faceKey == "\(secondBase)_face", "la cara es la del tipo base del segundo piso")
        #expect(second != first)
        #expect(second.name != first.name)

        gameState.setVisibleFloor(0)
        #expect(QuickHireTagContent(offer: try #require(gameState.quickHireOffer)) == first, "y vuelve al bajar")
    }

    @Test("al fijar a otro en el selector, la cara y el nombre pasan a ser los suyos")
    func contentFollowsThePin() async throws {
        let gameState = try await twoFloorsScenario()
        let best = QuickHireTagContent(offer: try #require(gameState.quickHireOffer))
        gameState.setQuickHire(mode: .pinned, typeId: "homeless")
        let pinned = QuickHireTagContent(offer: try #require(gameState.quickHireOffer))
        #expect(pinned.faceKey == "homeless_face")
        #expect(pinned != best, "el mejor es otro personaje")
    }

    @Test("el nombre más largo del catálogo, achicado hasta su piso, entra en la placa del SE")
    func longestNameFits() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let names = content.tiers.concreteTypes.map { $0.localizedName.uppercased() }
        #expect(names.contains { !$0.isEmpty })
        let base = UIFont.systemFont(ofSize: QuickHireButton.nameSize, weight: .black)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: QuickHireButton.nameSize) } ?? base
        for width: CGFloat in [375, 393, 430] {
            let lane = BarFlapLayout.make(barWidth: width, tabs: GameScreen.barOrder.map { $0 == GameScreen.centerTab }).left.width
            let available = QuickHireButton.nameTextWidth(lane: lane)
            #expect(available >= 30, "la placa tiene lugar para un nombre a \(width) pt")
            for name in names {
                let natural = (name as NSString).size(withAttributes: [.font: font]).width
                #expect(natural * QuickHireButton.nameMinScale <= available, "«\(name)» a \(width) pt")
            }
        }
    }
}
