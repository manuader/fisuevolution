import Testing
import UIKit
@testable import FisuEvolution

/// Un fondo que no carga no rompe nada: `FloorNode` cae a dos colores planos.
/// Por eso no alcanza con que esté en el manifest (`floorBackgroundsExistInManifest`).
@Suite("Los fondos de los pisos")
@MainActor
struct BackgroundArtTests {
    private let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("cada piso tiene un fondo que carga")
    func everyFloorBackgroundLoads() throws {
        for floor in content.floorTable.floors {
            let name = try #require(content.manifest.backgrounds[floor.background], "\(floor.id)")
            #expect(UIImage(named: name) != nil, "\(floor.id): \(name) no carga")
        }
    }

    @Test("los fondos de la 2.0 miden 2048")
    func backgroundsAre2048() throws {
        for (stage, name) in content.manifest.backgrounds {
            let image = try #require(UIImage(named: name), "\(stage)")
            #expect(image.size.width * image.scale >= 2048, "\(stage): \(image.size.width * image.scale) px")
        }
    }
}
