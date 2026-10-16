import Foundation

/// Un brazo del bandido: una oferta posible con lo que se sabe de ella como
/// `Beta(α, β)` (α − 1 aciertos y β − 1 fallos sobre el prior). El de control
/// no muestra nada: está para medir qué pasa cuando no se ofrece.
public struct BanditArm: Sendable, Equatable, Codable {
    public let id: String
    public private(set) var alpha: Double
    public private(set) var beta: Double
    public let isControl: Bool

    public init(id: String, alpha: Double = 1, beta: Double = 1, isControl: Bool = false) {
        self.id = id
        self.alpha = ThompsonBandit.usableShape(alpha)
        self.beta = ThompsonBandit.usableShape(beta)
        self.isControl = isControl
    }

    mutating func record(success: Bool) {
        if success {
            alpha += 1
        } else {
            beta += 1
        }
    }
}

/// El bandido de Thompson (2.1 F3 C2): para elegir, saca una muestra de la
/// Beta de cada brazo elegible y se queda con la mayor; después anota si salió
/// bien. El azar entra de afuera, así con una semilla la secuencia se repite.
public struct ThompsonBandit: Sendable, Equatable, Codable {
    /// Los brazos en el orden de la config: con muestras iguales gana el primero.
    public private(set) var arms: [BanditArm]

    public init(arms: [BanditArm]) {
        var seen = Set<String>()
        self.arms = arms.filter { seen.insert($0.id).inserted }
    }

    public func arm(_ id: String) -> BanditArm? {
        arms.first { $0.id == id }
    }

    /// El brazo elegido entre `eligible`, o `nil` si no queda ninguno. El de
    /// control es elegible siempre, esté o no en la lista; un id que el bandido
    /// no conoce no cuenta.
    public func choose<R: RandomNumberGenerator>(eligible: [String], rng: inout R) -> String? {
        let allowed = Set(eligible)
        var best: (id: String, sample: Double)?
        for arm in arms where arm.isControl || allowed.contains(arm.id) {
            let sample = Self.sampleBeta(alpha: arm.alpha, beta: arm.beta, rng: &rng)
            if sample > best?.sample ?? -.infinity {
                best = (arm.id, sample)
            }
        }
        return best?.id
    }

    /// Anota el resultado de una vez que salió `arm`. Un id desconocido no hace nada.
    public mutating func observe(arm id: String, success: Bool) {
        guard let index = arms.firstIndex(where: { $0.id == id }) else { return }
        arms[index].record(success: success)
    }

    // MARK: - Muestreo

    /// Una muestra de `Beta(α, β)` como cociente de dos Gamma. Un parámetro que
    /// no sirve (cero, negativo, infinito o NaN) cuenta como 1.
    public static func sampleBeta<R: RandomNumberGenerator>(alpha: Double, beta: Double, rng: inout R) -> Double {
        let x = sampleGamma(shape: usableShape(alpha), rng: &rng)
        let y = sampleGamma(shape: usableShape(beta), rng: &rng)
        let total = x + y
        guard total > 0, total.isFinite else { return 0.5 }
        return x / total
    }

    /// Una muestra de `Gamma(shape, 1)` por Marsaglia-Tsang. Con forma menor a
    /// 1 se sortea con forma + 1 y se corrige por `u^(1/forma)`.
    static func sampleGamma<R: RandomNumberGenerator>(shape: Double, rng: inout R) -> Double {
        if shape < 1 {
            return sampleGamma(shape: shape + 1, rng: &rng) * pow(unitOpen(&rng), 1 / shape)
        }
        let d = shape - 1.0 / 3.0
        let c = 1 / (9 * d).squareRoot()
        while true {
            let x = standardNormal(&rng)
            var v = 1 + c * x
            guard v > 0 else { continue }
            v = v * v * v
            let u = unitOpen(&rng)
            if u < 1 - 0.0331 * x * x * x * x {
                return d * v
            }
            if log(u) < 0.5 * x * x + d * (1 - v + log(v)) {
                return d * v
            }
        }
    }

    static func usableShape(_ value: Double) -> Double {
        value > 0 && value.isFinite ? value : 1
    }

    /// Un uniforme en (0, 1), sin los bordes: el logaritmo de cero no existe.
    private static func unitOpen<R: RandomNumberGenerator>(_ rng: inout R) -> Double {
        (Double(rng.next() >> 11) + 0.5) * 0x1p-53
    }

    /// Una normal estándar por Box-Muller.
    private static func standardNormal<R: RandomNumberGenerator>(_ rng: inout R) -> Double {
        let u1 = unitOpen(&rng)
        let u2 = unitOpen(&rng)
        return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }
}
