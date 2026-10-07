import Foundation

/// Los tres formatos que el jugador no pide: los que `remove_ads` saca y los
/// que sólo pueden caer en un corte natural (PLAN-v2 §2).
enum ForcedAdFormat: String, Codable, Sendable, CaseIterable {
    /// El intersticial común.
    case interstitial
    /// La pausa publicitaria: intersticial bonificado, con pantalla previa.
    case rewardedInterstitial
    /// El anuncio al volver a la app.
    case appOpen
}

/// La configuración de anuncios que se cambia **sin pasar por Apple**: IDs,
/// cadencia, alternancia, app open, interruptores de apagado y las tiendas
/// donde se apaga el azar con ORO.
///
/// Se publica en `adergames-site` (`/config/ads.json`) y el bundle trae una
/// copia con la misma forma (`Resources/Config/ads.json`), que es el respaldo
/// cuando no hay red ni caché. Quien la baja, la valida y la guarda es
/// `AdsRemoteConfigLoader`.
///
/// ## El archivo remoto no es de confianza, y por eso se valida entero
///
/// Un JSON publicado en un sitio es un JSON que se puede romper, pisar o
/// publicar a medias. Lo que no puede pasar es que un error ahí le haga daño
/// al juego o a la cuenta de AdMob, así que las reglas son de todo o nada:
///
/// - **Cada ID tiene que ser del publisher propio** (el `ca-app-pub-…` de
///   `GADApplicationIdentifier`). Un ID ajeno es plata que va a otra cuenta;
///   uno mal tipeado es un lugar sin anuncios. Con UNO que falle, se descarta
///   el archivo entero: aplicar la mitad buena de un archivo roto es mezclar
///   dos versiones que nadie probó juntas.
/// - **Los números no pueden ser más agresivos que las decisiones del dueño**
///   (ver `Floor`). Lo remoto puede espaciar más los anuncios, nunca menos: un
///   `0` publicado por error no puede convertir el juego en una ametralladora
///   de intersticiales, que es política de AdMob y desinstalaciones.
struct AdsRemoteConfig: Codable, Sendable, Equatable {

    /// La cadencia común a los tres formatos forzados.
    struct Cadence: Codable, Sendable, Equatable {
        /// Segundos entre dos forzados, **de cualquier formato** (el
        /// `lastFullScreenAt` es uno solo).
        let minSecondsBetweenForced: Double
        /// Gracia al arrancar la app o al volver del background, para el
        /// intersticial y la pausa (el app open no la mira: su momento es
        /// justamente la vuelta).
        let graceSecondsAfterLaunch: Double
        /// Gracia después de un video con premio que el jugador eligió mirar.
        let graceSecondsAfterRewarded: Double
    }

    /// Las reglas propias del app open.
    struct AppOpen: Codable, Sendable, Equatable {
        /// Cuánto tiene que haber estado afuera para que la vuelta cuente.
        let minSecondsAway: Double
        /// Como máximo uno cada tanto.
        let minSecondsBetween: Double
        /// Desde qué arranque de la app (contando el primero como 1).
        let minSessionNumber: Int
    }

    /// Los interruptores de apagado, uno por formato forzado. `false` apaga
    /// el formato en todos los jugadores sin build nuevo.
    struct Switches: Codable, Sendable, Equatable {
        let interstitial: Bool
        let rewardedInterstitial: Bool
        let appOpen: Bool

        func isOn(_ format: ForcedAdFormat) -> Bool {
            switch format {
            case .interstitial: interstitial
            case .rewardedInterstitial: rewardedInterstitial
            case .appOpen: appOpen
            }
        }
    }

    /// Los pisos de lo remoto: las decisiones del dueño (PLAN-v2 §2) como
    /// mínimos. Un archivo que baje de alguno se descarta entero.
    enum Floor {
        /// "Cada ≥2 min".
        static let minSecondsBetweenForced: Double = 120
        /// "Gracia de 90 s después de un bonificado".
        static let graceSecondsAfterRewarded: Double = 90
        /// "Al volver tras ≥3 min afuera".
        static let appOpenMinSecondsAway: Double = 180
        /// "Como máximo 1 cada 20 min".
        static let appOpenMinSecondsBetween: Double = 20 * 60
        /// "Desde la 2ª sesión; nunca en el primer arranque".
        static let appOpenMinSessionNumber = 2
        /// Un patrón de alternancia más largo que esto no es una alternancia.
        static let maxAlternationLength = 8
    }

    /// Por qué se descartó un archivo. Es `Equatable` para que los tests
    /// distingan "se rechazó por el ID ajeno" de "se rechazó por cualquier
    /// otra cosa".
    enum Rejection: Error, Equatable, Sendable {
        case unsupportedSchema(Int)
        /// No se pudo leer el publisher propio del `Info.plist`: sin él no hay
        /// contra qué validar, y no se acepta nada.
        case unknownPublisher
        case foreignAdUnit(String)
        case belowFloor(String)
        case invalidAlternation
        case invalidStorefront(String)
        case undecodable
        case notHTTPS
        case badResponse
        case tooLarge
    }

    static let supportedSchemaVersion = 1

