import EconomyKit
import Foundation

/// Los eventos que existen: los seis de la 2.0 (C4) y los tres de la 2.1 (C6). Un nombre nuevo es
/// un cambio de contrato: también lo es en el `check` de la tabla.
enum TelemetryEventName: String, Codable, Sendable, CaseIterable {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case adImpression = "ad_impression"
    case offer
    case purchase
    case prestige
    case segment
    case exposure
    case progress
}

/// Un valor de `props`: sólo texto acotado o números. Nunca un objeto ni un texto libre.
enum TelemetryValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int64)
    case double(Double)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let integer = try? container.decode(Int64.self) {
            self = .int(integer)
        } else if let number = try? container.decode(Double.self) {
            self = .double(number)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let text): try container.encode(text)
        case .int(let integer): try container.encode(integer)
        case .double(let number): try container.encode(number)
        }
    }

    /// Un identificador (id de botón, de producto, de red): sólo letras y dígitos ASCII y `._-:`,
    /// recortado. Lo que no es un identificador se cae: así ningún texto libre llega a la tabla.
    static func token(_ raw: String, maxLength: Int = 64) -> TelemetryValue {
        .string(String(raw.unicodeScalars.filter(isTokenScalar).prefix(maxLength).map(Character.init)))
    }

    /// ISO 4217 para «sin moneda»: la tabla exige tres mayúsculas, así que lo ilegible viaja así.
    static let noCurrency = "XXX"

    /// Un código ISO 4217: tres letras en mayúscula, o `XXX` si no lo es.
    static func currency(_ raw: String) -> TelemetryValue {
        let letters = raw.uppercased().unicodeScalars.filter { $0.isASCII && CharacterSet.uppercaseLetters.contains($0) }
        return .string(letters.count == 3 ? String(letters) : noCurrency)
    }

    private static func isTokenScalar(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || "._-:".unicodeScalars.contains(scalar))
    }
}

/// Lo que la app cuenta, con sus claves cerradas (C4). Es la única puerta para armar un evento:
/// de afuera no entra ni un nombre ni una clave de `props`.
enum TelemetryPayload: Sendable, Equatable {
    /// `number`: el número de sesión de esta instalación.
    case sessionStart(number: Int)
    case sessionEnd(seconds: Int)
    /// C1: el formato y la precisión llegan tipados; viajan como su `rawValue`.
    case adImpression(
        format: AdFormat, site: String, micros: Int64, currency: String, precision: AdValuePrecision, source: String?)
    /// C3: la etapa llega tipada; viaja como su `rawValue`. `ctx` (2.1, C6) es el momento de
    /// necesidad que la sacó (F3); sin momento, la clave no viaja.
    case offer(site: String, stage: OfferStage, ctx: NeedMoment? = nil)
    /// Sólo el producto: ni precio ni transacción.
    case purchase(product: String)
    /// Las reencarnaciones de la cuenta.
    case prestige(count: Int)
    /// 2.1 (C6): el segmento de valor, la versión de las tablas que lo decidió y de dónde salió
    /// (`rules` o `tree-<v>`). Sólo al cambiar; lo emite el servicio de personalización (F1 T5).
    case segment(id: PlayerSegment, ver: String, src: String)
    /// 2.1 (C6): el jugador vio un brazo de un experimento (el bandido de F3, un A/B de F6). Una vez
    /// por sesión y brazo; lo emite quien expone.
    case exposure(exp: String, arm: String, ver: String)
    /// 2.1 (C6): dónde va la partida, junto con cada `session_end`: el tier de esta vida, los minutos
    /// activos de la partida y las reencarnaciones. Es el ritmo real contra el simulado (F7).
    case progress(maxTier: Int, activeMinutes: Int, prestige: Int)

    var name: TelemetryEventName {
        switch self {
        case .sessionStart: .sessionStart
        case .sessionEnd: .sessionEnd
        case .adImpression: .adImpression
        case .offer: .offer
        case .purchase: .purchase
        case .prestige: .prestige
        case .segment: .segment
        case .exposure: .exposure
        case .progress: .progress
        }
    }

