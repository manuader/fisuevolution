import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El evento es el contrato con la tabla (C4). La lista blanca es a propósito: un campo nuevo
/// rompe este test y obliga a mirar la privacidad, el SQL y los textos.
@Suite("Telemetría: el evento")
struct TelemetryEventTests {
    private static let columns: Set<String> = [
        "install_id", "session_id", "client_ts", "name", "app_version", "build",
        "os_version", "device_model", "storefront", "props",
    ]

    private static let installId = "11111111-2222-4333-8444-555555555555"
    private static let at = Date(timeIntervalSince1970: 1_790_000_000.75)

    private static func event(_ payload: TelemetryPayload, device: TelemetryDevice = TelemetryFakeNetwork.device) -> TelemetryEvent {
        TelemetryEvent(payload, installId: installId, sessionId: UUID(), at: at, device: device)
    }

    private static func json(_ event: TelemetryEvent) throws -> [String: Any] {
        let data = try TelemetryEvent.makeEncoder().encode(event)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("las claves codificadas son exactamente las columnas de C4, con storefront null si no hay")
    func encodedKeysAreTheColumns() throws {
        let withStore = try Self.json(Self.event(.sessionStart(number: 1)))
        #expect(Set(withStore.keys) == Self.columns)
        #expect(withStore["storefront"] as? String == "ARG")

        let noStore = TelemetryDevice(appVersion: "2.0", build: "42", osVersion: "18.2", deviceModel: "iPhone16,2", storefront: nil)
        let withoutStore = try Self.json(Self.event(.sessionStart(number: 1), device: noStore))
        #expect(Set(withoutStore.keys) == Self.columns)
        #expect(withoutStore["storefront"] is NSNull)
    }

    @Test("los valores de cada columna: uuid en minúsculas, ISO 8601 en segundos, el aparato")
    func columnValues() throws {
        let row = try Self.json(Self.event(.prestige(count: 3)))
        #expect(row["install_id"] as? String == Self.installId)
        let session = try #require(row["session_id"] as? String)
        #expect(UUID(uuidString: session) != nil)
        #expect(session == session.lowercased())
        #expect(row["client_ts"] as? String == "2026-09-21T14:13:20Z")
        #expect(row["name"] as? String == "prestige")
        #expect(row["app_version"] as? String == "2.0")
        #expect(row["build"] as? String == "42")
        #expect(row["os_version"] as? String == "18.2")
        #expect(row["device_model"] as? String == "iPhone16,2")
    }

    static let closedKeys: [(TelemetryPayload, Set<String>)] = [
        (.sessionStart(number: 4), ["n"]),
        (.sessionEnd(seconds: 90), ["seconds"]),
        (.adImpression(format: .rewarded, site: "offline.x2", micros: 1, currency: "USD", precision: .precise, source: "Google"),
         ["format", "site", "micros", "currency", "precision", "source"]),
        (.adImpression(format: .appOpen, site: "appOpen", micros: 1, currency: "USD", precision: .estimated, source: nil),
         ["format", "site", "micros", "currency", "precision"]),
        (.offer(site: "ads.watch.double_earnings", stage: .accepted), ["site", "stage"]),
        (.offer(site: "moment.ff_merge", stage: .shown, ctx: .floorFull), ["site", "stage", "ctx"]),
        (.purchase(product: "com.adergames.fisu.blue.small"), ["product"]),
        (.prestige(count: 1), ["count"]),
        (.segment(id: .mid, ver: "seed-2026-10-16", src: "rules"), ["id", "ver", "src"]),
        (.exposure(exp: "moments", arm: "ff_merge", ver: "3"), ["exp", "arm", "ver"]),
        (.progress(maxTier: 12, activeMinutes: 340, prestige: 2), ["max_tier", "active_minutes", "prestige"]),
    ]

    /// La lista blanca de nombres (C4 + C6 de la 2.1): uno nuevo rompe acá y obliga a migrar el `check`.
    @Test("los nombres son exactamente los seis de la 2.0 y los tres de la 2.1")
    func eventNamesAreTheWhitelist() {
        #expect(Set(TelemetryEventName.allCases.map(\.rawValue)) == [
            "session_start", "session_end", "ad_impression", "offer", "purchase", "prestige",
            "segment", "exposure", "progress",
        ])
    }

    /// Todos los casos de C6 con sus claves: si un caso nuevo no aparece en `closedKeys`, falta su fila.
    @Test("cada nombre tiene al menos un caso en la lista de claves cerradas")
    func everyNameHasClosedKeys() {
        #expect(Set(Self.closedKeys.map { $0.0.name }) == Set(TelemetryEventName.allCases))
    }

    @Test("props de cada evento, con sus claves cerradas", arguments: TelemetryEventTests.closedKeys)
    func propsKeys(payload: TelemetryPayload, keys: Set<String>) throws {
        let props = try #require(try Self.json(Self.event(payload))["props"] as? [String: Any])
        #expect(Set(props.keys) == keys)
    }

    @Test("los números viajan como números y los ids, tal cual")
    func propsValues() {
        let impression = TelemetryPayload.adImpression(
            format: .rewarded, site: "offline.x2", micros: 12_500, currency: "usd", precision: .precise, source: "Unity")
        #expect(impression.props == [
            "format": .string("rewarded"), "site": .string("offline.x2"), "micros": .int(12_500),
            "currency": .string("USD"), "precision": .string("precise"), "source": .string("Unity"),
        ])
        #expect(TelemetryPayload.sessionEnd(seconds: -5).props == ["seconds": .int(0)])
        #expect(TelemetryPayload.offer(site: "offline.x2", stage: .shown).name == .offer)
    }

    @Test("2.1: el segmento y el contexto viajan como su rawValue; el progreso, como números no negativos")
    func v21PropsValues() {
        #expect(TelemetryPayload.segment(id: .high, ver: "seed-2026-10-16", src: "tree-1").props == [
            "id": .string("high"), "ver": .string("seed-2026-10-16"), "src": .string("tree-1"),
        ])
        #expect(TelemetryPayload.offer(site: "moment.ff_merge", stage: .shown, ctx: .backOffline).props == [
            "site": .string("moment.ff_merge"), "stage": .string("shown"), "ctx": .string("back_offline"),
        ])
        #expect(TelemetryPayload.offer(site: "offline.x2", stage: .shown, ctx: nil)
                == TelemetryPayload.offer(site: "offline.x2", stage: .shown))
        #expect(TelemetryPayload.exposure(exp: "moments", arm: "ff_merge", ver: "3").props == [
            "exp": .string("moments"), "arm": .string("ff_merge"), "ver": .string("3"),
        ])
        #expect(TelemetryPayload.progress(maxTier: 12, activeMinutes: 340, prestige: 2).props == [
            "max_tier": .int(12), "active_minutes": .int(340), "prestige": .int(2),
        ])
        #expect(TelemetryPayload.progress(maxTier: -1, activeMinutes: -5, prestige: -2).props == [
            "max_tier": .int(0), "active_minutes": .int(0), "prestige": .int(0),
        ])
        for moment in NeedMoment.allCases {
            #expect(TelemetryPayload.offer(site: "x", stage: .shown, ctx: moment).props["ctx"] == .string(moment.rawValue))
        }
        for segment in PlayerSegment.allCases {
            #expect(TelemetryPayload.segment(id: segment, ver: "v", src: "rules").props["id"] == .string(segment.rawValue))
        }
    }

    @Test("2.1: los textos de segment y exposure son identificadores recortados a 32, nunca texto libre")
    func v21NoFreeText() {
        let segment = TelemetryPayload.segment(id: .low, ver: "versión 2 <x>", src: String(repeating: "r", count: 50))
        #expect(segment.props["ver"] == .string("versin2x"))
        #expect(segment.props["src"] == .string(String(repeating: "r", count: 32)))
        let exposure = TelemetryPayload.exposure(
            exp: String(repeating: "e", count: 40), arm: "brazo uno", ver: "manu@mail.com")
        #expect(exposure.props["exp"] == .string(String(repeating: "e", count: 32)))
        #expect(exposure.props["arm"] == .string("brazouno"))
        #expect(exposure.props["ver"] == .string("manumail.com"))
    }

    @Test("ningún texto libre: lo que no es un identificador se cae y todo queda recortado")
    func noFreeText() {
        let offer = TelemetryPayload.offer(site: "Hola, soy Manu <manu@mail.com>", stage: .shown)
        #expect(offer.props["site"] == .string("HolasoyManumanumail.com"))
        let long = TelemetryPayload.offer(site: String(repeating: "a", count: 500), stage: .shown)
        #expect(long.props["site"] == .string(String(repeating: "a", count: 64)))
        #expect(TelemetryPayload.adImpression(
            format: .rewarded, site: "x", micros: 1, currency: "dólares", precision: .precise, source: nil
        ).props["currency"] == .string("XXX"))
    }

    @Test("nada de IDFA, IDFV ni nombre: ninguna clave ni valor los lleva")
    func noPersonalIdentifiers() throws {
        let data = try TelemetryEvent.makeEncoder().encode(Self.event(.sessionStart(number: 1)))
        let text = try #require(String(data: data, encoding: .utf8)).lowercased()
        for forbidden in ["idfa", "idfv", "advertising", "vendor", "player_name", "ip"] {
            #expect(!text.contains("\"\(forbidden)\""), "aparece \(forbidden)")
        }
        #expect(Set(TelemetryEvent.CodingKeys.allCases.map(\.stringValue)) == Self.columns)
    }

    @Test("el aparato se recorta a los largos de la tabla y la tienda sólo pasa con tres letras")
    func deviceClamps() {
        let device = TelemetryDevice(
            appVersion: String(repeating: "9", count: 40), build: String(repeating: "1", count: 40),
            osVersion: "18.2.1.2.3.4.5.6.7", deviceModel: String(repeating: "M", count: 60), storefront: "arg")
        #expect(device.appVersion.count == 16)
        #expect(device.build.count == 16)
        #expect(device.osVersion.count == 16)
        #expect(device.deviceModel.count == 32)
        #expect(device.storefront == "ARG")
        for bad in ["AR", "ARGE", "A1G", ""] {
            #expect(TelemetryDevice(appVersion: "1", build: "1", osVersion: "1", deviceModel: "x", storefront: bad).storefront == nil)
        }
    }

    @Test("el contexto del aparato lee la tienda una sola vez")
    func deviceContextCaches() async {
        let lookups = LookupCounter()
        let context = DeviceContext(appVersion: "2.0", build: "42", osVersion: "18.2", deviceModel: "iPhone16,2") {
            await lookups.increment()
            return "USA"
        }
        let first = await context.snapshot()
        let second = await context.snapshot()
        #expect(first == second)
        #expect(first.storefront == "USA")
        #expect(await lookups.value == 1)
    }

    @Test("ida y vuelta por JSON sin perder nada")
    func roundTrip() throws {
        let event = Self.event(.adImpression(
            format: .interstitial, site: "adBreak", micros: 7_000, currency: "USD", precision: .estimated, source: "Unity"))
        let data = try TelemetryEvent.makeEncoder().encode(event)
        #expect(try TelemetryEvent.makeDecoder().decode(TelemetryEvent.self, from: data) == event)
    }

    private actor LookupCounter {
        private(set) var value = 0
        func increment() { value += 1 }
    }
}
