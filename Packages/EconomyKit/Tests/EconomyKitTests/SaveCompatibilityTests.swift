import Foundation
import Testing
@testable import EconomyKit

// MARK: - Compatibilidad del save v4: una clave nueva jamás borra una partida
//
// El Codable sintetizado de Swift NO respeta los valores por defecto de las
// propiedades: exige toda clave que no sea opcional. Un save v4 ya escrito en el
// device del jugador no tiene las claves que agregamos después, así que sin
// decoders a mano el decode tira `keyNotFound`, el repositorio cae a "starting
// fresh" y la partida se pierde. Estos tests son el candado.

@Suite("Compatibilidad del save v4")
struct SaveCompatibilityTests {
    @Test("un save v4 sin las claves nuevas decodifica con defaults")
    func v4SinClavesNuevasDecodifica() throws {
        let data = try JSONSerialization.data(withJSONObject: fixtureV4SinClavesNuevas())
        let state = try JSONDecoder().decode(PlayerState.self, from: data)

        // Lo que el save SÍ traía llega intacto (el decoder a mano no se come nada).
        #expect(state.schemaVersion == 4)
        #expect(state.run.coins == 123_456.5)
        #expect(state.run.units == ["a": 3, "b": 2])
        #expect(state.run.passiveUnlocked == ["a": true])
        #expect(state.run.chosenCareerPath == "c_prog")
        #expect(state.run.hireCounts == ["f1": 4])
        #expect(state.run.maxTierReached == 3)
        #expect(state.run.charUpgradeLevels == ["a": 2])
        #expect(state.run.unlockedFloors == ["f1", "f2"])
        #expect(state.run.activeModifiers.count == 1)
        #expect(state.run.activeModifiers.first?.sourceKey == "boost.mate")
        #expect(state.meta.lifetimeEarnings == 7_500_000)
        #expect(state.meta.oro == 12)
        #expect(state.meta.stats.maxFloorOrdinalEver == 7)

        // Lo que no traía cae a su default en vez de tirar keyNotFound.
        #expect(state.run.seenTypes.isEmpty)
        #expect(state.run.hireCountsByType.isEmpty)
        #expect(state.meta.stats.totalMergesEver == 0)
        #expect(state.meta.stats.totalHiresEver == 0)
        #expect(state.meta.stats.totalTapsEver == 0)
        #expect(state.meta.stats.videosWatchedEver == 0)
        #expect(state.meta.stats.boostsActivatedEver == 0)
        #expect(state.meta.unlockedAchievements.isEmpty)
        #expect(state.meta.claimedAchievements.isEmpty)
        #expect(state.meta.rewardedActivations.isEmpty)
        #expect(state.meta.creditedPurchases.isEmpty)
    }

    @Test("un save v4 guardado antes de elegir carrera decodifica con carrera nil")
    func v4SinCarreraDecodifica() throws {
        // `chosenCareerPath` es opcional: el encoder omite la clave cuando es nil,
        // así que el decoder a mano no puede exigirla.
        var object = fixtureV4SinClavesNuevas()
        var run = try #require(object["run"] as? [String: Any])
        run["chosenCareerPath"] = nil
        object["run"] = run

        let data = try JSONSerialization.data(withJSONObject: object)
        let state = try JSONDecoder().decode(PlayerState.self, from: data)
        #expect(state.run.chosenCareerPath == nil)
    }

    @Test("round trip: los campos nuevos sobreviven encode → decode")
    func roundTripConservaLosCamposNuevos() throws {
        var state = PlayerState.newGame(
            startTypeId: "a", startFloorId: "f1",
            offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 1000
        )
        state.run.seenTypes = ["a", "b"]
        state.run.hireCountsByType = ["a": 3, "b": 1]
        state.meta.stats = MetaStats(
            maxFloorOrdinalEver: 4,
            totalMergesEver: 111,
            totalHiresEver: 22,
            totalTapsEver: 3333,
            videosWatchedEver: 5,
            boostsActivatedEver: 6
        )
        state.meta.unlockedAchievements = ["ach_primer_merge", "ach_piso_2"]
        state.meta.claimedAchievements = ["ach_primer_merge"]

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PlayerState.self, from: data)

        #expect(decoded == state)
        #expect(decoded.run.hireCountsByType == ["a": 3, "b": 1])
        #expect(decoded.meta.stats.totalMergesEver == 111)
        #expect(decoded.meta.stats.totalHiresEver == 22)
        #expect(decoded.meta.stats.totalTapsEver == 3333)
        #expect(decoded.meta.stats.videosWatchedEver == 5)
        #expect(decoded.meta.stats.boostsActivatedEver == 6)
        #expect(decoded.meta.unlockedAchievements == ["ach_primer_merge", "ach_piso_2"])
        #expect(decoded.meta.claimedAchievements == ["ach_primer_merge"])
    }

    @Test("reencarnar borra las compras por tipo de la run")
    func freshRunEmpiezaSinComprasPorTipo() {
        // `hireCountsByType` es curva de costo de ESTA run: reencarnar la resetea.
        let run = RunState.fresh(startTypeId: "a", startFloorId: "f1")
        #expect(run.hireCountsByType.isEmpty)
    }
}

/// Un v4 tal como lo escribió una versión anterior del juego: sin `seenTypes`,
/// sin `hireCountsByType`, sin `rewardedActivations` ni `creditedPurchases`, sin
/// los contadores nuevos de `stats` y sin los logros.
private func fixtureV4SinClavesNuevas() -> [String: Any] {
    [
        "schemaVersion": 4,
        "run": [
            "coins": 123_456.5,
            "units": ["a": 3, "b": 2],
            "passiveUnlocked": ["a": true],
            "chosenCareerPath": "c_prog",
            "hireCounts": ["f1": 4],
            "maxTierReached": 3,
            "charUpgradeLevels": ["a": 2],
            "unlockedFloors": ["f1", "f2"],
            "activeModifiers": [
                [
                    "id": "11111111-2222-3333-4444-555555555555",
                    "effect": "tapMultiplier",
                    "magnitude": 2.0,
                    "expiresAt": 1_900_000_000.0,
                    "sourceKey": "boost.mate",
                ] as [String: Any],
            ],
        ] as [String: Any],
        "meta": [
            "lifetimeEarnings": 7_500_000.0,
            "oro": 12,
            "oroEarnedLifetime": 12,
            "prestigeLevel": 2,
            "oroUpgradeLevels": ["offline": 2],
            "derivedEffects": [
                "offlineEfficiency": 0.5,
                "tapMultiplier": 2.0,
                "critChance": 0.25,
                "incomeMultiplier": 1.5,
                "goldenChance": 0.125,
                "spawnDiscount": 0.25,
                "prestigeBonus": 0.5,
            ],
            "globalMultiplier": 2.5,
            "ownedSpecials": ["sp_cryptobro"],
            "specialAnchors": [String: String](),
            "ownedSkins": ["skin_gold"],
            "milestoneSkins": [String](),
            "activeSkinByType": ["a": "skin_gold"],
            "removedAds": true,
            "boostActivations": ["mate": 1_690_000_000.0],
            "daily": ["lastClaimDay": "2026-07-30", "cycleDay": 4] as [String: Any],
            "sharesCompleted": 3,
            "lastSeenTimestamp": 1_750_000_000.0,
            "stats": ["maxFloorOrdinalEver": 7],
        ] as [String: Any],
    ]
}
