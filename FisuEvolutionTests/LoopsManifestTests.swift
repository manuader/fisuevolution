import Foundation
import Testing
@testable import FisuEvolution

@Suite("loops_manifest.json: el contrato del lado del juego")
@MainActor
struct LoopsManifestTests {
    /// El gemelo de los retratos que pinea `test_video_assets.py`.
    static let portraits: Set<String> = [
        "npc_comisario", "npc_conductor", "npc_ministro", "npc_puntero",
        "npc_sindicalista", "npc_turista", "npc_vecina", "npc_vendedor",
        "sp_alien_investor", "sp_arbolito", "sp_bug_simulacion", "sp_coach",
        "sp_contador_dios", "sp_cryptobro", "sp_demonio_arca", "sp_influencer",
        "sp_lizard", "sp_zombie_ceo",
    ]
    static let objects: Set<String> = ["paquete_abre", "paquete_espera", "colchon_abre", "colchon_espera"]

    @Test("la primera tanda: retratos y objetos 512² con alfa, mudos y en el bundle")
    func firstBatch() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(manifest.schemaVersion == 1)
        #expect(Set(manifest.portraits.keys) == Self.portraits)
        #expect(Set(manifest.objects.keys) == Self.objects)
        for (id, entry) in manifest.portraits {
            #expect(entry.file == "loop_\(id).mov", "\(id)")
            #expect(entry.width == 512 && entry.height == 512 && entry.alpha && !entry.audio, "\(id)")
            #expect(manifest.url(for: .portrait(id)) != nil, "\(id): en el manifest pero no en el bundle")
        }
        for (id, entry) in manifest.objects {
            #expect(entry.file == "obj_\(id).mov" && entry.alpha && !entry.audio, "\(id)")
            #expect(manifest.url(for: .object(id)) != nil, "\(id)")
        }
    }

    @Test("las cinemáticas que hay: 720×1280, opacas, con sonido; la intro todavía no")
    func cinematics() throws {
        let manifest = try LoopsManifest.load(from: .main)
        for id in [CinematicID.reencarnacion, .arresto, .dios] {
            let entry = try #require(manifest.cinematics[id.rawValue], "\(id.rawValue)")
            #expect(entry.file == "cine_\(id.rawValue).mov")
            #expect(entry.width == 720 && entry.height == 1280 && !entry.alpha && entry.audio)
            #expect(manifest.cinematicURL(for: id) != nil)
        }
        #expect(manifest.cinematicURL(for: .intro) == nil, "la intro es de la segunda tanda (🔒)")
    }

    @Test("la cabina está en su sección y fuera de las cinemáticas")
    func cabinIsItsOwnSection() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(Set(manifest.cabin.keys) == ["puertas_cierran", "puertas_abren"])
        #expect(manifest.cinematics.keys.allSatisfy { !$0.hasPrefix("ascensor") })
    }

    @Test("cada retrato de especial es de un especial que existe")
    func specialPortraitsBelongToSpecials() throws {
        let specials = Set(try GameContentLoader.load(from: .main).specials.specials.map(\.id))
        let manifest = try LoopsManifest.load(from: .main)
        for id in manifest.portraits.keys where id.hasPrefix("sp_") {
            #expect(specials.contains(id), "\(id): un loop que nadie pide")
        }
    }

    @Test("las secciones de la segunda tanda decodifican: vacías si faltan, llenas si vienen")
    func secondBatchSections() throws {
        let empty = try JSONDecoder().decode(LoopsManifest.self, from: Data(#"{"schemaVersion":1}"#.utf8))
        #expect(empty.characters.isEmpty && empty.floors.isEmpty && empty.shopIcons.isEmpty)
        let json = #"""
        {"schemaVersion":1,"portraits":{},"objects":{},"cabin":{},"cinematics":{},
         "floors":{"urban":{"file":"floor_urban.mov","width":1024,"height":1024,"fps":24,"frames":120,
                            "alpha":false,"audio":false,"matte":null,"keyColor":null}},
         "characters":{"pasante":{"file":"char_pasante.mov","width":512,"height":512,"fps":24,"frames":121,
                       "alpha":true,"audio":false,"matte":"blanco","keyColor":null,"odrTag":"anim-piso-1"}},
         "algoNuevo":{}}
        """#
        let manifest = try JSONDecoder().decode(LoopsManifest.self, from: Data(json.utf8))
        #expect(manifest.entry(for: .floor("urban"))?.alpha == false)
        #expect(manifest.entry(for: .character("pasante"))?.odrTag == "anim-piso-1")
        #expect(manifest.url(for: .floor("urban")) == nil, "en el manifest pero sin archivo: póster")
    }

    @Test("sin entrada no hay video")
    func noEntryNoVideo() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(manifest.url(for: .portrait("npc_que_no_existe")) == nil)
        #expect(LoopsManifest.empty.url(for: .cinematic(.dios)) == nil)
    }
}
