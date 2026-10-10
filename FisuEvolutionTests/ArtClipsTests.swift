import Foundation
import Testing
@testable import FisuEvolution

@Suite("ArtClips: qué clip le toca a cada lugar")
struct ArtClipsTests {
    private static func entries(_ ids: [String]) -> String {
        ids.map { #""\#($0)":{"file":"\#($0).mov","width":512,"height":512,"alpha":true,"audio":false}"# }
            .joined(separator: ",")
    }

    private static func manifest(characters: [String] = [], talking: [String] = [],
                                 actions: [String] = [], events: [String] = [],
                                 shopIcons: [String] = []) throws -> LoopsManifest {
        let json = """
        {"schemaVersion":1,"characters":{\(entries(characters))},"talking":{\(entries(talking))},
         "visitorActions":{\(entries(actions))},"events":{\(entries(events))},
         "shopIcons":{\(entries(shopIcons))}}
        """
        return try JSONDecoder().decode(LoopsManifest.self, from: Data(json.utf8))
    }

    @Test("sin pinta, el cuerpo base")
    func baseWithoutSkin() throws {
        let manifest = try Self.manifest(characters: ["homeless"])
        #expect(ArtClips.character(type: "homeless", skin: nil, in: manifest) == .character("homeless"))
    }

    @Test("con pinta y clip, el de la pinta")
    func skinWithClip() throws {
        let manifest = try Self.manifest(characters: ["homeless", "homeless__pijama"])
        #expect(ArtClips.character(type: "homeless", skin: "pijama", in: manifest) == .character("homeless__pijama"))
    }

    @Test("una pinta sin clip queda quieta: nunca la base")
    func skinWithoutClipIsStill() throws {
        let manifest = try Self.manifest(characters: ["homeless"])
        #expect(ArtClips.character(type: "homeless", skin: "pijama", in: manifest) == nil)
    }

    @Test("sin base y sin pinta no hay clip")
    func noBaseNoClip() throws {
        #expect(ArtClips.character(type: "homeless", skin: nil, in: try Self.manifest()) == nil)
    }

    @Test("el visitante del escenario habla con globo")
    func stageVisitorTalksWithBubble() throws {
        let manifest = try Self.manifest(talking: ["npc_vecina"], actions: ["npc_vecina"])
        #expect(ArtClips.stageVisitor("npc_vecina", talking: true, in: manifest) == .talking("npc_vecina"))
    }

    @Test("el visitante del escenario actúa sin globo, y sin clip no cae al retrato")
    func stageVisitorActsWithoutBubble() throws {
        let manifest = try Self.manifest(talking: ["npc_vecina", "sp_coach"], actions: ["npc_vecina"])
        #expect(ArtClips.stageVisitor("npc_vecina", talking: false, in: manifest) == .visitorAction("npc_vecina"))
        #expect(ArtClips.stageVisitor("sp_coach", talking: false, in: manifest) == nil)
    }

    @Test("los ítems de la tienda mapean a su clip; sin clip o sin entrada, póster")
    func shopIconMapsItems() throws {
        let manifest = try Self.manifest(shopIcons: ["ui_oro_income_boost"])
        #expect(ArtClips.shopIcon(item: "income_x3", in: manifest) == .shopIcon("ui_oro_income_boost"))
        #expect(ArtClips.shopIcon(item: "skin_chest", in: manifest) == nil)
        #expect(ArtClips.shopIcon(item: "auto_tap", in: manifest) == nil, "mapeado, pero el clip falta")
    }

    @Test("el evento tiene clip sólo si está en el manifest")
    func eventClipOnlyWhenPresent() throws {
        let manifest = try Self.manifest(events: ["aguinaldo"])
        #expect(ArtClips.event("aguinaldo", in: manifest) == .event("aguinaldo"))
        #expect(ArtClips.event("apagon", in: manifest) == nil)
    }

    @Test("la clave de una pinta es tipo__pinta")
    func skinKeyConvention() {
        #expect(ArtClips.skinKey(type: "administrativo", skin: "dinosaurio") == "administrativo__dinosaurio")
    }
}
