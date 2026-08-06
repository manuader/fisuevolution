import Foundation

/// La pieza ÚNICA que traduce un efecto —de mejora permanente o de boost— al
/// número que se muestra, más su formateador (RF-06).
///
/// Vive en la capa de app y no en EconomyKit a propósito: `UpgradesConfig.EffectType`,
/// `BoostsConfig.EffectType` y los topes viven en `ContentConfigs.swift`/`ContentSystems.swift`,
/// que son de la app. Mudarla al paquete obligaría a que la economía pura conozca
/// el formato de presentación — justo lo que prohíbe la regla de capas del HANDOFF §3.

// MARK: - Topes

/// Topes de los efectos acumulados. Son la MISMA fuente que usa
/// `ContentSystems.recomputeDerivedEffects`: si se duplican, la fila de la UI
/// termina prometiendo un efecto que la economía recorta.
enum EffectCaps {
    static let crit = 0.5
    static let offline = 1.0
    static let golden = 0.1
    static let spawnDiscount = 0.6
}

// MARK: - El valor mostrable

/// Qué unidad tiene el número, que es lo que decide su signo y su símbolo.
/// `.percentBonus` suma ("+30%"), `.percentDiscount` resta ("−30%"),
/// `.chance` es una probabilidad a secas ("3%") y `.multiplier` es un factor ("×2,5").
enum EffectUnit: Equatable {
    case percentBonus
    case percentDiscount
    case chance
    case multiplier
}

struct EffectAmount: Equatable {
    let unit: EffectUnit
    /// 0,30 significa 30%. Para `.multiplier`, 2,5 significa ×2,5.
    let value: Double
    /// El cap de ContentSystems ya recortó este valor.
    let isCapped: Bool
}

// MARK: - La traducción

enum EffectDescriptor {
    /// Mejoras permanentes: el efecto es aditivo por nivel.
    static func amount(for effectType: UpgradesConfig.EffectType, level: Int, magnitudePerLevel: Double) -> EffectAmount {
        let raw = Double(level) * magnitudePerLevel
        switch effectType {
        case .incomeMultiplier, .tapMultiplier, .prestigeBonusPerSoulPoint:
            return EffectAmount(unit: .percentBonus, value: raw, isCapped: false)
        case .critChance:
            return EffectAmount(unit: .chance, value: min(raw, EffectCaps.crit), isCapped: raw > EffectCaps.crit)
        case .goldenTouchChance:
            return EffectAmount(unit: .chance, value: min(raw, EffectCaps.golden), isCapped: raw > EffectCaps.golden)
        case .offlineEfficiency:
            return EffectAmount(unit: .percentBonus, value: min(raw, EffectCaps.offline), isCapped: raw > EffectCaps.offline)
        case .spawnCostDiscount:
            return EffectAmount(unit: .percentDiscount, value: min(raw, EffectCaps.spawnDiscount), isCapped: raw > EffectCaps.spawnDiscount)
        }
    }

    /// Boosts: el efecto es la magnitud sola, no depende de ningún nivel.
    static func amount(forBoost effectType: BoostsConfig.EffectType, magnitude: Double) -> EffectAmount {
        switch effectType {
        case .incomeMultiplier, .tapMultiplier, .periodicChest:
            return EffectAmount(unit: .multiplier, value: magnitude, isCapped: false)
        case .spawnCostMultiplier:
            // La magnitud es un FACTOR de costo (0,7 = cuesta 0,7×). Mostrarla
            // cruda deja al jugador leyendo "0,7" y adivinando si es bueno.
            return EffectAmount(unit: .percentDiscount, value: 1 - magnitude, isCapped: false)
        case .offlineEfficiencyPermanent:
            return EffectAmount(unit: .percentBonus, value: magnitude, isCapped: false)
        }
    }
}

// Ninguno de los dos `switch` de arriba lleva `default`. Es a propósito: cuando
// alguien agregue un tipo de efecto nuevo, el compilador lo va a mandar acá en
// vez de dejarlo salir a pantalla sin descripción.

// MARK: - El formato

enum EffectFormatter {
    /// "+30%", "−9%", "3%", "×2,5"
    static func text(_ amount: EffectAmount) -> String {
        let percent = Int((amount.value * 100).rounded())
        switch amount.unit {
        case .percentBonus: return "+\(percent)%"
        case .percentDiscount: return "−\(percent)%" // menos tipográfico, no guion
        case .chance: return "\(percent)%"
        case .multiplier:
            let formatted = amount.value.formatted(.number.precision(.fractionLength(0...1)))
            return "×\(formatted)"
        }
    }

    /// "+30% → +40%", o sólo "+30%" cuando `next` es nil (nivel máximo).
    static func progression(current: EffectAmount, next: EffectAmount?) -> String {
        guard let next else { return text(current) }
        return String(localized: "effect.progression \(text(current)) \(text(next))")
    }

    /// La etiqueta de "ya no sube más", para las filas cuyo `EffectAmount`
    /// viene con `isCapped`. Está acá y no en cada pantalla por lo mismo que
    /// todo lo demás de este archivo: tres frentes la escribirían distinto.
    static var cappedNote: String {
        String(localized: "effect.capped")
    }
}
