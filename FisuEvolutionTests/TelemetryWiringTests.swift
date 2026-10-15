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

    func events(named name: TelemetryEventName) -> [TelemetryPayload] {
        events.filter { $0.name == name }
    }
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

    @Test("al adjuntar con la escena activa arranca el servicio y abre la sesión 1")
    func attachingWhileActiveOpensTheFirstSession() async {
        let gameState = await makeGameState()
        let spy = SpyTelemetry()

        gameState.attachTelemetry(spy, defaults: .isolatedForTest())

        #expect(spy.starts == 1)
        #expect(spy.events == [.sessionStart(number: 1)])
        #expect(gameState.telemetry?.isSessionOpen == true)
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

    @Test("una compra restaurada (la transacción ya acreditada) no emite")
    func restoredPurchaseDoesNotEmit() async {
        let (gameState, spy) = await rig()

        gameState.creditStorePurchase(Self.bluePack(), transactionID: "tx-1")
        #expect(gameState.creditStorePurchase(Self.bluePack(), transactionID: "tx-1"))

        #expect(spy.events(named: .purchase).count == 1)
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

    @Test("sin telemetría adjunta, las fuentes son un no-op")
    func detachedIsANoOp() async {
        let gameState = await makeGameState()

        playAllSources(gameState)

        #expect(gameState.telemetry == nil)
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
