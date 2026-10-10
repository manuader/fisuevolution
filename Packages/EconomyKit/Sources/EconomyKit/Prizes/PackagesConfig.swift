import Foundation

/// `packages.json`: el Paquete de la Aduana (PLAN-v2 E5 y §2). Cae uno cada
/// tanto de juego activo, hasta un tope en espera, y al tocarlo sortea a quién
/// trae entre lo que FisuJobs vende con lugar.
public struct PackagesConfig: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    /// Segundos de juego activo entre dos paquetes.
    public let spawnIntervalSeconds: Double
    /// El primero de una partida (o de un save anterior a E5).
    public let firstPackageAfterSeconds: Double
    /// Cuántos esperan como mucho. Los regalados (visitantes, ruleta, colchón,
    /// ofertas) pueden pasarlo: el tope es del reloj, no del buzón.
    public let maxWaiting: Int
    /// Cuántos tiers elegibles, desde el más alto, entran al sorteo.
    public let windowTiers: Int
    /// La razón r entre un tier y el de arriba (el de abajo pesa r veces más),
    /// por nivel del permanente "mejor proveedor" de la tienda de ORO (E6).
    public let tierRatioByBestSupplierLevel: [Double]

    public init(
        schemaVersion: Int,
        spawnIntervalSeconds: Double,
        firstPackageAfterSeconds: Double,
        maxWaiting: Int,
        windowTiers: Int,
        tierRatioByBestSupplierLevel: [Double]
    ) {
        self.schemaVersion = schemaVersion
        self.spawnIntervalSeconds = spawnIntervalSeconds
        self.firstPackageAfterSeconds = firstPackageAfterSeconds
        self.maxWaiting = maxWaiting
        self.windowTiers = windowTiers
        self.tierRatioByBestSupplierLevel = tierRatioByBestSupplierLevel
    }

    /// La razón de ese nivel; uno fuera de rango se queda en el borde.
    public func tierRatio(bestSupplierLevel: Int) -> Double {
        let index = min(max(0, bestSupplierLevel), tierRatioByBestSupplierLevel.count - 1)
        return tierRatioByBestSupplierLevel[index]
    }

    public enum ValidationError: Error, Equatable {
        case notPositive(String)
        case noRatios
        /// Una razón menor que 1 haría al tope MÁS probable que los de abajo.
        case ratioBelowOne(Double)
    }

    public func validate() throws {
        guard spawnIntervalSeconds > 0, spawnIntervalSeconds.isFinite else { throw ValidationError.notPositive("spawnIntervalSeconds") }
        guard firstPackageAfterSeconds > 0, firstPackageAfterSeconds.isFinite else { throw ValidationError.notPositive("firstPackageAfterSeconds") }
        guard maxWaiting > 0 else { throw ValidationError.notPositive("maxWaiting") }
        guard windowTiers > 0 else { throw ValidationError.notPositive("windowTiers") }
        guard !tierRatioByBestSupplierLevel.isEmpty else { throw ValidationError.noRatios }
        if let odd = tierRatioByBestSupplierLevel.first(where: { !$0.isFinite }) {
            throw ValidationError.notPositive("tierRatioByBestSupplierLevel \(odd)")
        }
        if let low = tierRatioByBestSupplierLevel.first(where: { $0 < 1 }) {
            throw ValidationError.ratioBelowOne(low)
        }
    }
}
