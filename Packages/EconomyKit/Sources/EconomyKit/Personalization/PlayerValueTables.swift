import Foundation

/// Las tablas con que se estima el valor de un jugador (2.1 E15 F1, contrato C2). Llegan por la
/// config remota (sección `player_value`) con respaldo en el bundle (`player_value.json`). Un
/// archivo que no pasa `validate()` no se usa entero: no hay arreglos a medias.
public struct PlayerValueTables: Codable, Sendable, Equatable {
    /// Cuánto pesa cada parte del score; suman 1.
    public struct Weights: Codable, Sendable, Equatable {
        public var value: Double
        public var engagement: Double
        public var purchase: Double

        public init(value: Double, engagement: Double, purchase: Double) {
            self.value = value
            self.engagement = engagement
            self.purchase = purchase
        }
    }

    /// Dónde satura en 1 cada mitad del engagement.
    public struct Engagement: Codable, Sendable, Equatable {
        /// Sesiones en los últimos 7 días que valen 1.
        public var sessionsFor1: Int
        /// Duración media de sesión, en segundos, que vale 1.
        public var secondsFor1: Double

        public init(sessionsFor1: Int, secondsFor1: Double) {
            self.sessionsFor1 = sessionsFor1
            self.secondsFor1 = secondsFor1
        }
    }

    /// Los cortes del score: `< mid` → `low`; `< high` → `mid`; si no, `high`.
    public struct Thresholds: Codable, Sendable, Equatable {
        public var mid: Double
        public var high: Double

        public init(mid: Double, high: Double) {
            self.mid = mid
            self.high = high
        }
    }

    /// Viaja en el evento `segment` (`ver`): un token de hasta 32 caracteres.
    public var version: String
    /// ISO alfa-3 → tier de eCPM (1 = el que más paga).
    public var countryTier: [String: Int]
    public var defaultCountryTier: Int
    /// Tier (como texto: `"1"`, `"2"`, …) → micros que paga un video en ese tier.
    public var tierMicros: [String: Int64]
    /// Prefijo de `utsname.machine` → tier del aparato (1…3); gana el prefijo más largo.
    public var deviceTier: [String: Int]
    public var defaultDeviceTier: Int
    /// Desde cuántas impresiones propias se mezcla el promedio del jugador con el del país.
    public var minOwnImpressions: Int
    /// Cuánto pesa el promedio propio en esa mezcla.
    public var ownWeight: Double
    public var engagement: Engagement
    public var weights: Weights
    public var thresholds: Thresholds
    /// Cuánto tiene que pasar el score un umbral para cambiar de escalón.
    public var hysteresis: Double

    public static let maxVersionLength = 32
    public static let maxHysteresis = 0.2
    public static let weightsTolerance = 0.001
    /// Los tiers de aparato que existen: cada uno con su multiplicador en `PlayerValue`.
    public static let deviceTiers = 1...3

    public init(
        version: String,
        countryTier: [String: Int],
        defaultCountryTier: Int,
        tierMicros: [String: Int64],
        deviceTier: [String: Int],
        defaultDeviceTier: Int,
        minOwnImpressions: Int,
        ownWeight: Double,
        engagement: Engagement,
        weights: Weights,
        thresholds: Thresholds,
        hysteresis: Double
    ) {
        self.version = version
        self.countryTier = countryTier
        self.defaultCountryTier = defaultCountryTier
        self.tierMicros = tierMicros
        self.deviceTier = deviceTier
        self.defaultDeviceTier = defaultDeviceTier
        self.minOwnImpressions = minOwnImpressions
        self.ownWeight = ownWeight
        self.engagement = engagement
        self.weights = weights
        self.thresholds = thresholds
        self.hysteresis = hysteresis
    }

    // MARK: - Consultas

    /// El tier del país de la tienda; el de por defecto si no se sabe o no está en la tabla.
    public func resolvedCountryTier(storefront: String?) -> Int {
        guard let code = storefront?.uppercased() else { return defaultCountryTier }
        return countryTier[code] ?? defaultCountryTier
    }

    /// Lo que paga un video en el país de la tienda; 0 si el tier no tiene precio (no pasa con
    /// tablas validadas).
    public func countryMicros(for storefront: String?) -> Int64 {
        tierMicros[String(resolvedCountryTier(storefront: storefront))] ?? 0
    }

