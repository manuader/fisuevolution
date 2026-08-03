import EconomyKit
import Foundation

/// Corre `PacingSimulator` contra economy.json + tiers.json reales e imprime el
/// reporte con el semáforo de targets (PLAN-F7 §F7.1c, tolerancia ±30% ya aplicada).
///
///     swift run pacing-sim --economy <economy.json> --tiers <tiers.json> [--max-days 90]
///
/// Los targets duros viven en PacingTests (app target); esta tool es el loop de
/// calibración: tocar knob en economy.json → correr → mirar el semáforo.

struct SimToolError: Error, CustomStringConvertible {
    let description: String
}

func parseArguments() throws -> (economyURL: URL, tiersURL: URL, maxDays: Int) {
    var economyPath: String?
    var tiersPath: String?
    var maxDays = 90
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--economy": economyPath = iterator.next()
        case "--tiers": tiersPath = iterator.next()
        case "--max-days": maxDays = iterator.next().flatMap { Int($0) } ?? maxDays
        default: throw SimToolError(description: "unknown argument '\(argument)'")
        }
    }
    guard let economyPath, let tiersPath else {
        throw SimToolError(description: "usage: pacing-sim --economy <economy.json> --tiers <tiers.json> [--max-days N]")
    }
    return (URL(fileURLWithPath: economyPath), URL(fileURLWithPath: tiersPath), maxDays)
}

func minutes(_ seconds: Double) -> String { String(format: "%7.1f min", seconds / 60) }
func hours(_ seconds: Double) -> String { String(format: "%7.2f h", seconds / 3600) }
func pad(_ text: String, _ width: Int) -> String {
    text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
}

/// Un renglón del semáforo: PASS si el valor cae en el rango (inclusive).
func check(_ label: String, value: Double?, range: ClosedRange<Double>, format: (Double) -> String) {
    guard let value else {
        print("  ❌ \(pad(label, 26)) — NO ALCANZADO (target \(format(range.lowerBound))…\(format(range.upperBound)))")
        return
    }
    let mark = range.contains(value) ? "✅" : "❌"
    print("  \(mark) \(pad(label, 26)) \(format(value))  (target \(format(range.lowerBound))…\(format(range.upperBound)))")
}

do {
    let (economyURL, tiersURL, maxDays) = try parseArguments()
    let config = try JSONDecoder().decode(EconomyConfig.self, from: Data(contentsOf: economyURL))
    let tiersFile = try JSONDecoder().decode(TiersFile.self, from: Data(contentsOf: tiersURL))
    let tiers = try TierRepository(types: tiersFile.types)
    let floorTable = try FloorTable(floors: config.floors, maxTier: tiers.maxTier)

    let simulator = try PacingSimulator(config: config, tiers: tiers)
    let report = simulator.run(maxDays: maxDays)

    print("== pacing-sim — horizonte \(maxDays) días ==")
    print("\n-- Desbloqueo de pisos (activo / pared) --")
    for (ordinal, floor) in floorTable.floors.enumerated() where ordinal > 0 {
        guard let wall = report.floorUnlockWallSeconds[floor.id],
              let active = report.floorUnlockActiveSeconds[floor.id]
        else {
            print("  \(pad(floor.id, 10)) —")
            continue
        }
        print("  \(pad(floor.id, 10)) \(minutes(active))  \(hours(wall))")
    }

    print("\n-- Hitos --")
    print("  reencarnaciones: \(report.reincarnations)")
    print("  1ª reencarnación: \(report.firstReincarnationWall.map(hours) ?? "—")")
    print("  dios: \(report.godWall.map(hours) ?? "—")  (maxTier final \(report.finalMaxTier))")
    print("  lifetimeEarnings final: \(String(format: "%.3e", report.finalLifetimeEarnings))")

    print("\n-- Targets (±30% ya aplicado) --")
    let secondFloorId = floorTable.floors.count > 1 ? floorTable[1].id : floorTable[0].id
    check(
        "piso 2 (\(secondFloorId)) activo",
        value: report.floorUnlockActiveSeconds[secondFloorId],
        range: (14.0 * 60)...(39.0 * 60),
        format: minutes
    )
    // Ratio de tiempo activo entre pisos consecutivos alcanzados.
    var ratioViolations = 0
    var ratiosSeen = 0
    var previous: Double?
    print("  ratios activos entre pisos (target 1.15…2.6):")
    for (ordinal, floor) in floorTable.floors.enumerated() where ordinal > 0 {
        guard let active = report.floorUnlockActiveSeconds[floor.id] else { break }
        if let previous, previous > 0 {
            let ratio = active / previous
            ratiosSeen += 1
            let ok = (1.15...2.6).contains(ratio)
            if !ok { ratioViolations += 1 }
            print("    \(ok ? "✅" : "❌") \(pad(floor.id, 10)) ×\(String(format: "%.2f", ratio))")
        }
        previous = active
    }
    if ratiosSeen == 0 { print("    ❌ sin datos (no se desbloqueó ningún piso más allá del 2º)") }
    check("1ª reencarnación (pared)", value: report.firstReincarnationWall, range: (2.8 * 3600)...(7.8 * 3600), format: hours)
    check("dios (pared)", value: report.godWall, range: (21.0 * 3600)...(65.0 * 3600), format: hours)
    check("reencarnaciones al llegar", value: Double(report.reincarnations), range: 3...1000, format: { String(format: "%.0f", $0) })
} catch {
    FileHandle.standardError.write(Data("pacing-sim: error: \(error)\n".utf8))
    exit(1)
}
