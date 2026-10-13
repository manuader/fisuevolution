import Foundation
import Testing
import UIKit
@testable import FisuEvolution

/// El arte aprobado de E14 (C4, C8, C15, C26, C27) integrado por T3: cada id existe en su
/// manifest y carga de verdad (imagen con píxeles, `.mov` en el bundle). Las pantallas que lo
/// muestran son de T17–T20; acá sólo se prueba que se encuentra por su id.
@Suite("Arte de premios integrado (E14 T3)")
@MainActor
struct PremiosArtIntegradoTests {
    /// Las 26 imágenes de `ui.atlas`. Pineadas LITERALES: son los ids que consumen
    /// `RewardKind`, `GameGlyph` y las pantallas de T17–T20.
    static let uiKeys: [String] = [
        "rw_arrest", "rw_boost_refresh", "rw_coins", "rw_evolve", "rw_exchange", "rw_fine",
        "rw_free_unit", "rw_frozen", "rw_hire_discount", "rw_income_mult", "rw_mattress_treasure",
        "rw_mystery_all", "rw_package_employee", "rw_tap_mult",
        "ui_dolar_blue", "ui_icon_check", "ui_icon_clock", "ui_icon_lock", "ui_icon_video",
        "ui_offer_bienvenida", "ui_offer_mudanza", "ui_offer_renacer",
        "ui_rail_mattress", "ui_rail_merge_all", "ui_rail_package", "ui_rail_wheel",
    ]

    /// Los 11 clips, con su matte y los cuadros que dura cada uno a 24 fps.
    static let clips: [String: (matte: String, frames: Int)] = [
        "cofre_espera": ("blanco", 97), "cofre_sacude": ("blanco", 24), "cofre_abre": ("verde", 73),
        "ruleta_espera": ("blanco", 97), "ruleta_premio": ("verde", 48),
        "paquete_espera": ("blanco", 97), "paquete_sacude": ("blanco", 24), "paquete_abre": ("verde", 73),
        "colchon_espera": ("blanco", 97), "colchon_sacude": ("blanco", 24), "colchon_abre": ("blanco", 73),
    ]

    @Test("las 26 imágenes de ui.atlas están en el manifest y cargan con píxeles")
    func uiImagesLoad() throws {
        let manifest = try GameContentLoader.load(from: .main).manifest
        #expect(Set(Self.uiKeys).count == 26)
        for key in Self.uiKeys {
            #expect(manifest.ui[key] == key, "\(key): sin entrada en assets_manifest")
            let image = try #require(UIArt.uiImage(key), "\(key): en el manifest pero no carga del atlas")
            #expect(image.size.width > 1 && image.size.height > 1, "\(key)")
        }
    }

    @Test("el Vendedor enojado está en el atlas de visitantes y carga")
    func angryVendorLoads() throws {
        let manifest = try GameContentLoader.load(from: .main).manifest
        #expect(manifest.npcs?["npc_vendedor_enojado"] == "npc_vendedor_enojado")
        #expect(UIArt.characterImage(atlas: "npcs", key: "npc_vendedor_enojado") != nil)
    }

    @Test("cada premio ilustrado resuelve su imagen de E14, ya no el disco de respaldo")
    func rewardKindsResolveTheirNewArt() {
        let expected: [RewardKind: String] = [
            .coins: "rw_coins", .incomeBoost: "rw_income_mult", .tapBoost: "rw_tap_mult",
            .hireDiscount: "rw_hire_discount", .boostRefresh: "rw_boost_refresh", .evolve: "rw_evolve",
            .freeUnit: "rw_free_unit", .exchange: "rw_exchange", .fine: "rw_fine", .arrest: "rw_arrest",
            .frozen: "rw_frozen", .blue: "ui_dolar_blue", .mystery: "rw_mystery_all",
            .mattressTreasure: "rw_mattress_treasure",
        ]
        for (kind, key) in expected {
            #expect(kind.resolvedArtKey == key, "\(kind)")
        }
    }

    @Test("los glifos generales y las ofertas resuelven su imagen de E14")
    func glyphsResolveTheirNewArt() {
        #expect(GameGlyph.video.resolvedArtKey == "ui_icon_video")
        #expect(GameGlyph.clock.resolvedArtKey == "ui_icon_clock")
        #expect(GameGlyph.lock.resolvedArtKey == "ui_icon_lock")
        #expect(GameGlyph.check.resolvedArtKey == "ui_icon_check")
        #expect(GameGlyph.blue.resolvedArtKey == "ui_dolar_blue")
        #expect(GameGlyph.offerMoving.resolvedArtKey == "ui_offer_mudanza")
        #expect(GameGlyph.offerWelcome.resolvedArtKey == "ui_offer_bienvenida")
        #expect(GameGlyph.offerRebirth.resolvedArtKey == "ui_offer_renacer")
    }

    @Test("los 11 clips de cofre, Ruleta, caja y Colchón están en objects, en el bundle y con su duración")
    func objectClipsLoad() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(Set(manifest.objects.keys) == Set(Self.clips.keys))
        for (id, expected) in Self.clips {
            let entry = try #require(manifest.objects[id], "\(id)")
            #expect(entry.file == "obj_\(id).mov", "\(id)")
            #expect(entry.frames == expected.frames, "\(id)")
            #expect(entry.fps == 24, "\(id)")
            #expect(manifest.url(for: .object(id)) != nil, "\(id): en el manifest pero no en el bundle")
        }
        // Las sacudidas duran 1 s y el festejo de la Ruleta, 2 s.
        for id in ["cofre_sacude", "paquete_sacude", "colchon_sacude"] {
            #expect(manifest.objects[id]?.frames == 24, "\(id)")
        }
        #expect(manifest.objects["ruleta_premio"]?.frames == 48)
    }
}
