import CryptoKit
import Foundation

/// El reparto A/B estable por instalación (2.1 E15 F6): reglas contra modelo. El mismo `installId`
/// con la misma sal cae siempre en el mismo balde; cambiar la sal rebaraja a todos.
public enum ExperimentBucket {
    public static let bucketCount = 100

    public enum Arm: String, Sendable, Equatable, CaseIterable {
        case rules
        case model
    }

    /// `0…99`: los primeros 8 bytes de `SHA-256("<salt>:<installId>")` como entero, módulo 100.
    public static func bucket(installId: String, salt: String) -> Int {
        let digest = SHA256.hash(data: Data("\(salt):\(installId)".utf8))
        let prefix = digest.prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        return Int(prefix % UInt64(bucketCount))
    }

    /// `split` = porcentaje de instalaciones en el brazo modelo (se acota a 0…100): los baldes
    /// `0..<split` van al modelo, el resto a las reglas. Con 0 nadie usa el modelo.
    public static func arm(bucket: Int, split: Int) -> Arm {
        let cut = min(bucketCount, max(0, split))
        return (0..<cut).contains(bucket) ? .model : .rules
    }
}