    /// El tier del aparato por el prefijo más largo de `model` que esté en la tabla
    /// (`iPhone16,2` → `iPhone16,`); el de por defecto si no hay ninguno.
    public func resolvedDeviceTier(model: String?) -> Int {
        guard let model, !model.isEmpty else { return defaultDeviceTier }
        let match = deviceTier
            .filter { !$0.key.isEmpty && model.hasPrefix($0.key) }
            .max { lhs, rhs in
                lhs.key.count != rhs.key.count ? lhs.key.count < rhs.key.count : lhs.key > rhs.key
            }
        return match?.value ?? defaultDeviceTier
    }

    /// Lo que paga un video en el mejor tier: el techo con que se normaliza el valor del score.
    public var topTierMicros: Int64 {
        tierMicros["1"] ?? 0
    }

    // MARK: - Validación

    public enum ValidationError: Error, Equatable {
        case badVersion
        case weightsMustSumToOne(Double)
        case negativeWeight(String)
        case badThresholds
        case badTierKey(String)
        case nonPositiveTierMicros(String)
        case missingTopTier
        case badCountryCode(String)
        case unknownCountryTier(String)
        case badDeviceTier(String)
        case outOfRange(String)
    }

    /// Todo o nada: la primera regla rota invalida el archivo entero.
    public func validate() throws {
        guard !version.isEmpty, version.count <= Self.maxVersionLength,
              version.unicodeScalars.allSatisfy(Self.isTokenScalar)
        else { throw ValidationError.badVersion }

        for (name, weight) in [("value", weights.value), ("engagement", weights.engagement),
                               ("purchase", weights.purchase)] {
            guard weight >= 0, weight.isFinite else { throw ValidationError.negativeWeight(name) }
        }
        let total = weights.value + weights.engagement + weights.purchase
        guard abs(total - 1) <= Self.weightsTolerance else { throw ValidationError.weightsMustSumToOne(total) }

        guard thresholds.mid > 0, thresholds.mid < thresholds.high, thresholds.high < 1 else {
            throw ValidationError.badThresholds
        }

        for (key, micros) in tierMicros {
            guard let tier = Int(key), tier >= 1, String(tier) == key else { throw ValidationError.badTierKey(key) }
            guard micros > 0 else { throw ValidationError.nonPositiveTierMicros(key) }
        }
        guard topTierMicros > 0 else { throw ValidationError.missingTopTier }

        for (code, tier) in countryTier {
            guard Self.isCountryCode(code) else { throw ValidationError.badCountryCode(code) }
            guard tierMicros[String(tier)] != nil else { throw ValidationError.unknownCountryTier(code) }
        }
        guard tierMicros[String(defaultCountryTier)] != nil else {
            throw ValidationError.unknownCountryTier("defaultCountryTier")
        }

        for (prefix, tier) in deviceTier {
            guard !prefix.isEmpty, Self.deviceTiers.contains(tier) else { throw ValidationError.badDeviceTier(prefix) }
        }
        guard Self.deviceTiers.contains(defaultDeviceTier) else {
            throw ValidationError.badDeviceTier("defaultDeviceTier")
        }

        guard minOwnImpressions >= 1 else { throw ValidationError.outOfRange("minOwnImpressions") }
        guard (0...1).contains(ownWeight) else { throw ValidationError.outOfRange("ownWeight") }
        guard engagement.sessionsFor1 > 0 else { throw ValidationError.outOfRange("engagement.sessionsFor1") }
        guard engagement.secondsFor1 > 0, engagement.secondsFor1.isFinite else {
            throw ValidationError.outOfRange("engagement.secondsFor1")
        }
        guard (0...Self.maxHysteresis).contains(hysteresis) else { throw ValidationError.outOfRange("hysteresis") }
    }

    /// `^[A-Z]{3}$`.
    static func isCountryCode(_ code: String) -> Bool {
        code.unicodeScalars.count == 3 && code.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) }
    }

    /// Las mismas letras que acepta un token de la telemetría: ASCII alfanumérico y `._-:`.
    private static func isTokenScalar(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar) || ("0"..."9").contains(scalar)
            || "._-:".unicodeScalars.contains(scalar)
    }
}
