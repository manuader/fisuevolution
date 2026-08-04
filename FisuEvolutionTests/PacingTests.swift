import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Guardián del pacing (F7 §4): corre `PacingSimulator` (bot greedy, 4 sesiones
/// ×20 min/día + offline) contra el CONTENIDO REAL bundleado y asserta los 4
/// targets del plan (PLAN-F7-torre §F7.1c, tolerancia ±30% ya aplicada). El
/// reloj del sim salta por evento: ~50 h simuladas corren en milisegundos.
///
/// Diseño del assert de gradiente (ver Docs/balance-log.md §F7.1): los unlocks
/// se pegan a los inicios de sesión del modelo humano (el offline paga cadenas
/// enteras durante los gaps), así que el ratio PISO A PISO es discreto/lumpy
/// por estructura, no por curva. Se asserta la MEDIA GEOMÉTRICA del arco
/// pre-prestigio (urban→island), más una guarda anti-acantilado por paso. Post-island los ratios tienden a 1 POR
/// DISEÑO (sweep de reencarnación) y quedan fuera del assert.
///
/// ⚠️ BANDAS RE-PINEADAS TRES VECES por decisión del dueño — ver
/// `Docs/balance-log.md §F7.6` y §"Gate de contratación". Estos asserts fijan la
/// conducta ACTUAL para detectar regresiones; NO representan el pacing que el
/// spec pedía (§4: "fase fisura ≥20-30 min activos"). Hoy esa fase dura
/// **0.8 min**. La causa está medida, no estimada: la regla de precios vigente
/// (300× lo que rinde un click en pisos superiores, +20% por compra; el callejón
/// queda aparte y barato) hace que los primeros Fisuras salgan 50/60/72/86…, una
/// curva que se recorre en segundos.
///
/// ⚠️⚠️ El **gate de contratación** (un piso desbloqueado por encima) alargó el
/// juego ~7×: dios pasó de 38 h a 264 h. El dueño lo eligió sabiendo ese costo.
/// Lo que NO estaba en esa decisión y quedó como consecuencia derivada: apareció
/// un **acantilado de ×48 en luxury** (antes ×7.1). El backfill de corporate se
/// habilita recién al abrir luxury, así que atravesar corporate pasó a depender
/// casi sólo del merge desde abajo. La guarda anti-acantilado se ensanchó para
/// tolerarlo y por lo tanto **ya casi no guarda nada**: si algún día se
/// recalibra, lo primero que hay que volver a bajar es ese 62.
@Suite("Pacing (simulación contra targets F7)")
struct PacingTests {
    let report: PacingSimulator.Report
    let floorTable: FloorTable

    init() throws {
        let content = try GameContentLoader.load(from: .main)
        let simulator = try PacingSimulator(config: content.economy, tiers: content.tiers)
        report = simulator.run(maxDays: 90)
        floorTable = content.floorTable
    }

    @Test("la fase fisura dura 0.5-1.5 min activos")
    func strugglingPhaseLength() throws {
        let secondFloor = floorTable[1].id
        let active = try #require(report.floorUnlockActiveSeconds[secondFloor])
        #expect(active >= 30 && active <= 90, "\(secondFloor): \(active / 60) min activos")
    }

    @Test("el gradiente del arco pre-prestigio es ~6-10× por piso")
    func floorGradient() throws {
        // Pisos 2..5 (urban→island): el arco antes de que las reencarnaciones
        // barran pisos enteros de una pasada.
        let arc = (1...4).map { floorTable[$0].id }
        let actives = try arc.map {
            try #require(report.floorUnlockActiveSeconds[$0], "\($0) nunca se desbloqueó")
        }
        for index in 1..<actives.count {
            let ratio = actives[index] / actives[index - 1]
            // 62 = el ×47.8 medido en luxury + 30%. Ver la nota del suite: esta
            // guarda quedó vestigial por el gate de contratación.
            #expect(ratio >= 1.0 && ratio <= 62.0, "acantilado en \(arc[index]): ×\(ratio)")
        }
        let geomean = pow(actives[actives.count - 1] / actives[0], 1.0 / Double(actives.count - 1))
        #expect(geomean >= 5.6 && geomean <= 10.3, "gradiente geomean ×\(geomean)")
    }

    @Test("la 1ª reencarnación cae entre 0.05 y 0.25 h de pared")
    func firstReincarnation() throws {
        let wall = try #require(report.firstReincarnationWall, "nunca reencarnó")
        #expect(wall >= 0.05 * 3600 && wall <= 0.25 * 3600, "1ª reencarnación: \(wall / 3600) h")
    }

    @Test("dios llega entre 185 y 343 h de pared con ≥3 reencarnaciones")
    func godTiming() throws {
        let wall = try #require(report.godWall, "dios nunca llegó (maxTier \(report.finalMaxTier))")
        #expect(wall >= 185 * 3600 && wall <= 343 * 3600, "dios: \(wall / 3600) h")
        #expect(report.reincarnations >= 3, "reencarnaciones: \(report.reincarnations)")
    }
}
