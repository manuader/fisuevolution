import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// F7 wiring: GameState orquestando la torre (merge/ascenso, carrera, pasivo,
/// offline y reencarnación) sobre el contenido real bundleado. La matemática
/// pura vive en EconomyKitTests; acá se prueba el CABLEADO: que las acciones
/// sobre el piso visible muten `run.units` y `tower` en sincronía.
@Suite("GameState F7 wiring")
@MainActor
struct GameLoopWiringTests {
    /// Slots (ordenados) que ocupa un tipo en el piso VISIBLE — los slots
    /// concretos los decide TowerReconciler/firstFreeSlot, no los pineamos.
    private func slots(of typeId: String, in gameState: GameState) -> [Int] {
        gameState.visiblePlacements.filter { $0.typeId == typeId }.map(\.slot).sorted()
    }

    // MARK: Torre en escena (F7.2)

    @Test func towerNavigationProjectsUnlockedBoundsAndTotalIncome() async throws {
        let gameState = await makeGameState()

        #expect(gameState.towerNavigation.floorID == "alley")
        #expect(gameState.towerNavigation.ordinal == 0)
        #expect(gameState.towerNavigation.totalFloors == gameState.floorTable?.floors.count)
        // La torre deja asomarse exactamente a UN piso bloqueado: hace visible
        // el objetivo de progresión sin permitir contratar ni saltar más arriba.
        #expect(gameState.towerNavigation.canNavigateUp)
        #expect(gameState.towerNavigation.canNavigateDown == false)
        #expect(gameState.moveVisibleFloor(by: 1))
        #expect(gameState.visibleFloorOrdinal == 1)
        #expect(gameState.visibleFloorIsUnlocked == false)
        #expect(gameState.canAffordSpawn == false)
        #expect(gameState.towerNavigation.canNavigateUp == false)
        #expect(gameState.towerNavigation.canNavigateDown)
        #expect(gameState.moveVisibleFloor(by: -1))

        // El helper coloca el par en urban y lo desbloquea: el límite de preview
        // se desplaza al siguiente piso, sin permitir saltarlo.
        gameState.debugSetMaxTier(5)
        gameState.debugGrantPair()
        #expect(gameState.towerNavigation.canNavigateUp)

        let versionBeforeNavigation = gameState.boardVersion
        #expect(gameState.moveVisibleFloor(by: 1))
        #expect(gameState.visibleFloorOrdinal == 1)
        #expect(gameState.towerNavigation.floorID == "urban")
        #expect(gameState.visibleFloorIsUnlocked)
        #expect(gameState.towerNavigation.canNavigateUp)
        #expect(gameState.towerNavigation.canNavigateDown)
        #expect(gameState.boardVersion > versionBeforeNavigation)
        #expect(gameState.moveVisibleFloor(by: 1))
        #expect(gameState.visibleFloorOrdinal == 2)
        #expect(gameState.visibleFloorIsUnlocked == false)
        #expect(gameState.towerNavigation.canNavigateUp == false)
        #expect(gameState.moveVisibleFloor(by: 1) == false)
        #expect(gameState.moveVisibleFloor(by: -1))

        gameState.debugGrantCoins()
        gameState.unlockPassive(typeId: "homeless")
        gameState.flushHUD()
        #expect(gameState.towerIncomePerSecond > 0)
        #expect(gameState.towerIncomePerSecondText != "0")
    }

    // MARK: Drag & drop en el piso visible

    @Test func dropOnSameTypeMergesOnVisibleFloor() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair() // 2 fisuras extra en el alley
        let fisuras = slots(of: "homeless", in: gameState)
        #expect(fisuras.count == 3) // la inicial + el par

