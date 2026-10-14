import Testing
@testable import FisuEvolution

/// Los sellos de la esquina de arriba a la izquierda (E14 C9, D8): sólo se
/// dibujan los disponibles; el resto entra cuando se desbloquea.
@Suite("RailSeals")
struct RailSealsTests {
    private func rail(_ statuses: [SideRailKind: SideRailStatus]) -> SideRailState {
        SideRailState(items: SideRailKind.allCases.map { SideRailItem(kind: $0, status: statuses[$0] ?? .idle) })
    }

    @Test("los sellos sin nada que cobrar ni reloj que mostrar no se dibujan")
    func idleSealsAreHidden() {
        let state = rail([.wheel: .ready(count: 2), .mattress: .waiting(seconds: 90), .packages: .blocked])

        let kinds = state.shownItems(lessonTarget: nil).map(\.kind)

        #expect(kinds == [.wheel, .mattress, .packages])
    }

    @Test("al volverse disponible, el sello entra en su lugar de siempre")
    func aSealEntersWhenItBecomesAvailable() {
        let before = rail([.wheel: .ready(count: 1)])
        let after = rail([.wheel: .ready(count: 1), .boost: .ready(count: nil)])

        #expect(before.shownItems(lessonTarget: nil).map(\.kind) == [.wheel])
        #expect(after.shownItems(lessonTarget: nil).map(\.kind) == [.wheel, .boost])
    }

    @Test("el sello que una lección señala se queda aunque esté apagado")
    func theLessonTargetStaysVisible() {
        let state = rail([.wheel: .ready(count: 1)])

        let kinds = state.shownItems(lessonTarget: .sidePackages).map(\.kind)

        #expect(kinds == [.wheel, .packages])
    }

    @Test("sin paquetes, el sello de Paquetes vive mientras se pueda ofrecer la lluvia por video")
    func packagesStayForTheRainVideo() {
        var state = rail([.wheel: .ready(count: 1)])

        state.packageRain = .available
        #expect(state.shownItems(lessonTarget: nil).map(\.kind) == [.wheel, .packages])
        #expect(state.shownItems(lessonTarget: nil).last?.status == .ready(count: nil))

        state.packageRain = .coolingDown(seconds: 90)
        #expect(state.shownItems(lessonTarget: nil).last?.status == .waiting(seconds: 90))

        state.packageRain = .notApplicable
        #expect(state.shownItems(lessonTarget: nil).map(\.kind) == [.wheel])
    }

    @Test("sin columna no hay sellos")
    func nothingWhenTheRailIsHidden() {
        #expect(SideRailState.hidden.shownItems(lessonTarget: .sideWheel).isEmpty)
    }
}
