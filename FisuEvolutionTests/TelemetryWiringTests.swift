import EconomyKit
import Foundation
import SwiftUI
import Testing
@testable import FisuEvolution

/// Un `TelemetryService` de prueba: anota lo que le piden, sin compuerta ni red.
@MainActor
private final class SpyTelemetry: TelemetryRecording {
    private(set) var events: [TelemetryPayload] = []
    private(set) var starts = 0
    private(set) var activations = 0
    private(set) var flushes = 0

    func start() { starts += 1 }
    func didBecomeActive() { activations += 1 }
    func record(_ event: TelemetryPayload) { events.append(event) }
    func flush() { flushes += 1 }
    func settle() async {}

    func events(named name: TelemetryEventName) -> [TelemetryPayload] {
        events.filter { $0.name == name }
    }
}

/// Anota qué tareas de background se piden y se devuelven.
@MainActor
private final class TelemetryBackgroundTasks: BackgroundTaskRunning {
    private(set) var begun: [String] = []
    private(set) var ended = 0

    func begin(_ name: String) -> BackgroundTaskToken {
        begun.append(name)
        return BackgroundTaskToken()
    }

    func end(_ token: BackgroundTaskToken) { ended += 1 }
}

/// El cableado de E15 T6: cada fuente emite **un** evento con sus `props` de C4, todo pasa por
/// `TelemetryService.record` y, con la compuerta cerrada, no sale ningún pedido de red.
@Suite("Telemetría: el cableado", .serialized)
@MainActor
struct TelemetryWiringTests {
    private static let impression = AdImpression(
        format: .rewarded, site: RewardedPlacement.offlineX2.rawValue, valueMicros: 12_500, currency: "USD",
        precision: .precise, adSource: "Google", at: 0)

    private static func bluePack(id: String = "pack.blue", amount: Int = 250) -> ProductCatalog.Entry {
        ProductCatalog.Entry(
            id: id, type: "consumable", entitlement: .blue, skinId: nil, coinMinutes: nil, blueAmount: amount)
    }

    private static let removeAds = ProductCatalog.Entry(
        id: "remove_ads", type: "nonConsumable", entitlement: .removeAds, skinId: nil, coinMinutes: nil,
        blueAmount: nil)

    /// Un juego listo con el espía adjunto y la escena quieta: la sesión la abre cada test.
    private func rig() async -> (GameState, SpyTelemetry) {
        let gameState = await makeGameState()
        gameState.isSceneActive = false
        let spy = SpyTelemetry()
        gameState.attachTelemetry(spy, defaults: .isolatedForTest())
        return (gameState, spy)
    }

    /// Las seis fuentes, una vez cada una, por sus caminos reales.
    private func playAllSources(_ gameState: GameState, now: TimeInterval = 1_000) {
        gameState.telemetrySceneChanged(to: .active, now: now)
        gameState.recordImpression(Self.impression)
        gameState.offerFunnelReporter.report("ads.watch.double_earnings", .shown)
        gameState.creditStorePurchase(Self.bluePack(), transactionID: "tx-telemetry-1")
        gameState.giveEarningsForPrestigeTesting(blue: 3)
        gameState.confirmPrestige()
        gameState.telemetrySceneChanged(to: .background, now: now + 300)
    }

    // MARK: - Las sesiones

