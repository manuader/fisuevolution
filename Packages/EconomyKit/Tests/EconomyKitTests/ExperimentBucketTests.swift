import Foundation
import Testing
@testable import EconomyKit

// MARK: - 2.1 E15 F6 T2: el reparto A/B reglas contra modelo

@Suite("ExperimentBucket (2.1 F6)")
struct ExperimentBucketTests {
    private static let ids = (0..<10_000).map { "install-\($0)" }

    @Test("el mismo id con la misma sal cae siempre en el mismo balde, dentro de 0…99")
    func stableAndInRange() {
        for id in Self.ids.prefix(500) {
            let bucket = ExperimentBucket.bucket(installId: id, salt: "vej-1")
            #expect((0..<100).contains(bucket))
            #expect(ExperimentBucket.bucket(installId: id, salt: "vej-1") == bucket)
        }
    }

    @Test("el balde es SHA-256(\"sal:id\"): los primeros 8 bytes, módulo 100")
    func pinnedValues() {
        // Calculado aparte con hashlib (Python): el panel puede repetir el reparto del lado del servidor.
        #expect(ExperimentBucket.bucket(installId: "ABC", salt: "vej-1") == 15)
        #expect(ExperimentBucket.bucket(installId: "", salt: "vej-1") == 98)
    }

    @Test("uniforme: cada brazo y cada décimo dentro de ±3 puntos en 10.000 ids")
    func uniform() {
        let buckets = Self.ids.map { ExperimentBucket.bucket(installId: $0, salt: "vej-1") }
        for split in [10, 50, 90] {
            let model = buckets.filter { ExperimentBucket.arm(bucket: $0, split: split) == .model }.count
            let share = Double(model) / Double(buckets.count) * 100
            #expect(abs(share - Double(split)) <= 3, "split \(split): \(share) %")
        }
        for decile in 0..<10 {
            let share = Double(buckets.filter { $0 / 10 == decile }.count) / Double(buckets.count) * 100
            #expect(abs(share - 10) <= 3, "décimo \(decile): \(share) %")
        }
    }

    @Test("otra sal rebaraja el reparto")
    func saltReshuffles() {
        let a = Self.ids.map { ExperimentBucket.bucket(installId: $0, salt: "vej-1") }
        let b = Self.ids.map { ExperimentBucket.bucket(installId: $0, salt: "vej-2") }
        let moved = zip(a, b).filter { $0 != $1 }.count
        #expect(moved > 9_500, "con 100 baldes, ~99 % cambia de balde")
        let switchedArm = zip(a, b).filter {
            ExperimentBucket.arm(bucket: $0, split: 50) != ExperimentBucket.arm(bucket: $1, split: 50)
        }.count
        #expect((4_500...5_500).contains(switchedArm), "la mitad cambia de brazo: los repartos son independientes")
    }

    @Test("el brazo: 0..<split es modelo; el split se acota a 0…100")
    func arms() {
        #expect(ExperimentBucket.arm(bucket: 0, split: 10) == .model)
        #expect(ExperimentBucket.arm(bucket: 9, split: 10) == .model)
        #expect(ExperimentBucket.arm(bucket: 10, split: 10) == .rules)
        #expect(ExperimentBucket.arm(bucket: 99, split: 99) == .rules)
        #expect(ExperimentBucket.arm(bucket: 0, split: 0) == .rules, "con 0 nadie usa el modelo")
        #expect(ExperimentBucket.arm(bucket: 0, split: -5) == .rules)
        #expect(ExperimentBucket.arm(bucket: 99, split: 100) == .model)
        #expect(ExperimentBucket.arm(bucket: 99, split: 250) == .model)
    }
}
