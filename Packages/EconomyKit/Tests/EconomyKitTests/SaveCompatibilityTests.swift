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
        // Los tres del cofre y el de la run: `SaveMigrator` los escribe al pasar
        // a v5, pero acá se decodifica el blob crudo y tienen que caer a cero
        // igual — un sobre recortado no puede costar la partida.
        #expect(state.meta.chestsPending == 0)
        #expect(state.meta.prestigeChestsPending == 0)
        #expect(state.meta.welcomeChestGiven == false)
        #expect(state.run.floorChestsAwarded == 0)
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
        state.run.floorChestsAwarded = 2
        state.meta.chestsPending = 3
        state.meta.prestigeChestsPending = 1
        state.meta.welcomeChestGiven = true

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
        #expect(decoded.run.floorChestsAwarded == 2)
        #expect(decoded.meta.chestsPending == 3)
        #expect(decoded.meta.prestigeChestsPending == 1)
        #expect(decoded.meta.welcomeChestGiven == true)
    }

    /// ⚠️ El agujero que quedaba abierto era de v3, no de v4.
    /// `SaveMigrator.migrate` entra por `case 3` derecho a `migrateV3toV4`, que
    /// **no** pasa por el backfill de `migrateV2toV3` y copia `upgrades` tal
    /// cual. Un v3 pre-expansión —con las tres claves originales y ninguna de
    /// las cuatro que llegaron después— tiraba `keyNotFound` y se llevaba puesta
    /// la partida entera.
    @Test("un dict de upgrades con sólo las 3 claves originales decodifica con defaults")
    func upgradesV3PreExpansionDecodifica() throws {
        var object = fixtureV4SinClavesNuevas()
        var meta = try #require(object["meta"] as? [String: Any])
        meta["derivedEffects"] = [
            "offlineEfficiency": 0.6,
            "tapMultiplier": 3.0,
            "critChance": 0.2,
        ] as [String: Any]
        object["meta"] = meta

        let data = try JSONSerialization.data(withJSONObject: object)
        let state = try JSONDecoder().decode(PlayerState.self, from: data)

        // Lo que el v3 SÍ traía llega intacto.
        #expect(state.meta.derivedEffects.offlineEfficiency == 0.6)
        #expect(state.meta.derivedEffects.tapMultiplier == 3.0)
        #expect(state.meta.derivedEffects.critChance == 0.2)
        // Las cuatro de v3 caen a su neutro en vez de reventar.
        #expect(state.meta.derivedEffects.incomeMultiplier == 1.0)
        #expect(state.meta.derivedEffects.goldenChance == 0)
        #expect(state.meta.derivedEffects.spawnDiscount == 0)
        #expect(state.meta.derivedEffects.prestigeBonus == 0)
        // Y el resto de la partida sobrevive, que es de lo que se trata.
        #expect(state.run.coins == 123_456.5)
        #expect(state.meta.oro == 12)
    }

    /// El caso extremo del mismo camino: `migrateV3toV4` hace
    /// `old["upgrades"] as? [String: Any] ?? [:]`, así que un v3 SIN la clave
    /// llega acá como diccionario vacío. Tampoco puede costar la partida.
    @Test("un dict de upgrades vacío decodifica entero con defaults")
    func upgradesVacioDecodifica() throws {
        var object = fixtureV4SinClavesNuevas()
        var meta = try #require(object["meta"] as? [String: Any])
        meta["derivedEffects"] = [String: Any]()
        object["meta"] = meta

        let data = try JSONSerialization.data(withJSONObject: object)
        let state = try JSONDecoder().decode(PlayerState.self, from: data)

        #expect(state.meta.derivedEffects == UpgradeState(
            offlineEfficiency: 0, tapMultiplier: 1.0, critChance: 0
        ))
        #expect(state.run.units == ["a": 3, "b": 2])
    }

    /// Y el escalón siguiente: el sobre SIN la clave `derivedEffects`. No lo
    /// produce ninguna migración de hoy —`migrateV3toV4` siempre escribe la
    /// clave, aunque sea con `{}`— pero sí un v4 escrito por otra versión o un
    /// blob recortado, y hasta acá se llevaba la partida entera con un
    /// `keyNotFound`. Son efectos DERIVADOS: la fuente de verdad
    /// (`oroUpgradeLevels`) sobrevive al lado y `recomputeDerivedEffects` los
    /// reconstruye, así que caer al neutro es recuperable y perder el save no.
    @Test("un save v4 sin la clave derivedEffects decodifica con el neutro")
    func metaSinDerivedEffectsDecodifica() throws {
        var object = fixtureV4SinClavesNuevas()
        var meta = try #require(object["meta"] as? [String: Any])
        meta["derivedEffects"] = nil
        object["meta"] = meta

        let data = try JSONSerialization.data(withJSONObject: object)
        let state = try JSONDecoder().decode(PlayerState.self, from: data)

        // El neutro es el MISMO que sale de decodificar `{}`.
        #expect(state.meta.derivedEffects == UpgradeState(
            offlineEfficiency: 0, tapMultiplier: 1.0, critChance: 0
        ))
        // La fuente de verdad de esos efectos llega intacta: se pueden recalcular.
        #expect(state.meta.oroUpgradeLevels == ["offline": 2])
        // Y el resto de la partida sobrevive, que es de lo que se trata.
        #expect(state.run.coins == 123_456.5)
        #expect(state.run.units == ["a": 3, "b": 2])
        #expect(state.meta.oro == 12)
        #expect(state.meta.prestigeLevel == 2)
    }

    @Test("reencarnar borra las compras por tipo de la run")
    func freshRunEmpiezaSinComprasPorTipo() {
        // `hireCountsByType` es curva de costo de ESTA run: reencarnar la resetea.
        let run = RunState.fresh(startTypeId: "a", startFloorId: "f1")
        #expect(run.hireCountsByType.isEmpty)
        // Y los cofres que pagó la torre: volver a subirla vuelve a pagar, que
        // es justo lo que empuja a reencarnar.
        #expect(run.floorChestsAwarded == 0)
    }

    // MARK: - Save v6 (la 2.0)

    /// Un sobre v5 tal como lo escribe la v1: sin ninguna clave de la 2.0.
    private func v5Blob(maxTier: Int) throws -> Data {
        var state = fxState()
        state.run.raiseFrontier(to: maxTier)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var run = try #require(object["run"] as? [String: Any])
        var meta = try #require(object["meta"] as? [String: Any])
        var stats = try #require(meta["stats"] as? [String: Any])
        for key in ["revealedTier", "priceRelief"] { run.removeValue(forKey: key) }
        for key in ["oroPurchases", "revokedPurchases", "purchasedOroReconstructed", "lastRunMaxTier",
                    "quickHirePinnedTypeId", "unlockedTabs", "engagement", "ranking"] { meta.removeValue(forKey: key) }
        stats.removeValue(forKey: "oroSpentEver")
        meta["stats"] = stats
        object["run"] = run
        object["meta"] = meta
        object["schemaVersion"] = 5
        return try JSONSerialization.data(withJSONObject: object)
    }

    @Test("un sobre sin los campos de la 2.0 decodifica con defaults seguros")
    func v5BlobDecodesWithSafeDefaults() throws {
        let decoded = try JSONDecoder().decode(PlayerState.self, from: v5Blob(maxTier: 4))
        #expect(decoded.run.revealedTier == 4, "nunca una lluvia de revelaciones al actualizar")
        #expect(decoded.run.priceRelief == 1)
        #expect(decoded.meta.oroPurchasedLifetime == 0)
        #expect(decoded.meta.purchasedOroReconstructed, "sin el migrador no se reconstruye")
        #expect(decoded.meta.lastRunMaxTier == 0)
        #expect(decoded.meta.quickHirePinnedTypeId == nil)
        #expect(decoded.meta.unlockedTabs.isEmpty)
        #expect(decoded.meta.engagement == .initial)
        #expect(decoded.meta.ranking == .legacy)
        #expect(decoded.meta.stats.oroSpentEver == 0)
    }

    @Test("un engagement vacío o con claves de una versión futura decodifica como el inicial")
    func engagementDecodesLeniently() throws {
        for engagement in [[String: Any](), ["visitor": ["id": "x"]] as [String: Any]] {
            var object = try #require(
                JSONSerialization.jsonObject(with: JSONEncoder().encode(fxState())) as? [String: Any]
            )
            var meta = try #require(object["meta"] as? [String: Any])
            meta["engagement"] = engagement
            object["meta"] = meta
            let decoded = try JSONDecoder().decode(
                PlayerState.self, from: JSONSerialization.data(withJSONObject: object)
            )
            #expect(decoded.meta.engagement == .initial)
        }
    }

    @Test("una cuenta nueva nace en v6, sin nada que reconstruir ni pestañas heredadas")
    func newGameIsV6() {
        let state = fxState()
        #expect(PlayerState.currentSchemaVersion == 6)
        #expect(state.schemaVersion == 6)
        #expect(state.run.revealedTier == 1)
        #expect(state.run.priceRelief == 1)
        #expect(state.meta.purchasedOroReconstructed)
        #expect(state.meta.oroPurchasedLifetime == 0)
        #expect(state.meta.lastRunMaxTier == 0)
        #expect(state.meta.quickHirePinnedTypeId == nil)
        #expect(state.meta.unlockedTabs.isEmpty)
        #expect(state.meta.engagement == .initial)
        #expect(state.meta.stats.oroSpentEver == 0)
    }

    @Test("round trip: los campos de la 2.0 sobreviven encode → decode")
    func roundTripKeepsTheV6Fields() throws {
        var state = fxState()
        state.run.raiseFrontier(to: 3)
        state.run.revealedTier = 2
        state.run.priceRelief = 0.75
        state.meta.recordOroPurchase(transactionID: "tx_550", amount: 550)
        state.meta.purchasedOroReconstructed = false
        state.meta.lastRunMaxTier = 4
        state.meta.quickHirePinnedTypeId = "b"
        state.meta.unlockedTabs = ["jobs", "gifts"]
        state.meta.stats.oroSpentEver = 30

        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(state))

        #expect(decoded == state)
        #expect(decoded.run.revealedTier == 2, "la red de seguridad no se pisa con maxTierReached")
        #expect(decoded.run.priceRelief == 0.75)
        #expect(decoded.meta.oroPurchasedLifetime == 550)
        #expect(!decoded.meta.purchasedOroReconstructed)
        #expect(decoded.meta.lastRunMaxTier == 4)
        #expect(decoded.meta.quickHirePinnedTypeId == "b")
        #expect(decoded.meta.unlockedTabs == ["jobs", "gifts"])
        #expect(decoded.meta.stats.oroSpentEver == 30)
    }

    @Test("los contadores de compra fraccionarios sobreviven encode → decode")
    func fractionalPurchaseCountersRoundTrip() throws {
        var state = fxState()
        state.run.hireCounts = ["f1": 2.4, "f2": 7]
        state.run.hireCountsByType = ["a": 1.5]

        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(state))

        #expect(decoded.run.hireCounts == ["f1": 2.4, "f2": 7])
        #expect(decoded.run.hireCountsByType == ["a": 1.5])
    }

    @Test("gastar ORO pasa por un solo lugar y lo cuenta")
    func spendOroIsTheOnlyWayOut() {
        var meta = fxState().meta
        meta.oro = 10
        let tooMuch = meta.spendOro(11)
        #expect(!tooMuch)
        #expect(meta.oro == 10)
        let spent = meta.spendOro(4)
        #expect(spent)
        #expect(meta.oro == 6)
        #expect(meta.stats.oroSpentEver == 4)
    }

    @Test("gastar ORO rechaza lo negativo, acepta el saldo exacto y no toca el ORO ganado")
    func spendOroEdges() {
        var meta = fxState().meta
        meta.oro = 5
        meta.oroEarnedLifetime = 9

        let negative = meta.spendOro(-1)
        #expect(!negative)
        #expect(meta.oro == 5)
        #expect(meta.stats.oroSpentEver == 0)

        let nothing = meta.spendOro(0)
        #expect(nothing)
        #expect(meta.oro == 5)
        #expect(meta.stats.oroSpentEver == 0)

        let everything = meta.spendOro(5)
        #expect(everything)
        #expect(meta.oro == 0)
        let overdraft = meta.spendOro(1)
        #expect(!overdraft)
        #expect(meta.stats.oroSpentEver == 5)
        #expect(meta.oroEarnedLifetime == 9, "gastar ORO nunca nerfea el multiplicador global")
    }

    @Test("reencarnar recuerda la pared de la run que muere")
    func reincarnationRemembersTheLastRunWall() throws {
        var state = fxState()
        state.run.raiseFrontier(to: 4)
        PrestigeCalculator.applyReincarnation(
            state: &state, economy: fxEconomy(), tiers: try fxTiers(), floorTable: try fxFloorTable(), now: 0
        )
        #expect(state.meta.lastRunMaxTier == 4)
        #expect(state.run.maxTierReached == 1)
        #expect(state.run.revealedTier == 1)
    }

    @Test("la pared es la de la última run, no el récord, y el resto de la 2.0 sobrevive")
    func reincarnationKeepsTheMovingFloorAndTheMeta() throws {
        var state = fxState()
        state.meta.unlockedTabs = ["jobs"]
        state.meta.quickHirePinnedTypeId = "a"
        state.meta.recordOroPurchase(transactionID: "tx_550", amount: 550)
        state.meta.purchasedOroReconstructed = false
        state.run.raiseFrontier(to: 4)
        state.run.priceRelief = 0.5

        let tiers = try fxTiers()
        let floorTable = try fxFloorTable()
        PrestigeCalculator.applyReincarnation(
            state: &state, economy: fxEconomy(), tiers: tiers, floorTable: floorTable, now: 0
        )
        #expect(state.meta.lastRunMaxTier == 4)
        #expect(state.run.priceRelief == 1, "el colchón es de la run y muere con ella")
        #expect(state.meta.unlockedTabs == ["jobs"])
        #expect(state.meta.quickHirePinnedTypeId == "a")
        #expect(state.meta.oroPurchasedLifetime == 550)
        #expect(!state.meta.purchasedOroReconstructed)

        state.run.raiseFrontier(to: 2)
        PrestigeCalculator.applyReincarnation(
            state: &state, economy: fxEconomy(), tiers: tiers, floorTable: floorTable, now: 0
        )
        #expect(state.meta.lastRunMaxTier == 2, "una run más corta baja la pared: es un piso móvil")
    }
}

/// Un v4 tal como lo escribió una versión anterior del juego: sin `seenTypes`,
/// sin `hireCountsByType`, sin `rewardedActivations` ni `creditedPurchases`, sin
/// los contadores nuevos de `stats`, sin los logros y sin los campos del cofre.
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
