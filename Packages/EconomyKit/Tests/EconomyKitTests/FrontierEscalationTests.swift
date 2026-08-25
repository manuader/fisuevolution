import Foundation
import Testing
@testable import EconomyKit

// MARK: - La desaceleración dentro de la run (decisión del dueño, 2026-08-23)
//
// Con el precio anclado a la frontera y nada más, cada tier cuesta el MISMO
// tiempo que el anterior: 37 tiers × constante = duración fija, y —lo que
// importa— **la run nunca se traba**. Por eso se puede ir de Fisura a Dios de una
// sentada y por eso reencarnar no paga: se reencarna para correr una pared, y no
// había pared.
//
// `frontierEscalationPerTier` es la que la construye: tu propia frontera se
// encarece un poco por cada tier que subís, POR ENCIMA de lo que ya sube por
// rendir más. Los primeros pisos quedan ágiles y los últimos se ponen densos.

@Suite("Desaceleración: la frontera se encarece por tier")
struct FrontierEscalationTests {
    /// El caso que NO se puede mover: con la frontera en el tier 1 el factor es
    /// `D^0 = 1`, así que **el primer Fisura sigue saliendo 25** y el tutorial no
    /// se entera. Es la decisión cerrada del dueño y la escalada tiene que
    /// respetarla por construcción, no por un caso especial.
    @Test("el primer Fisura sigue saliendo 25 para cualquier escalada")
    func elPrimerFisuraNoSeMueve() throws {
        for escalada in [1.0, 1.05, 1.15, 1.5] {
            let config = fxConfig(frontierEscalationPerTier: escalada)
            let f1 = try fxFloorTable(config: config)[0]
            #expect(config.hireCost(floor: f1, tier: 1, frontierTier: 1, purchases: 0) == 15,
                    "con escalada \(escalada) el tier base del piso 1 se movió")
        }
    }

    /// Lo que la escalada hace, en una línea: subir un tier de frontera
    /// multiplica el precio por `yieldGrowthPerTier × D` en vez de por
    /// `yieldGrowthPerTier` solo. Como el INGRESO sólo crece
    /// `yieldGrowthPerTier`, el tiempo por tier crece `D` — que es exactamente la
    /// desaceleración.
    @Test("subir un tier de frontera multiplica el precio por yieldGrowth × D")
    func laEscaladaSeAplicaPorTierDeFrontera() throws {
        let escalada = 1.1
        let config = fxConfig(frontierEscalationPerTier: escalada)
        let tabla = try fxFloorTable(config: config)
        // Lo que se mide es **lo que cuesta tu propia frontera**, o sea con el
        // tier comprado IGUAL a la frontera: es el enunciado de la regla y el
        // único par en el que no se mezcla el factor de profundidad. Los dos
        // tiers del par tienen que compartir piso, o el salto de multiplicador
        // se sumaría a la cuenta.
        let pares = [(f1: 1, f2: 2), (f1: 3, f2: 4)]
        for (acáTier, arribaTier) in pares {
            let pisoAcá = tabla[tabla.ordinal(forTier: acáTier)]
            let pisoArriba = tabla[tabla.ordinal(forTier: arribaTier)]
            let acá = config.hireCost(floor: pisoAcá, tier: acáTier, frontierTier: acáTier, purchases: 0)
            let arriba = config.hireCost(
                floor: pisoArriba, tier: arribaTier, frontierTier: arribaTier, purchases: 0
            )
            // 3,8 es el `yieldGrowthPerTier` de la fixture: lo que ya subía por
            // rendir más. El `× 1,1` es lo nuevo, y es la desaceleración.
            #expect(abs(arriba / acá - 3.8 * escalada) < 1e-9,
                    "T\(acáTier) → T\(arribaTier): ×\(arriba / acá)")
        }

        // Y el contraste que hace legible el knob: sin escalada el mismo par sube
        // sólo 3,8×, que es lo que hace que cada tier cueste el mismo TIEMPO.
        let plana = fxConfig(frontierEscalationPerTier: 1.0)
        let f2 = try fxFloorTable(config: plana)[1]
        let sinEscalada = plana.hireCost(floor: f2, tier: 4, frontierTier: 4, purchases: 0)
            / plana.hireCost(floor: f2, tier: 3, frontierTier: 3, purchases: 0)
        #expect(abs(sinEscalada - 3.8) < 1e-9)
    }

    /// ⚠️ **La escalada NO puede tocar el invariante de la ronda anterior.**
    /// Depende sólo de la frontera, así que a frontera FIJA no cambia nada entre
    /// dos tiers comprados: comprar hondo sigue costando `(2/priceGrowthPerTier)^d`
    /// más caro. Si algún día la escalada empezara a mirar el tier comprado, este
    /// test es el que lo dice.
    @Test("a frontera fija la escalada no cambia el costo relativo de comprar hondo")
    func laEscaladaNoTocaElInvarianteDeProfundidad() throws {
        let sinEscalada = fxConfig(frontierEscalationPerTier: 1.0)
        let conEscalada = fxConfig(frontierEscalationPerTier: 1.15)
        let tabla = try fxFloorTable(config: conEscalada)
        let frontera = 4
        for tier in 1..<frontera {
            let piso = tabla[tabla.ordinal(forTier: tier)]
            let pisoArriba = tabla[tabla.ordinal(forTier: tier + 1)]
            let razón = { (c: EconomyConfig) -> Double in
                let bajo = pow(2.0, Double(frontera - tier))
                    * c.hireCost(floor: piso, tier: tier, frontierTier: frontera, purchases: 0)
                let alto = pow(2.0, Double(frontera - tier - 1))
                    * c.hireCost(floor: pisoArriba, tier: tier + 1, frontierTier: frontera, purchases: 0)
                return bajo / alto
            }
            #expect(abs(razón(sinEscalada) - razón(conEscalada)) < 1e-9, "T\(tier): la escalada movió la profundidad")
        }
    }

    /// La escalada sale de la config, y **1,0 es apagarla**: es el valor con el
    /// que la fórmula queda idéntica a la de la ronda anterior, y por eso es el
    /// default del init (las fixtures que no hablan de desaceleración no eligen
    /// una política).
    @Test("la escalada vive en la config y 1,0 la apaga")
    func laEscaladaViveEnLaConfig() throws {
        #expect(EconomyConfig.HireConfig.noFrontierEscalation == 1.0)
        let apagada = fxConfig(frontierEscalationPerTier: 1.0)
        let tabla = try fxFloorTable(config: apagada)
        let f2 = tabla[1]
        // Sin escalada, el precio a frontera 3 es el multiplicador por lo que
        // rinde un click de esa frontera: 100 × 3,8² = 1444, el número de siempre.
        #expect(abs(apagada.hireCost(floor: f2, tier: 3, frontierTier: 3, purchases: 0) - 1444) < 1e-9)
    }

    /// Y la clave es OBLIGATORIA en el JSON, por lo mismo que las otras dos de
    /// política: su único default posible (1,0) es "no hay desaceleración", que
    /// es justo la forma de curva que esta ronda vino a arreglar. Un
    /// `economy.json` al que se le caiga la clave tiene que no cargar.
    @Test("hire SIN frontierEscalationPerTier no decodifica")
    func laEscaladaEsObligatoriaEnElJSON() throws {
        let sinClave = #"{"defaultCostMultiplier": 600, "defaultCostGrowth": 1.06, "priceGrowthPerTier": 1.5, "gateTierDistance": 7}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(EconomyConfig.HireConfig.self, from: Data(sinClave.utf8))
        }
        let completo = #"{"defaultCostMultiplier": 600, "defaultCostGrowth": 1.06, "priceGrowthPerTier": 1.5, "gateTierDistance": 7, "frontierEscalationPerTier": 1.1}"#
        let decodificado = try JSONDecoder().decode(EconomyConfig.HireConfig.self, from: Data(completo.utf8))
        #expect(decodificado.frontierEscalationPerTier == 1.1)
    }
}
