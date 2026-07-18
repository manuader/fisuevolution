import EconomyKit
import Foundation

/// Generates `tiers.json` from `economy.json` + the cultural table below.
///
///     swift run generate-tiers --economy <path/economy.json> --output <path/tiers.json>
///
/// The bible's rule: "no inventar números sueltos — todo sale de las fórmulas".
/// Numbers are baked by `StandardEconomy`; this tool owns only the cultural layer
/// (ids, rioplatense display names, placeholder symbols, merge ladder shape).
/// The output is self-validated with `TierRepository` before being written.

/// One row of the cultural table (bible §1). Cosmic names (T22–T30) keep the
/// design doc's "Owns The Moon → God" arc with local flavor; they are data, so the
/// Content track can rename them without touching code.
struct CulturalEntry {
    let id: String
    let tier: Int
    let phase: GamePhase
    let displayName: String
    let symbol: String
    let mergesInto: String?
    let isChoiceNode: Bool
    let choiceOptions: [String]?

    init(
        _ id: String,
        _ tier: Int,
        _ phase: GamePhase,
        _ displayName: String,
        _ symbol: String,
        mergesInto: String?,
        isChoiceNode: Bool = false,
        choiceOptions: [String]? = nil
    ) {
        self.id = id
        self.tier = tier
        self.phase = phase
        self.displayName = displayName
        self.symbol = symbol
        self.mergesInto = mergesInto
        self.isChoiceNode = isChoiceNode
        self.choiceOptions = choiceOptions
    }
}

let culturalTable: [CulturalEntry] = [
    // Fase Tierra (bible §1) — T9/T10 son la bifurcación de carrera (elección UBA).
    CulturalEntry("homeless", 1, .earth, "El Fisura", "person.fill", mergesInto: "cartonero"),
    CulturalEntry("cartonero", 2, .earth, "Cartonero", "cart.fill", mergesInto: "kiosco"),
    CulturalEntry("kiosco", 3, .earth, "Personal de Kiosco", "storefront.fill", mergesInto: "repartidor"),
    CulturalEntry("repartidor", 4, .earth, "Repartidor", "bicycle", mergesInto: "chofer_app"),
    CulturalEntry("chofer_app", 5, .earth, "Chofer de App", "car.fill", mergesInto: "fast_food"),
    CulturalEntry("fast_food", 6, .earth, "Empleado de Fast Food", "takeoutbag.and.cup.and.straw.fill", mergesInto: "oficinista"),
    CulturalEntry("oficinista", 7, .earth, "Oficinista", "laptopcomputer", mergesInto: "administrativo"),
    CulturalEntry("administrativo", 8, .earth, "Administrativo", "doc.on.doc.fill", mergesInto: "junior"),
    CulturalEntry(
        "junior", 9, .earth, "Recién Recibido", "graduationcap.fill",
        mergesInto: nil, isChoiceNode: true,
        choiceOptions: ["junior_programmer", "junior_architect", "junior_doctor", "junior_lawyer"]
    ),
    CulturalEntry("junior_programmer", 9, .earth, "Programador Jr.", "chevron.left.forwardslash.chevron.right", mergesInto: "senior_programmer"),
    CulturalEntry("junior_architect", 9, .earth, "Arquitecto Jr.", "ruler.fill", mergesInto: "senior_architect"),
    CulturalEntry("junior_doctor", 9, .earth, "Médico Jr.", "stethoscope", mergesInto: "senior_doctor"),
    CulturalEntry("junior_lawyer", 9, .earth, "Abogado Jr.", "text.book.closed.fill", mergesInto: "senior_lawyer"),
    CulturalEntry("senior_programmer", 10, .earth, "Programador Sr.", "chevron.left.forwardslash.chevron.right", mergesInto: "director"),
    CulturalEntry("senior_architect", 10, .earth, "Arquitecto Sr.", "ruler.fill", mergesInto: "director"),
    CulturalEntry("senior_doctor", 10, .earth, "Médico Sr.", "stethoscope", mergesInto: "director"),
    CulturalEntry("senior_lawyer", 10, .earth, "Abogado Sr.", "text.book.closed.fill", mergesInto: "director"),
    CulturalEntry("director", 11, .earth, "Director", "briefcase.fill", mergesInto: "fundador_startup"),
    CulturalEntry("fundador_startup", 12, .earth, "Fundador de Startup", "lightbulb.fill", mergesInto: "dueno_pyme"),
    CulturalEntry("dueno_pyme", 13, .earth, "Dueño de PYME", "box.truck.fill", mergesInto: "emprendedor"),
    CulturalEntry("emprendedor", 14, .earth, "Emprendedor", "megaphone.fill", mergesInto: "ceo"),
    CulturalEntry("ceo", 15, .earth, "CEO", "building.2.fill", mergesInto: "millonario"),
    CulturalEntry("millonario", 16, .earth, "Millonario", "dollarsign.circle.fill", mergesInto: "multimillonario"),
    CulturalEntry("multimillonario", 17, .earth, "Multimillonario", "banknote.fill", mergesInto: "rey_ladrillo"),
    CulturalEntry("rey_ladrillo", 18, .earth, "Rey del Ladrillo", "building.columns.fill", mergesInto: "magnate_petrolero"),
    CulturalEntry("magnate_petrolero", 19, .earth, "Magnate Petrolero", "fuelpump.fill", mergesInto: "space_billionaire"),
    CulturalEntry("space_billionaire", 20, .earth, "Space Billionaire", "paperplane.fill", mergesInto: "trillonario"),
    CulturalEntry("trillonario", 21, .earth, "Trillonario", "infinity", mergesInto: "dueno_luna"),
    // Fase Cósmica (22–30): Owns The Moon → God con winks argentinos en el flavor.
    CulturalEntry("dueno_luna", 22, .cosmic, "Dueño de la Luna", "moon.fill", mergesInto: "dueno_marte"),
    CulturalEntry("dueno_marte", 23, .cosmic, "Dueño de Marte", "globe.americas.fill", mergesInto: "magnate_solar"),
    CulturalEntry("magnate_solar", 24, .cosmic, "Magnate del Sistema Solar", "sun.max.fill", mergesInto: "senor_galaxia"),
    CulturalEntry("senor_galaxia", 25, .cosmic, "Señor de la Galaxia", "sparkles", mergesInto: "emperador_cosmico"),
    CulturalEntry("emperador_cosmico", 26, .cosmic, "Emperador Cósmico", "crown.fill", mergesInto: "ser_ascendido"),
    CulturalEntry("ser_ascendido", 27, .cosmic, "Ser Ascendido", "figure.mind.and.body", mergesInto: "semidios"),
    CulturalEntry("semidios", 28, .cosmic, "Semidiós", "bolt.fill", mergesInto: "deidad"),
    CulturalEntry("deidad", 29, .cosmic, "Deidad", "flame.fill", mergesInto: "god"),
    CulturalEntry("god", 30, .cosmic, "Dios", "eye.fill", mergesInto: nil),
]

