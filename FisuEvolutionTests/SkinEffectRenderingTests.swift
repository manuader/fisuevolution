import EconomyKit
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("Las familias se ven")
@MainActor
struct SkinEffectRenderingTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private var skins: SkinsConfig {
        let base = content.tiers.baseType.id
        return SkinsConfig(schemaVersion: 2, skins: [
            .init(id: "pijama", characterType: base, treatment: .texture,
                  textureKey: "\(base)_idle__pijama", oroPrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
            .init(id: "cohete", characterType: base, treatment: .texture, textureKey: "\(base)_idle__cohete", oroPrice: 150),
        ])
    }

    @Test("una familia busca su textura en el atlas de la familia; el resto, en el del personaje")
    func familyAtlas() {
        let base = content.tiers.baseType.id
        #expect(SkinResolver.atlas(for: "pijama", characterType: base, config: skins) == "fam_pijama")
        #expect(SkinResolver.atlas(for: "cohete", characterType: base, config: skins) == nil)
        #expect(SkinResolver.atlas(for: nil, characterType: base, config: skins) == nil)
        #expect(SkinResolver.atlas(for: "pijama", characterType: "otro", config: skins) == nil)
    }

    @Test("el tablero resuelve la textura de la familia en su atlas")
    func boardTextureComesFromTheFamilyAtlas() throws {
        let family = try #require(content.skins.skins.first { $0.family != nil })
        let type = try #require(content.tiers.type(id: family.characterType))
        let key = try #require(family.textureKey)
        let atlas = try #require(family.textureAtlas)
        let expected = try #require(AtlasCache.texture(named: key, inAtlas: atlas))
        let texture = try #require(PlaceholderRenderer().texture(
            for: type, manifest: content.manifest, skinTextureKey: key, skinAtlas: atlas
        ))
        #expect(texture.size() == expected.size())
    }

    @Test("sin el atlas de la familia todavía, cae a la textura base")
    func missingFamilyArtFallsBack() throws {
        let type = content.tiers.baseType
        let texture = try #require(PlaceholderRenderer().texture(
            for: type, manifest: content.manifest, skinTextureKey: "\(type.id)_idle__pijama", skinAtlas: "fam_inexistente"
        ))
        #expect(texture.size().width > 1)
    }

    @Test("SwiftUI dibuja la familia y, si falta su arte, el retrato base")
    func swiftUIArt() {
        let type = content.tiers.baseType
        #expect(SkinArt.image(type: type, skinID: "pijama", skins: skins, manifest: content.manifest) != nil)
        #expect(SkinArt.image(type: type, skinID: "cohete", skins: skins, manifest: content.manifest) != nil)
        #expect(SkinArt.image(type: type, skinID: nil, skins: skins, manifest: content.manifest) != nil)
    }
}
