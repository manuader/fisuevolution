import Foundation
import Testing
@testable import EconomyKit

@Suite("skins.json v2: efectos, familias y precio en ORO")
struct SkinsConfigV2Tests {
    private let types: Set<String> = ["homeless", "cartonero"]
    private let shaders: Set<String> = ["neon", "pixel"]

    private func config(_ entries: [SkinsConfig.Entry]) -> SkinsConfig {
        SkinsConfig(schemaVersion: 2, skins: entries)
    }

    private func validate(_ entries: [SkinsConfig.Entry]) throws {
        try config(entries).validate(characterTypeIDs: types, floorIDs: [], shaderIDs: shaders)
    }

    @Test("se leen los cuatro campos nuevos, y una entrada vieja sigue leyéndose")
    func decodes() throws {
        let json = #"""
        {"schemaVersion": 2, "skins": [
          {"id": "neon", "characterType": "*", "treatment": "effect", "shaderId": "neon", "oroPrice": 150},
          {"id": "pijama", "characterType": "homeless", "treatment": "texture", "textureKey": "homeless_idle__pijama",
           "textureAtlas": "fam_pijama", "family": "pijama", "oroPrice": 450},
          {"id": "cohete", "characterType": "cartonero", "treatment": "texture", "textureKey": "cartonero_idle__cohete", "chestRarity": "comun"}
        ]}
        """#
        let skins = try JSONDecoder().decode(SkinsConfig.self, from: Data(json.utf8))
        #expect(skins.skins[0].treatment == .effect)
        #expect(skins.skins[0].shaderId == "neon")
        #expect(skins.skins[1].textureAtlas == "fam_pijama")
        #expect(skins.skins[1].family == "pijama")
        #expect(skins.skins[2].oroPrice == nil)
        #expect(throws: Never.self) { try skins.validate(characterTypeIDs: types, floorIDs: [], shaderIDs: shaders) }
    }

    @Test("las de ORO: una vez por id, en el orden del catálogo, con su precio")
    func oroSkins() {
        let skins = config([
            .init(id: "neon", characterType: "*", treatment: .effect, shaderId: "neon", oroPrice: 150),
            .init(id: "pijama", characterType: "homeless", treatment: .texture, textureKey: "homeless_idle__pijama",
                  oroPrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
            .init(id: "pijama", characterType: "cartonero", treatment: .texture, textureKey: "cartonero_idle__pijama",
                  oroPrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
            .init(id: "cohete", characterType: "cartonero", treatment: .texture, textureKey: "k", chestRarity: .comun),
        ])
        #expect(skins.oroSkinIDs == ["neon", "pijama"])
        #expect(skins.oroPrice(of: "pijama") == 450)
        #expect(skins.oroPrice(of: "cohete") == nil)
        #expect(skins.exclusiveCharacterTypeBySkinID["pijama"] == nil, "una familia viste a varios: no trae a nadie")
        #expect(skins.exclusiveCharacterTypeBySkinID["neon"] == nil)
        #expect(skins.entries(forCharacterType: "homeless").map(\.id) == ["neon", "pijama"])
    }

    @Test("un efecto necesita un shader que exista")
    func effectNeedsAShader() {
        #expect(throws: SkinsConfig.ValidationError.missingShader("x")) {
            try validate([.init(id: "x", characterType: "*", treatment: .effect, oroPrice: 150)])
        }
        #expect(throws: SkinsConfig.ValidationError.unknownShader("glitchy")) {
            try validate([.init(id: "x", characterType: "*", treatment: .effect, shaderId: "glitchy", oroPrice: 150)])
        }
    }

    @Test("una pinta de ORO no sale de un cofre, no se gana por milestone y tiene un solo precio")
    func oroIsExclusive() {
        #expect(throws: SkinsConfig.ValidationError.nonPositiveOroPrice("x")) {
            try validate([.init(id: "x", characterType: "*", treatment: .effect, shaderId: "neon", oroPrice: 0)])
        }
        #expect(throws: SkinsConfig.ValidationError.oroAndChest("x")) {
            try validate([.init(id: "x", characterType: "homeless", treatment: .texture, textureKey: "k", chestRarity: .rara, oroPrice: 150)])
        }
        #expect(throws: SkinsConfig.ValidationError.oroAndMilestone("x")) {
            try validate([.init(id: "x", characterType: "homeless", treatment: .texture, textureKey: "k", reincarnations: 1, oroPrice: 150)])
        }
        #expect(throws: SkinsConfig.ValidationError.inconsistentOroPrice("p")) {
            try validate([
                .init(id: "p", characterType: "homeless", treatment: .texture, textureKey: "a", oroPrice: 450, family: "p", textureAtlas: "fam_p"),
                .init(id: "p", characterType: "cartonero", treatment: .texture, textureKey: "b", oroPrice: 400, family: "p", textureAtlas: "fam_p"),
            ])
        }
    }

    @Test("una familia dice en qué atlas vive")
    func familyNeedsAnAtlas() {
        #expect(throws: SkinsConfig.ValidationError.familyWithoutAtlas("p")) {
            try validate([.init(id: "p", characterType: "homeless", treatment: .texture, textureKey: "a", oroPrice: 450, family: "p")])
        }
    }

    @Test("sin shaders conocidos, ningún efecto valida")
    func noShadersNoEffects() {
        #expect(throws: SkinsConfig.ValidationError.unknownShader("neon")) {
            try config([.init(id: "neon", characterType: "*", treatment: .effect, shaderId: "neon", oroPrice: 150)])
                .validate(characterTypeIDs: types, floorIDs: [])
        }
    }
}
