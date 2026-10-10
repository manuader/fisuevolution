import EconomyKit
import SpriteKit
import Testing
@testable import FisuEvolution

/// Las familias dibujadas (PLAN-v2 E6): una familia se vende con los 43 o no se vende.
@Suite("Las tres familias")
@MainActor
struct FamilySkinsContentTests {
    nonisolated static let families = ["pijama", "gaucho", "dinosaurio"]

    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("cada familia viste a los 43, con el mismo id y 450 de ORO", arguments: families)
    func everyCharacter(family: String) {
        let entries = content.skins.skins.filter { $0.family == family }
        let concrete = content.tiers.concreteTypes.map(\.id)
        #expect(concrete.count == 43)
        #expect(entries.count == concrete.count)
        #expect(Set(entries.map(\.characterType)) == Set(concrete))
        #expect(entries.allSatisfy {
            $0.id == family && $0.oroPrice == 450 && $0.textureAtlas == "fam_\(family)"
                && $0.displayNameKey == "skin.name.\(family)"
        })
        #expect(content.skins.oroPrice(of: family) == 450)
    }

    @Test("las familias no se reparten por cofre ni por hito", arguments: families)
    func onlySoldForOro(family: String) {
        let entries = content.skins.skins.filter { $0.family == family }
        #expect(entries.allSatisfy { $0.chestRarity == nil && !$0.isMilestone })
    }

    @Test("cada textura existe en el atlas de su familia", arguments: families)
    func everyTextureExists(family: String) throws {
        let atlas = AtlasCache.atlas(named: "fam_\(family)")
        let names = Set(atlas.textureNames.map {
            $0.replacingOccurrences(of: "@2x", with: "")
                .replacingOccurrences(of: "@3x", with: "")
                .replacingOccurrences(of: ".png", with: "")
        })
        for entry in content.skins.skins where entry.family == family {
            let key = try #require(entry.textureKey)
            #expect(names.contains(key), "\(family): falta \(key)")
        }
    }
}
