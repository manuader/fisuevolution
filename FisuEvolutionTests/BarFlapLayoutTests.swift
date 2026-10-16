import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import FisuEvolution

/// La geometría de los botones de la barra (E14b B28, «Etiqueta y billete»): cada
/// solapa ocupa su mitad y nunca entra al hueco del plato de Contratar, que va
/// arriba de todo; y los textos largos, achicados hasta su piso, entran en lo que
/// les deja la solapa.
@Suite("Los botones de la barra: la geometría")
@MainActor
struct BarFlapLayoutTests {
    /// iPhone SE (3.ª gen.), 15 Pro, Pro Max y el iPad 13" (la columna de juego lo topa).
    private static let widths: [CGFloat] = [375, 393, 430, 1032]

    @Test("ninguna solapa cruza el marco del plato, en ningún teléfono")
    func flapsNeverTouchThePlate() {
        for width in Self.widths {
            let layout = BarFlapLayout.make(barWidth: width)
            #expect(!layout.left.intersects(layout.plate), "izquierda vs plato a \(width) pt")
            #expect(!layout.right.intersects(layout.plate), "derecha vs plato a \(width) pt")
            #expect(layout.left.maxX <= layout.plate.minX - BarFlapLayout.plateGap + 0.001)
            #expect(layout.right.minX >= layout.plate.maxX + BarFlapLayout.plateGap - 0.001)
            #expect(layout.plate.midX == width / 2, "el plato está en el centro")
        }
    }

    /// La barra entera: tres pestañas a la izquierda de Contratar y dos a la derecha.
    private static let fullBar = GameScreen.barOrder.map { $0 == GameScreen.centerTab }

    @Test("con la barra entera el plato queda corrido y las solapas lo esquivan donde está")
    func flapsFollowTheRealPlate() {
        for width in Self.widths {
            let layout = BarFlapLayout.make(barWidth: width, tabs: Self.fullBar)
            let center = GameTabBar.prominentCenterX(prominent: Self.fullBar, barWidth: width) ?? 0
            #expect(abs(layout.plate.midX - center) < 0.001, "el plato es el que dibuja la barra a \(width) pt")
            #expect(layout.plate.midX > width / 2, "tres a la izquierda: el plato se corre a la derecha")
            #expect(!layout.left.intersects(layout.plate), "izquierda vs plato a \(width) pt")
            #expect(!layout.right.intersects(layout.plate), "derecha vs plato a \(width) pt")
            #expect(layout.right.minX >= layout.plate.maxX + BarFlapLayout.plateGap - 0.001)
            #expect(layout.right.width < layout.left.width, "el billete se achica antes que pisarlo")
        }
        // Lo que vio el UI test en el 16 Pro (402 pt): el plato en 191,7…269,7. Ese frame ya viene
        // redondeado al píxel de 3x; la cuenta pura cae a menos de un píxel (1/3 pt) de ahí.
        let pro = BarFlapLayout.make(barWidth: 402, tabs: Self.fullBar)
        #expect(abs(pro.plate.minX - 191.66) < 1.0 / 3)
    }

    @Test("cada solapa se queda en su mitad, dentro de la barra y con el mismo ancho")
    func eachFlapKeepsItsHalf() {
        for width in Self.widths {
            let layout = BarFlapLayout.make(barWidth: width)
            let usable = min(width, PlayColumn.maxWidth)
            let origin = (width - usable) / 2
            #expect(layout.left.minX >= origin + BarFlapLayout.sideMargin - 0.001)
            #expect(layout.left.maxX <= origin + usable / 2 + 0.001)
            #expect(layout.right.minX >= origin + usable / 2 - 0.001)
            #expect(layout.right.maxX <= origin + usable - BarFlapLayout.sideMargin + 0.001)
            #expect(abs(layout.left.width - layout.right.width) < 0.001)
            #expect(layout.left.height == GameTabBar.flapHeight, "la solapa entera es el objetivo de toque")
        }
    }

    @Test("en el SE la solapa se achica antes que pisar el plato y sigue siendo tocable")
    func theSmallestPhoneShrinksTheFlaps() {
        let se = BarFlapLayout.make(barWidth: 375)
        let pro = BarFlapLayout.make(barWidth: 430)
        #expect(se.left.width < pro.left.width)
        #expect(se.left.width >= 100, "alcanza para la etiqueta y el billete")
        // Hasta con la barra del SE de primera generación no hay cruce.
        let tiny = BarFlapLayout.make(barWidth: 320)
        #expect(!tiny.left.intersects(tiny.plate))
        #expect(!tiny.right.intersects(tiny.plate))
    }

    @Test("la carpeta tiene el tamaño del plato de arte, cabe en lo que sobresale la barra y su botón no es toda la celda")
    func folderKeepsThePlateSize() {
        #expect(GameTabBar.centerPlateSide == 70)
        #expect(GameTabBar.riseHeight >= GameTabBar.centerRise)
        #expect(GameTabBar.centerButtonWidth >= GameTabBar.centerPlateSide)
        // Con pocas pestañas la celda de Contratar es enorme: el botón no la usa entera.
        let early = GameTabBar.cellWidths(prominent: [false, true, false], available: 351)
        #expect(early[1] > GameTabBar.centerButtonWidth)
    }

    // MARK: - Textos largos

    private func width(of text: String, font: UIFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    @Test("el billete: «Reencarnar» y la meta, achicados hasta su piso, entran en es y en")
    func billTextFitsInBothLanguages() {
        let titles = ["Reencarnar", "Reincarnate"]
        let metas = ["Meta: Multimillonario", "Goal: Multimillionaire", "Meta: tier 12", "+1.23M", "100%"]
        for width in Self.widths {
            let lane = BarFlapLayout.make(barWidth: width, tabs: Self.fullBar).right.width
            for title in titles {
                let natural = self.width(of: title, font: rounded(PrestigeButton.titleSize, .black))
                #expect(natural * PrestigeButton.titleMinScale <= PrestigeButton.titleWidth(lane: lane),
                        "«\(title)» a \(width) pt")
            }
            for meta in metas {
                let natural = self.width(of: meta, font: rounded(PrestigeButton.metaSize, .black))
                #expect(natural * PrestigeButton.metaMinScale <= PrestigeButton.metaWidth(lane: lane),
                        "«\(meta)» a \(width) pt")
            }
        }
    }

    @Test("la etiqueta: el monto más largo, achicado hasta su piso, entra en la placa")
    func tagPriceFits() {
        let prices = ["999", "1.23M", "999.99Qa", CoinFormatter.string(from: 1e300),
                      CoinFormatter.string(from: .greatestFiniteMagnitude)]
        for width in Self.widths {
            let lane = BarFlapLayout.make(barWidth: width, tabs: Self.fullBar).left.width
            let available = QuickHireButton.priceTextWidth(lane: lane)
            #expect(available >= 40, "la placa tiene lugar a \(width) pt")
            for price in prices {
                let natural = self.width(of: price, font: rounded(15, .bold))
                #expect(natural * 0.5 <= available, "«\(price)» a \(width) pt")
            }
        }
    }
}
