import EconomyKit
import Foundation

/// Simulador de balance headless (plan F2 §12): bots con 3 estrategias juegan
/// tiempo simulado contra la economía real y reportan tiempo-a-cada-tier y
/// tiempo al primer prestige.
///
///     swift run balance-sim --economy <economy.json> --tiers <tiers.json> \
///         [--max-hours 24] [--csv <salida.csv>]
///
/// CHECK DURO de alcanzabilidad: si el bot merge-greedy no llega a T30 dentro
/// de --max-hours de juego activo simulado, exit 1 — y el gate de balance de F2
/// no puede aprobarse.

struct SimError: Error, CustomStringConvertible {
    let description: String
}

// MARK: - Estrategias

enum Strategy: String, CaseIterable {
    case tapOnly = "tap-only"
    case mergeGreedy = "merge-greedy"
    case passiveFirst = "passive-first"

    /// Taps por segundo sostenidos (humano plausible).
    var tapsPerSecond: Int {
        switch self {
        case .tapOnly: 3
        case .mergeGreedy: 3
        case .passiveFirst: 1
        }
    }

    /// Acciones de board (spawn/merge, ~un drag) por segundo.
    var actionsPerSecond: Int {
        switch self {
        case .tapOnly: 0
        case .mergeGreedy: 2
        case .passiveFirst: 2
        }
    }
}

// MARK: - Motor de simulación

struct SimResult {
    let strategy: Strategy
    /// tier → segundos de juego activo hasta alcanzarlo por primera vez.
    var tierTimes: [Int: Int] = [:]
    var prestigeTime: Int?
    var finalCoinsPerSecond: Double = 0
    var totalTaps = 0
    var totalSpawns = 0
    var totalMerges = 0
    var totalPassiveUnlocks = 0
}

struct Simulator {
    let economy: StandardEconomy
    let tiers: TierRepository
    let unlocks: PrestigeUnlocks
    let maxSeconds: Int

    func run(strategy: Strategy) -> SimResult {
        var result = SimResult(strategy: strategy)
        var state = PlayerState.newGame(
            startTypeId: tiers.baseType.id,
            offlineEfficiencyBase: economy.config.offlineEfficiencyBase,
            critChanceBase: economy.config.critChanceBase,
            now: 0
        )
        result.tierTimes[1] = 0
        let capacity = economy.config.board.cellCount

        for second in 0..<maxSeconds {
            // Pasivo del segundo (delta 1s, dentro del clamp del ticker).
            IncomeTicker.tick(state: &state, tiers: tiers, delta: 1)

            // Taps sobre la unidad de mayor tier.
            if strategy.tapsPerSecond > 0, let best = bestUnit(state: state) {
                for _ in 0..<strategy.tapsPerSecond {
                    _ = economy.applyTap(type: best, state: &state)
                    result.totalTaps += 1
                }
            }

            // Acciones de board: prioridad merge > unlock (según estrategia) > spawn.
            var actions = strategy.actionsPerSecond
            while actions > 0 {
                if performMerge(state: &state, result: &result) {
                    actions -= 1
                    continue
                }
                if shouldUnlockPassive(strategy: strategy, state: state),
                   performPassiveUnlock(state: &state, result: &result) {
                    actions -= 1
                    continue
                }
                if performSpawn(state: &state, capacity: capacity, result: &result) {
                    actions -= 1
                    continue
                }
                break
            }

            let reached = state.maxTierReached
            if result.tierTimes[reached] == nil {
                result.tierTimes[reached] = second
            }

            if PrestigeCalculator.canPrestige(state: state, tiers: tiers) {
                result.prestigeTime = second
                break
            }
        }

        result.finalCoinsPerSecond = IncomeTicker.passivePerSecond(state: state, tiers: tiers)
        return result
    }

    private func bestUnit(state: PlayerState) -> CharacterType? {
        state.board
            .compactMap { tiers.type(id: $0.typeId) }
            .max { $0.tier < $1.tier }
    }

