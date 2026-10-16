import Foundation

/// Las features del modelo v2 del valor por jugador (2.1 E15 F6), con nombre y orden fijos. Son el
/// contrato con `Tools/player-value-model/train.py` (`FEATURES`): mismo nombre, mismo orden, misma
/// semántica que las columnas de `export.sql`. Cambiar una es una versión nueva.
public enum PlayerValueFeatures {
    public static let version = "pvf-1"

    /// El orden de `FEATURES` en `train.py`.
    public static let names = [
        "country_tier",
        "device_tier",
        "sessions_7d",
        "mean_session_seconds",
        "rewarded_count",
        "avg_rewarded_micros",
        "has_purchased",
        "offers_seen",
        "prestige_count",
    ]

    /// Las features por nombre. Lo que en el export sale `NULL` (un promedio sin eventos) acá es `NaN`,
    /// y el árbol lo manda por `default_left`, igual que en el entrenamiento.
    public static func features(from inputs: PlayerValueInputs, tables: PlayerValueTables) -> [String: Double] {
        let rewarded = max(0, inputs.rewardedCount)
        return [
            "country_tier": Double(tables.resolvedCountryTier(storefront: inputs.storefront)),
            "device_tier": Double(tables.resolvedDeviceTier(model: inputs.deviceModel)),
            "sessions_7d": Double(max(0, inputs.sessionsLast7Days)),
            "mean_session_seconds": positiveOrNaN(inputs.meanSessionSeconds),
            "rewarded_count": Double(rewarded),
            "avg_rewarded_micros": rewarded > 0 ? Double(max(0, inputs.averageRewardedMicros)) : .nan,
            "has_purchased": inputs.hasPurchased ? 1 : 0,
            "offers_seen": Double(max(0, inputs.offersSeenLast7Days)),
            "prestige_count": Double(max(0, inputs.prestigesLast7Days)),
        ]
    }

    /// El vector en el orden que pide `model.features`. `nil` si el modelo pide una feature que no
    /// existe: ese modelo no sirve y se usan las reglas.
    public static func vector(for model: TreeEnsemble, from features: [String: Double]) -> [Double]? {
        var vector: [Double] = []
        vector.reserveCapacity(model.features.count)
        for name in model.features {
            guard let value = features[name] else { return nil }
            vector.append(value)
        }
        return vector
    }

    /// `true` si todas las features que pide el modelo existen.
    public static func supports(_ model: TreeEnsemble) -> Bool {
        model.features.allSatisfy(names.contains)
    }

    private static func positiveOrNaN(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : .nan
    }
}
