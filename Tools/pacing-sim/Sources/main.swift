import EconomyKit
import Foundation

/// Corre `PacingSimulator` contra economy.json + tiers.json reales e imprime el
/// reporte con el semáforo de targets (PLAN-F7 §F7.1c, tolerancia ±30% ya aplicada).
///
///     swift run pacing-sim --economy <economy.json> --tiers <tiers.json> \
///         [--upgrades <upgrades.json>] [--max-days 90] [--csv <out.csv>]
///
/// Sin `--upgrades` busca el catálogo real al lado de `economy.json` (ver
/// `resolveUpgradesURL`). Sin catálogo el bot NO compra mejoras permanentes, o
/// sea que mide el modelo viejo — y lo dice en la salida.
///
/// Los targets duros viven en PacingTests (app target); esta tool es el loop de
/// calibración: tocar knob en economy.json → correr → mirar el semáforo.

struct SimToolError: Error, CustomStringConvertible {
    let description: String
}

struct SimArguments {
    let economyURL: URL
    let tiersURL: URL
    let upgradesURL: URL?
    let maxDays: Int
    let csvURL: URL?
    /// Cuántas veces el ORO por reencarnar tiene que superar al histórico para
    /// que el bot reencarne (1 = duplicar, la conducta de siempre). Correr la
    /// misma economía con 1 y con un número grande contesta, con un número, si
    /// reencarnar temprano conviene o si el óptimo es esperar a la pared.
    let prestigeThreshold: Double
}

func parseArguments() throws -> SimArguments {
    var economyPath: String?
    var tiersPath: String?
    var upgradesPath: String?
    var csvPath: String?
    var maxDays = 90
    var prestigeThreshold = 1.0
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--economy": economyPath = iterator.next()
        case "--tiers": tiersPath = iterator.next()
        case "--upgrades": upgradesPath = iterator.next()
        case "--csv": csvPath = iterator.next()
        case "--max-days": maxDays = iterator.next().flatMap { Int($0) } ?? maxDays
        case "--prestige-threshold": prestigeThreshold = iterator.next().flatMap { Double($0) } ?? prestigeThreshold
        default: throw SimToolError(description: "unknown argument '\(argument)'")
        }
    }
    guard let economyPath, let tiersPath else {
        throw SimToolError(description: "usage: pacing-sim --economy <economy.json> --tiers <tiers.json> [--upgrades <upgrades.json>] [--max-days N] [--csv <out.csv>] [--prestige-threshold X]")
    }
    let economyURL = URL(fileURLWithPath: economyPath)
    return SimArguments(
        economyURL: economyURL,
        tiersURL: URL(fileURLWithPath: tiersPath),
        upgradesURL: upgradesPath.map { URL(fileURLWithPath: $0) } ?? resolveUpgradesURL(nextTo: economyURL),
        maxDays: maxDays,
        csvURL: csvPath.map { URL(fileURLWithPath: $0) },
        prestigeThreshold: prestigeThreshold
    )
}

