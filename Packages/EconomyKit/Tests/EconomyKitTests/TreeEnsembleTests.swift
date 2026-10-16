import Foundation
import Testing
@testable import EconomyKit

// MARK: - TreeEnsemble (2.1 F6 T1)
//
// Fixtures/tree_fixture.json está escrito a mano: 3 features, 3 árboles, base_score 0.5, link expm1.
//   Árbol 0: country_tier < 1.5 → 0.1 | si no: rewarded_count < 10 → 0.2 | si no → 0.5   (NaN: izq. / der.)
//   Árbol 1: device_tier < 2.5 → -0.05 | si no → 0.3                                     (NaN: der.)
//   Árbol 2: una sola hoja 0.01
// Fixtures/tree_fixture_cases.json repite los casos de abajo para `Tools/player-value-model/fixture.py`.

private func fixtureURL(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "Fixtures/\(name)")
}

private func fixtureModel() throws -> TreeEnsemble {
    try TreeEnsemble.load(from: Data(contentsOf: fixtureURL("tree_fixture.json")))
}

private func withLink(_ model: TreeEnsemble, _ link: TreeEnsemble.Link) -> TreeEnsemble {
    TreeEnsemble(
        version: model.version, features: model.features, baseScore: model.baseScore,
        link: link, trees: model.trees
    )
}

private func leaf(_ value: Double) -> TreeEnsemble.Tree {
    .init(left: [-1], right: [-1], feature: [-1], threshold: [0], defaultLeft: [true], value: [value])
}

/// Un tocón: raíz que parte por la feature 0 en 1.0, hojas -1 y +1.
private func stump(
    left: [Int] = [1, -1, -1], right: [Int] = [2, -1, -1], feature: [Int] = [0, -1, -1],
    threshold: [Double] = [1.0, 0, 0]
) -> TreeEnsemble.Tree {
    .init(
        left: left, right: right, feature: feature, threshold: threshold,
        defaultLeft: [true, true, true], value: [0, -1, 1]
    )
}

private func model(_ trees: [TreeEnsemble.Tree], features: [String] = ["a"], version: String = "tree-1")
    -> TreeEnsemble {
    TreeEnsemble(version: version, features: features, baseScore: 0, link: .identity, trees: trees)
}

private func isClose(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= 1e-12 * max(1, abs(b)) }

@Suite("TreeEnsemble: predicción del fixture")
struct TreeEnsemblePredictTests {
    @Test("el fixture carga y es válido")
    func fixtureLoads() throws {
        let m = try fixtureModel()
        #expect(m.features == ["country_tier", "device_tier", "rewarded_count"])
        #expect(m.trees.count == 3)
        #expect(m.link == .expm1)
        #expect(m.baseScore == 0.5)
    }

    @Test("izquierda en el árbol 0, izquierda en el árbol 1")
    func leftLeft() throws {
        let m = try withLink(fixtureModel(), .identity)
        #expect(isClose(m.predict([1, 2, 5]), 0.5 + 0.1 - 0.05 + 0.01))
    }

    @Test("derecha y luego izquierda en el árbol 0, derecha en el árbol 1")
    func rightLeft() throws {
        let m = try withLink(fixtureModel(), .identity)
        #expect(isClose(m.predict([2, 3, 5]), 0.5 + 0.2 + 0.3 + 0.01))
    }

    @Test("derecha y derecha en el árbol 0")
    func rightRight() throws {
        let m = try withLink(fixtureModel(), .identity)
        #expect(isClose(m.predict([2, 3, 20]), 0.5 + 0.5 + 0.3 + 0.01))
    }

    @Test("el umbral es estricto: igual al umbral va a la derecha")
    func thresholdIsStrict() throws {
        let m = try withLink(fixtureModel(), .identity)
        #expect(isClose(m.predict([1.5, 2.5, 10]), 0.5 + 0.5 + 0.3 + 0.01))
    }

