import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Las dos proyecciones del Menú (§10.1 y §10.2): la foto de estadísticas y el
/// organigrama.
///
/// Lo que estos tests protegen no es la aritmética —los contadores ya los pinea
/// `StatsCountersAppTests`— sino que la pantalla reciba **texto para dibujar**.
/// Las dos proyecciones existen justamente para que ninguna vista tenga que
/// formatear un número ni resolver una clave: si `maxFloorName` volviera con
/// `tower.floor.alley` adentro, en pantalla se leería la clave cruda (trampa 5
/// del HANDOFF) y ningún test de UI lo notaría, porque el runner corre la app en
/// inglés y compara identifiers.
@Suite("Menú: statsSnapshot y orgChartRows", .serialized)
@MainActor
struct StatsSnapshotTests {
    // MARK: statsSnapshot

    @Test("partida nueva: la foto arranca en cero y ya viene formateada")
    func freshGameSnapshot() async throws {
        let gameState = await makeGameState()
        let snapshot = gameState.statsSnapshot

        #expect(snapshot.lifetimeEarnings == "0")
        #expect(snapshot.oro == "0")
        #expect(snapshot.oroLifetime == "0")
        #expect(snapshot.prestigeLevel == "0")
        #expect(snapshot.maxTier == "1")
        #expect(snapshot.unitCount == "1", "la partida arranca con un Fisura en el callejón")
        #expect(snapshot.shares == "0")
        #expect(snapshot.totalMerges == "0")
        #expect(snapshot.totalHires == "0")
        #expect(snapshot.totalTaps == "0")
        #expect(snapshot.videosWatched == "0")
        #expect(snapshot.boostsActivated == "0")
    }

    @Test("los ratios de colección se dicen 'tenés/hay' contra el catálogo")
    func collectionRatiosCountAgainstTheCatalog() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let snapshot = gameState.statsSnapshot

