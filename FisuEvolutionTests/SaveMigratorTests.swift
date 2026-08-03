import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Migraciones de schema (v1→v2→v3→v4). Son Codable puro: no hace falta
/// GameState ni contenido bundleado. Los fixtures viejos se arman por
/// diccionario JSON (los tipos v1/v3 ya no existen congelados en código).
@Suite("SaveMigrator")
struct SaveMigratorTests {
    // MARK: - Fixture v3 (flat, pre-Torre)

    /// Un save v3 REALISTA: mid-game con carrera elegida, prestigio hecho,
    /// upgrades compradas y un boost activo. Todas las claves que el migrador
    /// lee (y las dos que descarta a propósito: spawnPurchases y
    /// unlockedBackgrounds).
    private func v3Fixture() -> [String: Any] {
        [
            "schemaVersion": 3,
            "coins": 123_456.5,
            // Tipos repetidos a propósito: el migrador agrupa por typeId.
            "board": [
                ["cellIndex": 0, "typeId": "homeless"],
                ["cellIndex": 3, "typeId": "homeless"],
                ["cellIndex": 5, "typeId": "homeless"],
                ["cellIndex": 1, "typeId": "oficinista"],
                ["cellIndex": 4, "typeId": "oficinista"],
                ["cellIndex": 7, "typeId": "junior_programmer"],
            ],
            "soulPoints": 12,
            "upgradeLevels": ["offline": 2, "tap": 1],
            "upgrades": [
                "offlineEfficiency": 0.5,
                "tapMultiplier": 2.0,
                "critChance": 0.25,
                "incomeMultiplier": 1.5,
                "goldenChance": 0.125,
                "spawnDiscount": 0.25,
                "prestigeBonus": 0.5,
            ],
            "lifetimeEarnings": 7_500_000.0,
            "prestigeLevel": 2,
            "globalMultiplier": 2.5,
            "ownedSkins": ["skin_homeless_gold"],
            "activeSkin": "skin_homeless_gold",
            "ownedSpecials": ["sp_cryptobro"],
            "spawnPurchases": 41,
            "unlockedBackgrounds": ["alley", "urban"],
            "maxTierReached": 12,
            // Cartonero pasivo aunque ya no esté en el board: pasa de verdad
            // (se mergea y el unlock queda). El migrador copia verbatim.
            "passiveUnlocked": ["homeless": true, "cartonero": true],
            "chosenCareerPath": "programmer",
            "activeModifiers": [
                [
                    "id": "11111111-2222-3333-4444-555555555555",
                    "effect": "tapMultiplier",
                    "magnitude": 2.0,
                    "expiresAt": 1_900_000_000.0,
                    "sourceKey": "boost.mate",
                ],
            ],
            "removedAds": true,
            "boostActivations": ["mate": 1_690_000_000.0],
            "daily": ["lastClaimDay": "2026-07-30", "cycleDay": 4],
            "sharesCompleted": 3,
            "lastSeenTimestamp": 1_750_000_000.0,
        ]
    }

    // MARK: - Schema actual

    @Test func currentVersionDecodesUnchanged() throws {
        let state = PlayerState.newGame(
            startTypeId: "homeless",
            startFloorId: "alley",
            offlineEfficiencyBase: 0.5,
            critChanceBase: 0,
            now: 1_700_000_000
        )
        let data = try JSONEncoder().encode(state)
        let migrated = try SaveMigrator.migrate(data)
        #expect(migrated == state)
    }