    @Test("NaN sigue default_left en cada nodo")
    func nanFollowsDefault() throws {
        let m = try withLink(fixtureModel(), .identity)
        // Raíz del 0: NaN → izq. (0.1); árbol 1: NaN → der. (0.3).
        #expect(isClose(m.predict([.nan, .nan, .nan]), 0.5 + 0.1 + 0.3 + 0.01))
        // Nodo 2 del 0: NaN → der. (0.5).
        #expect(isClose(m.predict([2, .nan, .nan]), 0.5 + 0.5 + 0.3 + 0.01))
    }

    @Test("una feature que falta al final del vector cuenta como NaN")
    func missingTailIsNaN() throws {
        let m = try withLink(fixtureModel(), .identity)
        #expect(isClose(m.predict([1]), 0.5 + 0.1 + 0.3 + 0.01))
    }

    @Test("link expm1 se aplica a la suma")
    func expm1Link() throws {
        let m = try fixtureModel()
        #expect(isClose(m.predict([1, 2, 5]), Foundation.expm1(0.5 + 0.1 - 0.05 + 0.01)))
        #expect(isClose(m.predict([2, 3, 20]), Foundation.expm1(0.5 + 0.5 + 0.3 + 0.01)))
    }

    @Test("los casos compartidos con el script de Python dan lo mismo")
    func sharedCases() throws {
        struct Case: Decodable {
            let features: [Double?]
            let expected: Double
        }
        let data = try Data(contentsOf: fixtureURL("tree_fixture_cases.json"))
        let cases = try JSONDecoder().decode([Case].self, from: data)
        #expect(cases.count == 7)
        let m = try fixtureModel()
        for c in cases {
            let x = c.features.map { $0 ?? .nan }
            #expect(isClose(m.predict(x), c.expected), "x = \(c.features)")
        }
    }
}

@Suite("TreeEnsemble: validación")
struct TreeEnsembleValidationTests {
    @Test("un tocón y una hoja sola son válidos")
    func minimalIsValid() throws {
        try model([stump(), leaf(0.5)]).validate()
    }

    @Test("ciclo: un hijo que apunta a un nodo anterior es inválido")
    func cycleIsInvalid() {
        let looped = stump(left: [1, 2, -1], right: [2, 0, -1], feature: [0, 0, -1], threshold: [1, 1, 0])
        #expect(throws: TreeEnsembleError.cycle(tree: 0, node: 1)) { try model([looped]).validate() }
        let selfLoop = stump(left: [0, -1, -1])
        #expect(throws: TreeEnsembleError.cycle(tree: 0, node: 0)) { try model([selfLoop]).validate() }
    }

