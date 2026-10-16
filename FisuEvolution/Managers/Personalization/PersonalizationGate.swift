import EconomyKit
import Foundation

/// La compuerta de la personalización (2.1 E15 F1, contrato C4). Pura: todos los insumos vienen de
/// afuera, así que cada combinación se prueba sin red ni SDK.
///
/// Abre sólo si todo es cierto a la vez: el interruptor remoto dijo que sí, hay consentimiento
/// (`PersonalizationConsent`), no hay señal de menor de edad (V10: no se pide edad; si UMP o el SDK
/// de anuncios traen la etiqueta, `base`), no es un UI test (`--uitest*`) y no es un build `DEBUG`
/// (salvo `--personalization-debug`). Cerrada, el segmento es `base`: el juego de la 2.0.
///
/// `--uitest-segment <s>` fuerza el segmento y saltea todo lo demás: es lo que usan los UI tests de
/// las palancas. Un valor que no es un segmento fuerza `base`.
struct PersonalizationGate: Sendable, Equatable {
    static let debugOverride = "--personalization-debug"
    static let forcedSegmentArgument = "--uitest-segment"

    var remoteEnabled: Bool
    var consentAllows: Bool
    var underAgeSignal: Bool
    var arguments: [String]
    var isDebug: Bool

    var isOpen: Bool {
        remoteEnabled && consentAllows && !underAgeSignal && !isUITest
            && (!isDebug || arguments.contains(Self.debugOverride))
    }

    /// El segmento que fuerza `--uitest-segment <s>`; `nil` sin el flag. Sin valor o con uno raro: `base`.
    var forcedSegment: PlayerSegment? {
        guard let index = arguments.firstIndex(of: Self.forcedSegmentArgument) else { return nil }
        let value = arguments.dropFirst(index + 1).first ?? ""
        return PlayerSegment(rawValue: value) ?? .base
    }

    /// El segmento que vive el jugador: el forzado, si hay; si no, el de las reglas con la compuerta
    /// abierta; si no, `base`. Sin segmento calculado todavía, `base`.
    func segment(ruled: PlayerSegment?) -> PlayerSegment {
        if let forcedSegment { return forcedSegment }
        guard isOpen, let ruled else { return .base }
        return ruled
    }

    /// La señal de menor de edad (V10): cualquiera de las etiquetas de menores del SDK de anuncios
    /// (`tagForUnderAgeOfConsent`, `tagForChildDirectedTreatment`) en `true`. Sin etiquetas, no hay
    /// señal: el juego es 12+ y no pide edad.
    static func underAgeSignal(tagForUnderAgeOfConsent: Bool?, tagForChildDirectedTreatment: Bool?) -> Bool {
        tagForUnderAgeOfConsent == true || tagForChildDirectedTreatment == true
    }

    private var isUITest: Bool {
        arguments.contains { $0.hasPrefix("--uitest") }
    }
}
