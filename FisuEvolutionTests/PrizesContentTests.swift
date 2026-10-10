import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los números del Paquete, el Colchón y la Ruleta tal como quedaron en el dato
/// (PLAN-v2 E5 y §2; la tabla de premios de E2a).
@Suite("Paquete, colchón y ruleta: el contenido real")
struct PrizesContentTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("el paquete: uno cada 2 min de juego, hasta 2, ventana de 4 tiers y el tope al 6,7 %")
    func packages() {
        let packages = content.packages
        #expect(packages.spawnIntervalSeconds == 120)
        #expect(packages.maxWaiting == 2)
        #expect(packages.windowTiers == 4)
        #expect(packages.tierRatioByBestSupplierLevel == [2, 1.8, 1.6, 1.4])
        let ladder = content.tiers.concreteTypes.filter { $0.tier <= 4 }
        let top = PackageRoller.odds(eligible: ladder, windowTiers: packages.windowTiers, ratio: packages.tierRatio(bestSupplierLevel: 0))[0]
        #expect(top.probability > 0.05 && top.probability < 0.08, "§2: el tope sale ~5–8 %")
    }

    @Test("el colchón: cada 8 min de juego, uno solo, y plata 20 min / un Paquete / 2 ORO")
    func treasures() {
        let treasures = content.treasures
        #expect(treasures.spawnIntervalSeconds == 480)
        #expect(treasures.extraOpensPerTreasure == 1)
        #expect(treasures.prizes.map(\.id) == ["coins", "package", "oro"])
        #expect(treasures.prizes[0].rewards == [.coinsSeconds(1200)])
        #expect(treasures.prizes[1].rewards == [.package(1)])
        #expect(treasures.prizes[2].rewards == [.oro(2)])
    }

    @Test("la ruleta: 10 segmentos que suman 100, 6 por video, 12 ORO con tope 6 y 3,8 s de giro")
    func wheel() {
        let wheel = content.wheel
        #expect(wheel.segments.count == 10)
        #expect(wheel.segments.map(\.weight).reduce(0, +) == 100)
        #expect(wheel.videoSpinsPerDay == 6)
        #expect(wheel.oroSpinCost == 12)
        #expect(wheel.oroSpinsPerDay == 6)
        #expect(wheel.spinSeconds == 3.8)
    }

    @Test("la ruleta da lo que dice E2a: plata 30–60 min, ×2/×3/×5 por 10 min, ORO 1–3, paquete y cofre")
    func wheelPrizes() {
        var kinds: Set<RewardSpec.Kind> = []
        for segment in content.wheel.segments {
            kinds.insert(segment.reward.kind)
            switch segment.reward {
            case .coinsSeconds(let seconds):
                #expect((1800...3600).contains(seconds), "\(segment.id): \(seconds) s")
            case let .modifier(effect, magnitude, seconds):
                #expect(effect == .incomeMultiplier)
                #expect([2, 3, 5].contains(magnitude))
                #expect(seconds == 600)
            case .oro(let amount):
                #expect((1...3).contains(amount))
            case .package(let count), .skinChest(let count):
                #expect(count == 1)
            default:
                Issue.record("\(segment.id): la ruleta no da \(segment.reward.kind)")
            }
        }
        #expect(kinds == [.coinsSeconds, .modifier, .oro, .package, .skinChest])
        #expect(content.wheel.chestFallbackSegmentId == "coins_30")
    }

    @Test("el arranque rechaza una ruleta que no suma 100")
    func loaderRejectsABrokenWheel() throws {
        let fileManager = FileManager.default
        let bundleURL = fileManager.temporaryDirectory.appending(path: "e5-\(UUID().uuidString).bundle")
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: bundleURL) }
        for url in Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [] {
            try fileManager.copyItem(at: url, to: bundleURL.appending(path: url.lastPathComponent))
        }
        let wheelURL = bundleURL.appending(path: "wheel.json")
        var wheel = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: wheelURL)) as? [String: Any])
        var segments = try #require(wheel["segments"] as? [[String: Any]])
        segments[0]["weight"] = 1
        wheel["segments"] = segments
        try JSONSerialization.data(withJSONObject: wheel).write(to: wheelURL)
        let bundle = try #require(Bundle(url: bundleURL))

        #expect {
            _ = try GameContentLoader.load(from: bundle)
        } throws: { error in
            guard case .contentInvalid(let file, let reason)? = error as? GameError else { return false }
            return file == "wheel.json" && reason.contains("weightsMustSumTo100")
        }
    }

    @Test("el validador rechaza lo que no es finito, además de lo que no es positivo")
    func validatorsRejectNonFiniteValues() {
        let real = content.packages
        func packages(interval: Double = 120, ratios: [Double] = [2]) -> PackagesConfig {
            PackagesConfig(
                schemaVersion: 1, spawnIntervalSeconds: interval, firstPackageAfterSeconds: 120,
                maxWaiting: real.maxWaiting, windowTiers: real.windowTiers, tierRatioByBestSupplierLevel: ratios
            )
        }
        #expect(throws: PackagesConfig.ValidationError.self) { try packages(interval: .infinity).validate() }
        #expect(throws: PackagesConfig.ValidationError.self) { try packages(interval: .nan).validate() }
        #expect(throws: PackagesConfig.ValidationError.self) { try packages(ratios: [.infinity]).validate() }

        let treasures = content.treasures
        let endless = TreasuresConfig(
            schemaVersion: 1, spawnIntervalSeconds: .infinity, firstTreasureAfterSeconds: 480,
            extraOpensPerTreasure: 1, prizes: treasures.prizes
        )
        #expect(throws: TreasuresConfig.ValidationError.self) { try endless.validate() }
        let endlessPrize = TreasuresConfig(
            schemaVersion: 1, spawnIntervalSeconds: 480, firstTreasureAfterSeconds: 480, extraOpensPerTreasure: 1,
            prizes: [.init(id: "coins", weight: 1, rewards: [.coinsSeconds(.infinity)])]
        )
        #expect(throws: TreasuresConfig.ValidationError.self) { try endlessPrize.validate() }

        let wheel = content.wheel
        let endlessSpin = WheelConfig(
            schemaVersion: 1, videoSpinsPerDay: wheel.videoSpinsPerDay, oroSpinCost: wheel.oroSpinCost,
            oroSpinsPerDay: wheel.oroSpinsPerDay, spinSeconds: .infinity,
            chestFallbackSegmentId: wheel.chestFallbackSegmentId, segments: wheel.segments
        )
        #expect(throws: WheelConfig.ValidationError.self) { try endlessSpin.validate() }
        #expect(throws: RewardSpec.ValidationError.self) { try RewardSpec.coinsSeconds(.infinity).validate() }
        #expect(throws: RewardSpec.ValidationError.self) {
            try RewardSpec.modifier(effect: .incomeMultiplier, magnitude: .infinity, seconds: 600).validate()
        }
    }
}
