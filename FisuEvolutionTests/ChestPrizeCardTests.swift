import EconomyKit
import Testing
@testable import FisuEvolution

/// La tarjeta de figurita del premio del cofre (E14b B8, D7): fondo y borde
/// iguales para todas; sólo el brillo y el sello cambian con la rareza.
@Suite("El cofre: la tarjeta del premio")
struct ChestPrizeCardTests {
    @Test func elFondoYElBordeSonLosMismosParaTodasLasRarezas() {
        // Son constantes de tipo: no dependen de la rareza.
        #expect(ChestCardStyle.paperAsset == "PaletteCream")
        #expect(ChestCardStyle.borderAsset == "PaletteBrown")
        #expect(ChestCardStyle.borderWidth >= 4, "borde grueso")
    }

    @Test func cadaRarezaTieneSuPropioBrillo() {
        let brillos = SkinsConfig.Rarity.allCases.map { ChestCardStyle.glowAsset($0) }
        #expect(Set(brillos).count == SkinsConfig.Rarity.allCases.count)
    }

    @Test func elSelloLlevaElColorDelBrillo() {
        for rarity in SkinsConfig.Rarity.allCases {
            #expect(ChestCardStyle.sealAsset(rarity) == ChestCardStyle.glowAsset(rarity))
        }
    }

    @Test func elBrilloNoEsElColorDelFondo() {
        for rarity in SkinsConfig.Rarity.allCases {
            #expect(ChestCardStyle.glowAsset(rarity) != ChestCardStyle.paperAsset)
        }
    }

    /// D14: la tarjeta entra en el bloque del premio y éste no pisa el cofre.
    @Test func laTarjetaEntraEnElBloqueDelPremio() {
        #expect(ChestCardStyle.height + 16 + 40 <= ChestStage.prizeHeight)
        #expect(ChestStage.prizeBottomY < ChestStage.lidTopY)
        #expect(ChestStage.prizeY - ChestStage.prizeHeight / 2 > -667 / 2)
    }
}