        let resolution = gameState.handleDrop(fromCell: fisuras[1], toCell: fisuras[2])
        guard case .merged(
            targetCell: let targetCell,
            evolvedTo: let evolvedTo,
            promotedType: let promotedType,
            promotedToFloor: let promotedToFloor,
            unlockedFloorId: let unlockedFloorId
        ) = resolution else {
            Issue.record("expected merge, got \(resolution)")
            return
        }
        #expect(targetCell == fisuras[2])
        // Primer trapito: el tier máximo avanzó → hay reveal.
        #expect(evolvedTo?.id == "trapito")
        // T2 sigue viviendo en el alley (1-4): ni ascenso ni desbloqueo.
        #expect(promotedType == nil)
        #expect(promotedToFloor == nil)
        #expect(unlockedFloorId == nil)
        #expect(gameState.player?.run.units == ["homeless": 1, "trapito": 1])
        #expect(gameState.player?.run.maxTierReached == 2)
        #expect(gameState.unitCount == 2)
        // Invariante F7: la torre en memoria refleja exactamente run.units.
        #expect(gameState.tower?.unitCounts == gameState.player?.run.units)
    }

    @Test func dropOnEmptyCellMoves() async throws {
        let gameState = await makeGameState()
        let from = try #require(slots(of: "homeless", in: gameState).first)
        let resolution = gameState.handleDrop(fromCell: from, toCell: 7)
        guard case .moved = resolution else {
            Issue.record("expected move, got \(resolution)")
            return
        }
        #expect(gameState.visiblePlacements == [TowerPlacement(floorOrdinal: 0, slot: 7, typeId: "homeless")])
    }

    @Test func dropOnDifferentTypeSnapsBack() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(2)
        gameState.debugGrantPair() // 2 trapitos en el alley
        let fisura = try #require(slots(of: "homeless", in: gameState).first)
        let trapito = try #require(slots(of: "trapito", in: gameState).first)

        let resolution = gameState.handleDrop(fromCell: fisura, toCell: trapito) // fisura → trapito
        guard case .snapBack = resolution else {
            Issue.record("expected snapBack, got \(resolution)")
            return
        }
        // Nada se consumió: la torre y el save siguen sincronizados.
        #expect(gameState.unitCount == 3)
        #expect(gameState.tower?.unitCounts == gameState.player?.run.units)
    }

    /// El callejón es 1…4, así que la frontera con urban la cruza el Cartonero
    /// (T4) al mergear en El Mantero (T5), primero del piso urbano.
    @Test func tier4MergePromotesToUrbanAndUnlocksIt() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(4)
        gameState.debugGrantPair()
        let cartoneros = slots(of: "cartonero", in: gameState)
        #expect(cartoneros.count == 2)

        let resolution = gameState.handleDrop(fromCell: cartoneros[0], toCell: cartoneros[1])
        guard case .merged(
            targetCell: _,
            evolvedTo: _,
            promotedType: let promotedType,
            promotedToFloor: let promotedToFloor,
            unlockedFloorId: let unlockedFloorId
        ) = resolution else {
            Issue.record("expected an urban promotion, got \(resolution)")
            return
        }
        #expect(promotedType?.id == "mantero")
        #expect(promotedType?.tier == 5)
        #expect(promotedToFloor == 1)
        #expect(unlockedFloorId == "urban")
        #expect(gameState.player?.run.unlockedFloors.contains("urban") == true)
        #expect(gameState.player?.meta.milestoneSkins.contains("urban_trailblazer") == true)
        #expect(gameState.tower?.unitCounts == gameState.player?.run.units)
        // El sheet ya NO aparece en el instante del merge: taparía el vuelo, el
        // reveal y la celebración del piso, los tres a la vez. Espera a que la
        // escena termine su cadena.
        #expect(gameState.skinAward == nil, "el sheet no puede tapar la cadena")
        gameState.celebrationsDidFinish()
        // ⚠️ Acá se pineaba `skinAward?.id == "urban_trailblazer"`, y se rompió al
        // agregar personajes: `urban` ahora otorga TRES skins y el popup muestra
        // la primera alfabéticamente (`GameState.swift`, `newlyUnlocked.sorted().first`),
        // que pasó a ser `malabarista`. Varias skins por piso es la conducta de
        // siempre —isla y lujo otorgan siete— así que lo que estaba mal era el
        // test: pinear el ganador alfabético lo rompe cada vez que entra
        // contenido. Se pinea la regla, que es la que importa.
        let premiada = try #require(gameState.skinAward, "tras la cadena tiene que aparecer el sheet")
        #expect(
            gameState.player?.meta.milestoneSkins.contains(premiada.id) == true,
            "el popup tiene que mostrar una de las skins recién ganadas, no cualquiera"
        )
        #expect(
            content(of: premiada, in: gameState)?.floorReached == "urban",
            "y tiene que ser una del piso que se acaba de abrir"
        )
    }

    /// La entrada de catálogo de la skin que muestra el sheet.
    private func content(of award: GameState.SkinAward, in gameState: GameState) -> SkinsConfig.Entry? {
        gameState.content?.skins.skins.first { $0.id == award.id }
    }

    /// Con el gate de contratación, abrir corporate (ordinal 2) es lo que
    /// destraba urban (ordinal 1): recién ahí urban tiene el piso de arriba.
    @Test func hireUnlockedNoticeWaitsItsTurn() async throws {
        let gameState = await makeGameState()
        // tier 8 (`fast_food`) es el ÚLTIMO de urban (5-8), así que su merge
        // cruza a corporate. Hay que abrir urban y pararse ahí: `slots(of:in:)`
        // y `handleDrop` miran el piso VISIBLE.
        gameState.debugUnlockFloors(throughTier: 8)
        gameState.debugSetMaxTier(8)
        gameState.debugGrantPair()
        #expect(gameState.moveVisibleFloor(by: 1), "no pude subir a urban")
        let pair = slots(of: "fast_food", in: gameState)
        #expect(pair.count >= 2)

        _ = gameState.handleDrop(fromCell: pair[0], toCell: pair[1])
        #expect(gameState.player?.run.unlockedFloors.contains("corporate") == true)
        #expect(gameState.towerNotice == nil, "el toast no sale durante la cadena")

        gameState.celebrationsDidFinish()
        gameState.skinAwardDismissed()        // no-op si no hubo skin que otorgar
        #expect(gameState.towerNotice?.kind == .hireUnlocked(floorID: "urban"))
    }

    /// Parado en la frontera, el gate cierra la contratación de ese piso. En vez
    /// de dejar el botón muerto, la compra cae en el piso de abajo — que es
    /// justamente donde hace falta material de merge — hasta que ese piso se
    /// llena.
    @Test func hiringOnTheFrontierFallsBackToTheFloorBelow() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 5)   // abre alley + urban, corporate no
        #expect(gameState.moveVisibleFloor(by: 1), "no pude subir a urban")

        // El gate de urban no pasa (corporate cerrado), así que la oferta baja.
        #expect(gameState.hireOffer == .floorBelow(floorID: "alley"))
        #expect(gameState.spawnQuote?.floorOrdinal == 0)
        #expect(gameState.spawnQuote?.type.id == "homeless", "cotiza el tier base del callejón")

        gameState.debugGrantCoins()
        gameState.flushHUD()
        #expect(gameState.canAffordSpawn, "con plata el botón tiene que comprar, no quedar muerto")

        let alleyBefore = gameState.floorOccupancy(ordinal: 0).occupied
        let urbanBefore = gameState.floorOccupancy(ordinal: 1).occupied
        gameState.buySpawn()
        #expect(gameState.floorOccupancy(ordinal: 0).occupied == alleyBefore + 1, "la unidad cae abajo")
        #expect(gameState.floorOccupancy(ordinal: 1).occupied == urbanBefore, "y no en el piso visible")
        #expect(gameState.visibleFloorOrdinal == 1, "comprar no mueve la cámara")

        // Y cuando el callejón se llena, el botón lo dice en vez de seguir cobrando.
        let capacity = gameState.floorOccupancy(ordinal: 0).capacity
        while gameState.floorOccupancy(ordinal: 0).occupied < capacity {
            let before = gameState.floorOccupancy(ordinal: 0).occupied
            gameState.buySpawn()
            #expect(gameState.floorOccupancy(ordinal: 0).occupied == before + 1, "se quedó sin plata antes de llenarlo")
        }
        gameState.flushHUD()
        #expect(gameState.hireOffer == .full(belowFloorID: "alley"))
        #expect(gameState.canAffordSpawn == false)
    }

    /// Con el piso de arriba abierto no hay fallback: se contrata donde estás.
    @Test func hiringStaysOnTheVisibleFloorWhenTheGateIsOpen() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 9)   // alley + urban + corporate
        #expect(gameState.moveVisibleFloor(by: 1), "no pude subir a urban")

        #expect(gameState.hireOffer == .here)
        #expect(gameState.spawnQuote?.floorOrdinal == 1)

        gameState.debugGrantCoins()
        gameState.flushHUD()
        let urbanBefore = gameState.floorOccupancy(ordinal: 1).occupied
        gameState.buySpawn()
        #expect(gameState.floorOccupancy(ordinal: 1).occupied == urbanBefore + 1)
    }

    /// Los specials no ocupan slot: quedan de decorado en el piso donde cayeron
    /// (⚠️5). La escena los dibuja desde esta proyección, así que un ancla de una
    /// config vieja (o un special no poseído) simplemente no aparece.
    @Test func anchoredSpecialsAreScopedToTheirFloor() async throws {
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "anchor-\(UUID().uuidString).json")
        )
        var seeded = PlayerState.newGame(
            startTypeId: "homeless",
            startFloorId: "alley",
            offlineEfficiencyBase: 0.35,
            critChanceBase: 0,
            now: Date().timeIntervalSince1970
        )
        seeded.meta.ownedSpecials = ["sp_arbolito", "sp_cryptobro"]
        seeded.meta.specialAnchors = [
            "sp_arbolito": "alley",
            "sp_cryptobro": "urban",
            // Ancla huérfana: el special no está en ownedSpecials.
            "sp_lizard": "alley",
        ]
        seeded.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
        await repository.save(seeded)

        let gameState = GameState(repository: repository)
        await gameState.bootstrap()

        #expect(gameState.visibleFloorDef?.id == "alley")
        #expect(gameState.visibleFloorSpecials.map(\.id) == ["sp_arbolito"])
    }

    // MARK: Carrera (T10+T10 → choice node diferido)

    @Test func tier10MergeAsksForCareerAndResolvesAfterChoice() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(10)
        gameState.debugGrantPair() // 2 administrativos en corporate (ordinal 2)
        // handleDrop opera sobre el piso VISIBLE: subir hasta el par.
        gameState.setVisibleFloor(2)
        #expect(gameState.visibleFloorDef?.id == "corporate")
        let admins = slots(of: "administrativo", in: gameState)
        #expect(admins.count == 2)

        let resolution = gameState.handleDrop(fromCell: admins[0], toCell: admins[1])
        guard case .careerPending = resolution else {
            Issue.record("expected careerPending, got \(resolution)")
            return
        }
        let prompt = try #require(gameState.careerPrompt)
        #expect(prompt.options.count == 4)
        // La torre no cambió todavía (merge diferido, snap-back visual).
        #expect(gameState.player?.run.units["administrativo"] == 2)
        #expect(gameState.tower?.unitCounts == gameState.player?.run.units)

        gameState.chooseCareer(optionId: "junior_programmer")
        #expect(gameState.careerPrompt == nil)
        #expect(gameState.player?.run.chosenCareerPath == "programmer")
        #expect(gameState.player?.run.units["junior_programmer"] == 1)
        #expect(gameState.player?.run.maxTierReached == 11)
        #expect(gameState.tower?.unitCounts == gameState.player?.run.units)
    }

    // MARK: Ascenso de piso (F7 §3.4: el merge cruza la frontera corporate → luxury)

    /// Corporate es 9…12, así que ahora la frontera con luxury la cruza el
    /// Senior (T12) al mergear en Director (T13) — no el junior, que se queda
    /// en corporate.
    @Test func tier12MergePromotesToLuxuryAndUnlocksIt() async throws {
        let gameState = await makeGameState()
        // Carrera elegida por el camino real (T10+T10 → prompt → programmer).
        gameState.debugSetMaxTier(10)
        gameState.debugGrantPair()
        gameState.setVisibleFloor(2)
        let admins = slots(of: "administrativo", in: gameState)
        _ = gameState.handleDrop(fromCell: admins[0], toCell: admins[1])
        gameState.chooseCareer(optionId: "junior_programmer")
        #expect(gameState.player?.run.maxTierReached == 11)

        // Con la carrera elegida, debugGrantPair coloca la rama correcta.
        gameState.debugSetMaxTier(12)
        gameState.debugGrantPair()
        let seniors = slots(of: "senior_programmer", in: gameState)
        #expect(seniors.count == 2)

        let resolution = gameState.handleDrop(fromCell: seniors[0], toCell: seniors[1])
        guard case .merged(
            targetCell: _,
            evolvedTo: let evolvedTo,
            promotedType: let promotedType,
            promotedToFloor: let promotedToFloor,
            unlockedFloorId: let unlockedFloorId
        ) = resolution else {
            Issue.record("expected merge, got \(resolution)")
            return
        }
        // T13 pertenece a luxury (13-16): reveal + ascenso + desbloqueo.
        let luxuryOrdinal = try #require(gameState.floorTable?.ordinal(of: "luxury"))
        #expect(evolvedTo?.id == "director")
        #expect(promotedType?.id == "director")
        #expect(promotedToFloor == luxuryOrdinal)
        #expect(unlockedFloorId == "luxury")
        #expect(gameState.player?.run.unlockedFloors.contains("luxury") == true)
        // La unidad ascendida vive en luxury, no en corporate.
        #expect(gameState.tower?.placements(onFloor: luxuryOrdinal).contains { $0.typeId == "director" } == true)
        #expect(gameState.player?.run.units["director"] == 1)
        #expect(gameState.tower?.unitCounts == gameState.player?.run.units)
    }

    @Test func destinationFullMergePublishesTowerNotice() async throws {
        let gameState = await makeGameState()
        gameState.debugSetMaxTier(10)
        gameState.debugGrantPair()
        gameState.setVisibleFloor(2)
        let admins = slots(of: "administrativo", in: gameState)
        _ = gameState.handleDrop(fromCell: admins[0], toCell: admins[1])
        gameState.chooseCareer(optionId: "junior_programmer")
        gameState.debugSetMaxTier(12)
        gameState.debugGrantPair() // dos seniors que intentarán ascender

        // Llenamos luxury de forma intencional con el helper existente. La acción
        // de merge tiene que seguir siendo atómica y publicar sólo la intención UI.
        gameState.debugSetMaxTier(13)
        for _ in 0..<5 { gameState.debugGrantPair() }
        gameState.setVisibleFloor(2)
        let seniors = slots(of: "senior_programmer", in: gameState)
        let resolution = gameState.handleDrop(fromCell: seniors[0], toCell: seniors[1])
        guard case .snapBack = resolution else {
            Issue.record("expected blocked promotion, got \(resolution)")
            return
        }
        #expect(gameState.towerNotice?.kind == .destinationFloorFull(floorID: "luxury"))
        let noticeID = try #require(gameState.towerNotice?.id)
        gameState.dismissTowerNotice(id: noticeID)
        #expect(gameState.towerNotice == nil)
    }

    // MARK: Pasivo + tick

    @Test func passiveUnlockMakesTickEarn() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.unlockPassive(typeId: "homeless")
        #expect(gameState.player?.run.passiveUnlocked["homeless"] == true)

        // Yield real derivado del contenido: passive del tipo × mult del piso
        // donde vive (alley) — sin números mágicos.
        let content = try #require(gameState.content)
        let fisura = try #require(content.tiers.type(id: "homeless"))
        let expectedPerSecond = fisura.passiveYieldPerInstance
            * content.floorTable.floor(forTier: fisura.tier).incomeMultiplier

        let coinsBefore = try #require(gameState.player?.run.coins)
        gameState.tick(delta: 1.0)
        let coinsAfter = try #require(gameState.player?.run.coins)
        #expect(abs(coinsAfter - coinsBefore - expectedPerSecond) < 1e-9)
    }

    // MARK: Ficha de personaje + skins (F7.5)

    @Test func skinEquipIsScopedToItsCharacterAndSurvivesReincarnation() async throws {
        let gameState = await makeGameState()
        // `second_life` es de milestone, no de tienda: los tintes IAP se
        // retiraron del catálogo y ya no hay skins comprables.
        gameState.grantMilestoneSkinsForTests(["second_life"])

        // La skin se equipa en UNA ficha, no en todos los tipos como el puente
        // F7.1. La preferencia vive en Meta y debe sobrevivir la run.
        gameState.equipSkin(id: "second_life", forCharacterType: "homeless")
        #expect(gameState.activeSkinID(forCharacterType: "homeless") == "second_life")
        #expect(gameState.activeSkinID(forCharacterType: "cartonero") == nil)

        var fuse = 0
        while !gameState.prestigeAvailable && fuse < 64 {
            gameState.debugGrantCoins()
            fuse += 1
        }
        #expect(gameState.prestigeAvailable)
        gameState.confirmPrestige()
        #expect(gameState.activeSkinID(forCharacterType: "homeless") == "second_life")
    }

    @Test func hugeTickDeltaIsClamped() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.unlockPassive(typeId: "homeless")
        let coinsBefore = try #require(gameState.player?.run.coins)
        // El delta gigante del primer frame post-background lo cubre offline:
        // acreditarlo acá duplicaría.
        gameState.tick(delta: 3600)
        #expect(gameState.player?.run.coins == coinsBefore)
    }

    // MARK: Offline

    @Test func offlineSimulationCreditsAndPresentsPopup() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.unlockPassive(typeId: "homeless")
        gameState.debugSimulateOffline(hours: 4)

        let content = try #require(gameState.content)
        let fisura = try #require(content.tiers.type(id: "homeless"))
        let perSecond = fisura.passiveYieldPerInstance
            * content.floorTable.floor(forTier: fisura.tier).incomeMultiplier
        let expected = perSecond * 4 * 3600 * content.economy.offlineEfficiencyBase

        let reward = try #require(gameState.offlineReward)
        // Tolerancia: el reloj real avanza unos ms entre bootstrap y apply.
        #expect(abs(reward.amount - expected) < 1.0)
    }

    // MARK: Reencarnación (F7: gate por ORO, no por tier)

    @Test func prestigeFlowResetsRunAndKeepsMeta() async throws {
        let gameState = await makeGameState()
        let divisor = try #require(gameState.content?.economy.oro.divisor)
        let fisura = try #require(gameState.content?.tiers.type(id: "homeless"))
        gameState.debugGrantCoins()
        let coinsBeforeCharacterUpgrade = try #require(gameState.player?.run.coins)
        gameState.buyCharacterUpgrade(typeID: fisura.id)
        #expect(gameState.characterUpgradeLevel(of: fisura.id) == 1)
        #expect((gameState.player?.run.coins ?? coinsBeforeCharacterUpgrade) < coinsBeforeCharacterUpgrade)
        // Gate: reencarnar ⟺ ganar ≥1 ORO ⟺ lifetimeEarnings alcanza el divisor.
        var fuse = 0
        while !gameState.prestigeAvailable && fuse < 64 {
            gameState.debugGrantCoins()
            fuse += 1
        }
        #expect(gameState.prestigeAvailable)
        #expect((gameState.player?.meta.lifetimeEarnings ?? 0) >= divisor)
        #expect(gameState.prestigeOroGained > 0)

        gameState.confirmPrestige()
        // La run murió entera…
        #expect(gameState.player?.run.units == ["homeless": 1])
        #expect(gameState.player?.run.hireCounts.isEmpty == true)
        #expect(gameState.characterUpgradeLevel(of: fisura.id) == 0)
        #expect(gameState.player?.run.unlockedFloors == ["alley"])
        // …y la meta cobró.
        #expect(gameState.player?.meta.prestigeLevel == 1)
        #expect((gameState.player?.meta.oro ?? 0) > 0)
        #expect((gameState.player?.meta.globalMultiplier ?? 0) > 1.0)
        #expect(gameState.prestigeAvailable == false)
        // Torre reconciliada: una fisura sola en el alley.
        #expect(gameState.visibleFloorOrdinal == 0)
        #expect(gameState.visiblePlacements.count == 1)
        #expect(gameState.visiblePlacements.first?.typeId == "homeless")
        #expect(gameState.tower?.unitCounts == gameState.player?.run.units)
    }

    @Test func hireQuoteAppliesPrestigeDiscount() async throws {
        let gameState = await makeGameState()
        let baseCost = try #require(gameState.spawnQuote?.cost)

        var fuse = 0
        while !gameState.prestigeAvailable && fuse < 64 {
            gameState.debugGrantCoins()
            fuse += 1
        }
        gameState.confirmPrestige()

        // El descuento fluye por prestige_unlocks → costMultiplier del hireQuote
        // (GameState.currentQuote), NO por derivedEffects.spawnDiscount (esa es
        // la línea de upgrade "spawn"). Post-reencarnación hireCounts está en 0,
        // así que la única diferencia con el quote virgen es el descuento.
        let unlocks = try #require(gameState.content?.prestigeUnlocks)
        let level = try #require(gameState.player?.meta.prestigeLevel)
        #expect(level == 1)
        let expected = baseCost * (1 - unlocks.cumulativeSpawnDiscount(atPrestigeLevel: level))
        let discounted = try #require(gameState.spawnQuote?.cost)
        #expect(discounted < baseCost)
        #expect(abs(discounted - expected) < 1e-9)
    }

    // MARK: Deslizamiento vertical (RF-09)

    @Test("el deslizamiento usa la metáfora de scroll: dedo hacia abajo sube un piso")
    func swipeDownGoesUp() async throws {
        let gameState = await makeGameState()
        gameState.debugUnlockFloors(throughTier: 5)   // abre alley + urban
        let scene = BoardScene(gameState: gameState)
        let startOrdinal = gameState.visibleFloorOrdinal

        // En coordenadas de escena la y crece hacia arriba, así que el dedo
        // yendo hacia ABAJO de la pantalla es deltaY negativo.
        scene.simulateSwipe(deltaY: -120)
        #expect(gameState.visibleFloorOrdinal == startOrdinal + 1, "hacia abajo tiene que subir")

        scene.simulateSwipe(deltaY: 120)
        #expect(gameState.visibleFloorOrdinal == startOrdinal, "hacia arriba tiene que bajar")
    }

    /// La regla vive en `floorDelta` y no duplicada en `touchesEnded`: si alguien
    /// afloja el umbral o el sesgo vertical, se entera acá.
    @Test("un roce corto o mayormente horizontal no navega")
    func shortOrHorizontalSwipesDoNothing() async throws {
        let gameState = await makeGameState()
        let scene = BoardScene(gameState: gameState)

        #expect(scene.floorDelta(deltaX: 0, deltaY: 40) == nil, "48pt es el umbral")
        #expect(scene.floorDelta(deltaX: 200, deltaY: 120) == nil, "el arrastre horizontal no navega")
        #expect(scene.floorDelta(deltaX: 0, deltaY: -120) == 1)
        #expect(scene.floorDelta(deltaX: 0, deltaY: 120) == -1)
    }
}
