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
/// pre-prestigio (urban→island) contra la banda 1.15–2.6, más una guarda
/// anti-acantilado por paso (≤4). Post-island los ratios tienden a 1 POR
/// DISEÑO (sweep de reencarnación) y quedan fuera del assert.
///
/// ⚠️ BANDAS RE-PINEADAS EN F7.6 (decisión del dueño, `Docs/balance-log.md §F7.6`):
/// el precio del primer Fisura quedó en 50 (era 450) porque arrancar barato se
/// siente mejor. El costo es real y está medido: la fase fisura pasó de 16 a
/// **5.8 min activos** y la 1ª reencarnación de 4.0 h a **0.26 h** — muy por
/// debajo del objetivo de diseño original (§4 del spec: "≥20-30 min"). Estos
/// asserts fijan la conducta ACTUAL para detectar regresiones; no representan
/// el pacing que el spec pedía. Si algún día se recalibra, vuelven a subir.
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

    @Test("la fase fisura dura 4-8 min activos")
    func strugglingPhaseLength() throws {
        let secondFloor = floorTable[1].id
        let active = try #require(report.floorUnlockActiveSeconds[secondFloor])
        #expect(active >= 4 * 60 && active <= 8 * 60, "\(secondFloor): \(active / 60) min activos")
    }

    @Test("el gradiente del arco pre-prestigio es ~1.15-2.6× por piso")
    func floorGradient() throws {
        // Pisos 2..5 (urban→island): el arco antes de que las reencarnaciones
        // barran pisos enteros de una pasada.
        let arc = (1...4).map { floorTable[$0].id }
        let actives = try arc.map {
            try #require(report.floorUnlockActiveSeconds[$0], "\($0) nunca se desbloqueó")
        }
        for index in 1..<actives.count {
            let ratio = actives[index] / actives[index - 1]
            #expect(ratio >= 1.0 && ratio <= 4.0, "acantilado en \(arc[index]): ×\(ratio)")
        }
        let geomean = pow(actives[actives.count - 1] / actives[0], 1.0 / Double(actives.count - 1))
        #expect(geomean >= 1.15 && geomean <= 2.6, "gradiente geomean ×\(geomean)")
    }

    @Test("la 1ª reencarnación cae entre 0.15 y 0.40 h de pared")
    func firstReincarnation() throws {
        let wall = try #require(report.firstReincarnationWall, "nunca reencarnó")
        #expect(wall >= 0.15 * 3600 && wall <= 0.40 * 3600, "1ª reencarnación: \(wall / 3600) h")
    }

    @Test("dios llega entre 21 y 65 h de pared con ≥3 reencarnaciones")
    func godTiming() throws {
        let wall = try #require(report.godWall, "dios nunca llegó (maxTier \(report.finalMaxTier))")
        #expect(wall >= 21 * 3600 && wall <= 65 * 3600, "dios: \(wall / 3600) h")
        #expect(report.reincarnations >= 3, "reencarnaciones: \(report.reincarnations)")
    }
}
