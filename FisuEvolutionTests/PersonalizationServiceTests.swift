import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Una config de personalización de mentira: el interruptor y las secciones, a mano.
actor FakePersonalizationSource: PersonalizationConfigSource {
    private(set) var isEnabled: Bool
    private var config: PersonalizationConfig
    private(set) var refreshes: [Bool] = []

    init(enabled: Bool, json: String = PersonalizationFixtures.full) {
        isEnabled = enabled
        config = PersonalizationConfig.decode(Data(json.utf8)) ?? .empty
    }

    func current() -> PersonalizationConfig { config }

    func refresh(force: Bool) async -> PersonalizationConfigLoader.RefreshOutcome {
        refreshes.append(force)
        return isEnabled ? .enabled : .disabled
    }

    func set(enabled: Bool) { isEnabled = enabled }

    func set(json: String) { config = PersonalizationConfig.decode(Data(json.utf8)) ?? .empty }
}

/// El servicio con todo inyectado: reloj, consentimiento, aparato, registro en un temporal y un
/// espía de los eventos.
@MainActor
private final class Harness {
    static let start = Date(timeIntervalSince1970: 1_790_000_000)
    static let hour: TimeInterval = 60 * 60
    static let day: TimeInterval = 24 * hour

    let source: FakePersonalizationSource
    let store: PersonalizationStore
    var now = Harness.start
    var consent = true
    var underAge = false
    var storefront: String? = "USA"
    var player = PlayerState.newGame(
        startTypeId: "homeless", startFloorId: "alley", offlineEfficiencyBase: 0.5, critChanceBase: 0,
        now: 1_700_000_000)
    private(set) var events: [TelemetryPayload] = []
    private(set) var service: PersonalizationService!

    init(enabled: Bool = true, json: String = PersonalizationFixtures.full, arguments: [String] = [],
         storeURL: URL? = nil) {
        source = FakePersonalizationSource(enabled: enabled, json: json)
        store = PersonalizationStore(url: storeURL ?? Self.temporaryURL())
        service = makeService(arguments: arguments)
    }

    static func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "personalization-\(UUID().uuidString)")
            .appending(path: "personalization.json")
    }

    /// Otro servicio sobre el mismo registro: un arranque nuevo de la app.
    func relaunch(arguments: [String] = []) {
        service = makeService(arguments: arguments)
    }

    private func makeService(arguments: [String]) -> PersonalizationService {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let storefront = storefront
        let service = PersonalizationService(
            source: source,
            store: store,
            device: { (storefront, "iPhone16,2") },
            installId: { "8c1f0c6e-0000-4000-8000-000000000001" },
            consentAllows: { [unowned self] in consent },
            underAgeSignal: { [unowned self] in underAge },
            arguments: arguments,
            isDebug: false,
            now: { [unowned self] in now },
            calendar: calendar
        )
        service.attach(player: { [unowned self] in player }, record: { [unowned self] in events.append($0) })
        return service
    }

    /// Una sesión entera: `.active`, el cálculo y `.background` diez minutos después.
    func playSession() async {
        service.sceneDidBecomeActive()
        await service.settle()
        now = now.addingTimeInterval(600)
        service.sceneDidEnterBackground()
    }

    var segmentEvents: [TelemetryPayload] { events.filter { $0.name == .segment } }
    var exposureEvents: [TelemetryPayload] { events.filter { $0.name == .exposure } }
}

/// El servicio de la personalización (2.1 E15 F1 T5): la compuerta, el cálculo de una vez por día,
/// el registro y el evento `segment`.
@Suite("Personalización: el servicio y el segmento", .serialized)
@MainActor
struct PersonalizationServiceTests {
    static let seed = "seed-2026-10-16"

    @Test("interruptor apagado: base, nada calculado y ningún evento")
    func remoteOffIsBase() async {
        let harness = Harness(enabled: false)
        await harness.playSession()
        #expect(harness.service.segment == .base)
        #expect(harness.service.playerValue == nil)
        #expect(harness.events.isEmpty)
        #expect(harness.store.load().computation == nil)
    }

    @Test("sin consentimiento, o con señal de menor: base y ningún evento")
    func closedGateIsBase() async {
        let noConsent = Harness()
        noConsent.consent = false
        await noConsent.playSession()
        #expect(noConsent.service.segment == .base)
        #expect(noConsent.events.isEmpty)

        let minor = Harness()
        minor.underAge = true
        await minor.playSession()
        #expect(minor.service.segment == .base)
        #expect(minor.events.isEmpty)
    }

