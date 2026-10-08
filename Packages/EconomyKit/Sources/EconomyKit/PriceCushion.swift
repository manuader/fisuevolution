import Foundation

/// El amortiguador del salto de precio (PLAN-v2 E2a, "Fórmula B").
///
/// `hireCost` está anclado a la frontera, así que en la v1 subirla multiplica
/// en el acto el precio de TODO lo que se vende por `J` (×1,87 por tier en el
/// callejón, ×2,99 desde el tier 8). Con el amortiguador, al subir la frontera
/// `RunState.priceRelief` hace `D ×= J` y el precio se divide por `D`: no salta.
/// Cada compra que cuenta hace `D = max(1, D/ρ)` con `ρ = J^(1/K)`, así que la
/// diferencia se cobra en las K compras siguientes y el precio vuelve EXACTO a
/// la v1.
///
/// `D` divide a todos los tipos por igual: la regla de precios (comprar hondo
/// no es atajo) y la compuerta no cambian.
///
/// Apagado (`K = 0`, la v1) el precio ignora `D` y cualquier compra lo vuelve a
/// 1: un save que lo trae de una prueba en el panel de debug no paga de menos.
public struct PriceCushion: Sendable, Equatable {
    /// `K`: en cuántas compras se paga un salto. 0 = apagado.
    public let purchases: Int
    private let yieldGrowthPerTier: Double
    private let priceGrowthPerTier: Double
    private let escalationPerTier: Double
    private let escalationFromTier: Int

    /// Un `D` a menos de esto de 1 es 1: después de K divisiones el redondeo no
    /// puede dejar el precio un pelo debajo de la v1 para siempre.
    static let snap = 1e-9

    public init(config: EconomyConfig) {
        purchases = max(0, config.hire.priceReliefPurchases)
        yieldGrowthPerTier = config.yieldGrowthPerTier
        priceGrowthPerTier = config.hire.priceGrowthPerTier
        escalationPerTier = config.hire.frontierEscalationPerTier
        escalationFromTier = config.hire.frontierEscalationFromTier
    }

    public var isEnabled: Bool { purchases > 0 }

    /// Cuánto salta el precio v1 de cualquier tipo cuando la frontera va de
    /// `from` a `to`: el cociente de los factores de `hireCost` que dependen de
    /// la frontera (rendimiento, escalada y la pendiente por tier).
    public func jump(from: Int, to: Int) -> Double {
        guard to > from else { return 1 }
        let escalated = max(0, to - escalationFromTier) - max(0, from - escalationFromTier)
        return pow(yieldGrowthPerTier / priceGrowthPerTier, Double(to - from))
            * pow(escalationPerTier, Double(escalated))
    }

    /// `ρ` en esta frontera: el salto que llevó hasta ella, repartido en K compras.
    public func step(atFrontier frontier: Int) -> Double {
        guard isEnabled, frontier > 1 else { return 1 }
        return pow(jump(from: frontier - 1, to: frontier), 1 / Double(purchases))
    }

    public func relief(_ relief: Double, raisingFrom from: Int, to: Int) -> Double {
        isEnabled ? max(1, relief) * jump(from: from, to: to) : 1
    }

    public func relief(_ relief: Double, afterPurchaseAt frontier: Int) -> Double {
        guard isEnabled else { return 1 }
        let next = relief / step(atFrontier: frontier)
        return next <= 1 + Self.snap ? 1 : next
    }

    public func price(v1: Double, relief: Double) -> Double {
        isEnabled ? v1 / max(1, relief) : v1
    }
}

extension EconomyConfig {
    public var priceCushion: PriceCushion { PriceCushion(config: self) }
}
