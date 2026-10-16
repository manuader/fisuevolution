import EconomyKit
import Foundation

/// Los flags del simulador por segmento (2.1 E15 F2-T3). Sin ninguno, la herramienta corre el camino de la 2.0
/// sin tocar nada.
struct SegmentFlags {
    /// `--segment low|mid|high`.
    var segment: PlayerSegment?
    /// `--segments-file <segments.json>`; sin él, el del bundle al lado de `economy.json` (`Resources/Config`).
    var segmentsURL: URL?
    /// `--accept-rate x`: pisa la fracción de ofertas con video que acepta el segmento de referencia.
    var acceptRate: Double?
    /// `--caps`: las palancas son los topes del código (el peor caso remoto), no las del archivo.
    var useCaps = false
    /// `--segment-matrix`: la tabla de R7 y el semáforo de C3.
    var matrix = false

    /// Si la corrida lleva un jugador de segmento (si no, el camino de la 2.0).
    var isSegmented: Bool { segment != nil || acceptRate != nil || useCaps }
}

func parseSegmentName(_ text: String?) throws -> PlayerSegment {
    guard let text, let segment = PlayerSegment(rawValue: text), segment != .base else {
        throw SimToolError(description: "--segment espera low|mid|high, no '\(text ?? "nada")'")
    }
    return segment
}

func parseAcceptRate(_ text: String?) throws -> Double {
    let value = try number(text, for: "--accept-rate")
    guard (0...1).contains(value) else {
        throw SimToolError(description: "--accept-rate espera un número entre 0 y 1, no '\(value)'")
    }
    return value
}

/// El `segments.json` del bundle (o el de `--segments-file`), validado con los topes del código: un archivo
/// fuera de tope no corre. `nil` si la corrida no lo necesita (`--caps`, o sin segmento).
func loadSegmentLevers(flags: SegmentFlags, sourcesURL: URL?) throws -> SegmentLevers? {
    guard !flags.useCaps, flags.segment != nil || flags.matrix else { return nil }
    guard let url = flags.segmentsURL ?? sourcesURL?.appendingPathComponent("segments.json") else {
        throw SimToolError(description: "no encuentro segments.json: pasá --segments-file <segments.json> o usá --caps")
    }
    do {
        let levers = try JSONDecoder().decode(SegmentLevers.self, from: Data(contentsOf: url))
        try levers.validate()
        return levers
    } catch {
        throw SimToolError(description: "\(url.lastPathComponent) no sirve (\(error))")
    }
}

/// Las palancas de un segmento según los flags: los topes con `--caps`, el archivo si no. `base` es siempre la
/// identidad.
private func levers(for segment: PlayerSegment, flags: SegmentFlags, file: SegmentLevers?) -> SegmentLevers.Levers {
    guard segment != .base else { return .identity }
    return flags.useCaps ? SegmentLevers.Caps.worstCase : (file?.levers(for: segment) ?? .identity)
}

/// El jugador de una corrida suelta. `--caps` sin `--segment` es el peor caso: `high`. `--accept-rate` solo
/// corre las palancas de la base con esa fracción.
func singleSegmentPlayer(flags: SegmentFlags, file: SegmentLevers?) -> PacingSegment? {
    guard flags.isSegmented else { return nil }
    let segment = flags.segment ?? (flags.useCaps ? .high : .base)
    return PacingSegment(
        levers: levers(for: segment, flags: flags, file: file),
        acceptRate: flags.acceptRate ?? PacingSegment.referenceAcceptRate(for: segment)
    )
}

/// El jugador de una celda de la matriz. `base` va con `nil`: la 2.0 tal cual.
private func matrixPlayer(_ segment: PlayerSegment, flags: SegmentFlags, file: SegmentLevers?) -> PacingSegment? {
    guard segment != .base else { return nil }
    return PacingSegment(
        levers: levers(for: segment, flags: flags, file: file),
        acceptRate: flags.acceptRate ?? PacingSegment.referenceAcceptRate(for: segment)
    )
}

/// Lo que la herramienta necesita para armar un simulador: todo menos el perfil, la semilla y el segmento.
struct SimulatorInputs {
    let config: EconomyConfig
    let tiers: TierRepository
    let human: PacingSimulator.HumanModel
    let upgrades: [PermanentUpgradeLine]
    let prestigeUnlocks: PrestigeUnlocks?
    let sources: PacingSources
    let maxDays: Int

