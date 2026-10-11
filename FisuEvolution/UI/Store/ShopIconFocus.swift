/// Cuál de las filas visibles de la Tienda de ORO anima su ícono: la del medio (spec E8, "anima
/// sólo el que está centrado"). Si esa no tiene clip, la más cercana que sí; a igual distancia, la
/// de arriba.
enum ShopIconFocus {
    static func pick(visibleInOrder: [String], animatable: Set<String>) -> String? {
        guard !visibleInOrder.isEmpty else { return nil }
        let middle = (visibleInOrder.count - 1) / 2
        return visibleInOrder.enumerated()
            .filter { animatable.contains($0.element) }
            .min { lhs, rhs in
                let (left, right) = (abs(lhs.offset - middle), abs(rhs.offset - middle))
                return left == right ? lhs.offset < rhs.offset : left < right
            }?.element
    }
}
