import EconomyKit
import Testing

/// E14 C17: dos personajes cambian de lugar en la escalera. Lo que vale por la
/// POSICIÓN (unidades, mejoras, contrataciones, vistos) pasa al que ahora ocupa
/// ese lugar; lo que es del PERSONAJE (sus pintas) se queda con él.
@Suite("TierSwap")
struct TierSwapTests {
    private func stateWithBoth() -> PlayerState {
        var state = fxState(units: ["a": 2, "x": 3, "y": 1])
        state.run.passiveUnlocked = ["a": true, "x": true]
        state.run.hireCountsByType = ["x": 4, "y": 1.5]
        state.run.charUpgradeLevels = ["x": 7, "a": 1]
        state.run.seenTypes = ["a", "x"]
        state.run.hireCounts = ["f2": 9]
        state.meta.quickHirePinnedTypeId = "x"
        state.meta.activeSkinByType = ["x": "pinta_de_x", "y": "pinta_de_y"]
        state.meta.milestoneSkins = ["pinta_de_x"]
        state.meta.engagement.sharedMoments = ["character.x"]
        return state
    }

    @Test("lo que vale por la posición pasa al que ahora ocupa ese lugar")
    func positionalFieldsSwap() {
        let swapped = stateWithBoth().swappingTierPositions(of: "x", and: "y")

        #expect(swapped.run.units == ["a": 2, "y": 3, "x": 1])
        #expect(swapped.run.passiveUnlocked == ["a": true, "y": true])
        #expect(swapped.run.hireCountsByType == ["y": 4, "x": 1.5])
        #expect(swapped.run.charUpgradeLevels == ["y": 7, "a": 1])
        #expect(swapped.run.seenTypes == ["a", "y"])
        #expect(swapped.meta.quickHirePinnedTypeId == "y")
    }

    @Test("las pintas siguen al personaje, y lo que no es de ninguno de los dos no se toca")
    func characterFieldsStay() {
        let original = stateWithBoth()
        let swapped = original.swappingTierPositions(of: "x", and: "y")

        #expect(swapped.meta.activeSkinByType == original.meta.activeSkinByType)
        #expect(swapped.meta.allOwnedSkins == original.meta.allOwnedSkins)
        #expect(swapped.meta.engagement == original.meta.engagement)
        #expect(swapped.run.hireCounts == original.run.hireCounts, "por piso, no por personaje")
        #expect(swapped.run.maxTierReached == original.run.maxTierReached)
        #expect(swapped.run.revealedTier == original.run.revealedTier)
        #expect(swapped.run.coins == original.run.coins)
        #expect(swapped.schemaVersion == original.schemaVersion, "estampar la versión es del migrador")
    }

    @Test("sin ninguno de los dos en el save, el intercambio no cambia nada")
    func unrelatedSaveIsUntouched() {
        let original = fxState(units: ["a": 2])
        #expect(original.swappingTierPositions(of: "x", and: "y") == original)
    }

    @Test("intercambiar dos veces vuelve al save original: por eso lo corre UNA vez el migrador")
    func swapIsAnInvolution() {
        let original = stateWithBoth()
        let twice = original.swappingTierPositions(of: "x", and: "y").swappingTierPositions(of: "x", and: "y")
        #expect(twice == original)
    }
}
