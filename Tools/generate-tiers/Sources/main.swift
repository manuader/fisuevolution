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

/// Cadena de 37 tiers repartida en los 10 pisos de la torre, 4 por piso salvo el
/// de Dios (spec `2026-08-06-siete-personajes-y-remapeo.md` §5). El orden de la
/// lista es el de la cadena de merge y cada bloque de 4 es un piso.
///
/// El corte `earth`/`cosmic` cae entre el ÚLTIMO del piso `moon` (T24, Dueño de
/// la Luna) y el PRIMERO de `mars` (T25, Dueño de Marte), para que el cambio de
/// fase coincida con un borde de piso y no parta uno al medio. Por eso el Dueño
/// de la Luna es `.earth` aunque su nombre suene cósmico: vive en el último piso
/// de la fase terrenal. El atlas NO sale de acá — lo fija `assets_manifest.json`
/// por personaje, así que su sprite sigue en `cosmic.atlas`.
let culturalTable: [CulturalEntry] = [
    // Piso 1 — alley (T1–T4): nada → un trapo → un secador → un carro.
    CulturalEntry("homeless", 1, .earth, "El Fisura", "person.fill", mergesInto: "trapito"),
    CulturalEntry("trapito", 2, .earth, "El Trapito", "hand.raised.fill", mergesInto: "limpiavidrios"),
    CulturalEntry("limpiavidrios", 3, .earth, "Limpiavidrios", "drop.fill", mergesInto: "cartonero"),
    CulturalEntry("cartonero", 4, .earth, "Cartonero", "cart.fill", mergesInto: "mantero"),
    // Piso 2 — urban (T5–T8): una manta → una moto → un auto → un uniforme.
    CulturalEntry("mantero", 5, .earth, "El Mantero", "bag.fill", mergesInto: "repartidor"),
    CulturalEntry("repartidor", 6, .earth, "Repartidor", "bicycle", mergesInto: "chofer_app"),
    CulturalEntry("chofer_app", 7, .earth, "Chofer de App", "car.fill", mergesInto: "fast_food"),
    CulturalEntry("fast_food", 8, .earth, "Empleado de Fast Food", "takeoutbag.and.cup.and.straw.fill", mergesInto: "oficinista"),
    // Piso 3 — corporate (T9–T12): T11/T12 son la bifurcación de carrera (elección UBA).
    CulturalEntry("oficinista", 9, .earth, "Oficinista", "laptopcomputer", mergesInto: "administrativo"),
    CulturalEntry("administrativo", 10, .earth, "Administrativo", "doc.on.doc.fill", mergesInto: "junior"),
    CulturalEntry(
        "junior", 11, .earth, "Recién Recibido", "graduationcap.fill",
        mergesInto: nil, isChoiceNode: true,
        choiceOptions: ["junior_programmer", "junior_architect", "junior_doctor", "junior_lawyer"]
    ),
    CulturalEntry("junior_programmer", 11, .earth, "Programador Jr.", "chevron.left.forwardslash.chevron.right", mergesInto: "senior_programmer"),
    CulturalEntry("junior_architect", 11, .earth, "Arquitecto Jr.", "ruler.fill", mergesInto: "senior_architect"),
    CulturalEntry("junior_doctor", 11, .earth, "Médico Jr.", "stethoscope", mergesInto: "senior_doctor"),
    CulturalEntry("junior_lawyer", 11, .earth, "Abogado Jr.", "text.book.closed.fill", mergesInto: "senior_lawyer"),
    CulturalEntry("senior_programmer", 12, .earth, "Programador Sr.", "chevron.left.forwardslash.chevron.right", mergesInto: "director"),
    CulturalEntry("senior_architect", 12, .earth, "Arquitecto Sr.", "ruler.fill", mergesInto: "director"),
    CulturalEntry("senior_doctor", 12, .earth, "Médico Sr.", "stethoscope", mergesInto: "director"),
    CulturalEntry("senior_lawyer", 12, .earth, "Abogado Sr.", "text.book.closed.fill", mergesInto: "director"),
    // Piso 4 — luxury (T13–T16).
    CulturalEntry("director", 13, .earth, "Director", "briefcase.fill", mergesInto: "fundador_startup"),
    CulturalEntry("fundador_startup", 14, .earth, "Fundador de Startup", "lightbulb.fill", mergesInto: "dueno_pyme"),
    CulturalEntry("dueno_pyme", 15, .earth, "Dueño de PYME", "box.truck.fill", mergesInto: "emprendedor"),
    CulturalEntry("emprendedor", 16, .earth, "Emprendedor", "megaphone.fill", mergesInto: "ceo"),
    // Piso 5 — island (T17–T20).
    CulturalEntry("ceo", 17, .earth, "CEO", "building.2.fill", mergesInto: "millonario"),
    CulturalEntry("millonario", 18, .earth, "Millonario", "dollarsign.circle.fill", mergesInto: "multimillonario"),
    CulturalEntry("multimillonario", 19, .earth, "Multimillonario", "banknote.fill", mergesInto: "rey_ladrillo"),
    CulturalEntry("rey_ladrillo", 20, .earth, "Rey del Ladrillo", "building.columns.fill", mergesInto: "magnate_petrolero"),
    // Piso 6 — moon (T21–T24). Última tanda terrenal: el corte de fase va después.
    CulturalEntry("magnate_petrolero", 21, .earth, "Magnate Petrolero", "fuelpump.fill", mergesInto: "space_billionaire"),
    CulturalEntry("space_billionaire", 22, .earth, "Space Billionaire", "paperplane.fill", mergesInto: "trillonario"),
    CulturalEntry("trillonario", 23, .earth, "Trillonario", "infinity", mergesInto: "dueno_luna"),
    CulturalEntry("dueno_luna", 24, .earth, "Dueño de la Luna", "moon.fill", mergesInto: "dueno_marte"),
    // Piso 7 — mars (T25–T28). Arranca la fase cósmica.
    CulturalEntry("dueno_marte", 25, .cosmic, "Dueño de Marte", "globe.americas.fill", mergesInto: "rey_asteroides"),
    CulturalEntry("rey_asteroides", 26, .cosmic, "Rey de los Asteroides", "circle.hexagongrid.fill", mergesInto: "magnate_solar"),
    CulturalEntry("magnate_solar", 27, .cosmic, "Magnate del Sistema Solar", "sun.max.fill", mergesInto: "fondo_buitre"),
    CulturalEntry("fondo_buitre", 28, .cosmic, "Fondo Buitre Estelar", "doc.text.fill", mergesInto: "rentista_soles"),
    // Piso 8 — solar (T29–T32).
    CulturalEntry("rentista_soles", 29, .cosmic, "Rentista de Soles", "key.fill", mergesInto: "estanciero_estelar"),
    CulturalEntry("estanciero_estelar", 30, .cosmic, "Estanciero Estelar", "leaf.fill", mergesInto: "senor_galaxia"),
    CulturalEntry("senor_galaxia", 31, .cosmic, "Señor de la Galaxia", "sparkles", mergesInto: "coleccionista_galaxias"),
    CulturalEntry("coleccionista_galaxias", 32, .cosmic, "Coleccionista de Galaxias", "square.grid.3x3.fill", mergesInto: "emperador_cosmico"),
    // Piso 9 — galaxy (T33–T36): el tramo trascendente.
    CulturalEntry("emperador_cosmico", 33, .cosmic, "Emperador Cósmico", "crown.fill", mergesInto: "ser_ascendido"),
    CulturalEntry("ser_ascendido", 34, .cosmic, "Ser Ascendido", "figure.mind.and.body", mergesInto: "semidios"),
    CulturalEntry("semidios", 35, .cosmic, "Semidiós", "bolt.fill", mergesInto: "deidad"),
    CulturalEntry("deidad", 36, .cosmic, "Deidad", "flame.fill", mergesInto: "god"),
    // Piso 10 — god_realm (T37).
    CulturalEntry("god", 37, .cosmic, "Dios", "eye.fill", mergesInto: nil),
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
