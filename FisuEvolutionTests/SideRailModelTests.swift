import Testing
@testable import FisuEvolution

/// La columna lateral, pura (PLAN-v2 §2): cada botón dice "!" con algo listo,
/// el reloj cuando falta, y nada que confunda cuando no hay nada.
@Suite("La columna lateral, pura")
struct SideRailModelTests {
    private func input(_ change: (inout SideRailInput) -> Void = { _ in }) -> SideRailInput {
        var input = SideRailInput(
            shown: true,
            access: .none,
            packageSecondsUntilNext: 90,
            mattressSecondsUntilNext: 300,
            wheelSecondsUntilReset: 7200,
            mergeAllPairs: 0,
            mergeAll: .notApplicable,
            packageRain: .notApplicable
        )
        change(&input)
        return input
    }

    @Test("oculta no hay columna; a la vista, los cuatro en su orden")
    func visibility() {
        #expect(SideRailModel.state(input { $0.shown = false }) == .hidden)
        #expect(SideRailModel.state(input()).items.map(\.kind) == [.wheel, .mattress, .packages, .boost])
    }

    @Test("la ruleta: cuántos giros quedan, o el reloj hasta mañana")
    func wheel() {
        #expect(SideRailModel.state(input { $0.access.wheelSpinsReady = 3 }).status(of: .wheel) == .ready(count: 3))
        #expect(SideRailModel.state(input()).status(of: .wheel) == .waiting(seconds: 7200))
    }

    @Test("el colchón: «!» si espera, el reloj si no, nada si no hay reloj")
    func mattress() {
        #expect(SideRailModel.state(input { $0.access.mattressReady = true }).status(of: .mattress) == .ready(count: nil))
        #expect(SideRailModel.state(input()).status(of: .mattress) == .waiting(seconds: 300))
        #expect(SideRailModel.state(input { $0.mattressSecondsUntilNext = nil }).status(of: .mattress) == .idle)
    }

    @Test("los paquetes: cuántos, LLENO si no entra ninguno, o el reloj del próximo")
    func packages() {
        #expect(SideRailModel.state(input { $0.access.packagesWaiting = 2 }).status(of: .packages) == .ready(count: 2))
        #expect(SideRailModel.state(input {
            $0.access.packagesWaiting = 1
            $0.access.packagesBlocked = true
        }).status(of: .packages) == .blocked)
        #expect(SideRailModel.state(input()).status(of: .packages) == .waiting(seconds: 90))
    }

    @Test("Fusionar todo: listo con pares, el reloj si se está enfriando, apagado sin pares")
    func boost() {
        #expect(SideRailModel.state(input { $0.mergeAll = .available }).status(of: .boost) == .ready(count: nil))
        #expect(SideRailModel.state(input { $0.mergeAll = .coolingDown(seconds: 61.2) }).status(of: .boost) == .waiting(seconds: 62))
        #expect(SideRailModel.state(input()).status(of: .boost) == .idle)
    }

    @Test("el «!» del botón en reposo suma los accesos listos; LLENO no cuenta")
    func readyCount() {
        #expect(SideRailModel.state(input()).readyCount == 0, "todo con reloj o apagado: sin «!»")
        let busy = SideRailModel.state(input {
            $0.access.wheelSpinsReady = 2
            $0.access.mattressReady = true
            $0.access.packagesWaiting = 1
            $0.access.packagesBlocked = true
            $0.mergeAll = .available
        })
        #expect(busy.readyCount == 3)
        #expect(SideRailModel.state(input { $0.shown = false }).readyCount == 0)
    }

    @Test("los relojes van en segundos enteros: 125 ms de diferencia no cambian lo publicado")
    func clocksAreWholeSeconds() {
        let first = SideRailModel.state(input {
            $0.packageSecondsUntilNext = 89.9
            $0.mergeAll = .coolingDown(seconds: 61.9)
            $0.packageRain = .coolingDown(seconds: 500.9)
        })
        let tick = SideRailModel.state(input {
            $0.packageSecondsUntilNext = 89.775
            $0.mergeAll = .coolingDown(seconds: 61.775)
            $0.packageRain = .coolingDown(seconds: 500.775)
        })
        #expect(first == tick)
        #expect(first.packageRain == .coolingDown(seconds: 501))
    }

    @Test("el reloj: segundos, minutos y horas")
    func clock() {
        #expect(SideRailClock.text(42) == "42s")
        #expect(SideRailClock.text(245) == "4:05")
        #expect(SideRailClock.text(3 * 3600 + 10) == "3h")
    }

    @Test("lo que leen VoiceOver y los tests")
    func accessibilityValue() {
        #expect(SideRailAX.value(.ready(count: 2)) == "ready:2")
        #expect(SideRailAX.value(.ready(count: nil)) == "ready")
        #expect(SideRailAX.value(.blocked) == "full")
        #expect(SideRailAX.value(.waiting(seconds: 9)) == "waiting:9")
        #expect(SideRailAX.value(.idle) == "idle")
    }
}
