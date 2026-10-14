import Foundation
import Testing
import UIKit
@testable import FisuEvolution

/// Todo pop-up con su imagen (E14b B9, D8, D9): el arte aprobado de `fisu-v2-blue` está integrado y
/// carga, cada oferta resuelve su imagen principal, ningún evento queda sin dibujo y el escenario de
/// la Ruleta entra en el ancho que le da la hoja.
@Suite("Pop-ups con su imagen (E14b B9)")
@MainActor
struct PopupHeroTests {
    /// Las 8 imágenes de B9. Pineadas LITERALES: son los ids que consumen las pantallas.
    static let heroKeys: [String] = [
        "rw_pack_mudanza", "rw_pack_bienvenida", "rw_pack_renacer", "rw_reencarnar",
        "rw_mattress_hero", "ui_notif_campana", "ui_save_rescate", "ui_reset_demolicion",
    ]

    @Test("las 8 imágenes de B9 están en el manifest y cargan con píxeles")
    func heroArtLoads() throws {
        let manifest = try GameContentLoader.load(from: .main).manifest
        for key in Self.heroKeys {
            #expect(manifest.ui[key] == key, "\(key): sin entrada en assets_manifest")
            let image = try #require(UIArt.uiImage(key), "\(key): en el manifest pero no carga del atlas")
            #expect(image.size.width > 1 && image.size.height > 1, "\(key)")
        }
    }

    @Test("cada oferta lleva su imagen principal y esa imagen carga")
    func everyOfferHasHeroArt() throws {
        let offers = try GameContentLoader.load(from: .main).offers.offers
        #expect(!offers.isEmpty)
        let expected = ["mudanza": "rw_pack_mudanza", "bienvenida": "rw_pack_bienvenida", "renacer": "rw_pack_renacer"]
        for offer in offers {
            let key = OfferHeroArt.key(forOfferId: offer.id, iconKey: offer.iconKey)
            #expect(key == expected[offer.id], "\(offer.id)")
            #expect(UIArt.uiImage(key) != nil, "\(offer.id): \(key) no carga")
        }
    }

    @Test("una oferta sin imagen propia usa la de su ícono")
    func unknownOfferFallsBackToItsIcon() {
        #expect(OfferHeroArt.key(forOfferId: "otra", iconKey: "ui_offer_mudanza") == "ui_offer_mudanza")
    }

    @Test("ningún evento queda sin imagen: la suya o el dibujo de lo que cambia")
    func everyEventHasAnIllustration() throws {
        let content = try GameContentLoader.load(from: .main)
        for event in content.events.events {
            let hasPoster = UIArt.uiImage("ui_event_\(event.id)") != nil
            let shop = event.shopOffer.map(EventPopupView.shopIllustrationKind(for:))
            let kind = shop ?? EventPopupView.fallbackKind(for: event)
            #expect(hasPoster || kind.resolvedArtKey != nil, "\(event.id): sin imagen")
        }
    }

    @Test("el marco de la imagen principal incluye el aire de los rayos")
    func heroFrameIncludesTheRays() {
        #expect(PopupHeroMetrics.frameSide(for: 100) == 130)
        #expect(PopupHeroMetrics.pileSide > PopupHeroMetrics.side)
        #expect(PopupHeroMetrics.side >= 120, "grande, no un ícono")
    }

    @Test("el escenario de la Ruleta se achica al ancho de la hoja y nunca se agranda")
    func wheelStageFitsTheSheet() {
        #expect(WheelStage.fitScale(availableWidth: WheelStage.size.width + 100) == 1)
        #expect(WheelStage.fitScale(availableWidth: WheelStage.size.width) == 1)
        let narrow = WheelStage.fitScale(availableWidth: 252)
        #expect(narrow < 1 && narrow > 0.5)
        #expect(abs(WheelStage.size.width * narrow - 252) < 0.001)
        #expect(WheelStage.fitScale(availableWidth: 0) == 1, "sin medir todavía: tamaño natural")
    }
}