/// Dónde está `upgrades.json` cuando nadie lo dijo. En el repo NO está al lado
/// de `economy.json` —`Resources/Data/` es economía y tiers, `Resources/Config/`
/// es contenido—, así que se prueba primero el hermano (por si algún día se
/// mudan juntos) y después `../Config/`. El default existe para que la línea de
/// calibración de la bitácora siga siendo una sola línea; `--upgrades` la pisa.
func resolveUpgradesURL(nextTo economyURL: URL) -> URL? {
    let dataDirectory = economyURL.deletingLastPathComponent()
    let candidates = [
        dataDirectory.appendingPathComponent("upgrades.json"),
        dataDirectory.deletingLastPathComponent().appendingPathComponent("Config/upgrades.json"),
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
}

/// Espejo mínimo de `upgrades.json`. El catálogo canónico —con `titleKey`,
/// `iconKey` y moneda— es `UpgradesConfig`, que vive en el app target y que
/// EconomyKit no puede importar porque es un paquete PURO. Acá se lee sólo lo
/// que la economía necesita y se arma la abstracción que el bot consume.
struct UpgradesFile: Decodable {
    struct Line: Decodable {
        let id: String
        let effectType: PermanentUpgradeLine.Effect
        let magnitudePerLevel: Double
        let maxLevel: Int
        let baseCost: Double
        let costGrowth: Double
        let currency: String?
    }

    let upgrades: [Line]

    /// Sólo las líneas que se pagan con ORO: son las que desbloquean las skins
    /// doradas y las únicas que el bot puede comprar (el ORO es lo único que le
    /// entra al reencarnar). Las de plata, si algún día vuelven, compiten con
    /// las compras de la run y son otra política.
    var permanentLines: [PermanentUpgradeLine] {
        upgrades
            .filter { ($0.currency ?? "coins") == "oro" }
            .map {
                PermanentUpgradeLine(
                    id: $0.id,
                    effect: $0.effectType,
                    magnitudePerLevel: $0.magnitudePerLevel,
                    maxLevel: $0.maxLevel,
                    baseCost: $0.baseCost,
                    costGrowth: $0.costGrowth
                )
            }
    }
}

/// "income 20/20 · tap 20/20 · crit 7/25 …" — dónde se atascó el bot, que es lo
/// que la calibración de las siete líneas necesita ver.
func upgradeLevelsSummary(report: PacingSimulator.Report, lines: [PermanentUpgradeLine]) -> String {
    guard !lines.isEmpty else { return "—" }
    return lines
        .map { "\($0.id) \(report.finalPermanentUpgradeLevels[$0.id] ?? 0)/\($0.maxLevel)" }
        .joined(separator: " · ")
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
    let arguments = try parseArguments()
    let maxDays = arguments.maxDays
    let config = try JSONDecoder().decode(EconomyConfig.self, from: Data(contentsOf: arguments.economyURL))
    let tiersFile = try JSONDecoder().decode(TiersFile.self, from: Data(contentsOf: arguments.tiersURL))
    let tiers = try TierRepository(types: tiersFile.types)
    let floorTable = try FloorTable(floors: config.floors, maxTier: tiers.maxTier)
    let upgradeLines: [PermanentUpgradeLine] = try arguments.upgradesURL.map {
        try JSONDecoder().decode(UpgradesFile.self, from: Data(contentsOf: $0)).permanentLines
    } ?? []

    let simulator = try PacingSimulator(
        config: config,
        tiers: tiers,
        human: .init(reincarnationThresholdMultiple: arguments.prestigeThreshold),
        upgrades: upgradeLines
    )
    let report = simulator.run(maxDays: maxDays)

    print("== pacing-sim — horizonte \(maxDays) días ==")
    if let upgradesURL = arguments.upgradesURL, !upgradeLines.isEmpty {
        print("   mejoras permanentes: \(upgradeLines.count) líneas de ORO (\(upgradesURL.lastPathComponent))")
    } else {
        print("   ⚠️ SIN catálogo de mejoras permanentes: el bot no gasta ORO y")
        print("      derivedEffects viaja en cero. Pasá --upgrades <upgrades.json>.")
    }
    print("\n-- Desbloqueo de pisos (activo / pared / lo que cuesta su hire) --")
    for (ordinal, floor) in floorTable.floors.enumerated() where ordinal > 0 {
        guard let wall = report.floorUnlockWallSeconds[floor.id],
              let active = report.floorUnlockActiveSeconds[floor.id]
        else {
            print("  \(pad(floor.id, 10)) —")
            continue
        }
        // La tercera columna es la evidencia de §2.3: cuántos SEGUNDOS de tu
        // income cuesta contratar el tier base del piso al abrirlo. Si la serie
        // se desploma, los precios se quedaron quietos mientras el ingreso se
        // multiplicaba; si se mantiene, el costo sigue al ingreso.
        let cost = report.floorUnlockHireSeconds[floor.id].map { String(format: "%9.1f s de income", $0) } ?? "—"
        print("  \(pad(floor.id, 10)) \(minutes(active))  \(hours(wall))  \(cost)")
    }

    print("\n-- Hitos --")
    print("  reencarnaciones: \(report.reincarnations)  (umbral ×\(arguments.prestigeThreshold) del ORO histórico)")
    print("  1ª reencarnación: \(report.firstReincarnationWall.map(hours) ?? "—") de pared"
        + "  (\(report.firstReincarnationActive.map(hours) ?? "—") ACTIVAS)")
    // La cadencia que pidió el dueño: "una reencarnación cada 2,5-4 h de juego
    // activo, cada una un hito que se prepara y se nota".
    let cadence = report.reincarnationActiveSeconds.prefix(12)
        .map { String(format: "%.1f", $0 / 3600) }
        .joined(separator: " · ")
    print("  cadencia (h ACTIVAS de cada una): \(cadence.isEmpty ? "—" : cadence)\(report.reincarnations > 12 ? " · …" : "")")
    // La métrica que pidió el dueño: horas ACTIVAS hasta maxear las siete líneas
    // permanentes, o sea hasta las skins doradas ("ganarlo al máximo").
    let maxedReincarnations = report.reincarnationsAtMaxedUpgrades.map { "\($0) reencarnaciones" } ?? "—"
    print("  las 7 al tope: \(report.maxedUpgradesActiveSeconds.map(hours) ?? "      — ") ACTIVAS"
        + "  (\(report.maxedUpgradesWall.map(hours) ?? "—") de pared, \(maxedReincarnations))")
    print("  niveles finales: \(upgradeLevelsSummary(report: report, lines: upgradeLines))")
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
    // Los dos targets del rebalance (PROMPT-rebalance-pacing §1): maxear las
    // siete en 20-30 h ACTIVAS y con ≤8 reencarnaciones.
    check("las 7 al tope (activo)", value: report.maxedUpgradesActiveSeconds, range: (20.0 * 3600)...(30.0 * 3600), format: hours)
    check(
        "reencarnaciones al maxear",
        value: report.reincarnationsAtMaxedUpgrades.map(Double.init),
        range: 1...8,
        format: { String(format: "%.0f", $0) }
    )
    check("1ª reencarnación (pared)", value: report.firstReincarnationWall, range: (2.8 * 3600)...(7.8 * 3600), format: hours)
    check("dios (pared)", value: report.godWall, range: (21.0 * 3600)...(65.0 * 3600), format: hours)
    check("reencarnaciones al llegar", value: Double(report.reincarnations), range: 3...1000, format: { String(format: "%.0f", $0) })
    print("\n  Nota: estos rangos son los OBJETIVOS DE DISEÑO del plan F7.1c.")
    print("  Los asserts de PacingTests se re-pinearon en F7.6 a la conducta real")
    print("  (ver Docs/balance-log.md §F7.6): el Fisura a 50 acortó el early game.")

    if let csvURL = arguments.csvURL {
        var rows = ["seccion,clave,valor,unidad"]
        for (ordinal, floor) in floorTable.floors.enumerated() where ordinal > 0 {
            let active = report.floorUnlockActiveSeconds[floor.id].map { String(format: "%.1f", $0 / 60) } ?? ""
            let wall = report.floorUnlockWallSeconds[floor.id].map { String(format: "%.2f", $0 / 3600) } ?? ""
            rows.append("piso,\(floor.id)_activo,\(active),min")
            rows.append("piso,\(floor.id)_pared,\(wall),h")
        }
        rows.append("hito,reencarnaciones,\(report.reincarnations),conteo")
        for (index, active) in report.reincarnationActiveSeconds.enumerated() {
            rows.append("reencarnacion,\(index + 1),\(String(format: "%.3f", active / 3600)),h activas")
        }
        for floor in floorTable.floors {
            guard let seconds = report.floorUnlockHireSeconds[floor.id] else { continue }
            rows.append("costo,\(floor.id)_hire_en_segundos,\(String(format: "%.2f", seconds)),s de income")
        }
        rows.append("hito,siete_al_tope_activo,\(report.maxedUpgradesActiveSeconds.map { String(format: "%.2f", $0 / 3600) } ?? ""),h")
        rows.append("hito,siete_al_tope_pared,\(report.maxedUpgradesWall.map { String(format: "%.2f", $0 / 3600) } ?? ""),h")
        rows.append("hito,reencarnaciones_al_maxear,\(report.reincarnationsAtMaxedUpgrades.map(String.init) ?? ""),conteo")
        rows.append("hito,primera_reencarnacion,\(report.firstReincarnationWall.map { String(format: "%.2f", $0 / 3600) } ?? ""),h")
        rows.append("hito,dios,\(report.godWall.map { String(format: "%.2f", $0 / 3600) } ?? ""),h")
        rows.append("hito,max_tier_final,\(report.finalMaxTier),tier")
        rows.append("hito,lifetime_earnings,\(String(format: "%.4e", report.finalLifetimeEarnings)),monedas")
        for line in upgradeLines {
            rows.append("mejora,\(line.id),\(report.finalPermanentUpgradeLevels[line.id] ?? 0),de \(line.maxLevel)")
        }
        for (key, value) in [
            ("yieldGrowthPerTier", config.yieldGrowthPerTier),
            ("hire_defaultCostMultiplier", config.hire.defaultCostMultiplier),
            ("hire_defaultCostGrowth", config.hire.defaultCostGrowth),
            ("oro_divisor", config.oro.divisor),
            ("oro_globalMultiplierPerOro", config.oro.globalMultiplierPerOro),
            ("offlineEfficiencyBase", config.offlineEfficiencyBase),
        ].sorted(by: { $0.0 < $1.0 }) {
            rows.append("knob,\(key),\(value),")
        }
        for floor in config.floors where floor.hireCostMultiplierOverride != nil || floor.hireCostGrowthOverride != nil {
            if let mult = floor.hireCostMultiplierOverride {
                rows.append("knob,\(floor.id)_hireCostMultiplier,\(mult),")
            }
            if let growth = floor.hireCostGrowthOverride {
                rows.append("knob,\(floor.id)_hireCostGrowth,\(growth),")
            }
        }
        try (rows.joined(separator: "\n") + "\n").write(to: csvURL, atomically: true, encoding: .utf8)
        print("\n  CSV escrito en \(csvURL.path)")
    }
} catch {
    FileHandle.standardError.write(Data("pacing-sim: error: \(error)\n".utf8))
    exit(1)
}
