import Foundation
import Testing
@testable import EconomyKit

@Suite("skins.json v2: familias y precio en blue")
struct SkinsConfigV2Tests {
    private let types: Set<String> = ["homeless", "cartonero"]

    private func config(_ entries: [SkinsConfig.Entry]) -> SkinsConfig {
        SkinsConfig(schemaVersion: 2, skins: entries)
    }

    private func validate(_ entries: [SkinsConfig.Entry]) throws {
        try config(entries).validate(characterTypeIDs: types, floorIDs: [])
    }

    @Test("se leen los campos nuevos, y una entrada vieja sigue leyéndose")
    func decodes() throws {
        let json = #"""
        {"schemaVersion": 2, "skins": [
          {"id": "dorado", "characterType": "*", "treatment": "tint", "tintHex": "#FFD700", "bluePrice": 150},
          {"id": "pijama", "characterType": "homeless", "treatment": "texture", "textureKey": "homeless_idle__pijama",
           "textureAtlas": "fam_pijama", "family": "pijama", "bluePrice": 450},
          {"id": "cohete", "characterType": "cartonero", "treatment": "texture", "textureKey": "cartonero_idle__cohete", "chestRarity": "comun"}
        ]}
        """#
        let skins = try JSONDecoder().decode(SkinsConfig.self, from: Data(json.utf8))
        #expect(skins.skins[0].bluePrice == 150)
        #expect(skins.skins[1].textureAtlas == "fam_pijama")
        #expect(skins.skins[1].family == "pijama")
        #expect(skins.skins[2].bluePrice == nil)
        #expect(throws: Never.self) { try skins.validate(characterTypeIDs: types, floorIDs: []) }
    }

    @Test("las de blue: una vez por id, en el orden del catálogo, con su precio")
    func blueSkins() {
        let skins = config([
            .init(id: "dorado", characterType: "*", treatment: .tint, tintHex: "#FFD700", bluePrice: 150),
            .init(id: "pijama", characterType: "homeless", treatment: .texture, textureKey: "homeless_idle__pijama",
                  bluePrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
            .init(id: "pijama", characterType: "cartonero", treatment: .texture, textureKey: "cartonero_idle__pijama",
                  bluePrice: 450, family: "pijama", textureAtlas: "fam_pijama"),
            .init(id: "cohete", characterType: "cartonero", treatment: .texture, textureKey: "k", chestRarity: .comun),
        ])
        #expect(skins.blueSkinIDs == ["dorado", "pijama"])
        #expect(skins.bluePrice(of: "pijama") == 450)
        #expect(skins.bluePrice(of: "cohete") == nil)
        #expect(skins.exclusiveCharacterTypeBySkinID["pijama"] == nil, "una familia viste a varios: no trae a nadie")
        #expect(skins.exclusiveCharacterTypeBySkinID["dorado"] == nil)
        #expect(skins.entries(forCharacterType: "homeless").map(\.id) == ["dorado", "pijama"])
    }

    @Test("una pinta de blue no sale de un cofre, no se gana por milestone y tiene un solo precio")
    func blueIsExclusive() {
        #expect(throws: SkinsConfig.ValidationError.nonPositiveBluePrice("x")) {
            try validate([.init(id: "x", characterType: "*", treatment: .tint, tintHex: "#FFD700", bluePrice: 0)])
        }
        #expect(throws: SkinsConfig.ValidationError.blueAndChest("x")) {
            try validate([.init(id: "x", characterType: "homeless", treatment: .texture, textureKey: "k", chestRarity: .rara, bluePrice: 150)])
        }
        #expect(throws: SkinsConfig.ValidationError.blueAndMilestone("x")) {
            try validate([.init(id: "x", characterType: "homeless", treatment: .texture, textureKey: "k", reincarnations: 1, bluePrice: 150)])
        }
        #expect(throws: SkinsConfig.ValidationError.inconsistentBluePrice("p")) {
            try validate([
                .init(id: "p", characterType: "homeless", treatment: .texture, textureKey: "a", bluePrice: 450, family: "p", textureAtlas: "fam_p"),
                .init(id: "p", characterType: "cartonero", treatment: .texture, textureKey: "b", bluePrice: 400, family: "p", textureAtlas: "fam_p"),
            ])
        }
    }

    @Test("una familia dice en qué atlas vive")
    func familyNeedsAnAtlas() {
        #expect(throws: SkinsConfig.ValidationError.familyWithoutAtlas("p")) {
            try validate([.init(id: "p", characterType: "homeless", treatment: .texture, textureKey: "a", bluePrice: 450, family: "p")])
        }
    }
}
