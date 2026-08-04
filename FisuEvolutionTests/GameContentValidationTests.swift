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

    /// Anti-drift: every number in tiers.json must equal the F7 formulas applied to
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
        // Pins de la calibración FINAL de economy.json v2 (F7 "La Torre").
        // Si tuneás la economía, actualizá estos pins A PROPÓSITO — el drift
        // silencioso del JSON es exactamente el bug que este test caza.
        let economy = content.economy
        #expect(economy.schemaVersion == 2)
        #expect(economy.baseTapYieldTier1 == 1)
        #expect(economy.yieldGrowthPerTier == 2.8)
        #expect(economy.passiveRatio == 0.5)
        #expect(economy.passiveUnlockCostMultiplier == 60)
        #expect(economy.hire.defaultCostMultiplier == 3000)
        #expect(economy.hire.defaultCostGrowth == 1.15)
        #expect(economy.charUpgrades.baseCostMultiplier == 50)
        #expect(economy.charUpgrades.costGrowth == 4.0)
        #expect(economy.charUpgrades.effectFactorPerLevel == 2.0)
        #expect(economy.oro.divisor == 3_000_000)
        #expect(economy.oro.exponent == 0.5)
        #expect(economy.oro.globalMultiplierPerOro == 0.12)
        #expect(economy.critChanceBase == 0.0)
        #expect(economy.critMultiplier == 5.0)
        #expect(economy.offlineEfficiencyBase == 0.35)
        #expect(economy.offlineCapHours == 10)
    }

    @Test func floorHireOverridesMatchTunedValues() {
        // Overrides por piso de la calibración final: alley barato para arrancar
        // (50/15), corporate y luxury con multiplicador propio; TODO el resto
        // cae al default global punitivo (3000/1.15). Un override que aparezca
        // en otro piso es drift, no tuning.
        for floor in content.floorTable.floors {
            switch floor.id {
            case "alley":
                #expect(floor.hireCostMultiplierOverride == 50)
                #expect(floor.hireCostGrowthOverride == 15)
            case "corporate":
                #expect(floor.hireCostMultiplierOverride == 1800)
                #expect(floor.hireCostGrowthOverride == nil)
            case "luxury":
                #expect(floor.hireCostMultiplierOverride == 9000)
                #expect(floor.hireCostGrowthOverride == nil)
            default:
                #expect(floor.hireCostMultiplierOverride == nil, "override de hire inesperado en \(floor.id)")
                #expect(floor.hireCostGrowthOverride == nil, "override de growth inesperado en \(floor.id)")
            }
            // v2 no overridea unlockTier: todo piso se desbloquea con su firstTier.
            #expect(floor.unlockTierOverride == nil, "unlockTier inesperado en \(floor.id)")
        }
    }

    @Test func towerFloorsMatchCalibratedLayout() throws {
        // Layout FINAL de La Torre: 11 pisos data-driven, del callejón al reino
        // divino, capacity 10 en todos e income estrictamente creciente.
        let expected: [(id: String, tiers: ClosedRange<Int>, income: Double)] = [
            ("alley", 1...2, 1.0),
            ("urban", 3...5, 2.0),
            ("corporate", 6...9, 3.6),
            ("luxury", 10...13, 7.0),
            ("island", 14...17, 13.0),
            ("moon", 18...21, 25.0),
            ("mars", 22...23, 48.0),
            ("solar", 24...25, 90.0),
            ("galaxy", 26...27, 170.0),
            ("cosmic", 28...29, 325.0),
            ("god_realm", 30...30, 620.0),
        ]
        let table = content.floorTable
        try #require(table.count == expected.count)
        for (floor, pin) in zip(table.floors, expected) {
            #expect(floor.id == pin.id)
            #expect(floor.firstTier == pin.tiers.lowerBound, "\(pin.id).firstTier")
            #expect(floor.lastTier == pin.tiers.upperBound, "\(pin.id).lastTier")
            #expect(floor.capacity == 10, "\(pin.id).capacity")
            expectRelativelyEqual(floor.incomeMultiplier, pin.income, context: "\(pin.id).incomeMultiplier")
        }
        // Estrictamente creciente: un piso más alto SIEMPRE rinde más.
        for (lower, upper) in zip(table.floors, table.floors.dropFirst()) {
            #expect(lower.incomeMultiplier < upper.incomeMultiplier, "income no crece de \(lower.id) a \(upper.id)")
        }
        // Cobertura exacta 1...maxTier, sin huecos ni solapes. FloorTable ya lo
        // valida en su init; esto es anti-regresión por si esa validación se relaja.
        #expect(table.floors.first?.firstTier == 1)
        for (lower, upper) in zip(table.floors, table.floors.dropFirst()) {
            #expect(upper.firstTier == lower.lastTier + 1, "hueco o solape entre \(lower.id) y \(upper.id)")
        }
        #expect(table.floors.last?.lastTier == content.tiers.maxTier)
    }

    /// Todo fondo referenciado por un piso tiene que tener arte en el manifest
    /// (el loader ya lo exige al arrancar; acá queda documentado como contrato).
    @Test func floorBackgroundsExistInManifest() {
        for floor in content.floorTable.floors {
            #expect(
                content.manifest.backgrounds[floor.background] != nil,
                "piso \(floor.id): fondo \(floor.background) sin entrada en manifest.backgrounds"
            )
        }
    }

    @Test func featureFlagsShipDisabled() {
        #expect(content.flags.gameCenterEnabled == false)
        #expect(content.flags.cloudKitEnabled == false)
        #expect(content.flags.useRealAds == false)
        #expect(content.flags.buildVariant == "dev")
    }

    /// El arte entra por tandas: cada entrada del manifest debe apuntar a un
    /// tipo real; los tipos sin entrada renderizan placeholder (regla de oro).
    @Test func manifestEntriesReferenceRealTypes() {
        // Una entrada de personaje debe apuntar a un tier real O a un special
        // real (los specials tienen arte propio en specials.atlas, no son tiers).
        let specialIds = Set(content.specials.specials.map(\.id))
        for (typeId, asset) in content.manifest.characters {
            let isReal = content.tiers.type(id: typeId) != nil || specialIds.contains(typeId)
            #expect(isReal, "manifest huérfano: \(typeId)")
            #expect(!asset.key.isEmpty)
            #expect(!asset.atlas.isEmpty)
        }
    }

    private func expectRelativelyEqual(_ actual: Double, _ expected: Double, context: String) {
        let tolerance = max(abs(expected), 1) * 1e-9
        #expect(abs(actual - expected) <= tolerance, "\(context): \(actual) != \(expected)")
    }
}
