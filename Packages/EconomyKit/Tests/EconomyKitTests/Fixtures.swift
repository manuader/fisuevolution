import Foundation
@testable import EconomyKit

// MARK: - Fixtures compartidas v2 (F7 "La Torre")
//
// Escalera chica espejo de la real (choice node en T3 como la carrera en T9):
//   a(1) → b(2) → [choice] c_prog/c_law (3) → d(4, terminal)
// Torre fixture: f1 {T1-2} y f2 {T3-4}, capacity 5, incomeMultiplier 1.0 (los
// tests de valores exactos no quieren multiplicadores escondidos). f1 overridea
// la curva de hire a 15/1.15 (mismos números que la curva de spawn vieja); f2
// usa el default PUNITIVO 100/2.0.

func fxConfig(
    capacity: Int = 5,
    f2IncomeMultiplier: Double = 1.0,
    hireDefaultMultiplier: Double = 100,
    hireDefaultGrowth: Double = 2.0,
    priceGrowthPerTier: Double = 1.5,
    frontierEscalationPerTier: Double = EconomyConfig.HireConfig.noFrontierEscalation,
    frontierEscalationFromTier: Int = EconomyConfig.HireConfig.escalationFromFirstTier,
    tapFloorMultiplierExponent: Double? = nil
) -> EconomyConfig {
    EconomyConfig(
        schemaVersion: 2,
        baseTapYieldTier1: 1,
        yieldGrowthPerTier: 3.8,
        passiveRatio: 0.3,
        passiveUnlockCostMultiplier: 100,
        tapFloorMultiplierExponent: tapFloorMultiplierExponent,
        hire: .init(
            defaultCostMultiplier: hireDefaultMultiplier,
            defaultCostGrowth: hireDefaultGrowth,
            priceGrowthPerTier: priceGrowthPerTier,
            frontierEscalationPerTier: frontierEscalationPerTier,
            frontierEscalationFromTier: frontierEscalationFromTier
        ),
        charUpgrades: .init(baseCostMultiplier: 10, costGrowth: 2.0, effectStepPerLevel: 1.0),
        oro: .init(divisor: 1_000_000, exponent: 0.5, globalMultiplierPerOro: 0.02),
        critChanceBase: 0,
        critMultiplier: 5,
        offlineEfficiencyBase: 0.5,
        offlineCapHours: 8,
        floors: [
            FloorDef(
                id: "f1", background: "alley", firstTier: 1, lastTier: 2,
                capacity: capacity, incomeMultiplier: 1.0,
                hireCostMultiplierOverride: 15, hireCostGrowthOverride: 1.15
            ),
            FloorDef(
                id: "f2", background: "urban", firstTier: 3, lastTier: 4,
                capacity: capacity, incomeMultiplier: f2IncomeMultiplier
            ),
        ]
    )
}

func fxEconomy(config: EconomyConfig = fxConfig()) -> StandardEconomy {
    StandardEconomy(config: config)
}

func fxType(
    _ id: String,
    tier: Int,
    tapYield: Double = 1,
    mergesInto: String? = nil,
    isChoiceNode: Bool = false,
    choiceOptions: [String]? = nil
) -> CharacterType {
    CharacterType(
        id: id, tier: tier, phase: .earth, displayName: id,
        spritePlaceholder: "sf:person.fill",
        tapYield: tapYield, passiveYieldPerInstance: tapYield * 0.3, passiveUnlockCost: tapYield * 100,
        mergesInto: mergesInto, isChoiceNode: isChoiceNode, choiceOptions: choiceOptions
    )
}

func fxTiers() throws -> TierRepository {
    try TierRepository(types: [
        fxType("a", tier: 1, mergesInto: "b"),
        fxType("b", tier: 2, mergesInto: "choice"),
        fxType("choice", tier: 3, isChoiceNode: true, choiceOptions: ["c_prog", "c_law"]),
        fxType("c_prog", tier: 3, tapYield: 14.44, mergesInto: "d"),
        fxType("c_law", tier: 3, tapYield: 14.44, mergesInto: "d"),
        fxType("d", tier: 4, tapYield: 54.87),
    ])
}

func fxFloorTable(config: EconomyConfig = fxConfig()) throws -> FloorTable {
    try FloorTable(floors: config.floors, maxTier: 4)
}