    func report(profile: PacingProfile, seed: Double, segment: PacingSegment?) throws -> PacingSimulator.Report {
        try PacingSimulator(
            config: config, tiers: tiers, human: human, upgrades: upgrades, prestigeUnlocks: prestigeUnlocks,
            profile: profile, sources: sources, seedFraction: seed, segment: segment
        ).run(maxDays: maxDays)
    }
}

/// Una celda de la matriz de R7: un segmento, un perfil y una semilla.
struct MatrixCell {
    let segment: PlayerSegment
    let profileName: String
    let seed: Double
    let report: PacingSimulator.Report

    var godActiveSeconds: Double? { report.godActive }
    var godWallSeconds: Double? { report.godWall }
    var reincarnations: Int { report.reincarnations }
    /// Los videos que mira el bot por run (las reencarnaciones parten la partida en runs).
    var videosPerRun: Double { (report.sourceTotals["videos"] ?? 0) / Double(report.reincarnations + 1) }
    /// El mayor salto de tier entre dos runs seguidas: cuánto corre la pared de golpe.
    var worstJump: Int { zip(report.maxTierPerRun, report.maxTierPerRun.dropFirst()).map { $1 - $0 }.max() ?? 0 }
    var moonActiveSeconds: Double? { report.floorUnlockActiveSeconds["moon"] }
}

enum SegmentMatrix {
    static let segments: [PlayerSegment] = [.base, .low, .mid, .high]
    static let profiles: [(name: String, profile: PacingProfile)] = [("free", .free), ("ads", .ads), ("max", .max)]
    static let seeds = [0.1, 0.5, 0.9]
    /// V7: el piso de Dios para `high` con `.ads`, `acceptRate` 1 y los topes del código.
    static let highFloorHours = 30.0
    /// Debajo de esto, `.max` + `high` se avisa en el reporte.
    static let maxWarningHours = 28.0

    /// `base/low/mid/high × free/ads/max × semillas 0,1/0,5/0,9`: 36 corridas.
    static func run(inputs: SimulatorInputs, flags: SegmentFlags, file: SegmentLevers?) throws -> [MatrixCell] {
        var cells: [MatrixCell] = []
        for segment in segments {
            let player = matrixPlayer(segment, flags: flags, file: file)
            for (name, profile) in profiles {
                for seed in seeds {
                    cells.append(MatrixCell(
                        segment: segment, profileName: name, seed: seed,
                        report: try inputs.report(profile: profile, seed: seed, segment: player)
                    ))
                }
            }
        }
        return cells
    }

    /// C3.5: el segmento `identity` (palancas de la base, todo aceptado) da el mismo reporte que `nil`.
    static func identityHolds(inputs: SimulatorInputs, cells: [MatrixCell]) throws -> Bool {
        for (name, profile) in profiles {
            guard let base = cells.first(where: { $0.segment == .base && $0.profileName == name && $0.seed == 0.5 }) else {
                return false
            }
            if try inputs.report(profile: profile, seed: 0.5, segment: .identity) != base.report { return false }
        }
        return true
    }
}

/// `--segment-matrix`: corre las 36 celdas, imprime la tabla de R7 y el semáforo de C3 y, con `--csv`, la
/// matriz en filas.
func runSegmentMatrix(arguments: SimArguments, flags: SegmentFlags, file: SegmentLevers?, inputs: SimulatorInputs) throws {
    print("== pacing-sim --segment-matrix — horizonte \(inputs.maxDays) días ==")
    let cells = try SegmentMatrix.run(inputs: inputs, flags: flags, file: file)
    printSegmentMatrix(cells: cells, flags: flags)
    let identity = try SegmentMatrix.identityHolds(inputs: inputs, cells: cells)
    printSegmentContract(cells: cells, flags: flags, identityHolds: identity)
    if let csvURL = arguments.csvURL {
        let rows = ["seccion,clave,valor,unidad"] + segmentMatrixCSVRows(cells: cells)
        try (rows.joined(separator: "\n") + "\n").write(to: csvURL, atomically: true, encoding: .utf8)
        print("\n  CSV escrito en \(csvURL.path)")
    }
}
