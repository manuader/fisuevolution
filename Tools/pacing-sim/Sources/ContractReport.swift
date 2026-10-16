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
    if arguments.profile.ownsShopPermanents, let shop = loaded.sources.shop {
        print("   tienda: \(shop.extraSlots) lugares · proveedor \(shop.bestSupplierLevel) · \(shop.bonusDailyWheelSpins) giros")
    }
    for warning in loaded.warnings { print("   \(warning)") }
}

private func series<T>(_ values: [T], _ format: (T) -> String) -> String {
    values.isEmpty ? "—" : values.map(format).joined(separator: " · ")
}

/// Lo que el contrato mira y el reporte viejo no imprimía.
func printContractMilestones(report: PacingSimulator.Report) {
    print("  blue al llegar a dios: \(report.blueAtGod.map(String.init) ?? "—")")
    print("  blue por reencarnación: \(series(report.blueGainedPerReincarnation) { String($0) })")
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

/// El contrato de la 2.0 (E2b), punto por punto, con los números de 45 h
/// (`tasks.md` §7 «2026-10-12»). El 8 y el 9 piden otras corridas (`.never` y
/// los otros perfiles) y los mide `PacingContractTests`.
func printContract(report: PacingSimulator.Report, floorTable: FloorTable) {
    print("\n-- El contrato de la 2.0 (45 h) --")
    let minutesOf: (Double) -> String = { String(format: "%.0f min", $0 / 60) }
    let godRange = 2600.0...2800.0
    let godMinutes = report.godActive.map { $0 / 60 }
    print("  \(mark(inRange(godMinutes, godRange))) 1 Dios 2.600–2.800 min activos: "
        + (godMinutes.map { String(format: "%.0f min (%.2f h)", $0, $0 / 60) } ?? "NO ALCANZADO"))
    print("  \(mark((5...6).contains(report.reincarnations))) 2 5 o 6 reencarnaciones: \(report.reincarnations)")

    let maxed = report.maxedUpgradesActiveSeconds
    var beforeEighty = false
    if let maxed, let god = report.godActive { beforeEighty = maxed < 0.8 * god }
    let afterFifth = (report.reincarnationsAtMaxedUpgrades ?? 0) >= 5
    print("  \(mark(beforeEighty && afterFifth)) 3 las líneas al tope antes del 80 % de Dios y no antes de la 5ª: "
        + "\(maxed.map(minutesOf) ?? "—") (\(maxed.flatMap { m in report.godActive.map { String(format: "%.0f%%", m / $0 * 100) } } ?? "—")), "
        + "\(report.reincarnationsAtMaxedUpgrades.map(String.init) ?? "—") reencarnaciones")

    let first = report.firstReincarnationActive.map { $0 / 3600 }
    print("  \(mark(inRange(first, 1...2))) 4 1ª reencarnación 1–2 h activas: "
        + (first.map { String(format: "%.2f h", $0) } ?? "—"))

    let tiers = report.maxTierPerRun
    let farther = zip(tiers, tiers.dropFirst()).allSatisfy { $1 >= $0 + 1 }
    var later: [String] = []
    for (index, (previous, current)) in zip(report.tierReachedPerRun, report.tierReachedPerRun.dropFirst()).enumerated() {
        for (tier, seconds) in previous.sorted(by: { $0.key < $1.key }) where seconds > 0 {
            if let now = current[tier], now <= seconds { continue }
            later.append("run \(index + 2) T\(tier)")
        }
    }
    print("  \(mark(farther && later.isEmpty && tiers.count > 1)) 5 cada run un tier más lejos y antes en lo ya visto: "
        + "\(farther ? "más lejos" : "NO siempre más lejos"), \(later.count) tiers no llegaron antes")
    if !later.isEmpty { print("      más tarde: \(later.joined(separator: " · "))") }

    let payoff = report.prestigePayoffPerRun
    print("  \(mark(!payoff.isEmpty && payoff.allSatisfy { $0 >= 0.65 })) 6 reencarnar paga ≥ 65 %: "
        + series(payoff) { String(format: "%.0f%%", $0 * 100) })

    let bands: [(String, ClosedRange<Double>)] = [
        ("urban", 0...1.5), ("corporate", 6...12), ("luxury", 45...80), ("island", 270...410),
        ("moon", 710...930), ("mars", 1230...1500), ("solar", 1840...2110), ("galaxy", 2250...2520),
    ]
    print("  7 primera llegada por piso (min activos):")
    for (id, range) in bands where floorTable.floors.contains(where: { $0.id == id }) {
        let value = report.floorUnlockActiveSeconds[id].map { $0 / 60 }
        print("    \(mark(inRange(value, range))) \(pad(id, 10)) "
            + "\(value.map { String(format: "%7.1f", $0) } ?? "      —")  (\(String(format: "%g–%g", range.lowerBound, range.upperBound)))")
    }
    print("    \(mark(inRange(godMinutes, godRange))) \(pad("Dios", 10)) "
        + "\(godMinutes.map { String(format: "%7.1f", $0) } ?? "      —")  (2600–2800)")
    print("  — 8 sin reencarnar no se llega a Dios · 9 .ads ≥ 65 % y .max ≥ 55 % de .free: los mide PacingContractTests")
    print("  \(mark(inRange(report.blueAtGod.map(Double.init), 5000...12000))) guarda del blue al llegar a Dios 5.000–12.000: "
        + (report.blueAtGod.map(String.init) ?? "—"))
}

/// Las series del contrato y las perillas de la corrida, para comparar CSVs.
func contractCSVRows(report: PacingSimulator.Report, arguments: SimArguments, config: EconomyConfig) -> [String] {
    var rows = ["hito,blue_al_llegar_a_dios,\(report.blueAtGod.map(String.init) ?? ""),blue"]
    for (index, blue) in report.blueGainedPerReincarnation.enumerated() {
        rows.append("blue,reencarnacion_\(index + 1),\(blue),blue")
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
    rows.append("knob,blue_exponent,\(config.blue.exponent),")
    rows.append("knob,hire_mergeRefundCounts,\(config.hire.mergeRefundCounts),")
    rows.append("knob,hire_priceReliefPurchases,\(config.hire.priceReliefPurchases),")
    rows.append("knob,staffedBonusPerFloor,\(config.staffedBonusPerFloor),")
    return rows
}

// MARK: - Por segmento (2.1 E15 F2-T3)

private func hoursText(_ seconds: Double?) -> String {
    seconds.map { String(format: "%7.2f h", $0 / 3600) } ?? "      — "
}

func printSegmentHeader(segment: PacingSegment, flags: SegmentFlags) {
    let source = flags.useCaps ? "topes del código (peor caso)" : "segments.json"
    let name = flags.segment?.rawValue ?? (flags.useCaps ? "high" : "base")
    print("   segmento: \(name) · palancas: \(source) · acepta \(String(format: "%.0f%%", segment.acceptRate * 100)) de las ofertas con video")
}

/// La tabla de R7: Dios activo y de pared, reencarnaciones, videos por run, peor salto y la llegada a la luna,
/// por segmento, perfil y semilla.
func printSegmentMatrix(cells: [MatrixCell], flags: SegmentFlags) {
    print("\n-- La matriz de R7 (palancas: \(flags.useCaps ? "topes del código" : "segments.json")) --")
    print("  \(pad("segmento", 9)) \(pad("perfil", 6)) \(pad("semilla", 8)) \(pad("Dios activo", 11)) \(pad("Dios pared", 11)) "
        + "\(pad("reenc.", 7)) \(pad("videos/run", 11)) \(pad("peor salto", 10)) luna activa")
    for cell in cells {
        let moon = cell.moonActiveSeconds.map { String(format: "%7.1f min", $0 / 60) } ?? "      —"
        print("  \(pad(cell.segment.rawValue, 9)) \(pad(cell.profileName, 6)) \(pad(String(format: "%.1f", cell.seed), 8)) "
            + "\(hoursText(cell.godActiveSeconds)) \(hoursText(cell.godWallSeconds)) "
            + "\(pad(String(cell.reincarnations), 7)) \(pad(String(format: "%.1f", cell.videosPerRun), 11)) "
            + "\(pad("+\(cell.worstJump) tiers", 10)) \(moon)")
    }
}

/// El semáforo de C3 sobre las celdas de la matriz. Devuelve si todo está en verde.
@discardableResult
func printSegmentContract(cells: [MatrixCell], flags: SegmentFlags, identityHolds: Bool) -> Bool {
    print("\n-- El contrato por segmento (C3) --")
    func god(_ segment: PlayerSegment, _ profile: String, _ seed: Double) -> Double {
        cells.first { $0.segment == segment && $0.profileName == profile && $0.seed == seed }?.godActiveSeconds ?? .infinity
    }
    let others: [PlayerSegment] = [.low, .mid, .high]
    var allGreen = true
    func report(_ ok: Bool, _ text: String, detail: String = "") {
        allGreen = allGreen && ok
        print("  \(mark(ok)) \(text)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    // 1 y 2: ningún segmento llega a Dios más tarde que la base `.free`.
    for profile in ["free", "ads"] {
        let late = SegmentMatrix.seeds.flatMap { seed in
            others.filter { god($0, profile, seed) > god(.base, "free", seed) }.map { "\($0.rawValue)@\(seed)" }
        }
        report(late.isEmpty, "\(profile == "free" ? "1" : "2") con .\(profile) Dios ≤ la base .free (tolerancia 0)",
               detail: late.isEmpty ? "ningún segmento más lento" : "más lentos: \(late.joined(separator: " · "))")
    }

    // 3: monotonía high ≤ mid ≤ low con el mismo perfil (relevo 61: contra la base, con la misma fracción).
    let broken = SegmentMatrix.monotonyBreaks(cells: cells)
    report(broken.isEmpty, "3 monotonía high ≤ mid ≤ low en minutos a Dios",
           detail: broken.isEmpty ? "en los tres perfiles y las tres semillas" : "rota en \(broken.joined(separator: " · "))")

    // 4: el piso de `high` (V7); con `segments.json` no es el peor caso, y se dice.
    let floorHours = SegmentMatrix.highFloorHours
    let worst = SegmentMatrix.seeds.map { god(.high, "ads", $0) }.min() ?? .infinity
    report(worst >= floorHours * 3600, "4 piso: high con .ads, acepta todo, Dios ≥ \(String(format: "%.0f", floorHours)) h",
           detail: "\(String(format: "%.2f h", worst / 3600)) el peor de las semillas"
               + (flags.useCaps ? " (topes del código)" : " (con segments.json: para el peor caso corré --caps)"))
    let maxWorst = SegmentMatrix.seeds.map { god(.high, "max", $0) }.min() ?? .infinity
    let maxLow = maxWorst < SegmentMatrix.maxWarningHours * 3600
    print("  \(maxLow ? "⚠️" : "ℹ️") .max + high se reporta: \(String(format: "%.2f h", maxWorst / 3600))"
        + (maxLow ? " — por debajo de \(String(format: "%.0f", SegmentMatrix.maxWarningHours)) h: avisar" : ""))

    // 5: identidad.
    report(identityHolds, "5 identidad: segment nil == todo base, mismo reporte campo a campo")

    // 6: el archivo del bundle (no sólo los topes).
    print("  \(flags.useCaps ? "ℹ️" : "✅") 6 lo mismo con el segments.json del bundle: "
        + (flags.useCaps ? "esta corrida usó los topes; repetila sin --caps" : "esta corrida usó el archivo"))
    print(allGreen ? "\n  Semáforo: todo en verde." : "\n  Semáforo: HAY ROJOS.")
    return allGreen
}

/// La matriz en el CSV de contrato: una fila por celda y métrica.
func segmentMatrixCSVRows(cells: [MatrixCell]) -> [String] {
    var rows: [String] = []
    for cell in cells {
        let key = "\(cell.segment.rawValue)_\(cell.profileName)_\(String(format: "%.1f", cell.seed))"
        func hoursOrEmpty(_ seconds: Double?) -> String { seconds.map { String(format: "%.2f", $0 / 3600) } ?? "" }
        rows.append("segmento,\(key)_dios_activo,\(hoursOrEmpty(cell.godActiveSeconds)),h activas")
        rows.append("segmento,\(key)_dios_pared,\(hoursOrEmpty(cell.godWallSeconds)),h")
        rows.append("segmento,\(key)_reencarnaciones,\(cell.reincarnations),conteo")
        rows.append("segmento,\(key)_videos_por_run,\(String(format: "%.2f", cell.videosPerRun)),videos")
        rows.append("segmento,\(key)_peor_salto,\(cell.worstJump),tiers")
        rows.append("segmento,\(key)_luna_activa,\(cell.moonActiveSeconds.map { String(format: "%.1f", $0 / 60) } ?? ""),min")
    }
    return rows
}

/// El jugador de una corrida suelta en el CSV, para comparar contra la base.
func segmentCSVRows(flags: SegmentFlags, segment: PacingSegment) -> [String] {
    [
        "corrida,segmento,\(flags.segment?.rawValue ?? (flags.useCaps ? "high" : "base")),",
        "corrida,palancas,\(flags.useCaps ? "topes" : "segments.json"),",
        "corrida,accept_rate,\(segment.acceptRate),",
    ]
}
