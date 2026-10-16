import Foundation

/// El jugador de un segmento para el simulador de ritmo (2.1 E15 F2, contrato C2; diseño de R7): las
/// palancas que ve (`SegmentLevers.Levers`) y qué fracción de las ofertas con video acepta.
///
/// El simulador recibe las fuentes **de la base** y les aplica las palancas él mismo
/// (`PacingSources.applying(_:)`): quien arma las fuentes no las aplica antes, o se aplicarían dos veces.
/// Con `segment: nil` el simulador corre el camino de la 2.0, sin tocar nada.
public struct PacingSegment: Sendable, Equatable {
    public var levers: SegmentLevers.Levers
    /// 0…1: la fracción de las ofertas con video que el bot acepta. Cada oferta se decide con una moneda
    /// determinista (la semilla de la corrida y el número de la oferta), nunca con el azar del sistema.
    public var acceptRate: Double

    public init(levers: SegmentLevers.Levers = .identity, acceptRate: Double = 1) {
        self.levers = levers
        self.acceptRate = min(1, max(0, acceptRate))
    }

    /// La base: las fuentes de siempre y todas las ofertas aceptadas. Da lo mismo que `segment: nil`.
    public static let identity = PacingSegment()

    /// La fracción de ofertas que acepta el jugador de referencia de cada segmento (R7). `base` las acepta
    /// todas: con `.ads` es el bot de la 2.0.
    public static func referenceAcceptRate(for segment: PlayerSegment) -> Double {
        switch segment {
        case .base, .high: 1
        case .mid: 0.6
        case .low: 0.25
        }
    }

    /// El jugador de referencia de un segmento con las palancas de un `segments.json` (o de los topes).
    public static func reference(_ segment: PlayerSegment, levers: SegmentLevers) -> PacingSegment {
        PacingSegment(levers: levers.levers(for: segment), acceptRate: referenceAcceptRate(for: segment))
    }

    /// Un punto del barrido de R7 (F2-T3/T5): el ×N por fuente (`rewardMultiplier`, las que faltan quedan
    /// en ×2) y `offerIntervalScale`, la escala de los relojes de las ayudas (colchón gratis, visitantes y
    /// costado; < 1 = más ofertas). Los forzados quedan como en la base.
    public static func sweep(
        rewardMultiplier: [SegmentLevers.Source: Double], offerIntervalScale: Double, acceptRate: Double = 1
    ) -> PacingSegment {
        PacingSegment(
            levers: SegmentLevers.Levers(
                videoRewardMultiplier: Dictionary(uniqueKeysWithValues: rewardMultiplier.map { ($0.key.rawValue, $0.value) }),
                freeMattressIntervalScale: offerIntervalScale,
                visitorIntervalScale: offerIntervalScale,
                sideRailCooldownScale: offerIntervalScale
            ),
            acceptRate: acceptRate
        )
    }

    /// La moneda de la oferta número `index`: `true` si el bot la acepta. Con `acceptRate` 1 siempre, con 0
    /// nunca; en el medio, la misma respuesta para la misma semilla y el mismo número de oferta.
    func accepts(offer index: Int, seedFraction: Double) -> Bool {
        accepts(index, seed: seedFraction.bitPattern)
    }

    /// La moneda de la oferta del momento número `index`: otra tirada, independiente de la de las otras ofertas.
    func accepts(momentOffer index: Int, seedFraction: Double) -> Bool {
        accepts(index, seed: ~seedFraction.bitPattern)
    }

    private func accepts(_ index: Int, seed: UInt64) -> Bool {
        if acceptRate >= 1 { return true }
        if acceptRate <= 0 { return false }
        var generator = SplitMix64(seed: seed ^ (UInt64(truncatingIfNeeded: index) &* 0x9E37_79B9_7F4A_7C15))
        let unit = Double(generator.next() >> 11) * 0x1p-53
        return unit < acceptRate
    }
}

extension PacingSources {
    /// Las fuentes con las palancas de un segmento, como las vería ese jugador: el ×N con video por fuente
    /// (offline, diario, carrera, el ×2 del colchón gratis y el «repetir premio» de la ruleta), el reloj del
    /// colchón gratis, las pausas del costado («Fusionar todo» y la lluvia) y el espaciado de la pausa
    /// publicitaria. Un ×N sólo crece donde el bot ya mira el video (multiplicador > 1). Con `.identity`
    /// devuelve exactamente las mismas fuentes (`==`).
    ///
    /// Los visitantes no los juega el bot: `visitorIntervalScale` y el ×N de `visit` se acotan por
    /// presupuesto (F2-T4), no acá.
    public func applying(_ levers: SegmentLevers.Levers) -> PacingSources {
        var result = self
        if let mattress = freeMattress, levers.freeMattressIntervalScale != 1 {
            result.freeMattress = TreasuresConfig(
                schemaVersion: mattress.schemaVersion,
                spawnIntervalSeconds: mattress.spawnIntervalSeconds,
                firstTreasureAfterSeconds: mattress.firstTreasureAfterSeconds,
                extraOpensPerTreasure: mattress.extraOpensPerTreasure,
                freeBoardIntervalSeconds: mattress.freeBoardIntervalSeconds * levers.freeMattressIntervalScale,
                prizes: mattress.prizes,
                freeBoardPrizes: mattress.freeBoardPrizes
            )
        }
        guard var ads else { return result }
        func scaled(_ multiplier: Double, _ source: SegmentLevers.Source) -> Double {
            guard multiplier > 1 else { return multiplier }
            return multiplier * levers.rewardMultiplier(for: source) / SegmentLevers.Levers.baseVideoRewardMultiplier
        }
        ads.offlineMultiplier = scaled(ads.offlineMultiplier, .offline)
        ads.dailyMultiplier = scaled(ads.dailyMultiplier, .daily)
        ads.careerMultiplier = scaled(ads.careerMultiplier, .career)
        ads.giftDoubleMultiplier = scaled(ads.giftDoubleMultiplier, .mattress)
        ads.wheelRepeatMultiplier = scaled(ads.wheelRepeatMultiplier, .wheel)
        ads.mergeAllCooldownSeconds *= levers.sideRailCooldownScale
        ads.packageRainCooldownSeconds *= levers.sideRailCooldownScale
        ads.adBreakIntervalSeconds *= levers.forcedSpacingScale
        result.ads = ads
        return result
    }
}