    private func performMerge(state: inout PlayerState, result: inout SimResult) -> Bool {
        var byType: [String: [Int]] = [:]
        for placement in state.board {
            byType[placement.typeId, default: []].append(placement.cellIndex)
        }
        // Mergea primero los tiers más altos (sube la escalera cuanto antes).
        let candidates = byType
            .filter { $0.value.count >= 2 }
            .sorted { (tiers.type(id: $0.key)?.tier ?? 0) > (tiers.type(id: $1.key)?.tier ?? 0) }

        for (typeId, cells) in candidates {
            let outcome = MergeRules.evaluate(
                sourceTypeId: typeId,
                targetTypeId: typeId,
                chosenCareerPath: state.chosenCareerPath,
                tiers: tiers
            )
            switch outcome {
            case .merged(let newTypeId):
                BoardActions.applyMerge(sourceCell: cells[0], targetCell: cells[1], newTypeId: newTypeId, state: &state, tiers: tiers)
                result.totalMerges += 1
                return true
            case .requiresCareerChoice(let options):
                // El bot elige la primera carrera (el humano elige por gusto).
                state.chosenCareerPath = MergeRules.careerPath(fromOptionId: options[0])
                return true
            case .invalid:
                continue
            }
        }
        return false
    }

    private func shouldUnlockPassive(strategy: Strategy, state: PlayerState) -> Bool {
        guard let cheapest = cheapestLockedPassive(state: state) else { return false }
        switch strategy {
        case .tapOnly: return false
        case .passiveFirst: return state.coins >= cheapest.passiveUnlockCost
        case .mergeGreedy:
            // No morfarse el presupuesto de spawn: unlock solo si sobra plata.
            return state.coins >= cheapest.passiveUnlockCost * 3
        }
    }

    private func cheapestLockedPassive(state: PlayerState) -> CharacterType? {
        let onBoard = Set(state.board.map(\.typeId))
        return onBoard
            .compactMap { tiers.type(id: $0) }
            .filter { state.passiveUnlocked[$0.id] != true }
            .min { $0.passiveUnlockCost < $1.passiveUnlockCost }
    }

    private func performPassiveUnlock(state: inout PlayerState, result: inout SimResult) -> Bool {
        guard let type = cheapestLockedPassive(state: state) else { return false }
        do {
            try economy.applyPassiveUnlock(typeId: type.id, state: &state, tiers: tiers)
            result.totalPassiveUnlocks += 1
            return true
        } catch {
            return false
        }
    }

    private func performSpawn(state: inout PlayerState, capacity: Int, result: inout SimResult) -> Bool {
        let discount = unlocks.cumulativeSpawnDiscount(atPrestigeLevel: state.prestigeLevel)
        guard let quote = economy.spawnQuote(state: state, tiers: tiers, costMultiplier: 1 - discount),
              state.coins >= quote.cost
        else { return false }
        do {
            try economy.applySpawn(quote: quote, state: &state, boardCapacity: capacity)
            result.totalSpawns += 1
            return true
        } catch {
            return false
        }
    }
}

// MARK: - CLI

func parseArguments() throws -> (economy: URL, tiers: URL, maxHours: Double, csv: URL?) {
    var economyPath: String?
    var tiersPath: String?
    var maxHours = 24.0
    var csvPath: String?
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--economy": economyPath = iterator.next()
        case "--tiers": tiersPath = iterator.next()
        case "--max-hours": maxHours = iterator.next().flatMap(Double.init) ?? maxHours
        case "--csv": csvPath = iterator.next()
        default: throw SimError(description: "unknown argument '\(argument)'")
        }
    }
    guard let economyPath, let tiersPath else {
        throw SimError(description: "usage: balance-sim --economy <economy.json> --tiers <tiers.json> [--max-hours 24] [--csv out.csv]")
    }
    return (
        URL(fileURLWithPath: economyPath),
        URL(fileURLWithPath: tiersPath),
        maxHours,
        csvPath.map { URL(fileURLWithPath: $0) }
    )
}

