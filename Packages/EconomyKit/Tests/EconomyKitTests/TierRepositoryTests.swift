import Foundation
import Testing
@testable import EconomyKit

private func type(
    _ id: String,
    tier: Int,
    mergesInto: String? = nil,
    isChoiceNode: Bool = false,
    choiceOptions: [String]? = nil
) -> CharacterType {
    CharacterType(
        id: id,
        tier: tier,
        phase: .earth,
        displayName: id,
        spritePlaceholder: "sf:person.fill",
        spriteAssetKey: nil,
        tapYield: 1,
        passiveYieldPerInstance: 0.3,
        passiveUnlockCost: 100,
        mergesInto: mergesInto,
        isChoiceNode: isChoiceNode,
        choiceOptions: choiceOptions
    )
}

@Suite("TierRepository validation")
struct TierRepositoryTests {
    @Test func acceptsValidLinearChain() throws {
        let repo = try TierRepository(types: [
            type("a", tier: 1, mergesInto: "b"),
            type("b", tier: 2, mergesInto: "c"),
            type("c", tier: 3),
        ])
        #expect(repo.baseType.id == "a")
        #expect(repo.terminalType.id == "c")
        #expect(repo.maxTier == 3)
    }

    @Test func acceptsChoiceNodeExpandingToTerminal() throws {
        let repo = try TierRepository(types: [
            type("a", tier: 1, mergesInto: "choice"),
            type("choice", tier: 2, isChoiceNode: true, choiceOptions: ["left", "right"]),
            type("left", tier: 2, mergesInto: "end"),
            type("right", tier: 2, mergesInto: "end"),
            type("end", tier: 3),
        ])
        #expect(repo.terminalType.id == "end")
        #expect(repo.concreteTypes.count == 4)
    }

    @Test func rejectsDuplicateIds() {
        #expect(throws: TierValidationError.duplicateId("a")) {
            try TierRepository(types: [type("a", tier: 1, mergesInto: "a"), type("a", tier: 2)])
        }
    }

    @Test func rejectsBrokenMergeTarget() {
        #expect(throws: TierValidationError.unresolvedMergeTarget(from: "a", target: "ghost")) {
            try TierRepository(types: [type("a", tier: 1, mergesInto: "ghost"), type("b", tier: 2)])
        }
    }

    @Test func rejectsNonConsecutiveMerge() {
        #expect(throws: TierValidationError.nonConsecutiveMerge(from: "a", target: "c")) {
            try TierRepository(types: [
                type("a", tier: 1, mergesInto: "c"),
                type("b", tier: 2, mergesInto: "c"),
                type("c", tier: 3),
            ])
        }
    }

    @Test func rejectsTwoTerminals() {
        #expect(throws: TierValidationError.self) {
            try TierRepository(types: [
                type("a", tier: 1, mergesInto: "b"),
                type("b", tier: 2),
                type("dead", tier: 1),
            ])
        }
    }

    @Test func rejectsChoiceNodeWithoutOptions() {
        #expect(throws: TierValidationError.malformedChoiceNode("choice")) {
            try TierRepository(types: [
                type("a", tier: 1, mergesInto: "choice"),
                type("choice", tier: 2, isChoiceNode: true, choiceOptions: []),
            ])
        }
    }

    @Test func rejectsMissingTierInLadder() {
        #expect(throws: TierValidationError.missingTier(2)) {
            try TierRepository(types: [
                type("a", tier: 1, mergesInto: "c"),
                type("c", tier: 3),
            ])
        }
    }
}
