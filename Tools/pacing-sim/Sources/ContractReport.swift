import EconomyKit
import Foundation

func printLegacyTargets(report: PacingSimulator.Report, floorTable: FloorTable) {
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
    // seis en 20-30 h ACTIVAS y con ≤9 reencarnaciones.
    check("las 6 al tope (activo)", value: report.maxedUpgradesActiveSeconds, range: (20.0 * 3600)...(30.0 * 3600), format: hours)
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
    print("  Los asserts de PacingTests miden otra cosa: sus cuatro BANDAS se")
    print("  re-pinearon el 2026-08-21 a la conducta real del rebalance de pacing")
    print("  (ver Docs/balance-log.md), y aparte assertean el objetivo del dueño")
    print("  —maxear las seis en 20-30 h activas con <=9 reencarnaciones—, que sí")
    print("  se cumple. La brecha que queda es la fase fisura: el spec pide 20-30")
    print("  min activos y el Fisura a 25 la deja en segundos.")
}

func printProfileHeader(arguments: SimArguments, loaded: LoadedSources) {
    let name: String
    switch arguments.profile {
    case .bare: name = "bare"
    case .free: name = "free"
    case .ads: name = "ads"
    case .max: name = "max"
    default: name = "?"
    }
    let sources = loaded.loaded.isEmpty ? "—" : "\(loaded.loaded.count) archivos de \(arguments.sourcesURL?.lastPathComponent ?? "?")"
    print("   perfil: \(name) · fuentes: \(sources) · semilla \(arguments.seedFraction)"
        + " · descuento de prestigio \(arguments.prestigeDiscount ? "sí" : "no")")
    for warning in loaded.warnings { print("   \(warning)") }
}

private func series<T>(_ values: [T], _ format: (T) -> String) -> String {
    values.isEmpty ? "—" : values.map(format).joined(separator: " · ")
}

/// Lo que el contrato mira y el reporte viejo no imprimía.
func printContractMilestones(report: PacingSimulator.Report) {
    print("  oro al llegar a dios: \(report.oroAtGod.map(String.init) ?? "—")")
    print("  ORO por reencarnación: \(series(report.oroGainedPerReincarnation) { String($0) })")
    print("  pasivos comprados por run: \(series(report.passiveUnlocksPerRun) { String($0) })")
    print("  pisos en marcha (máx / en dios): \(report.maxStaffedFloors) / \(report.staffedFloorsAtGod.map(String.init) ?? "—")")
    print("  el techo del prestigio por run: \(series(report.prestigeCeilingPerRun) { String(format: "%.0f%%", $0 * 100) })")
    print("  tier máximo por run: \(series(report.maxTierPerRun) { "T\($0)" })")
    let totals = report.sourceTotals.sorted { $0.key < $1.key }
    print("  lo que dieron las fuentes: \(totals.isEmpty ? "—" : totals.map { "\($0.key) \(String(format: "%.3g", $0.value))" }.joined(separator: " · "))")
}

private func mark(_ ok: Bool) -> String { ok ? "✅" : "❌" }

private func inRange(_ value: Double?, _ range: ClosedRange<Double>) -> Bool {
    value.map { range.contains($0) } ?? false
}