func format(seconds: Int?) -> String {
    guard let seconds else { return "—" }
    if seconds < 60 { return "\(seconds)s" }
    if seconds < 3600 { return String(format: "%.1fm", Double(seconds) / 60) }
    return String(format: "%.2fh", Double(seconds) / 3600)
}

do {
    let (economyURL, tiersURL, maxHours, csvURL) = try parseArguments()
    let config = try JSONDecoder().decode(EconomyConfig.self, from: Data(contentsOf: economyURL))
    let tiersFile = try JSONDecoder().decode(TiersFile.self, from: Data(contentsOf: tiersURL))
    let tiers = try TierRepository(types: tiersFile.types)
    let economy = StandardEconomy(config: config)
    // El sim no necesita los unlocks reales (primera vida = sin descuento).
    let unlocks = PrestigeUnlocks(schemaVersion: 1, spawnDiscountCap: 0.5, levels: [])

    let simulator = Simulator(
        economy: economy,
        tiers: tiers,
        unlocks: unlocks,
        maxSeconds: Int(maxHours * 3600)
    )

    var results: [SimResult] = []
    for strategy in Strategy.allCases {
        let result = simulator.run(strategy: strategy)
        results.append(result)
    }

    // Reporte
    let milestones = [2, 3, 5, 9, 15, 21, 25, 30]
    print("=== balance-sim | yieldGrowth \(config.yieldGrowthPerTier) | spawnGrowth \(config.spawn.costGrowth) | tierOffset \(config.spawn.tierOffset) | tope \(maxHours)h activas ===")
    print(String(format: "%-14@", "estrategia" as NSString), terminator: "")
    for tier in milestones { print(String(format: "%8@", "T\(tier)" as NSString), terminator: "") }
    print(String(format: "%10@%8@%8@%8@", "prestige" as NSString, "taps" as NSString, "spawns" as NSString, "merges" as NSString))

    for result in results {
        print(String(format: "%-14@", result.strategy.rawValue as NSString), terminator: "")
        for tier in milestones {
            print(String(format: "%8@", format(seconds: result.tierTimes[tier]) as NSString), terminator: "")
        }
        print(String(format: "%10@%8d%8d%8d", format(seconds: result.prestigeTime) as NSString, result.totalTaps, result.totalSpawns, result.totalMerges))
    }

    if let csvURL {
        var csv = "strategy,tier,seconds\n"
        for result in results {
            for (tier, time) in result.tierTimes.sorted(by: { $0.key < $1.key }) {
                csv += "\(result.strategy.rawValue),\(tier),\(time)\n"
            }
            if let prestige = result.prestigeTime {
                csv += "\(result.strategy.rawValue),prestige,\(prestige)\n"
            }
        }
        try csv.write(to: csvURL, atomically: true, encoding: .utf8)
        print("CSV → \(csvURL.path)")
    }

    // CHECK DURO: merge-greedy tiene que llegar a T30 (prestige disponible).
    let greedy = results.first { $0.strategy == .mergeGreedy }
    if let prestige = greedy?.prestigeTime {
        print("\n✅ ALCANZABILIDAD OK: merge-greedy llega a T30 en \(format(seconds: prestige)) de juego activo.")
        exit(0)
    } else {
        let maxReached = greedy?.tierTimes.keys.max() ?? 0
        print("\n❌ ALCANZABILIDAD FALLIDA: merge-greedy solo llegó a T\(maxReached) en \(maxHours)h.")
        print("El gate de balance de F2 NO puede aprobarse con estos números.")
        exit(1)
    }
} catch {
    FileHandle.standardError.write(Data("balance-sim: error: \(error)\n".utf8))
    exit(1)
}
