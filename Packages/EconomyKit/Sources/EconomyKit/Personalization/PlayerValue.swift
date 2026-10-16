import Foundation

/// Cuánto vale en promedio un video de este jugador y en qué segmento queda (2.1 E15 F1, contratos
/// C1 y C2). Puro y determinista: mismas entradas y tablas, mismo resultado. No lee el reloj: el
/// «una vez por día» lo maneja el servicio de la app (T5).
public enum PlayerValue {
    /// Multiplicador del valor del país por el tier del aparato, cuando todavía no hay impresiones
    /// propias: 1 → ×1,0; 2 → ×0,8; 3 → ×0,6.
    public static func deviceMultiplier(tier: Int) -> Double {
        switch tier {
        case ...1: 1.0
        case 2: 0.8
        default: 0.6
        }
    }

    /// Evalúa al jugador. `previous` es el segmento del último cálculo (nil o `.base` = no hubo):
    /// con él aplica la histéresis y el tope de un escalón por evaluación. Nunca devuelve `.base`.
    public static func evaluate(
        _ inputs: PlayerValueInputs,
        tables: PlayerValueTables,
        previous: PlayerSegment?
    ) -> PlayerValueEstimate {
        let expected = expectedMicrosPerVideo(inputs, tables: tables)
        let score = score(inputs, expectedMicros: expected, tables: tables)
        return PlayerValueEstimate(
            segment: segment(forScore: score, tables: tables, previous: previous),
            expectedMicrosPerVideo: expected,
            score: score,
            tablesVersion: tables.version
        )
    }

    /// Con `minOwnImpressions` o más: `ownWeight × promedio propio + (1 − ownWeight) × país`.
    /// Si no: el valor del país por el multiplicador del aparato.
    public static func expectedMicrosPerVideo(_ inputs: PlayerValueInputs, tables: PlayerValueTables) -> Int64 {
        let country = Double(max(0, tables.countryMicros(for: inputs.storefront)))
        let own = Double(max(0, inputs.averageRewardedMicros))
        let value: Double
        if max(0, inputs.rewardedCount) >= tables.minOwnImpressions {
            value = tables.ownWeight * own + (1 - tables.ownWeight) * country
        } else {
            value = country * deviceMultiplier(tier: tables.resolvedDeviceTier(model: inputs.deviceModel))
        }
        return micros(value)
    }

    /// `weights.value × norm(valor) + weights.engagement × norm(sesiones, duración) +
    /// weights.purchase × (compró ? 1 : 0)`, en 0…1. El engagement es el promedio de sus dos
    /// mitades, cada una saturada en 1.
    public static func score(_ inputs: PlayerValueInputs, expectedMicros: Int64, tables: PlayerValueTables) -> Double {
        let value = saturated(Double(max(0, expectedMicros)), at: Double(tables.topTierMicros))
        let sessions = saturated(Double(max(0, inputs.sessionsLast7Days)), at: Double(tables.engagement.sessionsFor1))
        let seconds = saturated(sane(inputs.meanSessionSeconds), at: tables.engagement.secondsFor1)
        let engagement = (sessions + seconds) / 2
        let purchase: Double = inputs.hasPurchased ? 1 : 0
        let total = tables.weights.value * value
            + tables.weights.engagement * engagement
            + tables.weights.purchase * purchase
        return min(1, max(0, sane(total)))
    }

    /// El segmento de un score. Sin anterior: `< mid` → `low`; `< high` → `mid`; si no, `high`.
    /// Con anterior: para subir, el score tiene que pasar el umbral por `hysteresis`; para bajar,
    /// quedar `hysteresis` por debajo; y nunca se mueve más de un escalón.
    public static func segment(forScore rawScore: Double, tables: PlayerValueTables, previous: PlayerSegment?) -> PlayerSegment {
        let score = sane(rawScore)
        let mid = tables.thresholds.mid
        let high = tables.thresholds.high
        guard let previous, previous != .base else { return bucket(score, mid: mid, high: high) }

        let margin = tables.hysteresis
        let up = bucket(score, mid: mid + margin, high: high + margin)
        let down = bucket(score, mid: mid - margin, high: high - margin)
        let target: PlayerSegment
        if up > previous {
            target = up
        } else if down < previous {
            target = down
        } else {
            target = previous
        }
        return step(from: previous, toward: target)
    }

    // MARK: - Privado

    private static let ladder: [PlayerSegment] = [.low, .mid, .high]

    private static func bucket(_ score: Double, mid: Double, high: Double) -> PlayerSegment {
        if score < mid { return .low }
        if score < high { return .mid }
        return .high
    }

    private static func step(from previous: PlayerSegment, toward target: PlayerSegment) -> PlayerSegment {
        guard let from = ladder.firstIndex(of: previous), let to = ladder.firstIndex(of: target) else { return target }
        if to > from { return ladder[from + 1] }
        if to < from { return ladder[from - 1] }
        return previous
    }

    /// `NaN`, infinitos y negativos valen 0.
    private static func sane(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : 0
    }

    private static func saturated(_ value: Double, at full: Double) -> Double {
        guard full > 0, full.isFinite else { return 0 }
        return min(1, sane(value) / full)
    }

    /// A micros enteros sin desbordar: lo que no es finito o positivo es 0; lo enorme, `Int64.max`.
    private static func micros(_ value: Double) -> Int64 {
        guard value.isFinite, value > 0 else { return 0 }
        guard value < Double(Int64.max) else { return Int64.max }
        return Int64(value.rounded())
    }
}
