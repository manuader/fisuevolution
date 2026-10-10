import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El arte de los visitantes, con respaldo")
@MainActor
struct VisitorArtTests {
    private func manifest(npcs: [String: String]?) throws -> AssetsManifest {
        var manifest = try GameContentLoader.load(from: .main).manifest
        manifest.npcs = npcs
        return manifest
    }

    @Test("un visitante nuevo sin arte no tiene asset; un especial cae a su canónica de la v1")
    func fallbacks() throws {
        let manifest = try manifest(npcs: nil)
        #expect(VisitorArt.asset(for: "npc_comisario", pose: .talk, manifest: manifest) == nil)
        let special = try #require(VisitorArt.asset(for: "sp_cryptobro", pose: .face, manifest: manifest))
        #expect(special.atlas == manifest.characters["sp_cryptobro"]?.atlas)
        #expect(special.key == manifest.characters["sp_cryptobro"]?.key)
        #expect(!VisitorArt.hasOwnFace("sp_cryptobro", manifest: manifest), "la cara se recorta de la canónica")
    }

    @Test("una pose integrada gana; si falta, la canónica de npcs")
    func integratedPosesWin() throws {
        let manifest = try manifest(npcs: ["npc_comisario": "npc_comisario", "npc_comisario_talk": "npc_comisario_talk"])
        #expect(VisitorArt.asset(for: "npc_comisario", pose: .talk, manifest: manifest)?.key == "npc_comisario_talk")
        #expect(VisitorArt.asset(for: "npc_comisario", pose: .talk, manifest: manifest)?.atlas == "npcs")
        #expect(VisitorArt.asset(for: "npc_comisario", pose: .action, manifest: manifest)?.key == "npc_comisario")
    }

    @Test("el manifest de hoy decodifica sin la sección npcs")
    func manifestWithoutNpcsDecodes() throws {
        let json = #"{"schemaVersion": 1, "characters": {}, "backgrounds": {}, "ui": {}}"#
        let manifest = try JSONDecoder().decode(AssetsManifest.self, from: Data(json.utf8))
        #expect(manifest.npcs == nil)
    }

    @Test("el respaldo se dibuja sin vista y del tamaño pedido")
    func placeholderRenders() {
        let image = VisitorArt.placeholderImage(symbol: "figure.stand", tint: "PaletteBlue", side: 64)
        #expect(image.size == CGSize(width: 64, height: 64))
    }
}