    @Test("al adjuntar con la escena activa abre la sesión 1 con la hora del arranque, no la de adjuntar")
    func attachingWhileActiveOpensTheFirstSession() async {
        let gameState = await makeGameState()
        let spy = SpyTelemetry()
        gameState.noteLaunchScene(inBackground: false, now: 1_000)

        gameState.attachTelemetry(spy, defaults: .isolatedForTest())
        gameState.telemetrySceneChanged(to: .background, now: 1_090)

        #expect(spy.starts == 1)
        #expect(spy.events == [.sessionStart(number: 1), .sessionEnd(seconds: 90)],
                "la sesión cuenta desde el arranque, con el bootstrap adentro")
    }

    @Test("un arranque en background no abre sesión; el primer .active sí")
    func backgroundLaunchOpensNothing() async {
        let gameState = await makeGameState()
        let spy = SpyTelemetry()
        gameState.noteLaunchScene(inBackground: true, now: 1_000)

        gameState.attachTelemetry(spy, defaults: .isolatedForTest())
        #expect(spy.starts == 1)
        #expect(spy.events.isEmpty, "isSceneActive arranca en true, pero no alcanza para abrir")
        #expect(gameState.telemetry?.isSessionOpen == false)

        gameState.telemetrySceneChanged(to: .active, now: 2_000)
        #expect(spy.events == [.sessionStart(number: 1)])
    }

    @Test("el envío al irse va dentro de una tarea de background que se devuelve al terminar")
    func sessionEndRunsInsideABackgroundTask() async {
        let (gameState, spy) = await rig()
        let tasks = TelemetryBackgroundTasks()
        gameState.attachBackgroundTasks(tasks)

        gameState.telemetrySceneChanged(to: .active, now: 0)
        gameState.telemetrySceneChanged(to: .background, now: 30)
        await gameState.telemetry?.flushTask?.value

        #expect(tasks.begun == ["fisu.telemetry"])
        #expect(tasks.ended == 1)
        #expect(spy.flushes == 1)
    }

    @Test("activa → background: session_start, session_end con la duración y el envío")
    func sessionStartAndEndWithDuration() async {
        let (gameState, spy) = await rig()

        gameState.telemetrySceneChanged(to: .active, now: 1_000)
        gameState.telemetrySceneChanged(to: .background, now: 1_090)

        #expect(spy.events == [.sessionStart(number: 1), .sessionEnd(seconds: 90)])
        #expect(spy.flushes == 1, "irse a background manda lo juntado")
        #expect(spy.activations == 1)
    }

    @Test("un inactive en el medio no corta la sesión; volver abre la siguiente con su número")
    func inactiveDoesNotSplitTheSession() async {
        let (gameState, spy) = await rig()

        gameState.telemetrySceneChanged(to: .active, now: 0)
        gameState.telemetrySceneChanged(to: .inactive, now: 10)
        gameState.telemetrySceneChanged(to: .active, now: 20)
        gameState.telemetrySceneChanged(to: .background, now: 60)
        gameState.telemetrySceneChanged(to: .background, now: 70)
        gameState.telemetrySceneChanged(to: .active, now: 500)

        #expect(spy.events == [.sessionStart(number: 1), .sessionEnd(seconds: 60), .sessionStart(number: 2)])
        #expect(spy.flushes == 1)
    }

    @Test("handleScenePhase es el que lo dispara")
    func scenePhaseDrivesTheSession() async {
        let gameState = await makeGameState()
        let spy = SpyTelemetry()
        gameState.noteLaunchScene(inBackground: false)
        gameState.attachTelemetry(spy, defaults: .isolatedForTest())

        gameState.handleScenePhase(from: .active, to: .background)
        gameState.handleScenePhase(from: .background, to: .active)

        #expect(spy.events(named: .sessionEnd).count == 1)
        #expect(spy.events(named: .sessionStart).count == 2)
        #expect(spy.flushes == 1)
    }

    // MARK: - Cada fuente, un evento

    @Test("una impresión anotada emite un ad_impression con sus props de C1")
    func impressionEmitsOneEvent() async {
        let (gameState, spy) = await rig()

        gameState.recordImpression(Self.impression)

        #expect(spy.events == [.impression(Self.impression)])
        #expect(spy.events.first?.props == [
            "format": .string("rewarded"), "site": .string("offlineX2"), "micros": .int(12_500),
            "currency": .string("USD"), "precision": .string("precise"), "source": .string("Google"),
        ])
    }

    @Test("cada etapa del embudo emite un offer con su lugar y su etapa")
    func offerEmitsOneEventPerStage() async {
        let (gameState, spy) = await rig()

        gameState.offerFunnelReporter.report("double.offline", .shown)
        gameState.offerFunnelReporter.report("double.offline", .accepted)

        #expect(spy.events == [
            .offer(site: "double.offline", stage: .shown),
            .offer(site: "double.offline", stage: .accepted),
        ])
        #expect(spy.events.first?.props == ["site": .string("double.offline"), "stage": .string("shown")])
    }

    @Test("una compra acreditada emite un purchase con el producto y nada más")
    func purchaseEmitsTheProductOnly() async {
        let (gameState, spy) = await rig()

        #expect(gameState.creditStorePurchase(Self.bluePack(), transactionID: "tx-1"))

        #expect(spy.events == [.purchase(product: "pack.blue")])
        #expect(spy.events.first?.props == ["product": .string("pack.blue")])
    }

    @Test("la misma transacción consumible entregada dos veces emite una sola vez")
    func redeliveredConsumableEmitsOnce() async {
        let (gameState, spy) = await rig()

        gameState.creditStorePurchase(Self.bluePack(), transactionID: "tx-1")
        #expect(gameState.creditStorePurchase(Self.bluePack(), transactionID: "tx-1"))

        #expect(spy.events(named: .purchase).count == 1)
    }

    @Test("remove_ads reentregado por StoreKit emite un solo purchase, aunque su id no quede en el save")
    func redeliveredNonConsumableEmitsOnce() async {
        let (gameState, spy) = await rig()

        #expect(gameState.creditStorePurchase(Self.removeAds, transactionID: "tx-ads"))
        #expect(gameState.creditStorePurchase(Self.removeAds, transactionID: "tx-ads"))

        #expect(spy.events(named: .purchase) == [.purchase(product: "remove_ads")])
    }

    @Test("la reentrega no cuenta tampoco después de reabrir la app (lo emitido persiste)")
    func emittedPurchasesSurviveARelaunch() async {
        let defaults = UserDefaults.isolatedForTest()
        let first = await makeGameState()
        first.isSceneActive = false
        first.attachTelemetry(SpyTelemetry(), defaults: defaults)
        first.creditStorePurchase(Self.removeAds, transactionID: "tx-ads")

        let second = await makeGameState()
        second.isSceneActive = false
        let spy = SpyTelemetry()
        second.attachTelemetry(spy, defaults: defaults)
        second.creditStorePurchase(Self.removeAds, transactionID: "tx-ads")

        #expect(spy.events(named: .purchase).isEmpty)
    }

    @Test("lo que llega por En Familia se acredita pero no emite purchase")
    func familySharedDoesNotEmit() async {
        let (gameState, spy) = await rig()

        #expect(gameState.creditStorePurchase(Self.removeAds, transactionID: "tx-family", boughtByThisAccount: false))

        #expect(spy.events(named: .purchase).isEmpty)
    }

    @Test("comprar una oferta emite un purchase con el producto de la oferta")
    func offerPurchaseEmits() async throws {
        let (gameState, spy) = await rig()
        let offer = try #require(try ProductCatalog.load(from: .main).products.first { $0.offerId == "renacer" })

        #expect(gameState.creditStorePurchase(offer, transactionID: "tx-offer"))

        #expect(spy.events(named: .purchase) == [.purchase(product: offer.id)])
    }

    @Test("lo recordado tiene tope: guarda las últimas transacciones y nada más")
    func emittedPurchasesAreBounded() async {
        let defaults = UserDefaults.isolatedForTest()
        let hookup = TelemetryHookup(recorder: SpyTelemetry(), defaults: defaults)

        for index in 0...TelemetryHookup.emittedPurchasesLimit {
            hookup.recordPurchase(product: "pack.blue", transactionID: "tx-\(index)", boughtByThisAccount: true)
        }

        let kept = defaults.stringArray(forKey: TelemetryHookup.emittedPurchasesKey) ?? []
        #expect(kept.count == TelemetryHookup.emittedPurchasesLimit)
        #expect(kept.first == "tx-1")
        #expect(kept.last == "tx-\(TelemetryHookup.emittedPurchasesLimit)")
    }

    @Test("una compra que no se pudo acreditar no emite")
    func failedCreditDoesNotEmit() async {
        let (gameState, spy) = await rig()
        let broken = ProductCatalog.Entry(
            id: "pack.broken", type: "consumable", entitlement: .blue, skinId: nil, coinMinutes: nil, blueAmount: nil)

        #expect(!gameState.creditStorePurchase(broken, transactionID: "tx-9"))

        #expect(spy.events(named: .purchase).isEmpty)
    }

    @Test("reencarnar emite un prestige con las reencarnaciones de la cuenta")
    func prestigeEmitsTheCount() async throws {
        let (gameState, spy) = await rig()
        gameState.giveEarningsForPrestigeTesting(blue: 3)

        gameState.confirmPrestige()

        let level = try #require(gameState.player?.meta.prestigeLevel)
        #expect(level >= 1)
        #expect(spy.events(named: .prestige) == [.prestige(count: level)])
    }

    @Test("las seis fuentes, una vez cada una: un evento por nombre")
    func everySourceEmitsExactlyOnce() async {
        let (gameState, spy) = await rig()

        playAllSources(gameState)

        for name in TelemetryEventName.allCases {
            #expect(spy.events(named: name).count == 1, "\(name.rawValue)")
        }
    }

    @Test("medir no acredita nada: la impresión y la oferta no tocan la plata")
    func measuringDoesNotPay() async throws {
        let (gameState, _) = await rig()
        let before = try #require(gameState.player)

        gameState.recordImpression(Self.impression)
        gameState.offerFunnelReporter.report("ads.watch.double_earnings", .completed)

        let after = try #require(gameState.player)
        #expect(after.run.coins == before.run.coins)
        #expect(after.meta.blue == before.meta.blue)
    }

    @Test("sin telemetría adjunta, cada gancho es un no-op: el save no cambia")
    func detachedIsANoOp() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player)

        gameState.telemetrySceneChanged(to: .active, now: 1_000)
        gameState.telemetryImpression(Self.impression)
        gameState.telemetryOffer(.shown, site: "double.offline")
        gameState.telemetryPurchase(Self.bluePack(), transactionID: "tx-1", boughtByThisAccount: true)
        gameState.telemetryPrestige()
        gameState.telemetrySceneChanged(to: .background, now: 1_300)

        #expect(gameState.telemetry == nil)
        #expect(gameState.player == before)
    }

    // MARK: - La compuerta manda

    @Test("con el interruptor apagado, las seis fuentes no sacan ni un insert y la cola queda vacía")
    func closedGateSendsNothing() async {
        let network = TelemetryFakeNetwork(switchBody: "false")
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = network.service(queue: queue)
        let gameState = await makeGameState()
        gameState.isSceneActive = false
        gameState.attachTelemetry(service, defaults: .isolatedForTest())

        playAllSources(gameState)
        service.flush()
        await service.settle()

        #expect(network.inserts.isEmpty)
        #expect(await queue.count == 0)
    }

    @Test("sin consentimiento, ni siquiera se pregunta el interruptor")
    func noConsentAsksNothing() async {
        let network = TelemetryFakeNetwork(switchBody: "true")
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = network.service(queue: queue, canRequestAds: false)
        let gameState = await makeGameState()
        gameState.isSceneActive = false
        gameState.attachTelemetry(service, defaults: .isolatedForTest())

        playAllSources(gameState)
        await service.settle()

        #expect(network.requests.isEmpty)
        #expect(await queue.count == 0)
    }

    @Test("bajo UI test la compuerta local se cierra aunque el interruptor diga que sí")
    func uiTestArgumentClosesTheGate() async {
        let network = TelemetryFakeNetwork(switchBody: "true")
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = network.service(queue: queue, arguments: ["--uitest-reset"])
        let gameState = await makeGameState()
        gameState.isSceneActive = false
        gameState.attachTelemetry(service, defaults: .isolatedForTest())

        playAllSources(gameState)
        await service.settle()

        #expect(network.requests.isEmpty)
    }

    /// El control positivo: sin él, «no salió nada» podría ser un cableado roto.
    @Test("con la compuerta abierta, los seis eventos llegan a la tabla")
    func openGateDeliversEverySource() async throws {
        let network = TelemetryFakeNetwork(switchBody: "true")
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = network.service(queue: queue)
        let gameState = await makeGameState()
        gameState.isSceneActive = false
        gameState.attachTelemetry(service, defaults: .isolatedForTest())

        playAllSources(gameState)
        await service.settle()

        var names: [String] = []
        for request in network.inserts {
            let body = try #require(request.httpBody)
            let rows = try #require(try JSONSerialization.jsonObject(with: body) as? [[String: Any]])
            names += rows.compactMap { $0["name"] as? String }
        }
        #expect(names.sorted() == TelemetryEventName.allCases.map(\.rawValue).sorted())
        #expect(await queue.count == 0)
    }
}
