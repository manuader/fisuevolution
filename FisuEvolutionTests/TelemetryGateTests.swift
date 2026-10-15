import Foundation
import Testing
@testable import FisuEvolution

/// Un Supabase de mentira para la telemetría: cuenta cada pedido y contesta lo que se le diga por
/// ruta (`rpc/telemetry_enabled`, `telemetry_events`). Nada sale a la red real.
final class TelemetryFakeNetwork: @unchecked Sendable {
    enum Reply: Sendable {
        case status(Int, body: String)
        case failure(URLError)
    }

    private let lock = NSLock()
    private var seen: [URLRequest] = []
    private var rpcReply: Reply
    private var insertReply: Reply

    init(switchBody: String = "false", insertStatus: Int = 201) {
        rpcReply = .status(200, body: switchBody)
        insertReply = .status(insertStatus, body: "")
    }

    var requests: [URLRequest] { lock.withLock { seen } }

    /// Los inserts a la tabla: lo único que importa para «no salió nada».
    var inserts: [URLRequest] { requests.filter { $0.url?.lastPathComponent == "telemetry_events" } }

    var switchQueries: [URLRequest] { requests.filter { $0.url?.lastPathComponent == "telemetry_enabled" } }

    func answerSwitch(_ reply: Reply) { lock.withLock { rpcReply = reply } }

    func answerInserts(_ reply: Reply) { lock.withLock { insertReply = reply } }

    var fetch: TelemetryNetwork.Fetch {
        { [self] request in
            let reply = lock.withLock { () -> Reply in
                seen.append(request)
                return request.url?.lastPathComponent == "telemetry_events" ? insertReply : rpcReply
            }
            switch reply {
            case .failure(let error):
                throw error
            case .status(let status, let body):
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                return (Data(body.utf8), response)
            }
        }
    }

    static let config = RankingConfig(
        schemaVersion: 1, enabled: true, baseURL: URL(string: "https://proyecto.supabase.co"), anonKey: "sb_publishable_test")

    static func temporaryQueue() -> TelemetryQueue {
        TelemetryQueue(fileURL: FileManager.default.temporaryDirectory.appending(path: "telemetry-\(UUID().uuidString).json"))
    }

    static let device = TelemetryDevice(
        appVersion: "2.0", build: "42", osVersion: "18.2", deviceModel: "iPhone16,2", storefront: "ARG")

    @MainActor
    func service(
        queue: TelemetryQueue,
        config: RankingConfig? = TelemetryFakeNetwork.config,
        canRequestAds: Bool = true,
        arguments: [String] = [],
        isDebug: Bool = false
    ) -> TelemetryService {
        TelemetryService(
            queue: queue,
            telemetrySwitch: TelemetrySwitch(config: config, fetch: fetch),
            uploader: TelemetryUploader(config: config, fetch: fetch),
            device: DeviceContext(
                appVersion: "2.0", build: "42", osVersion: "18.2", deviceModel: "iPhone16,2", storefront: { "ARG" }),
            identity: InstallIdentity(store: MemoryIdentityStore("11111111-2222-4333-8444-555555555555")),
            canRequestAds: { canRequestAds },
            arguments: arguments,
            isDebug: isDebug
        )
    }
}

/// El «Listo cuando» de la spec de E15: con cualquier insumo dudoso, nada sale del teléfono y
/// nada se junta en la cola.
@MainActor
@Suite("Telemetría: la compuerta")
struct TelemetryGateTests {
    private static let events: [TelemetryPayload] = [
        .sessionStart(number: 1),
        .adImpression(format: "rewarded", site: "offline.x2", micros: 12_500, currency: "USD", precision: "precise", source: "Google"),
        .offer(site: "ads.watch.double_earnings", stage: "shown"),
        .purchase(product: "com.adergames.fisu.blue.small"),
        .prestige(count: 2),
        .sessionEnd(seconds: 300),
    ]

    /// Arranca, manda los seis eventos y fuerza el envío, esperando a que termine todo.
    private func play(_ service: TelemetryService) async {
        service.start()
        for event in Self.events { service.record(event) }
        service.flush()
        await service.settle()
    }

    @Test("(a) interruptor apagado + consentimiento: 0 inserts y la cola vacía")
    func switchOffSendsNothing() async {
        let network = TelemetryFakeNetwork(switchBody: "false")
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = network.service(queue: queue)

        await play(service)

        #expect(network.switchQueries.count == 1)
        #expect(network.inserts.isEmpty)
        #expect(await queue.count == 0)
        #expect(service.gate.canSend == false)
    }

    @Test("(b) interruptor prendido sin consentimiento de UMP: 0 inserts y la cola vacía")
    func noConsentSendsNothing() async {
        let network = TelemetryFakeNetwork(switchBody: "true")
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = network.service(queue: queue, canRequestAds: false)

        await play(service)

        #expect(network.inserts.isEmpty)
        #expect(await queue.count == 0)
    }