    @Test func futureVersionThrowsInsteadOfCorrupting() throws {
        var state = PlayerState.newGame(
            startTypeId: "homeless",
            startFloorId: "alley",
            offlineEfficiencyBase: 0.5,
            critChanceBase: 0,
            now: 1_700_000_000
        )
        state.schemaVersion = 99
        let data = try JSONEncoder().encode(state)
        #expect(throws: SaveMigrationError.unsupportedVersion(99)) {
            try SaveMigrator.migrate(data)
        }
    }

    // MARK: - Cadena completa v1 → v4

    @Test func v1SaveMigratesThroughTheWholeChain() throws {
        // Un v1 mínimo pero honesto: flat, sin activeModifiers (nace en v2),
        // sin upgradeLevels/daily/shares (nacen en v3), upgrades con las TRES
        // claves base de la época (las otras cuatro las rellena v2→v3).
        let v1Object: [String: Any] = [
            "schemaVersion": 1,
            "coins": 77.0,
            "board": [
                ["cellIndex": 0, "typeId": "homeless"],
                ["cellIndex": 2, "typeId": "homeless"],
            ],
            "soulPoints": 0,
            "upgrades": [
                "offlineEfficiency": 0.5,
                "tapMultiplier": 1.0,
                "critChance": 0.0,
            ],
            "lifetimeEarnings": 77.0,
            "prestigeLevel": 0,
            "globalMultiplier": 1.0,
            "ownedSkins": [] as [String],
            "ownedSpecials": [] as [String],
            "spawnPurchases": 1,
            "unlockedBackgrounds": ["alley"],
            "maxTierReached": 1,
            "passiveUnlocked": [:] as [String: Bool],
            "removedAds": false,
            "lastSeenTimestamp": 1_600_000_000.0,
        ]
        let v1Data = try JSONSerialization.data(withJSONObject: v1Object)

        let migrated = try SaveMigrator.migrate(v1Data)
        #expect(migrated.schemaVersion == PlayerState.currentSchemaVersion)
        #expect(migrated.run.coins == 77)
        #expect(migrated.run.units == ["homeless": 2])
        #expect(migrated.run.chosenCareerPath == nil)
        // Defaults sanos que aportó cada eslabón de la cadena:
        #expect(migrated.run.activeModifiers.isEmpty) // v1→v2
        #expect(migrated.meta.oroUpgradeLevels.isEmpty) // v2→v3
        #expect(migrated.meta.boostActivations.isEmpty) // v2→v3
        #expect(migrated.meta.daily.cycleDay == 1) // v2→v3
        #expect(migrated.meta.sharesCompleted == 0) // v2→v3
        // v2→v3 rellenó las líneas de upgrade que no existían en v1.
        #expect(migrated.meta.derivedEffects.incomeMultiplier == 1.0)
        #expect(migrated.meta.derivedEffects.goldenChance == 0.0)
        #expect(migrated.meta.derivedEffects.spawnDiscount == 0.0)
        #expect(migrated.meta.derivedEffects.prestigeBonus == 0.0)
        // v3→v4: curvas nuevas arrancan frescas.
        #expect(migrated.run.hireCounts.isEmpty)
        #expect(migrated.run.unlockedFloors.isEmpty)
    }

    // MARK: - v3 → v4 campo a campo (la migración grande de F7)

    @Test func v3SaveMigratesToV4FieldByField() throws {
        let data = try JSONSerialization.data(withJSONObject: v3Fixture())
        let migrated = try SaveMigrator.migrate(data)

        #expect(migrated.schemaVersion == 4)

        // RUN — board posicional → units por tipo, con counts agrupados.
        #expect(migrated.run.coins == 123_456.5)
        #expect(migrated.run.units == ["homeless": 3, "oficinista": 2, "junior_programmer": 1])
        #expect(migrated.run.passiveUnlocked == ["homeless": true, "cartonero": true])
        #expect(migrated.run.chosenCareerPath == "programmer")
        #expect(migrated.run.maxTierReached == 12)
        // spawnPurchases y unlockedBackgrounds se DESCARTAN: la curva de hire
        // nueva arranca fresca y los pisos los puebla el TowerReconciler.
        #expect(migrated.run.hireCounts.isEmpty)
        #expect(migrated.run.unlockedFloors.isEmpty)
        #expect(migrated.run.charUpgradeLevels.isEmpty)
        // El boost activo cruza la migración intacto.
        let modifier = try #require(migrated.run.activeModifiers.first)
        #expect(migrated.run.activeModifiers.count == 1)
        #expect(modifier.id == UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        #expect(modifier.effect == .tapMultiplier)
        #expect(modifier.magnitude == 2.0)
        #expect(modifier.expiresAt == 1_900_000_000)
        #expect(modifier.sourceKey == "boost.mate")

        // META — soul points → ORO 1:1 (balance Y earned).
        #expect(migrated.meta.lifetimeEarnings == 7_500_000)
        #expect(migrated.meta.oro == 12)
        #expect(migrated.meta.oroEarnedLifetime == 12)
        #expect(migrated.meta.prestigeLevel == 2)
        #expect(migrated.meta.oroUpgradeLevels == ["offline": 2, "tap": 1])
        #expect(migrated.meta.derivedEffects == UpgradeState(
            offlineEfficiency: 0.5,
            tapMultiplier: 2.0,
            critChance: 0.25,
            incomeMultiplier: 1.5,
            goldenChance: 0.125,
            spawnDiscount: 0.25,
            prestigeBonus: 0.5
        ))
        #expect(migrated.meta.globalMultiplier == 2.5)
        #expect(migrated.meta.ownedSpecials == ["sp_cryptobro"])
        #expect(migrated.meta.specialAnchors.isEmpty)
        #expect(migrated.meta.ownedSkins == ["skin_homeless_gold"])
        #expect(migrated.meta.milestoneSkins.isEmpty)
        // Skin global legacy → aplicada a cada tipo presente en el board.
        #expect(migrated.meta.activeSkinByType == [
            "homeless": "skin_homeless_gold",
            "oficinista": "skin_homeless_gold",
            "junior_programmer": "skin_homeless_gold",
        ])
        #expect(migrated.meta.removedAds == true)
        #expect(migrated.meta.boostActivations == ["mate": 1_690_000_000])
        #expect(migrated.meta.daily == DailyRewardState(lastClaimDay: "2026-07-30", cycleDay: 4))
        #expect(migrated.meta.sharesCompleted == 3)
        #expect(migrated.meta.lastSeenTimestamp == 1_750_000_000)
        #expect(migrated.meta.stats.maxFloorOrdinalEver == 0)
    }

    /// Gotcha real: un v3 guardado antes de elegir carrera serializa
    /// `"chosenCareerPath": null`. JSONSerialization lo trae como NSNull, que
    /// NO castea a String — el migrador tiene que omitir la clave, no copiarla.
    @Test func v3NullCareerPathSurvivesMigration() throws {
        var object = v3Fixture()
        object["chosenCareerPath"] = NSNull()
        let data = try JSONSerialization.data(withJSONObject: object)

        let migrated = try SaveMigrator.migrate(data)
        #expect(migrated.run.chosenCareerPath == nil)
        // Y el resto de la migración salió entera igual.
        #expect(migrated.run.units == ["homeless": 3, "oficinista": 2, "junior_programmer": 1])
        #expect(migrated.meta.oro == 12)
    }
}
