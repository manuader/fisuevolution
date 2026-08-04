import Testing
@testable import EconomyKit

@Suite("Skins data-driven")
struct SkinMilestonesTests {
    @Test func awardsEachEligibleMilestoneOnce() throws {
        let config = SkinsConfig(
            schemaVersion: 1,
            skins: [
                .init(
                    id: "golden", characterType: "*", treatment: .tint,
                    tintHex: "#FFD93D", textureKey: nil,
                    floorReached: nil, reincarnations: nil
                ),
                .init(
                    id: "urban_trailblazer", characterType: "b", treatment: .texture,
                    tintHex: nil, textureKey: "b__urban_trailblazer",
                    floorReached: "f2", reincarnations: nil
                ),
                .init(
                    id: "second_life", characterType: "a", treatment: .texture,
                    tintHex: nil, textureKey: "a__second_life",
                    floorReached: nil, reincarnations: 2
                ),
            ]
        )
        var state = fxState()
        state.run.unlockedFloors = ["f1", "f2"]
        state.meta.prestigeLevel = 2

        #expect(SkinMilestones.newlyUnlocked(state: state, config: config) == ["urban_trailblazer", "second_life"])

        state.meta.milestoneSkins = ["urban_trailblazer"]
        #expect(SkinMilestones.newlyUnlocked(state: state, config: config) == ["second_life"])
    }

    @Test func validationRejectsUnknownCharacterAndFloorReferences() {
        let config = SkinsConfig(
            schemaVersion: 1,
            skins: [
                .init(
                    id: "bad", characterType: "missing", treatment: .texture,
                    tintHex: nil, textureKey: "missing__bad",
                    floorReached: "missing_floor", reincarnations: nil
                ),
            ]
        )

        #expect(throws: SkinsConfig.ValidationError.unknownCharacterType("missing")) {
            try config.validate(characterTypeIDs: ["a"], floorIDs: ["f1"])
        }
    }
}
