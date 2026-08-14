import Foundation
import Testing
@testable import EconomyKit

// MARK: - Drill de extensibilidad (F7.6 — spec §7, principio §6.1)
//
// El principio dice: "agregar contenido = editar JSON + soltar PNGs; cero
// código". Eso es una promesa fácil de romper sin darse cuenta (un `11`
// hardcodeado, un switch por etapa, un enum de pisos). Este drill la convierte
// en un test: monta una config con UN PISO MÁS, UN PERSONAJE MÁS y UNA SKIN MÁS
// —todo declarado como datos, sin tocar una línea de producción— y verifica que
// los sistemas la adopten enteros.
//
// Si alguien vuelve a meter un número mágico, este archivo se pone rojo.

/// Contenido "del futuro": 12 pisos y una escalera de 13 tiers, declarados acá
/// como si vinieran de economy.json/tiers.json.
private func drillFloors(count: Int = 12) -> [FloorDef] {
    (0..<count).map { index in
        FloorDef(
            id: "floor\(index + 1)",
            background: "bg\(index + 1)",
            firstTier: index + 1,
            lastTier: index + 1,
            capacity: 4,
            incomeMultiplier: 1.0 + Double(index)
        )
    }
}

/// Escalera lineal t1 → t2 → … → t12, un tier por piso: el tier 12 estrena el
/// piso 12 y recibe las promociones que suben desde el 11.
private func drillTiers(maxTier: Int = 12) throws -> TierRepository {
    try TierRepository(types: (1...maxTier).map { tier in
        fxType(
            "t\(tier)",
            tier: tier,
            tapYield: pow(2.0, Double(tier - 1)),
            mergesInto: tier < maxTier ? "t\(tier + 1)" : nil
        )
    })
}

@Suite("Drill de extensibilidad: piso 12 + personaje + skin, cero código")
struct ExtensibilityDrillTests {
    @Test("un piso 12 declarado en config entra sin tocar código")
    func extraFloorIsAdopted() throws {
        let floors = drillFloors()
        let tiers = try drillTiers()
        let table = try FloorTable(floors: floors, maxTier: tiers.maxTier)

        // Nadie asume 11: la tabla adopta la cantidad que le den.
        #expect(table.count == 12)
        #expect(table.floors.last?.id == "floor12")
        // El tier 12 mapea al piso 12 y el 13 al último, sin huecos ni solapes.
        #expect(table.ordinal(forTier: 12) == 11)
        #expect(table[table.ordinal(forTier: 12)].id == "floor12")
        #expect(table.ordinal(of: "floor12") == 11)
    }

    @Test("un personaje nuevo del piso 12 se contrata y se mergea igual que el resto")
    func extraCharacterPlaysByTheSameRules() throws {
        let floors = drillFloors()
        let tiers = try drillTiers()
        let table = try FloorTable(floors: floors, maxTier: tiers.maxTier)
        let config = EconomyConfig(
            schemaVersion: 2,
            baseTapYieldTier1: 1,
            yieldGrowthPerTier: 2,
            passiveRatio: 0.5,
            passiveUnlockCostMultiplier: 60,
            hire: .init(defaultCostMultiplier: 10, defaultCostGrowth: 1.5),
            charUpgrades: .init(baseCostMultiplier: 50, costGrowth: 4, effectFactorPerLevel: 2),
            oro: .init(divisor: 1_000_000, exponent: 0.5, globalMultiplierPerOro: 0.12),
            critChanceBase: 0,
            critMultiplier: 5,
            offlineEfficiencyBase: 0.35,
            offlineCapHours: 10,
            floors: floors
        )
        let economy = StandardEconomy(config: config)

        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "floor1",
            offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 0
        )
        // Dos t11 en el piso 11: el material para estrenar el piso 12.
        state.run.units = ["t11": 2]
        // El piso 12 arranca BLOQUEADO a propósito: el ascenso lo tiene que abrir.
        state.run.unlockedFloors = floors.dropLast().map(\.id)
        state.run.maxTierReached = 11
        state.run.coins = 1_000_000

