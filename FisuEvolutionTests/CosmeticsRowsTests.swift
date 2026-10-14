import EconomyKit
import Testing
@testable import FisuEvolution

@Suite("El estante de Cosméticos")
struct CosmeticsRowsTests {
    private let skins = SkinsConfig(schemaVersion: 2, skins: [
        .init(id: "pijama", characterType: "homeless", treatment: .texture, textureKey: "a", bluePrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
        .init(id: "pijama", characterType: "cartonero", treatment: .texture, textureKey: "b", bluePrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
        .init(id: "cohete", characterType: "repartidor", treatment: .texture, textureKey: "c", bluePrice: 150),
        .init(id: "urban", characterType: "cartonero", treatment: .texture, textureKey: "d", chestRarity: .comun),
    ])

    @Test("una fila por pinta de blue, con su clase, su precio y si ya es tuya")
    func rows() {
        let rows = CosmeticRow.rows(skins: skins, owned: ["pijama"])
        #expect(rows.map(\.id) == ["pijama", "cohete"])
        #expect(rows[0].kind == .family(name: "pijama"))
        #expect(rows[1].kind == .outfit(characterType: "repartidor"))
        #expect(rows.map(\.price) == [450, 150])
        #expect(rows.map(\.owned) == [true, false])
    }

    @Test("el estante va entre Permanentes y Suerte")
    func shelfOrder() {
        #expect(BlueShopCatalog.Shelf.allCases == [.boosts, .shortcuts, .permanents, .cosmetics, .luck])
    }

    @Test("la leyenda de una familia a la venta con blue dice que incluye a todos")
    @MainActor
    func packCaptionForBlueFamilies() async throws {
        let state = await makeGameState()
        let content = try #require(state.content)
        let family = try #require(content.skins.skins.first { $0.family != nil })
        let rows = state.skinCatalogRows(forCharacterType: family.characterType)
        let row = try #require(rows.first { $0.id == family.id })
        #expect(row.state == .bluePurchasable(price: try #require(family.bluePrice)))
        #expect(row.packSize == content.skins.skins.filter { $0.id == family.id }.count)
    }
}
