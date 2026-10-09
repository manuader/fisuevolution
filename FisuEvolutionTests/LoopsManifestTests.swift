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

    /// Un manifest en memoria que apunta pisos a `.mov` reales del bundle.
    static func fixture(floors: [String: String]) throws -> LoopsManifest {
        let entries = floors.map { id, file in
            #""\#(id)":{"file":"\#(file)","width":720,"height":1280,"fps":24,"frames":120,"alpha":false,"audio":false}"#
        }.joined(separator: ",")
        let json = #"{"schemaVersion":1,"floors":{\#(entries)}}"#
        return try JSONDecoder().decode(LoopsManifest.self, from: Data(json.utf8))
    }

    /// Como `fixture`, pero cada piso lleva su `odrTag`.
    static func fixture(floors: [String: String], odrTag: String) throws -> LoopsManifest {
        let entries = floors.map { id, file in
            #""\#(id)":{"file":"\#(file)","width":720,"height":1280,"fps":24,"frames":120,"alpha":false,"audio":false,"odrTag":"\#(odrTag)"}"#
        }.joined(separator: ",")
        let json = #"{"schemaVersion":1,"floors":{\#(entries)}}"#
        return try JSONDecoder().decode(LoopsManifest.self, from: Data(json.utf8))
    }

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

    @Test("las cuatro cinemáticas: 720×1280, opacas, con sonido")
    func cinematics() throws {
        let manifest = try LoopsManifest.load(from: .main)
        for id in [CinematicID.intro, .reencarnacion, .arresto, .dios] {
            let entry = try #require(manifest.cinematics[id.rawValue], "\(id.rawValue)")
            #expect(entry.file == "cine_\(id.rawValue).mov")
            #expect(entry.width == 720 && entry.height == 1280 && !entry.alpha && entry.audio)
            #expect(manifest.cinematicURL(for: id) != nil)
        }
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

    /// Los packs ODR de la segunda tanda, uno por familia; el pin de Python tiene el mismo cuadro.
    static let packs: Set<String> =
        Set((1...10).map { "anim-piso-\($0)" }).union(["anim-especiales", "anim-visitantes", "anim-eventos", "anim-tienda"])

    private func sections(of manifest: LoopsManifest) -> [(name: String, entries: [String: LoopsManifest.Entry])] {
        [("portraits", manifest.portraits), ("objects", manifest.objects), ("cabin", manifest.cabin),
         ("cinematics", manifest.cinematics), ("characters", manifest.characters),
         ("talking", manifest.talking), ("visitorActions", manifest.visitorActions),
         ("events", manifest.events), ("shopIcons", manifest.shopIcons), ("floors", manifest.floors)]
    }

    @Test("la segunda tanda: 53 personajes, 18 charlas, 8 pedidos, 8 eventos, 10 íconos, 10 fondos")
    func secondBatchCounts() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(manifest.characters.count == 53)
        #expect(Set(manifest.talking.keys) == Self.portraits)
        #expect(Set(manifest.visitorActions.keys) == Set(Self.portraits.filter { $0.hasPrefix("npc_") }))
        #expect(manifest.events.count == 8 && manifest.shopIcons.count == 10 && manifest.floors.count == 10)
        for entry in manifest.floors.values {
            #expect(entry.width == 1024 && entry.height == 1024 && !entry.alpha && entry.odrTag == nil)
        }
    }

    @Test("el odrTag es de la familia: lo pesado viaja en packs y lo base no lleva tag")
    func odrTagsByFamily() throws {
        let manifest = try LoopsManifest.load(from: .main)
        for name in ["portraits", "objects", "cabin", "cinematics", "floors"] {
            let entries = sections(of: manifest).first { $0.name == name }!.entries
            #expect(entries.values.allSatisfy { $0.odrTag == nil }, "\(name) va en el paquete base")
        }
        let family = ["talking": "anim-visitantes", "visitorActions": "anim-visitantes",
                      "events": "anim-eventos", "shopIcons": "anim-tienda"]
        for (name, tag) in family {
            let entries = sections(of: manifest).first { $0.name == name }!.entries
            #expect(entries.values.allSatisfy { $0.odrTag == tag }, "\(name)")
        }
        for (id, entry) in manifest.characters {
            let tag = try #require(entry.odrTag, "\(id)")
            #expect(id.hasPrefix("sp_") ? tag == "anim-especiales" : tag.hasPrefix("anim-piso-"), "\(id)")
        }
        let used = Set(manifest.characters.values.compactMap(\.odrTag))
        #expect(used.isSuperset(of: Self.packs.subtracting(["anim-visitantes", "anim-eventos", "anim-tienda"])))
    }

    @Test("cada file del manifest está en el bundle (o en su pack) y cada .mov del bundle está en el manifest")
    func manifestAndBundleAgree() throws {
        let manifest = try LoopsManifest.load(from: .main)
        let all = sections(of: manifest).flatMap(\.entries.values)
        let declared = all.map(\.file)
        #expect(declared.count == Set(declared).count, "dos entradas con el mismo archivo")
        for entry in all {
            if let tag = entry.odrTag {
                let pack = try #require(assetPack(for: tag), "\(tag): el pack no está embebido en el bundle de Debug")
                #expect(FileManager.default.fileExists(atPath: pack.appending(path: entry.file).path),
                        "\(entry.file): no está en el pack \(tag)")
                #expect(Bundle.main.url(forResource: entry.file, withExtension: nil) == nil,
                        "\(entry.file): con tag no puede estar también en el paquete base")
            } else {
                let name = entry.file as NSString
                let url = Bundle.main.url(forResource: name.deletingPathExtension, withExtension: name.pathExtension)
                #expect(url != nil, "\(entry.file): en el manifest y no en el bundle")
            }
        }
        let onDisk = try #require(Bundle.main.resourceURL)
        let movs = (FileManager.default.enumerator(at: onDisk, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension == "mov" }.map(\.lastPathComponent)
        let extra = Set(movs).subtracting(declared).subtracting(["chest_open.mov"])
        #expect(extra.isEmpty, "\(extra.sorted()): .mov en el bundle que el manifest no nombra")
    }

    /// Con `EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE` (Debug) cada pack es una carpeta `.assetpack`
    /// dentro de `OnDemandResources/`; se encuentra por el tag, no por el nombre del archivo.
    private func assetPack(for tag: String) -> URL? {
        guard let root = Bundle.main.resourceURL?.appending(path: "OnDemandResources"),
              let id = Bundle.main.bundleIdentifier else { return nil }
        let prefix = "\(id).\(tag)-"
        let packs = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return packs.first { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "assetpack" }
    }

    @Test("sin entrada no hay video")
    func noEntryNoVideo() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(manifest.url(for: .portrait("npc_que_no_existe")) == nil)
        #expect(LoopsManifest.empty.url(for: .cinematic(.dios)) == nil)
    }
}
