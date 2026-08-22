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
            // ⚠️ `tap: 3` y no `tap: 1`: **1 es punto fijo del reescalado**
            // (1/20 × 10 = 0,5 → 1), así que con él borrar la llamada a
            // `rescaleUpgradeLevelsForRebalance` de `migrateV3toV4` dejaba la
            // suite entera VERDE — la migración estaba probada como función y
            // sin cablear. Con 3 el valor migrado es 2 y el cableado queda
            // cubierto por los dos tests de punta a punta.
            "upgradeLevels": ["offline": 2, "tap": 3],
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

    /// El rebalance de pacing (2026-08-21) bajó `income` y `tap` de 20 niveles a
    /// 10 y `crit` de 25 a 10. Un save v3 trae los números viejos, y `v3→v4`
    /// resetea `milestoneSkins`: si los niveles llegaran sin reescalar, cualquier
    /// save con `crit` ≥ 10 contaría como "las siete al tope" y se llevaría las
    /// skins doradas de "ganarlo al máximo".
    @Test func rebalanceRescaleKeepsTheAchievementAndNotTheGift() {
        // El que MAXEÓ de verdad conserva su logro.
        let maxeado = SaveMigrator.rescaleUpgradeLevelsForRebalance(
            ["income": 20, "tap": 20, "crit": 25, "spawn": 10]
        )
        #expect(maxeado == ["income": 10, "tap": 10, "crit": 10, "spawn": 10])

        // El que apenas la empezó NO: con la curva vieja (3 × 2,5ⁿ) crit 10
        // costaba ~19.100 ORO de 1,776e10, el 0,0001 % de la línea. Un clamp lo
        // habría dejado en 10 —al tope— y le habría regalado las skins.
        let apenas = SaveMigrator.rescaleUpgradeLevelsForRebalance(["crit": 10, "income": 12])
        #expect(apenas["crit"] == 4)
        #expect(apenas["income"] == 6)

        // Las líneas cuyo tope no cambió pasan intactas.
        let intactas = SaveMigrator.rescaleUpgradeLevelsForRebalance(["offline": 7, "golden": 3])
        #expect(intactas == ["offline": 7, "golden": 3])

        // ⚠️ **NO es idempotente**, y decirlo importa porque éste es el camino
        // más peligroso de la rama: cada pasada vuelve a dividir por el tope
        // VIEJO, así que aplicarla de nuevo sobre su propio resultado degrada la
        // línea hasta borrarla.
        var repetido = SaveMigrator.rescaleUpgradeLevelsForRebalance(["crit": 25])
        var cadena = [repetido["crit"] ?? -1]
        for _ in 0..<4 {
            repetido = SaveMigrator.rescaleUpgradeLevelsForRebalance(repetido)
            cadena.append(repetido["crit"] ?? -1)
        }
        #expect(cadena == [10, 4, 2, 1, 0], "crit 25 reescalado cinco veces: \(cadena)")

        // Lo que la hace segura NO es la función sino el cableado, y es lo único
        // que hay que cuidar si algún día se agrega otra migración: hay UN SOLO
        // call site (`SaveMigrator.migrateV3toV4`) y `migrate` despacha POR
        // VERSIÓN, así que un save cruza el reescalado exactamente una vez y lo
        // que se guarda después ya es v4. Un v4 nunca vuelve a entrar.
        #expect(SaveMigrator.rescaleUpgradeLevelsForRebalance([:]).isEmpty,
                "sin niveles no hay nada que reescalar")
    }

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
        // `tap: 3` del fixture → 2: 3/20 × 10 = 1,5, redondeado. `offline` no
        // está en `rebalanceLevelCaps` (su tope no cambió) y pasa intacto.
        #expect(migrated.meta.oroUpgradeLevels == ["offline": 2, "tap": 2])
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

    /// El v3 que NINGÚN otro test cruza de punta a punta: el pre-expansión, con
    /// las tres claves originales de `upgrades` y ninguna de las cuatro que
    /// llegaron después.
    ///
    /// ⚠️ Entra por `case 3` **derecho** a `migrateV3toV4`, así que se saltea el
    /// backfill de `migrateV2toV3` que sí protege al v1 de
    /// `v1SaveMigratesThroughTheWholeChain`. Ese hueco lo tapa hoy el
    /// `decodeIfPresent` de `UpgradeState`, y del lado de EconomyKit hay un test
    /// que lo pinea — pero contra un sobre v4 armado a mano, o sea contra el
    /// DECODER. Si mañana `migrateV3toV4` deja de copiar `upgrades` a
    /// `derivedEffects`, o le mete las claves en otro lado, aquel test sigue
    /// verde y el jugador pierde sus mejoras igual. Este corre el blob crudo por
    /// el migrador de verdad, que es lo único que prueba las dos capas juntas.
    @Test func v3PreExpansionMigratesEndToEnd() throws {
        var object = v3Fixture()
        object["upgrades"] = [
            "offlineEfficiency": 0.5,
            "tapMultiplier": 2.0,
            "critChance": 0.25,
        ]
        let data = try JSONSerialization.data(withJSONObject: object)

        let migrated = try SaveMigrator.migrate(data)

        // Lo que el v3 SÍ traía cruza el migrador y llega al `PlayerState`.
        #expect(migrated.schemaVersion == PlayerState.currentSchemaVersion)
        #expect(migrated.meta.derivedEffects.offlineEfficiency == 0.5)
        #expect(migrated.meta.derivedEffects.tapMultiplier == 2.0)
        #expect(migrated.meta.derivedEffects.critChance == 0.25)
        // Las cuatro que no existían caen a su neutro en vez de reventar.
        #expect(migrated.meta.derivedEffects.incomeMultiplier == 1.0)
        #expect(migrated.meta.derivedEffects.goldenChance == 0)
        #expect(migrated.meta.derivedEffects.spawnDiscount == 0)
        #expect(migrated.meta.derivedEffects.prestigeBonus == 0)
        // Y la partida entera sobrevive, que es de lo que se trata.
        #expect(migrated.run.coins == 123_456.5)
        #expect(migrated.run.units == ["homeless": 3, "oficinista": 2, "junior_programmer": 1])
        #expect(migrated.meta.oro == 12)
        // La fuente de verdad de esos efectos también: se pueden recalcular, y
        // llegan REESCALADOS (`tap: 3` → 2).
        #expect(migrated.meta.oroUpgradeLevels == ["offline": 2, "tap": 2])
    }

    /// El extremo del mismo camino: un v3 SIN la clave `upgrades`.
    /// `migrateV3toV4` escribe `derivedEffects: [:]` y de ahí sale el neutro
    /// entero. Tampoco puede costar la partida.
    @Test func v3SinUpgradesMigratesEndToEnd() throws {
        var object = v3Fixture()
        object["upgrades"] = nil
        let data = try JSONSerialization.data(withJSONObject: object)

        let migrated = try SaveMigrator.migrate(data)

        #expect(migrated.meta.derivedEffects == UpgradeState(
            offlineEfficiency: 0, tapMultiplier: 1.0, critChance: 0
        ))
        #expect(migrated.run.coins == 123_456.5)
        #expect(migrated.meta.oro == 12)
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