        #expect(snapshot.seenTypes == "1/\(content.tiers.concreteTypes.count)")
        #expect(snapshot.skins == "0/\(content.skins.skins.count)")
        #expect(snapshot.specials == "0/\(content.specials.specials.count)")
        #expect(snapshot.floorsUnlocked == "1/\(content.floorTable.count)")
    }

    @Test("el piso máximo llega con NOMBRE, no con su id ni con su clave")
    func theMaxFloorArrivesNamed() async throws {
        let gameState = await makeGameState()
        let snapshot = gameState.statsSnapshot

        #expect(!snapshot.maxFloorName.isEmpty)
        #expect(snapshot.maxFloorName != "alley", "el id no es un nombre")
        #expect(snapshot.maxFloorName != "tower.floor.alley", "la clave cruda es la trampa 5")
        #expect(snapshot.maxFloorName == TowerNaming.floorName(for: "alley"))
    }

    @Test("ver tipos y abrir pisos mueve los ratios")
    func seeingAndUnlockingMovesTheRatios() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.debugMarkTypesSeen(throughTier: 8)
        gameState.debugUnlockFloors(throughTier: 5)

        let snapshot = gameState.statsSnapshot
        let seen = content.tiers.concreteTypes.filter { $0.tier <= 8 }.count
        #expect(snapshot.seenTypes == "\(seen)/\(content.tiers.concreteTypes.count)")
        #expect(snapshot.floorsUnlocked == "2/\(content.floorTable.count)")
    }

    @Test("la plata histórica y el income van abreviados, no en crudo")
    func moneyIsAbbreviated() async throws {
        let gameState = await makeGameState()
        gameState.giveLifetimeEarningsForTesting(2_500_000)

        let snapshot = gameState.statsSnapshot
        #expect(snapshot.lifetimeEarnings == CoinFormatter.string(from: 2_500_000))
        #expect(snapshot.lifetimeEarnings != "2500000.0", "un stat de idle no se muestra crudo")
        // El income es EL MISMO texto del HUD: dos formateos distintos harían que
        // la barra de arriba y la pantalla de stats dijeran cosas distintas.
        #expect(snapshot.incomePerSecond == gameState.towerIncomePerSecondText)
    }

    @Test("los contadores históricos sobreviven a la reencarnación")
    func historicCountersSurviveReincarnation() async throws {
        let gameState = await makeGameState()
        var player = try #require(gameState.player)
        player.meta.stats.totalMergesEver = 42
        player.meta.stats.totalTapsEver = 1234
        player.meta.stats.videosWatchedEver = 3
        player.meta.stats.boostsActivatedEver = 7
        player.meta.sharesCompleted = 2
        player.run.maxTierReached = 12
        gameState.player = player
        #expect(gameState.statsSnapshot.maxTier == "12", "antes de reencarnar, el tier es el de la run vigente")

        gameState.giveLifetimeEarningsForTesting(500_000_000)
        gameState.confirmPrestige()

        let snapshot = gameState.statsSnapshot
        #expect(snapshot.totalMerges == "42")
        #expect(snapshot.totalTaps == "1234")
        #expect(snapshot.videosWatched == "3")
        #expect(snapshot.boostsActivated == "7")
        #expect(snapshot.shares == "2")
        #expect(snapshot.prestigeLevel == "1")
        #expect(snapshot.unitCount == "1", "reencarnar deja un solo Fisura")
        #expect(snapshot.oroLifetime != "0", "el ORO ganado es histórico")
        // ⚠️ `maxTier` es el que NO sobrevive, y va acá justamente por eso: vive
        // entre dos filas históricas en pantalla y es el único del grupo Carrera
        // que vuelve a cero. Si algún día se agrega un `maxTierEver` a `MetaStats`,
        // este assert es el que se cae y avisa que la etiqueta "(esta vida)" ya
        // no corresponde.
        #expect(snapshot.maxTier == "1",
                "el tier máximo es de ESTA vida: reencarnar lo devuelve a 1 y por eso lo aclara la etiqueta")
        // Los dos atajos que usa el organigrama dicen lo mismo que las
        // proyecciones enteras: si divergieran, la tarjeta del Jefe y la pantalla
        // de Stats se contradirían en la misma partida.
        #expect(gameState.prestigeLevelText == snapshot.prestigeLevel)
        #expect(gameState.globalMultiplierText == gameState.prestigePreview.multiplierBeforeText)
    }

    /// El multiplicador del Jefe **no** puede salir de `prestigePreview`: esa
    /// proyección lleva `coinsLost` y `oroGained` adentro y `refreshProjections`
    /// la reescribe a 8 Hz mientras la torre produce, así que leerla desde el
    /// organigrama recotiza los 43 nodos ocho veces por segundo. El accesor
    /// estrecho tiene que decir exactamente lo mismo que el popup, o la tarjeta
    /// del Jefe y el indicador del HUD se contradicen.
    @Test("el multiplicador del Jefe dice lo mismo que el del popup de reencarnación")
    func theBossMultiplierMatchesThePrestigePopup() async throws {
        let gameState = await makeGameState()
        #expect(gameState.globalMultiplierText == gameState.prestigePreview.multiplierBeforeText,
                "partida nueva: el multiplicador neutro")

        gameState.giveLifetimeEarningsForTesting(500_000_000)
        gameState.confirmPrestige()

        #expect(gameState.globalMultiplierText == gameState.prestigePreview.multiplierBeforeText,
                "con ORO cobrado tampoco pueden divergir")
        #expect(gameState.globalMultiplierText != PrestigePreview.empty.multiplierBeforeText,
                "reencarnar con 500M tiene que mover el multiplicador")
    }

    // MARK: orgChartRows

    @Test("el organigrama tiene una fila por tipo concreto, el jefe arriba")
    func rowsAreTheWholeChainWithTheBossOnTop() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let rows = gameState.orgChartRows

        #expect(rows.count == content.tiers.concreteTypes.count)
        #expect(!rows.contains { $0.id == "junior" }, "el nodo de elección no es un empleado")

        let tiers = rows.map(\.tier)
        #expect(tiers == tiers.sorted(by: >), "tiers DESC: el de arriba manda")
        #expect(rows.first?.tier == content.tiers.maxTier)
        #expect(rows.last?.id == "homeless")
    }

    @Test("empate de tier: las cuatro carreras salen siempre en el mismo orden")
    func tiesAreBrokenByIdSoTheOrderIsStable() async throws {
        let gameState = await makeGameState()
        let rows = gameState.orgChartRows

        for (lhs, rhs) in zip(rows, rows.dropFirst()) where lhs.tier == rhs.tier {
            #expect(lhs.id < rhs.id, "\(lhs.id) y \(rhs.id) comparten tier y tienen que ordenarse por id")
        }
    }

    @Test("partida nueva: sólo el Fisura tiene cara y nombre, el resto es '???'")
    func aFreshGameOnlyKnowsTheFisura() async throws {
        let gameState = await makeGameState()
        let rows = gameState.orgChartRows

        let fisura = try #require(rows.first { $0.id == "homeless" })
        #expect(fisura.seen)
        #expect(fisura.displayName == "El Fisura")
        #expect(fisura.faceKey == "homeless_face")
        #expect(fisura.count == 1)
        #expect(fisura.tier == 1)
        #expect(fisura.floorID == "alley")

        let rest = rows.filter { $0.id != "homeless" }
        #expect(rest.allSatisfy { !$0.seen })
        #expect(rest.allSatisfy { $0.displayName == "???" })
        #expect(rest.allSatisfy { $0.count == 0 })
        // La clave del retrato viaja igual: la vista la dibuja en silueta, y para
        // eso necesita el PNG. Sin clave, el nodo desconocido sería un hueco.
        #expect(rest.allSatisfy { !$0.faceKey.isEmpty })
    }

    @Test("visto pero sin contratar es ×0, no desaparece")
    func aSeenTypeWithNoUnitsStaysWithZero() async throws {
        let gameState = await makeGameState()
        gameState.debugMarkTypesSeen(throughTier: 8)

        let rows = gameState.orgChartRows
        let seen = rows.filter(\.seen)
        #expect(seen.count > 1)
        #expect(seen.allSatisfy { $0.displayName != "???" })
        // Marcarlos vistos no contrata a nadie: todos menos el Fisura van en ×0.
        #expect(seen.filter { $0.count > 0 }.map(\.id) == ["homeless"])
    }

    @Test("el conteo sale de las unidades vivas de la run")
    func countComesFromLiveUnits() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 5)
        gameState.debugMarkTypesSeen(throughTier: 8)
        gameState.debugGrantCoins()
        gameState.hireCharacter(typeId: "homeless")

        let row = try #require(gameState.orgChartRows.first { $0.id == "homeless" })
        let units = try #require(gameState.player?.run.units["homeless"])
        #expect(row.count == units)
        #expect(row.count == 2, "el Fisura de la partida nueva más el contratado")
    }

    @Test("cada fila cae en el piso que le toca por su tier")
    func everyRowKnowsItsFloor() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)

        for row in gameState.orgChartRows {
            let ordinal = content.floorTable.ordinal(forTier: row.tier)
            #expect(row.floorID == content.floorTable[ordinal].id,
                    "\(row.id) (tier \(row.tier)) dice estar en \(row.floorID)")
        }
    }
}
