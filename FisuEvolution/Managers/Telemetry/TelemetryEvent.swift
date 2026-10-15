import Foundation

/// Los seis eventos que existen (C4). Un nombre nuevo es un cambio de contrato: también lo es en
/// el `check` de la tabla.
enum TelemetryEventName: String, Codable, Sendable, CaseIterable {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case adImpression = "ad_impression"
    case offer
    case purchase
    case prestige
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

    /// Un código ISO 4217: tres letras en mayúscula, o vacío.
    static func currency(_ raw: String) -> TelemetryValue {
        let letters = raw.uppercased().unicodeScalars.filter { $0.isASCII && CharacterSet.uppercaseLetters.contains($0) }
        return .string(letters.count == 3 ? String(letters) : "")
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
    /// C1, en crudo: `format`/`precision` son los `rawValue` de `AdFormat`/`AdValuePrecision`.
    case adImpression(format: String, site: String, micros: Int64, currency: String, precision: String, source: String?)
    /// C3: `stage` es el `rawValue` de `OfferStage`.
    case offer(site: String, stage: String)
    /// Sólo el producto: ni precio ni transacción.
    case purchase(product: String)
    /// Las reencarnaciones de la cuenta.
    case prestige(count: Int)

    var name: TelemetryEventName {
        switch self {
        case .sessionStart: .sessionStart
        case .sessionEnd: .sessionEnd
        case .adImpression: .adImpression
        case .offer: .offer
        case .purchase: .purchase
        case .prestige: .prestige
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
                "format": .token(format, maxLength: 32),
                "site": .token(site),
                "micros": .int(micros),
                "currency": .currency(currency),
                "precision": .token(precision, maxLength: 32),
            ]
            if let source { values["source"] = .token(source, maxLength: 32) }
            return values
        case .offer(let site, let stage):
            return ["site": .token(site), "stage": .token(stage, maxLength: 32)]
        case .purchase(let product):
            return ["product": .token(product, maxLength: 128)]
        case .prestige(let count):
            return ["count": .int(Int64(count))]
        }
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