struct GeneratorError: Error, CustomStringConvertible {
    let description: String
}

func parseArguments() throws -> (economyURL: URL, outputURL: URL) {
    var economyPath: String?
    var outputPath: String?
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--economy": economyPath = iterator.next()
        case "--output": outputPath = iterator.next()
        default: throw GeneratorError(description: "unknown argument '\(argument)'")
        }
    }
    guard let economyPath, let outputPath else {
        throw GeneratorError(description: "usage: generate-tiers --economy <economy.json> --output <tiers.json>")
    }
    return (URL(fileURLWithPath: economyPath), URL(fileURLWithPath: outputPath))
}

do {
    let (economyURL, outputURL) = try parseArguments()
    let config = try JSONDecoder().decode(EconomyConfig.self, from: Data(contentsOf: economyURL))
    let economy = StandardEconomy(config: config)

    let types = culturalTable.map { entry in
        CharacterType(
            id: entry.id,
            tier: entry.tier,
            phase: entry.phase,
            displayName: entry.displayName,
            spritePlaceholder: "sf:\(entry.symbol)",
            spriteAssetKey: nil,
            tapYield: economy.tapYield(forTier: entry.tier),
            passiveYieldPerInstance: economy.passiveYield(forTier: entry.tier),
            passiveUnlockCost: economy.passiveUnlockCost(forTier: entry.tier),
            mergesInto: entry.mergesInto,
            isChoiceNode: entry.isChoiceNode,
            choiceOptions: entry.choiceOptions
        )
    }

    // Self-check: never emit a tiers.json the game itself would reject.
    let repository = try TierRepository(types: types)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(TiersFile(schemaVersion: 1, types: types))
    try data.write(to: outputURL, options: .atomic)

    print("generate-tiers: wrote \(types.count) entries (\(repository.concreteTypes.count) concrete, max tier \(repository.maxTier)) to \(outputURL.path)")
} catch {
    FileHandle.standardError.write(Data("generate-tiers: error: \(error)\n".utf8))
    exit(1)
}