    let schemaVersion: Int
    let adUnitIDs: FeatureFlags.AdUnitIDs
    let cadence: Cadence
    /// El orden en que se turnan los dos intersticiales en los cortes
    /// naturales. `["interstitial", "rewardedInterstitial"]` es "uno y uno";
    /// `["interstitial", "interstitial", "rewardedInterstitial"]`, "dos
    /// comunes por cada pausa". El app open no entra: tiene su propio corte.
    let alternation: [ForcedAdFormat]
    let appOpen: AppOpen
    let switches: Switches
    /// Los códigos de tienda (ISO 3166-1 alfa-3, como `Storefront.countryCode`)
    /// donde se apagan los giros extra y los cofres por ORO (decisión "loot
    /// boxes" de PLAN-v2 §2: Bélgica y Australia).
    let restrictedStorefronts: [String]

    /// Si en esa tienda se apagan el azar con ORO.
    func isRestricted(storefront countryCode: String) -> Bool {
        restrictedStorefronts.contains(countryCode.uppercased())
    }

    // MARK: - Validación

    /// Decodifica y valida. Lanza `Rejection` con el primer motivo encontrado.
    static func decodeValidated(_ data: Data, publisherID: String?) throws -> AdsRemoteConfig {
        let config: AdsRemoteConfig
        do {
            config = try JSONDecoder().decode(AdsRemoteConfig.self, from: data)
        } catch {
            throw Rejection.undecodable
        }
        try config.validate(publisherID: publisherID)
        return config
    }

    func validate(publisherID: String?) throws {
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw Rejection.unsupportedSchema(schemaVersion)
        }
        guard let publisherID, !publisherID.isEmpty else { throw Rejection.unknownPublisher }
        for unitID in adUnitIDs.allDeclared where !Self.isAdUnit(unitID, of: publisherID) {
            throw Rejection.foreignAdUnit(unitID)
        }

        let floors: [(String, Bool)] = [
            ("cadence.minSecondsBetweenForced", cadence.minSecondsBetweenForced >= Floor.minSecondsBetweenForced),
            ("cadence.graceSecondsAfterLaunch", cadence.graceSecondsAfterLaunch >= 0),
            ("cadence.graceSecondsAfterRewarded", cadence.graceSecondsAfterRewarded >= Floor.graceSecondsAfterRewarded),
            ("appOpen.minSecondsAway", appOpen.minSecondsAway >= Floor.appOpenMinSecondsAway),
            ("appOpen.minSecondsBetween", appOpen.minSecondsBetween >= Floor.appOpenMinSecondsBetween),
            ("appOpen.minSessionNumber", appOpen.minSessionNumber >= Floor.appOpenMinSessionNumber),
        ]
        // `>=` ya descarta NaN (toda comparación con NaN es falsa); el
        // infinito se descarta aparte porque apagaría el formato en silencio,
        // y para eso están los interruptores.
        let numbers = [
            cadence.minSecondsBetweenForced, cadence.graceSecondsAfterLaunch,
            cadence.graceSecondsAfterRewarded, appOpen.minSecondsAway, appOpen.minSecondsBetween,
        ]
        if let field = floors.first(where: { !$0.1 })?.0 { throw Rejection.belowFloor(field) }
        guard numbers.allSatisfy(\.isFinite) else { throw Rejection.belowFloor("valor infinito") }

        guard !alternation.isEmpty,
              alternation.count <= Floor.maxAlternationLength,
              !alternation.contains(.appOpen)
        else { throw Rejection.invalidAlternation }

        for code in restrictedStorefronts where !Self.isStorefrontCode(code) {
            throw Rejection.invalidStorefront(code)
        }
    }

    /// `ca-app-pub-<publisher>/<dígitos>`, y nada más.
    static func isAdUnit(_ unitID: String, of publisherID: String) -> Bool {
        let prefix = "ca-app-pub-\(publisherID)/"
        guard unitID.hasPrefix(prefix) else { return false }
        let unit = unitID.dropFirst(prefix.count)
        return !unit.isEmpty && unit.allSatisfy(\.isASCIIDigit)
    }

    private static func isStorefrontCode(_ code: String) -> Bool {
        code.count == 3 && code.allSatisfy { $0.isASCII && $0.isUppercase && $0.isLetter }
    }

    // MARK: - El publisher propio

    /// El publisher de un App ID de AdMob (`ca-app-pub-<publisher>~<app>`).
    ///
    /// ⚠️ El App ID lleva `~` y las unidades `/`: es el mismo número de
    /// publisher con distinto separador, y por eso se puede validar una unidad
    /// contra el App ID.
    static func publisherID(fromAppID appID: String) -> String? {
        let prefix = "ca-app-pub-"
        guard appID.hasPrefix(prefix) else { return nil }
        let parts = appID.dropFirst(prefix.count).split(separator: "~", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let publisher = parts.first, !publisher.isEmpty, publisher.allSatisfy(\.isASCIIDigit),
              let app = parts.last, !app.isEmpty, app.allSatisfy(\.isASCIIDigit)
        else { return nil }
        return String(publisher)
    }

    /// El publisher de ESTA app, leído del `GADApplicationIdentifier` del
    /// `Info.plist`, que es el mismo que usa el SDK.
    static var ownPublisherID: String? {
        (Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String)
            .flatMap(publisherID(fromAppID:))
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
