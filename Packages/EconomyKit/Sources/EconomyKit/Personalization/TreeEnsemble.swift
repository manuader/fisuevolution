import Foundation

// MARK: - TreeEnsemble (2.1 E15 F6, contrato C1)
//
// El modelo de árboles que se entrena afuera (`Tools/player-value-model/train.py`) y se evalúa en el
// teléfono. Formato: arrays paralelos por nodo, nodo 0 = raíz, hoja ⇔ left == right == feature == -1.
// Rama: x < threshold → left; si no → right; NaN (o feature ausente) → default_left.
// Predicción = link(base_score + Σ hojas), con link `identity` o `expm1`.

public struct TreeEnsemble: Codable, Sendable, Equatable {
    public static let formatVersion = "tree-1"
    public static let maxTrees = 500
    public static let maxDepth = 8
    public static let maxBytes = 256 * 1024

    public enum Link: String, Codable, Sendable {
        case identity
        case expm1
    }

    public struct Tree: Codable, Sendable, Equatable {
        public let left: [Int]
        public let right: [Int]
        public let feature: [Int]
        public let threshold: [Double]
        public let defaultLeft: [Bool]
        public let value: [Double]

        public init(
            left: [Int], right: [Int], feature: [Int],
            threshold: [Double], defaultLeft: [Bool], value: [Double]
        ) {
            self.left = left
            self.right = right
            self.feature = feature
            self.threshold = threshold
            self.defaultLeft = defaultLeft
            self.value = value
        }

        var nodeCount: Int { left.count }

        func isLeaf(_ node: Int) -> Bool { left[node] == -1 }

        enum CodingKeys: String, CodingKey {
            case left, right, feature, threshold, value
            case defaultLeft = "default_left"
        }
    }

    public let version: String
    public let features: [String]
    public let baseScore: Double
    public let link: Link
    public let trees: [Tree]

    public init(version: String, features: [String], baseScore: Double, link: Link, trees: [Tree]) {
        self.version = version
        self.features = features
        self.baseScore = baseScore
        self.link = link
        self.trees = trees
    }

    enum CodingKeys: String, CodingKey {
        case version, features, link, trees
        case baseScore = "base_score"
    }

    /// Decodifica y valida: el único camino para cargar un modelo que viene de afuera.
    public static func load(from data: Data) throws -> TreeEnsemble {
        guard data.count <= maxBytes else { throw TreeEnsembleError.tooLarge(bytes: data.count) }
        let model: TreeEnsemble
        do {
            model = try JSONDecoder().decode(TreeEnsemble.self, from: data)
        } catch {
            throw TreeEnsembleError.malformed
        }
        try model.validate()
        return model
    }

    // MARK: Validación

    public func validate() throws {
        guard version == Self.formatVersion else { throw TreeEnsembleError.unsupportedVersion(version) }
        guard !features.isEmpty else { throw TreeEnsembleError.noFeatures }
        guard baseScore.isFinite else { throw TreeEnsembleError.nonFinite(tree: nil, node: nil) }
        guard !trees.isEmpty, trees.count <= Self.maxTrees else {
            throw TreeEnsembleError.treeCount(trees.count)
        }
        for (index, tree) in trees.enumerated() {
            try validate(tree, index: index)
        }
    }

    private func validate(_ tree: Tree, index: Int) throws {
        let count = tree.nodeCount
        guard count > 0,
              tree.right.count == count, tree.feature.count == count, tree.threshold.count == count,
              tree.defaultLeft.count == count, tree.value.count == count
        else { throw TreeEnsembleError.ragged(tree: index) }

        for node in 0..<count {
            let (l, r, f) = (tree.left[node], tree.right[node], tree.feature[node])
            if l == -1, r == -1, f == -1 {
                guard tree.value[node].isFinite else { throw TreeEnsembleError.nonFinite(tree: index, node: node) }
                continue
            }
            guard l >= 0, r >= 0, f >= 0 else { throw TreeEnsembleError.mixedNode(tree: index, node: node) }
            guard l < count, r < count, f < features.count else {
                throw TreeEnsembleError.indexOutOfRange(tree: index, node: node)
            }
            // Hijos siempre después del padre: con eso no puede haber ciclos.
            guard l > node, r > node else { throw TreeEnsembleError.cycle(tree: index, node: node) }
            guard tree.threshold[node].isFinite else { throw TreeEnsembleError.nonFinite(tree: index, node: node) }
        }

        // Cada nodo se alcanza desde la raíz exactamente una vez; de paso, la profundidad.
        var depth = [Int](repeating: -1, count: count)
        depth[0] = 0
        for node in 0..<count {
            guard depth[node] >= 0 else { throw TreeEnsembleError.unreachable(tree: index, node: node) }
            guard depth[node] <= Self.maxDepth else { throw TreeEnsembleError.tooDeep(tree: index) }
            guard !tree.isLeaf(node) else { continue }
            for child in [tree.left[node], tree.right[node]] {
                guard depth[child] == -1 else { throw TreeEnsembleError.sharedChild(tree: index, node: child) }
                depth[child] = depth[node] + 1
            }
        }
    }

    // MARK: Predicción

    /// Evalúa un vector en el orden de `features`. Lo que falta al final del vector cuenta como NaN.
    /// Presupone un modelo validado (`load(from:)` lo garantiza); el recorrido da a lo sumo un paso por nodo.
    public func predict(_ x: [Double]) -> Double {
        var margin = baseScore
        for tree in trees {
            margin += leafValue(tree, x)
        }
        switch link {
        case .identity: return margin
        case .expm1: return Foundation.expm1(margin)
        }
    }

    private func leafValue(_ tree: Tree, _ x: [Double]) -> Double {
        var node = 0
        for _ in 0..<tree.nodeCount {
            guard !tree.isLeaf(node) else { return tree.value[node] }
            let f = tree.feature[node]
            let v = f < x.count ? x[f] : .nan
            let goLeft = v.isNaN ? tree.defaultLeft[node] : v < tree.threshold[node]
            node = goLeft ? tree.left[node] : tree.right[node]
        }
        return tree.value[node]
    }
}

public enum TreeEnsembleError: Error, Equatable {
    case tooLarge(bytes: Int)
    case malformed
    case unsupportedVersion(String)
    case noFeatures
    case treeCount(Int)
    case ragged(tree: Int)
    case mixedNode(tree: Int, node: Int)
    case indexOutOfRange(tree: Int, node: Int)
    case cycle(tree: Int, node: Int)
    case unreachable(tree: Int, node: Int)
    case sharedChild(tree: Int, node: Int)
    case tooDeep(tree: Int)
    case nonFinite(tree: Int?, node: Int?)
}