    var props: [String: TelemetryValue] {
        switch self {
        case .sessionStart(let number):
            return ["n": .int(Int64(number))]
        case .sessionEnd(let seconds):
            return ["seconds": .int(Int64(max(0, seconds)))]
        case .adImpression(let format, let site, let micros, let currency, let precision, let source):
            var values: [String: TelemetryValue] = [
                "format": .token(format.rawValue, maxLength: 32),
                "site": .token(site),
                "micros": .int(micros),
                "currency": .currency(currency),
                "precision": .token(precision.rawValue, maxLength: 32),
            ]
            if let source { values["source"] = .token(source, maxLength: 32) }
            return values
        case .offer(let site, let stage, let ctx):
            var values: [String: TelemetryValue] = ["site": .token(site), "stage": .token(stage.rawValue, maxLength: 32)]
            if let ctx { values["ctx"] = .token(ctx.rawValue, maxLength: 32) }
            return values
        case .purchase(let product):
            return ["product": .token(product, maxLength: 128)]
        case .prestige(let count):
            return ["count": .int(Int64(count))]
        case .segment(let id, let ver, let src):
            return ["id": .token(id.rawValue, maxLength: 32), "ver": .token(ver, maxLength: 32),
                    "src": .token(src, maxLength: 32)]
        case .exposure(let exp, let arm, let ver):
            return ["exp": .token(exp, maxLength: 32), "arm": .token(arm, maxLength: 32),
                    "ver": .token(ver, maxLength: 32)]
        case .progress(let maxTier, let activeMinutes, let prestige):
            return ["max_tier": .int(Int64(max(0, maxTier))), "active_minutes": .int(Int64(max(0, activeMinutes))),
                    "prestige": .int(Int64(max(0, prestige)))]
        }
    }

    /// Una impresión del ledger (C1), tal cual la anotó `GameState.recordImpression`.
    static func impression(_ impression: AdImpression) -> TelemetryPayload {
        .adImpression(
            format: impression.format, site: impression.site, micros: impression.valueMicros,
            currency: impression.currency, precision: impression.precision, source: impression.adSource)
    }
}

/// Una fila de `public.telemetry_events` (C4): las claves JSON son las columnas.
///
/// El único identificador es el UUID de instalación propio (`InstallIdentity`): ni IDFA, ni IDFV,
/// ni el nombre del ranking.
struct TelemetryEvent: Codable, Sendable, Equatable {
    let installId: String
    let sessionId: String
    let clientTs: Date
    let name: TelemetryEventName
    let appVersion: String
    let build: String
    let osVersion: String
    let deviceModel: String
    let storefront: String?
    let props: [String: TelemetryValue]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case installId = "install_id"
        case sessionId = "session_id"
        case clientTs = "client_ts"
        case name
        case appVersion = "app_version"
        case build
        case osVersion = "os_version"
        case deviceModel = "device_model"
        case storefront
        case props
    }

    /// La hora va en segundos enteros: es lo que viaja (ISO 8601) y lo que vuelve de la cola.
    init(_ payload: TelemetryPayload, installId: String, sessionId: UUID, at date: Date, device: TelemetryDevice) {
        self.installId = installId
        self.sessionId = sessionId.uuidString.lowercased()
        clientTs = Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
        name = payload.name
        appVersion = device.appVersion
        build = device.build
        osVersion = device.osVersion
        deviceModel = device.deviceModel
        storefront = device.storefront
        props = payload.props
    }

    /// `storefront` sale como `null` en vez de faltar: PostgREST exige las mismas claves en
    /// todas las filas de un insert de varias.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(installId, forKey: .installId)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(clientTs, forKey: .clientTs)
        try container.encode(name, forKey: .name)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(build, forKey: .build)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encode(deviceModel, forKey: .deviceModel)
        try container.encode(storefront, forKey: .storefront)
        try container.encode(props, forKey: .props)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
