import Foundation
import Testing
@testable import EconomyKit

// MARK: - El bandido de Thompson con semilla (2.1 F3 T2)

@Suite("Bandido de Thompson")
struct ThompsonBanditTests {
    private let seed: UInt64 = 20_261_016

    private func pair() -> ThompsonBandit {
        ThompsonBandit(arms: [BanditArm(id: "good"), BanditArm(id: "bad")])
    }

    /// Juega `rounds` rondas contra tasas de éxito fijas; el éxito lo sortea
    /// otro generador, así el bandido y el mundo no comparten azar.
    private func play(
        _ bandit: inout ThompsonBandit,
        rates: [String: Double],
        rounds: Int,
        seed: UInt64
    ) -> [String] {
        var rng = SplitMix64(seed: seed)
        var world = SplitMix64(seed: seed ^ 0xAB_CDEF)
        var picks: [String] = []
        for _ in 0..<rounds {
            guard let pick = bandit.choose(eligible: Array(rates.keys), rng: &rng) else { continue }
            let success = Double.random(in: 0..<1, using: &world) < rates[pick, default: 0]
            bandit.observe(arm: pick, success: success)
            picks.append(pick)
        }
        return picks
    }

    @Test("el generador es SplitMix64: la semilla 0 da el primer número conocido")
    func splitMixMatchesTheReference() {
        var rng = SplitMix64(seed: 0)
        #expect(rng.next() == 0xE220_A839_7B1D_CDAF)
    }

    @Test("con la misma semilla, la misma secuencia de elecciones")
    func sameSeedSameChoices() {
        var first = pair()
        var second = pair()
        let rates = ["good": 0.6, "bad": 0.4]
        let a = play(&first, rates: rates, rounds: 200, seed: seed)
        let b = play(&second, rates: rates, rounds: 200, seed: seed)
        #expect(a == b)
        #expect(first == second)
        var other = pair()
        let c = play(&other, rates: rates, rounds: 200, seed: seed + 1)
        #expect(a != c)
    }

    @Test("con un brazo de 0,8 y otro de 0,2, después de 500 rondas el bueno sale más del 80 %")
    func learnsTheBetterArm() {
        var bandit = pair()
        let picks = play(&bandit, rates: ["good": 0.8, "bad": 0.2], rounds: 500, seed: seed)
        #expect(picks.count == 500)
        let share = Double(picks.filter { $0 == "good" }.count) / Double(picks.count)
        #expect(share > 0.8, "el bueno salió \(share)")
        #expect(bandit.arm("good")!.alpha > bandit.arm("bad")!.alpha)
    }

    @Test("con priors α = β = 1 y sin datos, reparte entre todos")
    func flatPriorsSpreadTheChoices() {
        let bandit = ThompsonBandit(arms: [BanditArm(id: "a"), BanditArm(id: "b"), BanditArm(id: "c")])
        var rng = SplitMix64(seed: seed)
        var counts: [String: Int] = [:]
        for _ in 0..<3_000 {
            if let pick = bandit.choose(eligible: ["a", "b", "c"], rng: &rng) {
                counts[pick, default: 0] += 1
            }
        }
        for id in ["a", "b", "c"] {
            let share = Double(counts[id, default: 0]) / 3_000
            #expect(share > 0.28 && share < 0.39, "\(id) salió \(share)")
        }
    }

    @Test("un brazo no elegible nunca sale, aunque sea el que mejor anda")
    func ineligibleArmNeverWins() {
        var bandit = ThompsonBandit(arms: [BanditArm(id: "star"), BanditArm(id: "plain")])
        for _ in 0..<200 { bandit.observe(arm: "star", success: true) }
        var rng = SplitMix64(seed: seed)
        for _ in 0..<1_000 {
            #expect(bandit.choose(eligible: ["plain"], rng: &rng) == "plain")
        }
        #expect(bandit.choose(eligible: [], rng: &rng) == nil)
        #expect(bandit.choose(eligible: ["ghost"], rng: &rng) == nil)
    }

