import Foundation
import Testing
@testable import EconomyKit

@Suite("Las probabilidades del cofre: lo que se muestra es lo que se sortea")
struct ChestOddsTests {
    /// Las `PrizeOdds` de E5a llevan la rareza en el `id`.
    private func shares(_ table: ChestOddsTable) -> [SkinsConfig.Rarity: Double] {
        guard case .skins(let odds) = table else { return [:] }
        return Dictionary(uniqueKeysWithValues: odds.compactMap { row in
            SkinsConfig.Rarity(rawValue: row.id).map { ($0, row.probability) }
        })
    }

    @Test("cada fila es una rareza, en orden, y suman 1")
    func rowsAreRarities() {
        let skins = fxChestSkins()
        guard case .skins(let odds) = ChestRoller.effectiveOdds(
            owned: [], unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests()
        ) else {
            Issue.record("con todo desbloqueado hay tabla")
            return
        }
        #expect(odds.map(\.id) == SkinsConfig.Rarity.allCases.map(\.rawValue))
        #expect(abs(odds.map(\.probability).reduce(0, +) - 1) < 1e-12)
    }

    @Test("con todo disponible, son los pesos del dato")
    func rawWeights() {
        let skins = fxChestSkins()
        let odds = shares(ChestRoller.effectiveOdds(owned: [], unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests()))
        #expect(abs((odds[.comun] ?? 0) - 0.55) < 1e-12)
        #expect(abs((odds[.rara] ?? 0) - 0.28) < 1e-12)
        #expect(abs((odds[.epica] ?? 0) - 0.12) < 1e-12)
        #expect(abs((odds[.legendaria] ?? 0) - 0.05) < 1e-12)
    }

    @Test("una rareza agotada pasa su chance a la que el sorteo promociona")
    func exhaustedPromotes() {
        let skins = fxChestSkins()
        let comunes = Set(skins.chestPool.filter { $0.chestRarity == .comun }.map(\.id))
        let odds = shares(ChestRoller.effectiveOdds(owned: comunes, unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests()))
        #expect(odds[.comun] == nil)
        #expect(abs((odds[.rara] ?? 0) - 0.83) < 1e-12, "las comunes suben a raras")
    }

    @Test("sólo lo desbloqueado: lo de arriba degrada hacia abajo")
    func lockedDegrades() {
        let skins = fxChestSkins()
        let odds = shares(ChestRoller.effectiveOdds(
            owned: [], unlocked: fxDesbloqueadoHasta(skins, .comun, .rara), skins: skins, config: fxChests()
        ))
        #expect(abs((odds[.comun] ?? 0) - 0.55) < 1e-12)
        #expect(abs((odds[.rara] ?? 0) - 0.45) < 1e-12, "épica y legendaria bajan a rara")
        #expect(odds[.epica] == nil)
    }

    @Test("el cofre de prestigio sólo sortea de épica para arriba")
    func minimumRarity() {
        let skins = fxChestSkins()
        let odds = shares(ChestRoller.effectiveOdds(
            owned: [], unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests(), minRarity: .epica
        ))
        #expect(abs((odds[.epica] ?? 0) - 12.0 / 17.0) < 1e-12)
        #expect(abs((odds[.legendaria] ?? 0) - 5.0 / 17.0) < 1e-12)
    }

    @Test("una rareza con peso 0 no aparece en la tabla")
    func zeroWeightRowIsAbsent() {
        let skins = fxChestSkins()
        let odds = shares(ChestRoller.effectiveOdds(
            owned: [], unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests(legendaria: 0)
        ))
        #expect(odds[.legendaria] == nil)
        #expect(abs(odds.values.reduce(0, +) - 1) < 1e-12)
    }

    @Test("colección completa: paga plata; nada alcanzable todavía: no hay tabla")
    func noSkinsCases() {
        let skins = fxChestSkins()
        let all = Set(skins.chestPool.map(\.id))
        #expect(ChestRoller.effectiveOdds(owned: all, unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests()) == .coins)
        #expect(ChestRoller.effectiveOdds(owned: [], unlocked: [], skins: skins, config: fxChests()) == .nothingYet)
    }

    @Test("las pintas alcanzables son las que no tiene y puede ganar")
    func reachableCount() {
        let skins = fxChestSkins()
        let todo = fxTodoDesbloqueado(skins)
        let total = skins.chestPool.count
        #expect(ChestRoller.reachableSkinCount(owned: [], unlocked: todo, skins: skins) == total)
        #expect(ChestRoller.reachableSkinCount(owned: [], unlocked: [], skins: skins) == 0)
        let una = Set(skins.chestPool.prefix(1).map(\.id))
        #expect(ChestRoller.reachableSkinCount(owned: una, unlocked: todo, skins: skins) == total - 1)
    }

    @Test("la tabla coincide con 20.000 sorteos de verdad")
    func matchesTheRolls() {
        let skins = fxChestSkins()
        let owned = Set(skins.chestPool.filter { $0.chestRarity == .comun }.prefix(5).map(\.id))
        let unlocked = fxDesbloqueadoHasta(skins, .comun, .rara, .epica)
        let odds = shares(ChestRoller.effectiveOdds(owned: owned, unlocked: unlocked, skins: skins, config: fxChests()))
        var rng = SeededRNG(seed: 7)
        var counts: [SkinsConfig.Rarity: Int] = [:]
        let rolls = 20_000
        for _ in 0..<rolls {
            if case .prize(.skin(_, _, let rarity)) = ChestRoller.roll(
                owned: owned, unlocked: unlocked, skins: skins, config: fxChests(), using: &rng
            ) {
                counts[rarity, default: 0] += 1
            }
        }
        for rarity in SkinsConfig.Rarity.allCases {
            let seen = Double(counts[rarity] ?? 0) / Double(rolls)
            #expect(abs(seen - (odds[rarity] ?? 0)) < 0.01, "\(rarity): sorteado \(seen), mostrado \(odds[rarity] ?? 0)")
        }
    }
}
