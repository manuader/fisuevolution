import Foundation
import Testing
@testable import FisuEvolution

@Suite("La Tienda de ORO anima sólo el ícono del medio")
@MainActor
struct ShopIconFocusTests {
    private func pick(_ visible: [String], animatable: Set<String>? = nil) -> String? {
        ShopIconFocus.pick(visibleInOrder: visible, animatable: animatable ?? Set(visible))
    }

    @Test("sin filas visibles no hay foco")
    func empty() {
        #expect(pick([]) == nil)
    }

    @Test("una fila: es la foco")
    func single() {
        #expect(pick(["a"]) == "a")
    }

    @Test("impar: la del medio; par: la de arriba del par central")
    func middle() {
        #expect(pick(["a", "b", "c"]) == "b")
        #expect(pick(["a", "b"]) == "a")
        #expect(pick(["a", "b", "c", "d"]) == "b")
        #expect(pick(["a", "b", "c", "d", "e"]) == "c")
    }

    @Test("el del medio sin clip cede al más cercano con clip; a igual distancia, el de arriba")
    func nearestAnimatable() {
        #expect(pick(["a", "b", "c"], animatable: ["a", "c"]) == "a")
        #expect(pick(["a", "b", "c", "d", "e"], animatable: ["d"]) == "d")
        #expect(pick(["a", "b", "c", "d", "e"], animatable: ["a", "e"]) == "a")
    }

    @Test("ninguno con clip: no hay foco")
    func noneAnimatable() {
        #expect(pick(["a", "b"], animatable: []) == nil)
    }

    @Test("cada ítem de oro_shop.json con clip en la tabla tiene su clip en el manifest")
    func tableResolves() throws {
        let manifest = try LoopsManifest.load(from: .main)
        let content = try GameContentLoader.load(from: .main)
        let resolved = content.oroShop.items.filter { ArtClips.shopIcon(item: $0.id, in: manifest) != nil }
        #expect(resolved.count == ArtClips.shopIconKeys.count)
    }
}