/// Estado v4 con unidades dadas. `unlockedFloors` arranca con ambos pisos para
/// que las acciones no fallen por gate de desbloqueo (los tests de gate lo pisan).
func fxState(units: [String: Int] = ["a": 1], unlockedFloors: [String] = ["f1", "f2"]) -> PlayerState {
    var state = PlayerState.newGame(
        startTypeId: "a", startFloorId: "f1",
        offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 1000
    )
    state.run.units = units
    state.run.unlockedFloors = unlockedFloors
    state.meta.lastSeenTimestamp = 1000
    return state
}

/// Estado + torre reconciliada (slots poblados desde units).
func fxStateAndTower(
    units: [String: Int] = ["a": 1],
    unlockedFloors: [String] = ["f1", "f2"],
    config: EconomyConfig = fxConfig()
) throws -> (state: PlayerState, tower: TowerState, floorTable: FloorTable) {
    var state = fxState(units: units, unlockedFloors: unlockedFloors)
    let floorTable = try fxFloorTable(config: config)
    let tiers = try fxTiers()
    let outcome = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers)
    return (state, outcome.tower, floorTable)
}

/// Slot del primer placement de un tipo en un piso (para tests de acciones).
func fxSlot(of typeId: String, onFloor ordinal: Int, in tower: TowerState) -> Int? {
    tower.placements(onFloor: ordinal).first(where: { $0.typeId == typeId })?.slot
}

/// Slots de un tipo en un piso (para pares).
func fxSlots(of typeId: String, onFloor ordinal: Int, in tower: TowerState) -> [Int] {
    tower.placements(onFloor: ordinal).filter { $0.typeId == typeId }.map(\.slot)
}

// MARK: - Fixtures de cofres (F8)

/// PRNG determinista (SplitMix64). Sembrado a mano porque un sorteo verificado
/// con `SystemRandomNumberGenerator` sería "casi siempre verde"; y con estado
/// real y no un valor constante porque un generador que devuelve siempre lo
/// mismo cuelga a `Int.random` en el rechazo del muestreo de Lemire.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Una bolsa de cofre con la forma de la real: 7 comunes, 14 raras, 12 épicas y 8
/// legendarias. Los ids son `<rareza>_<n>` para que un fallo diga de una qué salió.
func fxChestSkins(
    comun: Int = 7, rara: Int = 14, epica: Int = 12, legendaria: Int = 8
) -> SkinsConfig {
    var entradas: [SkinsConfig.Entry] = []
    for (rareza, cuantas) in [(SkinsConfig.Rarity.comun, comun), (.rara, rara),
                              (.epica, epica), (.legendaria, legendaria)] {
        for n in 0..<cuantas {
            entradas.append(.init(
                id: "\(rareza.rawValue)_\(n)", characterType: "t\(entradas.count)",
                treatment: .texture, textureKey: "t\(entradas.count)__\(rareza.rawValue)_\(n)",
                chestRarity: rareza
            ))
        }
    }
    return SkinsConfig(schemaVersion: 1, skins: entradas)
}

/// Todos los personajes de una bolsa, desbloqueados. Es lo que pide un test que
/// NO está mirando la regla de desbloqueo — y se escribe así, explícito, porque
/// `ChestRoller.roll` no le pone default a `unlocked` a propósito: un default
/// sería la puerta por la que la regla del dueño se apaga sin que nada se ponga
/// rojo.
func fxTodoDesbloqueado(_ skins: SkinsConfig) -> Set<String> {
    Set(skins.chestPool.map(\.characterType))
}

/// Los personajes de las rarezas que se listan, y nadie más. Es el jugador que
/// llegó hasta cierto punto de la torre: la bolsa se repartió por el piso donde
/// vive cada personaje, así que una rareza ES una banda de pisos.
func fxDesbloqueadoHasta(
    _ skins: SkinsConfig, _ rarezas: SkinsConfig.Rarity...
) -> Set<String> {
    Set(skins.chestPool.filter { rarezas.contains($0.chestRarity!) }.map(\.characterType))
}

func fxChests(
    comun: Int = 55, rara: Int = 28, epica: Int = 12, legendaria: Int = 5
) -> ChestsConfig {
    ChestsConfig(
        schemaVersion: 1,
        weights: [.init(rarity: .comun, weight: comun), .init(rarity: .rara, weight: rara),
                  .init(rarity: .epica, weight: epica), .init(rarity: .legendaria, weight: legendaria)],
        floorsPerChest: 2, completedPayoutFactor: 6, prestigePayoutFactor: 12,
        welcomeSkinId: "comun_0"
    )
}
