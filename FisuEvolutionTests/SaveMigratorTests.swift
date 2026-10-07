import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Migraciones de schema (v1→v2→v3→v4→v5→v6). Son Codable puro: no hace falta
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

    // MARK: - Fixture v4 (sobre Run/Meta, post-Torre)

    /// Un save v4 REALISTA y SANO: el mismo mid-game del v3 pero ya en sobre
    /// Run/Meta y con los niveles DENTRO de los topes de hoy, o sea escrito
    /// DESPUÉS del rebalance de pacing. Hasta v5 no hacía falta: v4 era la
    /// versión corriente y se decodificaba derecho, sin cruzar el migrador.
    ///
    /// `oroUpgradeLevels` va por parámetro porque es lo único que v4→v5 mira:
    /// los tests del reescalado cambian esa clave y ninguna otra.
    private func v4Fixture(
        oroUpgradeLevels: [String: Int] = ["offline": 2, "tap": 3],
        unlockedFloors: [String] = ["alley", "urban"]
    ) -> [String: Any] {
        [
            "schemaVersion": 4,
            "run": [
                "coins": 123_456.5,
                "units": ["homeless": 3, "oficinista": 2, "junior_programmer": 1],
                "passiveUnlocked": ["homeless": true, "cartonero": true],
                "chosenCareerPath": "programmer",
                "hireCounts": ["alley": 4],
                "hireCountsByType": ["homeless": 4],
                "maxTierReached": 12,
                "charUpgradeLevels": ["homeless": 2],
                "unlockedFloors": unlockedFloors,
                "activeModifiers": [
                    [
                        "id": "11111111-2222-3333-4444-555555555555",
                        "effect": "tapMultiplier",
                        "magnitude": 2.0,
                        "expiresAt": 1_900_000_000.0,
                        "sourceKey": "boost.mate",
                    ] as [String: Any],
                ],
                "seenTypes": ["homeless", "oficinista", "junior_programmer"],
            ] as [String: Any],
            "meta": [
                "lifetimeEarnings": 7_500_000.0,
                "oro": 12,
                "oroEarnedLifetime": 12,
                "prestigeLevel": 2,
                "oroUpgradeLevels": oroUpgradeLevels,
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
                "ownedSkins": ["skin_homeless_gold"],
                "milestoneSkins": [String](),
                "activeSkinByType": ["homeless": "skin_homeless_gold"],
                "removedAds": true,
                "boostActivations": ["mate": 1_690_000_000.0],
                "rewardedActivations": [String: Double](),
                "daily": ["lastClaimDay": "2026-07-30", "cycleDay": 4] as [String: Any],
                "sharesCompleted": 3,
                "lastSeenTimestamp": 1_750_000_000.0,
                "stats": ["maxFloorOrdinalEver": 7],
            ] as [String: Any],
        ]
    }

    // MARK: - Fixtures v1, v2 y v5

    /// Un v1 mínimo pero honesto: flat, sin activeModifiers (nace en v2), sin
    /// upgradeLevels/daily/shares (nacen en v3), upgrades con las TRES claves
    /// base de la época (las otras cuatro las rellena v2→v3).
    private func v1Fixture() -> [String: Any] {
        [
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
    }

    /// El v1 con lo único que estrena v2: `activeModifiers`.
    private func v2Fixture() -> [String: Any] {
        var object = v1Fixture()
        object["schemaVersion"] = 2
        object["activeModifiers"] = [] as [[String: Any]]
        return object
    }

    /// Un estado con todo lo que un save v5 de un veterano trae, y con los
    /// números que más fácil se deforman al pasar por `JSONSerialization`:
    /// magnitudes de idle, sumas que no son exactas en binario y contadores de
    /// compra fraccionarios.
    private func veteranState(maxTier: Int) -> PlayerState {
        var state = PlayerState.newGame(
            startTypeId: "homeless", startFloorId: "alley",
            offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 1_700_000_000.123
        )
        state.run.raiseFrontier(to: maxTier)
        state.run.coins = 1.2345678901234567e30
        state.run.units = ["homeless": 3, "oficinista": 2]
        state.run.passiveUnlocked = ["homeless": true]
        state.run.chosenCareerPath = "programmer"
        state.run.hireCounts = ["alley": 2.4, "urban": 7]
        state.run.hireCountsByType = ["homeless": 1.5]
        state.run.charUpgradeLevels = ["homeless": 2]
        state.run.unlockedFloors = ["alley", "urban"]
        state.run.seenTypes = ["homeless", "oficinista"]
        state.run.floorChestsAwarded = 1
        state.run.activeModifiers = [
            ActiveModifier(
                id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                effect: .tapMultiplier, magnitude: 2.5, expiresAt: 1_900_000_000.5, sourceKey: "boost.mate"
            ),
        ]
        state.meta.lifetimeEarnings = 0.1 + 0.2
        state.meta.oro = 12
        state.meta.oroEarnedLifetime = 40
        state.meta.prestigeLevel = 2
        state.meta.oroUpgradeLevels = ["offline": 2, "tap": 3]
        state.meta.derivedEffects = UpgradeState(
            offlineEfficiency: 0.5, tapMultiplier: 2.0, critChance: 0.25,
            incomeMultiplier: 1.5, goldenChance: 0.125, spawnDiscount: 0.25, prestigeBonus: 0.5
        )
        state.meta.globalMultiplier = 1.0000000000000002
        state.meta.ownedSpecials = ["sp_cryptobro"]
        state.meta.ownedSkins = ["skin_homeless_gold"]
        state.meta.milestoneSkins = ["skin_homeless_milestone"]
        state.meta.activeSkinByType = ["homeless": "skin_homeless_gold"]
        state.meta.removedAds = true
        state.meta.boostActivations = ["mate": 1_690_000_000.123456]
        state.meta.rewardedActivations = ["double_earnings": 1_700_000_000.5]
        state.meta.creditedPurchases = ["tx_1"]
        state.meta.daily = DailyRewardState(lastClaimDay: "2026-07-30", cycleDay: 4)
        state.meta.sharesCompleted = 3
        state.meta.lastSeenTimestamp = 1_750_000_000.987
        state.meta.stats = MetaStats(
            maxFloorOrdinalEver: 7, totalMergesEver: 100, totalHiresEver: 40,
            totalTapsEver: 9000, videosWatchedEver: 5, boostsActivatedEver: 6
        )
        state.meta.unlockedAchievements = ["ach_primer_merge"]
        state.meta.claimedAchievements = ["ach_primer_merge"]
        state.meta.chestsPending = 2
        state.meta.prestigeChestsPending = 1
        state.meta.welcomeChestGiven = true
        return state
    }

    /// El estado codificado como lo escribe la v1 (la app de hoy): sin NINGUNA
    /// clave de la 2.0, ni las que el migrador fija ni las que entran por el decoder.
    private func v5Object(from state: PlayerState) throws -> [String: Any] {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var run = try #require(object["run"] as? [String: Any])
        var meta = try #require(object["meta"] as? [String: Any])
        var stats = try #require(meta["stats"] as? [String: Any])
        for key in ["revealedTier", "priceRelief"] { run.removeValue(forKey: key) }
        for key in ["oroPurchasedLifetime", "purchasedOroReconstructed", "lastRunMaxTier",
                    "quickHirePinnedTypeId", "unlockedTabs", "engagement"] { meta.removeValue(forKey: key) }
        stats.removeValue(forKey: "oroSpentEver")
        meta["stats"] = stats
        object["run"] = run
        object["meta"] = meta
        object["schemaVersion"] = 5
        return object
    }

    private func v5Fixture(maxTier: Int) throws -> Data {
        try JSONSerialization.data(withJSONObject: v5Object(from: veteranState(maxTier: maxTier)))
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
        // que hay que cuidar si algún día se agrega otra migración. Desde v5
        // los call sites son DOS —`migrateV3toV4` la aplica al diccionario
        // entero y `migrateV4toV5` sólo a las líneas que superan su tope de
        // hoy—, y un v3 los cruza a los dos en la misma cadena. No se pisan
        // porque la función CLAMPEA a `caps.actual`: después de la primera
        // pasada ninguna línea queda arriba del tope, así que el filtro de la
        // segunda devuelve el conjunto vacío. `v3SaveMigratesToV4FieldByField`
        // lo pinea de punta a punta (`tap` 3 → 2, no 3 → 2 → 1).
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

    // MARK: - Cadena completa v1 → v6

    @Test func v1SaveMigratesThroughTheWholeChain() throws {
        let v1Data = try JSONSerialization.data(withJSONObject: v1Fixture())

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
        // v5→v6: el último eslabón también corre en la cadena larga.
        #expect(migrated.schemaVersion == 6)
        #expect(migrated.meta.unlockedTabs == Set(SaveMigrator.v1Tabs))
        #expect(!migrated.meta.purchasedOroReconstructed)
    }

    // MARK: - v3 → v4 campo a campo (la migración grande de F7)

    @Test func v3SaveMigratesToV4FieldByField() throws {
        let data = try JSONSerialization.data(withJSONObject: v3Fixture())
        let migrated = try SaveMigrator.migrate(data)

        // La cadena no para en v4: sigue hasta v6 y el sobre queda estampado ahí.
        #expect(migrated.schemaVersion == 6)
        #expect(migrated.run.revealedTier == 12)

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

    // MARK: - v4 → v5 (los cofres, y el arreglo de las skins doradas)

    /// Un v4 SANO —niveles ya dentro de los topes de hoy— sólo estrena los
    /// campos del cofre: no se le toca nada más.
    @Test("un save v4 se migra a v5 sin cofres pendientes")
    func v4MigratesToV5WithEmptyChestState() throws {
        let data = try JSONSerialization.data(withJSONObject: v4Fixture())
        let state = try SaveMigrator.migrate(data)

        #expect(state.meta.chestsPending == 0)
        #expect(state.meta.prestigeChestsPending == 0)
        #expect(state.meta.welcomeChestGiven == false)
        // ⚠️ El contador de la torre NO arranca en cero: arranca donde el jugador
        // está parado. El fixture trae dos pisos abiertos, así que son 2 ÷ 2 = 1
        // cofre YA otorgado — que es exactamente lo que evita que la torre le
        // pague de nuevo por pisos que subió antes de que los cofres existieran.
        // El caso del veterano lo ejerce `v4VeteranDoesNotCollectBackChests`.
        #expect(state.run.floorChestsAwarded == 1)
        // El sobre queda ESTAMPADO —la cadena sigue hasta v6—, y eso es lo único
        // que evita que el save vuelva a cruzar la migración —y con ella un
        // reescalado que no es idempotente— en cada carga. Que `migrate` llame
        // a `migrateV4toV5` lo prueba `floorChestsAwarded == 1` de arriba: los
        // campos del cofre se decodifican con `decodeIfPresent ?? 0`, y el
        // back-fill de la torre es lo único que el decoder no inventa.
        #expect(state.schemaVersion == PlayerState.currentSchemaVersion)
        // Y un save post-rebalance no tiene nada que reescalar: pasa intacto.
        #expect(state.meta.oroUpgradeLevels == ["offline": 2, "tap": 3])
        // La partida entera cruza, que es de lo que se trata.
        #expect(state.run.coins == 123_456.5)
        #expect(state.meta.oro == 12)
        // Los contadores de compra del v4 son enteros en el JSON: llegan como Double.
        #expect(state.run.hireCounts == ["alley": 4])
        #expect(state.run.hireCountsByType == ["homeless": 4])
    }

    /// **El veterano no cobra los cofres de los pisos que ya subió** (decisión del
    /// dueño, 2026-08-27).
    ///
    /// La primera versión de este bump dejaba `floorChestsAwarded` en cero, y con
    /// eso un save parado en el piso 8 cobraba CUATRO cofres de golpe en el primer
    /// merge después de actualizar. Peor: el número dependía de cuándo actualizara.
    /// `unlockedFloors` vive en `run` y muere al reencarnar, así que al recién
    /// reencarnado la actualización lo agarraba en cero y no cobraba nada — dos
    /// saves igual de veteranos cobrando distinto por dónde los agarró el reloj.
    ///
    /// ⚠️ Este test es el ÚNICO candado del back-fill: volver la línea a
    /// `run["floorChestsAwarded"] = 0` lo pone rojo acá y en
    /// `v4MigratesToV5WithEmptyChestState`, y en ningún otro lado.
    @Test("un v4 veterano no cobra los cofres de los pisos que ya subió")
    func v4VeteranDoesNotCollectBackChests() throws {
        let ochoPisos = ["alley", "urban", "corporate", "luxury", "island", "moon", "mars", "solar"]
        let data = try JSONSerialization.data(withJSONObject: v4Fixture(unlockedFloors: ochoPisos))
        let state = try SaveMigrator.migrate(data)

        #expect(state.run.floorChestsAwarded == 4, "ocho pisos abiertos son cuatro cofres ya otorgados")
        #expect(state.meta.chestsPending == 0, "y ninguno esperando ser cobrado")
        // Impar: el back-fill trunca, y el piso suelto queda del lado del jugador
        // —el noveno le paga—. Redondear para arriba le cobraría un cofre que
        // nunca ganó.
        let nuevePisos = ochoPisos + ["mars_deep"]
        let impar = try SaveMigrator.migrate(
            JSONSerialization.data(withJSONObject: v4Fixture(unlockedFloors: nuevePisos))
        )
        #expect(impar.run.floorChestsAwarded == 4, "nueve pisos siguen siendo cuatro, no cinco")
    }

    /// El arreglo de las skins doradas. Un `crit` en 24 sólo existe con el tope
    /// VIEJO de 25: es la huella de un save escrito antes del rebalance de
    /// pacing, justo el que pasaba el `nivel >= maxLevel` de
    /// `awardEligibleMilestoneSkins` y se llevaba las 43 doradas sin ganarlas.
    ///
    /// ⚠️ 24 y no 25 a propósito, pero NO para separar el proporcional del
    /// clamp: con 24 los dos dan lo mismo (24/25 × 10 = 9,6 redondea a 10, y
    /// `min(24, 10)` es 10), igual que con `income: 20`. Lo que compra el 24 es
    /// que la huella dispare con un valor que NO es el tope viejo — lo que
    /// delata a un save pre-rebalance es estar por encima del tope de HOY, no
    /// ser igual al tope de ayer. El candado del proporcional es la otra mitad
    /// del test, `crit 12 → 5`: un clamp lo dejaría en 10 —al tope— y le
    /// regalaría las doradas al que apenas empezó la línea.
    @Test("un v4 pre-rebalance con niveles arriba del tope de hoy se reescala y NO cuenta como maxeado")
    func preRebalanceV4LosesTheFakeMaxOut() throws {
        let maxeado = try SaveMigrator.migrate(
            JSONSerialization.data(withJSONObject: v4Fixture(oroUpgradeLevels: ["income": 20, "tap": 20, "crit": 24]))
        )
        #expect(maxeado.meta.oroUpgradeLevels["crit"] == 10) // 24/25 × 10 ≈ 10
        #expect(maxeado.meta.oroUpgradeLevels["income"] == 10) // 20/20 × 10 = 10

        // El que SÍ tenía poco no se lleva nada regalado:
        let flojo = try SaveMigrator.migrate(
            JSONSerialization.data(withJSONObject: v4Fixture(oroUpgradeLevels: ["income": 20, "tap": 20, "crit": 12]))
        )
        #expect(flojo.meta.oroUpgradeLevels["crit"] == 5) // 12/25 × 10 = 4,8 → 5
    }

    /// El save que CRUZA el rebalance, y la decisión del dueño sobre él: se
    /// reescala LÍNEA POR LÍNEA, sólo la que está arriba de su tope de hoy.
    ///
    /// El caso es real y no de laboratorio: `crit 24` sólo existe con el tope
    /// viejo, pero con `income` en 3 la compra seguía habilitada después del
    /// rebalance (3 < 10), así que esos siete niveles hasta 10 se pagaron con la
    /// curva NUEVA. Reescalar el diccionario entero se los llevaba puestos.
    @Test("en un save que cruza el rebalance sólo se reescala la línea que está arriba del tope")
    func onlyTheLinesAboveTodaysCapAreRescaled() throws {
        let state = try SaveMigrator.migrate(
            JSONSerialization.data(withJSONObject: v4Fixture(oroUpgradeLevels: ["crit": 24, "income": 10, "offline": 2]))
        )
        // La pre-rebalance sí: 24 no puede existir con el tope de hoy.
        #expect(state.meta.oroUpgradeLevels["crit"] == 10)
        // La comprada con la curva nueva NO se toca. Pasando el diccionario
        // entero habría caído a 5 (10/20 × 10) y el jugador habría perdido siete
        // niveles pagados: es exactamente lo que el dueño no quiere.
        #expect(state.meta.oroUpgradeLevels["income"] == 10)
        // Y la línea cuyo tope nunca cambió tampoco entra: no está en `rebalanceLevelCaps`.
        #expect(state.meta.oroUpgradeLevels["offline"] == 2)
    }

    // MARK: - v5 → v6 (la 2.0)

    @Test("un save v5 sube a v6 como veterano y con la reconstrucción pendiente")
    func v5MigratesToV6() throws {
        let state = try SaveMigrator.migrate(v5Fixture(maxTier: 14))
        #expect(state.schemaVersion == 6)
        #expect(state.run.revealedTier == 14)
        #expect(state.meta.unlockedTabs == ["jobs", "upgrades", "skins", "gifts", "store", "menu"])
        #expect(!state.meta.purchasedOroReconstructed)
    }

    /// Un v5 es CUALQUIER partida de la 1.x: pasa por `JSONSerialization` y de
    /// vuelta, y no puede salir distinta. Los números del fixture son los que
    /// más fácil se deforman (1,2e30 de plata, 0,1 + 0,2, 1 + 2⁻⁵²).
    @Test("migrar a v6 no altera ni un campo de lo que el v5 ya tenía")
    func v5MigrationLosesNothing() throws {
        let original = veteranState(maxTier: 9)
        let migrated = try SaveMigrator.migrate(JSONSerialization.data(withJSONObject: v5Object(from: original)))

        var expected = original
        expected.run.revealedTier = 9
        expected.meta.unlockedTabs = Set(SaveMigrator.v1Tabs)
        expected.meta.purchasedOroReconstructed = false
        #expect(migrated == expected)
    }

    @Test("un v5 con la frontera en el tier 1 sube a v6 con lo revelado parejo")
    func v5AtTheFirstTierMigrates() throws {
        let state = try SaveMigrator.migrate(v5Fixture(maxTier: 1))
        #expect(state.run.revealedTier == 1)
        #expect(state.run.maxTierReached == 1)
    }

    @Test("los contadores de compra enteros de un v5 llegan a v6 como Double, y los fraccionarios intactos")
    func purchaseCountersCrossTheMigrationAsDoubles() throws {
        var object = try v5Object(from: veteranState(maxTier: 5))
        var run = try #require(object["run"] as? [String: Any])
        run["hireCounts"] = ["alley": 4, "urban": 2.4]
        run["hireCountsByType"] = ["homeless": 4]
        object["run"] = run

        let state = try SaveMigrator.migrate(JSONSerialization.data(withJSONObject: object))

        #expect(state.run.hireCounts == ["alley": 4.0, "urban": 2.4])
        #expect(state.run.hireCountsByType == ["homeless": 4.0])
    }

    @Test("un v6 ya migrado decodifica sin pasar por ningún eslabón")
    func aV6SaveIsNotMigratedAgain() throws {
        var state = veteranState(maxTier: 9)
        state.run.revealedTier = 7
        state.run.priceRelief = 0.8
        state.meta.unlockedTabs = ["jobs"]
        state.meta.purchasedOroReconstructed = true
        state.meta.oroPurchasedLifetime = 550
        state.meta.lastRunMaxTier = 6
        state.meta.quickHirePinnedTypeId = "homeless"
        state.meta.stats.oroSpentEver = 30

        let migrated = try SaveMigrator.migrate(JSONEncoder().encode(state))

        #expect(migrated == state)
        #expect(migrated.run.revealedTier == 7, "la migración no pisa la red de seguridad de un v6")
        #expect(migrated.meta.unlockedTabs == ["jobs"], "ni vuelve a regalar las seis pestañas")
        #expect(migrated.meta.purchasedOroReconstructed, "ni reabre la reconstrucción")
    }

    @Test("un v5 sin la sección run o meta no se migra: tira en vez de inventar una partida")
    func malformedV5Throws() throws {
        for missing in ["run", "meta"] {
            var object = try v5Object(from: veteranState(maxTier: 3))
            object[missing] = nil
            let data = try JSONSerialization.data(withJSONObject: object)
            #expect(throws: SaveMigrationError.unsupportedVersion(5)) {
                try SaveMigrator.migrate(data)
            }
        }
    }

    /// El candado de la cadena entera: cada versión de entrada llega a la
    /// actual con los defaults de veterano, y lo guardado después ya no vuelve
    /// a cruzar ningún eslabón.
    @Test("toda versión de entrada llega a v6 como veterano y es estable al volver a guardarse")
    func everyEntryPointArrivesAsAVeteran() throws {
        let entries: [(version: Int, object: [String: Any])] = [
            (1, v1Fixture()),
            (2, v2Fixture()),
            (3, v3Fixture()),
            (4, v4Fixture()),
            (5, try v5Object(from: veteranState(maxTier: 6))),
        ]
        for (version, object) in entries {
            let migrated = try SaveMigrator.migrate(JSONSerialization.data(withJSONObject: object))

            #expect(migrated.schemaVersion == 6, "v\(version)")
            #expect(migrated.run.revealedTier == migrated.run.maxTierReached, "v\(version): nunca una lluvia de revelaciones")
            #expect(migrated.run.priceRelief == 1, "v\(version)")
            #expect(migrated.meta.unlockedTabs == Set(SaveMigrator.v1Tabs), "v\(version)")
            #expect(!migrated.meta.purchasedOroReconstructed, "v\(version)")
            #expect(migrated.meta.oroPurchasedLifetime == 0, "v\(version)")
            #expect(migrated.meta.lastRunMaxTier == 0, "v\(version)")
            #expect(migrated.meta.quickHirePinnedTypeId == nil, "v\(version)")
            #expect(migrated.meta.engagement == .initial, "v\(version)")
            #expect(migrated.meta.stats.oroSpentEver == 0, "v\(version)")

            let resaved = try SaveMigrator.migrate(JSONEncoder().encode(migrated))
            #expect(resaved == migrated, "v\(version): guardar y volver a cargar no cambia nada")
        }
    }
}