    @Test("el de control es elegible siempre, esté o no en la lista")
    func controlIsAlwaysEligible() {
        let bandit = ThompsonBandit(arms: [
            BanditArm(id: "offer"),
            BanditArm(id: "control", isControl: true),
        ])
        var rng = SplitMix64(seed: seed)
        var picks = Set<String>()
        for _ in 0..<200 {
            if let pick = bandit.choose(eligible: ["offer"], rng: &rng) { picks.insert(pick) }
        }
        #expect(picks == ["offer", "control"])
        #expect(bandit.choose(eligible: [], rng: &rng) == "control")
    }

    @Test("observar suma un acierto a α o un fallo a β; un brazo desconocido no cambia nada")
    func observeUpdatesThePosterior() {
        var bandit = ThompsonBandit(arms: [BanditArm(id: "x", alpha: 2, beta: 3)])
        bandit.observe(arm: "x", success: true)
        bandit.observe(arm: "x", success: false)
        bandit.observe(arm: "x", success: false)
        #expect(bandit.arm("x") == BanditArm(id: "x", alpha: 3, beta: 5))
        let before = bandit
        bandit.observe(arm: "ghost", success: true)
        #expect(bandit == before)
    }

    @Test("un id repetido en la config queda una sola vez, el primero")
    func duplicateIdsKeepTheFirst() {
        let bandit = ThompsonBandit(arms: [BanditArm(id: "x", alpha: 4), BanditArm(id: "x", alpha: 9)])
        #expect(bandit.arms.count == 1)
        #expect(bandit.arm("x")?.alpha == 4)
    }

    @Test("una Beta con α o β en cero, negativo o NaN se trata como 1 y no explota")
    func invalidShapesCountAsOne() {
        for (alpha, beta) in [(0.0, 1.0), (1.0, -3.0), (-1.0, 0.0), (Double.nan, 1.0), (1.0, Double.infinity)] {
            var odd = SplitMix64(seed: seed)
            var flat = SplitMix64(seed: seed)
            let sample = ThompsonBandit.sampleBeta(alpha: alpha, beta: beta, rng: &odd)
            let expected = ThompsonBandit.sampleBeta(alpha: 1, beta: 1, rng: &flat)
            #expect(sample == expected, "α \(alpha), β \(beta)")
            #expect(sample >= 0 && sample <= 1)
        }
        let arm = BanditArm(id: "x", alpha: 0, beta: -2)
        #expect(arm.alpha == 1 && arm.beta == 1)
        let bandit = ThompsonBandit(arms: [arm])
        var rng = SplitMix64(seed: seed)
        #expect(bandit.choose(eligible: ["x"], rng: &rng) == "x")
    }

    @Test("la media muestral de la Beta queda a ±0,02 de la teórica en 10.000 muestras", arguments: [
        (2.0, 5.0), (1.0, 1.0), (0.5, 0.5), (30.0, 70.0), (0.3, 4.0),
    ])
    func betaMeanMatches(alpha: Double, beta: Double) {
        var rng = SplitMix64(seed: seed)
        var sum = 0.0
        var outOfRange = 0
        for _ in 0..<10_000 {
            let sample = ThompsonBandit.sampleBeta(alpha: alpha, beta: beta, rng: &rng)
            if !(0...1).contains(sample) { outOfRange += 1 }
            sum += sample
        }
        #expect(outOfRange == 0)
        let mean = sum / 10_000
        let expected = alpha / (alpha + beta)
        #expect(abs(mean - expected) < 0.02, "Beta(\(alpha), \(beta)): \(mean) contra \(expected)")
    }

    @Test("el bandido va y vuelve por JSON igual")
    func codableRoundTrip() throws {
        var bandit = ThompsonBandit(arms: [BanditArm(id: "a"), BanditArm(id: "control", isControl: true)])
        bandit.observe(arm: "a", success: true)
        let data = try JSONEncoder().encode(bandit)
        #expect(try JSONDecoder().decode(ThompsonBandit.self, from: data) == bandit)
    }
}
