import Foundation
import Testing
@testable import FisuEvolution

@Suite("CoinFormatter")
struct CoinFormatterTests {
    private func plain(_ value: Double) -> String {
        // Normaliza el separador decimal del locale para comparar estable.
        CoinFormatter.string(from: value).replacingOccurrences(of: ",", with: ".")
    }

    private func cost(_ value: Double) -> String {
        CoinFormatter.cost(from: value).replacingOccurrences(of: ",", with: ".")
    }

    @Test func smallValuesAreRaw() {
        #expect(plain(0) == "0")
        #expect(plain(15) == "15")
        #expect(plain(999) == "999")
        #expect(plain(999.9) == "999")
    }

    @Test func thousandsAndMillions() {
        #expect(plain(1000) == "1K")
        #expect(plain(1500) == "1.5K")
        #expect(plain(19_837.5) == "19.8K")
        #expect(plain(2_500_000) == "2.5M")
        #expect(plain(999_000_000_000) == "999B")
    }

    @Test func trillionsThenLetterPairs() {
        #expect(plain(1e12) == "1T")
        #expect(plain(1e15) == "1aa")
        #expect(plain(1e18) == "1ab")
        #expect(plain(6.5121e16) == "65.1aa")
    }

    @Test func hundredsScaleDropsDecimals() {
        #expect(plain(123_456) == "123K")
        #expect(plain(987_654_321) == "988M")
    }

    /// ⚠️ El sufijo se elige **después** de redondear. La mantisa cruda de
    /// 999_500 es 999,5 y a cero decimales se va a 1000: mostrar "1.000K" era
    /// mentir un orden de magnitud entero en el HUD (Critical del review de
    /// T20). El caso vive en el borde de CADA sufijo, no sólo en el de K.
    @Test func roundingUpToFourDigitsBumpsTheSuffix() {
        #expect(plain(999_500) == "1M")
        #expect(plain(999_999) == "1M")
        #expect(plain(999_500_000) == "1B")
        #expect(plain(999_999_999_999) == "1T")
        #expect(plain(9.995e14) == "1aa")
    }

    /// El otro lado del mismo borde: lo que NO llega a 1000 redondeado se queda
    /// con su sufijo y con sus tres dígitos.
    @Test func justBelowTheBoundaryKeepsItsSuffix() {
        #expect(plain(999_499) == "999K")
        #expect(plain(999_000) == "999K")
        #expect(plain(999_499_000) == "999M")
    }

    /// El borde bajo NO se toca: abajo de 1000 el valor se trunca hacia abajo
    /// (999,9 → "999") a propósito, para no anunciar plata que no se puede
    /// gastar. Es la única asimetría del formateador y queda pineada acá.
    @Test func theLowBoundaryStillTruncates() {
        #expect(plain(999.9) == "999")
        #expect(plain(999.999) == "999")
        #expect(plain(1000) == "1K")
    }

    // MARK: Precios

    /// **Un precio se redondea al revés que un saldo**, y las dos mitades de la
    /// asimetría existen por el mismo motivo: ninguna puede mentir para el lado
    /// que rompe. El saldo trunca para no anunciar plata que no se puede gastar
    /// (`theLowBoundaryStillTruncates`); el precio sube para no anunciar una
    /// compra más barata de lo que se cobra.
    ///
    /// El caso que lo trajo: 25 × 1,03 = 25,75. Truncado se leía "25", y un
    /// jugador con 25 monedas exactas tocaba el botón y le rebotaba.
    @Test func costsRoundUpSoTheyNeverUndersell() {
        #expect(cost(25) == "25", "un precio exacto no se infla")
        #expect(cost(25.75) == "26")
        #expect(cost(26.5) == "27")
        #expect(cost(0) == "0")
    }

    /// El borde: 999,5 no puede salir como "1000" —cuatro dígitos crudos al lado
    /// de las abreviaturas— así que sube al sufijo por el mismo camino que
    /// cualquier otro valor de esa escala.
    @Test func aCostThatRoundsPastTheBoundaryTakesTheSuffix() {
        #expect(cost(999) == "999")
        #expect(cost(999.5) == "1K")
        #expect(cost(1000) == "1K")
    }

    /// De 1000 para arriba el número ya es una abreviatura y no promete el valor
    /// exacto, así que precio y saldo se formatean igual.
    @Test func aboveTheExactRangeCostsMatchPlainFormatting() {
        for value in [1500.0, 2_500_000, 9.9e15] {
            #expect(cost(value) == plain(value))
        }
    }

    @Test func pathologicalInputsNeverCrash() {
        #expect(plain(.infinity) == "∞")
        #expect(plain(-5) == "∞")
        #expect(!plain(.greatestFiniteMagnitude).isEmpty)
    }
}
