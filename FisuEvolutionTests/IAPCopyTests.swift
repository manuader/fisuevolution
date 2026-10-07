import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El nombre y la descripción de los IAP salen del catálogo del juego y no de
/// App Store Connect (PLAN-v2, ítem 19: "algunos IAP salen en inglés").
///
/// Los bundles de cada idioma se abren a mano porque `Bundle.main` sólo
/// responde en el idioma con el que corre el runner (inglés, trampa 6).
@Suite("Textos de los IAP")
struct IAPCopyTests {
    private let catalog: ProductCatalog
    private let skins: SkinsConfig

    init() throws {
        catalog = try ProductCatalog.load(from: .main)
        skins = try GameContentLoader.load(from: .main).skins
    }

    private func languageBundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    private func product(_ suffix: String) throws -> ProductCatalog.Entry {
        try #require(catalog.products.first { $0.id == "com.fisuevolution.iap.\(suffix)" })
    }

    @Test("cada producto tiene nombre y descripción propios en los dos idiomas", arguments: ["es", "en"])
    func everyProductHasItsOwnCopy(language: String) throws {
        let bundle = try languageBundle(language)
        let storeKit = "lo de App Store Connect"
        for product in catalog.products {
            let name = IAPCopy.name(for: product.id, fallback: storeKit, bundle: bundle)
            let quantity = IAPCopy.quantity(for: product, skins: skins)
            let detail = IAPCopy.description(for: product.id, quantity: quantity, fallback: storeKit, bundle: bundle)
            #expect(name != storeKit, "\(product.id): sin nombre en \(language)")
            #expect(detail != storeKit, "\(product.id): sin descripción en \(language)")
            #expect(!detail.contains("%"), "\(product.id): quedó un placeholder sin llenar en \(language)")
        }
    }

    @Test func theNameIsTheGamesNotAppStoreConnects() throws {
        let id = try product("coins_small").id
        let es = try languageBundle("es")
        let en = try languageBundle("en")
        #expect(IAPCopy.name(for: id, fallback: "Handful of Cash", bundle: es) == "Puñado de Plata")
        #expect(IAPCopy.name(for: id, fallback: "Puñado de Plata", bundle: en) == "Handful of Cash")
    }

    /// Un producto nuevo sin su texto en el catálogo se ve con lo de App Store
    /// Connect, nunca con la clave cruda.
    @Test func aProductWithoutCopyFallsBackToStoreKit() throws {
        let bundle = try languageBundle("es")
        let id = "com.fisuevolution.iap.no_existe"
        #expect(IAPCopy.name(for: id, fallback: "Nombre de ASC", bundle: bundle) == "Nombre de ASC")
        let detail = IAPCopy.description(for: id, quantity: 160, fallback: "Descripción de ASC", bundle: bundle)
        #expect(detail == "Descripción de ASC")
    }

    /// Los packs de ORO cambian de monto en la 2.0 (160/550/1.400): el número
    /// sale de `oroAmount` y el texto no se toca.
    @Test func theOroDescriptionTakesTheAmountFromTheData() throws {
        let pack = try product("oro_small")
        let retuned = ProductCatalog.Entry(
            id: pack.id, type: pack.type, entitlement: .oro, skinId: nil, coinFactor: nil, oroAmount: 160
        )
        let quantity = IAPCopy.quantity(for: retuned, skins: skins)
        #expect(quantity == 160)

        let spanish = try languageBundle("es")
        let english = try languageBundle("en")
        let es = IAPCopy.description(
            for: pack.id, quantity: quantity, fallback: "", bundle: spanish, locale: Locale(identifier: "es")
        )
        let en = IAPCopy.description(
            for: pack.id, quantity: quantity, fallback: "", bundle: english, locale: Locale(identifier: "en")
        )
        #expect(es.hasPrefix("160 de ORO"))
        #expect(en.hasPrefix("160 ORO"))
    }

    @Test func everyOroPackSaysItsOwnAmount() throws {
        for pack in catalog.products where pack.entitlement == .oro {
            let amount = try #require(pack.oroAmount)
            #expect(IAPCopy.quantity(for: pack, skins: skins) == amount)
        }
    }

    /// El paquete de Diamante dice cuántos personajes trae, contados en
    /// `skins.json`: si el elenco cambia, el texto se entera solo.
    @Test func theDiamondPackCountsItsCharacters() throws {
        let pack = try product("skins_diamante")
        let diamonds = skins.skins.filter { $0.id == "diamante" }.count
        let quantity = IAPCopy.quantity(for: pack, skins: skins)
        #expect(diamonds > 1)
        #expect(quantity == diamonds)

        let spanish = try languageBundle("es")
        let es = IAPCopy.description(
            for: pack.id, quantity: quantity, fallback: "", bundle: spanish, locale: Locale(identifier: "es")
        )
        #expect(es == "Los \(diamonds) personajes tallados en diamante")
    }

    @Test("lo que no habla de un número no lleva número",
          arguments: ["coins_small", "starter_pack", "remove_ads", "skin_mundialista", "skin_parrillero"])
    func productsWithoutANumber(suffix: String) throws {
        let entry = try product(suffix)
        #expect(IAPCopy.quantity(for: entry, skins: skins) == nil)
    }
}