/// El contrato de la 2.0 (E2b), punto por punto. El 8 y el 9 piden otras
/// corridas (`.never` y los otros perfiles) y los mide `PacingContractTests`.
func printContract(report: PacingSimulator.Report, floorTable: FloorTable) {
    print("\n-- El contrato de la 2.0 --")
    let minutesOf: (Double) -> String = { String(format: "%.0f min", $0 / 60) }
    let godMinutes = report.godActive.map { $0 / 60 }
    print("  \(mark(inRange(godMinutes, 1900...2100))) 1 Dios 1.900–2.100 min activos: "
        + (godMinutes.map { String(format: "%.0f min (%.2f h)", $0, $0 / 60) } ?? "NO ALCANZADO"))
    print("  \(mark((5...6).contains(report.reincarnations))) 2 5 o 6 reencarnaciones: \(report.reincarnations)")

    let maxed = report.maxedUpgradesActiveSeconds
    var beforeEighty = false
    if let maxed, let god = report.godActive { beforeEighty = maxed < 0.8 * god }
    let afterFifth = (report.reincarnationsAtMaxedUpgrades ?? 0) >= 5
    print("  \(mark(beforeEighty && afterFifth)) 3 las 7 al tope antes del 80 % de Dios y no antes de la 5ª: "
        + "\(maxed.map(minutesOf) ?? "—") (\(maxed.flatMap { m in report.godActive.map { String(format: "%.0f%%", m / $0 * 100) } } ?? "—")), "
        + "\(report.reincarnationsAtMaxedUpgrades.map(String.init) ?? "—") reencarnaciones")

    let first = report.firstReincarnationActive.map { $0 / 3600 }
    print("  \(mark(inRange(first, 0.75...1.5))) 4 1ª reencarnación 0,75–1,5 h activas: "
        + (first.map { String(format: "%.2f h", $0) } ?? "—"))

    let tiers = report.maxTierPerRun
    let farther = zip(tiers, tiers.dropFirst()).allSatisfy { $1 >= $0 + 1 }
    var slower = 0
    for (previous, current) in zip(report.tierReachedPerRun, report.tierReachedPerRun.dropFirst()) {
        for (tier, seconds) in previous where seconds > 0 {
            if let now = current[tier], now < seconds { continue }
            slower += 1
        }
    }
    print("  \(mark(farther && slower == 0 && tiers.count > 1)) 5 cada run un tier más lejos y antes en lo ya visto: "
        + "\(farther ? "más lejos" : "NO siempre más lejos"), \(slower) tiers no llegaron antes")

    let payoff = report.prestigePayoffPerRun
    print("  \(mark(!payoff.isEmpty && payoff.allSatisfy { $0 >= 0.65 })) 6 reencarnar paga ≥ 65 %: "
        + series(payoff) { String(format: "%.0f%%", $0 * 100) })

    let bands: [(String, ClosedRange<Double>)] = [
        ("urban", 0...1.5), ("corporate", 6...10), ("luxury", 35...60), ("island", 200...300),
        ("moon", 520...680), ("mars", 900...1100), ("solar", 1350...1550), ("galaxy", 1650...1850),
    ]
    print("  7 primera llegada por piso (min activos):")
    for (id, range) in bands where floorTable.floors.contains(where: { $0.id == id }) {
        let value = report.floorUnlockActiveSeconds[id].map { $0 / 60 }
        print("    \(mark(inRange(value, range))) \(pad(id, 10)) "
            + "\(value.map { String(format: "%7.1f", $0) } ?? "      —")  (\(Int(range.lowerBound))–\(range.upperBound))")
    }
    print("    \(mark(inRange(godMinutes, 1900...2100))) \(pad("Dios", 10)) "
        + "\(godMinutes.map { String(format: "%7.1f", $0) } ?? "      —")  (1900–2100)")
    print("  — 8 sin reencarnar no se llega a Dios · 9 .ads ≥ 55 % y .max ≥ 50 % de .free: los mide PacingContractTests")
    print("  \(mark(inRange(report.oroAtGod.map(Double.init), 5000...12000))) guarda del ORO al llegar a Dios 5.000–12.000: "
        + (report.oroAtGod.map(String.init) ?? "—"))
}

/// Las series del contrato y las perillas de la corrida, para comparar CSVs.
func contractCSVRows(report: PacingSimulator.Report, arguments: SimArguments, config: EconomyConfig) -> [String] {
    var rows = ["hito,oro_al_llegar_a_dios,\(report.oroAtGod.map(String.init) ?? ""),ORO"]
    for (index, oro) in report.oroGainedPerReincarnation.enumerated() {
        rows.append("oro,reencarnacion_\(index + 1),\(oro),ORO")
    }
    for (index, count) in report.passiveUnlocksPerRun.enumerated() {
        rows.append("pasivos,run_\(index + 1),\(count),comprados")
    }
    for (index, tier) in report.maxTierPerRun.enumerated() {
        rows.append("forma,tier_maximo_run_\(index + 1),\(tier),tier")
    }
    for (index, ceiling) in report.prestigeCeilingPerRun.enumerated() {
        rows.append("forma,techo_run_\(index + 2),\(String(format: "%.3f", ceiling)),fracción")
    }
    rows.append("hito,pisos_en_marcha_max,\(report.maxStaffedFloors),pisos")
    rows.append("hito,pisos_en_marcha_en_dios,\(report.staffedFloorsAtGod.map(String.init) ?? ""),pisos")
    for (key, value) in report.sourceTotals.sorted(by: { $0.key < $1.key }) {
        rows.append("fuente,\(key),\(String(format: "%.4e", value)),")
    }
    rows.append("corrida,seed_fraction,\(arguments.seedFraction),")
    rows.append("corrida,descuento_de_prestigio,\(arguments.prestigeDiscount),")
    rows.append("knob,floor_capacity,\(config.floors.first?.capacity ?? 0),")
    rows.append("knob,oro_exponent,\(config.oro.exponent),")
    rows.append("knob,hire_mergeRefundCounts,\(config.hire.mergeRefundCounts),")
    rows.append("knob,hire_priceReliefPurchases,\(config.hire.priceReliefPurchases),")
    rows.append("knob,staffedBonusPerFloor,\(config.staffedBonusPerFloor),")
    return rows
}