    @Test("índice de hijo fuera de rango es inválido")
    func childOutOfRange() {
        #expect(throws: TreeEnsembleError.indexOutOfRange(tree: 0, node: 0)) {
            try model([stump(left: [7, -1, -1])]).validate()
        }
    }

    @Test("índice de feature fuera de rango es inválido")
    func featureOutOfRange() {
        #expect(throws: TreeEnsembleError.indexOutOfRange(tree: 0, node: 0)) {
            try model([stump(feature: [1, -1, -1])]).validate()
        }
    }

    @Test("un hijo compartido por dos padres es inválido")
    func sharedChild() {
        let shared = TreeEnsemble.Tree(
            left: [1, 3, -1, -1], right: [2, 3, -1, -1], feature: [0, 0, -1, -1],
            threshold: [1, 1, 0, 0], defaultLeft: [true, true, true, true], value: [0, 0, 1, 2]
        )
        #expect(throws: TreeEnsembleError.sharedChild(tree: 0, node: 3)) { try model([shared]).validate() }
    }

    @Test("un nodo que no cuelga de la raíz es inválido")
    func orphan() {
        let orphan = TreeEnsemble.Tree(
            left: [-1, -1], right: [-1, -1], feature: [-1, -1],
            threshold: [0, 0], defaultLeft: [true, true], value: [1, 2]
        )
        #expect(throws: TreeEnsembleError.unreachable(tree: 0, node: 1)) { try model([orphan]).validate() }
    }

    @Test("un nodo mitad hoja, mitad interno es inválido")
    func mixedNode() {
        #expect(throws: TreeEnsembleError.mixedNode(tree: 0, node: 0)) {
            try model([stump(right: [-1, -1, -1])]).validate()
        }
    }

    @Test("arrays de distinto largo son inválidos")
    func ragged() {
        #expect(throws: TreeEnsembleError.ragged(tree: 1)) {
            try model([leaf(0), stump(threshold: [1, 0])]).validate()
        }
    }

    @Test("sin features, sin árboles o con otra versión es inválido")
    func emptyOrWrongVersion() {
        #expect(throws: TreeEnsembleError.noFeatures) { try model([leaf(0)], features: []).validate() }
        #expect(throws: TreeEnsembleError.treeCount(0)) { try model([]).validate() }
        #expect(throws: TreeEnsembleError.unsupportedVersion("tree-2")) {
            try model([leaf(0)], version: "tree-2").validate()
        }
    }

    @Test("tope de árboles: 500 pasa, 501 no")
    func treeCap() throws {
        try model(Array(repeating: leaf(0), count: 500)).validate()
        #expect(throws: TreeEnsembleError.treeCount(501)) {
            try model(Array(repeating: leaf(0), count: 501)).validate()
        }
    }

    @Test("tope de profundidad: 8 pasa, 9 no")
    func depthCap() throws {
        /// Una cadena: cada nodo interno i tiene hoja 2i+1 a la izquierda y sigue por 2i+2.
        func chain(depth: Int) -> TreeEnsemble.Tree {
            var left: [Int] = [], right: [Int] = [], feature: [Int] = []
            var node = 0
            for _ in 0..<depth {
                left.append(node + 1); right.append(node + 2); feature.append(0)
                left.append(-1); right.append(-1); feature.append(-1)
                node += 2
            }
            left.append(-1); right.append(-1); feature.append(-1)
            let n = left.count
            return .init(
                left: left, right: right, feature: feature,
                threshold: Array(repeating: 0, count: n), defaultLeft: Array(repeating: true, count: n),
                value: Array(repeating: 0, count: n)
            )
        }
        try model([chain(depth: 8)]).validate()
        #expect(throws: TreeEnsembleError.tooDeep(tree: 0)) { try model([chain(depth: 9)]).validate() }
    }

    @Test("umbral no finito es inválido")
    func nonFiniteThreshold() {
        #expect(throws: TreeEnsembleError.nonFinite(tree: 0, node: 0)) {
            try model([stump(threshold: [.infinity, 0, 0])]).validate()
        }
    }

    @Test("load rechaza más de 256 KB, JSON roto y link desconocido")
    func loadRejects() throws {
        let big = Data(repeating: 0x20, count: TreeEnsemble.maxBytes + 1)
        #expect(throws: TreeEnsembleError.tooLarge(bytes: TreeEnsemble.maxBytes + 1)) {
            try TreeEnsemble.load(from: big)
        }
        #expect(throws: TreeEnsembleError.malformed) { try TreeEnsemble.load(from: Data("{".utf8)) }
        let text = try String(contentsOf: fixtureURL("tree_fixture.json"), encoding: .utf8)
            .replacingOccurrences(of: "\"expm1\"", with: "\"softplus\"")
        #expect(throws: TreeEnsembleError.malformed) { try TreeEnsemble.load(from: Data(text.utf8)) }
    }

    @Test("load valida: un modelo decodificable pero roto no carga")
    func loadValidates() throws {
        let text = try String(contentsOf: fixtureURL("tree_fixture.json"), encoding: .utf8)
            .replacingOccurrences(of: "\"tree-1\"", with: "\"tree-0\"")
        #expect(throws: TreeEnsembleError.unsupportedVersion("tree-0")) {
            try TreeEnsemble.load(from: Data(text.utf8))
        }
    }
}
