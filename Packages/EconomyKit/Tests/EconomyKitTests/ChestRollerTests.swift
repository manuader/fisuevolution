import Testing
@testable import EconomyKit

@Suite("El sorteo de un cofre")
struct ChestRollerTests {
    @Test("sortea una skin de la rareza que salió, y nunca una que ya tenés")
    func rollsUnownedOfDrawnRarity() {
        let skins = fxChestSkins()
        var rng: any RandomNumberGenerator = SeededRNG(seed: 7)
        // Una ya tomada: si el sorteo la devolviera, el cofre repartiría algo que el
        // jugador ya tiene, que es el modo de fallar más caro del sistema.
        let owned: Set<String> = ["comun_0"]
        for _ in 0..<200 {
            guard case let .skin(id, _, rarity) = ChestRoller.roll(
                owned: owned, skins: skins, config: fxChests(), using: &rng
            ) else { Issue.record("esperaba skin"); return }
            #expect(!owned.contains(id))
            #expect(skins.chestPool.first { $0.id == id }?.chestRarity == rarity)
        }
    }

    @Test("con la rareza sorteada agotada, promociona hacia ARRIBA")
    func promotesUpwardWhenExhausted() {
        let skins = fxChestSkins()
        // Todas las comunes tomadas. Con peso 55 sobre 100, sin promoción más de la
        // mitad de estas 200 tiradas no daría skin.
        let owned = Set(skins.chestPool.filter { $0.chestRarity == .comun }.map(\.id))
        var rng: any RandomNumberGenerator = SeededRNG(seed: 11)
        for _ in 0..<200 {
            guard case let .skin(_, _, rarity) = ChestRoller.roll(
                owned: owned, skins: skins, config: fxChests(), using: &rng
            ) else { Issue.record("esperaba skin"); return }
            #expect(rarity != .comun)
        }
    }

    @Test("sin nada arriba, baja")
    func fallsDownWhenNothingAbove() {
        let skins = fxChestSkins()
        let owned = Set(skins.chestPool.filter { $0.chestRarity != .comun }.map(\.id))
        var rng: any RandomNumberGenerator = SeededRNG(seed: 3)
        guard case let .skin(_, _, rarity) = ChestRoller.roll(
            owned: owned, skins: skins, config: fxChests(), minRarity: .legendaria, using: &rng
        ) else { Issue.record("esperaba skin"); return }
        #expect(rarity == .comun)
    }

    @Test("con la colección completa paga plata")
    func paysCoinsWhenCollectionIsComplete() {
        let skins = fxChestSkins()
        let owned = Set(skins.chestPool.map(\.id))
        var rng: any RandomNumberGenerator = SeededRNG(seed: 5)
        guard case .coins = ChestRoller.roll(
            owned: owned, skins: skins, config: fxChests(), using: &rng
        ) else { Issue.record("esperaba plata"); return }
    }

    @Test("la rareza mínima no deja salir nada por debajo mientras haya stock")
    func minRarityKeepsResultsAtOrAbove() {
        let skins = fxChestSkins()
        var rng: any RandomNumberGenerator = SeededRNG(seed: 13)
        for _ in 0..<200 {
            guard case let .skin(_, _, rarity) = ChestRoller.roll(
                owned: [], skins: skins, config: fxChests(), minRarity: .epica, using: &rng
            ) else { Issue.record("esperaba skin"); return }
            #expect(rarity >= .epica)
        }
    }

    @Test("41 cofres seguidos vacían la bolsa entera, sin una sola repetida")
    func fortyOneChestsCompleteTheCollection() {
        let skins = fxChestSkins()
        var owned: Set<String> = []
        var rng: any RandomNumberGenerator = SeededRNG(seed: 21)
        for n in 0..<skins.chestPool.count {
            guard case let .skin(id, _, _) = ChestRoller.roll(
                owned: owned, skins: skins, config: fxChests(), using: &rng
            ) else { Issue.record("cofre \(n): esperaba skin, la bolsa no estaba vacía"); return }
            #expect(owned.insert(id).inserted, "cofre \(n) repitió \(id)")
        }
        #expect(owned.count == 41)
    }

    @Test("la semilla manda: dos corridas iguales dan lo mismo, y una corrida no da ocho veces lo mismo")
    func theSeedDrivesTheWholeSequence() {
        let skins = fxChestSkins()
        // Sin `owned` que cambie entre tiradas, lo ÚNICO que puede mover el resultado
        // es el estado del generador. Si el `inout` dejara de escribirse de vuelta
        // —una copia local, una firma refactorizada— los otros seis tests seguirían
        // verdes midiendo una sola tirada repetida 200 veces, y nadie se enteraría.
        func ochoTiradas(semilla: UInt64) -> [ChestOutcome] {
            var rng: any RandomNumberGenerator = SeededRNG(seed: semilla)
            return (0..<8).map { _ in
                ChestRoller.roll(owned: [], skins: skins, config: fxChests(), using: &rng)
            }
        }
        let tirada = ochoTiradas(semilla: 99)
        #expect(tirada == ochoTiradas(semilla: 99), "la misma semilla tiene que reproducir la corrida entera")
        #expect(tirada.contains { $0 != tirada[0] }, "ocho resultados idénticos: el generador no avanzó")
        // Sin esto, `ochoTiradas` está parametrizado y se llama con UNA semilla:
        // un `SeededRNG` que ignorara la suya —devolviendo siempre la misma
        // secuencia— pasaría los dos `#expect` de arriba sin despeinarse.
        #expect(tirada != ochoTiradas(semilla: 100), "dos semillas distintas no pueden dar la misma corrida")
    }
}
