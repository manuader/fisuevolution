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

// MARK: - Skins de oro (2026-08-19)

/// El oro NO se vende: la única vía es tener todas las mejoras permanentes al
/// tope. El diamante es al revés — sin condición de milestone, sólo el bundle.
@Suite("Skins de material")
struct SkinsDeMaterialTests {
    private func catalogo() -> SkinsConfig {
        SkinsConfig(schemaVersion: 1, skins: [
            .init(id: "oro", characterType: "homeless", treatment: .texture,
                  textureKey: "homeless_idle__oro", upgradesMaxed: true),
            .init(id: "oro", characterType: "ceo", treatment: .texture,
                  textureKey: "ceo_idle__oro", upgradesMaxed: true),
            .init(id: "diamante", characterType: "homeless", treatment: .texture,
                  textureKey: "homeless_idle__diamante"),
        ])
    }

    @Test("el mismo id se repite por personaje sin romper la validación")
    func idCompartidoEntrePersonajes() throws {
        try catalogo().validate(
            characterTypeIDs: ["homeless", "ceo"], floorIDs: []
        )
    }

    @Test("dos entradas del MISMO personaje con el mismo id siguen siendo un error")
    func idDuplicadoEnUnPersonaje() {
        let roto = SkinsConfig(schemaVersion: 1, skins: [
            .init(id: "oro", characterType: "ceo", treatment: .texture, textureKey: "a"),
            .init(id: "oro", characterType: "ceo", treatment: .texture, textureKey: "b"),
        ])
        #expect(throws: SkinsConfig.ValidationError.duplicateID("oro")) {
            try roto.validate(characterTypeIDs: ["ceo"], floorIDs: [])
        }
    }

    @Test("el oro entra sólo con todas las mejoras al máximo")
    func oroPideMejorasAlMaximo() {
        let state = fxState()
        #expect(SkinMilestones.newlyUnlocked(
            state: state, config: catalogo(), allUpgradesMaxed: false) == [])
        #expect(SkinMilestones.newlyUnlocked(
            state: state, config: catalogo(), allUpgradesMaxed: true) == ["oro", "oro"])
    }

    @Test("el diamante nunca sale por milestone: es sólo del bundle")
    func diamanteNoEsMilestone() {
        let diamante = catalogo().skins.first { $0.id == "diamante" }
        #expect(diamante?.isMilestone == false)
        #expect(!SkinMilestones.newlyUnlocked(
            state: fxState(), config: catalogo(), allUpgradesMaxed: true
        ).contains("diamante"))
    }
}
