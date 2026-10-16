import EconomyKit
import SwiftUI

/// Cuándo se dice «Oferta elegida para vos» (2.1 E15 F5, V8). Una oferta con audiencia se le abre a
/// un jugador por su segmento; en las tiendas de la UE eso se avisa en la hoja, a la vista. Es
/// prudencia (R5: Omnibus no lo exige para elegir *qué* oferta se muestra, sin tocar el precio)
/// `[VERIFICAR CON ABOGADO]` en F1-T9.
enum OfferNotice {
    /// Los 27 de la UE, en el alfa-3 de `Storefront.countryCode`.
    static let euStorefronts: Set<String> = [
        "AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN",
        "FRA", "DEU", "GRC", "HUN", "IRL", "ITA", "LVA", "LTU", "LUX",
        "MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE",
    ]

    /// Sin tienda conocida, no: el aviso es de la UE.
    static func isEU(storefront: String?) -> Bool {
        guard let storefront, !storefront.isEmpty else { return false }
        return euStorefronts.contains(storefront.uppercased())
    }

    /// La oferta se eligió por el segmento: tiene audiencia y el segmento no es `base` (con `base`
    /// la audiencia se ignora y la oferta es la de todos, como en la 2.0).
    static func isChosen(audience: OfferAudience?, segment: PlayerSegment) -> Bool {
        audience != nil && segment != .base
    }
}

/// La cinta «Elegido para vos» / «Oferta elegida para vos»: una banderola con las puntas en cola
/// de golondrina, del naranja de la casa con su borde hundido y una chispa dibujada (nada de
/// cápsulas planas ni SF Symbols). Es una etiqueta, no un botón.
struct ChosenForYouRibbon: View {
    let titleKey: LocalizedStringKey
    let identifier: String
    var tint: Color = Color("PaletteOrange")

    var body: some View {
        HStack(spacing: 4) {
            GameGlyphView(glyph: .sparkle, size: 14)
            Text(titleKey)
                .font(Tokens.caption)
                .foregroundStyle(Color("PaletteCream"))
                .shadow(color: .black.opacity(0.35), radius: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.leading, Tokens.s8 + 4)
        .padding(.trailing, Tokens.s8 + 6)
        .padding(.vertical, 4)
        .background {
            SwallowtailBanner()
                .fill(LinearGradient(colors: [tint.lifted(0.14), tint], startPoint: .top, endPoint: .bottom))
                .overlay(SwallowtailBanner().stroke(tint.deepened(0.3), lineWidth: 2))
                .background(SwallowtailBanner().fill(tint.deepened(0.3)).offset(y: 2))
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
        // Sin `fixedSize`: en la columna angosta de una fila de la Tienda el texto se achica
        // (`minimumScaleFactor`) en vez de salirse de la tarjeta.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(titleKey))
        .accessibilityIdentifier(identifier)
    }
}

/// Una banda con la punta derecha en cola de golondrina y la izquierda cortada en diagonal.
private struct SwallowtailBanner: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = min(rect.height * 0.35, 8)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + notch * 0.6, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
