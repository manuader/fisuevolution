import Foundation

/// Abbreviates idle-scale numbers: 999 → "999", 1500 → "1,5K", 2.5e6 → "2,5M",
/// then B/T and letter pairs (1e15 → "aa", 1e18 → "ab", …). Values reach 10¹⁶⁺
/// (T30 tapYield), so raw formatting is never shown past 4 digits.
enum CoinFormatter {
    private static let suffixes: [String] = {
        var result = ["K", "M", "B", "T"]
        for first in UnicodeScalar("a").value...UnicodeScalar("e").value {
            for second in UnicodeScalar("a").value...UnicodeScalar("z").value {
                result.append(String(UnicodeScalar(first)!) + String(UnicodeScalar(second)!))
            }
        }
        return result
    }()

    static func string(from value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "∞" }
        if value < 1000 {
            return String(Int(value.rounded(.down)))
        }

        var scaled = value
        var suffixIndex = -1
        while scaled >= 1000 && suffixIndex < suffixes.count - 1 {
            scaled /= 1000
            suffixIndex += 1
        }

        // ⚠️ **El sufijo se elige DESPUÉS de redondear, no antes.** La mantisa
        // cruda de 999_500 es 999,5 y el redondeo a cero decimales la lleva a
        // 1000: con el sufijo ya fijado, el HUD mostraba "1.000K" — un orden de
        // magnitud entero de mentira, y encima con separador de miles adentro de
        // una abreviatura que existe justo para no tenerlo. Si la mantisa
        // redondeada llega a 1000 se re-escala y sube un sufijo (999_500 → 1M).
        //
        // El redondeo se hace ACÁ y no se delega al format style porque hay que
        // MIRAR el resultado antes de decidir el sufijo. Se usa la misma regla
        // que trae `.number` de fábrica (`.toNearestOrEven`) para que pre-redondear
        // no cambie ni un caso que ya funcionaba, y el valor que se le pasa al
        // formateador ya viene en su precisión final, así que el segundo redondeo
        // es un no-op.
        var digits = fractionDigits(for: scaled)
        var mantissa = rounded(scaled, digits: digits)
        if mantissa >= 1000, suffixIndex < suffixes.count - 1 {
            suffixIndex += 1
            // Es exactamente 1000: dividir da 1,0 y no puede volver a desbordar.
            mantissa = 1
            digits = fractionDigits(for: mantissa)
        }

        let number = mantissa.formatted(.number.precision(.fractionLength(0...digits)))
        return number + suffixes[suffixIndex]
    }

    /// Un decimal mientras la mantisa tenga dos dígitos enteros o menos; ninguno
    /// de ahí para arriba, que "123,4K" no cabe en la píldora del HUD.
    private static func fractionDigits(for mantissa: Double) -> Int {
        mantissa < 100 ? 1 : 0
    }

    private static func rounded(_ value: Double, digits: Int) -> Double {
        let factor = digits == 1 ? 10.0 : 1.0
        return (value * factor).rounded(.toNearestOrEven) / factor
    }
}