    @Test("(c) el RPC con error, timeout o un cuerpo raro deja la telemetría apagada", arguments: [
        TelemetryFakeNetwork.Reply.status(500, body: "true"),
        .status(404, body: #"{"message":"not found"}"#),
        .failure(URLError(.timedOut)),
        .failure(URLError(.notConnectedToInternet)),
        .status(200, body: "\"true\""),
        .status(200, body: #"{"telemetry_enabled":true}"#),
        .status(200, body: "[true]"),
        .status(200, body: "1"),
        .status(200, body: ""),
    ])
    func doubtfulSwitchIsOff(reply: TelemetryFakeNetwork.Reply) async {
        let network = TelemetryFakeNetwork()
        network.answerSwitch(reply)
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = network.service(queue: queue)

        await play(service)

        #expect(service.remoteEnabled == false)
        #expect(network.inserts.isEmpty)
        #expect(await queue.count == 0)
    }

    @Test("(c) una RankingConfig que no se puede usar no pregunta nada y queda apagada")
    func unusableConfigNeverAsks() async {
        let unusable = [
            nil,
            RankingConfig(schemaVersion: 1, enabled: false, baseURL: URL(string: "https://x.supabase.co"), anonKey: "k"),
            RankingConfig(schemaVersion: 1, enabled: true, baseURL: URL(string: "http://x.supabase.co"), anonKey: "k"),
            RankingConfig(schemaVersion: 1, enabled: true, baseURL: URL(string: "https://x.supabase.co"), anonKey: nil),
        ]
        for config in unusable {
            let network = TelemetryFakeNetwork(switchBody: "true")
            let queue = TelemetryFakeNetwork.temporaryQueue()
            await play(network.service(queue: queue, config: config))

            #expect(network.requests.isEmpty)
            #expect(await queue.count == 0)
        }
    }

    @Test("(d) bajo --uitest-reset no sale nada, ni con --telemetry-debug")
    func uiTestSendsNothing() async {
        for arguments in [["--uitest-reset"], ["--uitest-reset", "--telemetry-debug"]] {
            let network = TelemetryFakeNetwork(switchBody: "true")
            let queue = TelemetryFakeNetwork.temporaryQueue()
            await play(network.service(queue: queue, arguments: arguments))

            #expect(network.inserts.isEmpty)
            #expect(await queue.count == 0)
        }
    }

    @Test("un build DEBUG no manda nada salvo con --telemetry-debug")
    func debugNeedsTheOverride() async {
        let closed = TelemetryFakeNetwork(switchBody: "true")
        let closedQueue = TelemetryFakeNetwork.temporaryQueue()
        await play(closed.service(queue: closedQueue, isDebug: true))
        #expect(closed.inserts.isEmpty)
        #expect(await closedQueue.count == 0)

        let open = TelemetryFakeNetwork(switchBody: "true")
        let openQueue = TelemetryFakeNetwork.temporaryQueue()
        await play(open.service(queue: openQueue, arguments: ["--telemetry-debug"], isDebug: true))
        #expect(open.inserts.count == 1)
    }

    @Test("(e) interruptor prendido + consentimiento: un solo pedido con el lote entero")
    func openGateSendsOneBatch() async throws {
        let network = TelemetryFakeNetwork(switchBody: "true")
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = network.service(queue: queue)

        await play(service)

        #expect(service.remoteEnabled)
        let insert = try #require(network.inserts.first)
        #expect(network.inserts.count == 1)
        let body = try #require(insert.httpBody)
        let rows = try #require(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        #expect(rows.compactMap { $0["name"] as? String } == Self.events.map(\.name.rawValue))
        #expect(await queue.count == 0)
    }

    @Test("lo que se pidió antes de que el interruptor conteste espera y, si dice false, se pierde")
    func eventsBeforeTheAnswerFollowIt() async {
        let network = TelemetryFakeNetwork(switchBody: "false")
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let service = network.service(queue: queue)

        service.start()
        service.record(.sessionStart(number: 1))
        await service.settle()

        #expect(await queue.count == 0)
    }

    @Test("si el consentimiento se retira, lo que quedó en la cola no sale")
    func revokedConsentHoldsTheQueue() async {
        let network = TelemetryFakeNetwork(switchBody: "true")
        let queue = TelemetryFakeNetwork.temporaryQueue()
        let consent = ConsentFlag()
        let service = TelemetryService(
            queue: queue,
            telemetrySwitch: TelemetrySwitch(config: TelemetryFakeNetwork.config, fetch: network.fetch),
            uploader: TelemetryUploader(config: TelemetryFakeNetwork.config, fetch: network.fetch),
            device: DeviceContext(appVersion: "2.0", build: "1", osVersion: "18.2", deviceModel: "iPhone16,2", storefront: { nil }),
            identity: InstallIdentity(store: MemoryIdentityStore()),
            canRequestAds: { consent.allows },
            arguments: [],
            isDebug: false
        )
        service.start()
        service.record(.sessionStart(number: 1))
        await service.settle()
        #expect(await queue.count == 1)

        consent.allows = false
        service.flush()
        await service.settle()

        #expect(network.inserts.isEmpty)
    }

    @MainActor
    private final class ConsentFlag {
        var allows = true
    }

    // MARK: - La compuerta pura

    @Test("canSend exige las cuatro cosas a la vez")
    func gateTruthTable() {
        let open = TelemetryGate(remoteEnabled: true, canRequestAds: true, arguments: [], isDebug: false)
        #expect(open.canSend)

        var noSwitch = open
        noSwitch.remoteEnabled = false
        var noConsent = open
        noConsent.canRequestAds = false
        var uiTest = open
        uiTest.arguments = ["--uitest-skip-tutorial"]
        var debug = open
        debug.isDebug = true
        for closed in [noSwitch, noConsent, uiTest, debug] {
            #expect(closed.canSend == false)
        }

        var debugOverride = debug
        debugOverride.arguments = [TelemetryGate.debugOverride]
        #expect(debugOverride.canSend)
    }
}
