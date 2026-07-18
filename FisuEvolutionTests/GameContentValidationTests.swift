import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Validates the real bundled content (the JSON that ships in the app).
@Suite("Bundled game content")
struct GameContentValidationTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test func tierTableHasExpectedShape() {
        #expect(content.tiers.types.count == 37)
        #expect(content.tiers.concreteTypes.count == 36)
        #expect(content.tiers.maxTier == 30)
        #expect(content.tiers.baseType.id == "homeless")
        #expect(content.tiers.terminalType.id == "god")
    }

    @Test func careerChoiceNodeIsWellFormed() throws {
        let junior = try #require(content.tiers.type(id: "junior"))
        #expect(junior.isChoiceNode)
        #expect(junior.choiceOptions?.count == 4)
        for option in junior.choiceOptions ?? [] {
            let resolved = try #require(content.tiers.type(id: option))
            #expect(resolved.tier == 9)
            #expect(resolved.isChoiceNode == false)
        }
    }

    /// Anti-drift: every number in tiers.json must equal the §3 formulas applied to
    /// economy.json. Hand-edited numbers break this on purpose.
    @Test func tierNumbersDeriveFromEconomyFormulas() {
        let economy = StandardEconomy(config: content.economy)
        for type in content.tiers.types {
            expectRelativelyEqual(type.tapYield, economy.tapYield(forTier: type.tier), context: "\(type.id).tapYield")
            expectRelativelyEqual(type.passiveYieldPerInstance, economy.passiveYield(forTier: type.tier), context: "\(type.id).passiveYield")
            expectRelativelyEqual(type.passiveUnlockCost, economy.passiveUnlockCost(forTier: type.tier), context: "\(type.id).unlockCost")
        }
    }

    @Test func economyConfigMatchesTunedValues() {
        // Valores del gate de balance F2 (ver Docs/balance-log.md), no los del
        // bible §3 literal: el sim demostró que 15/1.15/perType llega a God en 7 min.
        #expect(content.economy.yieldGrowthPerTier == 3.8)
        #expect(content.economy.spawn.baseCost == 50)
        #expect(content.economy.spawn.costGrowth == 1.022)
        #expect(content.economy.spawn.costBasis == .total)
        #expect(content.economy.offlineCapHours == 8)
        #expect(content.economy.board.cellCount == 35)
    }

    @Test func featureFlagsShipDisabled() {
        #expect(content.flags.gameCenterEnabled == false)
        #expect(content.flags.cloudKitEnabled == false)
        #expect(content.flags.useRealAds == false)
        #expect(content.flags.buildVariant == "dev")
    }

    @Test func manifestStartsEmptySoEverythingRendersPlaceholders() {
        #expect(content.manifest.characters.isEmpty)
        #expect(content.manifest.backgrounds.isEmpty)
        #expect(content.manifest.ui.isEmpty)
    }

    private func expectRelativelyEqual(_ actual: Double, _ expected: Double, context: String) {
        let tolerance = max(abs(expected), 1) * 1e-9
        #expect(abs(actual - expected) <= tolerance, "\(context): \(actual) != \(expected)")
    }
}