        var tower = TowerReconciler.reconcile(run: &state.run, floorTable: table, tiers: tiers).tower
        #expect(tower.placements(onFloor: 10).map(\.typeId) == ["t11", "t11"])

        // Mergear en el piso 11 asciende al 12 y lo DESBLOQUEA: el piso nuevo
        // entra al juego por la misma regla que los otros once.
        let slots = tower.placements(onFloor: 10).map(\.slot).sorted()
        let result = try TowerActions.applyMerge(
            floorOrdinal: 10, sourceSlot: slots[0], targetSlot: slots[1],
            newTypeId: "t12", state: &state, tower: &tower, tiers: tiers, floorTable: table
        )
        guard case let .promoted(toFloorOrdinal, _, newTypeId, unlockedFloorId) = result else {
            Issue.record("esperaba una promoción al piso 12, llegó \(result)")
            return
        }
        #expect(toFloorOrdinal == 11)
        #expect(newTypeId == "t12")
        #expect(unlockedFloorId == "floor12")
        #expect(state.run.unlockedFloors.contains("floor12"))
        #expect(tower.unitCounts == state.run.units)

        // Y su tier base se contrata con la curva que declara la config, sin
        // ninguna tabla por etapa: el precio es el multiplicador por lo que
        // RINDE UN CLICK en ese piso (tapYield × incomeMultiplier del piso).
        let floor12 = table[11]
        let quote = try #require(TowerActions.hireQuote(
            floorOrdinal: 11, state: state, tiers: tiers,
            floorTable: table, config: config
        ))
        #expect(quote.type.id == "t12")
        #expect(quote.cost == 10 * economy.tapYield(forTier: 12) * floor12.incomeMultiplier)
        try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: table)
        #expect(state.run.units["t12"] == 2)
        #expect(state.run.hireCounts["floor12"] == 1)
        #expect(tower.unitCounts == state.run.units)
    }

    @Test("una skin nueva del personaje nuevo valida y se desbloquea por milestone")
    func extraSkinIsCataloguedAndAwarded() throws {
        let floors = drillFloors()
        let tiers = try drillTiers()
        let skins = SkinsConfig(schemaVersion: 1, skins: [
            SkinsConfig.Entry(
                id: "drill_skin",
                characterType: "t12",
                treatment: .texture,
                textureKey: "t12_idle__drill_skin",
                floorReached: "floor12"
            ),
        ])

        // Valida contra el contenido nuevo sin necesitar registro previo.
        try skins.validate(
            characterTypeIDs: Set(tiers.concreteTypes.map(\.id)),
            floorIDs: Set(floors.map(\.id))
        )
        #expect(skins.entries(forCharacterType: "t12").map(\.id) == ["drill_skin"])

        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "floor1",
            offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 0
        )
        // Sin haber llegado al piso 12 todavía no se gana.
        #expect(SkinMilestones.newlyUnlocked(state: state, config: skins).isEmpty)

        state.run.unlockedFloors = ["floor1", "floor12"]
        #expect(SkinMilestones.newlyUnlocked(state: state, config: skins) == ["drill_skin"])

        // Idempotente: una vez acreditada no se vuelve a proponer.
        state.meta.milestoneSkins = ["drill_skin"]
        #expect(SkinMilestones.newlyUnlocked(state: state, config: skins).isEmpty)
    }

    @Test("el arte faltante de la skin nueva no rompe el catálogo")
    func missingArtIsTolerated() throws {
        // El textureKey apunta a un PNG que no existe: el catálogo igual valida
        // (el fallback a textura base vive en la escena y en la ficha). Esto es
        // lo que permite shippear catálogo y arte por separado.
        let skins = SkinsConfig(schemaVersion: 1, skins: [
            SkinsConfig.Entry(
                id: "sin_arte",
                characterType: "t12",
                treatment: .texture,
                textureKey: "t12_idle__todavia_no_existe",
                floorReached: "floor12"
            ),
        ])
        let tiers = try drillTiers()
        try skins.validate(
            characterTypeIDs: Set(tiers.concreteTypes.map(\.id)),
            floorIDs: Set(drillFloors().map(\.id))
        )
    }
}
