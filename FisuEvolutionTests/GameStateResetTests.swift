import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// "Resetear partida" (E9b T8): lo comprado sobrevive, lo demás es partida nueva, hay copia
/// antes de borrar, un disco a medias no deja el save vacío y el doble toque corre una vez.
@Suite("Resetear partida", .serialized)
@MainActor
struct GameStateResetTests {
    private struct World {
        let gameState: GameState
        let backups: URL
        let repository: PlayerStateRepository
    }

    private func makeWorld(snapshotURL: URL? = nil) async -> World {
        let backups = FileManager.default.temporaryDirectory.appending(path: "reset-backups-\(UUID().uuidString)")
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: snapshotURL
                ?? FileManager.default.temporaryDirectory.appending(path: "reset-\(UUID().uuidString).json"),
            backups: SaveBackupStore(directory: backups)
        )
        let gameState = GameState(repository: repository)
        gameState.flagDefaults = .isolatedForTest()
        await gameState.bootstrap()
        return World(gameState: gameState, backups: backups, repository: repository)
    }

    private func oroPack(amount: Int) -> ProductCatalog.Entry {
        ProductCatalog.Entry(
            id: "pack.oro", type: "consumable", entitlement: .oro,
            skinId: nil, coinMinutes: nil, oroAmount: amount
        )
    }

    private func resetFiles(in backups: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: backups.path())) ?? []
        return names.filter { $0.hasPrefix("reset-") }
    }

    // MARK: Lo comprado

    @Test("el ORO comprado que no se gastó sobrevive entero; el ganado no")
    func unspentPurchasedOroSurvives() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "tx-1")
        gameState.player?.meta.oro += 100  // ORO ganado jugando
        let plan = try #require(gameState.resetPlan())
        let outcome = await gameState.resetGame(plan, repushEntitlements: {})
        #expect(outcome == .done)
        #expect(gameState.player?.meta.oro == 250, "min(350, 250)")
        #expect(gameState.player?.meta.oroPurchasedLifetime == 250, "lo comprado sigue contando")
    }

    @Test("el ORO comprado que se gastó no se resucita: oro = min(saldo, comprado)")
    func spentPurchasedOroStaysSpent() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "tx-1")
        #expect(gameState.player?.meta.spendOro(200) == true)
        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan, repushEntitlements: {})
        #expect(gameState.player?.meta.oro == 50, "min(50, 250)")
    }

    @Test("una compra re-entregada después del reset no se acredita dos veces")
    func noDoubleCredit() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "tx-1")
        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan, repushEntitlements: {})
        #expect(gameState.player?.meta.oro == 250)
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "tx-1")
        #expect(gameState.player?.meta.oro == 250, "la transacción ya estaba acreditada")
    }

    @Test("sin anuncios y las skins compradas sobreviven, y los entitlements se re-empujan")
    func entitlementsSurviveAndAreRepushed() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        gameState.applyStoreEntitlements(removedAds: true, ownedSkins: ["mundialista"])
        let plan = try #require(gameState.resetPlan())
        var repushed = false
        await gameState.resetGame(plan) { repushed = true }
        #expect(gameState.player?.meta.removedAds == true)
        #expect(gameState.player?.meta.ownedSkins == ["mundialista"])
        #expect(repushed, "StoreKit se vuelve a consultar con la partida nueva")
    }

    @Test("force re-empuja aunque nada haya cambiado; sin force no hace nada")
    func forcedEntitlementPush() {
        let gameState = GameState(repository: nil)
        gameState.player = PlayerState.newGame(
            startTypeId: "a", startFloorId: "f", offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 0
        )
        let before = gameState.skinSelectionVersion
        gameState.applyStoreEntitlements(removedAds: false, ownedSkins: [])
        #expect(gameState.skinSelectionVersion == before)
        gameState.applyStoreEntitlements(removedAds: false, ownedSkins: [], force: true)
        #expect(gameState.skinSelectionVersion != before)
    }

    // MARK: Copia, disco y época

    @Test("la copia se escribe ANTES de borrar y trae la partida de antes")
    func backupHoldsTheOldGame() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "tx-1")
        gameState.player?.meta.oro += 77
        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan, repushEntitlements: {})
        let file = try #require(resetFiles(in: world.backups).first)
        let saved = try JSONDecoder().decode(PlayerState.self, from: Data(contentsOf: world.backups.appending(path: file)))
        #expect(saved.meta.oro == 327, "la copia es la de antes del reset, no la nueva")
        #expect(saved.meta.resetEpoch == 0)
    }

    @Test("sin dónde guardar la copia no se borra nada")
    func noBackupNoReset() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "tx-1")
        gameState.repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: world.repository.snapshotURL,
            backups: nil
        )
        let before = try #require(gameState.player)
        let plan = try #require(gameState.resetPlan())
        let outcome = await gameState.resetGame(plan, repushEntitlements: {})
        #expect(outcome == .noBackup)
        #expect(gameState.player == before)
    }

    @Test("un reset a medias (el disco no escribe) deja la partida de antes, en memoria y en disco")
    func failedWriteLeavesTheOldGame() async throws {
        let unwritable = FileManager.default.temporaryDirectory
            .appending(path: "no-existe-\(UUID().uuidString)/save.json")
        let world = await makeWorld(snapshotURL: unwritable)
        let gameState = world.gameState
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "tx-1")
        gameState.player?.meta.oro += 100
        await world.repository.save(try #require(gameState.player))  // CoreData con la de antes
        let before = try #require(gameState.player)
        let plan = try #require(gameState.resetPlan())

        let outcome = await gameState.resetGame(plan, repushEntitlements: {})

        #expect(outcome == .writeFailed)
        #expect(gameState.player == before, "la memoria sigue con la partida de antes")
        #expect(gameState.player?.meta.resetEpoch == 0)
        guard case .loaded(let onDisk) = await world.repository.load() else {
            Issue.record("el save quedó vacío o ilegible")
            return
        }
        #expect(onDisk == before, "el disco también")
        #expect(!resetFiles(in: world.backups).isEmpty, "la copia ya estaba hecha")
    }

    @Test("el reset sube la época y lo que queda en disco es la partida nueva")
    func epochRisesAndDiskHoldsTheNewGame() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan, repushEntitlements: {})
        #expect(gameState.player?.meta.resetEpoch == 1)
        guard case .loaded(let onDisk) = await world.repository.load() else {
            Issue.record("sin save en disco")
            return
        }
        #expect(onDisk.meta.resetEpoch == 1)
        #expect(onDisk == gameState.player)
    }

    @Test("lo que se ejecuta es lo que se mostró")
    func executesThePlan() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        gameState.creditStorePurchase(oroPack(amount: 120), transactionID: "tx-1")
        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan, repushEntitlements: {})
        // La torre se reconcilia al arrancar (abre sus pestañas): se compara lo que el plan decide.
        #expect(gameState.player?.meta.oro == plan.result.meta.oro)
        #expect(gameState.player?.meta.resetEpoch == plan.result.meta.resetEpoch)
        #expect(gameState.player?.meta.oroPurchases == plan.result.meta.oroPurchases)
        #expect(gameState.player?.meta.creditedPurchases == plan.result.meta.creditedPurchases)
        #expect(gameState.player?.run.units == plan.result.run.units)
    }

    // MARK: Plan viejo y compras en vuelo

    @Test("un plan viejo (hubo una compra después de mostrarlo) no se ejecuta ni borra la compra")
    func stalePlanIsRejected() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "tx-1")
        let plan = try #require(gameState.resetPlan())
        #expect(gameState.creditStorePurchase(oroPack(amount: 100), transactionID: "tx-2"))

        let outcome = await gameState.resetGame(plan, repushEntitlements: {})

        #expect(outcome == .stale)
        #expect(gameState.player?.meta.creditedPurchases.contains("tx-2") == true, "la compra nueva sigue ahí")
        #expect(gameState.player?.meta.oro == 350)
        #expect(gameState.player?.meta.resetEpoch == 0)
        #expect(resetFiles(in: world.backups).isEmpty, "ni siquiera se hizo la copia")
        let fresh = try #require(gameState.resetPlan())
        #expect(await gameState.resetGame(fresh, repushEntitlements: {}) == .done)
        #expect(gameState.player?.meta.oro == 350, "con el plan nuevo, las dos compras se conservan")
    }

    @Test("una compra que llega mientras se escribe la partida nueva no se pierde: espera y se acredita después")
    func purchaseDuringTheWriteIsNotLost() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "tx-1")
        let plan = try #require(gameState.resetPlan())

        let reset = Task { @MainActor in await gameState.resetGame(plan, repushEntitlements: {}) }
        await Task.yield()
        try #require(gameState.isResetting, "fixture: el reset sigue escribiendo")

        let credited = gameState.creditStorePurchase(oroPack(amount: 100), transactionID: "tx-2")
        let revoked = gameState.revokeStorePurchase(transactionID: "tx-1")
        #expect(!credited, "StoreKit la deja sin finalizar")
        #expect(!revoked)

        #expect(await reset.value == .done)
        #expect(!gameState.isResetting)
        #expect(gameState.player?.meta.creditedPurchases.contains("tx-2") == false, "todavía no entró")
        #expect(gameState.creditStorePurchase(oroPack(amount: 100), transactionID: "tx-2"), "el reintento sí")
        #expect(gameState.player?.meta.oro == 350)
        #expect(gameState.player?.meta.oroPurchasedLifetime == 350)
    }

    // MARK: El doble toque

    @Test("el doble toque corre el reset una sola vez")
    func doubleTapRunsOnce() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        gameState.creditStorePurchase(oroPack(amount: 250), transactionID: "tx-1")
        let plan = try #require(gameState.resetPlan())

        async let first = gameState.resetGame(plan, repushEntitlements: {})
        async let second = gameState.resetGame(plan, repushEntitlements: {})
        let results = await [first, second]

        #expect(results.filter { $0 == .done }.count == 1, "uno corre, el otro es rechazado")
        #expect(results.filter { $0 == .stale }.count == 1)
        #expect(gameState.player?.meta.resetEpoch == 1, "la época sube una vez, no dos")
        #expect(resetFiles(in: world.backups).count == 1, "y una sola copia")
        #expect(gameState.player?.meta.oro == 250)
    }

    @Test("repetir el plan ya ejecutado no hace nada")
    func replayingAnExecutedPlanIsRejected() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        let plan = try #require(gameState.resetPlan())
        #expect(await gameState.resetGame(plan, repushEntitlements: {}) == .done)
        gameState.player?.run.coins = 999
        #expect(await gameState.resetGame(plan, repushEntitlements: {}) == .stale)
        #expect(gameState.player?.run.coins == 999, "la partida en curso no se pisa")
    }

    // MARK: El tutorial vuelve

    @Test("el núcleo vuelve con su cola restringida y el cofre; las banderas del dispositivo no se tocan")
    func tutorialComesBack() async throws {
        let world = await makeWorld()
        let gameState = world.gameState
        let defaults = UserDefaults.standard
        let flags = gameState.flagDefaults
        TutorialFlags.setCoreCompleted(true, in: flags)
        TutorialFlags.markLessonDone("upgrades", in: flags)
        defaults.set("en", forKey: "settings.language")
        defer { defaults.removeObject(forKey: "settings.language") }
        gameState.player?.meta.welcomeChestGiven = true
        gameState.skinAward = GameState.SkinAward(
            id: "urban_trailblazer", characterType: try #require(gameState.content?.tiers.baseType)
        )
        gameState.syncCelebrations()
        #expect(gameState.showing == .skinAward, "fixture: la partida vieja tenía un sheet")

        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan, repushEntitlements: {})

        #expect(!TutorialFlags.coreCompleted(in: flags))
        #expect(!TutorialFlags.isLessonDone("upgrades", in: flags))
        #expect(gameState.tutorialPhaseActive)
        #expect(gameState.tutorialRun?.script == .core)
        #expect(gameState.player?.meta.welcomeChestGiven == false)
        #expect(gameState.skinAward == nil)
        #expect(gameState.showing == nil, "la partida vieja se llevó sus celebraciones")
        gameState.skinAward = GameState.SkinAward(
            id: "urban_trailblazer", characterType: try #require(gameState.content?.tiers.baseType)
        )
        gameState.syncCelebrations()
        #expect(gameState.showing == nil, "la cola quedó restringida a la fase del núcleo")
        #expect(defaults.string(forKey: "settings.language") == "en")
    }
}
