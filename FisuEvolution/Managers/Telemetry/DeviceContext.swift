import Foundation
import StoreKit

/// Las columnas del aparato en cada evento (C4), ya recortadas a los largos de la tabla.
struct TelemetryDevice: Sendable, Equatable {
    let appVersion: String
    let build: String
    let osVersion: String
    let deviceModel: String
    /// ISO 3166-1 alfa-3 (`Storefront.countryCode`), o `nil` si no hay o no tiene esa forma.
    let storefront: String?

    init(appVersion: String, build: String, osVersion: String, deviceModel: String, storefront: String?) {
        self.appVersion = String(appVersion.prefix(16))
        self.build = String(build.prefix(16))
        self.osVersion = String(osVersion.prefix(16))
        self.deviceModel = String(deviceModel.prefix(32))
        self.storefront = storefront.flatMap(Self.storefrontCode)
    }

    private static func storefrontCode(_ raw: String) -> String? {
        let code = raw.uppercased()
        let letters = code.unicodeScalars.filter { $0.isASCII && CharacterSet.uppercaseLetters.contains($0) }
        return code.unicodeScalars.count == 3 && letters.count == 3 ? code : nil
    }
}

/// Junta el contexto del aparato una vez por proceso. La tienda es asíncrona (StoreKit), así que
/// todo se lee la primera vez que hace falta, fuera del main actor.
actor DeviceContext {
    typealias StorefrontLookup = @Sendable () async -> String?

    private let appVersion: String
    private let build: String
    private let osVersion: String
    private let deviceModel: String
    private let storefrontLookup: StorefrontLookup
    private var cached: TelemetryDevice?

    init(
        appVersion: String = DeviceContext.bundleString("CFBundleShortVersionString"),
        build: String = DeviceContext.bundleString("CFBundleVersion"),
        osVersion: String = DeviceContext.systemVersion,
        deviceModel: String = DeviceContext.machineIdentifier,
        storefront: @escaping StorefrontLookup = { await Storefront.current?.countryCode }
    ) {
        self.appVersion = appVersion
        self.build = build
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        storefrontLookup = storefront
    }

    func snapshot() async -> TelemetryDevice {
        if let cached { return cached }
        let device = TelemetryDevice(
            appVersion: appVersion, build: build, osVersion: osVersion,
            deviceModel: deviceModel, storefront: await storefrontLookup()
        )
        cached = device
        return device
    }

    nonisolated static func bundleString(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "0"
    }

    /// Lo mismo que `UIDevice.current.systemVersion` («18.2», «18.2.1»), sin pasar por el main actor.
    nonisolated static var systemVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let base = "\(version.majorVersion).\(version.minorVersion)"
        return version.patchVersion > 0 ? "\(base).\(version.patchVersion)" : base
    }

    /// El identificador de máquina (`iPhone16,2`); en el simulador, el del modelo simulado.
    nonisolated static var machineIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