    @Test("compuerta abierta: el segmento de las reglas y un evento segment")
    func openGateUsesRules() async throws {
        let harness = Harness()
        await harness.playSession()
        // USA (tier 1, 18.000 µ) en un iPhone16: valor 1 × 0,6 + una sesión de 14 × 0,25 / 2 ≈ 0,61 → mid.
        #expect(harness.service.segment == .mid)
        let value = try #require(harness.service.playerValue)
        #expect(value.expectedMicrosPerVideo == 18_000)
        #expect(value.tablesVersion == Self.seed)
        #expect(harness.segmentEvents == [.segment(id: .mid, ver: Self.seed, src: "rules")])
        #expect(harness.exposureEvents.isEmpty, "sin A/B no hay exposure")
        #expect(harness.store.load().computation?.segment == .mid)
    }

    @Test("dos sesiones el mismo día: no recalcula; al día siguiente, sí")
    func recomputesOncePerDay() async {
        let harness = Harness()
        await harness.playSession()
        #expect(harness.service.segment == .mid)

        harness.player.meta.creditedPurchases = ["tx-1"]
        harness.now = harness.now.addingTimeInterval(Harness.hour)
        await harness.playSession()
        #expect(harness.service.segment == .mid, "la compra del mismo día espera al cálculo de mañana")

        harness.now = harness.now.addingTimeInterval(Harness.day)
        await harness.playSession()
        #expect(harness.service.segment == .high)
        #expect(harness.segmentEvents == [
            .segment(id: .mid, ver: Self.seed, src: "rules"),
            .segment(id: .high, ver: Self.seed, src: "rules"),
        ])
    }

    @Test("cambia la versión de las tablas: recalcula el mismo día")
    func recomputesOnNewTables() async {
        let harness = Harness()
        await harness.playSession()
        harness.player.meta.creditedPurchases = ["tx-1"]

        let bumped = PersonalizationFixtures.playerValue.replacingOccurrences(of: Self.seed, with: "seed-2")
        await harness.source.set(json: PersonalizationFixtures.envelope(sections: ["player_value": bumped]))
        harness.now = harness.now.addingTimeInterval(Harness.hour)
        await harness.playSession()
        #expect(harness.service.segment == .high)
        #expect(harness.service.playerValue?.tablesVersion == "seed-2")
    }

    @Test("sin sección player_value válida: base, aunque la compuerta esté abierta")
    func invalidTablesAreBase() async {
        let broken = PersonalizationFixtures.playerValue.replacingOccurrences(of: "\"value\":0.6", with: "\"value\":0.9")
        let harness = Harness(json: PersonalizationFixtures.envelope(sections: ["player_value": broken]))
        await harness.playSession()
        #expect(harness.service.segment == .base)
        #expect(harness.events.isEmpty)
    }

    @Test("se retira el consentimiento: base, sin eventos, y el cálculo guardado sigue")
    func consentWithdrawnKeepsComputation() async throws {
        let harness = Harness()
        await harness.playSession()
        let saved = try #require(harness.store.load().computation)

        harness.consent = false
        harness.now = harness.now.addingTimeInterval(Harness.day)
        await harness.playSession()
        #expect(harness.service.segment == .base)
        #expect(harness.service.playerValue == nil)
        #expect(harness.service.lastEstimate?.segment == .mid, "el panel sigue viendo el último cálculo")
        #expect(harness.store.load().computation == saved)
        #expect(harness.segmentEvents.count == 1)

        harness.consent = true
        harness.relaunch()
        await harness.playSession()
        #expect(harness.service.segment == .mid, "vuelve el consentimiento: sigue desde el cálculo guardado")
    }

    @Test("el interruptor se apaga: base sin borrar el cálculo")
    func remoteSwitchedOffKeepsComputation() async {
        let harness = Harness()
        await harness.playSession()
        await harness.source.set(enabled: false)
        await harness.playSession()
        #expect(harness.service.segment == .base)
        #expect(harness.store.load().computation?.segment == .mid)
    }

    @Test("un registro roto: arranca vacío y calcula")
    func brokenStoreStartsEmpty() async throws {
        let url = Harness.temporaryURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"computation\":".utf8).write(to: url)
        #expect(PersonalizationStore(url: url).load() == .empty)

        let harness = Harness(storeURL: url)
        await harness.playSession()
        #expect(harness.service.segment == .mid)
        #expect(harness.store.load().sessions.count == 1)
    }

    @Test("segment sólo cuando cambia, también entre arranques")
    func segmentOnlyOnChange() async {
        let harness = Harness()
        for _ in 0..<3 {
            await harness.playSession()
            harness.now = harness.now.addingTimeInterval(Harness.day)
        }
        harness.relaunch()
        await harness.playSession()
        #expect(harness.segmentEvents == [.segment(id: .mid, ver: Self.seed, src: "rules")])
    }

    @Test("--uitest-segment fuerza el segmento sin calcular ni mandar nada")
    func forcedSegmentForUITests() async {
        let harness = Harness(enabled: false, arguments: ["--uitest-segment", "high"])
        #expect(harness.service.segment == .high, "forzado desde el arranque")
        await harness.playSession()
        #expect(harness.service.segment == .high)
        #expect(harness.service.playerValue == nil)
        #expect(harness.events.isEmpty)
        #expect(harness.store.load().computation == nil)
    }

    @Test("la sesión queda en el registro con su duración; dos .active seguidos son una")
    func sessionsAreRecorded() async {
        let harness = Harness(enabled: false)
        harness.service.sceneDidBecomeActive()
        harness.service.sceneDidBecomeActive()
        await harness.service.settle()
        harness.now = harness.now.addingTimeInterval(120)
        harness.service.sceneDidEnterBackground()
        #expect(harness.store.load().sessions.map(\.seconds) == [120])
    }

    // MARK: - El A/B de F6

    /// Un árbol de una hoja (predice 0,5) y cuantiles por debajo: con modelo, score 1 → `high`.
    static let model = """
    {"version":"tree-1","features":["country_tier"],"base_score":0,"link":"identity",
     "trees":[{"left":[-1],"right":[-1],"feature":[-1],"threshold":[0],"default_left":[true],"value":[0.5]}]}
    """

    static func abConfig(split: Int) -> String {
        let tables = PersonalizationFixtures.playerValue
            .replacingOccurrences(of: "\"hysteresis\":0.05}", with: "\"hysteresis\":0.05,\"modelThresholds\":[0.1,0.2,0.3,0.4]}")
        return PersonalizationFixtures.envelope(sections: [
            "player_value": tables,
            PlayerValueExperiment.modelSectionKey: model,
            PlayerValueExperiment.sectionKey: "{\"salt\":\"vej-1\",\"split\":\(split)}",
        ])
    }

    @Test("A/B prendido, brazo modelo: el segmento del modelo, src tree-1 y un exposure por sesión")
    func modelArm() async {
        let harness = Harness(json: Self.abConfig(split: 100))
        harness.storefront = "ARG"
        harness.relaunch()
        await harness.playSession()
        #expect(harness.service.segment == .high, "con las reglas, Argentina sería low")
        #expect(harness.service.playerValue?.source == .model)
        #expect(harness.segmentEvents == [.segment(id: .high, ver: Self.seed, src: "tree-1")])
        #expect(harness.exposureEvents == [.exposure(exp: "vej", arm: "model", ver: "tree-1")])

        harness.service.sceneDidBecomeActive()
        await harness.service.settle()
        #expect(harness.exposureEvents.count == 2, "una sesión nueva vuelve a exponer")
        harness.service.sceneDidBecomeActive()
        await harness.service.settle()
        #expect(harness.exposureEvents.count == 2, "un .active sin background en el medio es la misma sesión")
        #expect(harness.segmentEvents.count == 1)
    }

    @Test("A/B prendido, brazo reglas: las reglas, src rules y exposure del brazo reglas")
    func rulesArm() async {
        let harness = Harness(json: Self.abConfig(split: 0))
        await harness.playSession()
        #expect(harness.service.segment == .mid)
        #expect(harness.segmentEvents == [.segment(id: .mid, ver: Self.seed, src: "rules")])
        #expect(harness.exposureEvents == [.exposure(exp: "vej", arm: "rules", ver: "tree-1")])
    }

    @Test("sin sección del A/B, o con un modelo inválido: reglas y ningún exposure")
    func noExperimentWithoutBothSections() async {
        let onlyModel = PersonalizationFixtures.envelope(sections: [
            "player_value": PersonalizationFixtures.playerValue, PlayerValueExperiment.modelSectionKey: Self.model,
        ])
        let harness = Harness(json: onlyModel)
        await harness.playSession()
        #expect(harness.exposureEvents.isEmpty)

        let badModel = Self.abConfig(split: 100).replacingOccurrences(of: "\"tree-1\"", with: "\"tree-9\"")
        let other = Harness(json: badModel)
        await other.playSession()
        #expect(other.exposureEvents.isEmpty)
        #expect(other.segmentEvents == [.segment(id: .mid, ver: Self.seed, src: "rules")])
    }

    @Test("la sección del A/B valida la sal y el reparto")
    func experimentValidation() {
        #expect((try? PlayerValueExperiment(salt: "vej-1", split: 50).validate()) != nil)
        #expect((try? PlayerValueExperiment(salt: "", split: 50).validate()) == nil)
        #expect((try? PlayerValueExperiment(salt: "vej-1", split: 101).validate()) == nil)
        #expect((try? PlayerValueExperiment(salt: "vej-1", split: -1).validate()) == nil)
        #expect((try? PlayerValueExperiment(salt: String(repeating: "s", count: 33), split: 0).validate()) == nil)
    }
}

/// `GameState.segment` sin servicio es la 2.0.
@Suite("Personalización: GameState.segment")
@MainActor
struct GameStatePersonalizationTests {
    @Test("sin servicio adjunto: base y sin valor")
    func baseWithoutService() {
        let gameState = GameState()
        #expect(gameState.segment == .base)
        #expect(gameState.playerValue == nil)
        #expect(gameState.personalization == nil)
    }
}
