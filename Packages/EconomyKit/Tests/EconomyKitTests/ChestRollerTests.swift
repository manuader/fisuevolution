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
            guard case let .prize(.skin(id, _, rarity)) = ChestRoller.roll(
                owned: owned, unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests(), using: &rng
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
            guard case let .prize(.skin(_, _, rarity)) = ChestRoller.roll(
                owned: owned, unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests(), using: &rng
            ) else { Issue.record("esperaba skin"); return }
            #expect(rarity != .comun)
        }
    }

    @Test("sin nada arriba, baja")
    func fallsDownWhenNothingAbove() {
        let skins = fxChestSkins()
        let owned = Set(skins.chestPool.filter { $0.chestRarity != .comun }.map(\.id))
        var rng: any RandomNumberGenerator = SeededRNG(seed: 3)
        guard case let .prize(.skin(_, _, rarity)) = ChestRoller.roll(
            owned: owned, unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests(), minRarity: .legendaria, using: &rng
        ) else { Issue.record("esperaba skin"); return }
        #expect(rarity == .comun)
    }

    @Test("con la colección completa paga plata")
    func paysCoinsWhenCollectionIsComplete() {
        let skins = fxChestSkins()
        let owned = Set(skins.chestPool.map(\.id))
        var rng: any RandomNumberGenerator = SeededRNG(seed: 5)
        guard case .prize(.coins) = ChestRoller.roll(
            owned: owned, unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests(), using: &rng
        ) else { Issue.record("esperaba plata"); return }
    }

    @Test("la rareza mínima no deja salir nada por debajo mientras haya stock")
    func minRarityKeepsResultsAtOrAbove() {
        let skins = fxChestSkins()
        var rng: any RandomNumberGenerator = SeededRNG(seed: 13)
        for _ in 0..<200 {
            guard case let .prize(.skin(_, _, rarity)) = ChestRoller.roll(
                owned: [], unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests(), minRarity: .epica, using: &rng
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
            guard case let .prize(.skin(id, _, _)) = ChestRoller.roll(
                owned: owned, unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests(), using: &rng
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
        func ochoTiradas(semilla: UInt64) -> [ChestDraw] {
            var rng: any RandomNumberGenerator = SeededRNG(seed: semilla)
            return (0..<8).map { _ in
                ChestRoller.roll(owned: [], unlocked: fxTodoDesbloqueado(skins), skins: skins, config: fxChests(), using: &rng)
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

    // MARK: - La regla del dueño: sólo personajes desbloqueados (2026-08-28)

    /// **El candado central**: es imposible que salga la pinta de un personaje al
    /// que el jugador no llegó.
    ///
    /// La bolsa se monta para que el sorteo tenga que PROMOCIONAR: las comunes
    /// están todas tomadas, así que la rareza más pesada (55/100) nunca tiene
    /// stock y cada tirada cae en el camino de promoción. Ese es el punto —
    /// filtrar sólo lo sorteado y olvidarse de la promoción es exactamente el
    /// agujero por el que la Deidad se le aparecería a alguien parado en el
    /// Oficinista.
    @Test("ninguna pinta de un personaje bloqueado sale por ningún camino del sorteo")
    func lockedCharactersNeverDrop() {
        let skins = fxChestSkins()
        let comunes = skins.chestPool.filter { $0.chestRarity == .comun }
        let raras = skins.chestPool.filter { $0.chestRarity == .rara }
        // Llegó a las comunes y a las TRES primeras raras, y nada más.
        let alcanzables = Set(comunes.map(\.characterType) + raras.prefix(3).map(\.characterType))
        let owned = Set(comunes.map(\.id))   // ya se ganó todo lo común
        var rng: any RandomNumberGenerator = SeededRNG(seed: 31)

        for n in 0..<300 {
            let salida = ChestRoller.roll(
                owned: owned, unlocked: alcanzables, skins: skins, config: fxChests(), using: &rng
            )
            guard case let .prize(.skin(_, characterType, rarity)) = salida else {
                Issue.record("cofre \(n): con tres raras libres tenía que salir pinta, salió \(salida)")
                return
            }
            #expect(alcanzables.contains(characterType),
                    "cofre \(n) repartió \(characterType), que el jugador no desbloqueó")
            #expect(rarity == .rara, "cofre \(n): lo único alcanzable y sin ganar son raras")
        }
    }

    /// El mínimo de la reencarnación tampoco es una puerta lateral: pide épica,
    /// y si el jugador no llegó a ningún personaje épico tiene que bajar a lo
    /// que SÍ alcanzó, no entregar una épica bloqueada.
    @Test("ni siquiera el piso de rareza del cofre de prestigio saltea el desbloqueo")
    func minRarityNeverBreaksTheGate() {
        let skins = fxChestSkins()
        let alcanzables = fxDesbloqueadoHasta(skins, .comun, .rara)
        var rng: any RandomNumberGenerator = SeededRNG(seed: 37)
        for n in 0..<200 {
            guard case let .prize(.skin(_, characterType, rarity)) = ChestRoller.roll(
                owned: [], unlocked: alcanzables, skins: skins,
                config: fxChests(), minRarity: .epica, using: &rng
            ) else { Issue.record("cofre \(n): esperaba skin"); return }
            #expect(alcanzables.contains(characterType))
            #expect(rarity <= .rara, "no llegó a ningún épico: el piso tiene que ceder, no el desbloqueo")
        }
    }

    /// Con todo lo alcanzable ya ganado pero la colección a medio llenar, el
    /// cofre **espera**: no es plata, porque plata es el premio del que terminó.
    @Test("sin nada alcanzable y con la colección incompleta, el cofre espera")
    func waitsWhenEverythingReachableIsOwned() {
        let skins = fxChestSkins()
        let alcanzables = fxDesbloqueadoHasta(skins, .comun)
        let owned = Set(skins.chestPool.filter { $0.chestRarity == .comun }.map(\.id))
        var rng: any RandomNumberGenerator = SeededRNG(seed: 41)
        for _ in 0..<50 {
            #expect(ChestRoller.roll(
                owned: owned, unlocked: alcanzables, skins: skins, config: fxChests(), using: &rng
            ) == .needsProgress)
        }
    }

    /// Y con la colección COMPLETA sí paga, aunque el jugador tenga medio catálogo
    /// bloqueado — que no puede pasar, pero es la línea que separa los dos casos.
    @Test("la plata queda reservada para la colección completa de verdad")
    func coinsOnlyWhenTheWholeBagIsOwned() {
        let skins = fxChestSkins()
        let owned = Set(skins.chestPool.map(\.id))
        var rng: any RandomNumberGenerator = SeededRNG(seed: 43)
        guard case .prize(.coins) = ChestRoller.roll(
            owned: owned, unlocked: fxDesbloqueadoHasta(skins, .comun), skins: skins,
            config: fxChests(), using: &rng
        ) else { Issue.record("con todo ganado el cofre paga, no espera"); return }
    }

    /// `hasSomethingToGive` es lo que decide si Regalos dibuja el botón o el
    /// badge apagado, y `roll` es lo que pasa al tocarlo. **Si se separan, la
    /// pantalla miente**: ofrece cofres que no se abren, o esconde cofres que sí.
    ///
    /// Por eso el test no los mira por separado: barre una matriz de estados y
    /// exige que las dos respuestas sean la misma.
    @Test("la pregunta que hace la pantalla y la que contesta el sorteo son la misma")
    func theUIQuestionMatchesTheRoll() {
        let skins = fxChestSkins()
        let porRareza = SkinsConfig.Rarity.allCases.map { r in
            (r, skins.chestPool.filter { $0.chestRarity == r })
        }
        var rng: any RandomNumberGenerator = SeededRNG(seed: 47)

        // Desde "recién llegado" hasta "todo abierto", ganando de a una rareza.
        for cuantasAbiertas in 0...SkinsConfig.Rarity.allCases.count {
            let abiertas = SkinsConfig.Rarity.allCases.prefix(cuantasAbiertas)
            let alcanzables = Set(porRareza.filter { abiertas.contains($0.0) }
                .flatMap { $0.1 }.map(\.characterType))
            for cuantasGanadas in 0...cuantasAbiertas {
                let ganadas = SkinsConfig.Rarity.allCases.prefix(cuantasGanadas)
                let owned = Set(porRareza.filter { ganadas.contains($0.0) }
                    .flatMap { $0.1 }.map(\.id))

                let ofrece = ChestRoller.hasSomethingToGive(
                    owned: owned, unlocked: alcanzables, skins: skins
                )
                let salida = ChestRoller.roll(
                    owned: owned, unlocked: alcanzables, skins: skins, config: fxChests(), using: &rng
                )
                #expect(ofrece == (salida != .needsProgress),
                        "abiertas \(cuantasAbiertas), ganadas \(cuantasGanadas): la pantalla dice \(ofrece) y el sorteo \(salida)")
            }
        }
    }
}
