import SwiftUI
import Testing
@testable import FisuEvolution

/// La cabecera del menú deslizable (E14b B10): las flechas van a la altura del
/// cartel del título, y lo que el paginador publica por preferencia sólo se
/// considera «cambio» cuando cambia algo que se dibuja.
@Suite("La cabecera del paginador de menús")
@MainActor
struct MenuPagerHeaderTests {
    private func chrome(title: CGFloat, header: CGFloat = 120) -> MenuPageChrome {
        MenuPageChrome(awning: true, material: .wood, headerHeight: header, titleHeight: title, ornament: AnyView(EmptyView()))
    }

    @Test("el alto del cartel entra en la igualdad del marco")
    func titleHeightIsPartOfChromeEquality() {
        #expect(chrome(title: 44) == chrome(title: 44))
        #expect(chrome(title: 44) != chrome(title: 52))
        #expect(chrome(title: 44, header: 120) != chrome(title: 44, header: 160))
    }

    @Test("el moño no entra en la igualdad: viaja con el índice")
    func ornamentIsNotPartOfEquality() {
        let plain = chrome(title: 44)
        let decorated = MenuPageChrome(
            awning: true, material: .wood, headerHeight: 120, titleHeight: 44, ornament: AnyView(Color.red)
        )
        #expect(plain == decorated)
    }

    @Test("varios carteles en una página publican el más alto")
    func titleHeightKeyKeepsTheTallest() {
        var value: CGFloat = MenuTitleHeightKey.defaultValue
        MenuTitleHeightKey.reduce(value: &value) { 44 }
        MenuTitleHeightKey.reduce(value: &value) { 38 }
        #expect(value == 44)
        #expect(MenuTitleHeightKey.defaultValue == 0)
    }

    @Test("sólo el cartel cede el hueco de las flechas, no la cabecera entera")
    func chevronSlotIsTheTitleGap() {
        #expect(MenuPagerView.chevronSlot == 42)
    }

    @Test("las vecinas de la página actual se arman; las lejanas no")
    func neighborsAreTheOnesMounted() {
        #expect(MenuPagerView.isMounted(index: 1, current: 2))
        #expect(MenuPagerView.isMounted(index: 3, current: 2))
        #expect(!MenuPagerView.isMounted(index: 0, current: 2))
        #expect(!MenuPagerView.isMounted(index: 4, current: 2))
    }

    @Test("calentar los mismos atlas dos veces no repite el trabajo ni rompe")
    func warmingAtlasesIsIdempotent() {
        UIArt.warmAtlases(["ui"])
        UIArt.warmAtlases(["ui"])
        UIArt.warmAtlases([])
    }
}
